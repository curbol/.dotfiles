#!/bin/sh
# Claude Code statusLine command
# Mirrors Starship prompt segments: directory, git branch, gladmin config, model, context usage

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
model=$(echo "$input" | jq -r '.model.display_name // ""')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# Shorten home directory to ~
home="$HOME"
short_dir="${cwd/#$home/\~}"

# Git branch
git_branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)

if [ -n "$git_branch" ]; then
  git_dirty=$(git -C "$cwd" status --porcelain --no-optional-locks 2>/dev/null | head -1)
  if [ -n "$git_dirty" ]; then
    git_part="  ${git_branch} *"
  else
    git_part="  ${git_branch}"
  fi
else
  git_part=""
fi

# gladmin config current
if command -v gladmin >/dev/null 2>&1; then
  gladmin_out=$(gladmin config current 2>/dev/null)
  if [ -n "$gladmin_out" ]; then
    gladmin_part="  gladmin:${gladmin_out}"
  else
    gladmin_part=""
  fi
else
  gladmin_part=""
fi

# Model
if [ -n "$model" ]; then
  model_part=" | ${model}"
else
  model_part=""
fi

# Context usage
if [ -n "$used_pct" ]; then
  ctx_pct=$(awk "BEGIN {printf \"%.0f\", $used_pct}")
  ctx_part=" | ctx ${ctx_pct}%"
else
  ctx_part=""
fi

printf '%s%s%s%s%s' "$short_dir" "$git_part" "$gladmin_part" "$model_part" "$ctx_part"
