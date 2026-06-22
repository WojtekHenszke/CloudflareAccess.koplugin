--[[-- Test connection diagnostic.

Performs an actual GET request via socket.http/ssl.https (our own hooks
inject the CF Access headers if the host matches the allowlist) and shows
the HTTP status, cf-ray, redirect location, injected header names, and
contextual hints.

@module koplugin.cloudflareaccess.ui.test_connection
--]]

local InputDialog = require("ui/widget/inputdialog")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local _ = require("gettext")
local T = require("ffi/util").template

local config = require("config")
local header_rules = require("lib.header_rules")
local log = require("lib.log")
local url_match = require("lib/url_match")

local M = {}

--- Compute which headers would be injected for a given host.
-- Returns header names only (never values) for display.
-- @string host the hostname to check
-- @treturn table array of {source, name} pairs
local function compute_injected_headers(host)
    local snap = config.getSnapshot()
    local domains = snap.domains or {}
    local injected = {}

    -- CF Access headers
    if snap.enabled
       and snap.client_id and snap.client_id ~= ""
       and snap.client_secret and snap.client_secret ~= ""
       and url_match.is_allowed(host, domains) then
        table.insert(injected, { source = "CF Access", name = "CF-Access-Client-Id" })
        table.insert(injected, { source = "CF Access", name = "CF-Access-Client-Secret" })
    end

    -- Custom header rules
    if type(snap.custom_headers) == "table" then
        for _, rule in ipairs(snap.custom_headers) do
            if rule.enabled and header_rules.applies(rule, host, domains) then
                table.insert(injected, { source = "custom", name = rule.name })
            end
        end
    end

    return injected
end

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

    -- Show which headers were injected (names only, never values)
    local host = url_match.get_host(url)
    local injected = compute_injected_headers(host)
    if #injected > 0 then
        table.insert(lines, "")
        table.insert(lines, _("Injected headers:"))
        for _, h in ipairs(injected) do
            table.insert(lines, T("  %1: %2", h.source, h.name))
        end
    else
        table.insert(lines, "")
        table.insert(lines, _("No headers injected (host not in allowlist or no rules match)."))
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
