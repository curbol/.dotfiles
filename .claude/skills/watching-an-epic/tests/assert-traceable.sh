#!/bin/bash
# Resolves the citations in a watcher's journal instead of counting them.
#
#   assert-traceable.sh <watcher>
#
# A non-empty `sources` array is satisfied by an invented citation, which is why this
# resolves each one: a `window`-origin Slack permalink must name a configured channel and a
# ts inside the window that run recorded, a file:line must exist in a configured repo, and a
# story id must resolve over REST. `exploration`-origin citations are exempt from the window,
# because finding an earlier thread is what exploration is for.
#
# Needs SHORTCUT_API_TOKEN for the story checks; skips them without it.

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S="$(cd "$HERE/.." && pwd)/scripts"

WATCHER="${1:?usage: assert-traceable.sh <watcher>}"
CFG="$("$S/config.sh" show "$WATCHER")" || { echo "no config for $WATCHER" >&2; exit 2; }
JOURNAL="${XDG_STATE_HOME:-$HOME/.local/state}/epic-watch/$WATCHER/journal.ndjson"
[ -f "$JOURNAL" ] || { echo "no journal for $WATCHER" >&2; exit 2; }

WORKSPACE="$(jq -r '.slack_workspace' <<<"$CFG")"
OK=0; BAD=0
bad(){ BAD=$((BAD+1)); printf '  BAD  %s\n' "$1"; }
good(){ OK=$((OK+1)); }

# Each run's window, from its run_start record, so a past run's bounds survive the watermark
# moving on.
windows="$(jq -sc '[.[] | select(.action == "run_start") | {run_id, windows}] | from_entries?
                   // ([.[] | select(.action == "run_start")] | map({key: .run_id, value: .windows}) | from_entries)' \
           "$JOURNAL" 2>/dev/null || echo '{}')"

while IFS=$'\t' read -r run_id action target kind ref origin; do
    [ -n "${kind:-}" ] || continue
    case "$kind" in
    slack_message)
        chan="$(printf '%s' "$ref" | sed -n 's|.*/archives/\([^/]*\)/p.*|\1|p')"
        ts_digits="$(printf '%s' "$ref" | sed -n 's|.*/p\([0-9]*\).*|\1|p')"
        if [ -z "$chan" ] || [ -z "$ts_digits" ]; then
            bad "$action $target: unparseable permalink $ref"; continue
        fi
        if ! jq -e --arg c "$chan" '.slack_channels | index($c) != null' >/dev/null <<<"$CFG"; then
            bad "$action $target: $chan is not a configured channel"; continue
        fi
        if [ "$(printf '%s' "$ref" | sed -n 's|.*\(https://[^.]*\)\.slack\.com.*|\1|p' | sed 's|https://||')" != "$WORKSPACE" ]; then
            bad "$action $target: permalink workspace is not $WORKSPACE"; continue
        fi
        if [ "$origin" = window ]; then
            from="$(jq -r --arg r "$run_id" --arg c "$chan" \
                '(.[$r] // {}) | to_entries[] | select(.key | endswith("/" + $c)) | .value.from // empty' \
                <<<"$windows" | head -1)"
            if [ -n "$from" ]; then
                from_d="${from//./}"
                if [ "$ts_digits" -lt "${from_d:-0}" ] 2>/dev/null; then
                    bad "$action $target: window-origin ts $ts_digits precedes this run's window ($from)"
                    continue
                fi
            fi
        fi
        good ;;
    file)
        path="${ref%%:*}"; line="${ref##*:}"
        found=false
        while read -r repo; do
            [ -n "$repo" ] || continue
            if [ -f "$repo/$path" ]; then
                total="$(wc -l < "$repo/$path" | tr -d ' ')"
                [ "${line:-0}" -le "$((total + 1))" ] 2>/dev/null && found=true
            fi
        done < <(jq -r '.repos[]?' <<<"$CFG")
        [ "$found" = true ] && good || bad "$action $target: $ref not found in any configured repo"
        ;;
    story)
        if [ -z "${SHORTCUT_API_TOKEN:-}" ]; then good; continue; fi
        "$S/shortcut.sh" story "$ref" >/dev/null 2>&1 && good \
            || bad "$action $target: story $ref does not resolve"
        ;;
    notion_page)
        jq -e --arg p "$ref" '[.doc_surfaces[]?.notion_page] | index($p) != null' >/dev/null <<<"$CFG" \
            && good || bad "$action $target: notion page $ref is not a configured doc surface"
        ;;
    *) bad "$action $target: unknown source kind '$kind'" ;;
    esac
done < <(jq -r '
    select(.action == "filed" or .action == "asked" or .action == "commented")
    | . as $r | (.sources // [])[] | [$r.run_id, $r.action, ($r.target|tostring), .kind, .ref, .origin] | @tsv' "$JOURNAL")

# An action that wrote something must cite something.
uncited="$(jq -sr '[.[] | select(.action == "filed" or .action == "commented")
                        | select((.sources // []) | length == 0)] | length' "$JOURNAL")"
[ "${uncited:-0}" -gt 0 ] && bad "$uncited writing action(s) carry no sources at all"

printf '%d citation(s) resolved, %d bad\n' "$OK" "$BAD"
[ "$BAD" -eq 0 ]
