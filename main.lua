--[[-- Cloudflare Access plugin entrypoint.

Injects Cloudflare Access service-token headers into outgoing HTTP/HTTPS
requests, with a configurable hostname allowlist.

@module koplugin.cloudflareaccess
--]]

local ConfirmBox = require("ui/widget/confirmbox")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")

local config = require("config")
local hooks = require("hooks")
local log = require("lib.log")
local menu = require("ui.menu")

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

    -- One-time warning if enabled with an empty allowlist
    if config.isEnabled()
       and config.isAllowlistEmpty()
       and not config.hasAcknowledgedEmptyAllowlistWarning() then
        UIManager:nextTick(function()
            UIManager:show(ConfirmBox:new{
                text = _([[
The allowlist is empty. Cloudflare Access headers will be sent to
EVERY host, including third-party services (GitHub updates, news
feeds, dictionary lookups, etc.).

This risks leaking your service token. Add at least one allowed
domain to restrict header injection.]]),

                ok_text = _("I understand"),
                cancel_text = _("Open allowlist editor"),
                ok_callback = function()
                    config.acknowledgeEmptyAllowlistWarning()
                end,
                cancel_callback = function()
                    config.acknowledgeEmptyAllowlistWarning()
                    require("ui.domain_editor").show()
                end,
            })
        end)
    end
end

function CloudflareAccess:addToMainMenu(menu_items)
    menu.addToMainMenu(self, menu_items)
end

return CloudflareAccess
