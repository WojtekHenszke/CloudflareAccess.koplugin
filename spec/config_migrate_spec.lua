local config = require("config")

local function reset_settings()
    config._reset_for_test()
    for k in pairs(_G._test_settings_data) do
        _G._test_settings_data[k] = nil
    end
end

describe("config.migrate()", function()
    before_each(function()
        reset_settings()
    end)

    it("migrates schema=1 to schema=2 with custom_headers added", function()
        _G._test_settings_data.schema = 1
        _G._test_settings_data.enabled = true
        _G._test_settings_data.client_id = "<client-id>"
        _G._test_settings_data.client_secret = "<client-secret>"
        _G._test_settings_data.domains = { "example.com", "api.example.com" }
        _G._test_settings_data.log_level = "dbg"

        config.migrate()

        assert.equals(2, _G._test_settings_data.schema)
        assert.same({}, _G._test_settings_data.custom_headers)
        assert.is_true(_G._test_settings_data.enabled)
        assert.equals("<client-id>", _G._test_settings_data.client_id)
        assert.equals("<client-secret>", _G._test_settings_data.client_secret)
        assert.same({ "example.com", "api.example.com" }, _G._test_settings_data.domains)
        assert.equals("dbg", _G._test_settings_data.log_level)
    end)

    it("is idempotent on repeated calls", function()
        _G._test_settings_data.schema = 1
        _G._test_settings_data.enabled = false
        _G._test_settings_data.client_id = "id"
        _G._test_settings_data.client_secret = "secret"
        _G._test_settings_data.domains = { "a.com" }

        config.migrate()

        assert.equals(2, _G._test_settings_data.schema)
        assert.same({}, _G._test_settings_data.custom_headers)

        config.migrate()

        assert.equals(2, _G._test_settings_data.schema)
        assert.same({}, _G._test_settings_data.custom_headers)
        assert.is_false(_G._test_settings_data.enabled)
        assert.equals("id", _G._test_settings_data.client_id)
        assert.equals("secret", _G._test_settings_data.client_secret)
        assert.same({ "a.com" }, _G._test_settings_data.domains)
    end)

    it("initialises defaults on fresh settings (no schema)", function()
        config.migrate()

        assert.equals(2, _G._test_settings_data.schema)
        assert.same({}, _G._test_settings_data.custom_headers)
    end)

    it("does not overwrite existing custom_headers during migration", function()
        _G._test_settings_data.schema = 1
        _G._test_settings_data.custom_headers = {
            { name = "X-Rule", value = "val", domains = { "x.com" }, enabled = true, secret = false },
        }

        config.migrate()

        assert.equals(2, _G._test_settings_data.schema)
        assert.equals("X-Rule", _G._test_settings_data.custom_headers[1].name)
        assert.equals("val", _G._test_settings_data.custom_headers[1].value)
        assert.same({ "x.com" }, _G._test_settings_data.custom_headers[1].domains)
        assert.is_true(_G._test_settings_data.custom_headers[1].enabled)
        assert.is_false(_G._test_settings_data.custom_headers[1].secret)
    end)
end)
