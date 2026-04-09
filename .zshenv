#!/bin/zsh
#
# .zshenv - Zsh environment file, loaded always.
#

export XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}
export XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}
export XDG_CACHE_HOME=${XDG_CACHE_HOME:-$HOME/.cache}
export ZDOTDIR=${ZDOTDIR:-$XDG_CONFIG_HOME/zsh}
# systemd ssh-agent socket (Linux only; Mac uses launchd)
[[ -z "$SSH_AUTH_SOCK" && -n "$XDG_RUNTIME_DIR" ]] && export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"
export CODE_DIR="$HOME/code"
export GOPATH="$HOME/go"
export GOBIN="$HOME/go/bin"
export ZK_NOTEBOOK_DIR="$CODE_DIR/notes"
export GODOT_PATH="/usr/bin/godot-mono"

# Ensure path arrays do not contain duplicates.
typeset -gU path fpath
