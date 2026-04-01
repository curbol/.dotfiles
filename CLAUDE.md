# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A dotfiles repository for macOS (Apple Silicon and Intel) and Linux (Omarchy/Arch). It manages shell configuration, terminal settings, editor configs, and development tool setup via symlinks and file copies.

## Setup

```sh
sh ~/.dotfiles/setup.sh          # symlink and copy dotfiles
sh ~/.dotfiles/setup.sh --force  # overwrite copied files too
```

The setup script does two things:

1. **Symlinks** config files from this repo to their expected locations in `$HOME` (e.g., `.gitconfig`, `.zshenv`, `.config/zsh/.zshrc`)
2. **Copies** files that are meant to be locally customized (e.g., `.zshrc.local` for secrets, `.gladmin/config.yaml`)

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
| Ghostty | `.config/ghostty/config` | Terminal emulator (Omarchy theme integration, Shift+Enter fix) |
| Tmux | `.config/tmux/tmux.conf` | C-Space prefix, vim keys, minimal top statusline |
| AeroSpace | `.config/aerospace/aerospace.toml` | Tiling window manager (Mac only) |
| Omarchy/Hyprland | `~/.config/hypr/` | Tiling window manager (Linux only, managed by Omarchy) |
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

## When Adding New Dotfiles

1. Add the file to this repo at the correct relative path
2. Add it to either `linkfiles` (for shared config) or `copyfiles` (for machine-specific/secret templates) in `setup.sh`
3. For platform-specific files, add to the `is_mac_os` or `is_linux` block in `setup.sh`
4. Run `setup.sh` to apply

## Cross-Platform Support

`scripts/ostype.sh` provides OS detection flags. `setup.sh` has platform-specific symlink blocks for Mac (`is_mac_os`) and Linux (`is_linux`). Hyprland configs are managed directly by Omarchy on Linux and are not tracked in this repo.
