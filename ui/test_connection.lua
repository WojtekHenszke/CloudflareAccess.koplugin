--[[-- Test connection diagnostic.

Performs an actual GET request via socket.http/ssl.https (our own hooks
inject the CF Access headers if the host matches the allowlist) and shows
the HTTP status, cf-ray, redirect location, and contextual hints.

@module koplugin.cloudflareaccess.ui.test_connection
--]]

local InputDialog = require("ui/widget/inputdialog")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local _ = require("gettext")
local T = require("ffi/util").template

local config = require("config")
local log = require("lib.log")

local M = {}

--- Perform a GET request and return a human-readable result string.
-- @string url the URL to probe
-- @treturn string result message
local function probe(url)
    local scheme = url:match("^(https?)://")
    local http
    if scheme == "https" then
        http = require("ssl.https")
    else
        http = require("socket.http")
    end

    -- Our hooks are installed on these modules, so headers are injected
    -- automatically if the host matches the allowlist.
    local body, code, headers = http.request(url)

    if body == nil then
        -- LuaSocket returns (nil, err) on failure
        return T(_("Request failed: %1"), tostring(code))
    end

    local status = tostring(code)
    local cf_ray = type(headers) == "table"
        and (headers["cf-ray"] or headers["CF-Ray"])
    local location = type(headers) == "table"
        and (headers["location"] or headers["Location"])

    local lines = {}
    table.insert(lines, T(_("HTTP status: %1"), status))

    if cf_ray then
        table.insert(lines, T(_("CF-Ray: %1"), cf_ray))
    end

    if location then
        table.insert(lines, T(_("Redirect: %1"), location))
    end

    -- Contextual hints
    if code == 302 and location and location:find("cloudflareaccess%.com") then
        table.insert(lines, "")
        table.insert(lines, _("Hint: redirect to cloudflareaccess.com means "
            .. "CF Access authentication failed. Check your client ID and secret."))
    elseif code == 401 then
        table.insert(lines, "")
        table.insert(lines, _("Hint: 401 means CF Access passed but the app "
            .. "behind it requires its own authentication (e.g. Calibre-Web login)."))
    elseif code == 200 then
        table.insert(lines, "")
        table.insert(lines, _("Success: the request went through."))
    end

    return table.concat(lines, "\n")
end

--- Show the test connection dialog.
function M.show()
    local domains = config.getDomains()
    local default_url = "https://"
    if #domains > 0 then
        default_url = "https://" .. domains[1]
    end

    local dialog
    dialog = InputDialog:new{
        title = _("Test connection"),
        input = default_url,
        input_hint = _("https://example.com"),
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
                    text = _("Test"),
                    is_enter_default = true,
                    callback = function()
                        local url = dialog:getInputText()
                        UIManager:close(dialog)
                        log.info("test connection: %s", url)
                        local result = probe(url)
                        UIManager:show(InfoMessage:new{
                            text = result,
                        })
                    end,
                },
            },
        },
    }
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end

return M
