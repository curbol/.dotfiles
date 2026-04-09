#!/bin/zsh
#
# .zprofile - Zsh login shell profile, loaded after /etc/zprofile.
#
# PATH lives here (not .zshenv) because macOS path_helper and brew shellenv
# run between .zshenv and .zprofile, overriding any earlier PATH ordering.
#

# Homebrew (macOS only)
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# Set the list of directories that zsh searches for commands.
path=(
  $HOME/.local/share/mise/shims(N)
  $HOME/.local/{,s}bin(N)
  $GOBIN(N)
  $HOME/{,s}bin(N)
  /opt/{homebrew,local}/{,s}bin(N)
  /usr/local/{,s}bin(N)
  /nix/var/nix/profiles/default/bin(N) # Gladly (Nix)
  $HOME/.nix-profile/bin(N)            # Gladly (Nix)
  /opt/pact/bin(N)                     # Gladly (Pact)
  $path
)

# fpath[1] is a reliable user completions dir, always first so tools that
# recommend `${fpath[1]}/_tool` install to the right place.
fpath=(
  $HOME/.local/share/zsh/site-functions
  $fpath
)
