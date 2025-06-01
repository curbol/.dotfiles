# MacOS

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
brew install trailer mac-mouse-fix
```

```sh
brew install obsidian slack discord spotify licecap
```

## Nerd Font

```sh
brew install font-jetbrains-mono-nerd-font
```

## CLI Tools

```sh
brew install xclip jq cmake fzf ripgrep fd wget lazygit luarocks markdown-toc prettier
```

```sh
brew install gh postgresql kubectl awscli automake
```

```sh
gh extension install github/gh-copilot
```

```sh
npm i -g neovim terraform-fmt
```

```sh
brew install go nodejs python zig
```

```sh
brew install mise
```

```sh
mise use -g node@20.12
mise use -g python@3.11
```

## Terminal

```sh
brew install wezterm
```

## Dotfiles

Clone this repo to the home directory then run:

```sh
sh ~/.dotfiles/setup.sh
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

### GPG Config

```sh
mkdir ~/.gnupg
```

Set the correct permissions for `~/.gnupg`:

```sh
chmod 700 ~/.gnupg
```

Fill in config files

```sh
cat <<EOL >> ~/.gnupg/gpg-agent.conf
default-cache-ttl 600
max-cache-ttl 7200
pinentry-program /opt/homebrew/bin/pinentry-mac
# Use below instead for intel mac
# pinentry-program /usr/local/bin/pinentry-mac
EOL
```

```sh
cat <<EOL >> ~/.gnupg/gpg.conf
use-agent
EOL
```

```sh
chmod 600 ~/.gnupg/*
```

Reload the gpg-agent:

```sh
gpgconf --kill gpg-agent && \
gpgconf --launch gpg-agent
```

### Generate and Save GPG Key

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

## ZSH

(ZSH is the default shell on macOS)

### ZSH Addons (Antidote)

(might not need to install antidote as it might install when .zshrc is loaded)

```sh
brew install antidote
```

#### Powerlevel10k Prompt

> **Prompt Style:** Lean, Unicode, 8 colors, No time, Two lines, Disconnected, No frame, Sparse, Few icons, Concise, Yes transient, Verbose

## Neovim

```sh
brew install neovim
```

```sh
git clone https://github.com/curbol/LazyVim ~/.config/nvim
```
