# shellcheck shell=bash
# Default Theme: https://github.com/erikw/tmux-powerline/blob/main/themes/default.sh
# If changes made here does not take effect, then try to re-create the tmux session to force reload.

## Gruvbox Material Palette (https://github.com/sainnhe/gruvbox-material/blob/master/autoload/gruvbox_material.vim)
## Greys
# 'grey0':            ['#7c6f64',   '243'],
# 'grey1':            ['#928374',   '245'],
# 'grey2':            ['#a89984',   '246'],
## Background
# 'bg_dim':           ['#1b1b1b',   '233'],
# 'bg0':              ['#282828',   '235'],
# 'bg1':              ['#32302f',   '236'],
# 'bg2':              ['#32302f',   '236'],
# 'bg3':              ['#45403d',   '237'],
# 'bg4':              ['#45403d',   '237'],
# 'bg5':              ['#5a524c',   '239'],
# 'bg_statusline1':   ['#32302f',   '236'],
# 'bg_statusline2':   ['#3a3735',   '236'],
# 'bg_statusline3':   ['#504945',   '240'],
# 'bg_diff_red':      ['#402120',   '52'],
# 'bg_diff_green':    ['#34381b',   '22'],
# 'bg_diff_blue':     ['#0e363e',   '17'],
# 'bg_visual_red':    ['#4c3432',   '52'],
# 'bg_visual_yellow': ['#4f422e',   '94'],
# 'bg_visual_green':  ['#3b4439',   '22'],
# 'bg_visual_blue':   ['#374141',   '17'],
# 'bg_current_word':  ['#3c3836',   '237']
## Forground
# 'fg0':              ['#d4be98',   '223'],
# 'fg1':              ['#ddc7a1',   '223'],
# 'red':              ['#ea6962',   '167'],
# 'orange':           ['#e78a4e',   '208'],
# 'yellow':           ['#d8a657',   '214'],
# 'green':            ['#a9b665',   '142'],
# 'aqua':             ['#89b482',   '108'],
# 'blue':             ['#7daea3',   '109'],
# 'purple':           ['#d3869b',   '175'],
# 'bg_red':           ['#ea6962',   '167'],
# 'bg_green':         ['#a9b665',   '142'],
# 'bg_yellow':        ['#d8a657',   '214']

## Lualine Gruvbox Material (https://github.com/nvim-lualine/lualine.nvim/blob/master/lua/lualine/themes/gruvbox-material.lua)
GRUVBOX_MATERIAL_GREY1="#282828"
GRUVBOX_MATERIAL_GREY2="#32302f"
GRUVBOX_MATERIAL_GREY3="#504945"
GRUVBOX_MATERIAL_GREY4="#a89984"
GRUVBOX_MATERIAL_GREY5="#ddc7a1"

GRUVBOX_MATERIAL_RED="#ea6962"
GRUVBOX_MATERIAL_ORANGE="#e78a4e"
GRUVBOX_MATERIAL_YELLOW="#d8a657"
GRUVBOX_MATERIAL_GREEN="#a9b665"
GRUVBOX_MATERIAL_AQUA="#89b482"
GRUVBOX_MATERIAL_BLUE="#7daea3"
GRUVBOX_MATERIAL_PURPLE="#d3869b"

TMUX_POWERLINE_SEPARATOR_LEFT_BOLD=""
TMUX_POWERLINE_SEPARATOR_LEFT_THIN=""
TMUX_POWERLINE_SEPARATOR_RIGHT_BOLD=""
TMUX_POWERLINE_SEPARATOR_RIGHT_THIN=""
TMUX_POWERLINE_SEPARATOR_THIN="│"

TMUX_POWERLINE_DEFAULT_LEFTSIDE_SEPARATOR=${TMUX_POWERLINE_DEFAULT_LEFTSIDE_SEPARATOR:-$TMUX_POWERLINE_SEPARATOR_RIGHT_BOLD}
TMUX_POWERLINE_DEFAULT_RIGHTSIDE_SEPARATOR=${TMUX_POWERLINE_DEFAULT_RIGHTSIDE_SEPARATOR:-$TMUX_POWERLINE_SEPARATOR_LEFT_BOLD}

tmux set -g status-bg "$GRUVBOX_MATERIAL_GREY2"
TMUX_POWERLINE_DEFAULT_BACKGROUND_COLOR=${TMUX_POWERLINE_DEFAULT_BACKGROUND_COLOR:-$GRUVBOX_MATERIAL_GREY2}
TMUX_POWERLINE_DEFAULT_FOREGROUND_COLOR=${TMUX_POWERLINE_DEFAULT_FOREGROUND_COLOR:-$GRUVBOX_MATERIAL_GREY5}

TMUX_OUTER_1_BACKGROUND_COLOR=$GRUVBOX_MATERIAL_ORANGE
TMUX_OUTER_1_FOREGROUND_COLOR=$GRUVBOX_MATERIAL_GREY2
TMUX_OUTER_2_BACKGROUND_COLOR=$GRUVBOX_MATERIAL_GREY3
TMUX_OUTER_2_FOREGROUND_COLOR=$GRUVBOX_MATERIAL_GREY5

# See `man tmux` for additional formatting options for the status line.
# The `format regular` and `format inverse` functions are provided as conveniences

# shellcheck disable=SC2128
if [ -z "$TMUX_POWERLINE_WINDOW_STATUS_CURRENT" ]; then
	TMUX_POWERLINE_WINDOW_STATUS_CURRENT=(
		"#[$(format regular)]"
		"#[bold,italics,fg=${GRUVBOX_MATERIAL_ORANGE}]"
		" #F[#I]#W  "
	)
fi

# shellcheck disable=SC2128
if [ -z "$TMUX_POWERLINE_WINDOW_STATUS_STYLE" ]; then
	TMUX_POWERLINE_WINDOW_STATUS_STYLE=(
		"#[$(format regular)]"
	)
fi

# shellcheck disable=SC2128
if [ -z "$TMUX_POWERLINE_WINDOW_STATUS_FORMAT" ]; then
	TMUX_POWERLINE_WINDOW_STATUS_FORMAT=(
		"#[$(format regular)]"
		"#[dim]"
		" #{?window_flags,#F, }[#I]#W  "
	)
fi

# Format: segment_name background_color foreground_color [non_default_separator] [separator_background_color] [separator_foreground_color] [spacing_disable] [separator_disable]
#
# * background_color and foreground_color. Color formatting (see `man tmux` for complete list):
#   * Named colors, e.g. black, red, green, yellow, blue, magenta, cyan, white
#   * Hexadecimal RGB string e.g. #ffffff
#   * 'default' for the default tmux color.
#   * 'terminal' for the terminal's default background/foreground color
#   * The numbers 0-255 for the 256-color palette. Run `tmux-powerline/color-palette.sh` to see the colors.
# * non_default_separator - specify an alternative character for this segment's separator
# * separator_background_color - specify a unique background color for the separator
# * separator_foreground_color - specify a unique foreground color for the separator
# * spacing_disable - remove space on left, right or both sides of the segment:
#   * "left_disable" - disable space on the left
#   * "right_disable" - disable space on the right
#   * "both_disable" - disable spaces on both sides
#   * - any other character/string produces no change to default behavior (eg "none", "X", etc.)
#
# * separator_disable - disables drawing a separator on this segment, very useful for segments
#   with dynamic background colours (eg tmux_mem_cpu_load):
#   * "separator_disable" - disables the separator
#   * - any other character/string produces no change to default behavior
#
# Example segment with separator disabled and right space character disabled:
# "hostname 33 0 {TMUX_POWERLINE_SEPARATOR_RIGHT_BOLD} 33 0 right_disable separator_disable"
#
# Note that although redundant the non_default_separator, separator_background_color and
# separator_foreground_color options must still be specified so that appropriate index
# of options to support the spacing_disable and separator_disable features can be used

# shellcheck disable=SC1143,SC2128
if [ -z "$TMUX_POWERLINE_LEFT_STATUS_SEGMENTS" ]; then
	TMUX_POWERLINE_LEFT_STATUS_SEGMENTS=(
		"custom_mode ${TMUX_OUTER_1_BACKGROUND_COLOR} ${TMUX_OUTER_1_FOREGROUND_COLOR}"
		"tmux_session_info ${TMUX_OUTER_2_BACKGROUND_COLOR} ${TMUX_OUTER_2_FOREGROUND_COLOR}"
		# "hostname"
		# "pwd 89 211"
	)
fi

# shellcheck disable=SC1143,SC2128
if [ -z "$TMUX_POWERLINE_RIGHT_STATUS_SEGMENTS" ]; then
	TMUX_POWERLINE_RIGHT_STATUS_SEGMENTS=(
		# "date_day 235 136"
		# "date default ${GRUVBOX_MATERIAL_YELLOW} ${TMUX_POWERLINE_SEPARATOR_LEFT_THIN} default default"
		"custom_weather"
		"custom_session_info ${TMUX_OUTER_2_BACKGROUND_COLOR} ${TMUX_OUTER_2_FOREGROUND_COLOR}"
		"time ${TMUX_OUTER_1_BACKGROUND_COLOR} ${TMUX_OUTER_1_FOREGROUND_COLOR}"
		# "utc_time 235 136 ${TMUX_POWERLINE_SEPARATOR_LEFT_THIN}"
	)
fi
