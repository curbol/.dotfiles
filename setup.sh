#!/bin/bash

# Source the OS detection script
source $HOME/.dotfiles/ostype.sh

# Paths of dotfiles to symlink relative to the dotfiles directory
linkfiles=(
	".config/aerospace/aerospace.toml"
	".config/tmux/tmux.conf"
	".config/tmux-powerline"
	".config/wezterm/wezterm.lua"
	".ideavimrc"
	".vimrc"
	".zshrc"
)

# Paths of dotfiles to copy relative to the dotfiles directory
copyfiles=(
	".gitconfig"
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

copy_file() {
	local src=$1
	local dest=$2

	# Create the parent directory of the destination if it doesn't exist
	mkdir -p "$(dirname "$dest")"

	# Remove the destination file if it already exists
	if [[ -e "$dest" ]]; then
		echo "Removing existing file: $dest"
		rm -rf "$dest"
	fi

	# Copy the file
	echo "Copying file: $src -> $dest"
	cp -r "$src" "$dest"
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

	copy_file "$src" "$dest"
done

echo "Dotfiles have been processed!"
