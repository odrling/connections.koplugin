--[[--
This plugin lets you play Connections in KOReader.

@module koplugin.NYTConnections
--]]
--

local ConnectionsWidget = require("connectionsview")
local InfoMessage = require("ui/widget/InfoMessage")
local NetworkMgr = require("ui/network/manager")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")
local api = require("connectionsapi")
local logger = require("logger")

local NYTConnections = WidgetContainer:extend({
	name = "nytconnections",
	is_doc_only = false,
})

function NYTConnections:init()
	self.ui.menu:registerToMainMenu(self)
end

local function start_game()
	NetworkMgr:runWhenOnline(function()
		local puzzle = api.get_connections_puzzle()
		NetworkMgr:afterWifiAction()
		if puzzle == nil then
			UIManager:show(InfoMessage:new({ text = "failed to get today’s puzzle" }))
		else
			UIManager:show(ConnectionsWidget:new({ puzzle = puzzle }))
		end
	end)
end

function NYTConnections:addToMainMenu(menu_items)
	menu_items.nytconnections = {
		text = _("NYTConnections"),
		sorting_hint = "tools",
		callback = start_game,
	}
end

return NYTConnections
