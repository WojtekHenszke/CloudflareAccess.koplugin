-- SPDX-License-Identifier: MIT
--[[-- Custom header rules editor.

Builds a dynamic submenu for managing user-defined HTTP header rules.
Each rule is a submenu (Edit, Toggle enabled, Delete). An "Add rule"
entry opens a multi-field edit dialog.

@module koplugin.cloudflareaccess.ui.header_rules_editor
--]]

local ConfirmBox = require("ui/widget/confirmbox")
local InfoMessage = require("ui/widget/infomessage")
local MultiInputDialog = require("ui/widget/multiinputdialog")
local UIManager = require("ui/uimanager")
local _ = require("gettext")
local T = require("ffi/util").template

local config = require("config")
local editor_internal = require("lib.editor_internal")
local header_rules = require("lib.header_rules")

local M = {}

--- Format a rule's value for display in the list.
-- Masks the value if secret=true, shows it plain otherwise.
-- @tparam table rule the header rule
-- @treturn string display value
local function display_value(rule)
    if rule.secret then
        return header_rules.mask_preview(rule.value)
    end
    return rule.value
end

--- Format a rule's domains for display.
-- @tparam table rule the header rule
-- @treturn string domains summary
local function display_domains(rule)
    if #rule.domains == 0 then
        local global = config.getDomains()
        if #global == 0 then
            return _("all hosts")
        end
        return _("inherits allowlist")
    end
    return table.concat(rule.domains, ", ")
end

--- Build the submenu items for a single rule.
-- @int index 1-based index
-- @treturn table array of menu items
local function build_rule_submenu(index)
    return {
        {
            text = _("Edit"),
            keep_menu_open = true,
            callback = function(touchmenu_instance)
                M.editRule(touchmenu_instance, index)
            end,
        },
        {
            text = _("Enabled"),
            checked_func = function()
                local rule = config.getCustomHeader(index)
                return rule and rule.enabled or false
            end,
            callback = function()
                local rule = config.getCustomHeader(index)
                if rule then
                    config.setCustomHeaderEnabled(index, not rule.enabled)
                end
            end,
        },
        {
            text = _("Secret value"),
            checked_func = function()
                local rule = config.getCustomHeader(index)
                return rule and rule.secret or false
            end,
            callback = function()
                local rule = config.getCustomHeader(index)
                if rule then
                    rule.secret = not rule.secret
                    config.updateCustomHeader(index, rule)
                end
            end,
        },
        {
            text = _("Delete"),
            hold_callback = function(touchmenu_instance)
                local rule = config.getCustomHeader(index)
                if not rule then return end
                UIManager:show(ConfirmBox:new{
                    text = T(_("Delete rule '%1'?"), rule.name),
                    ok_text = _("Delete"),
                    ok_callback = function()
                        config.removeCustomHeader(index)
                        touchmenu_instance:closeMenu()
                    end,
                })
            end,
        },
    }
end

--- Build the submenu items for the header rules editor.
-- Called dynamically by the menu system via sub_item_table_func.
-- @treturn table array of menu items
function M.buildSubMenu()
    local headers = config.getCustomHeaders()
    local items = {}

    for i, rule in ipairs(headers) do
        local enabled_mark = rule.enabled and "●" or "○"
        items[#items + 1] = {
            text_func = function()
                return T("%1 %2: %3 (%4)",
                    enabled_mark, rule.name, display_value(rule), display_domains(rule))
            end,
            enabled_func = function() return true end,
            sub_item_table_func = function()
                return build_rule_submenu(i)
            end,
        }
    end

    if #headers == 0 then
        items[#items + 1] = {
            text = _("No custom header rules configured."),
            enabled_func = function() return false end,
            separator = true,
        }
    end

    items[#items + 1] = {
        text = _("Add rule"),
        keep_menu_open = true,
        callback = function(touchmenu_instance)
            M.editRule(touchmenu_instance, nil)
        end,
    }

    return items
end

--- Parse a comma-separated domains string into an array.
-- @string s comma-separated domain list
-- @treturn table array of trimmed domain strings
local function parse_domains(s)
    local domains = {}
    if not s or s == "" then
        return domains
    end
    for part in s:gmatch("[^,]+") do
        part = part:match("^%s*(.-)%s*$")
        if part ~= "" then
            domains[#domains + 1] = part:lower()
        end
    end
    return domains
end

--- Edit or create a rule.
-- Opens a MultiInputDialog with fields for header name, value, and domains.
-- Enabled and secret flags are preserved on edit, defaulted on create.
-- @param touchmenu_instance the TouchMenu instance for refreshing
-- @param index 1-based index for editing, nil for creating new
function M.editRule(touchmenu_instance, index)
    local is_new = index == nil
    local existing
    if not is_new then
        existing = config.getCustomHeader(index)
        if not existing then return end
    end

    local name, value, domains, enabled, secret = editor_internal.coerce_defaults(existing)
    local domains_str = table.concat(domains, ", ")

    local dialog
    dialog = MultiInputDialog:new{
        title = is_new and _("Add custom header rule") or _("Edit custom header rule"),
        fields = {
            {
                text = name,
                input_type = "string",
                hint = _("Header name (e.g. X-Api-Key)"),
            },
            {
                text = value,
                input_type = "string",
                hint = _("Header value"),
                text_type = secret and "password" or nil,
            },
            {
                text = domains_str,
                input_type = "string",
                hint = _("Domains (comma-separated, empty = inherit allowlist)"),
            },
        },
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
                        local fields = dialog:getFields()
                        local rule = {
                            name = fields[1],
                            value = fields[2],
                            domains = parse_domains(fields[3]),
                            enabled = enabled,
                            secret = secret,
                        }

                        local ok, err = header_rules.validate_rule(rule)
                        if not ok then
                            UIManager:show(InfoMessage:new{
                                text = err,
                                timeout = 3,
                            })
                            return
                        end

                        if is_new then
                            config.addCustomHeader(rule)
                        else
                            config.updateCustomHeader(index, rule)
                        end
                        UIManager:close(dialog)
                        if touchmenu_instance then
                            touchmenu_instance:updateItems()
                        end
                    end,
                },
            },
        },
    }
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end

return M
