#!/bin/bash

source $HOME/.dotfiles/ostype.sh

dotfiles=(
	".config/aerospace/aerospace.toml"
	".config/tmux/tmux.conf"
	".config/tmux-powerline"
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
	if [[ $is_windows -eq 1 ]]; then
		cmd //c mklink "$dest" "$src"
	else
		ln -s "$src" "$dest"
	fi
}

for file in "${dotfiles[@]}"; do
	src="$HOME/.dotfiles/$file"
	dest="$HOME/$file"

	create_symlink "$src" "$dest"
done

echo "Dotfiles have been symlinked!"
