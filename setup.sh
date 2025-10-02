#!/bin/bash

# Color definitions - Gruvbox-ish palette
COLOR_RESET='\033[0m'
COLOR_GREEN='\033[38;2;123;167;124m' # Sage Green: #7ba77c
COLOR_YELLOW='\033[38;2;209;139;22m' # Golden Amber: #d18b16
COLOR_RED='\033[38;2;207;83;83m'     # Coral Red: #cf5353
COLOR_BLUE='\033[38;2;120;155;141m'  # Seafoam Teal: #789b8d
COLOR_CYAN='\033[38;2;205;123;144m'  # Dusty Rose: #cd7b90

# Source the OS detection script
source "$HOME/.dotfiles/scripts/ostype.sh"

# Initialize force_overwrite_copy flag
force_overwrite_copy=0

# Parse command-line options
# If --force is passed as the first argument, enable overwriting for copy operations.
if [[ "$1" == "--force" ]]; then
  force_overwrite_copy=1
  echo -e "${COLOR_YELLOW}Force overwrite enabled for copied files.${COLOR_RESET}"
  shift # Consume the --force argument, so it's not processed by later parts of the script if any.
fi

# Paths of dotfiles to symlink relative to the dotfiles directory
linkfiles=(
  ".config/aerospace/aerospace.toml"
  ".config/mcphub/servers.json"
  ".config/starship.toml"
  ".config/wezterm/wezterm.lua"
  ".config/zsh/.zsh_plugins.txt"
  ".config/zsh/.zshrc"
  ".config/zsh/scripts/jump.sh"
  ".config/zsh/scripts/ostype.sh"
  ".gitconfig"
  ".gitignore"
  ".ideavimrc"
  ".mcp.json"
  ".npmrc"
  ".vimrc"
  ".zshenv"
  "Library/Application Support/Code/User/keybindings.json"
  "Library/Application Support/Code/User/settings.json"
)

# Paths of dotfiles to copy relative to the dotfiles directory
copyfiles=(
  ".config/zsh/.zshrc.local"
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

# Iterate over the copyfiles array and copy files
for file in "${copyfiles[@]}"; do
  src="$dotfiles_dir/$file"
  dest="$HOME/$file"

  copy_file "$src" "$dest" "$force_overwrite_copy"
done

echo -e "${COLOR_BLUE}Dotfiles have been processed!${COLOR_RESET}"
