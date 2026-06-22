--[[-- Persistent settings wrapper for Cloudflare Access.

Wraps `LuaSettings` with typed getters/setters and sensible defaults.
Settings are stored in `DataStorage:getSettingsDir() .. "/cloudflareaccess.lua"`.

@module koplugin.cloudflareaccess.config
--]]

local DataStorage = require("datastorage")
local LuaSettings = require("luasettings")

local M = {}

local SCHEMA_VERSION = 1
local SETTINGS_FILE = DataStorage:getSettingsDir() .. "/cloudflareaccess.lua"
local LOG_CAPACITY = 200

local VALID_LOG_LEVELS = {
    off = true,
    warn = true,
    info = true,
    dbg = true,
}

local settings

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

--- Run schema migration (no-op for v1).
function M.migrate()
    local current = get_settings():readSetting("schema", 0)
    if current < SCHEMA_VERSION then
        -- Future migrations go here.
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
    get_settings():saveSetting("domains", table or {})
    save()
end

function M.addDomain(str)
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
-- Snapshot (for hooks get_config closure)
----------------------------------------------------------------------

--- Return a snapshot of the current config as a plain table.
-- Used by the hooks `get_config` closure so wrappers read live values.
-- @treturn table {enabled, client_id, client_secret, domains}
function M.getSnapshot()
    return {
        enabled = M.isEnabled(),
        client_id = M.getClientId(),
        client_secret = M.getClientSecret(),
        domains = M.getDomains(),
    }
end

return M
