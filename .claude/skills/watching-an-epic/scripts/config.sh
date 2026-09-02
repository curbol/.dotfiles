#!/bin/bash
# Config and state for a named watcher. Sole writer of config.json, watermarks.json,
# journal.ndjson, health.json, and the ALERT marker.
#
# Exit codes: 0 ok  1 usage  2 configuration absent or invalid  3 lock already held
#
# Everything here is one writer on purpose. Each of these files is either append-only or
# read-modify-written by more than one caller, so a second writer with its own jq is how
# they diverge.

set -euo pipefail

MAX_LOOKBACK_SECONDS=604800   # 7 days: a watcher must not be configurable to trawl a quarter
ASK_GRACE_SECONDS=900         # a pending ask older than this never got posted
# Wider than run-lane's own lane deadline, so a slow-but-healthy run is never mistaken for a
# wedged one. A holder still alive past this has outlived the bound its own runner enforces.
LOCK_MAX_AGE_SECONDS=1800

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/epic-watch"
STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}/epic-watch"

die() { printf '%s\n' "$2" >&2; exit "$1"; }
command -v jq >/dev/null 2>&1 || die 2 "jq is required but not installed"

now() { date +%s; }

# A watcher name reaches rm -rf, sed replacements, plist XML and jq programs, so it is
# constrained at every entry point rather than trusted from any of them.
require_name() {
    case "${1:-}" in
        ""|*[!abcdefghijklmnopqrstuvwxyz0123456789-]*) die 1 "invalid watcher name: '${1:-}' (lowercase letters, digits and dashes)" ;;
    esac
}

# The lane reaches mkdir, rm -rf and jq programs on the same paths the name does.
require_lane() {
    case "${1:-}" in
        intake|groom|docs) ;;
        *) die 1 "invalid lane: '${1:-}'" ;;
    esac
}

# GNU first: BSD stat rejects -c cleanly with nothing on stdout, whereas GNU stat reads -f as
# --file-system, prints a filesystem dump to stdout, and only then exits 1 — so the reverse
# order returns that dump with the real value appended.
file_mtime() { stat -c '%Y' "$1" 2>/dev/null || stat -f '%m' "$1" 2>/dev/null; }

# `ps -p`, not `kill -0`: kill -0 fails with EPERM for a process you do not own, so a holder
# belonging to another user, or a recycled pid, would read as gone and its lock would be taken.
# An un-signalable process is exactly the one it is least safe to step over.
pid_alive() { ps -p "$1" >/dev/null 2>&1; }

# Slack ts values are fixed-point strings; comparing them as microsecond integers is exact
# and stays inside integer arithmetic, which is the only kind that is portable here.
ts_to_micros() { local t="${1:-0}"; case "$t" in *.*) printf '%s' "${t//./}" ;; *) printf '%s000000' "$t" ;; esac; }
seconds_to_ts() { printf '%s.000000' "$1"; }

config_file() { printf '%s/%s/config.json' "$CONFIG_HOME" "$1"; }
state_dir()   { printf '%s/%s' "$STATE_HOME" "$1"; }
env_file()    { printf '%s/env' "$CONFIG_HOME"; }

# Replace-by-rename so a killed write leaves the previous file intact.
# Replaces the target only when the producer succeeded and wrote something.
write_atomic() {
    local target="$1" tmp rc
    tmp="$(mktemp "${target}.XXXXXX")"
    cat > "$tmp"; rc=$?
    if [ "$rc" -ne 0 ] || [ ! -s "$tmp" ]; then rm -f "$tmp"; return 1; fi
    mv "$tmp" "$target"
}

# Falls back when the file is absent or unparseable, so one corrupt state file cannot stop
# every future run.
read_json_or() {
    [ -f "$1" ] || { printf '%s' "$2"; return 0; }
    jq -e . "$1" >/dev/null 2>&1 && cat "$1" || printf '%s' "$2"
}

parse_duration() {
    # A whole number with at most one unit.
    case "$1" in
        ""|*[!0123456789hmd]*|*[hmd]*[hmd]*|[hmd]*) die 2 "not a duration: $1" ;;
    esac
    # Bounded before the multiply: a value long enough to overflow wraps negative, passes the
    # MAX_LOOKBACK comparison, and yields a clamp far in the future that nothing can exceed.
    case "${1%[hmd]}" in ??????????*) die 2 "duration out of range: $1" ;; esac
    case "$1" in
        *h) printf '%s' $(( ${1%h} * 3600 )) ;;
        *m) printf '%s' $(( ${1%m} * 60 )) ;;
        *d) printf '%s' $(( ${1%d} * 86400 )) ;;
        *)  printf '%s' "$1" ;;
    esac
}

validate() {
    local cfg="$1" err=()
    local epic; epic="$(jq -r '.epic // ""' <<<"$cfg")"
    [[ "$epic" =~ ^[0-9]+$ ]] || err+=("epic must be present and numeric")
    [ "$(jq -r '(.slack_channels | type) == "array"' <<<"$cfg")" = true ] || err+=("slack_channels must be an array")
    [ "$(jq -r '(.slack_channels // []) | length' <<<"$cfg")" -gt 0 ] 2>/dev/null || err+=("slack_channels must be non-empty")
    [ "$(jq -r '(.doc_surfaces | type) == "array"' <<<"$cfg")" = true ] || err+=("doc_surfaces must be an array")
    [ "$(jq -r '(.lanes | type) == "object"' <<<"$cfg")" = true ] || err+=("lanes must be an object")
    case "$(jq -r '.intake_state.workflow_id // ""' <<<"$cfg")" in
        ""|*[!0123456789]*) err+=("intake_state.workflow_id must be numeric") ;;
    esac
    case "$(jq -r '.intake_state.workflow_state_id // ""' <<<"$cfg")" in
        ""|*[!0123456789]*) err+=("intake_state.workflow_state_id must be numeric") ;;
    esac
    [ "$(jq -r '.slack_workspace // ""' <<<"$cfg")" != "" ] || err+=("slack_workspace is required")
    # Required outright: the answered-ask rule compares reply authors against it, so a
    # config without it makes the watcher's own question read as a human answer.
    [ "$(jq -r '.slack_self_id // ""' <<<"$cfg")" != "" ] || err+=("slack_self_id is required")
    [ "$(jq -r 'if (.lanes | type) == "object" then (.lanes | length) else 0 end' <<<"$cfg")" -gt 0 ] \
        || err+=("lanes must be present and non-empty")
    while read -r lane; do
        [ -z "$lane" ] && continue
        case "$lane" in intake|groom|docs) ;; *) err+=("unknown lane: $lane") ;; esac
    done < <(jq -r '(.lanes // {}) | keys[]' <<<"$cfg")
    local ask_expiry; ask_expiry="$(parse_duration "$(jq -r '.ask_expiry // "72h"' <<<"$cfg")")" \
        || err+=("ask_expiry is not a duration")
    [ "${ask_expiry:-0}" -gt 0 ] 2>/dev/null || err+=("ask_expiry must be a positive duration")
    local lookback; lookback="$(parse_duration "$(jq -r '.lookback // "24h"' <<<"$cfg")")" \
        || err+=("lookback is not a duration")
    [ "${lookback:-0}" -gt 0 ] 2>/dev/null || err+=("lookback must be a positive duration")
    [ "${lookback:-0}" -le "$MAX_LOOKBACK_SECONDS" ] 2>/dev/null \
        || err+=("lookback exceeds MAX_LOOKBACK of ${MAX_LOOKBACK_SECONDS}s")
    # The pipe keeps `//` inside the iteration. Applied to the empty stream instead, it
    # emits one "null" for an empty array, indistinguishable from an entry with no page.
    while read -r page; do
        [ "$page" = "null" ] && err+=("doc_surfaces entry without notion_page")
    done < <(jq -r '.doc_surfaces[]? | .notion_page // "null"' <<<"$cfg")
    if [ ${#err[@]} -gt 0 ]; then
        printf 'invalid config:\n' >&2
        printf '  - %s\n' "${err[@]}" >&2
        exit 2
    fi
}

usage() {
    cat >&2 <<'USAGE'
Usage: config.sh <command> [args...]
  init <name> <config-json> [env-json]   write config.json and the 0600 env file
  validate <name>                        validate config.json
  show <name>                            print config.json
  list                                   list watcher names
  set-env <name> <key> <value>           set one config .env field
  watermark-get <name> <key>             print a watermark value ("" if unset)
  watermark-set <name> <key> <value> [backfill-latest]
  effective-bound <name> <key> <lookback>
                                         max(watermark, now - lookback) as a Slack ts
  ask-list <name> [status]               list ask registry entries
  ask-set <name> <key> <json>            upsert one ask entry
  ask-reap <name> <ask-expiry>           expire stale open and pending asks; prints keys
  journal <name> <json>                  append one journal record
  health-get <name>                      print health.json merged with launch-failure.json
  health-set <name> <lane> <json>        merge fields into one lane's health
  reset <name> <lane>                    close breaker, zero counters, clear the marker
  alert-set <name> <json>                write the ALERT marker
  clear-launch-failure <name> [lane]     remove launch-failure.json; the marker only when it
                                         belongs to <lane>, or unconditionally with no lane
  clear-alert <name>                     remove the ALERT marker
  lock-acquire <name> <lane> <holder-pid>   exit 0 acquired, 3 already held
  lock-release <name> <lane> [holder-pid]   with a pid, releases only if it still holds
USAGE
    exit 1
}

cmd="${1:-}"; shift || usage
case "$cmd" in list) ;; *) require_name "${1:-}" ;; esac
# Only the subcommands whose second argument really is a lane. alert-set takes JSON there.
case "$cmd" in
    reset|health-set|lock-acquire|lock-release) require_lane "${2:-}" ;;
esac

case "$cmd" in
init)
    [ $# -ge 2 ] || usage
    name="$1"; cfg="$2"; envjson="${3:-}"
    validate "$cfg"
    mkdir -p "$(dirname "$(config_file "$name")")" "$(state_dir "$name")"
    jq -S . <<<"$cfg" | write_atomic "$(config_file "$name")"
    # The env file is the only place secrets live. It is never inlined into a plist,
    # because ~/Library/LaunchAgents is plaintext, world-readable by default, and backed up.
    ef="$(env_file)"
    if [ -n "$envjson" ] && [ "$envjson" != "{}" ]; then
        # Checked before the merge: the parse error otherwise happens inside a process
        # substitution, where the loop sees nothing and the previous file is rewritten
        # unchanged, so a bad payload reported success and dropped the tokens.
        jq -e . <<<"$envjson" >/dev/null 2>&1 || die 2 "env json is not valid JSON"
        umask 077
        # Merged, not replaced: the env file is shared by every watcher on the machine.
        tmp_env="$(mktemp)"
        [ -f "$ef" ] && cp "$ef" "$tmp_env"
        while IFS= read -r line; do
            key="${line%%=*}"; key="${key#export }"
            grep -v "^export ${key}=" "$tmp_env" > "$tmp_env.new" 2>/dev/null || : > "$tmp_env.new"
            mv "$tmp_env.new" "$tmp_env"
            printf '%s\n' "$line" >> "$tmp_env"
        done < <(jq -r 'to_entries[] | "export \(.key)=\(.value | @sh)"' <<<"$envjson")
        cat "$tmp_env" | write_atomic "$ef"
        rm -f "$tmp_env"
        chmod 600 "$ef"
    fi
    printf '%s\n' "$(config_file "$name")"
    ;;
validate)
    [ $# -eq 1 ] || usage
    f="$(config_file "$1")"; [ -f "$f" ] || die 2 "no config for watcher $1"
    validate "$(cat "$f")"; echo ok
    ;;
show)     [ $# -eq 1 ] || usage; f="$(config_file "$1")"; [ -f "$f" ] || die 2 "no config for watcher $1"; cat "$f" ;;
list)
    [ -d "$CONFIG_HOME" ] || exit 0
    find "$CONFIG_HOME" -mindepth 2 -maxdepth 2 -name config.json 2>/dev/null | awk -F/ '{print $(NF-1)}' | sort
    ;;
set-env)
    [ $# -eq 3 ] || usage
    f="$(config_file "$1")"
    [ -f "$f" ] || die 2 "no config for watcher $1"
    jq -e . "$f" >/dev/null 2>&1 || die 2 "refusing to rewrite $f: it is not valid JSON"
    jq -S --arg k "$2" --arg v "$3" '.env[$k] = $v' "$f" | write_atomic "$f" \
        || die 2 "failed to write $f"
    ;;
watermark-get)
    [ $# -eq 2 ] || usage
    jq -r --arg k "$2" '.[$k].value // ""' <<<"$(read_json_or "$(state_dir "$1")/watermarks.json" '{}')"
    ;;
watermark-set)
    [ $# -ge 3 ] || usage
    f="$(state_dir "$1")/watermarks.json"; mkdir -p "$(dirname "$f")"
    jq -S --arg k "$2" --arg v "$3" --arg b "${4:-}" \
       '.[$k] = {value: $v, backfill_latest: (if $b == "" then null else $b end)}' \
       <<<"$(read_json_or "$f" '{}')" | write_atomic "$f"
    ;;
effective-bound)
    # The probe and the fetch must agree on the lower bound. Comparing against the raw
    # watermark instead would report work forever for a message that sits below the clamp,
    # since the fetch could never return it.
    [ $# -eq 3 ] || usage
    wm="$(jq -r --arg k "$2" '.[$k].value // ""' <<<"$(read_json_or "$(state_dir "$1")/watermarks.json" '{}')")"
    clamp="$(seconds_to_ts $(( $(now) - $(parse_duration "$3") )))"
    if [ -z "$wm" ] || [ "$(ts_to_micros "$wm")" -lt "$(ts_to_micros "$clamp")" ]; then
        printf '%s\n' "$clamp"
    else
        printf '%s\n' "$wm"
    fi
    ;;
ask-list)
    [ $# -ge 1 ] || usage
    jq -c --arg s "${2:-}" 'to_entries[] | select($s == "" or .value.status == $s)' \
        <<<"$(read_json_or "$(state_dir "$1")/asks.json" '{}')"
    ;;
ask-set)
    [ $# -eq 3 ] || usage
    f="$(state_dir "$1")/asks.json"; mkdir -p "$(dirname "$f")"
    jq -S --arg k "$2" --argjson v "$3" '.[$k] = $v' <<<"$(read_json_or "$f" '{}')" \
        | write_atomic "$f" || die 2 "refusing to write $f: the ask payload is not valid JSON"
    ;;
ask-reap)
    # pending is written before the Slack post, so a crash leaves one nothing else moves;
    # reaping it to expired keeps the bias toward never double-asking.
    [ $# -eq 2 ] || usage
    f="$(state_dir "$1")/asks.json"; [ -f "$f" ] || exit 0
    expiry_secs="$(parse_duration "$2")" || exit 2
    cutoff_open=$(( $(now) - expiry_secs ))
    cutoff_pending=$(( $(now) - ASK_GRACE_SECONDS ))
    jq -r --argjson o "$cutoff_open" --argjson p "$cutoff_pending" \
        'to_entries[] | select((.value.status == "open" and .value.asked_at < $o)
                            or (.value.status == "pending" and .value.asked_at < $p)) | .key' "$f"
    jq -S --argjson o "$cutoff_open" --argjson p "$cutoff_pending" \
        'with_entries(if (.value.status == "open" and .value.asked_at < $o)
                       or (.value.status == "pending" and .value.asked_at < $p)
                      then .value.status = "expired" else . end)' "$f" | write_atomic "$f"
    ;;
journal)
    [ $# -eq 2 ] || usage
    d="$(state_dir "$1")"; mkdir -p "$d"
    jq -c . <<<"$2" >> "$d/journal.ndjson"
    ;;
health-get)
    [ $# -eq 1 ] || usage
    d="$(state_dir "$1")"
    h="$(read_json_or "$d/health.json" "{\"watcher\":\"$1\",\"lanes\":{}}")"
    # The launcher cannot call into these scripts, so it writes its own file and the merge
    # happens here at read time rather than by a second writer of health.json.
    lf="$(read_json_or "$d/launch-failure.json" 'null')"
    alert="$(read_json_or "$d/ALERT" 'null')"
    # A launch failure predating the newest success has been repaired; reporting it forever
    # would make a healthy watcher look broken, since the launcher never touches the breaker.
    # Any run that got this far supersedes a launcher failure, which by definition
    # stopped one. last_success alone would never advance on a machine whose Slack path is
    # unconfigured, so a repaired failure would be reported forever.
    newest_success="$(jq -r '[.lanes[]?.last_run // 0, .lanes[]?.last_success // 0] | max // 0' <<<"$h")"
    # A marker older than the newest success describes a condition that has since cleared.
    # Suppressing the launch failure but still reporting its marker would leave status
    # announcing an alert it can no longer explain.
    jq -S --argjson lf "$lf" --argjson al "$alert" --argjson ok "${newest_success:-0}" '
        . + (if $lf == null or ($lf.ts // 0) < $ok then {} else {launch_failure: $lf} end)
          + (if $al == null or ($al.ts // 0) < $ok then {} else {alert: $al} end)' <<<"$h"
    ;;
health-set)
    [ $# -eq 3 ] || usage
    d="$(state_dir "$1")"; mkdir -p "$d"; f="$d/health.json"
    jq -S --arg lane "$2" --argjson patch "$3" \
        '.watcher = (.watcher // "'"$1"'") | .lanes[$lane] = ((.lanes[$lane] // {}) + $patch)' \
        <<<"$(read_json_or "$f" "{\"watcher\":\"$1\",\"lanes\":{}}")" | write_atomic "$f"
    ;;
reset)
    [ $# -eq 2 ] || usage
    d="$(state_dir "$1")"; mkdir -p "$d"; f="$d/health.json"
    jq -S --arg lane "$2" \
        '.lanes[$lane] = ((.lanes[$lane] // {}) + {breaker: "closed", consecutive_failures: 0, fires_since_open: 0, breaker_opened_at: null})' \
        <<<"$(read_json_or "$f" "{\"watcher\":\"$1\",\"lanes\":{}}")" | write_atomic "$f"
    rm -f "$d/ALERT"
    ;;
alert-set)
    [ $# -eq 2 ] || usage
    d="$(state_dir "$1")"; mkdir -p "$d"
    jq -c . <<<"$2" | write_atomic "$d/ALERT"
    ;;
clear-launch-failure)
    [ $# -ge 1 ] || usage
    d="$(state_dir "$1")"; rm -f "$d/launch-failure.json"
    # One marker slot per watcher, so a lane may only clear its own: otherwise a clean run in
    # one lane erases another lane's open-breaker alert while health still reports it open.
    if [ -f "$d/ALERT" ]; then
        if [ $# -lt 2 ] || [ "$(jq -r '.lane // ""' "$d/ALERT" 2>/dev/null)" = "$2" ]; then
            rm -f "$d/ALERT"
        fi
    fi
    ;;
clear-alert)
    [ $# -eq 1 ] || usage
    rm -f "$(state_dir "$1")/ALERT"
    ;;
lock-acquire)
    # mkdir, not flock: macOS ships no flock, while CI's ubuntu does, so a flock guard
    # would pass CI and fail on the target. The holder pid comes from the caller because a
    # pid this short-lived process recorded would be dead on return.
    [ $# -eq 3 ] || usage
    d="$(state_dir "$1")"; mkdir -p "$d"; lock="$d/$2.lock.d"
    if mkdir "$lock" 2>/dev/null; then printf '%s\n' "$3" > "$lock/pid"; exit 0; fi
    # An unreadable pid means the owner has not finished publishing it, not that it is dead.
    holder="$(cat "$lock/pid" 2>/dev/null || echo "")"
    case "$holder" in ""|*[!0123456789]*) exit 3 ;; esac
    age=$(( $(now) - $(file_mtime "$lock" 2>/dev/null || echo 0) ))
    if [ "$holder" -gt 0 ] && pid_alive "$holder"; then
        # A live holder is never simply stepped over: two runs acting at once is worse than a
        # lane that waits. Inside the window, wait. Past it the holder has outlived the wall
        # clock bound its own runner enforces, so it is stopped before the lane changes hands,
        # and if it will not stop the takeover is refused rather than run alongside it.
        [ "$age" -lt "$LOCK_MAX_AGE_SECONDS" ] && exit 3
        # `|| true` on both signals: killing a process this user does not own fails with
        # EPERM, and a bare failing command aborts the script under set -e, which turned a
        # refusal into a usage-code exit.
        kill -TERM "$holder" 2>/dev/null || true
        sleep 3
        if pid_alive "$holder"; then
            kill -KILL "$holder" 2>/dev/null || true
            sleep 1
        fi
        if pid_alive "$holder"; then exit 3; fi
    fi
    # An aged-out marker is itself reclaimed. A crash inside the takeover window would
    # otherwise wedge the lane for good, and a lock_skip run writes no health entry, so
    # nothing would report it.
    if [ -d "$lock.takeover" ]; then
        t_age=$(( $(now) - $(file_mtime "$lock.takeover" 2>/dev/null || echo 0) ))
        [ "$t_age" -ge "$LOCK_MAX_AGE_SECONDS" ] && rmdir "$lock.takeover" 2>/dev/null
    fi
    if mkdir "$lock.takeover" 2>/dev/null; then
        rm -rf "$lock"
        if mkdir "$lock" 2>/dev/null; then
            printf '%s\n' "$3" > "$lock/pid"
            rmdir "$lock.takeover"
            exit 0
        fi
        rmdir "$lock.takeover"
    fi
    exit 3
    ;;
lock-release)
    [ $# -lt 2 ] && usage
    lock="$(state_dir "$1")/$2.lock.d"
    # Only the recorded holder may release. Age-based reclaim can hand the lane to a
    # replacement while a long run is still going, and an unchecked release would then free
    # the replacement's lock rather than its own.
    if [ $# -ge 3 ] && [ -f "$lock/pid" ] && [ "$(cat "$lock/pid" 2>/dev/null)" != "$3" ]; then
        exit 3
    fi
    rm -rf "$lock" "$lock.takeover"
    ;;
*) usage ;;
esac
