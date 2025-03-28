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

```sh
scoop install wezterm
```

OR

[Download](https://wezfurlong.org/wezterm/install/windows.html#installing-on-windows)

## GPG

```sh
scoop install gpg
```

Generate GPG Key:

```sh
gpg --full-generate-key
```

## ZSH

### Bash Shell

```sh
scoop install git-with-openssh
```

### ZSH Shell

#### Install ZSH

[Download msys2](https://packages.msys2.org/package/zsh?repo=msys&variant=x86_64).

> **Note:** The download link should look something like this: `https://mirror.msys2.org/msys/x86_64/zsh-5.9-2-x86_64.pkg.tar.zst`.

Extract the contents into the folder with `git-bash.exe`. The folder should be `C:\Users\curti\scoop\apps\git-with-openssh\2.45.1.windows.1\`.

Add zsh (and bash, etc.) to `PATH`

```txt
%USERPROFILE%\scoop\apps\git-with-openssh\current\usr\bin
```

### ZSH Addons

#### Powerlevel10k Prompt

> **Prompt Style:** Lean, Unicode, 8 colors, No time, Two lines, Disconnected, No frame, Sparse, Few icons, Concise, Yes transient, Verbose

## Neovim

```sh
scoop install neovim
```

```sh
git clone https://github.com/curbol/LazyVim ~/.config/nvim
```
