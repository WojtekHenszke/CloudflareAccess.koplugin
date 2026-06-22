--[[-- Cloudflare Access plugin entrypoint.

Injects Cloudflare Access service-token headers into outgoing HTTP/HTTPS
requests, with a configurable hostname allowlist.

@module koplugin.cloudflareaccess
--]]

local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")

local config = require("config")
local hooks = require("hooks")
local log = require("lib.log")

local CloudflareAccess = WidgetContainer:extend{
    name = "cloudflareaccess",
    is_doc_only = false,
}

function CloudflareAccess:init()
    -- Configure logging from persisted settings
    log.setLevel(config.getLogLevel())
    log.setCapacity(config.getLogCapacity())

    -- Install HTTP/HTTPS hooks with a live config closure
    hooks.install(function()
        return config.getSnapshot()
    end)

    -- Register to main menu
    self.ui.menu:registerToMainMenu(self)
end

function CloudflareAccess:addToMainMenu(menu_items)
    -- Filled in by ui/menu.lua (Task 09)
end

return CloudflareAccess
