# Easily jump around the file system by manually adding marks
# marks are stored as symbolic links in the directory $MARKPATH (default $HOME/.marks)
#
# jump foo: jump to a mark named foo
# mark foo: create a mark named foo
# unmark foo: delete a mark
# marks: lists all marks

# Color definitions
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
RESET='\033[0m'

source "$HOME/.dotfiles/scripts/ostype.sh"

if [[ $is_windows -eq 1 ]]; then
	export MARKPATH="$HOMEPATH/.marks"
else
	export MARKPATH="$HOME/.marks"
fi

jump() {
  local mark="$1"

  # If no argument provided, use fzf to select a mark
  if [[ $# -eq 0 ]]; then
    if ! command -v fzf >/dev/null 2>&1; then
      echo "fzf not found. Please install fzf or provide a mark name."
      return 1
    fi

    if [[ ! -d "$MARKPATH" ]] || [[ -z "$(ls -A "$MARKPATH" 2>/dev/null)" ]]; then
      echo "No marks available."
      return 1
    fi

    # Create a list of marks with their paths for fzf
    local marks_list=""
    if [[ $is_windows -eq 1 ]]; then
      for link in "$MARKPATH"/*; do
        [[ -f "$link" ]] || continue
        local markname="${link##*/}"
        local markpath=$(cat "$link" 2>/dev/null)
        marks_list+="$markname -> $markpath"$'\n'
      done
    else
      # Use nullglob to handle cases where no matches exist
      setopt localoptions nullglob
      for link in "$MARKPATH"/* "$MARKPATH"/.*; do
        [[ -L "$link" && "${link##*/}" != "." && "${link##*/}" != ".." ]] || continue
        local markname="${link##*/}"
        local markpath=$(readlink "$link" 2>/dev/null)
        marks_list+="$markname -> $markpath"$'\n'
      done
    fi

    if [[ -z "$marks_list" ]]; then
      echo "No marks available."
      return 1
    fi

    # Use fzf to select a mark
    local selected=$(echo "$marks_list" | fzf | cut -d' ' -f1)
    [[ -z "$selected" ]] && return 0  # User cancelled
    mark="$selected"
  fi

  # First check if the mark file actually exists
  if [[ ! -e "$MARKPATH/$mark" ]]; then
    echo "No such mark: $mark"
    return 1
  fi

  if [[ $is_windows -eq 1 ]]; then
    local markpath=$(cat "$MARKPATH/$mark") || { echo "No such mark: $mark"; return 1; }
  else
    local markpath="$(readlink "$MARKPATH/$mark")" || { echo "No such mark: $mark"; return 1; }
  fi

  builtin cd "$markpath" 2>/dev/null || {
    echo "Destination does not exist for mark [$mark]: $markpath"
    return 2
  }
}

mark() {
	if [[ $# -eq 0 || "$1" = "." ]]; then
		MARK=${PWD##*/}
	else
		MARK="$1"
	fi

	# Check if mark already exists
	if [[ -e "$MARKPATH/$MARK" ]]; then
		if [[ $is_windows -eq 1 ]]; then
			local existing_path=$(cat "$MARKPATH/$MARK" 2>/dev/null)
		else
			local existing_path=$(readlink "$MARKPATH/$MARK" 2>/dev/null)
		fi
		echo "${YELLOW}Mark '$MARK' already exists -> $existing_path${RESET}"
		echo "${YELLOW}Overwrite with '$MARK' -> $PWD? (y/n)${RESET}"
	else
		echo "${GREEN}Mark '$MARK' -> $PWD? (y/n)${RESET}"
	fi

	read -r response
	if [[ $response =~ ^[Yy]$ ]]; then
		command mkdir -p "$MARKPATH"
		if [[ $is_windows -eq 1 ]]; then
			echo "$PWD" > "$MARKPATH/$MARK"
		else
			command ln -sfn "$PWD" "$MARKPATH/$MARK"
		fi
		echo "Mark '$MARK' created."
	fi
}

unmark() {
	local mark="$1"

	# If no argument provided, use current directory name
	if [[ $# -eq 0 ]]; then
		mark="${PWD##*/}"
	fi

	# Check if mark exists
	if [[ ! -e "$MARKPATH/$mark" ]]; then
		echo "No such mark: $mark"
		return 1
	fi

	# Get the mark path for display
	if [[ $is_windows -eq 1 ]]; then
		local markpath=$(cat "$MARKPATH/$mark" 2>/dev/null)
	else
		local markpath=$(readlink "$MARKPATH/$mark" 2>/dev/null)
	fi

	echo "${RED}Unmark '$mark' -> $markpath? (y/n)${RESET}"
	read -r response
	if [[ $response =~ ^[Yy]$ ]]; then
		if [[ $is_windows -eq 1 ]]; then
			rm "$MARKPATH/$mark"
		else
			LANG= command rm "$MARKPATH/$mark"
		fi
		echo "Mark '$mark' removed."
	fi
}

marks() {
  setopt localoptions nullglob
  local link max=0

  if [[ $is_windows -eq 1 ]]; then
    for link in "$MARKPATH"/*; do
      (( ${#link##*/} > max )) && max=${#link##*/}
    done
    local printf_markname_template="$(printf -- "%%%us" "$max")"

    for link in "$MARKPATH"/*; do
      local markname=$(printf -- "$printf_markname_template" "${link##*/}")
      local markpath=$(cat "$link")
      printf -- "%s -> %s\n" "$markname" "$markpath"
    done
  else
    for link in "$MARKPATH"/{,.}*; do
      (( ${#link##*/} > max )) && max=${#link##*/}
    done
    local printf_markname_template="$(printf -- "%%%us" "$max")"

    for link in "$MARKPATH"/{,.}*; do
      local markname=$(printf -- "$printf_markname_template" "${link##*/}")
      local markpath=$(readlink "$link")
      printf -- "%s -> %s\n" "$markname" "$markpath"
    done
  fi
}

_completemarks() {
	reply=("${(f)$(ls -1 "$MARKPATH")}")
}

autoload -U compinit && compinit
compctl -K _completemarks jump
compctl -K _completemarks unmark

_mark_expansion() {
	setopt localoptions extendedglob
	autoload -U modify-current-argument
	modify-current-argument '$(readlink "$MARKPATH/$ARG" || echo "$ARG")'
}
zle -N _mark_expansion
bindkey "^g" _mark_expansion
