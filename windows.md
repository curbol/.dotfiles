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

## Nerd Font

```sh
scoop bucket add nerd-fonts
```

```sh
scoop install JetBrainsMono-NF-Mono
```

## CLI Tools

```sh
scoop install fzf
```

## Wezterm Terminal

[Download](https://wezfurlong.org/wezterm/install/windows.html#installing-on-windows)

OR

```sh
scoop install wezterm
```

## Bash Shell

```sh
scoop install git-with-openssh
```

## ZSH Shell

[Download](https://packages.msys2.org/package/zsh?repo=msys&variant=x86_64).

> **Note:** The download link should look something like this: `https://mirror.msys2.org/msys/x86_64/zsh-5.9-2-x86_64.pkg.tar.zst`.

Extract the contents into the folder with `git-bash.exe`. The folder should be should be `C:\Users\curti\scoop\apps\git-with-openssh\2.45.1.windows.1\`.

Add zsh (and bash, etc.) to `PATH`

```sh
setx PATH "$env:PATH;C:\Users\curti\scoop\apps\git-with-openssh\2.45.1.windows.1\usr\bin"
```

## Neovim

```sh
scoop install neovim
```
