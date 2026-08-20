#!/usr/bin/env bash
# SessionStart hook: make an unfinished longrun resume through its skill.
# Silent unless .longrun/ exists without REPORT.md. Never blocks the session.

set -uo pipefail

root="${CLAUDE_PROJECT_DIR:-$PWD}"
run_dir="$root/.longrun"

if [ ! -d "$run_dir" ] || [ -f "$run_dir/REPORT.md" ]; then
    exit 0
fi

if [ -f "$run_dir/STATE.md" ]; then
    # escape_for_json covers only tab, newline, and carriage return, so strip the
    # other control bytes here, along with any UTF-8 sequence the byte cap split.
    state=$(head -c 4000 "$run_dir/STATE.md" \
        | iconv -c -f UTF-8 -t UTF-8 2>/dev/null \
        | tr -d '\000-\010\013\014\016-\037\177')
else
    state="STATE.md is absent. Inventory the run directory to establish the phase before re-entering."
fi

escape_for_json() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    printf '%s' "$s"
}

context="<EXTREMELY_IMPORTANT>
An unfinished longrun lives in ${run_dir}: no REPORT.md, so it stopped before its final phase.

Recorded state:

${state}

Before any work that touches this run, invoke the \`longrun\` skill and re-enter the pipeline at the phase and round above. This holds however the request is phrased, including a bare \"continue\". Finishing the remaining work directly is banned by the skill's principles.
</EXTREMELY_IMPORTANT>"

printf '{\n  "hookSpecificOutput": {\n    "hookEventName": "SessionStart",\n    "additionalContext": "%s"\n  }\n}\n' "$(escape_for_json "$context")"

exit 0
