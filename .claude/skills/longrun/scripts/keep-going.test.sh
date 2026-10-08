#!/usr/bin/env bash
# keep-going.test.sh — the Stop hook that holds a longrun open.
#
# This hook can refuse to let a session end, so the cases that matter are the ones
# where it MUST let go. A hook that blocks correctly but releases incorrectly is a
# wedged session, which is worse than the problem it solves.
#
# Exit status is the failure count.

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$HERE/keep-going.mjs"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n     -> %s\n' "$1" "$2"; fails=$((fails+1)); }

NODE_BIN="$(node -e 'process.stdout.write(process.execPath)' 2>/dev/null)"
[[ -x "$NODE_BIN" ]] || { printf 'cannot resolve node\n' >&2; exit 1; }

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

# Returns the hook's stdout. Empty means "allow"; a JSON blob means "block".
fire() {
  local project="$1" payload="${2:-{\}}"
  printf '%s' "$payload" | env CLAUDE_PROJECT_DIR="$project" "$NODE_BIN" "$HOOK" 2>/dev/null
}

decision() { jq -r '.decision // "allow"' <<<"${1:-{\}}" 2>/dev/null || printf 'allow'; }

mk() {
  local name="$1" body="$2"
  mkdir -p "$T/$name/.longrun"
  printf '%b' "$body" > "$T/$name/.longrun/TASKS.md"
  printf '%s' "$T/$name"
}

printf '\n1. INERT outside a longrun, which is every ordinary session\n'
mkdir -p "$T/plain"
out=$(fire "$T/plain")
[[ -z "$out" ]] && ok "no .longrun means no output at all" || bad "not inert" "$out"

printf '\n2. blocks while work remains, and names the next item\n'
P=$(mk active "- [x] T1 done\n- [ ] T2 the next thing\n- [ ] T3 later\n")
out=$(fire "$P")
[[ "$(decision "$out")" == "block" ]] && ok "blocks" || bad "did not block" "$out"
grep -q 'T2 the next thing' <<<"$out" && ok "names the next item" || bad "no next item named" "$out"
grep -q '2 of 3' <<<"$out" && ok "counts what remains" || bad "bad count" "$out"

printf '\n3. RELEASES when every item is checked\n'
P=$(mk done "- [x] T1\n- [x] T2\n")
out=$(fire "$P")
[[ -z "$out" ]] && ok "allows on a finished checklist" || bad "blocked a finished run" "$out"

printf '\n4. RELEASES on the kill switch\n'
P=$(mk killed "- [ ] T1 still open\n")
touch "$P/.longrun/STOP"
out=$(fire "$P")
[[ -z "$out" ]] && ok "allows when STOP exists" || bad "kill switch ignored" "$out"

printf '\n5. RELEASES when the harness says a stop hook already ran\n'
P=$(mk reentry "- [ ] T1 still open\n")
out=$(fire "$P" '{"stop_hook_active":true}')
[[ -z "$out" ]] && ok "allows on stop_hook_active" || bad "would re-enter" "$out"

printf '\n6. RELEASES after MAX_BLOCKS, so it cannot wedge forever\n'
# The escape that matters most: a model stuck on a task it cannot finish would
# otherwise be held in a loop producing nothing.
P=$(mk wedged "- [ ] T1 impossible\n")
# Counted up to the FIRST release, not across a fixed number of fires. The counter
# resets on every release (case 7), so a run of 30 fires legitimately shows 25
# blocks, a release, then 4 more. Counting the total would assert the wrong thing
# and fail against correct behaviour.
blocked=0
for _ in $(seq 1 40); do
  out=$(fire "$P")
  [[ "$(decision "$out")" == "block" ]] || break
  blocked=$((blocked+1))
done
[[ "$blocked" == "25" ]] && ok "blocked 25 times, then released" \
  || bad "wrong block count before release" "blocked $blocked, expected 25"

printf '\n7. the counter resets after a release, so the next run gets a full budget\n'
P=$(mk resets "- [ ] T1\n")
for _ in $(seq 1 26); do fire "$P" >/dev/null; done   # exhaust, then release
out=$(fire "$P" '{"stop_hook_active":true}')          # a release path
out=$(fire "$P")
[[ "$(decision "$out")" == "block" ]] && ok "budget restored after a release" \
  || bad "counter did not reset" "$out"

printf '\n8. a malformed payload does not wedge the session\n'
P=$(mk malformed "- [ ] T1\n")
out=$(printf 'not json' | env CLAUDE_PROJECT_DIR="$P" "$NODE_BIN" "$HOOK" 2>/dev/null)
rc=$?
[[ $rc == 0 ]] && ok "exits 0 on garbage input" || bad "exit status" "got $rc"

printf '\n9. an unreadable run directory releases rather than throwing\n'
mkdir -p "$T/weird/.longrun"
printf -- '- [ ] T1\n' > "$T/weird/.longrun/TASKS.md"
chmod 000 "$T/weird/.longrun/TASKS.md" 2>/dev/null
out=$(fire "$T/weird"); rc=$?
chmod 644 "$T/weird/.longrun/TASKS.md" 2>/dev/null
[[ $rc == 0 ]] && ok "exits 0 when the checklist cannot be read" || bad "exit status" "got $rc"

printf '\n%s: %s failure(s)\n' "$(basename "$0")" "$fails"
exit "$fails"
