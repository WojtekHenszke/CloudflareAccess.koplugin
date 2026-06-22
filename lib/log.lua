--[[-- Leveled ring buffer with redaction over KOReader's logger.

This facade wraps KOReader's `logger` module with three additions:

1. **Level filtering** — a single configurable level (`off`/`err`/`warn`/
   `info`/`dbg`) controls both what is forwarded to `logger` (and thus
   `crash.log`/`koreader.log`) and what is kept in the in-memory ring buffer.
   When set to `off`, every call is a cheap no-op.

2. **In-memory ring buffer** — a bounded FIFO of recent entries for the
   in-app log viewer. The buffer is volatile by design (never persisted to
   disk) so secrets-adjacent metadata like hostnames does not outlive the
   session.

3. **Redaction** — anything resembling a CF Access secret (long hex/base64
   strings) is masked before it reaches either the logger or the ring buffer,
   so both `crash.log` and the in-UI view are safe to screenshot.

@module koplugin.cloudflareaccess.lib.log
--]]

local logger = require("logger")

local M = {}

-- Level ordering: off drops everything; higher numbers are more verbose.
local LEVELS = {
    off = 0,
    err = 1,
    warn = 2,
    info = 3,
    dbg = 4,
}

-- Default capacity of the ring buffer (entries).
local DEFAULT_CAPACITY = 200

local current_level = LEVELS.warn
local capacity = DEFAULT_CAPACITY
local entries = {}

--- Redact secret-like substrings from a string.
-- Masks runs of >= 32 hex or base64 characters that could be a CF Access
-- service-token value. Applied before forwarding to `logger` and before
-- storing in the ring buffer (defense in depth).
-- @string str the message to redact
-- @treturn string the redacted message
local function redact(str)
    if type(str) ~= "string" then
        return str
    end
    -- Lua patterns don't support {n,} quantifiers, so we match runs of
    -- candidate chars and check the length in the replacement callback.
    -- Two token shapes:
    --  1. long hex strings (CF client IDs are 32+ hex chars)
    --  2. long base64url/base64 strings (CF client secrets, 40+ chars)
    str = str:gsub("[0-9a-fA-F]+", function(m)
        if #m >= 32 then return "<redacted>" end
        return m
    end)
    str = str:gsub("[A-Za-z0-9%+/%=_-]+", function(m)
        if #m >= 40 then return "<redacted>" end
        return m
    end)
    return str
end
M.redact = redact

--- Set the current log level.
-- @string level one of "off", "err", "warn", "info", "dbg"
function M.setLevel(level)
    if LEVELS[level] then
        current_level = LEVELS[level]
    end
end

--- Get the current log level name.
-- @treturn string one of "off", "err", "warn", "info", "dbg"
function M.getLevel()
    for name, num in pairs(LEVELS) do
        if num == current_level then
            return name
        end
    end
    return "warn"
end

--- Set the ring buffer capacity.
-- @int cap maximum number of entries to retain
function M.setCapacity(cap)
    if type(cap) == "number" and cap > 0 then
        capacity = cap
        -- Trim if we shrank below current size
        while #entries > capacity do
            table.remove(entries, 1)
        end
    end
end

--- Get the ring buffer capacity.
-- @treturn int
function M.getCapacity()
    return capacity
end

--- Append an entry to the ring buffer (evicting oldest when full).
local function append(level_name, message)
    local entry = {
        time = os.time(),
        level = level_name,
        message = message,
    }
    entries[#entries + 1] = entry
    if #entries > capacity then
        table.remove(entries, 1)
    end
end

--- Return a shallow copy of the ring buffer (oldest first).
-- @treturn table array of {time, level, message} entries
function M.getEntries()
    local copy = {}
    for i, e in ipairs(entries) do
        copy[i] = { time = e.time, level = e.level, message = e.message }
    end
    return copy
end

--- Clear the ring buffer.
function M.clear()
    entries = {}
end

-- Internal: emit a log line at a given level.
-- Formats lazily (only when args are provided), redacts, forwards to
-- KOReader's logger, and appends to the ring buffer.
local function emit(level_name, fmt, ...)
    if LEVELS[level_name] > current_level then
        return
    end
    local message
    if select("#", ...) > 0 then
        message = string.format(fmt, ...)
    else
        message = tostring(fmt)
    end
    message = redact(message)
    -- Forward to KOReader's logger with a stable prefix
    local prefixed = "[CFAccess] " .. message
    local fn = logger[level_name == "dbg" and "dbg"
        or level_name == "info" and "info"
        or level_name == "warn" and "warn"
        or "err"]
    fn(prefixed)
    append(level_name, message)
end

--- Log an error.
function M.err(fmt, ...)
    emit("err", fmt, ...)
end

--- Log a warning.
function M.warn(fmt, ...)
    emit("warn", fmt, ...)
end

--- Log an informational message.
function M.info(fmt, ...)
    emit("info", fmt, ...)
end

--- Log a debug message.
function M.dbg(fmt, ...)
    emit("dbg", fmt, ...)
end

return M
