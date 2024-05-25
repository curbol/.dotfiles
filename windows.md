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

Add `bash` to `PATH`

```sh
setx PATH "$env:PATH;C:\Users\curti\scoop\apps\git-with-openssh\2.45.1.windows.1\bin"
```
