# Configuration file for tmux-powerline.

# General {
# Show which segment fails and its exit code.
export TMUX_POWERLINE_DEBUG_MODE_ENABLED="false"
# Use patched font symbols.
export TMUX_POWERLINE_PATCHED_FONT_IN_USE="true"

# The theme to use.
export TMUX_POWERLINE_THEME="gruvbox-material"
# Overlay directory to look for themes. There you can put your own themes outside the repo. Fallback will still be the "themes" directory in the repo.
export TMUX_POWERLINE_DIR_USER_THEMES="${XDG_CONFIG_HOME:-$HOME/.config}/tmux-powerline/themes"
# Overlay directory to look for segments. There you can put your own segments outside the repo. Fallback will still be the "segments" directory in the repo.
export TMUX_POWERLINE_DIR_USER_SEGMENTS="${XDG_CONFIG_HOME:-$HOME/.config}/tmux-powerline/segments"

# The initial visibility of the status bar. Can be {"on", "off", "2"}. 2 will create two status lines: one for the window list and one with status bar segments.
export TMUX_POWERLINE_STATUS_VISIBILITY="on"
# In case of visibility = 2, where to display window status and where left/right status bars.
# 0: window status top, left/right status bottom; 1: window status bottom, left/right status top
export TMUX_POWERLINE_WINDOW_STATUS_LINE=0
# The status bar refresh interval in seconds.
# Note that events that force-refresh the status bar (such as window renaming) will ignore this.
export TMUX_POWERLINE_STATUS_INTERVAL="1"
# The location of the window list. Can be {"absolute-centre, centre, left, right"}.
# Note that "absolute-centre" is only supported on `tmux -V` >= 3.2.
export TMUX_POWERLINE_STATUS_JUSTIFICATION="left"

# The maximum length of the left status bar.
export TMUX_POWERLINE_STATUS_LEFT_LENGTH="60"
# The maximum length of the right status bar.
export TMUX_POWERLINE_STATUS_RIGHT_LENGTH="90"

# The separator to use between windows on the status bar.
export TMUX_POWERLINE_WINDOW_STATUS_SEPARATOR="│"

# Uncomment these if you want to enable tmux bindings for muting (hiding) one of the status bars.
# E.g. this example binding would mute the left status bar when pressing <prefix> followed by Ctrl-[
#export TMUX_POWERLINE_MUTE_LEFT_KEYBINDING="C-["
#export TMUX_POWERLINE_MUTE_RIGHT_KEYBINDING="C-]"
# }

# date.sh {
# date(1) format for the date. If you don't, for some reason, like ISO 8601 format you might want to have "%D" or "%m/%d/%Y".
export TMUX_POWERLINE_SEG_DATE_FORMAT="%F"
# }

# date_week.sh {
# Symbol for calendar week.
# export TMUX_POWERLINE_SEG_DATE_WEEK_SYMBOL="󰨳"
# export TMUX_POWERLINE_SEG_DATE_WEEK_SYMBOL_COLOUR="255"
# }

# hostname.sh {
# Use short or long format for the hostname. Can be {"short, long"}.
export TMUX_POWERLINE_SEG_HOSTNAME_FORMAT="short"
# }

# time.sh {
# date(1) format for the time. Americans might want to have "%I:%M %p".
export TMUX_POWERLINE_SEG_TIME_FORMAT=" %H:%M"
# Change this to display a different timezone than the system default.
# Use TZ Identifier like "America/Los_Angeles"
# export TMUX_POWERLINE_SEG_TIME_TZ=""
# }

# tmux_mem_cpu_load.sh {
# Arguments passed to tmux-mem-cpu-load.
# See https://github.com/thewtex/tmux-mem-cpu-load for all available options.
# export TMUX_POWERLINE_SEG_TMUX_MEM_CPU_LOAD_ARGS="-v"
# }

# tmux_session_info.sh {
# Session info format to feed into the command: tmux display-message -p
# For example, if FORMAT is '[ #S ]', the command is: tmux display-message -p '[ #S ]'
export TMUX_POWERLINE_SEG_TMUX_SESSION_INFO_FORMAT="󰖯 #S" # "#S:#I.#P"
# }

# custom_session_info.sh {
# Session info format to feed into the command: tmux display-message -p
# For example, if FORMAT is '[ #S ]', the command is: tmux display-message -p '[ #S ]'
export TMUX_POWERLINE_SEG_CUSTOM_SESSION_INFO_FORMAT=" #I:#P" # "#S:#I.#P"
# }

# utc_time.sh {
# date(1) format for the UTC time.
export TMUX_POWERLINE_SEG_UTC_TIME_FORMAT="%H:%M %Z"
# }

# weather.sh {
# The data provider to use. Currently only "yahoo" is supported.
export TMUX_POWERLINE_SEG_WEATHER_DATA_PROVIDER="yrno"
# What unit to use. Can be any of {c,f,k}.
export TMUX_POWERLINE_SEG_WEATHER_UNIT="c"
# How often to update the weather in seconds.
export TMUX_POWERLINE_SEG_WEATHER_UPDATE_PERIOD="600"
# Name of GNU grep binary if in PATH, or path to it.
export TMUX_POWERLINE_SEG_WEATHER_GREP="grep"
# Location of the JSON parser, jq
export TMUX_POWERLINE_SEG_WEATHER_JSON="jq"
# Your location
# Latitude and Longtitude for use with yr.no
TMUX_POWERLINE_SEG_WEATHER_LAT="44.900822"
TMUX_POWERLINE_SEG_WEATHER_LON="-123.017578"
# }
