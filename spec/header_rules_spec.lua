local hr = require("lib.header_rules")

describe("header_rules", function()
    describe("validate_name", function()
        it("accepts a simple valid name", function()
            assert.is_true(hr.validate_name("Authorization"))
        end)

        it("accepts names with hyphens and digits", function()
            assert.is_true(hr.validate_name("X-Api-Key"))
            assert.is_true(hr.validate_name("CF-Access-Client-Id"))
        end)

        it("accepts all RFC 7230 tchar characters", function()
            assert.is_true(hr.validate_name("X!#$%&'*+-.^_`|~"))
        end)

        it("rejects empty string", function()
            local ok, err = hr.validate_name("")
            assert.is_false(ok)
            assert.truthy(err)
        end)

        it("rejects nil", function()
            local ok, err = hr.validate_name(nil)
            assert.is_false(ok)
            assert.truthy(err)
        end)

        it("rejects names with spaces", function()
            local ok, err = hr.validate_name("X Test Header")
            assert.is_false(ok)
            assert.truthy(err)
        end)

        it("rejects names with colons", function()
            local ok, err = hr.validate_name("X:Header")
            assert.is_false(ok)
            assert.truthy(err)
        end)
    end)

    describe("validate_value", function()
        it("accepts a simple value", function()
            assert.is_true(hr.validate_value("Bearer abc123"))
        end)

        it("accepts empty value", function()
            assert.is_true(hr.validate_value(""))
        end)

        it("rejects nil", function()
            local ok, err = hr.validate_value(nil)
            assert.is_false(ok)
            assert.truthy(err)
        end)

        it("rejects CR", function()
            local ok, err = hr.validate_value("line\rbreak")
            assert.is_false(ok)
            assert.truthy(err)
        end)

        it("rejects LF", function()
            local ok, err = hr.validate_value("line\nbreak")
            assert.is_false(ok)
            assert.truthy(err)
        end)

        it("rejects CRLF", function()
            local ok, err = hr.validate_value("line\r\nbreak")
            assert.is_false(ok)
            assert.truthy(err)
        end)

        it("rejects values exceeding max length", function()
            local long = string.rep("a", 4097)
            local ok, err = hr.validate_value(long)
            assert.is_false(ok)
            assert.truthy(err)
        end)

        it("accepts values at exactly max length", function()
            local exact = string.rep("a", 4096)
            assert.is_true(hr.validate_value(exact))
        end)
    end)

    describe("validate_rule", function()
        local function valid_rule()
            return {
                name = "X-Test",
                value = "val",
                domains = {},
                enabled = true,
                secret = true,
            }
        end

        it("accepts a valid rule", function()
            assert.is_true(hr.validate_rule(valid_rule()))
        end)

        it("rejects non-table", function()
            local ok, err = hr.validate_rule("not a table")
            assert.is_false(ok)
            assert.truthy(err)
        end)

        it("rejects invalid name", function()
            local r = valid_rule()
            r.name = "bad name"
            local ok, err = hr.validate_rule(r)
            assert.is_false(ok)
            assert.truthy(err)
        end)

        it("rejects invalid value (CRLF)", function()
            local r = valid_rule()
            r.value = "bad\r\nvalue"
            local ok, err = hr.validate_rule(r)
            assert.is_false(ok)
            assert.truthy(err)
        end)

        it("rejects non-array domains", function()
            local r = valid_rule()
            r.domains = "not a table"
            local ok, err = hr.validate_rule(r)
            assert.is_false(ok)
            assert.truthy(err)
        end)

        it("rejects domains with non-string entry", function()
            local r = valid_rule()
            r.domains = { "ok.com", 123 }
            local ok, err = hr.validate_rule(r)
            assert.is_false(ok)
            assert.truthy(err)
        end)

        it("rejects non-boolean enabled", function()
            local r = valid_rule()
            r.enabled = "yes"
            local ok, err = hr.validate_rule(r)
            assert.is_false(ok)
            assert.truthy(err)
        end)

        it("rejects non-boolean secret", function()
            local r = valid_rule()
            r.secret = 1
            local ok, err = hr.validate_rule(r)
            assert.is_false(ok)
            assert.truthy(err)
        end)
    end)

    describe("effective_domains", function()
        it("returns rule domains when non-empty", function()
            local rule = { domains = { "a.com", "b.com" } }
            assert.same({ "a.com", "b.com" }, hr.effective_domains(rule, { "global.com" }))
        end)

        it("falls back to global when rule domains is empty", function()
            local rule = { domains = {} }
            assert.same({ "global.com" }, hr.effective_domains(rule, { "global.com" }))
        end)

        it("falls back to global when rule domains is nil", function()
            local rule = {}
            assert.same({ "global.com" }, hr.effective_domains(rule, { "global.com" }))
        end)

        it("returns empty when both are empty", function()
            local rule = { domains = {} }
            assert.same({}, hr.effective_domains(rule, {}))
        end)

        it("returns empty when both are nil/empty", function()
            local rule = {}
            assert.same({}, hr.effective_domains(rule, nil))
        end)
    end)

    describe("applies", function()
        it("matches host in rule's own domains", function()
            local rule = { domains = { "example.com" } }
            assert.is_true(hr.applies(rule, "example.com", { "other.com" }))
            assert.is_true(hr.applies(rule, "sub.example.com", { "other.com" }))
        end)

        it("does not match host outside rule's own domains", function()
            local rule = { domains = { "example.com" } }
            assert.is_false(hr.applies(rule, "other.com", { "other.com" }))
        end)

        it("falls back to global domains when rule domains is empty", function()
            local rule = { domains = {} }
            assert.is_true(hr.applies(rule, "global.com", { "global.com" }))
            assert.is_false(hr.applies(rule, "other.com", { "global.com" }))
        end)

        it("matches everything when both rule and global are empty (unsafe fallback)", function()
            local rule = { domains = {} }
            assert.is_true(hr.applies(rule, "anything.com", {}))
            assert.is_true(hr.applies(rule, "evil.com", nil))
        end)
    end)

    describe("mask_preview", function()
        it("masks a long string as abcd…wxyz", function()
            assert.equals("abcd…wxyz", hr.mask_preview("abcdefghijklmnopqrstuvwxyz"))
        end)

        it("returns **** for short strings", function()
            assert.equals("****", hr.mask_preview("short"))
            assert.equals("****", hr.mask_preview("12345678"))
        end)

        it("returns empty string for empty/nil input", function()
            assert.equals("", hr.mask_preview(""))
            assert.equals("", hr.mask_preview(nil))
        end)

        it("masks a 9-char string (just above threshold)", function()
            assert.equals("1234…6789", hr.mask_preview("123456789"))
        end)
    end)

    describe("redact_for_log", function()
        it("always returns <redacted>", function()
            assert.equals("<redacted>", hr.redact_for_log("secret-value"))
            assert.equals("<redacted>", hr.redact_for_log(""))
            assert.equals("<redacted>", hr.redact_for_log(nil))
            assert.equals("<redacted>", hr.redact_for_log("anything"))
        end)
    end)
end)
