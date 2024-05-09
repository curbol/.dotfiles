#!/bin/zsh

# Run this script to symlink dotfiles to the home directory.
# > ./setup.zsh

# Declare an associative array where
#   key = source file relative to the dotfiles directory
#   value = target location starting from the home directory
typeset -A links
links=(
  .config/tmux/tmux.conf ~/.config/tmux/tmux.conf
	.config/wezterm/wezterm.lua ~/.config/wezterm/wezterm.lua
  .gitconfig ~/.gitconfig
  .ideavimrc ~/.ideavimrc
  .vimrc ~/.vimrc
  .zshrc ~/.zshrc
)

create_symlink() {
  local src=$1
  local dest=$2

  # Create the parent directory of the destination if it doesn't exist
  mkdir -p $(dirname "$dest")

  # Remove the destination file if it already exists
  if [[ -e "$dest" || -L "$dest" ]]; then
    echo "Removing existing file: $dest"
    rm -rf "$dest"
  fi

  # Create the symlink
  echo "Creating symlink: $dest -> $src"
  ln -s "$src" "$dest"
}

# Directory containing your dotfiles
dotfiles_dir=$(cd "$(dirname "$0")" && pwd)

for src in ${(k)links}; do
  create_symlink "$dotfiles_dir/$src" "$links[$src]"
done

echo "Dotfiles have been symlinked!"
