--[[--
This plugin lets you play Connections in KOReader.

@module koplugin.NYTConnections
--]]
--

local ConnectionsWidget = require("connectionsview")
local InfoMessage = require("ui/widget/infomessage")
local InputDialog = require("ui/widget/inputdialog")
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

local start_game

local function show_puzzle(puzzle, date)
	UIManager:show(ConnectionsWidget:new({ puzzle = puzzle, puzzle_date = date, on_next_puzzle = start_game }))
end

function start_game()
	local puzzle, date = api.get_latest_unplayed()
	if puzzle ~= nil then
		show_puzzle(puzzle, date)
	elseif NetworkMgr:isOnline() then
		puzzle, date = api.get_connections_puzzle()
		if puzzle == nil then
			UIManager:show(InfoMessage:new({ text = _("Failed to get today’s puzzle.") }))
		else
			show_puzzle(puzzle, date)
		end
	else
		UIManager:show(InfoMessage:new({ text = _("No unplayed puzzles available. Go online and use Download Puzzles first.") }))
	end
end

local function download_puzzles()
	local dialog
	dialog = InputDialog:new({
		title = _("Download Puzzles"),
		input = "30",
		input_hint = _("Number of days"),
		input_type = "number",
		buttons = {
			{
				{
					text = _("Cancel"),
					id = "close",
					callback = function()
						UIManager:close(dialog)
					end,
				},
				{
					text = _("Download"),
					is_enter_default = true,
					callback = function()
						local num = tonumber(dialog:getInputText())
						UIManager:close(dialog)
						if num == nil or num < 1 then
							UIManager:show(InfoMessage:new({ text = _("Please enter a valid number.") }))
							return
						end
						NetworkMgr:runWhenOnline(function()
							local downloaded, skipped = api.bulk_download(num)
							NetworkMgr:afterWifiAction()
							UIManager:show(InfoMessage:new({
								text = string.format(_("Downloaded %d puzzles, skipped %d already archived."), downloaded, skipped),
							}))
						end)
					end,
				},
			},
		},
	})
	UIManager:show(dialog)
	dialog:onShowKeyboard()
end

local function archive_info()
	local total, played = api.get_archive_info()
	UIManager:show(InfoMessage:new({
		text = string.format(_("Archived: %d puzzles\nPlayed: %d\nUnplayed: %d"), total, played, total - played),
	}))
end

function NYTConnections:addToMainMenu(menu_items)
	menu_items.nytconnections = {
		text = _("NYT Connections"),
		sorting_hint = "tools",
		sub_item_table = {
			{
				text = _("Play"),
				callback = start_game,
			},
			{
				text = _("Download Puzzles"),
				callback = download_puzzles,
			},
			{
				text = _("Archive Info"),
				callback = archive_info,
			},
		},
	}
end

return NYTConnections
