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
    # Ensure brew is in PATH for the rest of this script (needed on fresh installs)
    if [[ $is_mac_arm -eq 1 ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ $is_mac_intel -eq 1 ]]; then
      eval "$(/usr/local/bin/brew shellenv)"
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
      rm -rf /tmp/yay-install
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
    zsh_path="$(command -v zsh)"
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
# Timezone
# ------------------------------------------------------------------------------
setup_timezone() {
  if [[ $is_linux -eq 1 ]]; then
    if [[ ! -f /etc/timezone ]]; then
      log "Creating /etc/timezone..."
      echo "America/Los_Angeles" | sudo tee /etc/timezone > /dev/null
    else
      skip "/etc/timezone already exists"
    fi
  fi
}

# ------------------------------------------------------------------------------
# Bluetooth
# ------------------------------------------------------------------------------
setup_bluetooth() {
  if [[ $is_linux -eq 1 ]]; then
    local connect_src="$DOTFILES_DIR/install/bluetooth-connect.service"
    local connect_dst="$HOME/.config/systemd/user/bluetooth-connect.service"
    if [[ ! -f "$connect_dst" ]]; then
      log "Installing bluetooth-connect systemd user service..."
      mkdir -p "$HOME/.config/systemd/user"
      cp "$connect_src" "$connect_dst"
      systemctl --user daemon-reload
      systemctl --user enable --now bluetooth-connect.service
    else
      skip "bluetooth-connect.service already installed"
    fi
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

  if command -v omarchy-theme-install >/dev/null 2>&1; then
    if [[ ! -d "$HOME/.config/omarchy/themes/gruvbox-material" ]]; then
      log "Installing gruvbox-material theme..."
      omarchy-theme-install https://github.com/curbol/omarchy-gruvbox-material
    else
      skip "~/.config/omarchy/themes/gruvbox-material already exists"
    fi
  fi

  if [[ ! -d "$HOME/code/notes" ]]; then
    if ssh -T -o ConnectTimeout=5 git@github.com 2>&1 | grep -q "successfully authenticated"; then
      log "Cloning notes..."
      git clone git@github.com:curbol/notes.git "$HOME/code/notes"
    else
      skip "notes: SSH not configured yet — re-run install.sh after SSH setup"
    fi
  else
    skip "~/code/notes already exists"
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
setup_timezone
setup_bluetooth
setup_mac_settings
clone_repos
run_setup

echo -e "${COLOR_BLUE}Install complete!${COLOR_RESET}"
