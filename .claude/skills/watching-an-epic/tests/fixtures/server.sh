#!/bin/bash
# Fixture HTTP server for the offline suite: serves recorded bodies and status codes so the
# API clients are exercised through their real curl path, including status-code mapping,
# with no credential and no network.
#
#   server.sh start <fixture-dir> <runtime-dir>   writes <runtime-dir>/{port,pid}
#   server.sh stop <runtime-dir>
#
# A fixture file is named <METHOD>_<path with / as _>.<status>, e.g. GET_epics_1.200.

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "${1:-}" in
start)
    dir="${2:?fixture dir required}"; rt="${3:?runtime dir required}"
    mkdir -p "$rt"; rm -f "$rt/port"
    # An absolute path is used as given, so a suite can build fixtures at run time.
    case "$dir" in /*) fixdir="$dir" ;; *) fixdir="$HERE/$dir" ;; esac
    nohup python3 "$HERE/server.py" "$fixdir" "$rt/port" >"$rt/log" 2>&1 &
    echo $! > "$rt/pid"
    for _ in $(seq 1 50); do [ -s "$rt/port" ] && break; sleep 0.1; done
    [ -s "$rt/port" ] || { echo "fixture server did not start" >&2; cat "$rt/log" >&2; exit 1; }
    printf 'http://127.0.0.1:%s' "$(cat "$rt/port")"
    ;;
stop)
    rt="${2:?runtime dir required}"
    [ -f "$rt/pid" ] && kill "$(cat "$rt/pid")" 2>/dev/null
    rm -f "$rt/pid" "$rt/port"
    ;;
*) printf 'usage: server.sh start <fixture-dir> <runtime-dir> | stop <runtime-dir>\n' >&2; exit 1 ;;
esac
