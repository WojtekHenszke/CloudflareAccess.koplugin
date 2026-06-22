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

-- Expose log_calls for specs that need to verify forwarding.
_G._test_log_calls = log_calls
