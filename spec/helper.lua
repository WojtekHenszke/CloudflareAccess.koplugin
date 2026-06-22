-- Busted helper: stub KOReader modules that are unavailable outside the device.
-- Loaded automatically by busted via the .busted config (see .busted).

-- Stub logger: capture forwarded messages so specs can assert on them.
local log_calls = {}
package.preload["logger"] = function()
    return setmetatable({}, {
        __index = function(_, key)
            return function(...)
                table.insert(log_calls, { level = key, args = {...} })
            end
        end,
    })
end

-- Stub gettext: return the input string unchanged.
package.preload["gettext"] = function()
    return function(s) return s end
end

-- Stub datastorage: return a temp-like path.
package.preload["datastorage"] = function()
    return {
        getSettingsDir = function() return "/tmp/cfaccess_test/settings" end,
        getDataDir = function() return "/tmp/cfaccess_test" end,
    }
end

-- Stub luasettings: in-memory key-value store mirroring LuaSettings API.
-- Uses a shared data table so tests can pre-populate it before requiring config.
local settings_data = {}
package.preload["luasettings"] = function()
    local M = {}
    function M:open(_file_path)
        return setmetatable({ data = settings_data }, { __index = M })
    end
    function M:readSetting(key, default)
        if self.data[key] ~= nil then return self.data[key] end
        return default
    end
    function M:saveSetting(key, value)
        self.data[key] = value
    end
    function M:isTrue(key)
        return self.data[key] == true
    end
    function M:has(key)
        return self.data[key] ~= nil
    end
    function M:delSetting(key)
        self.data[key] = nil
    end
    function M:flush() end
    return M
end

-- Expose for specs that need to verify forwarding or pre-populate settings.
_G._test_log_calls = log_calls
_G._test_settings_data = settings_data
