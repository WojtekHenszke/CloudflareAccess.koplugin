--[[-- In-app log viewer for troubleshooting.

Opens a TextViewer showing the in-memory ring buffer (newest at the bottom)
with buttons for Refresh, Clear, Copy, and showing the log file path.

@module koplugin.cloudflareaccess.ui.log_viewer
--]]

local ConfirmBox = require("ui/widget/confirmbox")
local DataStorage = require("datastorage")
local Device = require("device")
local InfoMessage = require("ui/widget/infomessage")
local TextViewer = require("ui/widget/textviewer")
local UIManager = require("ui/uimanager")
local _ = require("gettext")
local T = require("ffi/util").template

local log = require("lib.log")

local M = {}

--- Format the ring buffer as a single string for TextViewer.
-- @treturn string concatenated log entries
local function format_entries()
    local entries = log.getEntries()
    if #entries == 0 then
        return _("(no entries yet — enable the plugin and trigger a request, or raise the log level)")
    end
    local lines = {}
    for _, e in ipairs(entries) do
        local ts = os.date("%H:%M:%S", e.time)
        table.insert(lines, string.format("%s [%s] %s", ts, e.level, e.message))
    end
    return table.concat(lines, "\n")
end

--- Show the log viewer.
function M.show()
    M._show_viewer()
end

--- Internal: create and show the TextViewer.
function M._show_viewer()
    local viewer
    -- Device.input.setClipboardText is available on Android and some desktop
    -- builds only.  Feature-detect it so we never crash on devices that
    -- omit the clipboard write API (koreader/frontend/device/input.lua).
    local has_clipboard = Device.input and Device.input.setClipboardText
    local button_row = {
        {
            text = _("Refresh"),
            callback = function()
                UIManager:close(viewer)
                M._show_viewer()
            end,
        },
        {
            text = _("Clear"),
            callback = function()
                UIManager:show(ConfirmBox:new{
                    text = _("Clear all log entries?"),
                    ok_text = _("Clear"),
                    ok_callback = function()
                        log.clear()
                        UIManager:close(viewer)
                        M._show_viewer()
                    end,
                })
            end,
        },
    }
    if has_clipboard then
        button_row[#button_row + 1] = {
            text = _("Copy"),
            callback = function()
                Device.input.setClipboardText(format_entries())
                UIManager:show(InfoMessage:new{
                    text = _("Logs copied to clipboard."),
                    timeout = 2,
                })
            end,
        }
    end
    button_row[#button_row + 1] = {
        text = _("Log file"),
        callback = function()
            -- getDataDir() returns the KOReader data directory for the current platform
            -- (e.g. /mnt/onboard/.adds/koreader/ on Kobo, koreader/ on Android)
            -- see frontend/datastorage.lua in the KOReader source for platform mapping
            local log_path = DataStorage:getDataDir() .. "/crash.log"
            UIManager:show(InfoMessage:new{
                text = T(_("Full log file:\n%1"), log_path),
            })
        end,
    }
    local buttons = { button_row }

    viewer = TextViewer:new{
        title = _("Cloudflare Access logs"),
        text = format_entries(),
        buttons_table = buttons,
        monospace_font = true,
        justified = false,
        auto_para_direction = false,
    }
    UIManager:show(viewer)
end

return M
