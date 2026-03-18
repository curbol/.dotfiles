#!/bin/bash

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DOTFILES_DIR/.config/zsh/scripts/ostype.sh"

COLOR_RESET='\033[0m'
COLOR_GREEN='\033[38;2;123;167;124m'
COLOR_YELLOW='\033[38;2;209;139;22m'
COLOR_BLUE='\033[38;2;120;155;141m'

log()  { echo -e "${COLOR_GREEN}==>${COLOR_RESET} $1"; }
skip() { echo -e "${COLOR_YELLOW}skip:${COLOR_RESET} $1"; }

# ------------------------------------------------------------------------------
# Packages
# ------------------------------------------------------------------------------
install_packages() {
  if [[ $is_mac_os -eq 1 ]]; then
    if ! command -v brew >/dev/null 2>&1; then
      log "Installing Homebrew..."
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    log "Installing packages from Brewfile..."
    brew bundle --file="$DOTFILES_DIR/Brewfile"

  elif [[ $is_linux -eq 1 ]]; then
    local pacman_pkgs=(
      git zsh tmux neovim lazygit github-cli
      starship fzf ripgrep fd jq cmake wget
      wl-clipboard luarocks gnupg pinentry mise
    )
    local to_install=()
    for pkg in "${pacman_pkgs[@]}"; do
      pacman -Q "$pkg" &>/dev/null || to_install+=("$pkg")
    done
    if [[ ${#to_install[@]} -gt 0 ]]; then
      log "Installing packages: ${to_install[*]}"
      sudo pacman -S --noconfirm --needed "${to_install[@]}"
    else
      skip "all pacman packages already installed"
    fi

    if ! command -v yay >/dev/null 2>&1; then
      log "Installing yay (AUR helper)..."
      git clone https://aur.archlinux.org/yay.git /tmp/yay-install
      (cd /tmp/yay-install && makepkg -si --noconfirm)
      rm -rf /tmp/yay-install
    fi

    local aur_pkgs=(maplemono-nf)
    local aur_to_install=()
    for pkg in "${aur_pkgs[@]}"; do
      pacman -Q "$pkg" &>/dev/null || aur_to_install+=("$pkg")
    done
    if [[ ${#aur_to_install[@]} -gt 0 ]]; then
      log "Installing AUR packages: ${aur_to_install[*]}"
      yay -S --noconfirm "${aur_to_install[@]}"
    else
      skip "all AUR packages already installed"
    fi
  fi
}

# ------------------------------------------------------------------------------
# Mise (language runtimes)
# ------------------------------------------------------------------------------
install_mise() {
  # Mac: installed via Brewfile above
  # Linux: installed via pacman above
  if command -v mise >/dev/null 2>&1; then
    log "Installing mise tools..."
    mise use -g node@lts
    mise use -g python@latest
    mise use -g go@latest
    mise use -g zig@latest
  fi
}

# ------------------------------------------------------------------------------
# Shell
# ------------------------------------------------------------------------------
set_default_shell() {
  if [[ $is_linux -eq 1 ]]; then
    local zsh_path
    zsh_path="$(which zsh)"
    if [[ "$SHELL" != "$zsh_path" ]]; then
      log "Setting zsh as default shell..."
      chsh -s "$zsh_path"
    else
      skip "zsh already default shell"
    fi
  fi
}

# ------------------------------------------------------------------------------
# Font
# ------------------------------------------------------------------------------
set_font() {
  if [[ $is_linux -eq 1 ]] && command -v omarchy-font-set >/dev/null 2>&1; then
    log "Setting system font to Maple Mono NF..."
    omarchy-font-set "Maple Mono NF"
  fi
}

# ------------------------------------------------------------------------------
# macOS settings
# ------------------------------------------------------------------------------
setup_mac_settings() {
  if [[ $is_mac_os -eq 1 ]]; then
    log "Configuring macOS settings..."
    defaults write .GlobalPreferences com.apple.mouse.scaling -1
  fi
}

# ------------------------------------------------------------------------------
# Repos
# ------------------------------------------------------------------------------
clone_repos() {
  if [[ ! -d "$HOME/.config/nvim" ]]; then
    log "Cloning LazyVim config..."
    git clone https://github.com/curbol/LazyVim "$HOME/.config/nvim"
  else
    skip "~/.config/nvim already exists"
  fi
}

# ------------------------------------------------------------------------------
# Dotfiles
# ------------------------------------------------------------------------------
run_setup() {
  log "Running dotfiles setup..."
  bash "$DOTFILES_DIR/setup.sh"
}

# ------------------------------------------------------------------------------
install_packages
install_mise
set_default_shell
set_font
setup_mac_settings
clone_repos
run_setup

echo -e "${COLOR_BLUE}Install complete!${COLOR_RESET}"
