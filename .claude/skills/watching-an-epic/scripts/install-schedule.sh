#!/bin/bash
# Render, install, and remove scheduler entries. Rendering is separated from loading so
# the rendering half is testable anywhere while launchctl and systemctl are platform-bound.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$HERE/config.sh"
TEMPLATES="$HERE/templates"

IMPLEMENTED_LANES="intake"
ALL_LANES="intake groom docs"
LABEL_PREFIX="com.gladly.epic-watch"
BIN_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/epic-watch/bin"
LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/epic-watch/logs"

die() { printf '%s\n' "$2" >&2; exit "$1"; }

require_name() {
    case "${1:-}" in
        ""|*[!abcdefghijklmnopqrstuvwxyz0123456789-]*) die 1 "invalid watcher name: '${1:-}' (lowercase letters, digits and dashes)" ;;
    esac
}

usage() {
    cat >&2 <<'USAGE'
Usage: install-schedule.sh <command> [args]
  --render <watcher> <lane>     write the scheduler unit to stdout; touches nothing
  --install <watcher>           copy the launcher, render and load every enabled lane
  --unschedule <watcher>        remove scheduler entries and the launcher; keep state
  --purge <watcher>             --unschedule plus the watcher's state
USAGE
    exit 1
}

lane_supported() {
    for l in $IMPLEMENTED_LANES; do [ "$l" = "$1" ] && return 0; done
    return 1
}

# Determinism per <watcher>-<lane> and spread across a set is all this claims. It does not
# claim two given watchers differ: mod 60 collides for roughly one pair in sixty.
minute_for() { printf '%s' $(( $(printf '%s' "$1" | cksum | awk '{print $1}') % 60 )); }

render() {
    local watcher="$1" lane="$2"
    lane_supported "$lane" || die 1 "lane '$lane' has no implementation in this version (supported: $IMPLEMENTED_LANES)"
    local cadence min label launcher
    cadence="$("$CONFIG" show "$watcher" | jq -r --arg l "$lane" '.lanes[$l] // ""')"
    [ -n "$cadence" ] || die 1 "lane '$lane' is not enabled for watcher '$watcher'"
    min="$(minute_for "${watcher}-${lane}")"
    label="${LABEL_PREFIX}.${watcher}.${lane}"
    launcher="$BIN_DIR/epic-watch-launch"

    case "$(uname -s)" in
    Darwin)
        local schedule
        case "$cadence" in
            hourly) schedule="    <dict><key>Minute</key><integer>${min}</integer></dict>" ;;
            daily)  schedule="    <dict><key>Hour</key><integer>9</integer><key>Minute</key><integer>${min}</integer></dict>" ;;
            weekly) schedule="    <dict><key>Weekday</key><integer>1</integer><key>Hour</key><integer>9</integer><key>Minute</key><integer>${min}</integer></dict>" ;;
            *) die 1 "unknown cadence '$cadence'" ;;
        esac
        sed -e "s|@@LABEL@@|${label}|g" -e "s|@@LAUNCHER@@|${launcher}|g" \
            -e "s|@@WATCHER@@|${watcher}|g" -e "s|@@LANE@@|${lane}|g" \
            -e "s|@@LOGDIR@@|${LOG_DIR}|g" "$TEMPLATES/launchd.plist.tmpl" \
            | awk -v s="$schedule" '{ if ($0 == "@@SCHEDULE@@") print s; else print }'
        ;;
    *)
        local oncal
        case "$cadence" in
            hourly) oncal="*-*-* *:${min}:00" ;;
            daily)  oncal="*-*-* 09:${min}:00" ;;
            weekly) oncal="Mon *-*-* 09:${min}:00" ;;
            *) die 1 "unknown cadence '$cadence'" ;;
        esac
        sed -e "s|@@WATCHER@@|${watcher}|g" -e "s|@@LANE@@|${lane}|g" \
            -e "s|@@ONCALENDAR@@|${oncal}|g" "$TEMPLATES/systemd.timer.tmpl"
        printf '\n### service ###\n'
        sed -e "s|@@LAUNCHER@@|${launcher}|g" -e "s|@@WATCHER@@|${watcher}|g" \
            -e "s|@@LANE@@|${lane}|g" "$TEMPLATES/systemd.service.tmpl"
        ;;
    esac
}

install_launcher() {
    mkdir -p "$BIN_DIR" "$LOG_DIR"
    # Compared by content rather than a declared version: an edit to the launcher during a
    # soak has no version to bump, and a stale copy at the stable path is invisible.
    if ! cmp -s "$HERE/epic-watch-launch" "$BIN_DIR/epic-watch-launch"; then
        cp "$HERE/epic-watch-launch" "$BIN_DIR/epic-watch-launch"
        chmod +x "$BIN_DIR/epic-watch-launch"
    fi
}

cmd="${1:-}"; shift || usage
require_name "${1:-}"
case "$cmd" in --render) case "${2:-}" in intake|groom|docs) ;; *) die 1 "invalid lane: '${2:-}'" ;; esac ;; esac

case "$cmd" in
--render)
    [ $# -eq 2 ] || usage
    render "$1" "$2"
    ;;
--install)
    [ $# -eq 1 ] || usage
    watcher="$1"
    # Verified here rather than at config load because it needs the network: a stale state id
    # would otherwise surface as an API error mid-filing in a later stage.
    wf="$("$CONFIG" show "$watcher" | jq -r '.intake_state.workflow_id')"
    want="$("$CONFIG" show "$watcher" | jq -r '.intake_state.workflow_state_id')"
    if states="$("$HERE/shortcut.sh" workflow-states "$wf" 2>/dev/null)"; then
        jq -e --argjson s "$want" '[.states[].id] | index($s) != null' <<<"$states" >/dev/null \
            || die 1 "intake_state.workflow_state_id $want is not a state of workflow $wf"
    else
        printf 'warning: could not verify intake_state against workflow %s\n' "$wf" >&2
    fi
    install_launcher
    # install-schedule.sh runs from the checkout, so it is the one component that knows which
    # copy of the skill this watcher was scheduled from. The launcher has no other way to find
    # it: a scheduled run inherits no CLAUDE_CONFIG_DIR, and both config dirs symlink here.
    "$CONFIG" set-env "$watcher" skill_root "$(cd "$HERE/.." && pwd)"
    "$CONFIG" set-env "$watcher" path "$PATH"
    "$CONFIG" set-env "$watcher" claude_config_dir "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
    while read -r lane; do
        [ -n "$lane" ] || continue
        lane_supported "$lane" || { printf 'skipping lane %s: no implementation in this version\n' "$lane" >&2; continue; }
        case "$(uname -s)" in
        Darwin)
            dest="$HOME/Library/LaunchAgents/${LABEL_PREFIX}.${watcher}.${lane}.plist"
            render "$watcher" "$lane" > "$dest"
            launchctl unload "$dest" 2>/dev/null || true
            launchctl load "$dest"
            ;;
        *)
            mkdir -p "$HOME/.config/systemd/user"
            rendered="$(render "$watcher" "$lane")"
            printf '%s' "${rendered%%$'\n'### service ###*}" \
                > "$HOME/.config/systemd/user/epic-watch@${watcher}-${lane}.timer"
            printf '%s' "${rendered#*### service ###$'\n'}" \
                > "$HOME/.config/systemd/user/epic-watch@${watcher}-${lane}.service"
            systemctl --user daemon-reload
            systemctl --user enable --now "epic-watch@${watcher}-${lane}.timer"
            ;;
        esac
        printf 'scheduled %s %s\n' "$watcher" "$lane"
    done < <("$CONFIG" show "$watcher" | jq -r '(.lanes // {}) | keys[]')
    ;;
--unschedule|--purge)
    [ $# -eq 1 ] || usage
    watcher="$1"
    case "$(uname -s)" in
    Darwin)
        for f in "$HOME/Library/LaunchAgents/${LABEL_PREFIX}.${watcher}."*.plist; do
            [ -f "$f" ] || continue
            launchctl unload "$f" 2>/dev/null || true
            rm -f "$f"
        done
        ;;
    *)
        # Iterate the lanes rather than globbing on the name: unit files are
        # epic-watch@<watcher>-<lane>, so `<watcher>-`* also matches a watcher whose name
        # begins with this one plus a dash, and kebab-case names are what we tell users to use.
        for lane in $ALL_LANES; do
            for suffix in timer service; do
                f="$HOME/.config/systemd/user/epic-watch@${watcher}-${lane}.${suffix}"
                [ -f "$f" ] || continue
                [ "$suffix" = timer ] && { systemctl --user disable --now "$(basename "$f")" 2>/dev/null || true; }
                rm -f "$f"
            done
        done
        systemctl --user daemon-reload 2>/dev/null || true
        ;;
    esac
    # The launcher is shared by every watcher, and a scheduler entry whose program is gone
    # produces no output at all, so removing it while another watcher is scheduled would stop
    # that watcher silently.
    remaining=0
    case "$(uname -s)" in
    Darwin) remaining="$(find "$HOME/Library/LaunchAgents" -name "${LABEL_PREFIX}.*.plist" 2>/dev/null | wc -l | tr -d ' ')" ;;
    *)      remaining="$(find "$HOME/.config/systemd/user" -name 'epic-watch@*.timer' 2>/dev/null | wc -l | tr -d ' ')" ;;
    esac
    if [ "$remaining" -eq 0 ]; then rm -f "$BIN_DIR/epic-watch-launch"; fi
    if [ "$cmd" = --purge ]; then
        rm -rf "${XDG_STATE_HOME:-$HOME/.local/state}/epic-watch/$watcher"
        rm -rf "${XDG_CONFIG_HOME:-$HOME/.config}/epic-watch/$watcher"
    fi
    printf '%s %s\n' "${cmd#--}" "$watcher"
    ;;
*) usage ;;
esac
