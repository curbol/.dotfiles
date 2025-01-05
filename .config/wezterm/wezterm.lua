-- Mode Docs
-- https://wezfurlong.org/wezterm/quickselect.html
-- https://wezfurlong.org/wezterm/copymode.html

-- Config Docs
-- https://wezfurlong.org/wezterm/config/files.html

-- Built-in nerdfonts
-- https://wezfurlong.org/wezterm/config/lua/wezterm/nerdfonts.html

local wezterm = require("wezterm")
local gui = wezterm.gui
local action = wezterm.action
local config = wezterm.config_builder()

-- Gruvbox Material (https://github.com/nvim-lualine/lualine.nvim/blob/master/lua/lualine/themes/gruvbox-material.lua)
local GRUVBOX_GREY1 = "#282828"
local GRUVBOX_GREY2 = "#32302f"
local GRUVBOX_GREY3 = "#504945"
local GRUVBOX_GREY4 = "#a89984"
local GRUVBOX_GREY5 = "#ddc7a1"

local GRUVBOX_RED = "#ea6962"
local GRUVBOX_ORANGE = "#e78a4e"
local GRUVBOX_YELLOW = "#d8a657"
local GRUVBOX_GREEN = "#a9b665"
local GRUVBOX_AQUA = "#89b482"
local GRUVBOX_BLUE = "#7daea3"
local GRUVBOX_PURPLE = "#d3869b"

-- Colorscheme
local STATUS_BAR_BG = GRUVBOX_GREY2

-- Symbols
local SEPARATOR_LEFT_BOLD = ""
local SEPARATOR_LEFT_THIN = ""
local SEPARATOR_RIGHT_BOLD = ""
local SEPARATOR_RIGHT_THIN = ""
local SEPARATOR_THIN = "│"

local EDGE_LEFT = "▌"
local EDGE_RIGHT = "▐"

local is_windows = wezterm.target_triple:find("windows") ~= nil
if is_windows then
	config.default_prog = { "zsh" }
end

-- Equivalent to POSIX basename(3)
-- Given "/foo/bar" returns "bar"
-- Given "c:\\foo\\bar" returns "bar"
local function basename(s)
	return string.gsub(s, "(.*[/\\])(.*)", "%2")
end

-- TMUX Keybindings
config.leader = { key = "a", mods = "CTRL", timeout_milliseconds = 1000 }
config.keys = {
	{ key = "phys:Space", mods = "LEADER", action = action.QuickSelect },
	{ key = ":", mods = "LEADER", action = action.ActivateCommandPalette },
	{ key = "/", mods = "LEADER", action = action.Search("CurrentSelectionOrEmptyString") },
	{ key = "a", mods = "LEADER", action = action.ActivateLastTab },
	{ key = "a", mods = "LEADER|CTRL", action = action.ActivateLastTab },
	{ key = "m", mods = "LEADER", action = action.TogglePaneZoomState },
	{ key = "v", mods = "LEADER", action = action.ActivateCopyMode },
	{ key = "-", mods = "LEADER", action = action.SplitVertical({ domain = "CurrentPaneDomain" }) },
	{ key = "\\", mods = "LEADER", action = action.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
	{ key = "c", mods = "LEADER", action = action.SpawnTab("CurrentPaneDomain") },
	{ key = "x", mods = "LEADER", action = action.CloseCurrentPane({ confirm = true }) },
	{ key = "n", mods = "LEADER", action = action.ActivateTabRelative(1) },
	{ key = "n", mods = "LEADER|CTRL", action = action.ActivateTabRelative(1) },
	{ key = "p", mods = "LEADER", action = action.ActivateTabRelative(-1) },
	{ key = "p", mods = "LEADER|CTRL", action = action.ActivateTabRelative(-1) },
	{ key = "1", mods = "LEADER", action = action.ActivateTab(0) },
	{ key = "2", mods = "LEADER", action = action.ActivateTab(1) },
	{ key = "3", mods = "LEADER", action = action.ActivateTab(2) },
	{ key = "4", mods = "LEADER", action = action.ActivateTab(3) },
	{ key = "5", mods = "LEADER", action = action.ActivateTab(4) },
	{ key = "6", mods = "LEADER", action = action.ActivateTab(5) },
	{ key = "7", mods = "LEADER", action = action.ActivateTab(6) },
	{ key = "8", mods = "LEADER", action = action.ActivateTab(7) },
	{ key = "9", mods = "LEADER", action = action.ActivateTab(8) },
	{ key = "0", mods = "LEADER", action = action.ActivateTab(9) },
}

local copy_mode = nil
if gui then
	copy_mode = wezterm.gui.default_key_tables().copy_mode
	table.insert(copy_mode, {
		key = "y",
		mods = "NONE",
		action = action.Multiple({
			action.CopyTo("PrimarySelection"),
			action.ClearSelection,
			action.CopyMode("Close"),
		}),
	})
end
config.key_tables = {
	copy_mode = copy_mode,
}

-- Font
config.font = wezterm.font("JetBrainsMono Nerd Font Mono", { weight = "Regular" })
config.font_size = 15

-- Tab Bar
config.use_fancy_tab_bar = false
config.tab_max_width = 32
config.switch_to_last_active_tab_when_closing_tab = true

-- Window
config.scrollback_lines = 3000
config.window_decorations = "INTEGRATED_BUTTONS|RESIZE"
config.window_close_confirmation = "AlwaysPrompt"
config.window_padding = {
	left = 0,
	right = 0,
	top = 0,
	bottom = 0,
}
config.inactive_pane_hsb = {
	-- saturation = 0.8,
	brightness = 0.8,
}

-- Tab Bar
config.integrated_title_buttons = { "Close", "Hide", "Maximize" }
config.integrated_title_button_alignment = "Left"
config.integrated_title_button_style = "Windows"
config.tab_bar_style = {
	window_close = wezterm.format({
		{ Background = { Color = STATUS_BAR_BG } },
		{ Foreground = { Color = "#FF605C" } },
		{ Text = " " .. wezterm.nerdfonts.md_circle_medium .. " " },
	}),
	window_close_hover = wezterm.format({
		{ Background = { Color = STATUS_BAR_BG } },
		{ Foreground = { Color = "#FF605C" } },
		{ Text = " " .. wezterm.nerdfonts.md_close_circle .. " " },
	}),
	window_hide = wezterm.format({
		{ Background = { Color = STATUS_BAR_BG } },
		{ Foreground = { Color = "#FFBD44" } },
		{ Text = wezterm.nerdfonts.md_circle_medium .. " " },
	}),
	window_hide_hover = wezterm.format({
		{ Background = { Color = STATUS_BAR_BG } },
		{ Foreground = { Color = "#FFBD44" } },
		{ Text = wezterm.nerdfonts.md_minus_circle .. " " },
	}),
	window_maximize = wezterm.format({
		{ Background = { Color = STATUS_BAR_BG } },
		{ Foreground = { Color = "#00CA4E" } },
		{ Text = wezterm.nerdfonts.md_circle_medium .. " " },
	}),
	window_maximize_hover = wezterm.format({
		{ Background = { Color = STATUS_BAR_BG } },
		{ Foreground = { Color = "#00CA4E" } },
		{ Text = wezterm.nerdfonts.md_plus_circle .. " " },
	}),
}

wezterm.on("format-tab-title", function(tab, tabs, panes, config, hover, max_width)
	local pane = tab.active_pane
	local index = tab.tab_index + 1 -- converting 0-based to 1-based
	local cwd = basename(pane.current_working_dir.file_path)
	local process = basename(pane.foreground_process_name)

	local text = string.format("%d:%s❯%s", index, cwd, process)
	config.text_background_opacity = 0.85

	local ACTIVE_BG = "#ea6962"
	local ACTIVE_FG = "#32302f"
	local INACTIVE_BG = "#504945"
	local INACTIVE_FG = "#a89984"

	if tab.is_active then
		return {
			{ Background = { Color = ACTIVE_BG } },
			{ Foreground = { Color = STATUS_BAR_BG } },
			{ Text = EDGE_LEFT },
			{ Background = { Color = ACTIVE_BG } },
			{ Foreground = { Color = ACTIVE_FG } },
			{ Text = text },
			{ Background = { Color = ACTIVE_BG } },
			{ Foreground = { Color = STATUS_BAR_BG } },
			{ Text = EDGE_RIGHT },
		}
	else
		return {
			{ Background = { Color = INACTIVE_BG } },
			{ Foreground = { Color = STATUS_BAR_BG } },
			{ Text = EDGE_LEFT },
			{ Background = { Color = INACTIVE_BG } },
			{ Foreground = { Color = INACTIVE_FG } },
			{ Text = text },
			{ Background = { Color = INACTIVE_BG } },
			{ Foreground = { Color = STATUS_BAR_BG } },
			{ Text = EDGE_RIGHT },
		}
	end
end)

-- TODO: add left status bar with current mode and window index
wezterm.on("update-status", function(window, pane)
	-- Mode
	local mode = "NORMAL"
	local key_table = window:active_key_table()
	if key_table == "copy_mode" then
		mode = " COPY "
	elseif key_table == "search_mode" then
		mode = "SEARCH"
	elseif key_table == "quick_select" then -- TODO: This doesn't work. Need to find a way to detect quick select mode
		mode = "SELECT"
	elseif window:leader_is_active() then
		mode = "LEADER"
	end

	local stat_color = "#f7768e"

	-- Current working directory
	local cwd = pane:get_current_working_dir()
	if cwd then
		if type(cwd) == "userdata" then
			-- Wezterm introduced the URL object in 20240127-113634-bbcac864
			cwd = basename(cwd.file_path)
		else
			-- 20230712-072601-f4abf8fd or earlier version
			cwd = basename(cwd)
		end
	else
		cwd = ""
	end

	-- Current command
	local cmd = pane:get_foreground_process_name()
	-- CWD and CMD could be nil (e.g. viewing log using Ctrl-Alt-l)
	cmd = cmd and basename(cmd) or ""

	local time = wezterm.strftime("%H:%M")

	-- Left Status
	window:set_left_status(wezterm.format({
		{ Foreground = { Color = stat_color } },
		{ Text = " " .. mode .. " " },
	}))

	-- Right Status
	window:set_right_status(wezterm.format({
		{ Text = wezterm.nerdfonts.md_folder .. "  " .. cwd },
		{ Text = " | " },
		{ Foreground = { Color = "#e0af68" } },
		{ Text = wezterm.nerdfonts.fa_code .. "  " .. cmd },
		"ResetAttributes",
		{ Text = " | " },
		{ Text = wezterm.nerdfonts.md_clock .. "  " .. time },
		{ Text = "  " },
	}))
end)

-- TODO: change right status bar style and formatting to include tab_index:pane_index
-- Right Status Bar
-- wezterm.on("update-right-status", function(window, pane)
-- 	-- Each element holds the text for a cell in a "powerline" style << fade
-- 	local cells = {}
--
-- 	-- Figure out the cwd and host of the current pane.
-- 	-- This will pick up the hostname for the remote host if your
-- 	-- shell is using OSC 7 on the remote host.
-- 	local cwd_uri = pane:get_current_working_dir()
-- 	if cwd_uri then
-- 		local cwd = ""
-- 		local hostname = ""
--
-- 		if type(cwd_uri) == "userdata" then
-- 			cwd = cwd_uri.file_path
-- 			hostname = cwd_uri.host or wezterm.hostname()
-- 		end
--
-- 		-- Remove the domain name portion of the hostname
-- 		local dot = hostname:find("[.]")
-- 		if dot then
-- 			hostname = hostname:sub(1, dot - 1)
-- 		end
-- 		if hostname == "" then
-- 			hostname = wezterm.hostname()
-- 		end
--
-- 		table.insert(cells, cwd)
-- 		table.insert(cells, hostname)
-- 	end
--
-- 	-- I like my date/time in this style: "Wed Mar 3 08:14"
-- 	local date = wezterm.strftime("%a %b %-d %H:%M")
-- 	table.insert(cells, date)
--
-- 	-- An entry for each battery (typically 0 or 1 battery)
-- 	for _, b in ipairs(wezterm.battery_info()) do
-- 		table.insert(cells, string.format("%.0f%%", b.state_of_charge * 100))
-- 	end
--
-- 	-- The powerline < symbol
-- 	local LEFT_ARROW = utf8.char(0xe0b3)
-- 	-- The filled in variant of the < symbol
-- 	local SOLID_LEFT_ARROW = utf8.char(0xe0b2)
--
-- 	-- Color palette for the backgrounds of each cell
-- 	local colors = {
-- 		"#3c1361",
-- 		"#52307c",
-- 		"#663a82",
-- 		"#7c5295",
-- 		"#b491c8",
-- 	}
--
-- 	-- Foreground color for the text across the fade
-- 	local text_fg = "#c0c0c0"
--
-- 	-- The elements to be formatted
-- 	local elements = {}
-- 	-- How many cells have been formatted
-- 	local num_cells = 0
--
-- 	-- Translate a cell into elements
-- 	function push(text, is_last)
-- 		local cell_no = num_cells + 1
-- 		table.insert(elements, { Foreground = { Color = text_fg } })
-- 		table.insert(elements, { Background = { Color = colors[cell_no] } })
-- 		table.insert(elements, { Text = " " .. text .. " " })
-- 		if not is_last then
-- 			table.insert(elements, { Foreground = { Color = colors[cell_no + 1] } })
-- 			table.insert(elements, { Text = SOLID_LEFT_ARROW })
-- 		end
-- 		num_cells = num_cells + 1
-- 	end
--
-- 	while #cells > 0 do
-- 		local cell = table.remove(cells, 1)
-- 		push(cell, #cells == 0)
-- 	end
--
-- 	window:set_right_status(wezterm.format(elements))
-- end)

-- Theme https://wezfurlong.org/wezterm/colorschemes/g/index.html#gruvbox-material-gogh
config.color_scheme = "Gruvbox Material (Gogh)"
config.colors = {
	tab_bar = {
		-- background = "#282828", -- main terminal background
	},
}

-- Plugins
wezterm.plugin.require("https://github.com/mrjones2014/smart-splits.nvim").apply_to_config(config, {
	direction_keys = { "h", "j", "k", "l" },
	modifiers = {
		move = "CTRL",
		resize = "META",
	},
})

return config
