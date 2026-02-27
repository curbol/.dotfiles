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
-- local SEPARATOR_LEFT_BOLD = ""
-- local SEPARATOR_LEFT_THIN = ""
-- local SEPARATOR_RIGHT_BOLD = ""
-- local SEPARATOR_RIGHT_THIN = ""
local SEPARATOR_THIN = "│"

local EDGE_LEFT = "▌"
local EDGE_RIGHT = "▐"

-- Windows specific settings
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

-- Get the 1-based index of the window
local function get_window_index(window_id)
	-- https://wezfurlong.org/wezterm/config/lua/wezterm.mux/index.html
	for i, item in ipairs(wezterm.mux.all_windows()) do
		if item:window_id() == window_id then
			return i
		end
	end
	return nil
end

-- Get the 1-based index of the tab
local function get_tab_index(window, tab_id)
	-- https://wezfurlong.org/wezterm/config/lua/mux-window/tabs_with_info.html
	for _, item in ipairs(window:tabs_with_info()) do
		if item.tab:tab_id() == tab_id then
			return item.index + 1
		end
	end
end

-- Get the 1-based index of the pane
local function get_pane_index(tab, pane_id)
	-- https://wezfurlong.org/wezterm/config/lua/MuxTab/panes_with_info.html
	for _, item in ipairs(tab:panes_with_info()) do
		if item.pane:pane_id() == pane_id then
			return item.index + 1
		end
	end
end

-- Keybindings
config.leader = { key = "a", mods = "CTRL", timeout_milliseconds = 1000 }
config.keys = {
	-- Fix image paste (https://github.com/wezterm/wezterm/issues/7272):
	-- WezTerm's default Cmd+V only pastes text, silently dropping image-only clipboard.
	-- Send raw \x16 instead so apps like Claude Code can read the image from the OS clipboard.
	{
		key = "v",
		mods = "SUPER",
		action = wezterm.action_callback(function(window, pane)
			local ok, stdout, _ = wezterm.run_child_process({ "pbpaste" })
			if ok and stdout and #stdout > 0 then
				window:perform_action(action.PasteFrom("Clipboard"), pane)
			else
				window:perform_action(action.SendString("\x16"), pane)
			end
		end),
	},
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
	{
		key = "x",
		mods = "LEADER",
		action = action.Multiple({
			action.CloseCurrentTab({ confirm = false }),
			action.ActivateTabRelative(1), -- Hack to set the last active tab after closing the current one so that leader+a works
			action.ActivateTabRelative(-1),
		}),
	},
	{ key = "n", mods = "LEADER", action = action.ActivateTabRelative(1) },
	{ key = "n", mods = "LEADER|CTRL", action = action.ActivateTabRelative(1) },
	{ key = "p", mods = "LEADER", action = action.ActivateTabRelative(-1) },
	{ key = "p", mods = "LEADER|CTRL", action = action.ActivateTabRelative(-1) },
	{ key = "[", mods = "LEADER", action = action.MoveTabRelative(-1) },
	{ key = "[", mods = "LEADER|CTRL", action = action.MoveTabRelative(-1) },
	{ key = "]", mods = "LEADER", action = action.MoveTabRelative(1) },
	{ key = "]", mods = "LEADER|CTRL", action = action.MoveTabRelative(1) },
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

-- Clear copy mode selection after yanking
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

-- Keyboard
config.enable_kitty_keyboard = true

-- Font
-- config.font = wezterm.font("JetBrainsMono Nerd Font Mono", { weight = "Regular" })
config.font = wezterm.font("Maple Mono NF", { weight = "Regular" })
config.font_size = 15

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
config.tab_max_width = 32
config.use_fancy_tab_bar = false
config.switch_to_last_active_tab_when_closing_tab = true

config.integrated_title_buttons = { "Close", "Hide", "Maximize" }
config.integrated_title_button_alignment = "Left"
config.integrated_title_button_style = "Windows"

config.tab_bar_style = {
	window_close = wezterm.format({
		{ Background = { Color = STATUS_BAR_BG } },
		{ Foreground = { Color = "#FF605C" } },
		{ Text = " " .. wezterm.nerdfonts.md_record_circle .. " " },
	}),
	window_close_hover = wezterm.format({
		{ Background = { Color = STATUS_BAR_BG } },
		{ Foreground = { Color = "#FF605C" } },
		{ Text = " " .. wezterm.nerdfonts.md_close_circle .. " " },
	}),
	window_hide = wezterm.format({
		{ Background = { Color = STATUS_BAR_BG } },
		{ Foreground = { Color = "#FFBD44" } },
		{ Text = wezterm.nerdfonts.md_record_circle .. " " },
	}),
	window_hide_hover = wezterm.format({
		{ Background = { Color = STATUS_BAR_BG } },
		{ Foreground = { Color = "#FFBD44" } },
		{ Text = wezterm.nerdfonts.md_minus_circle .. " " },
	}),
	window_maximize = wezterm.format({
		{ Background = { Color = STATUS_BAR_BG } },
		{ Foreground = { Color = "#00CA4E" } },
		{ Text = wezterm.nerdfonts.md_record_circle .. " " },
	}),
	window_maximize_hover = wezterm.format({
		{ Background = { Color = STATUS_BAR_BG } },
		{ Foreground = { Color = "#00CA4E" } },
		{ Text = wezterm.nerdfonts.md_plus_circle .. " " },
	}),
}

wezterm.on("format-tab-title", function(tab, tabs, panes, conf, hover, max_width)
	local pane = tab.active_pane
	local index = tab.tab_index + 1
	local cwd = basename(pane.current_working_dir.file_path)
	local process = basename(pane.foreground_process_name)

	local text = string.format("%d:%s❯%s", index, cwd, process)

	local ACTIVE_BG = GRUVBOX_ORANGE
	local ACTIVE_FG = STATUS_BAR_BG
	local INACTIVE_BG = GRUVBOX_GREY3
	local INACTIVE_FG = GRUVBOX_GREY4

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

wezterm.on("update-status", function(window, pane)
	-- window: https://wezfurlong.org/wezterm/config/lua/window/index.html
	-- pane: https://wezfurlong.org/wezterm/config/lua/pane/index.html

	-- Mode
	local mode_color = GRUVBOX_GREY5
	local mode = wezterm.nerdfonts.md_code_tags .. " " .. "NORMAL"
	local key_table = window:active_key_table()
	if key_table == "copy_mode" then
		mode_color = GRUVBOX_RED
		mode = wezterm.nerdfonts.md_content_copy .. " " .. " COPY "
	elseif key_table == "search_mode" then
		mode_color = GRUVBOX_YELLOW
		mode = wezterm.nerdfonts.seti_search .. " " .. "SEARCH"
	elseif key_table == "quick_select" then -- TODO: This doesn't work. Need to find a way to detect quick select mode
		mode_color = GRUVBOX_GREEN
		mode = wezterm.nerdfonts.md_select .. " " .. "SELECT"
	elseif window:leader_is_active() then
		mode_color = GRUVBOX_BLUE
		mode = wezterm.nerdfonts.md_cog_outline .. " " .. "LEADER"
	end

	-- Window-:Tab:Pane
	local mux_window = window:mux_window()
	local active_tab = mux_window:active_tab()
	local window_index = get_window_index(mux_window:window_id())
	local tab_index = get_tab_index(mux_window, active_tab:tab_id())
	local pane_index = get_pane_index(active_tab, pane:pane_id())

	-- Time
	local datetime = wezterm.strftime("%a %b %-d %H:%M")

	window:set_left_status(wezterm.format({}))
	window:set_right_status(wezterm.format({
		{ Foreground = { Color = GRUVBOX_GREEN } },
		{ Text = wezterm.nerdfonts.md_alpha_m_box_outline .. " " .. window_index },
		{ Text = " " },
		{ Foreground = { Color = GRUVBOX_BLUE } },
		{ Text = wezterm.nerdfonts.md_alpha_t_box_outline .. " " .. tab_index },
		{ Text = " " },
		{ Foreground = { Color = GRUVBOX_RED } },
		{ Text = wezterm.nerdfonts.md_alpha_p_box_outline .. " " .. pane_index },

		"ResetAttributes",
		{ Text = " " .. SEPARATOR_THIN .. " " },

		{ Foreground = { Color = mode_color } },
		{ Text = mode },

		"ResetAttributes",
		{ Text = " " .. SEPARATOR_THIN .. " " },

		{ Foreground = { Color = GRUVBOX_GREY5 } },
		{ Text = wezterm.nerdfonts.md_clock_outline .. " " .. datetime },

		{ Text = " " },
	}))
end)

-- Theme https://wezfurlong.org/wezterm/colorschemes/g/index.html#gruvbox-material-gogh
config.color_scheme = "Gruvbox Material (Gogh)"
config.colors = {
	tab_bar = {
		-- background = GRUVBOX_GREY1,
	},
}

-- Plugins
wezterm.plugin.require("https://github.com/mrjones2014/smart-splits.nvim").apply_to_config(config)

return config
