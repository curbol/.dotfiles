#!/bin/bash

# Source the OS detection script
source $HOME/.dotfiles/ostype.sh

# Declare a simple array with the paths of dotfiles relative to the dotfiles directory
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

# Directory containing your dotfiles
dotfiles_dir=$(cd "$(dirname "$0")" && pwd)

# Iterate over the dotfiles array
for file in "${dotfiles[@]}"; do
	src="$dotfiles_dir/$file"
	dest="$HOME/$file"

	create_symlink "$src" "$dest"
done

echo "Dotfiles have been symlinked!"

