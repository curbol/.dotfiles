# shellcheck shell=bash
# Segment that indicates status of various tmux modes. The list of supported
# modes & a brief description of each is as follows:
#
# - Normal mode: The default mode when you are simply using tmux.
#
# - Prefix mode: The mode when the tmux prefix key is pressed.
#
# - Copy mode: The mode when text is being copied. By default this is triggered
#   by pressing the prefix key followed by '['; see `man tmux` for more details.

# Default values for the settings that this segment supports.
NORMAL_MODE_TEXT_DEFAULT=" TMUX "
NORMAL_MODE_FG_COLOR_DEFAULT="$TMUX_POWERLINE_CUR_SEGMENT_FG"

PREFIX_MODE_TEXT_DEFAULT="PREFIX"
PREFIX_MODE_FG_COLOR_DEFAULT="$TMUX_POWERLINE_CUR_SEGMENT_FG"

COPY_MODE_TEXT_DEFAULT=" COPY "
COPY_MODE_FG_COLOR_DEFAULT="$TMUX_POWERLINE_CUR_SEGMENT_FG"

run_segment() {
	__process_settings

	# Colors.
	# NOTE: Don't use commas here because it will break the formatting in mode_indicator().
	normal_text_color="#[fg=$TMUX_POWERLINE_SEG_CUSTOM_MODE_NORMAL_FG_COLOR]"
	prefix_text_color="#[bold]#[fg=$TMUX_POWERLINE_SEG_CUSTOM_MODE_PREFIX_FG_COLOR]"
	copy_text_color="#[bold]#[fg=$TMUX_POWERLINE_SEG_CUSTOM_MODE_COPY_FG_COLOR]"

	# Populate segment.
	segment=""
	__mode_indicator

	echo "$segment"
	return 0
}

__mode_indicator() {
	normal_mode="$normal_text_color$NORMAL_MODE_TEXT_DEFAULT"
	prefix_mode="$prefix_text_color$PREFIX_MODE_TEXT_DEFAULT"
	copy_mode="$copy_text_color$COPY_MODE_TEXT_DEFAULT"

	mode_to_show="#{?pane_in_mode,$copy_mode,$normal_mode}"
	mode_to_show="#{?client_prefix,$prefix_mode,$mode_to_show}"

	segment+="$mode_to_show"
}

__process_settings() {
	TMUX_POWERLINE_SEG_CUSTOM_MODE_NORMAL_FG_COLOR=${TMUX_POWERLINE_SEG_CUSTOM_MODE_NORMAL_FG_COLOR:-$NORMAL_MODE_FG_COLOR_DEFAULT}
	TMUX_POWERLINE_SEG_CUSTOM_MODE_PREFIX_FG_COLOR=${TMUX_POWERLINE_SEG_CUSTOM_MODE_PREFIX_FG_COLOR:-$PREFIX_MODE_FG_COLOR_DEFAULT}
	TMUX_POWERLINE_SEG_CUSTOM_MODE_COPY_FG_COLOR=${TMUX_POWERLINE_SEG_CUSTOM_MODE_COPY_FG_COLOR:-$COPY_MODE_FG_COLOR_DEFAULT}
}
