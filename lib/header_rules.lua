-- SPDX-License-Identifier: MIT
--[[-- Pure helpers for custom header rule validation and matching.

These functions have no KOReader dependencies (only `lib/url_match` for
host matching) so they can be unit-tested with busted in isolation.

@module koplugin.cloudflareaccess.lib.header_rules
--]]

local url_match = require("lib.url_match")

local M = {}

--- RFC 7230 token grammar: one or more of the following characters.
-- `token = 1*tchar`
-- `tchar = "!" / "#" / "$" / "%" / "&" / "'" / "*" / "+" / "-" / "." / "^" / "_" / "`" / "|" / "~" / DIGIT / ALPHA`
local HEADER_NAME_PATTERN = "^[A-Za-z0-9!#$%%&'*+%-%.^_`|~]+$"

--- Maximum header value length (defense against accidental huge input).
local MAX_VALUE_LENGTH = 4096

--- Threshold below which mask_preview returns the full string (too short to mask).
local MASK_MIN_LENGTH = 8

--- Validate a header name against RFC 7230 token grammar.
-- @string s the header name
-- @treturn boolean true if valid
-- @treturn string error message if invalid
function M.validate_name(s)
    if type(s) ~= "string" or s == "" then
        return false, "Header name cannot be empty."
    end
    if not s:match(HEADER_NAME_PATTERN) then
        return false, "Header name contains invalid characters."
    end
    return true
end

--- Validate a header value.
-- Disallows CR and LF (CRLF injection prevention). Enforces a length cap.
-- @string s the header value
-- @treturn boolean true if valid
-- @treturn string error message if invalid
function M.validate_value(s)
    if type(s) ~= "string" then
        return false, "Header value must be a string."
    end
    if s:find("[\r\n]") then
        return false, "Header value must not contain line breaks."
    end
    if #s > MAX_VALUE_LENGTH then
        return false, "Header value is too long (max " .. MAX_VALUE_LENGTH .. " characters)."
    end
    return true
end

--- Validate the full shape and content of a custom header rule.
-- Composes validate_name, validate_value, and checks domains is an array of strings.
-- @tparam table rule {name, value, domains, enabled, secret}
-- @treturn boolean true if valid
-- @treturn string error message if invalid
function M.validate_rule(rule)
    if type(rule) ~= "table" then
        return false, "Rule must be a table."
    end
    local ok, err = M.validate_name(rule.name)
    if not ok then return false, err end
    ok, err = M.validate_value(rule.value)
    if not ok then return false, err end
    if type(rule.domains) ~= "table" then
        return false, "Domains must be an array."
    end
    for _, d in ipairs(rule.domains) do
        if type(d) ~= "string" then
            return false, "Each domain must be a string."
        end
    end
    if type(rule.enabled) ~= "boolean" then
        return false, "Enabled must be a boolean."
    end
    if type(rule.secret) ~= "boolean" then
        return false, "Secret must be a boolean."
    end
    return true
end

--- Compute the effective domains for a rule.
-- If the rule has its own non-empty domains list, use that.
-- Otherwise, fall back to the global allowlist.
-- @tparam table rule the header rule
-- @tparam table global_domains the global CF Access allowlist
-- @treturn table the effective domains array
function M.effective_domains(rule, global_domains)
    if rule.domains and #rule.domains > 0 then
        return rule.domains
    end
    return global_domains or {}
end

--- Check whether a rule applies to a given host.
-- Uses url_match.is_allowed against the effective domains.
-- @tparam table rule the header rule
-- @string host the hostname to check
-- @tparam table global_domains the global CF Access allowlist
-- @treturn boolean true if the rule applies
function M.applies(rule, host, global_domains)
    local domains = M.effective_domains(rule, global_domains)
    return url_match.is_allowed(host, domains)
end

--- Mask a secret value for UI preview display.
-- Returns "abcd…wxyz" for longer strings, or the full string if too short.
-- @string s the value to mask
-- @treturn string masked preview
function M.mask_preview(s)
    if type(s) ~= "string" or s == "" then
        return ""
    end
    if #s <= MASK_MIN_LENGTH then
        return "****"
    end
    return s:sub(1, 4) .. "…" .. s:sub(-4)
end

--- Redact a secret value for log output.
-- Always returns a constant placeholder — never the value.
-- @string s the value to redact (ignored)
-- @treturn string the constant "<redacted>" placeholder
function M.redact_for_log(_s)
    return "<redacted>"
end

return M
