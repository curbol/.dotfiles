# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A dotfiles repository for macOS (Apple Silicon and Intel) and Linux (Omarchy/Arch). It manages shell configuration, terminal settings, editor configs, and development tool setup via symlinks and file copies.

## Setup

```sh
sh ~/.dotfiles/setup.sh                     # symlink and copy dotfiles
sh ~/.dotfiles/setup.sh --force             # overwrite copied files too
sh ~/.dotfiles/setup.sh --force --packages  # full rebuild after a reformat
```

The setup script does three things:

1. **Symlinks** config files from this repo to their expected locations in `$HOME` (e.g., `.gitconfig`, `.zshenv`, `.config/zsh/.zshrc`)
2. **Copies** files that are meant to be locally customized (e.g., `.zshrc.local` for secrets, `.gladmin/config.yaml`)
3. **Installs** the packages in `packages.txt`, but only with `--packages` (Linux only, via `yay`)

`packages.txt` lists what's installed on top of Omarchy's own defaults, so a fresh Omarchy install plus `setup.sh --force --packages` reproduces the machine. Regenerate it by diffing `pacman -Qqett` against Omarchy's shipped `*.packages` lists.

Secrets are deliberately not reproducible from this repo. A reformat still needs `~/.ssh`, the GPG secret key, and the real `.zshrc.local` restored by hand.

## Architecture

### File Organization

- **Symlinked files** (`linkfiles` array in `setup.sh`): Shared configs tracked in git. Changes here propagate immediately.
- **Copied files** (`copyfiles` array in `setup.sh`): Templates for machine-specific or secret-containing files. Won't overwrite existing copies without `--force`.
- **`scripts/`**: Shared shell utilities sourced by other configs
  - `ostype.sh` — OS detection flags (`is_mac_os`, `is_mac_arm`, `is_mac_intel`, `is_windows`, `is_linux`)
  - `jump.sh` — Directory bookmarking system (`jump`, `mark`, `unmark`, `marks`)
- **`docs/`**: Platform-specific setup guides (mac.md, linux.md)

### Shell Configuration Chain

`.zshenv` (always loaded) sets XDG paths and `ZDOTDIR=$XDG_CONFIG_HOME/zsh`, which redirects zsh to load `.config/zsh/.zshrc`. That file loads:

1. Starship prompt
2. Secrets from `.zshrc.local` (copied, not symlinked — contains API keys)
3. `jump.sh` for directory bookmarks (which sources `ostype.sh`)
4. Homebrew (Mac only)
5. Tool-specific aliases and env vars
6. Antidote plugin manager with plugins from `.zsh_plugins.txt`

### Key Configs

| Config | Path | Purpose |
|--------|------|---------|
| ZSH | `.config/zsh/.zshrc` | Main shell config |
| ZSH plugins | `.config/zsh/.zsh_plugins.txt` | Antidote plugin list |
| ZSH secrets | `.config/zsh/.zshrc.local` | API keys, tokens (copied, gitignored content) |
| Git | `.gitconfig` | URL rewrites for orgs, nvim as editor/difftool |
| Git local | `.gitconfig_local` | Machine-specific git config (copied, not symlinked) |
| Ghostty | `.config/ghostty/config` | Terminal emulator (Omarchy theme integration, Shift+Enter fix) |
| Tmux | `.config/tmux/tmux.conf` | C-Space prefix, vim keys, minimal top statusline |
| AeroSpace | `.config/aerospace/aerospace.toml` | Tiling window manager (Mac only) |
| Hyprland | `.config/hypr/*.lua` | Tiling window manager (Linux only); overrides load after Omarchy's defaults |
| Omarchy shell | `.config/omarchy/shell.json` | Bar layout, idle and lock timeouts (copied, not symlinked) |
| Starship | `.config/starship.toml` | Prompt (Gruvbox-ish palette) |
| IdeaVim | `.ideavimrc` | JetBrains vim keybindings |
| Claude Code | `.claude/CLAUDE.md` | Global Claude Code instructions (symlinked to ~/.claude/) |
| npm | `.npmrc` | GitHub Package Registry for @sagansystems/@gladly |
| MCP servers | `mcp.json` | Claude Code MCP server configs |

### Theming

On Linux, Omarchy manages theming via `omarchy-theme-set`. Terminal colors are imported from `~/.config/omarchy/current/theme/` — Ghostty and tmux pick up theme colors automatically. On Mac, Ghostty uses whatever theme is configured directly.

### Keybindings

WM modifier is `SUPER` on Linux (Hyprland) and `CMD` on Mac (Aerospace). Both keys send the `LGUI` HID keycode, so the same physical key works on both platforms. Bindings follow the same pattern:

- `MOD+arrows` — focus window
- `MOD+SHIFT+arrows` — move window
- `MOD+number` — switch workspace
- `MOD+SHIFT+number` — move window to workspace
- `MOD+F` — fullscreen
- `MOD+T` — float/tile toggle
- `MOD+W` — close window
- `MOD+SHIFT+letter` — launch app

tmux uses `C-Space` as prefix on both platforms. `Alt+number` switches tmux windows on both platforms.

## Version Control First

When making system configuration changes, always put them in this repo and deploy via `setup.sh` or `install.sh`.

## Checking for Omarchy Drift (Linux)

Omarchy writes files onto the machine once and never revisits them on update. `.local/bin/omarchy-drift` shows what upstream changed since the last acknowledged baseline. It ignores local customizations; the signal is purely what upstream changed.

Quattro ships Omarchy as a package at `/usr/share/omarchy` rather than a git checkout, so the baseline is a snapshot of the shipped trees under `~/.cache/omarchy-drift/baseline/` instead of a commit SHA.

It watches three paths, each stale for a different reason:

| Path | Why it drifts |
|------|---------------|
| `config/` | Seeded into `~/.config/` at install; upstream changes never re-apply |
| `install/` | Runs only at install time, so a fix upstream never reaches this machine |
| `default/` | Sourced live, but a new default can duplicate or fight a local override |

`install/` is the one that bites hardest: a bug fixed upstream stays broken here forever, since the script that would apply it only ever ran once.

First run snapshots the shipped trees and records the package version. Subsequent runs show a `diff -ruN` per watched path against that snapshot, skipping paths with no changes. `omarchy-refresh-config <path>` pulls an individual shipped default back into `~/.config`.

Typical workflow after `omarchy-update`:

```sh
omarchy-drift           # review upstream changes since last ack
omarchy-drift --ack     # advance baseline after reviewing
```

Merge upstream changes you want into the tracked dotfile (for symlinked configs) or into `~/.config/` directly (for untracked locals).

## When Adding New Dotfiles

1. Add the file to this repo at the correct relative path
2. Add it to either `linkfiles` (for shared config) or `copyfiles` (for machine-specific/secret templates) in `setup.sh`
3. For platform-specific files, add to the `is_mac_os` or `is_linux` block in `setup.sh`
4. Run `setup.sh` to apply

## Cross-Platform Support

`scripts/ostype.sh` provides OS detection flags. `setup.sh` has platform-specific symlink blocks for Mac (`is_mac_os`) and Linux (`is_linux`). On Linux, a subset of Hyprland configs is tracked here (see the `is_linux` block in `setup.sh`); the rest stay Omarchy-seeded in `~/.config/hypr/`.

Only genuine deviations from Omarchy's defaults belong in the tracked `hypr/*.lua` files. Omarchy loads its own defaults first, so anything that merely restates them is dead weight that silently diverges as upstream moves. `hl.config()` merges per key, so a partial override leaves the surrounding defaults intact.
