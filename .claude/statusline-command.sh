#!/bin/sh
# Claude Code statusLine command
# Segments: directory, git branch, model and effort level, context usage

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
model=$(echo "$input" | jq -r '.model.display_name // ""')
effort=$(echo "$input" | jq -r '.effort.level // ""')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# Shorten home directory to ~
home="$HOME"
short_dir="${cwd/#$home/\~}"

# Git branch
git_branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)

if [ -n "$git_branch" ]; then
  git_part="  ${git_branch}"
else
  git_part=""
fi

# Model and effort level
if [ -n "$model" ]; then
  model_part=" | ${model}"
else
  model_part=""
fi

if [ -n "$effort" ]; then
  effort_part=" (${effort})"
else
  effort_part=""
fi

# Context usage (raw percentage)
if [ -n "$used_pct" ]; then
  ctx_part=" | ctx $(printf '%.0f' "$used_pct")%"
else
  ctx_part=""
fi

printf '%s%s%s%s%s' "$short_dir" "$git_part" "$model_part" "$effort_part" "$ctx_part"
