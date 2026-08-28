#!/usr/bin/env bash
# PreToolUse (Bash) hook: pre-check a GitHub PR body against Gladly conventions.
#
# Vendored from config/dist/hooks/pr-body-precheck.sh in sagansystems/gladly-claude-tools,
# which holds the canonical copy and its fixture tests. setup.sh symlinks this
# into ~/.claude/hooks/; .claude/settings.json registers it as a PreToolUse hook.
#
# Fires only when `gh pr create` / `gh pr edit` is the command actually being
# invoked (at the start of a shell segment — line start or after && || ; | ,
# with optional env/VAR= prefixes) AND the PR body is passed INLINE, with its
# Markdown headings visible in the command text. Bodies passed via
# `--body-file`, or read from a heredoc / `$(cat file)` substitution, are NOT
# checked — only inline bodies are visible to this hook. All other commands
# pass through untouched. On a violation it exits 2 so the tool call is
# blocked and the reasons are fed back to the model.
set -euo pipefail

input=$(cat)

# Fast path: skip the jq parse unless the raw payload could even be a
# gh pr create/edit command — avoids forking jq on every Bash call.
case "$input" in
	*"gh pr create"* | *"gh pr edit"*) ;;
	*) exit 0 ;;
esac

cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')

# Heredoc bodies are data, not commands: a doc that documents `gh pr create`
# lives in one, and a `$(cat <<EOF …)` PR body is read from one (which the
# inline-only scope excludes anyway). Strip heredoc bodies from $cmd before
# deciding whether gh is invoked and before inspecting the body.
cmd=$(awk '
	!inh && match($0, /<<-?['\''"]?[A-Za-z_][A-Za-z0-9_]*['\''"]?/) {
		m = substr($0, RSTART, RLENGTH)
		sub(/^<<-?['\''"]?/, "", m); sub(/['\''"]$/, "", m)
		inh = 1; print; next
	}
	inh { t = $0; sub(/^[ \t]*/, "", t); if (t == m) inh = 0; next }
	{ print }
' <<<"$cmd")

# Confirm `gh pr create` / `gh pr edit` is actually INVOKED — at the start of a
# shell segment (line start, or after && || ; | ), allowing env/VAR= prefixes —
# not merely mentioned in the text. This avoids both the substring false
# positive (a doc that mentions the command) and the first-line false negative
# (`cd repo && gh pr create …`, `git push && gh pr create …`, `VAR=x gh …`).
grep -Eq '(^|&&|\|\||;|\|)[[:space:]]*(env[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*gh[[:space:]]+pr[[:space:]]+(create|edit)([[:space:]]|$)' <<<"$cmd" || exit 0

# Only inline bodies are inspectable. `--body-file` reads a file and
# `--body "$(…)"` is shell-substituted, so neither puts body text in $cmd.
# A compliant inline body always carries "## " Markdown headings; their
# absence means the body isn't visible here — nothing to check. (A
# heading-less inline body therefore passes unchecked: intentional — we
# can't distinguish "minor PR, no sections" from "body not visible".)
case "$cmd" in
	*--body-file*) exit 0 ;;
esac
grep -q '## ' <<<"$cmd" || exit 0

problems=()

# (1) Why is required. What is optional — the guidelines let a minor,
# title-sufficient PR omit it, and the What-content rules below simply
# don't fire when it's absent.
grep -q '## Why' <<<"$cmd" || problems+=("Missing '## Why' heading.")

# Carve the What and Why sections out of the command text (heredoc bodies
# arrive with real newlines, so line-oriented awk works). The section START
# is matched unanchored — the opening heading is often attached to `--body "…`
# on the same line — but a section ENDS at the next line-anchored heading of
# any level, so an interposed section (e.g. ## Screenshots) or trailing shell
# text isn't folded into it.
what=$(awk '/#+[[:space:]]*What/{f=1;next} /^[[:space:]]*#+[[:space:]]/{f=0} f' <<<"$cmd")
why=$(awk '/#+[[:space:]]*Why/{f=1;next} /^[[:space:]]*#+[[:space:]]/{f=0} f' <<<"$cmd")

# (2) What opens imperatively (like the title) — never "This change/This
# PR/These changes". Flag only when the FIRST non-blank line LEADS with the
# phrase (after an optional list marker), so a later "This PR is the first
# of two" — or a mid-sentence mention — doesn't trip it.
what_open=$(awk 'NF{print; exit}' <<<"$what")
if grep -Eq '^[[:space:]]*[-*]?[[:space:]]*(This change|This PR|These changes)' <<<"$what_open"; then
	problems+=("What opens non-imperatively ('This change/This PR/These changes') — lead with an imperative verb.")
fi

# (3) Why is motivation only — no trade-off / caveat language (those belong
# in What or the tech spec). "limitation" is intentionally not matched: a
# limitation of the existing system is a common, legitimate motivation.
if grep -Eiq 'trade-?off|accepted trade|caveat' <<<"$why"; then
	problems+=("Why contains trade-off/caveat language — Why is motivation only; state caveats in What or the tech spec, not here.")
fi

# (4) What describes only what the change does — never negative scope /
# exclusions. Only unambiguous scope-declaration phrasing is flagged;
# ordinary descriptive "does not <verb>" (a no-op guarantee) is allowed.
# Naming a follow-up PR concisely is fine.
if grep -Eiq 'deliberately (not|exclud)|not included in this|out[- ]of[- ]scope|not addressed here' <<<"$what"; then
	problems+=("What states negative scope (what the change does NOT do / excludes) — describe only what it does; a follow-up PR may be named in one concise line.")
fi

if ((${#problems[@]})); then
	echo "PR body pre-check failed — fix before creating/editing the PR:" >&2
	for p in "${problems[@]}"; do echo "  - $p" >&2; done
	exit 2
fi

exit 0
