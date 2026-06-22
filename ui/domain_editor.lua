--[[-- Allowed-domains editor (stub — implemented in Task 10).

@module koplugin.cloudflareaccess.ui.domain_editor
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
