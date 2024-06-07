-- Mode Docs
-- https://wezfurlong.org/wezterm/quickselect.html
-- https://wezfurlong.org/wezterm/copymode.html

-- Config Docs
-- https://wezfurlong.org/wezterm/config/files.html

-- Pull in the wezterm API
local wezterm = require("wezterm")
-- This will hold the configuration.
local config = wezterm.config_builder()

local is_windows = wezterm.target_triple:find("windows") ~= nil
if is_windows then
	config.default_prog = { "zsh" }
end

-- Window
config.use_fancy_tab_bar = false
config.enable_tab_bar = is_windows and true or false
config.window_decorations = is_windows and "INTEGRATED_BUTTONS|RESIZE" or "RESIZE"
config.window_padding = {
	left = 0,
	right = 0,
	top = 0,
	bottom = 0,
}

-- Font
config.font_size = 16
config.font = wezterm.font("JetBrainsMono Nerd Font Mono", { weight = "Regular" })

-- Theme
-- https://wezfurlong.org/wezterm/colorschemes/g/index.html#gruvbox-material-gogh
config.color_scheme = "Gruvbox Material (Gogh)"
config.colors = {
	tab_bar = {
		-- The color of the strip that goes along the top of the window
		background = "#282828", -- main terminal background

		-- The active tab is the one that has focus in the window
		active_tab = {
			bg_color = "#504945", -- bg_statusline3
			fg_color = "#d4be98", -- fg0
			intensity = "Normal",
			underline = "None",
			italic = true,
			strikethrough = false,
		},

		-- Inactive tabs are the tabs that do not have focus
		inactive_tab = {
			bg_color = "#3a3735", -- bg_statusline2
			fg_color = "#a89984", -- grey2
			intensity = "Normal",
			underline = "None",
			italic = false,
			strikethrough = false,
		},

		-- You can configure some alternate styling when the mouse pointer
		-- moves over inactive tabs
		inactive_tab_hover = {
			bg_color = "#374141", -- bg_visual_blue
			fg_color = "#ddc7a1", -- fg1
			italic = false,
			intensity = "Normal",
			underline = "None",
			strikethrough = false,
		},

		-- The new tab button that lets you create new tabs
		new_tab = {
			bg_color = "#3a3735", -- bg_statusline2
			fg_color = "#a89984", -- grey2
			intensity = "Normal",
			underline = "None",
			italic = false,
			strikethrough = false,
		},

		-- You can configure some alternate styling when the mouse pointer
		-- moves over the new tab button
		new_tab_hover = {
			bg_color = "#374141", -- bg_visual_blue
			fg_color = "#ddc7a1", -- fg1
			italic = false,
			intensity = "Normal",
			underline = "None",
			strikethrough = false,
		},
	},
}

-- Return the configuration to wezterm
return config
