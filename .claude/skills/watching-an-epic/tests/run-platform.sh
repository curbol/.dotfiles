#!/bin/bash
# Platform-gated checks: they drive launchctl or systemctl and the OS plist linter, so they
# cannot run on the CI runner. Kept out of run.sh so a green CI never implies they passed.
#
# Config, state, and the launcher path are redirected into a sandbox, so a live watcher's
# files are safe. The scheduler itself cannot be sandboxed: the install lifecycle really does
# load a unit into your user launchd or systemd domain. Watcher names are therefore unique per
# run (`zw<pid>...`), so this can never disable a watcher you actually rely on, and the sandbox
# is removed only after every unit it installed is confirmed gone.

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S="$(cd "$HERE/.." && pwd)/scripts"

PASS=0; FAIL=0; SKIP=0
ok(){ PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad(){ FAIL=$((FAIL+1)); printf '  FAIL %s\n     expected: %s\n     actual:   %s\n' "$1" "$2" "$3"; }
skip(){ SKIP=$((SKIP+1)); printf '  skip %s (%s)\n' "$1" "$2"; }
eq(){ [ "$2" = "$3" ] && ok "$1" || bad "$1" "$2" "$3"; }

SANDBOX="$(mktemp -d)"

# Unique per run, so a name collision cannot unschedule a watcher someone depends on.
PFX="zw$$"
W_MAIN="$PFX"
W_SIB="$PFX-two"
INSTALLED_WATCHERS="$W_MAIN $W_SIB"

# Exact unit names per lane, not a prefix glob: `epic-watch@<watcher>-<lane>` means
# `<watcher>-`* also matches a sibling called `<watcher>-two`, which this suite creates on
# purpose, so cleanup would report the sibling's units as this watcher's leftovers.
units_for() {
    find "$HOME/Library/LaunchAgents" -name "com.gladly.epic-watch.$1.*.plist" 2>/dev/null
    for lane in intake groom docs; do
        for suffix in timer service; do
            f="$HOME/.config/systemd/user/epic-watch@$1-$lane.$suffix"
            [ -f "$f" ] && printf '%s\n' "$f"
        done
    done
}

# An interrupted run must still unload its units: a job whose program points into a deleted
# sandbox keeps firing. The sandbox is only removed once none of them remain, and a unit that
# will not unload is reported rather than swallowed.
cleanup_platform() {
    local script left=0
    script="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/install-schedule.sh"
    for w in $INSTALLED_WATCHERS; do
        "$script" --unschedule "$w" >/dev/null 2>&1 || true
        if [ -n "$(units_for "$w")" ]; then
            printf 'cleanup: units for %s still present; leaving %s in place\n' "$w" "$SANDBOX" >&2
            left=1
        fi
    done
    [ "$left" -eq 0 ] && rm -rf "$SANDBOX"
}
trap cleanup_platform EXIT
export XDG_CONFIG_HOME="$SANDBOX/config" XDG_STATE_HOME="$SANDBOX/state" XDG_DATA_HOME="$SANDBOX/data"
export HOME="$SANDBOX/home"; mkdir -p "$HOME/Library/LaunchAgents" "$HOME/.config/systemd/user"

CFG='{"name":"WMAIN","epic":1,"team":"g","intake_state":{"name":"U","workflow_id":10,"workflow_state_id":20},"slack_workspace":"gladly","slack_self_id":"USELF","slack_channels":["C1"],"repos":[],"doc_surfaces":[],"lookback":"24h","ask_expiry":"72h","max_files_per_run":5,"max_asks_per_run":2,"lanes":{"intake":"hourly"}}'
CFG="$(jq -c --arg n "$W_MAIN" '.name=$n' <<<"${CFG/WMAIN/$W_MAIN}")"
"$S/config.sh" init "$W_MAIN" "$CFG" >/dev/null

printf '\nrendered unit validity\n'
"$S/install-schedule.sh" --render "$W_MAIN" intake > "$SANDBOX/unit"
case "$(uname -s)" in
Darwin)
    if command -v plutil >/dev/null 2>&1; then
        plutil -lint "$SANDBOX/unit" >/dev/null 2>&1 && ok "plutil -lint accepts the plist" \
            || bad "plutil -lint" "OK" "$(plutil -lint "$SANDBOX/unit" 2>&1)"
    else
        skip "plutil -lint" "plutil not present"
    fi
    ;;
*)
    # --render emits the timer and the service around a separator, so they are split before
    # verification; systemd rejects a file holding both.
    rendered="$(cat "$SANDBOX/unit")"
    printf '%s' "${rendered%%$'\n'### service ###*}" > "$SANDBOX/u.timer"
    printf '%s' "${rendered#*### service ###$'\n'}" > "$SANDBOX/u.service"
    eq "timer half parses as an ini section" "true" \
       "$(grep -q '^\[Timer\]' "$SANDBOX/u.timer" && grep -q '^OnCalendar=' "$SANDBOX/u.timer" && echo true || echo false)"
    eq "service half names the launcher" "true" \
       "$(grep -q "^ExecStart=$XDG_DATA_HOME/epic-watch/bin/epic-watch-launch" "$SANDBOX/u.service" && echo true || echo false)"
    if command -v systemd-analyze >/dev/null 2>&1; then
        systemd-analyze verify "$SANDBOX/u.service" >/dev/null 2>&1 \
            && ok "systemd-analyze accepts the service" \
            || bad "systemd-analyze verify" "clean" "$(systemd-analyze verify "$SANDBOX/u.service" 2>&1 | head -2)"
    else
        skip "systemd-analyze verify" "not present"
    fi
    ;;
esac

printf '\ninstall lifecycle\n'
# Only exercised where the scheduler actually exists; loading a unit is the whole point.
case "$(uname -s)" in
Darwin) have_sched=$(command -v launchctl >/dev/null 2>&1 && echo yes || echo no) ;;
*)      have_sched=$(command -v systemctl >/dev/null 2>&1 && echo yes || echo no) ;;
esac
if [ "$have_sched" != yes ]; then
    skip "install lifecycle" "no scheduler on this host"
else
    SHORTCUT_API_TOKEN="${SHORTCUT_API_TOKEN:-}" "$S/install-schedule.sh" --install "$W_MAIN" >/dev/null 2>&1
    eq "launcher copied to the stable path" "0" \
       "$( [ -x "$XDG_DATA_HOME/epic-watch/bin/epic-watch-launch" ] && echo 0 || echo 1 )"
    eq "skill_root recorded for the launcher" "true" \
       "$("$S/config.sh" show "$W_MAIN" | jq -r '.env.skill_root != null')"
    # Contents, not the path list: a re-install that rewrites a unit body would otherwise
    # produce the same hash.
    hash_units() { find "$HOME/Library/LaunchAgents" "$HOME/.config/systemd/user" -type f 2>/dev/null | sort | xargs cat 2>/dev/null | shasum | cut -d' ' -f1; }
    before="$(hash_units)"
    "$S/install-schedule.sh" --install "$W_MAIN" >/dev/null 2>&1
    after="$(hash_units)"
    eq "install is idempotent" "$before" "$after"

    # A launcher fix must reach the scheduled run. Content, not a declared version: an edit
    # during a soak has no version to bump, and the copy at the stable path is the one that
    # actually runs, so a stale one there is invisible until a fire goes wrong.
    printf 'stale\n' > "$XDG_DATA_HOME/epic-watch/bin/epic-watch-launch"
    "$S/install-schedule.sh" --install "$W_MAIN" >/dev/null 2>&1
    eq "a stale launcher is re-copied" "false" \
       "$(grep -qx stale "$XDG_DATA_HOME/epic-watch/bin/epic-watch-launch" && echo true || echo false)"
    eq "  matching the checkout byte for byte" "true" \
       "$(cmp -s "$S/epic-watch-launch" "$XDG_DATA_HOME/epic-watch/bin/epic-watch-launch" \
          && echo true || echo false)"

    "$S/install-schedule.sh" --unschedule "$W_MAIN" >/dev/null 2>&1
    eq "unschedule removes the scheduler entry" "0" \
       "$(find "$HOME/Library/LaunchAgents" "$HOME/.config/systemd/user" -name '*epic-watch*' 2>/dev/null | wc -l | tr -d ' ')"
    eq "unschedule removes the launcher" "1" \
       "$( [ -f "$XDG_DATA_HOME/epic-watch/bin/epic-watch-launch" ] && echo 0 || echo 1 )"
    eq "unschedule KEEPS state" "0" \
       "$( [ -d "$XDG_STATE_HOME/epic-watch/$W_MAIN" ] && echo 0 || echo 1 )"
    "$S/install-schedule.sh" --purge "$W_MAIN" >/dev/null 2>&1
    eq "purge removes state" "1" \
       "$( [ -d "$XDG_STATE_HOME/epic-watch/$W_MAIN" ] && echo 0 || echo 1 )"

    # A watcher whose name is a dash-prefix of another. Unit files are
    # epic-watch@<watcher>-<lane>, so globbing on the name alone also matches the sibling,
    # and kebab-case names are what the setup command tells users to pick.
    "$S/config.sh" init "$W_MAIN" "$(jq -c --arg n "$W_MAIN" '.name=$n' <<<"$CFG")" >/dev/null
    "$S/config.sh" init "$W_SIB" "$(jq -c --arg n "$W_SIB" '.name=$n' <<<"$CFG")" >/dev/null
    "$S/install-schedule.sh" --install "$W_MAIN" >/dev/null 2>&1
    "$S/install-schedule.sh" --install "$W_SIB" >/dev/null 2>&1
    sib_before="$(find "$HOME/Library/LaunchAgents" "$HOME/.config/systemd/user" -name "*$W_SIB*" 2>/dev/null | wc -l | tr -d ' ')"
    "$S/install-schedule.sh" --unschedule "$W_MAIN" >/dev/null 2>&1
    eq "unscheduling a dash-prefix name leaves its sibling scheduled" "$sib_before" \
       "$(find "$HOME/Library/LaunchAgents" "$HOME/.config/systemd/user" -name "*$W_SIB*" 2>/dev/null | wc -l | tr -d ' ')"
    eq "  and the shared launcher survives while the sibling needs it" "0" \
       "$( [ -x "$XDG_DATA_HOME/epic-watch/bin/epic-watch-launch" ] && echo 0 || echo 1 )"
    "$S/install-schedule.sh" --purge "$W_SIB" >/dev/null 2>&1
fi

printf '\n%d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]
