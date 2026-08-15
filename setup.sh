#!/bin/bash

# Color definitions - Gruvbox-ish palette
COLOR_RESET='\033[0m'
COLOR_GREEN='\033[38;2;123;167;124m' # Sage Green: #7ba77c
COLOR_YELLOW='\033[38;2;209;139;22m' # Golden Amber: #d18b16
COLOR_RED='\033[38;2;207;83;83m'     # Coral Red: #cf5353
COLOR_BLUE='\033[38;2;120;155;141m'  # Seafoam Teal: #789b8d
COLOR_CYAN='\033[38;2;205;123;144m'  # Dusty Rose: #cd7b90

# Source the OS detection script
source "$(cd "$(dirname "$0")" && pwd)/.config/zsh/scripts/ostype.sh"

# Initialize flags
force_overwrite_copy=0
install_packages=0

# Parse command-line options
while [[ $# -gt 0 ]]; do
  case "$1" in
  --force)
    force_overwrite_copy=1
    echo -e "${COLOR_YELLOW}Force overwrite enabled for copied files.${COLOR_RESET}"
    ;;
  --packages)
    install_packages=1
    ;;
  *)
    echo -e "${COLOR_RED}Unknown option:${COLOR_RESET} $1"
    echo "Usage: sh setup.sh [--force] [--packages]"
    exit 1
    ;;
  esac
  shift
done

# Paths of dotfiles to symlink relative to the dotfiles directory
linkfiles=(
  ".claude/CLAUDE.md"
  ".claude/RTK.md"
  ".claude/keybindings.json"
  ".claude/longrun-resume-hook.sh"
  ".claude/settings.json"
  ".claude/statusline-command.sh"
  ".claude/stop-hook.sh"
  ".claude/skills/longrun"
  ".config/ghostty/config"
  ".config/starship.toml"
  ".config/tmux/tmux.conf"
  ".config/zsh/.zsh_plugins.txt"
  ".config/zsh/.zshrc"
  ".config/zsh/scripts/jump.sh"
  ".config/zsh/scripts/ostype.sh"
  ".gitconfig"
  ".gitignore"
  ".ideavimrc"
  ".markdownlint.jsonc"
  ".npmrc"
  ".zshenv"
  ".config/mise/config.toml"
)

# macOS-only symlinks
if [[ $is_mac_os -eq 1 ]]; then
  linkfiles+=(
    ".config/aerospace/aerospace.toml"
    ".config/borders/bordersrc"
    ".config/ghostty/theme.conf"
  )
fi

# Linux-only symlinks
if [[ $is_linux -eq 1 ]]; then
  linkfiles+=(
    ".config/ghostty/linux.conf"
    ".config/hypr/autostart.conf"
    ".config/hypr/hypridle.conf"
    ".config/hypr/hyprsunset.conf"
    ".config/hypr/input.conf"
    ".config/hypr/monitors.conf"
    ".config/pacman/makepkg.conf"
    ".config/waybar/config.jsonc"
    ".config/waybar/style.css"
    ".config/environment.d/path.conf"
    ".config/wireplumber/wireplumber.conf.d/50-disable-bt-source.conf"
    ".local/bin/gamescope-auto"
    ".local/bin/omarchy-drift"
  )
fi

# Paths of dotfiles to copy relative to the dotfiles directory
copyfiles=(
  ".config/zsh/.zshrc.local"
  ".config/gladmin/config.yaml"
  ".gitconfig_local"
  ".marks"
)

create_symlink() {
  local src=$1
  local dest=$2

  # Create the parent directory of the destination if it doesn't exist
  mkdir -p "$(dirname "$dest")"

  # Remove the destination file if it already exists
  if [[ -e "$dest" || -L "$dest" ]]; then
    echo -e "${COLOR_RED}Removing existing file:${COLOR_RESET} $dest"
    rm -rf "$dest"
  fi

  # Create the symlink
  echo -e "${COLOR_GREEN}Creating symlink:${COLOR_RESET} $dest ${COLOR_CYAN}->${COLOR_RESET} $src"
  if [[ $is_windows -eq 1 ]]; then
    # Use mklink for Windows
    if [[ -d "$src" ]]; then
      cmd //c "mklink /D $(cygpath -w "$dest") $(cygpath -w "$src")"
    else
      cmd //c "mklink $(cygpath -w "$dest") $(cygpath -w "$src")"
    fi
  else
    ln -s "$src" "$dest"
  fi
}

install_arch_packages() {
  local list="$dotfiles_dir/packages.txt"
  local packages=()
  local line

  if [[ ! -f "$list" ]]; then
    echo -e "${COLOR_RED}Missing package list:${COLOR_RESET} $list"
    return 1
  fi

  if ! command -v yay >/dev/null 2>&1; then
    echo -e "${COLOR_RED}yay not found.${COLOR_RESET} Install an AUR helper before using --packages."
    return 1
  fi

  while IFS= read -r line; do
    line="${line%%#*}"
    line="${line//[[:space:]]/}"
    [[ -n "$line" ]] && packages+=("$line")
  done <"$list"

  if [[ ${#packages[@]} -eq 0 ]]; then
    echo -e "${COLOR_YELLOW}No packages listed in${COLOR_RESET} $list"
    return 0
  fi

  echo -e "${COLOR_GREEN}Installing ${#packages[@]} packages from${COLOR_RESET} packages.txt"
  yay -S --needed "${packages[@]}"
}

copy_file() {
  local src=$1
  local dest=$2
  local force_overwrite=$3

  # Create the parent directory of the destination if it doesn't exist
  mkdir -p "$(dirname "$dest")"

  if [[ -e "$dest" ]]; then
    if [[ "$force_overwrite" -eq 1 ]]; then
      echo -e "${COLOR_RED}Removing existing file (force overwrite):${COLOR_RESET} $dest"
      rm -rf "$dest"
      echo -e "${COLOR_GREEN}Copying file:${COLOR_RESET} $src ${COLOR_CYAN}->${COLOR_RESET} $dest"
      cp -r "$src" "$dest"
    else
      echo -e "${COLOR_YELLOW}Skipping copy:${COLOR_RESET} $dest already exists. Use --force to overwrite."
    fi
  else
    echo -e "${COLOR_GREEN}Copying file:${COLOR_RESET} $src ${COLOR_CYAN}->${COLOR_RESET} $dest"
    cp -r "$src" "$dest"
  fi
}

# Directory containing your dotfiles
dotfiles_dir=$(cd "$(dirname "$0")" && pwd)

# Iterate over the linkfiles array and create symlinks
for file in "${linkfiles[@]}"; do
  src="$dotfiles_dir/$file"
  dest="$HOME/$file"

  create_symlink "$src" "$dest"
done

# Mirror .claude/* symlinks to .claude-work/ (work account shares config, separate auth)
for file in "${linkfiles[@]}"; do
  if [[ "$file" == .claude/* ]]; then
    src="$dotfiles_dir/$file"
    dest="$HOME/.claude-work/${file#.claude/}"
    create_symlink "$src" "$dest"
  fi
done

# Iterate over the copyfiles array and copy files
for file in "${copyfiles[@]}"; do
  src="$dotfiles_dir/$file"
  dest="$HOME/$file"

  copy_file "$src" "$dest" "$force_overwrite_copy"
done

if [[ $install_packages -eq 1 ]]; then
  if [[ $is_linux -eq 1 ]]; then
    install_arch_packages
  else
    echo -e "${COLOR_YELLOW}Skipping --packages:${COLOR_RESET} packages.txt is Arch-only."
  fi
fi

echo -e "${COLOR_BLUE}Dotfiles have been processed!${COLOR_RESET}"
