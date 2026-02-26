#!/bin/zsh
#
# .zshenv - Zsh environment file, loaded always.
#

export XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}
export XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}
export XDG_CACHE_HOME=${XDG_CACHE_HOME:-$HOME/.cache}
export ZDOTDIR=${ZDOTDIR:-$XDG_CONFIG_HOME/zsh}
export GOPATH="$HOME/go"
export GOBIN="$HOME/go/bin"
export ZK_NOTEBOOK_DIR="$HOME/code/notes"

# Ensure path arrays do not contain duplicates.
typeset -gU path fpath

# Set the list of directories that zsh searches for commands.
path=(
  $HOME/.local/{,s}bin(N)
  $GOBIN(N)
  $HOME/{,s}bin(N)
  /opt/{homebrew,local}/{,s}bin(N)
  /usr/local/{,s}bin(N)
  /nix/var/nix/profiles/default/bin(N) # Gladly (Nix)
  $HOME/.nix-profile/bin(N)            # Gladly (Nix)
  $path
)

# fpath[1] is a reliable user completions dir, always first so tools that
# recommend `${fpath[1]}/_tool` install to the right place.
fpath=(
  $HOME/.local/share/zsh/site-functions
  $fpath
)
