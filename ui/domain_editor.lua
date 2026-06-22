--[[-- Allowed-domains editor.

Builds a dynamic submenu for managing the hostname allowlist. Each domain
is a deletable item; an "Add domain" entry opens an InputDialog with
validation (no scheme, no path, no spaces).

@module koplugin.cloudflareaccess.ui.domain_editor
--]]

local ConfirmBox = require("ui/widget/confirmbox")
local InputDialog = require("ui/widget/inputdialog")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local _ = require("gettext")
local T = require("ffi/util").template

local config = require("config")

local M = {}

--- Validate a domain string.
-- Rejects schemes (://), paths (/), spaces, userinfo (@), and empty input.
-- @string input the domain to validate
-- @treturn boolean true if valid
-- @treturn string error message if invalid
local function validate_domain(input)
    if not input or input == "" then
        return false, _("Domain cannot be empty.")
    end
    if input:find("://") then
        return false, _("Do not include the scheme (http://). Enter the domain only.")
    end
    if input:find("/") then
        return false, _("Do not include a path. Enter the domain only.")
    end
    if input:find("@") then
        return false, _("Do not include userinfo. Enter the domain only.")
    end
    if input:find("%s") then
        return false, _("Domain must not contain spaces.")
    end
    return true
end

--- Build the submenu items for the allowlist editor.
-- Called dynamically by the menu system via sub_item_table_func.
-- @treturn table array of menu items
function M.buildSubMenu()
    local domains = config.getDomains()
    local items = {}

    for _, domain in ipairs(domains) do
        items[#items + 1] = {
            text = domain,
            hold_callback = function(touchmenu_instance)
                UIManager:show(ConfirmBox:new{
                    text = T(_("Remove '%1' from the allowlist?"), domain),
                    ok_text = _("Remove"),
                    ok_callback = function()
                        config.removeDomain(domain)
                        touchmenu_instance:updateItems()
                    end,
                })
            end,
        }
    end

    if #domains == 0 then
        items[#items + 1] = {
            text = _("No domains in allowlist. Headers will be sent to every host."),
            enabled_func = function() return false end,
            separator = true,
        }
    end

    items[#items + 1] = {
        text = _("Add domain"),
        keep_menu_open = true,
        callback = function(touchmenu_instance)
            local dialog
            dialog = InputDialog:new{
                title = _("Add allowed domain"),
                input = "",
                input_hint = _("e.g. example.com"),
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
                            text = _("Add"),
                            is_enter_default = true,
                            callback = function()
                                local input = dialog:getInputText():lower()
                                local ok, err = validate_domain(input)
                                if not ok then
                                    UIManager:show(InfoMessage:new{
                                        text = err,
                                        timeout = 3,
                                    })
                                    return
                                end
                                config.addDomain(input)
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
    }

    return items
end

--- Show a message directing the user to the menu.
-- Used by the empty-allowlist warning's "Open allowlist editor" button,
-- since opening a specific submenu programmatically is not straightforward.
function M.show()
    UIManager:show(InfoMessage:new{
        text = _([[Open Cloudflare Access > Allowlist to manage domains.]]),
    })
end

return M
