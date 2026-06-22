--[[-- Pure host-matching helpers for the Cloudflare Access allowlist.

These functions have no KOReader dependencies (only `socket.url` from LuaSocket,
which KOReader ships) so they can be unit-tested with busted in isolation.

@module koplugin.cloudflareaccess.lib.url_match
--]]

local socket_url = require("socket.url")

local M = {}

--- Extract and normalize the hostname from a URL.
-- Uses `socket.url.parse` to robustly separate the host from port, userinfo,
-- path and query. The result is lowercased. Returns nil for any input that
-- is not a string, is empty, or does not contain a parseable host.
-- @string input the URL to parse
-- @treturn string lowercased host, or nil
function M.get_host(input)
    if type(input) ~= "string" or input == "" then
        return nil
    end
    local parsed = socket_url.parse(input)
    if type(parsed) ~= "table" then
        return nil
    end
    local host = parsed.host
    if type(host) ~= "string" or host == "" then
        return nil
    end
    return host:lower()
end

--- Check whether a host is allowed by the allowlist.
--
-- Matching is case-insensitive and uses an exact-host or subdomain suffix
-- match (`"." .. apex`). A trailing dot (FQDN form) is stripped before
-- comparison. Substring and regex matching are never used.
--
-- **Empty allowlist:** when `domains` is empty (or nil) the function returns
-- `true` for every host. This is the documented unsafe-but-convenient
-- fallback — the caller is responsible for warning the user when this mode
-- is active.
--
-- @string host the hostname to check (already lowercased by `get_host`, but
--   this function lowercases again for safety)
-- @tparam table domains array of allowlist entries (apex domains)
-- @treturn boolean true if the host is allowed
function M.is_allowed(host, domains)
    if type(host) ~= "string" or host == "" then
        return false
    end
    host = host:lower()
    -- Normalize: strip a single trailing dot (FQDN form, e.g. "example.com.")
    if host:sub(-1) == "." then
        host = host:sub(1, -2)
    end
    -- Empty allowlist = match every host (documented unsafe fallback)
    if domains == nil or #domains == 0 then
        return true
    end
    for _, domain in ipairs(domains) do
        if type(domain) == "string" then
            domain = domain:lower()
            if domain:sub(-1) == "." then
                domain = domain:sub(1, -2)
            end
            -- Exact match
            if host == domain then
                return true
            end
            -- Subdomain match: host ends with ".domain"
            -- The leading dot prevents sibling-domain false positives
            -- (e.g. "evilwojtasord.com" must not match "wojtasord.com").
            if host:sub(-#domain - 1) == "." .. domain then
                return true
            end
        end
    end
    return false
end

return M
