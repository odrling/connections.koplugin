local Blitbuffer = require("ffi/blitbuffer")
local Button = require("ui/widget/button")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local InfoMessage = require("ui/widget/InfoMessage")
local InputContainer = require("ui/widget/container/inputcontainer")
local Screen = Device.screen
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local TitleBar = require("ui/widget/titlebar")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")
local logger = require("logger")
local math = require("math")

local ConnectionsWidget = WidgetContainer:extend({
	width = nil,
	height = nil,
	color = Blitbuffer.COLOR_BLACK,
	puzzle = nil,
})

function ConnectionsWidget:init()
	self.screen_width = Screen:getWidth()
	self.screen_height = Screen:getHeight()

	self.lives = 4
	self.selected = {}
	self.revealed = {}

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

local ROW_WIDTH = Screen:getWidth() - Screen:scaleBySize(40)
local CARD_WIDTH = math.floor(ROW_WIDTH / 4)
local CARD_HEIGHT = Screen:scaleBySize(64)

local Card = InputContainer:extend({
	connections = nil,
	card_number = 0,
	width = nil,
})

function Card:card()
	return self.connections.puzzle.cards[self.card_number]
end

function Card:selected()
	return self.connections.selected
end

function Card:refresh()
	self.text:setText(self:card())
	self:setStyle()
end

function Card:init()
	local bordersize = Screen:scaleBySize(1)
	local padding = Screen:scaleBySize(2)
	local margin = Screen:scaleBySize(2)

	local frame_width = self.width - (bordersize + margin) * 2
	local frame_height = self.height - (bordersize + margin) * 2

	local inner_width = frame_width - (padding * 2)
	local inner_height = frame_height - (padding * 2)

	self.text = TextBoxWidget:new({
		text = self:card(),
		alignment = "center",
		width = inner_width,
		height = inner_height,
		face = Font:getFace("cfont", 18),
		height_adjust = true,
		height_overflow_show_ellipsis = true,
		bold = true,
		fgcolor = Blitbuffer.COLOR_BLACK,
		bgcolor = Blitbuffer.COLOR_WHITE,
	})

	self.frame = FrameContainer:new({
		background = Blitbuffer.COLOR_WHITE,
		bordersize = bordersize,
		width = frame_width,
		height = frame_height,
		padding = padding,
		margin = 0,
		dimen = Geom:new({
			w = frame_width,
			h = frame_height,
		}),
		CenterContainer:new({
			dimen = Geom:new({
				w = inner_width,
				h = inner_height,
			}),
			self.text,
		}),
	})
	self.dimen = Geom:new({ w = self.width, h = self.height })

	self[1] = CenterContainer:new({
		dimen = Geom:new({
			w = self.width,
			h = self.height,
		}),
		self.frame,
	})

	self.ges_events = {
		TapSelectCard = {
			GestureRange:new({
				ges = "tap",
				range = self.dimen,
			}),
		},
	}
end

function Card:setStyle()
	if self.connections:is_selected(self:card()) > 0 then
		self.frame.background = Blitbuffer.COLOR_BLACK
		self.text.bgcolor = Blitbuffer.COLOR_BLACK
		self.text.fgcolor = Blitbuffer.COLOR_WHITE
	else
		self.frame.background = Blitbuffer.COLOR_WHITE
		self.text.bgcolor = Blitbuffer.COLOR_WHITE
		self.text.fgcolor = Blitbuffer.COLOR_BLACK
	end
	self.text:init()
	UIManager:widgetRepaint(self, self.dimen.x, self.dimen.y)
	UIManager:setDirty(self, function()
		return "fast", self.dimen
	end)
end

function Card:onTapSelectCard()
	self.connections:select_or_remove(self:card())
	self:setStyle()
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
		FrameContainer:new({
			bordersize = 0,
			padding = Screen:scaleBySize(2),
			margin = 0,
			height = CARD_HEIGHT,
			HorizontalGroup:new({
				height = CARD_HEIGHT,
			}),
		}),
		FrameContainer:new({
			bordersize = 0,
			padding = Screen:scaleBySize(2),
			margin = 0,
			height = CARD_HEIGHT,
			HorizontalGroup:new({
				height = CARD_HEIGHT,
			}),
		}),
		FrameContainer:new({
			bordersize = 0,
			padding = Screen:scaleBySize(2),
			margin = 0,
			height = CARD_HEIGHT,
			HorizontalGroup:new({
				height = CARD_HEIGHT,
			}),
		}),
		FrameContainer:new({
			bordersize = 0,
			padding = Screen:scaleBySize(2),
			margin = 0,
			height = CARD_HEIGHT,
			HorizontalGroup:new({
				height = CARD_HEIGHT,
			}),
		}),
	})

	for i, _ in ipairs(self.puzzle.cards) do
		local row = math.floor((i - 1) / 4) + 1
		local col = ((i - 1) % 4) + 1

		local button = Card:new({
			connections = self,
			card_number = i,
			margin = 5,
			width = CARD_WIDTH,
			height = CARD_HEIGHT,
		})
		self.grid[row][1][col] = button
	end

	self.lives_remaining = TextWidget:new({
		face = Font:getFace("cfont"),
		bold = false,
		fgcolor = Blitbuffer.COLOR_BLACK,
	})
	self:set_lives_string()

	local actions = HorizontalGroup:new({
		Button:new({
			text = "Shuffle",
			margin = Screen:scaleBySize(5),
			callback = function()
				self:shuffle()
			end,
		}),
		Button:new({
			text = "Deselect All",
			margin = Screen:scaleBySize(5),
			callback = function()
				self:deselect_all()
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

function ConnectionsWidget:shuffle()
	local start = self:number_revealed() * 4 + 1
	local i_end = #self.puzzle.cards
	for i = start, i_end do
		local other = math.random(start, i_end)
		local tmp = self.puzzle.cards[i]
		self.puzzle.cards[i] = self.puzzle.cards[other]
		self.puzzle.cards[other] = tmp
	end
	self:refresh()
end

function ConnectionsWidget:select_or_remove(word)
	if word == "" then
		return
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
	self:refresh()
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

function ConnectionsWidget:reveal_answers()
	for i, _ in ipairs(self.puzzle.categories) do
		if self.revealed[i] == nil then
			self:reveal_category(i)
		end
	end
end

function ConnectionsWidget:number_revealed()
	local n = 0
	for i = 1, 4 do
		if self.revealed[i] ~= nil then
			n = n + 1
		end
	end

	return n
end

function ConnectionsWidget:reveal_category(cat)
	local category = self.puzzle.categories[cat]
	local src = 4 * self:number_revealed()

	for i, v in ipairs(self.puzzle.cards) do
		for _, card in ipairs(category.cards) do
			if v == card.content then
				src = src + 1
				self.puzzle.cards[i] = self.puzzle.cards[src]
				self.puzzle.cards[src] = ""
			end
		end
	end

	local text = category.title .. "\n"
	for i, card in ipairs(category.cards) do
		text = text .. card.content
		if i < #category.cards then
			text = text .. ", "
		end
	end

	self.revealed[cat] = true
	local reveal_row = self:number_revealed()
	for i = 1, 4 do
		self.grid[reveal_row][1][i]:free()
		self.grid[reveal_row][1][i] = nil
	end
	self.grid[reveal_row][1]:free()
	self.grid[reveal_row][1] = FrameContainer:new({
		w = ROW_WIDTH,
		h = CARD_HEIGHT,
		background = Blitbuffer.COLOR_BLACK,
		padding = 0,
		bordersize = 0,
		CenterContainer:new({
			dimen = Geom:new({
				w = ROW_WIDTH,
				h = CARD_HEIGHT,
			}),
			TextBoxWidget:new({
				width = CARD_WIDTH * 4,
				height = CARD_HEIGHT,
				height_adjust = true,
				padding = Screen:scaleBySize(2),
				alignment = "center",
				text = text,
				face = Font:getFace("cfont", 20),
				bold = true,
				fgcolor = Blitbuffer.COLOR_WHITE,
				bgcolor = Blitbuffer.COLOR_BLACK,
			}),
		}),
	})
	UIManager:widgetRepaint(self, self.dimen.x, self.dimen.y)

	self:refresh()

	if reveal_row == 4 then
		self:show_end_message()
	end
end

function ConnectionsWidget:show_end_message()
	if self.lives == 4 then
		UIManager:show(InfoMessage:new({ text = "Perfect" }))
	elseif self.lives == 3 then
		UIManager:show(InfoMessage:new({ text = "Great" }))
	elseif self.lives == 2 then
		UIManager:show(InfoMessage:new({ text = "Solid" }))
	elseif self.lives == 1 then
		UIManager:show(InfoMessage:new({ text = "Phew" }))
	else
		UIManager:show(InfoMessage:new({ text = "Next Time" }))
	end
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
		self:deselect_all()
	else
		self.lives = self.lives - 1
		self:set_lives_string()

		if self.lives == 0 then
			self:reveal_answers()
		elseif max_words == 3 then
			UIManager:show(InfoMessage:new({ text = "One Away" }))
		else
			UIManager:show(InfoMessage:new({ text = "Wrong" }))
		end
	end
end

function ConnectionsWidget:refresh()
	-- refresh the grid
	for i = 1, 4 do
		for u = 1, 4 do
			-- text_func is used and it’s only called in init
			if #self.grid[i][1] == 4 then
				self.grid[i][1][u]:refresh()
			end
		end
	end

	UIManager:setDirty(self, function()
		return "fast", self.dimen
	end)
end

function ConnectionsWidget:set_lives_string()
	self.lives_remaining:setText(self:get_lives_string())
	UIManager:setDirty(self, function()
		return "fast", self.dimen
	end)
end

function ConnectionsWidget:get_lives_string()
	return "Mistakes Remaining: " .. string.rep("●", self.lives)
end

function ConnectionsWidget:onClose()
	UIManager:close(self)
	return true
end

return ConnectionsWidget
