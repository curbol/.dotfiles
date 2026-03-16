# macOS

## Setup

1. Install Homebrew:

   ```sh
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

2. Clone dotfiles:

   ```sh
   git clone https://github.com/curbol/.dotfiles.git ~/code/.dotfiles
   ```

3. Run install:

   ```sh
   ~/code/.dotfiles/install.sh
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

### GPG Config

```sh
mkdir ~/.gnupg
chmod 700 ~/.gnupg
```

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

Choose defaults.

```sh
gpg --list-secret-keys --keyid-format LONG
```

Copy the GPG key ID from the output (looks like `pub ed25519/XXXXXXXXXXXXXXXX`).

Add it to `~/.config/zsh/.zshrc.local`:

```sh
export GIT_SIGNING_KEY_ID=XXXXXXXXXXXXXXXX
```

Print the public key:

```sh
gpg --armor --export XXXXXXXXXXXXXXXX
```

Add the public key to GitHub under Settings > SSH and GPG keys.
