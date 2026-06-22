--[[-- Monkey-patch `socket.http` and `ssl.https` to inject CF Access headers.

Installs wrappers around `socket.http.request` and `ssl.https.request` that
inject `CF-Access-Client-Id` / `CF-Access-Client-Secret` headers for
allowlisted hosts. The wrappers read configuration on every call so that
toggling enable/disable, editing credentials, or changing the allowlist takes
effect immediately without a restart.

When disabled or credentials are empty, the wrappers are a perfect no-op:
arguments and return values pass through unchanged.

@module koplugin.cloudflareaccess.hooks
--]]

local log = require("lib.log")
local url_match = require("lib.url_match")

local M = {}

local installed = false
local orig_http_request
local orig_https_request

--- Check whether a CF Access header is already present (case-insensitive).
-- @tparam table headers the request headers table
-- @string canonical the canonical header name (e.g. "CF-Access-Client-Id")
-- @treturn boolean true if the header is already set
local function has_header(headers, canonical)
    if type(headers) ~= "table" then
        return false
    end
    return headers[canonical] ~= nil
        or headers[canonical:lower()] ~= nil
end

--- Inject CF Access headers into a table-form request if needed.
-- Never overwrites headers the caller already set.
local function inject_headers(req, client_id, client_secret)
    req.headers = req.headers or {}
    if not has_header(req.headers, "CF-Access-Client-Id") then
        req.headers["CF-Access-Client-Id"] = client_id
    end
    if not has_header(req.headers, "CF-Access-Client-Secret") then
        req.headers["CF-Access-Client-Secret"] = client_secret
    end
end

--- Log the response status and cf-ray if present.
local function log_response(host, path, code, headers)
    local cf_ray = type(headers) == "table" and headers["cf-ray"]
        or type(headers) == "table" and headers["CF-Ray"]
    if cf_ray then
        log.dbg("host=%s path=%s status=%s cf-ray=%s", host, path, code, cf_ray)
    else
        log.dbg("host=%s path=%s status=%s", host, path, code)
    end
end

--- Create a wrapper around an original request function.
-- @func orig the original `socket.http.request` or `ssl.https.request`
-- @func get_config closure returning the current config table
local function wrap(orig, get_config)
    return function(req, body)
        local config = get_config()

        -- Perfect no-op when disabled or credentials are empty
        if not config.enabled
           or config.client_id == nil or config.client_id == ""
           or config.client_secret == nil or config.client_secret == "" then
            return orig(req, body)
        end

        local domains = config.domains or {}

        if type(req) == "table" then
            local host = url_match.get_host(req.url)
            local path = "/"
            local parsed = require("socket.url").parse(req.url or "")
            if parsed and parsed.path and parsed.path ~= "" then
                path = parsed.path
            end
            if url_match.is_allowed(host, domains) then
                inject_headers(req, config.client_id, config.client_secret)
                log.dbg("injected for host=%s path=%s", host, path)
                local ok, code, headers = orig(req, body)
                log_response(host, path, code, headers)
                return ok, code, headers
            else
                log.dbg("skip host=%s (not in allowlist)", host or "(no host)")
                return orig(req, body)
            end
        elseif type(req) == "string" then
            local host = url_match.get_host(req)
            if url_match.is_allowed(host, domains) then
                local parsed = require("socket.url").parse(req)
                local path = (parsed and parsed.path and parsed.path ~= "")
                    and parsed.path or "/"
                -- Promote string form to table form so we can attach headers
                local ltn12 = require("ltn12")
                local sink_t = {}
                local t = {
                    url = req,
                    sink = ltn12.sink.table(sink_t),
                    headers = {},
                }
                inject_headers(t, config.client_id, config.client_secret)
                log.dbg("injected for host=%s path=%s (string form)", host, path)
                local ok, code, headers = orig(t)
                log_response(host, path, code, headers)
                if ok == nil then
                    return nil, code, headers
                end
                return table.concat(sink_t), code, headers
            else
                log.dbg("skip host=%s (not in allowlist)", host or "(no host)")
                return orig(req, body)
            end
        end
        return orig(req, body)
    end
end

--- Install the HTTP/HTTPS hooks.
-- @func get_config closure returning the current config table with fields:
--   enabled (bool), client_id (string), client_secret (string),
--   domains (table/array of strings)
function M.install(get_config)
    if installed then
        return
    end

    local http_module = package.loaded["socket.http"] or require("socket.http")
    local https_module = package.loaded["ssl.https"] or require("ssl.https")

    orig_http_request = http_module.request
    orig_https_request = https_module.request

    http_module.request = wrap(orig_http_request, get_config)
    https_module.request = wrap(orig_https_request, get_config)

    installed = true
    log.info("hooks installed")

    -- One-time warning if enabled with an empty allowlist
    local config = get_config()
    if config.enabled and #config.domains == 0 then
        log.warn("hooks installed with empty allowlist — headers will be sent to every host")
    end
end

--- Check whether hooks are currently installed.
-- @treturn boolean
function M.is_installed()
    return installed
end

return M
