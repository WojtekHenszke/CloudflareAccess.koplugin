local editor_internal = require("lib.editor_internal")

describe("editor_internal.coerce_defaults()", function()
    it("preserves enabled=false from existing rule", function()
        local existing = { name = "X-Test", value = "v", domains = {}, enabled = false, secret = true }
        local _, _, _, enabled, secret = editor_internal.coerce_defaults(existing)
        assert.is_false(enabled)
        assert.is_true(secret)
    end)

    it("preserves secret=false from existing rule", function()
        local existing = { name = "X-Test", value = "v", domains = {}, enabled = true, secret = false }
        local _, _, _, enabled, secret = editor_internal.coerce_defaults(existing)
        assert.is_true(enabled)
        assert.is_false(secret)
    end)

    it("preserves both enabled=false and secret=false simultaneously", function()
        local existing = { name = "X-Test", value = "v", domains = {}, enabled = false, secret = false }
        local _, _, _, enabled, secret = editor_internal.coerce_defaults(existing)
        assert.is_false(enabled)
        assert.is_false(secret)
    end)

    it("preserves enabled=true and secret=true (smoke test)", function()
        local existing = { name = "X-Test", value = "v", domains = {}, enabled = true, secret = true }
        local _, _, _, enabled, secret = editor_internal.coerce_defaults(existing)
        assert.is_true(enabled)
        assert.is_true(secret)
    end)

    it("returns safe defaults when creating a new rule (existing=nil)", function()
        local name, value, domains, enabled, secret = editor_internal.coerce_defaults(nil)
        assert.equals("", name)
        assert.equals("", value)
        assert.same({}, domains)
        assert.is_true(enabled)
        assert.is_true(secret)
    end)
end)
