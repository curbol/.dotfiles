# MacOS

<!--toc:start-->
- [MacOS](#macos)
  - [General](#general)
  - [Homebrew](#homebrew)
  - [Apps](#apps)
  - [AeroSpace](#aerospace)
  - [Nerd Font](#nerd-font)
  - [CLI Tools](#cli-tools)
  - [Terminal](#terminal)
  - [SSH](#ssh)
  - [GPG](#gpg)
    - [GPG Config](#gpg-config)
  - [ZSH](#zsh)
    - [ZSH Addons](#zsh-addons)
      - [OhMyZsh](#ohmyzsh)
      - [Zsh-Vi-Mode](#zsh-vi-mode)
      - [Powerlevel10k Prompt](#powerlevel10k-prompt)
  - [Neovim](#neovim)
  - [Tmux](#tmux)
<!--toc:end-->

## General

Turn off mouse acceleration:

```sh
defaults write .GlobalPreferences com.apple.mouse.scaling -1
```

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

> TODO: Find something better

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
brew install go python nodejs zig ruby
```

## Terminal

```sh
brew install wezterm
```

## SSH

Generate ssh key:

```sh
ssh-keygen -t ed25519 -C "curtis.bollinger@gmail.com"
```

Add ssh private key to ssh agent:

```sh
ssh-add ~/.ssh/id_ed25519
```

Copy ssh public key to clipboard:

```sh
pbcopy < ~/.ssh/id_ed25519.pub
```

Add the copied ssh key in GitHub under Settings > SSH and GPG keys.

Test connection:

```sh
ssh -T git@github.com
```

## GPG

```sh
brew install gnupg pinentry-mac
```

```sh
gpg --full-generate-key
```

Choose defaults

```sh
gpg --list-secret-keys --keyid-format LONG
```

Copy the GPG key ID from the output. It will look something like pub ed25519/XXXXXXXXXXXXXXXX

Add the key ID to `~/.gitconfig`:

```sh
git config --global user.signingkey XXXXXXXXXXXXXXXX
```

Print the public key:

```sh
gpg --armor --export XXXXXXXXXXXXXXXX
```

Copy the entire output (including -----BEGIN PGP PUBLIC KEY BLOCK----- and -----END PGP PUBLIC KEY BLOCK-----).

Add the public key to GitHub under Settings > SSH and GPG keys.

### GPG Config

```sh
mkdir ~/.gnupg
```

Set the correct permissions for `~/.gnupg` and its contents:

```sh
chmod 700 ~/.gnupg
chmod 600 ~/.gnupg/*
```

```sh
cat <<EOL >> ~/.gnupg/gpg-agent.conf
default-cache-ttl 600
max-cache-ttl 7200
pinentry-program /usr/local/bin/pinentry-mac
EOL
```

```sh
cat <<EOL >> ~/.gnupg/gpg.conf
use-agent
EOL
```

Reload the gpg-agent:

```sh
gpgconf --kill gpg-agent
```

## ZSH

(ZSH is the default shell on macOS)

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

```sh
brew install neovim
```

```sh
git clone https://github.com/curbol/LazyVim ~/.config/nvim
```

## Tmux

```sh
brew install tmux
```

```sh
git clone https://github.com/tmux-plugins/tpm ~/.config/tmux/plugins/tpm
```

If needed, the config can be sourced like this:

```sh
tmux source ~/.config/tmux/tmux.conf
```
