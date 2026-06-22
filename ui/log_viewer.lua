--[[-- In-app log viewer (stub — implemented in Task 11a).

@module koplugin.cloudflareaccess.ui.log_viewer
--]]

local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local M = {}

function M.show()
    UIManager:show(InfoMessage:new{
        text = _("Not implemented yet"),
    })
end

return M
