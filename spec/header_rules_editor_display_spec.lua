local config = require("config")
local editor = require("ui.header_rules_editor")

describe("header_rules_editor._display_domains()", function()
    local function set_global_domains(t)
        config.setDomains(t)
    end

    it("shows 'inherits global (3)' when rule has empty domains and global has 3 entries", function()
        set_global_domains({ "example.com", "test.org", "foo.bar" })
        local rule = { domains = {} }
        assert.equals("inherits global (3)", editor._display_domains(rule))
    end)

    it("shows 'inherits global (1)' when rule has empty domains and global has 1 entry", function()
        set_global_domains({ "example.com" })
        local rule = { domains = {} }
        assert.equals("inherits global (1)", editor._display_domains(rule))
    end)

    it("shows 'all hosts' when rule has empty domains and global is empty", function()
        set_global_domains({})
        local rule = { domains = {} }
        assert.equals("all hosts", editor._display_domains(rule))
    end)

    it("returns the domain list when rule has its own domains", function()
        set_global_domains({ "global.example.com" })
        local rule = { domains = { "own.example.com", "other.test" } }
        assert.equals("own.example.com, other.test", editor._display_domains(rule))
    end)

    it("returns 'all hosts' when global returns nil (edge case)", function()
        _G._test_settings_data["domains"] = nil
        local rule = { domains = {} }
        assert.equals("all hosts", editor._display_domains(rule))
    end)
end)
