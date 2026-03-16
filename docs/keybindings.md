# Keybindings Reference

---

## AeroSpace (Mac only)

`cmd` = window manager modifier (matches Hyprland `super`)

| Key | Action |
|-----|--------|
| `cmd+arrows` | Focus window |
| `cmd+shift+arrows` | Move window |
| `cmd+[1–9]` | Switch workspace |
| `cmd+shift+[1–9]` | Move window to workspace |
| `cmd+tab` | Next workspace (wrap) |
| `cmd+shift+tab` | Prev workspace (wrap) |
| `cmd+f` | Fullscreen |
| `cmd+t` / `cmd+o` | Float / tile toggle |
| `cmd+j` | Split horizontal |
| `cmd+minus` / `cmd+equal` | Resize smart -/+ |
| `cmd+w` | Close window |
| `cmd+shift+b` | Open Zen Browser |
| `cmd+shift+s` | Open Slack |
| `cmd+shift+n` | Open Notion |
| `cmd+shift+t` | Open Ghostty |
| `cmd+shift+m` | Open Messages |

---

## Tmux

**Prefix:** `ctrl+space` (or `ctrl+b`)

### Panes

| Key | Action |
|-----|--------|
| `prefix+h` | Split horizontal (new pane below) |
| `prefix+v` | Split vertical (new pane right) |
| `prefix+x` | Kill pane |
| `prefix+m` | Zoom / unzoom pane |
| `ctrl+alt+arrows` | Navigate panes (no prefix) |
| `ctrl+alt+shift+arrows` | Resize pane (no prefix) |

### Windows

| Key | Action |
|-----|--------|
| `prefix+c` | New window |
| `prefix+k` | Kill window |
| `prefix+r` | Rename window |
| `alt+[1–9]` | Jump to window (no prefix) |
| `alt+left` / `alt+right` | Prev / next window (no prefix) |
| `alt+shift+left` / `alt+shift+right` | Swap window left / right (no prefix) |

### Sessions

| Key | Action |
|-----|--------|
| `prefix+C` | New session |
| `prefix+K` | Kill session |
| `prefix+R` | Rename session |
| `prefix+P` / `prefix+N` | Prev / next session |
| `alt+up` / `alt+down` | Prev / next session (no prefix) |

### Copy mode (`prefix+[`)

| Key | Action |
|-----|--------|
| `v` | Begin selection |
| `ctrl+v` | Rectangle toggle |
| `y` | Copy selection + exit |

### Other

| Key | Action |
|-----|--------|
| `prefix+q` | Reload config |

---

## Ghostty

| Key | Action |
|-----|--------|
| `ctrl+insert` | Copy to clipboard |
| `shift+insert` | Paste from clipboard |

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
