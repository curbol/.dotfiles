#!/bin/bash
# Token-gated checks against the real APIs. Never wired into CI: it needs credentials and
# network, so a green CI run says nothing about anything in here.
#
# SHORTCUT_API_TOKEN is required. SLACK_USER_TOKEN is optional; its checks skip without it.

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S="$(cd "$HERE/.." && pwd)/scripts"

SCRATCH_EPIC="${EPIC_WATCH_SCRATCH_EPIC:-256741}"
SCRATCH_STORY="${EPIC_WATCH_SCRATCH_STORY:-256757}"
SCRATCH_PERMALINK="${EPIC_WATCH_SCRATCH_PERMALINK:-https://gladly.slack.com/archives/C0901J82FLN/p1787257832925119}"

PASS=0; FAIL=0; SKIP=0
ok(){ PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad(){ FAIL=$((FAIL+1)); printf '  FAIL %s\n     expected: %s\n     actual:   %s\n' "$1" "$2" "$3"; }
skip(){ SKIP=$((SKIP+1)); printf '  skip %s (%s)\n' "$1" "$2"; }
eq(){ [ "$2" = "$3" ] && ok "$1" || bad "$1" "$2" "$3"; }

printf '\nShortcut\n'
if [ -z "${SHORTCUT_API_TOKEN:-}" ]; then
    skip "all Shortcut checks" "SHORTCUT_API_TOKEN unset"
else
    eq "epic probe returns the scratch epic" "$SCRATCH_EPIC" \
       "$("$S/shortcut.sh" epic "$SCRATCH_EPIC" | jq -r '.id')"
    eq "dedup lookup finds the known story" "$SCRATCH_STORY" \
       "$("$S/shortcut.sh" story-by-external-link "$SCRATCH_PERMALINK" | jq -r '.[0].id // "none"')"
    eq "a miss is an empty array, not a 404" "0" \
       "$("$S/shortcut.sh" story-by-external-link "https://example.invalid/nope" | jq -r 'length')"
    eq "epic-scoped search finds only in-epic stories" "true" \
       "$("$S/shortcut.sh" search-stories "epic:$SCRATCH_EPIC" 5 | jq -r --argjson e "$SCRATCH_EPIC" '[.data[].epic_id] | all(. == $e)')"
    ( "$S/shortcut.sh" story 999999999 >/dev/null 2>&1 ); eq "404 maps to exit 3" "3" "$?"
    ( SHORTCUT_API_TOKEN=deadbeef "$S/shortcut.sh" epic "$SCRATCH_EPIC" >/dev/null 2>&1 )
    eq "rejected credential maps to exit 4, not 2" "4" "$?"
fi

printf '\nSlack\n'
if [ -z "${SLACK_USER_TOKEN:-}" ]; then
    skip "all Slack API checks" "SLACK_USER_TOKEN unset; the shell path ships fixture-verified only"
else
    auth="$("$S/slack.sh" auth-test)" && ok "auth-test succeeds" || bad "auth-test" "ok" "failed"
    ws="$(jq -r '.workspace' <<<"$auth")"; self="$(jq -r '.self_id' <<<"$auth")"
    [ -n "$ws" ] && ok "derives workspace ($ws)" || bad "derives workspace" "non-empty" "empty"
    [ -n "$self" ] && ok "derives self id ($self)" || bad "derives self id" "non-empty" "empty"
    ch="${EPIC_WATCH_SCRATCH_CHANNEL:-}"
    if [ -z "$ch" ]; then
        skip "channel reads" "set EPIC_WATCH_SCRATCH_CHANNEL to a channel id"
    else
        newest="$("$S/slack.sh" latest-ts "$ch")"
        [ -n "$newest" ] && ok "latest-ts returns a ts ($newest)" || bad "latest-ts" "a ts" "empty"
        env_out="$("$S/slack.sh" channel-history "$ch" 0 "$(date +%s).000000" 2)"
        eq "history returns one envelope" "true" \
           "$(jq -r 'has("messages") and has("truncated") and has("oldest_read") and has("newest_read")' <<<"$env_out")"
        eq "envelope carries messages even when truncated" "true" \
           "$(jq -r '(.messages | type) == "array"' <<<"$env_out")"
        built="$("$S/slack.sh" permalink "$ws" "$ch" "$newest")"
        eq "constructed permalink matches the derived workspace and channel" \
           "https://$ws.slack.com/archives/$ch/p${newest//./}" "$built"
    fi
fi

printf '\nTraceability\n'
if [ -n "${EPIC_WATCH_TRACE_WATCHER:-}" ]; then
    "$HERE/assert-traceable.sh" "$EPIC_WATCH_TRACE_WATCHER" >/dev/null 2>&1 \
        && ok "every journal citation in $EPIC_WATCH_TRACE_WATCHER resolves" \
        || bad "traceability" "clean" "$("$HERE/assert-traceable.sh" "$EPIC_WATCH_TRACE_WATCHER" 2>&1 | tail -3)"
else
    skip "journal traceability" "set EPIC_WATCH_TRACE_WATCHER to a watcher that has run"
fi

printf '\n%d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]
