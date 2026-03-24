local http = require("socket.http")
local ltn12 = require("ltn12")
local json = require("json")
local logger = require("logger")
local datetime = require("datetime")
local DataStorage = require("datastorage")
local lfs = require("libs/libkoreader-lfs")

local MAX_ARCHIVE = 100

local function get_archive_dir()
	local dir = DataStorage:getDataDir() .. "/connections"
	lfs.mkdir(dir)
	return dir
end

local function get_state_path()
	return get_archive_dir() .. "/state.json"
end

local function load_state()
	local path = get_state_path()
	local f = io.open(path, "r")
	if f == nil then
		return { downloaded = {}, played = {} }
	end
	local content = f:read("*a")
	f:close()
	local ok, state = pcall(json.decode, content)
	if not ok or state == nil then
		return { downloaded = {}, played = {} }
	end
	if state.downloaded == nil then state.downloaded = {} end
	if state.played == nil then state.played = {} end
	return state
end

local function save_state(state)
	local path = get_state_path()
	local f = io.open(path, "w")
	if f == nil then
		logger.err("connections: failed to write state file")
		return
	end
	f:write(json.encode(state))
	f:close()
end

local function list_has(list, value)
	for _, v in ipairs(list) do
		if v == value then return true end
	end
	return false
end

local function save_puzzle(date, raw_resp)
	local path = get_archive_dir() .. "/" .. date .. ".json"
	local f = io.open(path, "w")
	if f == nil then
		logger.err("connections: failed to save puzzle " .. date)
		return false
	end
	f:write(json.encode(raw_resp))
	f:close()

	local state = load_state()
	if not list_has(state.downloaded, date) then
		table.insert(state.downloaded, date)
		table.sort(state.downloaded)
		save_state(state)
	end
	return true
end

local function delete_puzzle(date)
	local path = get_archive_dir() .. "/" .. date .. ".json"
	os.remove(path)

	local state = load_state()
	local new_downloaded = {}
	for _, d in ipairs(state.downloaded) do
		if d ~= date then
			table.insert(new_downloaded, d)
		end
	end
	state.downloaded = new_downloaded
	save_state(state)
end

local function enforce_max_archive()
	local state = load_state()
	table.sort(state.downloaded)
	while #state.downloaded > MAX_ARCHIVE do
		local oldest = state.downloaded[1]
		local path = get_archive_dir() .. "/" .. oldest .. ".json"
		os.remove(path)
		table.remove(state.downloaded, 1)
	end
	save_state(state)
end

local function parse_puzzle(resp)
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
		editor = resp.editor,
		print_date = resp.print_date,
	}
end

local function load_puzzle(date)
	local path = get_archive_dir() .. "/" .. date .. ".json"
	local f = io.open(path, "r")
	if f == nil then return nil end
	local content = f:read("*a")
	f:close()
	local ok, resp = pcall(json.decode, content)
	if not ok or resp == nil then return nil end
	return parse_puzzle(resp), date
end

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

	save_puzzle(date, resp)
	enforce_max_archive()

	return parse_puzzle(resp), date
end

local function mark_played(date)
	local state = load_state()
	if not list_has(state.played, date) then
		table.insert(state.played, date)
	end
	-- Remove from downloaded list
	local new_downloaded = {}
	for _, d in ipairs(state.downloaded) do
		if d ~= date then
			table.insert(new_downloaded, d)
		end
	end
	state.downloaded = new_downloaded
	save_state(state)
	-- Delete the puzzle file
	os.remove(get_archive_dir() .. "/" .. date .. ".json")
end

local function get_latest_unplayed()
	local state = load_state()
	local downloaded = state.downloaded
	table.sort(downloaded)
	-- iterate from newest to oldest
	for i = #downloaded, 1, -1 do
		if not list_has(state.played, downloaded[i]) then
			return load_puzzle(downloaded[i])
		end
	end
	return nil
end

local function bulk_download(num_puzzles)
	local state = load_state()
	local now = os.time()
	local downloaded_count = 0
	local skipped_count = 0
	local day_offset = 0

	while downloaded_count < num_puzzles and day_offset < 365 do
		local date = datetime.secondsToDate(now - day_offset * 86400)
		if list_has(state.downloaded, date) or list_has(state.played, date) then
			skipped_count = skipped_count + 1
		else
			local resp = get_connections_cards(date)
			if resp ~= nil then
				save_puzzle(date, resp)
				downloaded_count = downloaded_count + 1
			end
		end
		day_offset = day_offset + 1
	end

	enforce_max_archive()
	return downloaded_count, skipped_count
end

local function get_archive_info()
	local state = load_state()
	return #state.downloaded, #state.played
end

return {
	get_connections_puzzle = get_connections_puzzle,
	load_puzzle = load_puzzle,
	get_latest_unplayed = get_latest_unplayed,
	mark_played = mark_played,
	bulk_download = bulk_download,
	get_archive_info = get_archive_info,
}
