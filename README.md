# .dotfiles

Personal dotfiles for macOS and Linux (Omarchy/Arch).

## Setup

Clone the repo:

```sh
git clone https://github.com/curbol/.dotfiles.git ~/code/.dotfiles
```

Run the install script:

```sh
~/code/.dotfiles/install.sh
```

This installs packages, language runtimes (via mise), sets zsh as the default shell, clones supporting repos, and symlinks all dotfiles.

To re-apply dotfiles only (without reinstalling packages):

```sh
~/code/.dotfiles/setup.sh
```

Use `--force` to overwrite locally copied files (e.g. `.zshrc.local`):

```sh
~/code/.dotfiles/setup.sh --force
```

## Platform Guides

- [macOS](docs/mac.md)
- [Linux](docs/linux.md)
- [Windows](docs/windows.md)
