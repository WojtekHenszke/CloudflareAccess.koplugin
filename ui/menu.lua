--[[-- Main menu builder for Cloudflare Access.

@module koplugin.cloudflareaccess.ui.menu
--]]

local InputDialog = require("ui/widget/inputdialog")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local _ = require("gettext")
local T = require("ffi/util").template

local config = require("config")
local log = require("lib.log")

local M = {}

--- Mask a credential for display: first 4 + … + last 4 chars.
local function mask_credential(str)
    if not str or str == "" then
        return _("(not set)")
    end
    if #str <= 8 then
        return "****"
    end
    return str:sub(1, 4) .. "…" .. str:sub(-4)
end

--- Build and register the main menu items.
function M.addToMainMenu(plugin, menu_items)
    menu_items.cloudflare_access = {
        text_func = function()
            if config.isEnabled() and config.isAllowlistEmpty() then
                return "⚠ " .. _("Cloudflare Access")
            end
            return _("Cloudflare Access")
        end,
        sorting_hint = "network",
        sub_item_table = {
            -- Enabled toggle
            {
                text = _("Enabled"),
                checked_func = function()
                    return config.isEnabled()
                end,
                callback = function()
                    config.setEnabled(not config.isEnabled())
                end,
            },
            -- Client ID
            {
                text_func = function()
                    return T(_("Client ID: %1"), mask_credential(config.getClientId()))
                end,
                keep_menu_open = true,
                callback = function(touchmenu_instance)
                    local dialog
                    dialog = InputDialog:new{
                        title = _("Client ID"),
                        input = config.getClientId(),
                        input_hint = _("Paste your CF-Access-Client-Id"),
                        buttons = {
                            {
                                {
                                    text = _("Cancel"),
                                    id = "close",
                                    callback = function()
                                        UIManager:close(dialog)
                                    end,
                                },
                                {
                                    text = _("Save"),
                                    is_enter_default = true,
                                    callback = function()
                                        config.setClientId(dialog:getInputText())
                                        UIManager:close(dialog)
                                        touchmenu_instance:updateItems()
                                    end,
                                },
                            },
                        },
                    }
                    UIManager:show(dialog)
                    dialog:onShowKeyboard()
                end,
            },
            -- Client Secret
            {
                text_func = function()
                    if config.getClientSecret() == "" then
                        return T(_("Client Secret: %1"), _("(not set)"))
                    end
                    return _("Client Secret: ********")
                end,
                keep_menu_open = true,
                callback = function(touchmenu_instance)
                    local dialog
                    dialog = InputDialog:new{
                        title = _("Client Secret"),
                        input = "",
                        input_hint = _("Paste your CF-Access-Client-Secret"),
                        text_type = "password",
                        buttons = {
                            {
                                {
                                    text = _("Cancel"),
                                    id = "close",
                                    callback = function()
                                        UIManager:close(dialog)
                                    end,
                                },
                                {
                                    text = _("Save"),
                                    is_enter_default = true,
                                    callback = function()
                                        config.setClientSecret(dialog:getInputText())
                                        UIManager:close(dialog)
                                        touchmenu_instance:updateItems()
                                    end,
                                },
                            },
                        },
                    }
                    UIManager:show(dialog)
                    dialog:onShowKeyboard()
                end,
            },
            -- Allowlist status + domain editor
            {
                text_func = function()
                    local count = #config.getDomains()
                    if count == 0 then
                        return _("⚠ Allowlist: empty (headers sent to every host)")
                    end
                    return T(_("Allowlist: %1 domain(s)"), count)
                end,
                sub_item_table_func = function()
                    return require("ui.domain_editor").buildSubMenu()
                end,
            },
            -- Log level submenu
            {
                text_func = function()
                    local level = config.getLogLevel()
                    local display = level:sub(1, 1):upper() .. level:sub(2)
                    return T(_("Log level: %1"), display)
                end,
                sub_item_table = {
                    {
                        text = _("Off"),
                        checked_func = function()
                            return config.getLogLevel() == "off"
                        end,
                        callback = function()
                            config.setLogLevel("off")
                            log.setLevel("off")
                        end,
                    },
                    {
                        text = _("Warn"),
                        checked_func = function()
                            return config.getLogLevel() == "warn"
                        end,
                        callback = function()
                            config.setLogLevel("warn")
                            log.setLevel("warn")
                        end,
                    },
                    {
                        text = _("Info"),
                        checked_func = function()
                            return config.getLogLevel() == "info"
                        end,
                        callback = function()
                            config.setLogLevel("info")
                            log.setLevel("info")
                        end,
                    },
                    {
                        text = _("Debug"),
                        checked_func = function()
                            return config.getLogLevel() == "dbg"
                        end,
                        callback = function()
                            config.setLogLevel("dbg")
                            log.setLevel("dbg")
                        end,
                    },
                    {
                        text = _("Debug is verbose; use only while reproducing an issue."),
                        enabled_func = function() return false end,
                    },
                },
            },
            -- View logs
            {
                text = _("View logs"),
                keep_menu_open = true,
                callback = function()
                    local log_viewer = require("ui.log_viewer")
                    log_viewer.show()
                end,
            },
            -- Test connection (stub)
            {
                text = _("Test connection"),
                keep_menu_open = true,
                callback = function()
                    UIManager:show(InfoMessage:new{
                        text = _("Not implemented yet"),
                    })
                end,
            },
            -- About
            {
                text = _("About"),
                callback = function()
                    UIManager:show(InfoMessage:new{
                        text = _([[
Cloudflare Access v0.1.0

Injects Cloudflare Access service-token headers into outgoing HTTP/HTTPS requests.]]),
                    })
                end,
                separator = true,
            },
        },
    }
end

return M
