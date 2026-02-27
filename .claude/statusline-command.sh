#!/bin/sh
# Claude Code statusLine command
# Mirrors the Starship prompt style: directory, git branch/status, model, context usage

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
model=$(echo "$input" | jq -r '.model.display_name // ""')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# Shorten home directory to ~
home="$HOME"
short_dir="${cwd/#$home/\~}"

# Git branch (skip optional locks)
git_branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)

# Git dirty indicator
if [ -n "$git_branch" ]; then
  git_dirty=$(git -C "$cwd" status --porcelain --no-optional-locks 2>/dev/null | head -1)
  if [ -n "$git_dirty" ]; then
    git_part=" $git_branch *"
  else
    git_part=" $git_branch"
  fi
else
  git_part=""
fi

# Context usage
if [ -n "$used_pct" ]; then
  ctx_part=" | ctx ${used_pct}%"
else
  ctx_part=""
fi

# Model part
if [ -n "$model" ]; then
  model_part=" | $model"
else
  model_part=""
fi

printf '%s%s%s%s' "$short_dir" "$git_part" "$model_part" "$ctx_part"
