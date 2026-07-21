local config = require("config")
local header_rules_editor = require("ui.header_rules_editor")

local function reset_settings()
    config._reset_for_test()
    for k in pairs(_G._test_settings_data) do
        _G._test_settings_data[k] = nil
    end
end

local function make_rule()
    return { name = "X-Test", value = "test-val", domains = { "example.com" }, enabled = true, secret = true }
end

describe("header_rules_editor buildSubMenu", function()
    before_each(function()
        reset_settings()
    end)

    it("reflects enabled toggle in text_func without rebuilding submenu", function()
        config.addCustomHeader(make_rule())
        local items = header_rules_editor.buildSubMenu()

        local first = items[1]
        assert.truthy(first.text_func)

        local t = first.text_func()
        assert.truthy(t:match("●"))

        config.setCustomHeaderEnabled(1, false)
        t = first.text_func()
        assert.truthy(t:match("○"))

        config.setCustomHeaderEnabled(1, true)
        t = first.text_func()
        assert.truthy(t:match("●"))
    end)

    it("reflects disabled marker when rule created as disabled", function()
        local rule = make_rule()
        rule.enabled = false
        config.addCustomHeader(rule)
        local items = header_rules_editor.buildSubMenu()

        local t = items[1].text_func()
        assert.truthy(t:match("○"))
    end)
end)
