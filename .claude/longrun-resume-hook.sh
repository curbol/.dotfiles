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
    state=$(cat "$run_dir/STATE.md")
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
An unfinished longrun lives in ${run_dir}. REPORT.md is absent, so the run stopped before Phase 11.

Recorded state:

${state}

Before any work that touches this run, invoke the \`longrun\` skill and re-enter the pipeline at the phase and round above. This holds however the request is phrased, including a bare \"continue\".

Finishing the remaining work directly in this session is one of the rationalizations the skill's principles ban by name. The role-scoped subagents, the review loops, and their mechanical exits are the whole point of the harness; a run that reaches its end with any of them skipped looks complete and is not.
</EXTREMELY_IMPORTANT>"

printf '{\n  "hookSpecificOutput": {\n    "hookEventName": "SessionStart",\n    "additionalContext": "%s"\n  }\n}\n' "$(escape_for_json "$context")"

exit 0
