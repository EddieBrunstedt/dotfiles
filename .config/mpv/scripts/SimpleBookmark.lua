local mp = require("mp")
local utils = require("mp.utils")

local log_path = utils.join_path(mp.find_config_file(".") or ".", "mpvBookmark.log")

local keys = {
	save = "ctrl+b",
	toggle = "b",
	up = "k",
	down = "j",
	open = "ENTER",
	open_keypad_enter = "KP_ENTER",
	delete = "x",
	close = { "ESC", "q" },
}

local style = {
	font = "MonoLisa Medium",
	align = 1,
	max_items = 10,
	max_title_length = 90,
	text_scale = 70,
	cursor_scale = 70,
	header_scale = 80,
	text_color = "FFFFFF",
	cursor_color = "FFBF7F",
	header_color = "FFFFAA",
	border = 0.7,
	header_border = 0.8,
}

local entries = {}
local cursor = 1
local list_open = false
local pending_seek = nil

local function clamp(value, min, max)
	if value < min then
		return min
	end
	if value > max then
		return max
	end
	return value
end

local function trim(value)
	return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function filename(path)
	return tostring(path or ""):match("[^/\\]+$") or tostring(path or "")
end

local function clean_field(value)
	return trim(value):gsub("[\r\n]", " "):gsub('"', "")
end

local function ass_escape(value)
	return tostring(value or ""):gsub("{", "\\{"):gsub("}", "\\}")
end

local function truncate(value, max_length)
	value = tostring(value or "")
	if #value <= max_length then
		return value
	end
	return value:sub(1, max_length - 3) .. "..."
end

local function format_time(seconds)
	seconds = math.max(0, math.floor(tonumber(seconds) or 0))
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	local s = seconds % 60
	return string.format("%02d:%02d:%02d", h, m, s)
end

local function ass_style(scale, border, color)
	return string.format(
		"{\\an%d\\fn%s\\fscx%d\\fscy%d\\bord%.1f\\1c&H%s&}",
		style.align,
		style.font,
		scale,
		scale,
		border,
		color
	)
end

local normal_style = ass_style(style.text_scale, style.border, style.text_color)
local cursor_style = ass_style(style.cursor_scale, style.border, style.cursor_color)
local header_style = ass_style(style.header_scale, style.header_border, style.header_color)
local reset_style = "{\\r}"

local function read_lines()
	local lines = {}
	local file = io.open(log_path, "r")
	if not file then
		return lines
	end

	for line in file:lines() do
		table.insert(lines, line)
	end

	file:close()
	return lines
end

local function parse_line(line, line_number)
	local date, title, path, length, time =
		line:match('^%[(.-)%]%s+"(.-)"%s+|%s+(.-)%s+|%s+length=([^|]*)%s+|%s+time=([^|]*)')

	if not path then
		date, path, length, time = line:match("^%[(.-)%]%s+(.-)%s+|%s+length=([^|]*)%s+|%s+time=([^|]*)")
		title = filename(path)
	end

	if not path then
		return nil
	end

	path = trim(path)
	title = clean_field(title ~= "" and title or filename(path))

	return {
		line_number = line_number,
		date = date,
		title = title,
		path = path,
		length = tonumber(length) or 0,
		time = tonumber(time) or 0,
	}
end

local function load_entries()
	entries = {}

	for line_number, line in ipairs(read_lines()) do
		local entry = parse_line(line, line_number)
		if entry then
			-- Show newest bookmarks first while preserving the log file order on disk.
			table.insert(entries, 1, entry)
		end
	end

	if #entries == 0 then
		cursor = 1
	else
		cursor = clamp(cursor, 1, #entries)
	end
end

local function draw_list()
	if not list_open then
		return
	end

	local total = #entries
	local start = clamp(cursor - math.floor(style.max_items / 2), 1, math.max(1, total - style.max_items + 1))
	local finish = math.min(total, start + style.max_items - 1)

	local osd = header_style .. string.format("🔖 Bookmarks [%d/%d]", cursor, total) .. reset_style .. "\\N\\N"

	if start > 1 then
		osd = osd .. normal_style .. "..." .. reset_style .. "\\N"
	end

	for index = start, finish do
		local entry = entries[index]
		local selected = index == cursor
		-- Use an ASS hard space for unselected rows so the marker column is kept.
		local marker = selected and "›" or "\\h"
		local line_style = selected and cursor_style or normal_style
		local title = ass_escape(truncate(entry.title, style.max_title_length))

		osd = osd
			.. line_style
			.. string.format("%s %d. %s  🕒 %s", marker, index, title, format_time(entry.time))
			.. reset_style
			.. "\\N"
	end

	if finish < total then
		osd = osd .. normal_style .. "..." .. reset_style
	end

	mp.set_osd_ass(0, 0, osd)
end

local function unbind_list_keys()
	mp.remove_key_binding("bookmark-list-up")
	mp.remove_key_binding("bookmark-list-down")
	mp.remove_key_binding("bookmark-list-open")
	mp.remove_key_binding("bookmark-list-open-keypad-enter")
	mp.remove_key_binding("bookmark-list-delete")
	mp.remove_key_binding("bookmark-list-close-esc")
	mp.remove_key_binding("bookmark-list-close-q")
	mp.remove_key_binding("bookmark-list-close-h")
end

local function close_list()
	if not list_open then
		return
	end
	list_open = false
	unbind_list_keys()
	mp.set_osd_ass(0, 0, "")
end

local function move_cursor(delta)
	cursor = clamp(cursor + delta, 1, #entries)
	draw_list()
end

local function open_selected()
	local entry = entries[cursor]
	if not entry then
		return
	end

	pending_seek = entry.time
	close_list()
	mp.commandv("loadfile", entry.path, "replace")
	mp.osd_message("Loaded bookmark:\n" .. entry.title .. "  🕒 " .. format_time(entry.time))
end

local function write_lines(lines)
	local file = io.open(log_path, "w")
	if not file then
		mp.osd_message("Failed to write bookmark log")
		return false
	end

	for _, line in ipairs(lines) do
		file:write(line, "\n")
	end

	file:close()
	return true
end

local function delete_selected()
	local entry = entries[cursor]
	if not entry then
		return
	end

	local lines = read_lines()
	table.remove(lines, entry.line_number)

	if not write_lines(lines) then
		return
	end

	local deleted_title = entry.title
	load_entries()

	if #entries == 0 then
		close_list()
	else
		cursor = clamp(cursor, 1, #entries)
		draw_list()
	end

	mp.osd_message("Deleted bookmark:\n" .. deleted_title)
end

local function bind_list_keys()
	mp.add_forced_key_binding(keys.up, "bookmark-list-up", function()
		move_cursor(-1)
	end, "repeatable")
	mp.add_forced_key_binding(keys.down, "bookmark-list-down", function()
		move_cursor(1)
	end, "repeatable")
	mp.add_forced_key_binding(keys.open, "bookmark-list-open", open_selected)
	mp.add_forced_key_binding(keys.open_keypad_enter, "bookmark-list-open-keypad-enter", open_selected)
	mp.add_forced_key_binding(keys.delete, "bookmark-list-delete", delete_selected)
	mp.add_forced_key_binding(keys.close[1], "bookmark-list-close-esc", close_list)
	mp.add_forced_key_binding(keys.close[2], "bookmark-list-close-q", close_list)
	mp.add_forced_key_binding(keys.close[3], "bookmark-list-close-h", close_list)
end

local function toggle_list()
	if list_open then
		close_list()
		return
	end

	load_entries()
	if #entries == 0 then
		mp.osd_message("No bookmarks yet")
		return
	end

	list_open = true
	cursor = 1
	bind_list_keys()
	draw_list()
end

local function save_bookmark()
	local path = mp.get_property("path")
	if not path or path == "" then
		mp.osd_message("No file loaded")
		return
	end

	local title = clean_field(mp.get_property("media-title") or filename(path))
	local length = mp.get_property_number("duration") or 0
	local time = math.max(0, mp.get_property_number("time-pos") or 0)

	local file = io.open(log_path, "a+")
	if not file then
		mp.osd_message("Failed to write bookmark log")
		return
	end

	file:write(
		string.format(
			'[%s] "%s" | %s | length=%s | time=%s | \n',
			os.date("%Y-%m-%dT%H:%M:%S"),
			title,
			path,
			tostring(length),
			tostring(time)
		)
	)
	file:close()

	mp.osd_message("Bookmarked:\n" .. title .. "  🕒 " .. format_time(time))

	if list_open then
		load_entries()
		cursor = 1
		draw_list()
	end
end

mp.register_event("file-loaded", function()
	if not pending_seek then
		return
	end

	local seek_time = pending_seek
	pending_seek = nil
	mp.commandv("seek", seek_time, "absolute", "exact")
end)

mp.add_forced_key_binding(keys.save, "bookmark-save", save_bookmark)
mp.add_forced_key_binding(keys.toggle, "bookmark-list-toggle", toggle_list)
