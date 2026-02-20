# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A dotfiles repository for macOS (Apple Silicon and Intel) and Windows. It manages shell configuration, terminal settings, editor configs, and development tool setup via symlinks and file copies.

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
- **`docs/`**: Platform-specific setup guides (mac.md, windows.md)

### Shell Configuration Chain

`.zshenv` (always loaded) sets XDG paths and `ZDOTDIR=$XDG_CONFIG_HOME/zsh`, which redirects zsh to load `.config/zsh/.zshrc`. That file loads:
1. Starship prompt
2. Secrets from `.zshrc.local` (copied, not symlinked — contains API keys)
3. `jump.sh` for directory bookmarks
4. Homebrew
5. Tool-specific aliases and env vars
6. Antidote plugin manager with plugins from `.zsh_plugins.txt`

### Key Configs

| Config | Path | Purpose |
|--------|------|---------|
| ZSH | `.config/zsh/.zshrc` | Main shell config |
| ZSH plugins | `.config/zsh/.zsh_plugins.txt` | Antidote plugin list |
| ZSH secrets | `.config/zsh/.zshrc.local` | API keys, tokens (copied, gitignored content) |
| Git | `.gitconfig` | URL rewrites for orgs, nvim as editor/difftool |
| WezTerm | `.config/wezterm/wezterm.lua` | Terminal emulator (Gruvbox Material theme, Ctrl+A leader) |
| Tmux | `.config/tmux/tmux.conf` | Ctrl+A prefix, vim keys, powerline theme |
| AeroSpace | `.config/aerospace/aerospace.toml` | Tiling window manager |
| Starship | `.config/starship.toml` | Prompt (Gruvbox-ish palette) |
| IdeaVim | `.ideavimrc` | JetBrains vim keybindings |
| Claude Code | `.claude/CLAUDE.md` | Global Claude Code instructions (symlinked to ~/.claude/) |
| Gladmin | `.gladmin/config.yaml` | Gladly CLI profiles (copied) |
| npm | `.npmrc` | GitHub Package Registry for @sagansystems/@gladly |
| MCP servers | `mcp.json` | Claude Code MCP server configs |

### Theming

Gruvbox Material is used consistently across WezTerm, tmux-powerline, and Starship. The color palette is defined in starship.toml comments and wezterm.lua constants.

## When Adding New Dotfiles

1. Add the file to this repo at the correct relative path
2. Add it to either `linkfiles` (for shared config) or `copyfiles` (for machine-specific/secret templates) in `setup.sh`
3. Run `setup.sh` to apply

## Cross-Platform Support

`scripts/ostype.sh` provides OS detection flags. Both `setup.sh` and `jump.sh` use these to handle platform differences (e.g., Windows uses `mklink` instead of `ln -s`, file-based marks instead of symlinks).
