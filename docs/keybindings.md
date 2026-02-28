# Keybindings Reference

**Model:** `alt` = aerospace · `ctrl` = nvim/wezterm nav · `cmd` = wezterm-specific

---

## AeroSpace

### Main mode

| Key | Action |
|-----|--------|
| `alt+arrows` | Focus window |
| `alt+shift+arrows` | Move window |
| `alt+[1–9]` | Switch workspace |
| `alt+shift+[1–9]` | Move window to workspace |
| `alt+tab` | Last workspace |
| `alt+shift+tab` | Move workspace to next monitor |
| `alt+space` | **Enter service mode** |
| `alt+shift+-` / `alt+shift+=` | Resize smart -/+ |
| `alt+b` | Open Arc |
| `alt+s` | Open Slack |
| `alt+n` | Open Notion |
| `alt+t` | Open WezTerm |
| `alt+m` | Open Messages |

### Service mode (`alt+space`)

| Key | Action |
|-----|--------|
| `esc` | Reload config + exit |
| `m` | Fullscreen toggle |
| `f` | Float / tile toggle |
| `q` | Close window |
| `r` | **Enter resize mode** |
| `[` | Prev workspace |
| `]` | Next workspace |

### Resize mode (`alt+space r`)

| Key | Action |
|-----|--------|
| `arrows` | Resize window |
| `esc` | Exit to main |

---

## WezTerm

**Leader:** `ctrl+space`

### Direct bindings

| Key | Action |
|-----|--------|
| `cmd+arrows` | Navigate panes |
| `cmd+[1–9]` | Jump to tab |
| `cmd+v` | Paste (text or image) |

### Leader (`ctrl+space …`)

| Key | Action |
|-----|--------|
| `space` | Quick select |
| `:` | Command palette |
| `/` | Search |
| `a` | Last tab |
| `y` | Copy mode |
| `s` | Split horizontal (equalize) |
| `v` | Split vertical (equalize) |
| `t` | New tab |
| `q` | Close pane |
| `d` | Close tab |
| `x` | Swap pane (rotate clockwise) |
| `m` | Zoom / unzoom pane |
| `[` | Prev tab |
| `]` | Next tab |
| `=` | Equalize pane sizes |
| `o` | Close other panes |
| `r` | **Enter resize mode** |

### Resize mode (`ctrl+space r`)

| Key | Action |
|-----|--------|
| `arrows` | Resize pane (hold to keep resizing) |
| `esc` | Exit (also auto-exits after 1s idle) |

### Copy mode (`ctrl+space y`)

| Key | Action |
|-----|--------|
| `y` | Yank selection + exit |

---

## Neovim

**Leader:** `space`

### Direct bindings (ctrl layer)

| Key | Action |
|-----|--------|
| `ctrl+arrows` | Navigate windows |
| `ctrl+shift+arrows` (normal) | Move / swap window |
| `ctrl+shift+arrows` (visual) | Move selection (mini.move) |
| `ctrl+[1–9]` | Harpoon jump |

### Custom leader bindings

| Key | Action |
|-----|--------|
| `<leader>cs` | Change all occurrences of word / selection |
| `<leader>bs` | Save all buffers |
| `<leader>bz` | Clear unsaved buffer changes |
| `<leader>bm` | Close all markdown buffers |
| `<leader>sG` | Grep in current buffer's directory |
