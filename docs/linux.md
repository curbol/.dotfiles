# Linux (Omarchy / Arch)

## Omarchy

Follow the [Omarchy installation guide](https://omarchy.org) to get the base system set up.

## Dotfiles

Clone this repo to the home directory then run:

```sh
sh ~/.dotfiles/setup.sh
```

## ZSH

ZSH is likely already installed. Set it as your default shell if not already:

```sh
chsh -s $(which zsh)
```

Log out and back in for the change to take effect.

## Nerd Font

```sh
omarchy-font-set "Maple Mono NF"
```

Or install manually via pacman if not in the omarchy font list:

```sh
yay -S ttf-maple
```

## CLI Tools

```sh
sudo pacman -S git xclip wl-clipboard jq cmake fzf ripgrep fd wget luarocks prettier
```

```sh
sudo pacman -S lazygit neovim github-cli
```

```sh
gh extension install github/gh-copilot
```

```sh
sudo pacman -S go nodejs python python-pip zig
```

```sh
curl https://mise.run | sh
```

```sh
mise use -g node@20.12
mise use -g python@3.11
```

## Neovim

```sh
git clone https://github.com/curbol/LazyVim ~/.config/nvim
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
wl-copy < ~/.ssh/id_ed25519.pub
```

Add the copied ssh key in GitHub under Settings > SSH and GPG keys.

Test connection:

```sh
ssh -T git@github.com
```

## GPG

```sh
sudo pacman -S gnupg pinentry
```

### GPG Config

```sh
mkdir ~/.gnupg
```

Set the correct permissions for `~/.gnupg`:

```sh
chmod 700 ~/.gnupg
```

Fill in config files:

```sh
cat <<EOL >> ~/.gnupg/gpg-agent.conf
default-cache-ttl 600
max-cache-ttl 7200
pinentry-program /usr/bin/pinentry-gnome3
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

Choose defaults.

```sh
gpg --list-secret-keys --keyid-format LONG
```

Copy the GPG key ID from the output. It will look something like `pub ed25519/XXXXXXXXXXXXXXXX`.

Add the key ID to `~/.gitconfig`:

```sh
git config --global user.signingkey XXXXXXXXXXXXXXXX
```

Print the public key:

```sh
gpg --armor --export XXXXXXXXXXXXXXXX
```

Copy the entire output (including `-----BEGIN PGP PUBLIC KEY BLOCK-----` and `-----END PGP PUBLIC KEY BLOCK-----`).

Add the public key to GitHub under Settings > SSH and GPG keys.
