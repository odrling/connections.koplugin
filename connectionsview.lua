local Blitbuffer = require("ffi/blitbuffer")
local Button = require("ui/widget/button")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local InfoMessage = require("ui/widget/InfoMessage")
local InputContainer = require("ui/widget/container/inputcontainer")
local Screen = Device.screen
local TextWidget = require("ui/widget/textwidget")
local TitleBar = require("ui/widget/titlebar")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local _ = require("gettext")
local logger = require("logger")
local math = require("math")

local ConnectionsWidget = InputContainer:extend({
	width = nil,
	height = nil,
	color = Blitbuffer.COLOR_BLACK,
	puzzle = nil,
	lives = 4,
	selected = {},
})

function ConnectionsWidget:init()
	self.screen_width = Screen:getWidth()
	self.screen_height = Screen:getHeight()

	self.covers_fullscreen = true

	self[1] = FrameContainer:new({
		width = self.screen_width,
		height = self.screen_height,
		background = Blitbuffer.COLOR_WHITE,
		bordersize = 0,
		padding = 0,
		self:getContent(),
	})

	self.dimen = Geom:new({ w = self.screen_width, h = self.screen_height, x = 0, y = 0 })

	UIManager:setDirty(self, function()
		return "ui", self.dimen
	end)
end

function ConnectionsWidget:getContent()
	local titlebar = TitleBar:new({
		title = "Connections",
		width = self.screen_width,
		padding = Screen:scaleBySize(5),
		close_callback = not self.readonly and function()
			self:onClose()
		end,
	})

	self.grid = VerticalGroup:new({
		HorizontalGroup:new({}),
		HorizontalGroup:new({}),
		HorizontalGroup:new({}),
		HorizontalGroup:new({}),
	})

	local button_size = math.floor(self.screen_width / 4) - Screen:scaleBySize(10)
	for i, card in ipairs(self.puzzle.cards) do
		local row = math.floor((i - 1) / 4) + 1
		local col = ((i - 1) % 4) + 1

		local button = Button:new({
			text_func = function()
				return self.puzzle.cards[i]
			end,
			width = button_size,
			checked_func = function()
				return self:is_selected(card) ~= 0
			end,
			background = Blitbuffer.COLOR_WHITE,
			margin = Screen:scaleBySize(5),
			border = Screen:scaleBySize(1),
			callback = function()
				self:select_or_remove(self.puzzle.cards[i])
			end,
		})
		self.grid[row][col] = button
	end

	self.lives_remaining = TextWidget:new({
		face = Font:getFace("cfont"),
		bold = false,
		fgcolor = Blitbuffer.COLOR_BLACK,
	})
	self:set_lives_string()

	local actions = HorizontalGroup:new({
		Button:new({
			text = "Deselect All",
			margin = Screen:scaleBySize(5),
			callback = function()
				self:deselect_all()
				self:refresh()
			end,
		}),
		Button:new({
			text = "Submit",
			margin = Screen:scaleBySize(5),
			callback = function()
				self:check_selected()
			end,
		}),
	})

	return VerticalGroup:new({
		titlebar,
		self.grid,
		self.lives_remaining,
		actions,
	})
end

function ConnectionsWidget:select_or_remove(word)
	if word == "" then
		return nil
	end

	local n = self:is_selected(word)
	if n == 0 and #self.selected < 4 then
		self.selected[#self.selected + 1] = word
	else
		table.remove(self.selected, n)
	end
end

function ConnectionsWidget:is_selected(word)
	for i, v in ipairs(self.selected) do
		if v == word then
			return i
		end
	end
	return 0
end

function ConnectionsWidget:deselect_all()
	for i, _ in ipairs(self.selected) do
		self.selected[i] = nil
	end
end

function ConnectionsWidget:get_category(word)
	for i, category in ipairs(self.puzzle.categories) do
		for _, card in ipairs(category.cards) do
			if card.content == word then
				return i
			end
		end
	end

	-- should never happen
	return nil
end

function ConnectionsWidget:reveal_category(cat)
	for i, v in ipairs(self.puzzle.cards) do
		for _, selword in ipairs(self.selected) do
			if v == selword then
				self.puzzle.cards[i] = ""
			end
		end
	end
	self:deselect_all()

	-- do something better to show the category name
	UIManager:show(InfoMessage:new({ text = "Correct: " .. self.puzzle.categories[cat].title }))
end

function ConnectionsWidget:check_selected()
	if #self.selected < 4 then
		UIManager:show(InfoMessage:new({ text = "Select 4 cards first" }))
		return nil
	end

	local word_categories = { 0, 0, 0, 0 }
	local max_words = 0
	local max_cat = 0
	for _, v in ipairs(self.selected) do
		local word_cat = self:get_category(v)
		word_categories[word_cat] = word_categories[word_cat] + 1
		if word_categories[word_cat] > max_words then
			max_words = word_categories[word_cat]
			max_cat = word_cat
		end
	end

	if max_words == 4 then
		self:reveal_category(max_cat)
	else
		self.lives = self.lives - 1
		self:set_lives_string()

		if self.lives == 0 then
			UIManager:show(InfoMessage:new({ text = "Maybe next time." }))
		elseif word_categories[4] == 3 then
			UIManager:show(InfoMessage:new({ text = "One away." }))
		else
			UIManager:show(InfoMessage:new({ text = "Wrong." }))
		end
	end
	self:refresh()
end

function ConnectionsWidget:refresh()
	-- refresh the grid
	for i = 1, 4 do
		for u = 1, 4 do
			-- text_func is used and it’s only called in init
			self.grid[i][u]:init()
		end
	end
	UIManager:widgetRepaint(self, 0, 0)
	UIManager:setDirty(self.lives_remaining, function()
		return "fast", self.lives_remaining.dimen
	end)
end

function ConnectionsWidget:set_lives_string()
	self.lives_remaining:setText(self:get_lives_string())
end

function ConnectionsWidget:get_lives_string()
	return "Mistakes Remaining: " .. string.rep("●", self.lives)
end

function ConnectionsWidget:onClose()
	UIManager:close(self)
	return true
end

return ConnectionsWidget
