# Easily jump around the file system by manually adding marks
# marks are stored as symbolic links in the directory $MARKPATH (default $HOME/.marks)
#
# jump FOO: jump to a mark named FOO
# mark FOO: create a mark named FOO
# unmark FOO: delete a mark
# marks: lists all marks
#

source "$HOME/.dotfiles/scripts/ostype.sh"

if [[ $is_windows -eq 1 ]]; then
	export MARKPATH="$HOMEPATH/.marks"
else
	export MARKPATH="$HOME/.marks"
fi

jump() {
	if [[ $is_windows -eq 1 ]]; then
		local markpath=$(cat "$MARKPATH/$1") || { echo "No such mark: $1"; return 1; }
	else
		local markpath="$(readlink "$MARKPATH/$1")" || { echo "No such mark: $1"; return 1; }
	fi
	builtin cd "$markpath" 2>/dev/null || { echo "Destination does not exist for mark [$1]: $markpath"; return 2; }
}

mark() {
	if [[ $# -eq 0 || "$1" = "." ]]; then
		MARK=${PWD##*/}
	else
		MARK="$1"
	fi
	echo "Mark $PWD as ${MARK}? (y/n)"
	read -r response
	if [[ $response =~ ^[Yy]$ ]]; then
		command mkdir -p "$MARKPATH"
		if [[ $is_windows -eq 1 ]]; then
			echo "$PWD" > "$MARKPATH/$MARK"
		else
			command ln -sfn "$PWD" "$MARKPATH/$MARK"
		fi
	fi
}

unmark() {
	if [[ $is_windows -eq 1 ]]; then
		rm -i "$MARKPATH/$1"
	else
		LANG= command rm -i "$MARKPATH/$1"
	fi
}

marks() {
	local link max=0
	if [[ $is_windows -eq 1 ]]; then
		for link in "$MARKPATH"/*; do
			if [[ ${#link##*/} -gt $max ]]; then
				max=${#link##*/}
			fi
		done
		local printf_markname_template="$(printf -- "%%%us" "$max")"
		for link in "$MARKPATH"/*; do
			local markname=$(printf -- "$printf_markname_template" "${link##*/}")
			local markpath=$(cat "$link")
			printf -- "%s -> %s\n" "$markname" "$markpath"
		done
	else
		for link in $MARKPATH/{,.}*; do
			if [[ ${#link##*/} -gt $max ]]; then
				max=${#link##*/}
			fi
		done
		local printf_markname_template="$(printf -- "%%%us" "$max")"
		for link in $MARKPATH/{,.}*; do
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
