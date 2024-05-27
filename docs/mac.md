# MacOS

## Homebrew

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

## Apps

```sh
brew install mac-mouse-fix
```

```sh
brew install obsidian slack discord spotify
```

## AeroSpace

```sh
brew install --cask nikitabobko/tap/aerospace
```

```sh
brew tap FelixKratz/formulae
brew install borders
```

## Nerd Font

```sh
brew tap homebrew/cask-fonts
```

```sh
brew install font-jetbrains-mono-nerd-font
```

## CLI Tools

```sh
brew install jq cmake fzf ripgrep fd wget lazygit luarocks
```

```sh
brew install go python nodejs zig
```

## Terminal

```sh
brew install wezterm
```

## ZSH

(Zsh is the default on macOS)

### ZSH Addons

#### OhMyZsh

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --keep-zshrc
```

#### Zsh-Vi-Mode

```sh
git clone https://github.com/jeffreytse/zsh-vi-mode ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-vi-mode
```

#### Powerlevel10k Prompt

```sh
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
```

> **Prompt Style:** Lean, Unicode, 8 colors, No time, Two lines, Disconnected, No frame, Sparse, Few icons, Concise, Yes transient, Verbose

## Neovim

Clone repo:

```sh
git clone https://github.com/curbol/LazyVimStarter ~/.config/nvim
```

## Tmux

```sh
brew install tmux
```

```sh
brew install tpm
```
