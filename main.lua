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
local header_rules = require("lib.header_rules")
local hooks = require("hooks")
local log = require("lib.log")
local menu = require("ui.menu")

local CloudflareAccess = WidgetContainer:extend{
    name = "cloudflareaccess",
    is_doc_only = false,
}

function CloudflareAccess:init()
    config.migrate()
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

    -- One-time warning if any custom rule has no effective allowlist
    local custom_headers = config.getCustomHeaders()
    local global_domains = config.getDomains()
    local has_unsafe_custom = false
    for _, rule in ipairs(custom_headers) do
        if rule.enabled then
            local eff = header_rules.effective_domains(rule, global_domains)
            if #eff == 0 then
                has_unsafe_custom = true
                break
            end
        end
    end
    if has_unsafe_custom
       and not config.hasAcknowledgedEmptyAllowlistCustomWarning() then
        UIManager:nextTick(function()
            UIManager:show(ConfirmBox:new{
                text = _([[
One or more custom header rules will be sent to every host.
This risks leaking header values to third-party services.

Add per-rule domains or a global allowlist entry to restrict
header injection.]]),

                ok_text = _("I understand"),
                cancel_text = _("Dismiss"),
                ok_callback = function()
                    config.acknowledgeEmptyAllowlistCustomWarning()
                end,
                cancel_callback = function()
                    config.acknowledgeEmptyAllowlistCustomWarning()
                end,
            })
        end)
    end
end

function CloudflareAccess:addToMainMenu(menu_items)
    menu.addToMainMenu(self, menu_items)
end

return CloudflareAccess
