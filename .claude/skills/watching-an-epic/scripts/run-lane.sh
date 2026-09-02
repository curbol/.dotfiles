#!/bin/bash
# One lane run: precheck, then act on what it found.
#
# The precheck answers "is there anything to do" from the shell, so a quiet channel costs no
# model tokens. Only when it finds work does this invoke `claude -p`, which runs the
# watching-an-epic skill and does the filing.
#
# Exit codes: 0 ran (including a quiet or degraded run)  1 usage  2 config absent/invalid

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$HERE/config.sh"
SHORTCUT="$HERE/shortcut.sh"
SLACK="$HERE/slack.sh"

BREAKER_TRIP_AT=3
BREAKER_THROTTLE=6   # while open, one fire in six does work: a half-open probe

die() { printf '%s\n' "$2" >&2; exit "$1"; }
usage() { printf 'Usage: run-lane.sh <watcher> <lane> [--once] [--dry-run]\n' >&2; exit 1; }

[ $# -ge 2 ] || usage
WATCHER="$1"; LANE="$2"; shift 2
case "$LANE" in intake|groom|docs) ;; *) die 1 "invalid lane: '$LANE'" ;; esac
ONCE=false; DRY_RUN=false
for a in "$@"; do
    case "$a" in
        --once) ONCE=true ;;
        --dry-run) DRY_RUN=true ;;
        *) usage ;;
    esac
done

MAX_TURNS="${EPIC_WATCH_MAX_TURNS:-60}"
# A wall-clock bound, which --max-turns is not: a single turn can block indefinitely on a
# network call. Enforced here rather than with `timeout`, which is absent from the bare PATH a
# launchd job gets. The lock's staleness window is deliberately wider than this, so an
# ordinary slow run is never mistaken for a wedged one.
LANE_DEADLINE="${EPIC_WATCH_LANE_DEADLINE:-900}"
LANE_MODEL="${EPIC_WATCH_MODEL:-}"

# config.env.claude_bin wins over PATH, for a machine where `claude` is not resolvable from
# the recorded PATH, or where it is a version-manager shim that misbehaves outside a login
# shell. An absolute path sidesteps both.
resolve_claude() {
    local from_cfg
    from_cfg="$("$CONFIG" show "$WATCHER" 2>/dev/null | jq -r '.env.claude_bin // ""')"
    if [ -n "$from_cfg" ] && [ -x "$from_cfg" ]; then printf '%s' "$from_cfg"; return 0; fi
    command -v claude 2>/dev/null || return 1
}

# `if cmd; then :; else case $?` and not `if ! cmd`: inside the then-branch of a negation,
# $? is the negation's own status, so every arm but the default is unreachable.
if cfg="$("$CONFIG" show "$WATCHER" 2>/dev/null)"; then :; else
    case $? in
        1) die 1 "invalid watcher name: $WATCHER" ;;
        *) die 2 "no config for watcher $WATCHER" ;;
    esac
fi

# Validated on read, not only on write: a hand-edited config would otherwise reach the loops
# below, where bash 3.2 aborts on an empty array under set -u rather than reporting a problem.
"$CONFIG" validate "$WATCHER" >/dev/null 2>&1 \
    || die 2 "config for $WATCHER is invalid; run config.sh validate $WATCHER"
LOOKBACK="$(jq -r '.lookback // "24h"' <<<"$cfg")"
ASK_EXPIRY="$(jq -r '.ask_expiry // "72h"' <<<"$cfg")"
EPIC="$(jq -r '.epic' <<<"$cfg")"
WORKSPACE="$(jq -r '.slack_workspace' <<<"$cfg")"
SELF_ID="$(jq -r '.slack_self_id' <<<"$cfg")"

# run_id is minted here, before the lock, so a lock-skipped run can still name itself.
RUN_ID="${EPIC_WATCH_RUN_ID:-$(date +%s)-$$}"
export EPIC_WATCH_RUN_ID="$RUN_ID"
STATE_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/epic-watch/$WATCHER"
JOURNAL="$STATE_ROOT/journal.ndjson"
STATE_TMP="$STATE_ROOT/tmp"; mkdir -p "$STATE_TMP"
journal() {
    local action="$1" target="${2:-null}" detail="${3:-null}" sources="${4:-[]}"
    "$CONFIG" journal "$WATCHER" "$(jq -nc \
        --arg ts "$(date +%s)" --arg run_id "$RUN_ID" --arg w "$WATCHER" --arg l "$LANE" \
        --arg a "$action" --argjson t "$target" --argjson d "$detail" --argjson s "$sources" \
        '{ts: ($ts|tonumber), run_id: $run_id, watcher: $w, lane: $l, action: $a,
          target: $t, sources: $s, detail: $d}')"
}

health() { "$CONFIG" health-set "$WATCHER" "$LANE" "$1"; }
health_now() { "$CONFIG" health-get "$WATCHER" | jq -c --arg l "$LANE" '.lanes[$l] // {}'; }

h="$(health_now)"
FAILURES="$(jq -r '.consecutive_failures // 0' <<<"$h")"
BREAKER="$(jq -r '.breaker // "closed"' <<<"$h")"
FIRES="$(jq -r '.fires_since_open // 0' <<<"$h")"

# An open breaker throttles rather than halts. Halting outright means a transient blip
# parks an unattended watcher until a human notices, which is the failure the design's
# visibility rules exist to prevent.
if [ "$BREAKER" = open ] && [ "$ONCE" != true ]; then
    FIRES=$((FIRES + 1))
    if [ $((FIRES % BREAKER_THROTTLE)) -ne 0 ]; then
        health "$(jq -nc --argjson f "$FIRES" '{fires_since_open: $f}')"
        journal throttled
        exit 0
    fi
    health "$(jq -nc --argjson f "$FIRES" '{fires_since_open: $f}')"
fi

# Exit 3 is "already held"; any other non-zero is a usage or state problem, and both mean
# this run must not proceed to act.
if ! "$CONFIG" lock-acquire "$WATCHER" "$LANE" $$ 2>/dev/null; then
    journal lock_skip
    exit 0
fi

# Everything below holds the lock, so a fatal error here must still leave a record: an
# unrecorded run is indistinguishable from a healthy quiet one.
COMPLETED=false
on_exit() {
    local rc=$?
    if [ "$COMPLETED" != true ]; then
        "$CONFIG" journal "$WATCHER" "$(jq -nc --arg ts "$(date +%s)" --arg run_id "$RUN_ID" \
            --arg w "$WATCHER" --arg l "$LANE" --arg rc "$rc" \
            '{ts: ($ts|tonumber), run_id: $run_id, watcher: $w, lane: $l, action: "crashed",
              target: null, sources: [], detail: {exit: ($rc|tonumber)}}')" 2>/dev/null || true
        local crashed_failures
        crashed_failures="$(( $("$CONFIG" health-get "$WATCHER" 2>/dev/null \
            | jq -r --arg l "$LANE" '.lanes[$l].consecutive_failures // 0' 2>/dev/null || echo 0) + 1 ))"
        "$CONFIG" health-set "$WATCHER" "$LANE" "$(jq -nc --arg t "$(date +%s)" --arg rc "$rc" \
            --argjson f "$crashed_failures" \
            '{last_run: ($t|tonumber), consecutive_failures: $f,
              last_error: {class: "crashed", detail: ["run ended without completing, exit \($rc)"], denials: []}}')" 2>/dev/null || true
        if [ "$crashed_failures" -ge "$BREAKER_TRIP_AT" ]; then
            "$CONFIG" health-set "$WATCHER" "$LANE" "$(jq -nc --arg t "$(date +%s)" \
                '{breaker: "open", breaker_opened_at: ($t|tonumber)}')" 2>/dev/null || true
            "$CONFIG" alert-set "$WATCHER" "$(jq -nc --arg t "$(date +%s)" --arg l "$LANE" \
                '{ts: ($t|tonumber), lane: $l, class: "crashed", detail: ["the lane crashed on three consecutive fires"]}')" 2>/dev/null || true
        fi
    fi
    "$CONFIG" lock-release "$WATCHER" "$LANE" $$ 2>/dev/null || true
    exit "$rc"
}
trap on_exit EXIT

# Sources are keyed <lane>/<source> so an incidental read in one lane cannot advance
# another lane's stream. Recorded at run start because a window discovered afterwards
# would admit citations the run never read.
declare -a WINDOW_KEYS=()
declare -a WINDOW_FROM=()
CHANNELS=()
while read -r ch; do [ -n "$ch" ] && CHANNELS+=("$ch"); done < <(jq -r '.slack_channels[]' <<<"$cfg")
for ch in ${CHANNELS[@]+"${CHANNELS[@]}"}; do
    WINDOW_KEYS+=("$LANE/$ch")
    WINDOW_FROM+=("$("$CONFIG" effective-bound "$WATCHER" "$LANE/$ch" "$LOOKBACK")")
done
windows='{}'
for i in ${WINDOW_KEYS[@]+"${!WINDOW_KEYS[@]}"}; do
    windows="$(jq -c --arg k "${WINDOW_KEYS[$i]}" --arg f "${WINDOW_FROM[$i]}" --arg t "$(date +%s).000000" \
        '.[$k] = {from: $f, to: $t}' <<<"$windows")"
done
"$CONFIG" journal "$WATCHER" "$(jq -nc --arg ts "$(date +%s)" --arg run_id "$RUN_ID" \
    --arg w "$WATCHER" --arg l "$LANE" --argjson win "$windows" \
    '{ts: ($ts|tonumber), run_id: $run_id, watcher: $w, lane: $l, action: "run_start",
      target: null, sources: [], detail: null, windows: $win}')"

FAILED=false; DEGRADED=false; WORK=false
# Every tool the lane needs, named explicitly. A headless denial comes back as success with
# a polite sentence, so an omitted entry degrades a story rather than failing a run. Both
# Slack and Notion server prefixes are listed because they differ between an interactive
# session and a headless one, and no prompt may hardcode either.
allowed_tools() {
    local list="Bash,Read,Grep,Glob,ToolSearch,Task,Agent,Skill"
    list="$list,mcp__plugin_slack_slack,mcp__claude_ai_Slack"
    list="$list,mcp__claude_ai_Notion,mcp__notion"
    printf '%s' "$list"
}

# Invoked only when the precheck found work. --output-format json is not optional: it is the
# only way to read permission_denials, which is what makes a denial visible at all.
invoke_lane() {
    local root prompt out rc line
    root="$(cd "$HERE/.." && pwd)"
    prompt="Run the epic-watch ${LANE} lane for watcher '${WATCHER}'.

Invoke the watching-an-epic skill and follow it exactly. EPIC_WATCH_ROOT is ${root}.
Your run id is ${EPIC_WATCH_RUN_ID}; put it in every journal record.
The precheck found: ${1:-see the journal}.

Finish with the EPICWATCH_RESULT line described in the skill's reference.md."

    if [ "$DRY_RUN" = true ]; then
        prompt="$prompt

DRY RUN: report what you would file, ask, or comment, and journal it, but make no write
call to Shortcut or Slack. The scripts refuse writes in this mode regardless."
    fi

    local claude_bin
    if ! claude_bin="$(resolve_claude)"; then
        fail_source "cannot resolve claude: not on PATH and no usable env.claude_bin"
        return 0
    fi

    out="$(mktemp "$STATE_TMP/invoke.XXXXXX")"
    set +e
    EPIC_WATCH_DRY_RUN="$([ "$DRY_RUN" = true ] && echo 1 || echo 0)" \
    "$claude_bin" -p "$prompt" \
        ${LANE_MODEL:+--model "$LANE_MODEL"} \
        --max-turns "$MAX_TURNS" \
        --output-format json \
        --allowedTools "$(allowed_tools)" \
        < /dev/null > "$out" 2>"$out.err" &
    local lane_pid=$! waited=0
    while kill -0 "$lane_pid" 2>/dev/null && [ "$waited" -lt "$LANE_DEADLINE" ]; do
        sleep 2; waited=$((waited + 2))
    done
    if kill -0 "$lane_pid" 2>/dev/null; then
        kill -TERM "$lane_pid" 2>/dev/null
        sleep 3
        kill -0 "$lane_pid" 2>/dev/null && kill -KILL "$lane_pid" 2>/dev/null
        wait "$lane_pid" 2>/dev/null
        rc=124
    else
        wait "$lane_pid"; rc=$?
    fi
    set -e
    if [ "$rc" -eq 124 ]; then
        fail_source "lane exceeded its ${LANE_DEADLINE}s deadline and was terminated"
        rm -f "$out" "$out.err"
        return 0
    fi

    # stdin is closed explicitly and stderr kept separate. Without the redirect the CLI waits
    # three seconds and prints a warning; with stderr merged into stdout that warning lands
    # ahead of the JSON and nothing can parse the envelope.

    local denials result
    denials="$(jq -c '.permission_denials // []' "$out" 2>/dev/null || echo '[]')"
    result="$(jq -r '.result // ""' "$out" 2>/dev/null || echo "")"
    line="$(printf '%s' "$result" | grep -o 'EPICWATCH_RESULT .*' | tail -1 || true)"
    # Removed here rather than at the end: the branches below return early, and these live in
    # the persistent state directory, so a scheduled watcher would keep two files per run
    # forever. Anything worth keeping is already in the journal or last_error.
    rm -f "$out" "$out.err"

    if [ -z "$line" ]; then
        fail_source "lane produced no EPICWATCH_RESULT line (claude exit $rc)"
        LANE_DENIALS="$denials"
        return 0
    fi
    LANE_RESULT="${line#EPICWATCH_RESULT }"
    if ! jq -e . >/dev/null 2>&1 <<<"$LANE_RESULT"; then
        fail_source "lane result line is not valid JSON"
        LANE_RESULT=""
        return 0
    fi
    if [ "$(jq -r 'length' <<<"$denials")" -gt 0 ]; then
        fail_source "lane was denied tools: $(jq -r '[.[].tool_name] | join(",")' <<<"$denials")"
        LANE_DENIALS="$denials"
    fi
    apply_result "$LANE_RESULT"
}

# The result line is the only thing that advances a watermark, and only for a source the lane
# reported as ok or partial. A key the config does not contain fails the run rather than
# silently advancing nothing.
# Two phases on purpose. A watermark is the one thing here that cannot be undone: advancing it
# past a message means that message is below the clamp forever, and clearing the breaker does
# not rewind it. So nothing is committed until the whole line has been judged.
apply_result() {
    local res="$1" key status newest row
    local -a pending_keys=() pending_values=()

    # Phase 1: judge.
    if [ "$(jq -r 'has("sources") and has("actions")' <<<"$res")" != true ]; then
        fail_source "lane result line is missing sources or actions"
        return 0
    fi
    local claimed actual
    claimed="$(jq -r '[.actions.filed // 0, .actions.asked // 0, .actions.commented // 0] | add' <<<"$res")"
    actual="$(jq -sr --arg r "$EPIC_WATCH_RUN_ID" \
        '[.[] | select(.run_id == $r) | select(.action == "filed" or .action == "asked" or .action == "commented")] | length' \
        "$JOURNAL" 2>/dev/null || echo 0)"
    if [ "${claimed:-0}" -ne "${actual:-0}" ]; then
        fail_source "lane claimed $claimed actions but journaled $actual"
    fi
    while IFS= read -r row; do
        [ -n "$row" ] || continue
        key="$(jq -r '.[0]' <<<"$row")"
        status="$(jq -r '.[1]' <<<"$row")"
        newest="$(jq -r '.[2] // ""' <<<"$row")"
        case " ${WINDOW_KEYS[*]+${WINDOW_KEYS[*]}} " in
            *" $key "*) ;;
            *) fail_source "lane reported an unknown source key: $key"; continue ;;
        esac
        case "$status" in
            denied|error) fail_source "lane reported $status for $key" ;;
            ok|partial)
                if [ -z "$newest" ] || [ "$newest" = null ]; then
                    fail_source "lane reported $status for $key with no newest_processed"
                elif ! printf '%s' "$newest" | grep -qE '^[0-9]+\.[0-9]+$'; then
                    # It is written straight into persisted state, and a malformed value makes
                    # every later numeric comparison meaningless, so the source stops looking
                    # like it has work until someone repairs the file by hand.
                    fail_source "lane reported a malformed newest_processed for $key: $newest"
                elif [ "$(jq -r --arg k "$key" '.sources[$k].processed // 0' <<<"$res")" -eq 0 ] \
                     && [ "$WORK" = true ]; then
                    # The precheck proved there was something to read. A source claiming it
                    # processed nothing contradicts that, and is what an absent MCP tool looks
                    # like from out here.
                    fail_source "lane reported $status for $key with processed:0 after the precheck found work"
                else
                    pending_keys+=("$key"); pending_values+=("$newest")
                fi
                ;;
            *) fail_source "lane reported an unknown status '$status' for $key" ;;
        esac
    done < <(jq -c '.sources // {} | to_entries[] | [.key, .value.status, .value.newest_processed]' <<<"$res")

    # Recorded even when the run failed: the question is already posted in Slack, and not
    # recording it means the next run asks the same thread again. Only the watermark is unsafe
    # to commit on a run that did not validate.
    # Read as JSON rather than @tsv: TAB is an IFS whitespace character, so an empty field
    # (thread_ts is null for a top-level message) collapses and shifts every later field left,
    # which wrote an ask keyed on the watcher's own question with the baseline lost.
    while IFS= read -r row; do
        [ -n "$row" ] || continue
        ch="$(jq -r '.channel' <<<"$row")"
        thread_ts="$(jq -r '.thread_ts // .message_ts // ""' <<<"$row")"
        ask_ts="$(jq -r '.ask_ts // ""' <<<"$row")"
        baseline="$(jq -c '.reaction_baseline // []' <<<"$row")"
        if [ -z "$thread_ts" ]; then
            fail_source "lane reported an ask with no thread_ts for channel $ch"
            continue
        fi
        [ "$DRY_RUN" = true ] && continue
        "$CONFIG" ask-set "$WATCHER" "$ch:$thread_ts" "$(jq -nc \
            --arg t "$(date +%s)" --arg a "$ask_ts" --argjson b "${baseline:-[]}" \
            '{asked_at: ($t|tonumber), ask_ts: $a, reaction_baseline: $b, status: "open", story_id: null}')"
    done < <(jq -c '.asks // [] | .[]' <<<"$res")

    # Phase 2: commit the watermarks, but only if nothing above objected.
    if [ "$FAILED" = true ]; then
        NOTES+=("watermarks held: the result line did not validate")
        return 0
    fi
    local i
    for i in ${pending_keys[@]+"${!pending_keys[@]}"}; do
        [ "$DRY_RUN" = true ] || "$CONFIG" watermark-set "$WATCHER" "${pending_keys[$i]}" "${pending_values[$i]}"
    done

}

declare -a NOTES=()
LANE_RESULT=""
LANE_DENIALS="[]"
declare -a SOURCES=()
# A citation a checker can resolve, rather than prose in a note.
add_source() { SOURCES+=("$(jq -nc --arg k "$1" --arg r "$2" '{kind:$k, ref:$r, origin:"window"}')"); }

fail_source()     { FAILED=true;   NOTES+=("$1"); }
degrade_source()  { DEGRADED=true; NOTES+=("$1"); }

# Shortcut is probed for the credential, not the data. Without it nothing in 1a ever
# touches shortcut.sh, and the whole point of soaking a watcher is to learn whether the
# scheduled environment can reach Shortcut at all: the token lives in a shell rc file
# that launchd never reads.
if "$SHORTCUT" epic "$EPIC" >/dev/null 2>&1; then :; else
    case $? in
        2) fail_source "shortcut: SHORTCUT_API_TOKEN absent (no fallback exists)" ;;
        4) fail_source "shortcut: credential rejected" ;;
        *) fail_source "shortcut: upstream error" ;;
    esac
fi

# Slack: exit 2 means the shell path was never configured here, which 1a records and does
# not consume. Stage 1b turns the same outcome into a model invocation over MCP.
for i in ${WINDOW_KEYS[@]+"${!WINDOW_KEYS[@]}"}; do
    ch="${CHANNELS[$i]}"; bound="${WINDOW_FROM[$i]}"
    newest="$("$SLACK" latest-ts "$ch" 2>/dev/null)" && rc=0 || rc=$?
    if [ "${rc:-0}" -ne 0 ]; then
        case "$rc" in
            2) degrade_source "slack/$ch: SLACK_USER_TOKEN absent, shell path unavailable" ;;
            4) fail_source "slack/$ch: credential rejected" ;;
            *) fail_source "slack/$ch: upstream error" ;;
        esac
        continue
    fi
    add_source slack_channel "$ch"
    [ -n "$newest" ] || continue
    # Compared against the effective bound, not the raw watermark: a message below the
    # clamp is newer than the watermark yet outside every window the lane can fetch, so
    # comparing against the watermark reports work that can never be done.
    a="${newest//./}"; b="${bound//./}"
    if [ "${a:-0}" -gt "${b:-0}" ]; then WORK=true; NOTES+=("slack/$ch: new messages"); fi
done

# An unanswered ask is not work. An answered one is, and its answer arrives inside a
# thread, which a channel window never shows.
# Run before the loop rather than inside a process substitution, whose subshell would
# discard the FAILED assignment.
reap_out="$(mktemp)"
if "$CONFIG" ask-reap "$WATCHER" "$ASK_EXPIRY" > "$reap_out" 2>/dev/null; then
    while read -r key; do
        [ -n "$key" ] || continue
        journal ask_expired "$(jq -nc --arg k "$key" '$k')"
    done < "$reap_out"
else
    fail_source "ask-reap failed: asks.json unreadable, or expiry '$ASK_EXPIRY' invalid"
fi
rm -f "$reap_out"

while read -r entry; do
    [ -n "$entry" ] || continue
    key="$(jq -r '.key' <<<"$entry")"
    ch="${key%%:*}"; msg_ts="${key#*:}"
    ask_ts="$(jq -r '.value.ask_ts' <<<"$entry")"
    baseline="$(jq -c '.value.reaction_baseline // []' <<<"$entry")"
    if replies="$("$SLACK" thread-replies "$ch" "$msg_ts" 2>/dev/null)"; then :; else
        case $? in
            2) degrade_source "slack/$ch: shell path unavailable for ask $key" ;;
            *) fail_source "slack/$ch: thread-replies failed for ask $key" ;;
        esac
        continue
    fi
    # Dots stripped first, so both sides are integers below 2^53 and the comparison is exact.
    ask_micros="$(printf '%s' "${ask_ts//./}")"
    answered="$(jq -r --arg ask "$ask_micros" --arg self "$SELF_ID" \
        '[.messages[]? | select(((.ts | gsub("\\.";"")) | tonumber) > ($ask | tonumber))
           | select(.user != null and .user != $self)] | length' <<<"$replies")"
    if [ "${answered:-0}" -gt 0 ]; then
        WORK=true; NOTES+=("ask $key: replied"); add_source slack_thread "$ch:$msg_ts"; continue
    fi
    # A yes is likeliest as a reaction on the watcher's own question, which starts with
    # none, so any reaction there counts. A reaction on the reported message counts only
    # if it was not already in the baseline.
    for probe_ts in "$ask_ts" "$msg_ts"; do
        if r="$("$SLACK" reactions "$ch" "$probe_ts" 2>/dev/null)"; then :; else
            case $? in
                2) degrade_source "slack/$ch: shell path unavailable for reactions on $probe_ts" ;;
                *) fail_source "slack/$ch: reactions failed for $probe_ts" ;;
            esac
            continue
        fi
        names="$(jq -c '[.message.reactions[]?.name]' <<<"$r")"
        if [ "$probe_ts" = "$ask_ts" ]; then
            [ "$(jq -r 'length' <<<"$names")" -gt 0 ] && { WORK=true; NOTES+=("ask $key: reaction on question"); add_source slack_thread "$ch:$msg_ts"; }
        else
            new="$(jq -r --argjson b "$baseline" '[.[] | select(. as $n | ($b | index($n)) == null)] | length' <<<"$names")"
            [ "${new:-0}" -gt 0 ] && { WORK=true; NOTES+=("ask $key: new reaction on report"); add_source slack_thread "$ch:$msg_ts"; }
        fi
    done
done < <("$CONFIG" ask-list "$WATCHER" open 2>/dev/null || true)

# The lane runs before the health decision, so anything it reports as a failure counts the
# same as a precheck failure. Invoking after the decision would leave a denied or malformed
# run recorded as healthy.
if [ "$WORK" = true ] && [ "$FAILED" != true ]; then
    invoke_lane "$(printf '%s; ' "${NOTES[@]+"${NOTES[@]}"}")"
fi

notes_json="$(printf '%s\n' "${NOTES[@]+"${NOTES[@]}"}" | jq -Rsc 'split("\n") | map(select(. != ""))')"
if [ ${#SOURCES[@]} -eq 0 ]; then sources_json='[]'; else sources_json="$(printf '%s\n' "${SOURCES[@]}" | jq -sc .)"; fi

if [ "$FAILED" = true ]; then
    FAILURES=$((FAILURES + 1))
    patch="$(jq -nc --arg t "$(date +%s)" --argjson f "$FAILURES" --argjson n "$notes_json" \
        --argjson d "$LANE_DENIALS" \
        '{last_run: ($t|tonumber), consecutive_failures: $f, last_error: {class: "lane", detail: $n, denials: $d}}')"
    if [ "$FAILURES" -ge "$BREAKER_TRIP_AT" ]; then
        patch="$(jq -c --arg t "$(date +%s)" '. + {breaker: "open", breaker_opened_at: ($t|tonumber)}' <<<"$patch")"
        "$CONFIG" alert-set "$WATCHER" "$(jq -nc --arg t "$(date +%s)" --arg l "$LANE" --argjson n "$notes_json" \
            '{ts: ($t|tonumber), lane: $l, class: "breaker", detail: $n}')"
    fi
    health "$patch"
    journal failed null "$notes_json"
    journal run_end
    COMPLETED=true
    exit 0
fi

# Any degradation withholds last_success. "At least one source was fine" passes the case
# where the source the lane depends on is the dead one.
if [ "$DEGRADED" = true ]; then
    # A degraded run is not a failure, so it closes the breaker. On a machine whose Slack
    # path is permanently unconfigured, every run is degraded, and gating the close on a
    # fully clean run would leave the breaker open for good.
    health "$(jq -nc --arg t "$(date +%s)" --argjson n "$notes_json" \
        '{last_run: ($t|tonumber), consecutive_failures: 0, breaker: "closed", fires_since_open: 0, breaker_opened_at: null, last_error: {class: "degraded", detail: $n, denials: []}}')"
    "$CONFIG" clear-launch-failure "$WATCHER" "$LANE" >/dev/null 2>&1 || true
    journal degraded null "$notes_json"
    journal run_end
    COMPLETED=true
    exit 0
fi

now_s="$(date +%s)"
patch="$(jq -nc --argjson t "$now_s" \
    '{last_run: $t, last_success: $t, consecutive_failures: 0, breaker: "closed", fires_since_open: 0, breaker_opened_at: null, last_error: null}')"
health "$patch"
# Any run that got this far proves the launcher works now.
"$CONFIG" clear-launch-failure "$WATCHER" "$LANE" >/dev/null 2>&1 || true
# A quiet run cites what it examined too, so the journal answers "what did you look at"
# and not merely "did you find anything".
if [ "$WORK" = true ]; then
    journal pending_work null "$notes_json" "$sources_json"
else
    journal quiet null null "$sources_json"
fi
journal run_end
COMPLETED=true
