#!/bin/bash
# Print an epic's open PRs that are waiting on review, grouped under their story, from a
# fresh work-monitor snapshot. Prints only: posting is done in the session, on request.
#
# Usage: pr-digest.sh <epic-id> [<epic-id>...]
# Exit codes: 0 printed (or nothing open)  1 usage  2 dependency absent  3 collector error

set -euo pipefail

[ $# -ge 1 ] || { echo "Usage: pr-digest.sh <epic-id> [<epic-id>...]" >&2; exit 1; }
for e in "$@"; do
    case "$e" in ''|*[!0-9]*) echo "not an epic id: $e" >&2; exit 1 ;; esac
done
EPICS="$(printf '%s\n' "$@" | jq -R 'tonumber' | jq -cs .)"

command -v jq >/dev/null 2>&1 || { echo "jq is required but not installed" >&2; exit 2; }
MONITOR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/work-monitor/scripts/collect.sh"
[ -x "$MONITOR" ] || { echo "work-monitor's collector is absent: $MONITOR" >&2; exit 2; }

# Collect rather than read the last snapshot: yesterday's lists PRs that merged overnight.
STATE="$("$MONITOR")" || { echo "collector failed" >&2; exit 3; }
[ -f "$STATE" ] || { echo "collector reported a path that does not exist: $STATE" >&2; exit 3; }

# A source the collector couldn't read would otherwise print as "nothing waiting".
if [ "$(jq -r '.errors | length' "$STATE")" -gt 0 ]; then
    echo "refusing to print: the collector reported errors" >&2
    jq -r '.errors[] | "  - \(.)"' "$STATE" >&2
    exit 3
fi

# NONE (no reviewer ever requested) is listed with REVIEW_REQUIRED: from a reviewer's side
# the two are the same. Drafts are left out, since a draft isn't waiting on anyone.
rows() {
    jq -r --argjson es "$EPICS" --argjson want "$1" '
        .prs[]
        | select(.epic != null and (.epic as $e | $es | index($e)) != null
                 and (.draft | not) and (.review as $r | $want | index($r)) != null)
        | [ .repo + "#" + (.number | tostring), .title, .url, (.checks // "-"), (.story // "-"), (.epic | tostring) ]
        | @tsv
    ' "$STATE"
}

# A story often ships as several PRs, so they're grouped under it, in PR-number order.
section() {
    local heading="$1" body="$2" repo title url checks story epic last=""
    [ -n "$body" ] || return 0
    printf '%s\n' "$heading"
    while IFS=$'\t' read -r repo title url checks story epic; do
        [ -n "$repo" ] || continue
        case "$checks" in
            FAILURE) checks=" (checks failing)" ;;
            PENDING) checks=" (checks running)" ;;
            *)       checks="" ;;
        esac
        if [ "$story" = "-" ]; then
            printf -- '- [%s](%s) %s%s\n' "$repo" "$url" "$title" "$checks"
            continue
        fi
        if [ "$story" != "$last" ]; then
            printf -- '- [sc-%s](https://app.shortcut.com/gladly/story/%s), epic %s\n' "$story" "$story" "$epic"
            last="$story"
        fi
        printf -- '    - [%s](%s) %s%s\n' "$repo" "$url" "$title" "$checks"
    done <<<"$(sort -t$'\t' -k5,5 -k1,1 <<<"$body")"
    printf '\n'
}

needs_review="$(rows '["REVIEW_REQUIRED","NONE"]')"
changes="$(rows '["CHANGES_REQUESTED"]')"
if [ -z "$needs_review" ] && [ -z "$changes" ]; then
    echo "nothing open and unapproved on epic(s) $*" >&2
    exit 0
fi
section "Needs review" "$needs_review"
section "Changes requested" "$changes"
