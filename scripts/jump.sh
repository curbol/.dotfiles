#!/bin/bash

# Source the OS detection script
source $HOME/.dotfiles/scripts/ostype.sh

# Default mark path
export MARKPATH=$HOME/.marks

# Function to jump to a mark
jump() {
    local markpath
    if [[ $is_windows -eq 1 ]]; then
        markpath="$(cygpath -u "$(readlink "$MARKPATH/$1")")" || { echo "No such mark: $1"; return 1; }
    else
        markpath="$(readlink "$MARKPATH/$1")" || { echo "No such mark: $1"; return 1; }
    fi
    builtin cd "$markpath" 2>/dev/null || { echo "Destination does not exist for mark [$1]: $markpath"; return 2; }
}

# Function to create a mark
mark() {
    local MARK
    if [[ $# -eq 0 || "$1" = "." ]]; then
        MARK=${PWD##*/}
    else
        MARK="$1"
    fi
    if read -p "Mark $PWD as ${MARK}? (y/n) " -n 1 -r && [[ $REPLY =~ ^[Yy]$ ]]; then
        echo
        mkdir -p "$MARKPATH"
        ln -sfn "$PWD" "$MARKPATH/$MARK"
    else
        echo
    fi
}

# Function to delete a mark
unmark() {
    rm -i "$MARKPATH/$1"
}

# Function to list all marks
marks() {
    local link max=0
    for link in "$MARKPATH"/*; do
        if [[ ${#link##*/} -gt $max ]]; then
            max=${#link##*/}
        fi
    done
    local printf_markname_template
    printf_markname_template="$(printf "%%%us" "$max")"
    for link in "$MARKPATH"/*; do
        local markname markpath
        markname="$(printf "$printf_markname_template" "${link##*/}")"
        if [[ $is_windows -eq 1 ]]; then
            markpath="$(cygpath -u "$(readlink "$link")")"
        else
            markpath="$(readlink "$link")"
        fi
        printf "%s -> %s\n" "$markname" "$markpath"
    done
}

# Completion functions for Zsh
_completemarks() {
    reply=("${MARKPATH}"/*)
}
compctl -K _completemarks jump
compctl -K _completemarks unmark

_mark_expansion() {
    setopt localoptions extendedglob
    autoload -U modify-current-argument
    modify-current-argument '$(readlink "$MARKPATH/$ARG" || echo "$ARG")'
}
zle -N _mark_expansion
bindkey "^g" _mark_expansion
