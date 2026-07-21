--[[-- Persistent settings wrapper for Cloudflare Access.

Wraps `LuaSettings` with typed getters/setters and sensible defaults.
Settings are stored in `DataStorage:getSettingsDir() .. "/cloudflareaccess.lua"`.

@module koplugin.cloudflareaccess.config
--]]

local DataStorage = require("datastorage")
local LuaSettings = require("luasettings")

local M = {}

local SCHEMA_VERSION = 2
local SETTINGS_FILE = DataStorage:getSettingsDir() .. "/cloudflareaccess.lua"
local LOG_CAPACITY = 200

local VALID_LOG_LEVELS = {
    off = true,
    warn = true,
    info = true,
    dbg = true,
}

local settings

--- Deep copy a table (for defensive copies of persisted data).
local function deep_copy(t)
    if type(t) ~= "table" then return t end
    local copy = {}
    for k, v in pairs(t) do
        copy[k] = deep_copy(v)
    end
    return copy
end

--- Validate the shape of a custom header rule (basic type checks).
-- Detailed content validation (RFC 7230, CRLF) lives in lib/header_rules.lua.
local function validate_rule_shape(rule)
    if type(rule) ~= "table" then return false end
    if type(rule.name) ~= "string" then return false end
    if type(rule.value) ~= "string" then return false end
    if type(rule.domains) ~= "table" then return false end
    if type(rule.enabled) ~= "boolean" then return false end
    if type(rule.secret) ~= "boolean" then return false end
    for _, d in ipairs(rule.domains) do
        if type(d) ~= "string" then return false end
    end
    return true
end

--- Lazily open the settings file (once per session).
local function get_settings()
    if not settings then
        settings = LuaSettings:open(SETTINGS_FILE)
    end
    return settings
end

--- Save and flush to disk.
local function save()
    get_settings():flush()
end

----------------------------------------------------------------------
-- Schema / migration
----------------------------------------------------------------------

--- Run schema migration.
-- Idempotent: safe to run on any schema version, including v0.1.0 (schema=1).
function M.migrate()
    local current = get_settings():readSetting("schema", 0)
    if current < SCHEMA_VERSION then
        -- v2: add custom_headers if missing (non-destructive)
        if current < 2 then
            if not get_settings():has("custom_headers") then
                get_settings():saveSetting("custom_headers", {})
            end
        end
        get_settings():saveSetting("schema", SCHEMA_VERSION)
        save()
    end
end

----------------------------------------------------------------------
-- Enable / disable
----------------------------------------------------------------------

function M.isEnabled()
    return get_settings():isTrue("enabled")
end

function M.setEnabled(bool)
    get_settings():saveSetting("enabled", bool and true or false)
    save()
end

----------------------------------------------------------------------
-- Credentials
----------------------------------------------------------------------

function M.getClientId()
    return get_settings():readSetting("client_id", "") or ""
end

function M.setClientId(str)
    get_settings():saveSetting("client_id", str or "")
    save()
end

function M.getClientSecret()
    return get_settings():readSetting("client_secret", "") or ""
end

function M.setClientSecret(str)
    get_settings():saveSetting("client_secret", str or "")
    save()
end

----------------------------------------------------------------------
-- Domains (allowlist)
----------------------------------------------------------------------

function M.getDomains()
    return get_settings():readSetting("domains", {}) or {}
end

function M.setDomains(table)
    if type(table) ~= "table" then
        table = {}
    end
    get_settings():saveSetting("domains", table)
    save()
end

function M.addDomain(str)
    if type(str) ~= "string" or str == "" then
        return
    end
    local domains = M.getDomains()
    for _, d in ipairs(domains) do
        if d:lower() == str:lower() then
            return -- already present
        end
    end
    domains[#domains + 1] = str
    M.setDomains(domains)
end

function M.removeDomain(str)
    if type(str) ~= "string" or str == "" then
        return
    end
    local domains = M.getDomains()
    local new_domains = {}
    for _, d in ipairs(domains) do
        if d:lower() ~= str:lower() then
            new_domains[#new_domains + 1] = d
        end
    end
    M.setDomains(new_domains)
end

function M.isAllowlistEmpty()
    local domains = M.getDomains()
    return #domains == 0
end

----------------------------------------------------------------------
-- Empty-allowlist warning acknowledgement
----------------------------------------------------------------------

function M.hasAcknowledgedEmptyAllowlistWarning()
    return get_settings():isTrue("warned_empty_allowlist")
end

function M.acknowledgeEmptyAllowlistWarning()
    get_settings():saveSetting("warned_empty_allowlist", true)
    save()
end

----------------------------------------------------------------------
-- Custom-headers empty-allowlist warning acknowledgement
----------------------------------------------------------------------

function M.hasAcknowledgedEmptyAllowlistCustomWarning()
    return get_settings():isTrue("warned_empty_allowlist_custom")
end

function M.acknowledgeEmptyAllowlistCustomWarning()
    get_settings():saveSetting("warned_empty_allowlist_custom", true)
    save()
end

----------------------------------------------------------------------
-- Log level
----------------------------------------------------------------------

function M.getLogLevel()
    local level = get_settings():readSetting("log_level", "warn")
    if VALID_LOG_LEVELS[level] then
        return level
    end
    return "warn"
end

function M.setLogLevel(str)
    if type(str) ~= "string" then return false end
    if VALID_LOG_LEVELS[str] then
        get_settings():saveSetting("log_level", str)
        save()
        return true
    end
    return false
end

function M.getLogCapacity()
    return LOG_CAPACITY
end

----------------------------------------------------------------------
-- Custom headers
----------------------------------------------------------------------

--- Return a deep copy of all custom header rules.
-- Mutating the returned table does not affect persisted state.
-- @treturn table array of rule tables
function M.getCustomHeaders()
    local headers = get_settings():readSetting("custom_headers", {})
    return deep_copy(headers)
end

--- Replace all custom header rules (with shape validation).
-- @tparam table list array of rule tables
-- @treturn boolean true on success
function M.setCustomHeaders(list)
    if type(list) ~= "table" then return false end
    for _, rule in ipairs(list) do
        if not validate_rule_shape(rule) then
            return false
        end
    end
    get_settings():saveSetting("custom_headers", deep_copy(list))
    save()
    return true
end

--- Get a single rule by index (deep copy).
-- @int index 1-based index
-- @treturn table rule, or nil if out of range
function M.getCustomHeader(index)
    local headers = get_settings():readSetting("custom_headers", {})
    if type(index) ~= "number" or index < 1 or index > #headers then
        return nil
    end
    return deep_copy(headers[index])
end

--- Append a new custom header rule.
-- @tparam table rule {name, value, domains, enabled, secret}
-- @treturn int new index, or nil on failure
-- @treturn string error message on failure
function M.addCustomHeader(rule)
    if not validate_rule_shape(rule) then
        return nil, "invalid rule shape"
    end
    local headers = get_settings():readSetting("custom_headers", {})
    headers[#headers + 1] = deep_copy(rule)
    get_settings():saveSetting("custom_headers", headers)
    save()
    return #headers
end

--- Update an existing rule by index.
-- @int index 1-based index
-- @tparam table rule replacement rule
-- @treturn boolean true on success
-- @treturn string error message on failure
function M.updateCustomHeader(index, rule)
    local headers = get_settings():readSetting("custom_headers", {})
    if type(index) ~= "number" or index < 1 or index > #headers then
        return false, "index out of range"
    end
    if not validate_rule_shape(rule) then
        return false, "invalid rule shape"
    end
    headers[index] = deep_copy(rule)
    get_settings():saveSetting("custom_headers", headers)
    save()
    return true
end

--- Remove a rule by index (preserves order of survivors).
-- @int index 1-based index
-- @treturn boolean true on success
function M.removeCustomHeader(index)
    local headers = get_settings():readSetting("custom_headers", {})
    if type(index) ~= "number" or index < 1 or index > #headers then
        return false
    end
    table.remove(headers, index)
    get_settings():saveSetting("custom_headers", headers)
    save()
    return true
end

--- Toggle the enabled flag on a single rule.
-- @int index 1-based index
-- @bool bool new enabled state
-- @treturn boolean true on success
function M.setCustomHeaderEnabled(index, bool)
    local headers = get_settings():readSetting("custom_headers", {})
    if type(index) ~= "number" or index < 1 or index > #headers then
        return false
    end
    headers[index].enabled = bool and true or false
    get_settings():saveSetting("custom_headers", headers)
    save()
    return true
end

----------------------------------------------------------------------
-- Snapshot (for hooks get_config closure)
----------------------------------------------------------------------

--- Return a snapshot of the current config as a plain table.
-- Used by the hooks `get_config` closure so wrappers read live values.
-- @treturn table {enabled, client_id, client_secret, domains, custom_headers}
function M.getSnapshot()
    return {
        enabled = M.isEnabled(),
        client_id = M.getClientId(),
        client_secret = M.getClientSecret(),
        domains = M.getDomains(),
        custom_headers = M.getCustomHeaders(),
    }
end

--- Reset cached settings (test-only).
function M._reset_for_test()
    settings = nil
end

return M
