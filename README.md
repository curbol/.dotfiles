# .dotfiles

## MacOS

### Dotfiles

Clone this repo to the home directory then run:

```sh
zsh ~/.dotfiles/setup.zsh
```

### Nerd Font

```sh
brew tap homebrew/cask-fonts
```

```sh
brew install font-jetbrains-mono-nerd-font
```

### Terminal

```sh
brew install wezterm
```

### ZSH

(Zsh is the default on macOS)

```sh
brew install powerlevel10k
```

```sh
brew install zsh-vi-mode
```

```sh
brew install fzf
```

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

### Neovim

Clone repo:

```sh
git clone https://github.com/curbol/LazyVimStarter ~/.config/nvim
```

Dependencies:

```sh
brew install ripgrep fd wget
```

Optional dependencies:

```sh
brew install lazygit luarocks python3
```

### Tmux

```sh
brew install tmux
```

```sh
brew install tpm
```

### Version Manager

```sh
brew install asdf
```

### GoLang

```sh
brew install go
```

```sh
brew install goland
```
