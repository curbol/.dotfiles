#!/bin/bash

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DOTFILES_DIR/.config/zsh/scripts/ostype.sh"

COLOR_RESET='\033[0m'
COLOR_GREEN='\033[38;2;123;167;124m'
COLOR_BLUE='\033[38;2;120;155;141m'

log() { echo -e "${COLOR_GREEN}==>${COLOR_RESET} $1"; }

if [[ $is_mac_os -eq 1 ]]; then
  log "Installing work tools..."
  brew install terraform kubectl awscli

elif [[ $is_linux -eq 1 ]]; then
  log "Installing work tools..."
  sudo pacman -S --noconfirm --needed terraform kubectl aws-cli
fi

echo -e "${COLOR_BLUE}Work install complete!${COLOR_RESET}"
