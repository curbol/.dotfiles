-- Mode Docs
-- https://wezfurlong.org/wezterm/quickselect.html
-- https://wezfurlong.org/wezterm/copymode.html

-- Config Docs
-- https://wezfurlong.org/wezterm/config/files.html

-- Pull in the wezterm API
local wezterm = require("wezterm")
-- This will hold the configuration.
local config = wezterm.config_builder()

local target_triple = wezterm.target_triple
local is_windows = target_triple:find("windows") ~= nil

if is_windows then
	config.default_prog = { "zsh" }
end

-- Window
config.use_fancy_tab_bar = false
config.enable_tab_bar = false
config.window_decorations = is_windows and "TITLE | RESIZE" or "RESIZE"
config.window_close_confirmation = "AlwaysPrompt"
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

-- Return the configuration to wezterm
return config
