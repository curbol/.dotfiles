# Windows Setup

## Scoop Package Manager

```sh
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
```

The `extras` bucket is needed for some things like wezterm, git-with-openssh, etc.

```sh
scoop bucket add extras
```

## Apps

```sh
scoop install obsidian slack discord spotify
```

## Nerd Font

```sh
scoop bucket add nerd-fonts
```

```sh
scoop install JetBrainsMono-NF-Mono
```

## CLI Tools

```sh
scoop install jq cmake fzf ripgrep fd wget pwsh lazygit luarocks
```

```sh
scoop install go python nodejs zig
```

## Terminal

[Download](https://wezfurlong.org/wezterm/install/windows.html#installing-on-windows)

OR

```sh
scoop install wezterm
```

## ZSH

### Bash Shell

```sh
scoop install git-with-openssh
```

### ZSH Shell

#### Install ZSH

[Download](https://packages.msys2.org/package/zsh?repo=msys&variant=x86_64).

> **Note:** The download link should look something like this: `https://mirror.msys2.org/msys/x86_64/zsh-5.9-2-x86_64.pkg.tar.zst`.

Extract the contents into the folder with `git-bash.exe`. The folder should be should be `C:\Users\curti\scoop\apps\git-with-openssh\2.45.1.windows.1\`.

Add zsh (and bash, etc.) to `PATH`

```txt
%USERPROFILE%\scoop\apps\git-with-openssh\current\usr\bin
```

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
scoop install neovim
```

```sh
git clone https://github.com/curbol/LazyVim ~/.config/nvim
```

## TMUX \[Not Working\]

> **WARNING:** This only works for mintty or git-bash. Not working in Wezterm :(

```sh
scoop install msys2
```

Add pacman (and other tools) to `PATH`

```txt
%USERPROFILE%\scoop\apps\msys2\current\usr\bin
```

> **Note:** This installs `pacman` and some other unilities. A terminal restart is required.

```sh
pacman -S tmux
```

