#!/bin/zsh

# Declare a simple array with the paths of dotfiles relative to the dotfiles directory
dotfiles=(
  ".config/tmux/tmux.conf"
  ".config/wezterm/wezterm.lua"
  ".gitconfig"
  ".ideavimrc"
  ".vimrc"
  ".zshrc"
)

create_symlink() {
  local src=$1
  local dest=$2

  # Create the parent directory of the destination if it doesn't exist
  mkdir -p "$(dirname "$dest")"

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

# Iterate over the dotfiles array
for file in $dotfiles; do
  src="$dotfiles_dir/$file"
  dest="$HOME/$file"
  
  create_symlink "$src" "$dest"
done

echo "Dotfiles have been symlinked!"
