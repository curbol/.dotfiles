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
local resurrect = wezterm.plugin.require("https://github.com/MLFlexer/resurrect.wezterm")

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

-- Keybindings
config.leader = { key = "Space", mods = "CTRL", timeout_milliseconds = 1000 }

-- Equalize all panes so that each column gets equal width and each row within a
-- column gets equal height. At each vsplit, the weight is the number of distinct
-- column groups in each subtree (so horizontal splits inside a column don't inflate
-- that column's share). At each hsplit, weight is the number of distinct row groups.
-- This matches what you'd get from an N-ary equal-split layout.
local function equalize_panes()
	return wezterm.action_callback(function(window, pane)
		local tab = window:active_tab()
		local panes = tab:panes_with_info()
		if #panes <= 1 then
			return
		end

		local active_idx = 0
		for _, pi in ipairs(panes) do
			if pi.is_active then
				active_idx = pi.index
			end
		end

		-- Reconstruct the binary split tree from pane positions.
		-- At each level, find a horizontal or vertical line that cleanly partitions
		-- the pane set into two non-overlapping groups, then recurse.
		local function build_tree(ps)
			if #ps == 1 then
				return { type = "pane", pane = ps[1], width = ps[1].width, height = ps[1].height }
			end

			-- Try vertical split candidates (sorted left→right for consistent results)
			local xs = {}
			for _, p in ipairs(ps) do
				xs[p.left + p.width] = true
			end
			local xs_sorted = {}
			for x in pairs(xs) do
				table.insert(xs_sorted, x)
			end
			table.sort(xs_sorted)
			for _, x in ipairs(xs_sorted) do
				local left_ps, right_ps = {}, {}
				for _, p in ipairs(ps) do
					if p.left + p.width <= x then
						table.insert(left_ps, p)
					elseif p.left >= x then
						table.insert(right_ps, p)
					end
				end
				if #left_ps + #right_ps == #ps and #left_ps > 0 and #right_ps > 0 then
					local lc = build_tree(left_ps)
					local rc = build_tree(right_ps)
					return { type = "vsplit", left_child = lc, right_child = rc,
					         width = lc.width + rc.width, height = lc.height }
				end
			end

			-- Try horizontal split candidates (sorted top→bottom)
			local ys = {}
			for _, p in ipairs(ps) do
				ys[p.top + p.height] = true
			end
			local ys_sorted = {}
			for y in pairs(ys) do
				table.insert(ys_sorted, y)
			end
			table.sort(ys_sorted)
			for _, y in ipairs(ys_sorted) do
				local top_ps, bot_ps = {}, {}
				for _, p in ipairs(ps) do
					if p.top + p.height <= y then
						table.insert(top_ps, p)
					elseif p.top >= y then
						table.insert(bot_ps, p)
					end
				end
				if #top_ps + #bot_ps == #ps and #top_ps > 0 and #bot_ps > 0 then
					local tc = build_tree(top_ps)
					local bc = build_tree(bot_ps)
					return { type = "hsplit", top_child = tc, bot_child = bc,
					         width = tc.width, height = tc.height + bc.height }
				end
			end

			return { type = "pane", pane = ps[1], width = ps[1].width, height = ps[1].height }
		end

		-- For a vsplit resize, activate the pane in the LEFT subtree whose right edge
		-- sits at the split boundary. AdjustPaneSize("Right"/"Left") on it moves that boundary.
		local function rightmost_pane(node)
			if node.type == "pane" then return node.pane end
			if node.type == "vsplit" then return rightmost_pane(node.right_child) end
			return rightmost_pane(node.top_child) -- hsplit: either child shares the right edge
		end

		-- For an hsplit resize, activate the pane in the TOP subtree whose bottom edge
		-- sits at the split boundary.
		local function bottommost_pane(node)
			if node.type == "pane" then return node.pane end
			if node.type == "hsplit" then return bottommost_pane(node.bot_child) end
			return bottommost_pane(node.left_child) -- vsplit: either child shares the bottom edge
		end

		-- Count distinct column groups (vsplit branches) in a subtree.
		-- Hsplit nodes and leaves each count as 1 — they occupy a single column group
		-- and horizontal splits within a column shouldn't widen that column.
		local function count_columns(node)
			if node.type == "vsplit" then
				return count_columns(node.left_child) + count_columns(node.right_child)
			else
				return 1
			end
		end

		-- Count distinct row groups (hsplit branches) in a subtree.
		-- Vsplit nodes and leaves each count as 1.
		local function count_rows(node)
			if node.type == "hsplit" then
				return count_rows(node.top_child) + count_rows(node.bot_child)
			else
				return 1
			end
		end

		-- Walk the tree top-down, weighting each vsplit by column count and each hsplit
		-- by row count. This gives equal width to each logical column and equal height to
		-- each logical row within a column, regardless of how many panes are stacked inside.
		--
		-- scale_x / scale_y: multiply stale pane dimensions by these factors to get the
		-- expected current size, accounting for all ancestor resizes already queued.
		-- Since perform_action is async, pane sizes from panes_with_info() are stale;
		-- we track how they scale as parents are resized and propagate that to children.
		local function equalize_node(node, scale_x, scale_y)
			if node.type == "pane" then
				return
			end

			if node.type == "vsplit" then
				local lc, rc = node.left_child, node.right_child
				local l_cols = count_columns(lc)
				local r_cols = count_columns(rc)
				local cur_l = lc.width * scale_x
				local cur_r = rc.width * scale_x
				local target_l = (cur_l + cur_r) * l_cols / (l_cols + r_cols)
				local adj = math.floor(cur_l) - math.floor(target_l)
				local rep = rightmost_pane(lc)
				window:perform_action(action.ActivatePaneByIndex(rep.index), tab:active_pane())
				if adj > 0 then
					window:perform_action(action.AdjustPaneSize({ "Left", adj }), tab:active_pane())
				elseif adj < 0 then
					window:perform_action(action.AdjustPaneSize({ "Right", -adj }), tab:active_pane())
				end
				equalize_node(lc, target_l / lc.width, scale_y)
				equalize_node(rc, (cur_l + cur_r - target_l) / rc.width, scale_y)

			elseif node.type == "hsplit" then
				local tc, bc = node.top_child, node.bot_child
				local t_rows = count_rows(tc)
				local b_rows = count_rows(bc)
				local cur_t = tc.height * scale_y
				local cur_b = bc.height * scale_y
				local target_t = (cur_t + cur_b) * t_rows / (t_rows + b_rows)
				local adj = math.floor(cur_t) - math.floor(target_t)
				local rep = bottommost_pane(tc)
				window:perform_action(action.ActivatePaneByIndex(rep.index), tab:active_pane())
				if adj > 0 then
					window:perform_action(action.AdjustPaneSize({ "Up", adj }), tab:active_pane())
				elseif adj < 0 then
					window:perform_action(action.AdjustPaneSize({ "Down", -adj }), tab:active_pane())
				end
				equalize_node(tc, scale_x, target_t / tc.height)
				equalize_node(bc, scale_x, (cur_t + cur_b - target_t) / bc.height)
			end
		end

		local tree = build_tree(panes)
		equalize_node(tree, 1, 1)
		window:perform_action(action.ActivatePaneByIndex(active_idx), tab:active_pane())
	end)
end

-- Split and equalize all panes in the current tab
local function split_and_equalize(direction)
	return wezterm.action_callback(function(window, pane)
		local tab = window:active_tab()
		local n = #tab:panes()
		local fraction = 1.0 / (n + 1)
		if direction == "vertical" then
			window:perform_action(
				action.SplitPane({ direction = "Down", size = { Percent = math.floor(fraction * 100) } }),
				pane
			)
		else
			window:perform_action(
				action.SplitPane({ direction = "Right", size = { Percent = math.floor(fraction * 100) } }),
				pane
			)
		end
	end)
end

config.keys = {
	-- Wezterm pane navigation (cmd+arrows)
	{ key = "LeftArrow", mods = "SUPER", action = action.ActivatePaneDirection("Left") },
	{ key = "RightArrow", mods = "SUPER", action = action.ActivatePaneDirection("Right") },
	{ key = "UpArrow", mods = "SUPER", action = action.ActivatePaneDirection("Up") },
	{ key = "DownArrow", mods = "SUPER", action = action.ActivatePaneDirection("Down") },

	-- Pass ctrl+shift+arrows through to the terminal (nvim window move/mini.move).
	-- WezTerm defaults bind these to ActivatePaneDirection; SendString bypasses the pipeline.
	-- Sequences: \x1b[1;6A/B/C/D = ctrl+shift+up/down/right/left (VT modifier 6 = ctrl+shift)
	{ key = "LeftArrow", mods = "CTRL|SHIFT", action = action.SendString("\x1b[1;6D") },
	{ key = "RightArrow", mods = "CTRL|SHIFT", action = action.SendString("\x1b[1;6C") },
	{ key = "UpArrow", mods = "CTRL|SHIFT", action = action.SendString("\x1b[1;6A") },
	{ key = "DownArrow", mods = "CTRL|SHIFT", action = action.SendString("\x1b[1;6B") },

	-- Wezterm tab jump (cmd+[1-9])
	{ key = "1", mods = "SUPER", action = action.ActivateTab(0) },
	{ key = "2", mods = "SUPER", action = action.ActivateTab(1) },
	{ key = "3", mods = "SUPER", action = action.ActivateTab(2) },
	{ key = "4", mods = "SUPER", action = action.ActivateTab(3) },
	{ key = "5", mods = "SUPER", action = action.ActivateTab(4) },
	{ key = "6", mods = "SUPER", action = action.ActivateTab(5) },
	{ key = "7", mods = "SUPER", action = action.ActivateTab(6) },
	{ key = "8", mods = "SUPER", action = action.ActivateTab(7) },
	{ key = "9", mods = "SUPER", action = action.ActivateTab(8) },

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

	-- Leader: utility
	{ key = "phys:Space", mods = "LEADER", action = action.QuickSelect },
	{ key = ":", mods = "LEADER", action = action.ActivateCommandPalette },
	{ key = "/", mods = "LEADER", action = action.Search("CurrentSelectionOrEmptyString") },
	{ key = "a", mods = "LEADER", action = action.ActivateLastTab },
	{ key = "a", mods = "LEADER|CTRL", action = action.ActivateLastTab },
	{ key = "y", mods = "LEADER", action = action.ActivateCopyMode },

	-- Leader: management (matching nvim space+w vocabulary)
	{ key = "s", mods = "LEADER", action = split_and_equalize("vertical") },
	{ key = "v", mods = "LEADER", action = split_and_equalize("horizontal") },
	{ key = "t", mods = "LEADER", action = action.SpawnTab("CurrentPaneDomain") },
	{ key = "q", mods = "LEADER", action = action.CloseCurrentPane({ confirm = false }) },
	{
		key = "d",
		mods = "LEADER",
		action = action.Multiple({
			action.CloseCurrentTab({ confirm = false }),
			action.ActivateTabRelative(1), -- keep last-active tab tracking working
			action.ActivateTabRelative(-1),
		}),
	},
	{ key = "x", mods = "LEADER", action = action.PaneSelect({ mode = "SwapWithActive" }) },
	{ key = "m", mods = "LEADER", action = action.TogglePaneZoomState },
	{ key = "[", mods = "LEADER", action = action.ActivateTabRelative(-1) },
	{ key = "]", mods = "LEADER", action = action.ActivateTabRelative(1) },
	{ key = "{", mods = "LEADER|SHIFT", action = action.MoveTabRelative(-1) },
	{ key = "}", mods = "LEADER|SHIFT", action = action.MoveTabRelative(1) },
	{ key = "=", mods = "LEADER", action = equalize_panes() },
	{
		key = "o",
		mods = "LEADER",
		action = wezterm.action_callback(function(window, pane)
			local tab = window:active_tab()
			local active_id = pane:pane_id()
			for _, pi in ipairs(tab:panes_with_info()) do
				if pi.pane:pane_id() ~= active_id then
					window:perform_action(action.CloseCurrentPane({ confirm = false }), pi.pane)
				end
			end
		end),
	},

	-- Leader: enter resize key table (hold arrows to resize, auto-exits after 1s)
	{
		key = "r",
		mods = "LEADER",
		action = action.ActivateKeyTable({
			name = "resize_pane",
			one_shot = false,
			timeout_milliseconds = 1000,
		}),
	},
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
	resize_pane = {
		{ key = "LeftArrow", mods = "NONE", action = action.AdjustPaneSize({ "Left", 5 }) },
		{ key = "RightArrow", mods = "NONE", action = action.AdjustPaneSize({ "Right", 5 }) },
		{ key = "UpArrow", mods = "NONE", action = action.AdjustPaneSize({ "Up", 5 }) },
		{ key = "DownArrow", mods = "NONE", action = action.AdjustPaneSize({ "Down", 5 }) },
		{ key = "Escape", mods = "NONE", action = action.PopKeyTable },
	},
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
	saturation = 0.9,
	brightness = 0.7,
}

-- Mouse
config.mouse_bindings = {
	{
		event = { Down = { streak = 1, button = "Middle" } },
		mods = "NONE",
		action = action.CloseCurrentTab({ confirm = false }),
	},
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
	local cwd = pane.current_working_dir and basename(pane.current_working_dir.file_path) or "?"
	local process = pane.foreground_process_name and basename(pane.foreground_process_name) or "?"

	local text = string.format("%d:%s❯%s", index, cwd, process)

	local ACTIVE_BG = GRUVBOX_ORANGE
	local ACTIVE_FG = STATUS_BAR_BG
	local INACTIVE_BG = GRUVBOX_GREY3
	local INACTIVE_FG = GRUVBOX_GREY4

	if tab.is_active then
		return {
			{ Background = { Color = ACTIVE_BG } },
			{ Foreground = { Color = ACTIVE_FG } },
			{ Text = EDGE_LEFT },
			{ Background = { Color = ACTIVE_BG } },
			{ Foreground = { Color = ACTIVE_FG } },
			{ Text = text },
			{ Background = { Color = ACTIVE_BG } },
			{ Foreground = { Color = ACTIVE_FG } },
			{ Text = EDGE_RIGHT },
		}
	else
		return {
			{ Background = { Color = INACTIVE_BG } },
			{ Foreground = { Color = INACTIVE_FG } },
			{ Text = EDGE_LEFT },
			{ Background = { Color = INACTIVE_BG } },
			{ Foreground = { Color = INACTIVE_FG } },
			{ Text = text },
			{ Background = { Color = INACTIVE_BG } },
			{ Foreground = { Color = INACTIVE_FG } },
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

	-- Window:Tab:Pane
	local mux_window = window:mux_window()
	local active_tab = mux_window:active_tab()
	local all_windows = wezterm.mux.all_windows()
	local all_tabs = mux_window:tabs()
	local all_panes = active_tab:panes()

	local function fmt_index(idx, total)
		if not idx then return "?" end
		return total > 1 and (idx .. "/" .. total) or tostring(idx)
	end

	local win_idx, tab_idx, pane_idx
	local pane_id = pane:pane_id()
	local win_id = mux_window:window_id()
	local tab_id = active_tab:tab_id()
	for i, w in ipairs(all_windows) do
		if w:window_id() == win_id then win_idx = i; break end
	end
	for i, t in ipairs(all_tabs) do
		if t:tab_id() == tab_id then tab_idx = i; break end
	end
	for i, p in ipairs(all_panes) do
		if p:pane_id() == pane_id then pane_idx = i; break end
	end

	local window_index = fmt_index(win_idx, #all_windows)
	local tab_index = fmt_index(tab_idx, #all_tabs)
	local pane_index = fmt_index(pane_idx, #all_panes)

	-- Time
	local datetime = wezterm.strftime("%a %b %-d %H:%M")
	window:set_right_status(wezterm.format({
		{ Foreground = { Color = GRUVBOX_GREEN } },
		{ Text = wezterm.nerdfonts.md_alpha_w_box_outline .. " " .. window_index },
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

-- Session persistence (resurrect)
-- State files saved to ~/Library/Application Support/wezterm/plugins/.../state/
resurrect.state_manager.periodic_save({
	interval_seconds = 300,
	save_workspaces = true,
	save_windows = true,
	save_tabs = true,
})
-- Write the current_state pointer file after each periodic save so
-- resurrect_on_gui_startup knows which workspace to restore on next launch.
wezterm.on("resurrect.state_manager.periodic_save.finished", function()
	resurrect.state_manager.write_current_state(wezterm.mux.get_active_workspace(), "workspace")
end)
wezterm.on("gui-shutdown", function()
	local workspace = wezterm.mux.get_active_workspace()
	resurrect.state_manager.save_state(require("resurrect.workspace_state").get_workspace_state())
	resurrect.state_manager.write_current_state(workspace, "workspace")
end)
wezterm.on("gui-startup", resurrect.state_manager.resurrect_on_gui_startup)

return config
