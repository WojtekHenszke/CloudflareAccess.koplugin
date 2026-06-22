local config = require("config")

-- Helper: clear shared settings data between tests
local function reset_settings()
    config._reset_for_test()
    for k in pairs(_G._test_settings_data) do
        _G._test_settings_data[k] = nil
    end
end

-- Helper: a valid rule for tests
local function make_rule(overrides)
    return {
        name = overrides.name or "X-Test-Header",
        value = overrides.value or "test-value",
        domains = overrides.domains or {},
        enabled = overrides.enabled ~= nil and overrides.enabled or true,
        secret = overrides.secret ~= nil and overrides.secret or true,
    }
end

describe("config custom headers", function()
    before_each(function()
        reset_settings()
    end)

    describe("schema migration", function()
        it("migrates from v0.1.0 (schema=1) to schema=2", function()
            _G._test_settings_data.schema = 1
            _G._test_settings_data.enabled = true
            _G._test_settings_data.client_id = "<client-id>"
            _G._test_settings_data.client_secret = "<client-secret>"
            _G._test_settings_data.domains = { "example.com" }

            config.migrate()

            assert.equals(2, _G._test_settings_data.schema)
            assert.same({}, _G._test_settings_data.custom_headers)
            -- Existing v0.1.0 data untouched
            assert.is_true(_G._test_settings_data.enabled)
            assert.equals("<client-id>", _G._test_settings_data.client_id)
            assert.equals("<client-secret>", _G._test_settings_data.client_secret)
            assert.same({ "example.com" }, _G._test_settings_data.domains)
        end)

        it("is idempotent (running twice is safe)", function()
            _G._test_settings_data.schema = 1
            config.migrate()
            assert.equals(2, _G._test_settings_data.schema)
            assert.same({}, _G._test_settings_data.custom_headers)

            -- Run again — nothing should break
            config.migrate()
            assert.equals(2, _G._test_settings_data.schema)
            assert.same({}, _G._test_settings_data.custom_headers)
        end)

        it("preserves existing custom_headers during migration", function()
            _G._test_settings_data.schema = 1
            local existing = {
                { name = "X-Existing", value = "val", domains = {}, enabled = true, secret = false },
            }
            _G._test_settings_data.custom_headers = existing

            config.migrate()

            assert.equals(2, _G._test_settings_data.schema)
            assert.same(existing, _G._test_settings_data.custom_headers)
        end)

        it("migrates from schema=0 (fresh install)", function()
            config.migrate()
            assert.equals(2, _G._test_settings_data.schema)
            assert.same({}, _G._test_settings_data.custom_headers)
        end)
    end)

    describe("getCustomHeaders", function()
        it("returns empty table when no rules exist", function()
            assert.same({}, config.getCustomHeaders())
        end)

        it("returns a deep copy (mutating result does not affect state)", function()
            config.addCustomHeader(make_rule({ name = "X-Test" }))
            local headers = config.getCustomHeaders()
            headers[1].name = "MUTATED"
            headers[1].domains[1] = "injected.example.com"

            -- Persisted state unchanged
            local fresh = config.getCustomHeaders()
            assert.equals("X-Test", fresh[1].name)
            assert.same({}, fresh[1].domains)
        end)
    end)

    describe("getCustomHeader", function()
        it("returns a deep copy of a single rule", function()
            config.addCustomHeader(make_rule({ name = "X-One" }))
            config.addCustomHeader(make_rule({ name = "X-Two" }))

            local rule = config.getCustomHeader(1)
            assert.equals("X-One", rule.name)
            rule.name = "MUTATED"

            -- Persisted state unchanged
            assert.equals("X-One", config.getCustomHeader(1).name)
        end)

        it("returns nil for out-of-range index", function()
            assert.is_nil(config.getCustomHeader(0))
            assert.is_nil(config.getCustomHeader(1))
            assert.is_nil(config.getCustomHeader(-1))
        end)
    end)

    describe("addCustomHeader", function()
        it("appends a rule and returns its index", function()
            local idx = config.addCustomHeader(make_rule({ name = "X-First" }))
            assert.equals(1, idx)

            local idx2 = config.addCustomHeader(make_rule({ name = "X-Second" }))
            assert.equals(2, idx2)

            local headers = config.getCustomHeaders()
            assert.equals(2, #headers)
            assert.equals("X-First", headers[1].name)
            assert.equals("X-Second", headers[2].name)
        end)

        it("rejects invalid rule shape and returns nil, err", function()
            local idx, err = config.addCustomHeader({ name = "X-Test" }) -- missing fields
            assert.is_nil(idx)
            assert.truthy(err)

            idx, err = config.addCustomHeader({
                name = "X-Test",
                value = "val",
                domains = {},
                enabled = "not a bool",
                secret = true,
            })
            assert.is_nil(idx)
            assert.truthy(err)
        end)

        it("stores a deep copy (mutating original does not affect state)", function()
            local rule = make_rule({ name = "X-Test", domains = { "example.com" } })
            config.addCustomHeader(rule)
            rule.name = "MUTATED"
            rule.domains[1] = "injected.com"

            local stored = config.getCustomHeader(1)
            assert.equals("X-Test", stored.name)
            assert.equals("example.com", stored.domains[1])
        end)
    end)

    describe("updateCustomHeader", function()
        it("replaces a rule by index", function()
            config.addCustomHeader(make_rule({ name = "X-Old" }))
            local ok = config.updateCustomHeader(1, make_rule({ name = "X-New" }))
            assert.is_true(ok)
            assert.equals("X-New", config.getCustomHeader(1).name)
        end)

        it("returns false for out-of-range index", function()
            local ok, err = config.updateCustomHeader(99, make_rule({}))
            assert.is_false(ok)
            assert.truthy(err)
        end)

        it("rejects invalid rule shape", function()
            config.addCustomHeader(make_rule({}))
            local ok, err = config.updateCustomHeader(1, { name = "X-Test" })
            assert.is_false(ok)
            assert.truthy(err)
        end)
    end)

    describe("removeCustomHeader", function()
        it("removes a rule and preserves order of survivors", function()
            config.addCustomHeader(make_rule({ name = "X-One" }))
            config.addCustomHeader(make_rule({ name = "X-Two" }))
            config.addCustomHeader(make_rule({ name = "X-Three" }))

            local ok = config.removeCustomHeader(2)
            assert.is_true(ok)

            local headers = config.getCustomHeaders()
            assert.equals(2, #headers)
            assert.equals("X-One", headers[1].name)
            assert.equals("X-Three", headers[2].name)
        end)

        it("returns false for out-of-range index", function()
            assert.is_false(config.removeCustomHeader(0))
            assert.is_false(config.removeCustomHeader(1))
        end)
    end)

    describe("setCustomHeaderEnabled", function()
        it("toggles the enabled flag", function()
            config.addCustomHeader(make_rule({ enabled = true }))
            config.setCustomHeaderEnabled(1, false)
            assert.is_false(config.getCustomHeader(1).enabled)

            config.setCustomHeaderEnabled(1, true)
            assert.is_true(config.getCustomHeader(1).enabled)
        end)

        it("returns false for out-of-range index", function()
            assert.is_false(config.setCustomHeaderEnabled(99, true))
        end)
    end)

    describe("setCustomHeaders", function()
        it("replaces all rules with validation", function()
            config.addCustomHeader(make_rule({ name = "X-Old" }))
            config.setCustomHeaders({
                make_rule({ name = "X-New-1" }),
                make_rule({ name = "X-New-2" }),
            })
            local headers = config.getCustomHeaders()
            assert.equals(2, #headers)
            assert.equals("X-New-1", headers[1].name)
            assert.equals("X-New-2", headers[2].name)
        end)

        it("rejects a list containing an invalid rule", function()
            config.addCustomHeader(make_rule({ name = "X-Original" }))
            local ok = config.setCustomHeaders({
                make_rule({ name = "X-Valid" }),
                { name = "X-Invalid" }, -- missing fields
            })
            assert.is_false(ok)
            -- Original data preserved (setCustomHeaders failed atomically)
            local headers = config.getCustomHeaders()
            assert.equals(1, #headers)
            assert.equals("X-Original", headers[1].name)
        end)
    end)

    describe("getSnapshot", function()
        it("includes custom_headers in the snapshot", function()
            config.addCustomHeader(make_rule({ name = "X-Snap" }))
            local snap = config.getSnapshot()
            assert.truthy(snap.custom_headers)
            assert.equals(1, #snap.custom_headers)
            assert.equals("X-Snap", snap.custom_headers[1].name)
        end)

        it("snapshot custom_headers is a deep copy", function()
            config.addCustomHeader(make_rule({ name = "X-Snap", domains = { "a.com" } }))
            local snap = config.getSnapshot()
            snap.custom_headers[1].name = "MUTATED"
            snap.custom_headers[1].domains[1] = "b.com"

            local fresh = config.getSnapshot()
            assert.equals("X-Snap", fresh.custom_headers[1].name)
            assert.equals("a.com", fresh.custom_headers[1].domains[1])
        end)
    end)
end)
