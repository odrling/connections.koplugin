local http = require("socket.http")
local ltn12 = require("ltn12")
local json = require("json")
local logger = require("logger")
local datetime = require("datetime")

local function get_connections_cards(date)
	local sink = {}

	local _ = http.request({
		url = "https://www.nytimes.com/svc/connections/v2/" .. date .. ".json",
		method = "GET",
		sink = ltn12.sink.table(sink),
	})

	local resp = table.concat(sink)
	return json.decode(resp)
end

local function get_connections_puzzle()
	local date = datetime.secondsToDate(os.time())

	local resp = get_connections_cards(date)
	if resp == nil then
		logger.err("connections: request failed")
		return nil
	end

	local categories = resp.categories
	local cards = {}
	for _, category in ipairs(categories) do
		for _, card in ipairs(category.cards) do
			cards[card.position + 1] = card.content
		end
	end

	return {
		categories = categories,
		cards = cards,
	}
end

return {
	get_connections_puzzle = get_connections_puzzle,
}
