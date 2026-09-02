#!/bin/bash
# Offline, hermetic suite. No credentials, no network, no platform scheduler. This is what
# CI runs, and what a green CI proves is exactly this and nothing more: the token-gated
# checks live in run-live.sh, which CI never invokes.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL="$(cd "$HERE/.." && pwd)"
S="$SKILL/scripts"
# The commands and agents are separate components under the same config dir, not files inside
# the skill, so the frontmatter checks below have to reach up out of it.
CLAUDE_DIR="$(cd "$SKILL/../.." && pwd)"

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL %s\n     expected: %s\n     actual:   %s\n' "$1" "$2" "$3"; }
eq()   { [ "$2" = "$3" ] && ok "$1" || bad "$1" "$2" "$3"; }
group(){ printf '\n%s\n' "$1"; }

# Every state and config path is redirected. Without XDG_DATA_HOME the launcher's stable
# path is shared, so a suite run on a machine with a live watcher would overwrite it.
SANDBOX="$(mktemp -d)"
# EPIC_WATCH_KEEP_SANDBOX=1 leaves the sandbox for inspection when a case is being debugged.
trap 'for d in "$SANDBOX"/fx*; do [ -d "$d" ] && "$HERE/fixtures/server.sh" stop "$d" >/dev/null 2>&1; done; "$HERE/fixtures/server.sh" stop "$SANDBOX/fixture-server" >/dev/null 2>&1; [ "${EPIC_WATCH_KEEP_SANDBOX:-0}" = 1 ] && printf "sandbox kept: %s\n" "$SANDBOX" || rm -rf "$SANDBOX"' EXIT
export XDG_CONFIG_HOME="$SANDBOX/config" XDG_STATE_HOME="$SANDBOX/state" XDG_DATA_HOME="$SANDBOX/data"

# Hermetic by default rather than per call. Both API bases point at a closed port, so any
# client invocation that forgets to override them fails fast instead of reaching the real
# api.app.shortcut.com and slack.com; the fixture groups override them deliberately.
export SHORTCUT_API_BASE="http://127.0.0.1:1" SLACK_API_BASE="http://127.0.0.1:1"

# A stub `claude` ahead of the real one for the entire suite. The lane invokes `claude` by
# name whenever the precheck finds work, and a test that forgot to provide a stub would
# otherwise spend real tokens and reach real APIs.
SUITE_BIN="$SANDBOX/bin"; mkdir -p "$SUITE_BIN"
printf '#!/bin/bash\nprintf %s "{\\"result\\":\\"stub: no result line\\",\\"permission_denials\\":[]}"\n' \
    > "$SUITE_BIN/claude"
chmod +x "$SUITE_BIN/claude"
export PATH="$SUITE_BIN:$PATH"

CFG='{"name":"t1","epic":1,"team":"g","intake_state":{"name":"U","workflow_id":10,"workflow_state_id":20},"slack_workspace":"gladly","slack_self_id":"USELF","slack_channels":["C1"],"repos":[],"doc_surfaces":[],"lookback":"24h","ask_expiry":"72h","max_files_per_run":5,"max_asks_per_run":2,"lanes":{"intake":"hourly"}}'

group "component frontmatter (a component without it is silently not loaded)"
# Only the files the loader reads as components. A skill's supporting files are prose the
# skill itself points at, and frontmatter on them would mean nothing.
check_frontmatter() {
    local f="$1" label="$2" first desc
    first="$(head -1 "$f")"
    [ "$first" = "---" ] && ok "frontmatter: $label" || bad "frontmatter: $label" "---" "$first"
    desc="$(awk 'NR>1 && /^---$/{exit} /^description:/{print; exit}' "$f")"
    [ -n "$desc" ] && ok "description: $label" || bad "description: $label" "a description: key" "none"
}
check_frontmatter "$SKILL/SKILL.md" "skills/watching-an-epic/SKILL.md"
while IFS= read -r f; do
    [ -n "$f" ] || continue
    check_frontmatter "$f" "${f#$CLAUDE_DIR/}"
done < <(find "$CLAUDE_DIR/commands" -name 'epic-watch*.md' 2>/dev/null
         find "$CLAUDE_DIR/agents" -name 'epic-watch-*.md' 2>/dev/null)

group "component wiring"
# The three lanes' commands and the three subagents the skill dispatches are separate
# components: if the install drops one, nothing errors, the lane just quietly cannot do
# that step. Named explicitly so a missing file is a failure rather than a smaller sweep.
for c in epic-watch epic-watch-status epic-watch-stop; do
    eq "command present: /$c" "true" \
       "$([ -f "$CLAUDE_DIR/commands/$c.md" ] && echo true || echo false)"
done
for a in fetch classifier explorer; do
    eq "agent present: epic-watch-$a" "true" \
       "$([ -f "$CLAUDE_DIR/agents/epic-watch-$a.md" ] && echo true || echo false)"
done
# A personal agent takes its type from frontmatter, not its filename: without `name:` the
# file loads as nothing, the Agent call fails on an unknown subagent_type, and the lane
# reports a degraded source rather than a missing component.
for a in fetch classifier explorer; do
    f="$CLAUDE_DIR/agents/epic-watch-$a.md"
    eq "agent declares its own name: epic-watch-$a" "epic-watch-$a" \
       "$(awk 'NR>1 && /^---$/{exit} /^name:/{print $2; exit}' "$f" 2>/dev/null)"
done

eq "the classifier's rubric is where it looks for it" "true" \
   "$(grep -q 'EPIC_WATCH_ROOT/classification.md' "$CLAUDE_DIR/agents/epic-watch-classifier.md" \
      && [ -f "$SKILL/classification.md" ] && echo true || echo false)"
# Single-quoted: an unquoted $HOME here expands before grep sees it, and the pattern then
# matches nothing while still reporting a count per file.
eq "the commands resolve the skill from the config dir" "3" \
   "$(grep -l 'CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/watching-an-epic' \
      "$CLAUDE_DIR"/commands/epic-watch*.md 2>/dev/null | wc -l | tr -d ' ')"

group "permalink construction (the dedup key: a wrong transform files duplicates silently)"
eq "verified triple" "https://gladly.slack.com/archives/C0901J82FLN/p1787257832925119" \
   "$("$S/slack.sh" permalink gladly C0901J82FLN 1787257832.925119)"
eq "workspace argument is honored" "https://acme.slack.com/archives/C9/p12" \
   "$("$S/slack.sh" permalink acme C9 1.2)"
( env -u SLACK_USER_TOKEN "$S/slack.sh" permalink gladly C1 1.2 >/dev/null 2>&1 )
eq "needs no token" "0" "$?"

group "exit contract without credentials"
( env -u SLACK_USER_TOKEN "$S/slack.sh" latest-ts C1 >/dev/null 2>&1 ); eq "slack: no token is 2" "2" "$?"
( env -u SHORTCUT_API_TOKEN "$S/shortcut.sh" epic 1 >/dev/null 2>&1 ); eq "shortcut: no token is 2" "2" "$?"
( "$S/slack.sh" permalink gladly >/dev/null 2>&1 ); eq "usage is 1" "1" "$?"
( "$S/shortcut.sh" bogus >/dev/null 2>&1 ); eq "unknown subcommand is 1" "1" "$?"

group "API clients against recorded fixtures (real curl path, no credential, no network)"
FIX_RT="$SANDBOX/fixture-server"
serve()   { "$HERE/fixtures/server.sh" stop "$FIX_RT" >/dev/null 2>&1 || true
            "$HERE/fixtures/server.sh" start "$1" "$FIX_RT"; }
unserve() { "$HERE/fixtures/server.sh" stop "$FIX_RT" >/dev/null 2>&1 || true; }

BASE="$(serve shortcut)"
export SHORTCUT_API_TOKEN=fixture
eq "epic probe parses" "probe epic" "$(SHORTCUT_API_BASE="$BASE" "$S/shortcut.sh" epic 1 | jq -r '.name')"
eq "story parses" "a story" "$(SHORTCUT_API_BASE="$BASE" "$S/shortcut.sh" story 42 | jq -r '.name')"
eq "404 maps to exit 3" "3" "$( ( SHORTCUT_API_BASE="$BASE" "$S/shortcut.sh" story 9 >/dev/null 2>&1 ); echo $? )"
eq "401 maps to exit 4, not 3" "4" "$( ( SHORTCUT_API_BASE="$BASE" "$S/shortcut.sh" epic 401 >/dev/null 2>&1 ); echo $? )"
eq "dedup miss is an empty array" "0" "$(SHORTCUT_API_BASE="$BASE" "$S/shortcut.sh" story-by-external-link "https://x/y" | jq -r 'length')"
eq "search results live under .data[]" "42" "$(SHORTCUT_API_BASE="$BASE" "$S/shortcut.sh" search-stories "anything" 5 | jq -r '.data[0].id')"
eq "workflow-states lists states" "20" "$(SHORTCUT_API_BASE="$BASE" "$S/shortcut.sh" workflow-states 10 | jq -r '.states[0].id')"
unset SHORTCUT_API_TOKEN
unserve

export SLACK_USER_TOKEN=fixture
BASE="$(serve slack_ok)"
eq "latest-ts returns the newest of the page" "300.000003" "$(SLACK_API_BASE="$BASE" "$S/slack.sh" latest-ts C1)"
envjson="$(SLACK_API_BASE="$BASE" "$S/slack.sh" channel-history C1 0 999.9 5)"
eq "history returns one envelope" "true" "$(jq -r 'has("messages") and has("truncated") and has("oldest_read") and has("newest_read")' <<<"$envjson")"
eq "single page is not truncated" "false" "$(jq -r '.truncated' <<<"$envjson")"
eq "envelope reports the oldest read" "100.000001" "$(jq -r '.oldest_read' <<<"$envjson")"
eq "envelope reports the newest read" "300.000003" "$(jq -r '.newest_read' <<<"$envjson")"
eq "thread-replies includes the parent" "2" "$(SLACK_API_BASE="$BASE" "$S/slack.sh" thread-replies C1 100.000001 | jq -r '.messages | length')"
eq "reactions parse" "eyes" "$(SLACK_API_BASE="$BASE" "$S/slack.sh" reactions C1 100.000001 | jq -r '.message.reactions[0].name')"
eq "auth-test derives the workspace" "gladly" "$(SLACK_API_BASE="$BASE" "$S/slack.sh" auth-test | jq -r '.workspace')"
eq "auth-test derives self id" "USELF" "$(SLACK_API_BASE="$BASE" "$S/slack.sh" auth-test | jq -r '.self_id')"
unserve

BASE="$(serve slack_paged)"
envjson="$(SLACK_API_BASE="$BASE" "$S/slack.sh" channel-history C1 0 999.9 2)"
eq "page budget exhausted reports truncated" "true" "$(jq -r '.truncated' <<<"$envjson")"
eq "truncated walk still returns its messages" "true" "$(jq -r '(.messages | length) > 0' <<<"$envjson")"
eq "truncated walk reports oldest_read" "900.000009" "$(jq -r '.oldest_read' <<<"$envjson")"
unserve

BASE="$(serve slack_empty)"
eq "empty channel yields no ts" "" "$(SLACK_API_BASE="$BASE" "$S/slack.sh" latest-ts C1)"
unserve

BASE="$(serve slack_notinchannel)"
eq "not_in_channel maps to exit 3" "3" "$( ( SLACK_API_BASE="$BASE" "$S/slack.sh" latest-ts C1 >/dev/null 2>&1 ); echo $? )"
unserve

BASE="$(serve slack_badauth)"
eq "invalid_auth over HTTP 200 maps to exit 4" "4" "$( ( SLACK_API_BASE="$BASE" "$S/slack.sh" latest-ts C1 >/dev/null 2>&1 ); echo $? )"
unserve
unset SLACK_USER_TOKEN

group "config validation"
"$S/config.sh" init t1 "$CFG" >/dev/null 2>&1; eq "accepts a valid config" "0" "$?"
eq "doc_surfaces empty is valid" "0" "$( ( "$S/config.sh" init t2 "$(jq -c '.doc_surfaces=[]|.name="t2"' <<<"$CFG")" >/dev/null 2>&1 ); echo $? )"
eq "doc_surfaces without a page is not" "2" "$( ( "$S/config.sh" init t3 "$(jq -c '.doc_surfaces=[{"paths":["x"]}]|.name="t3"' <<<"$CFG")" >/dev/null 2>&1 ); echo $? )"
for bad_patch in '.epic=null' '.epic="abc"' '.slack_channels=[]' '.slack_workspace=null' '.slack_self_id=null' '.intake_state.workflow_id=null' '.intake_state.workflow_state_id=null' '.lanes={"nope":"hourly"}' '.lookback="30d"'; do
    eq "rejects $bad_patch" "2" "$( ( "$S/config.sh" init tbad "$(jq -c "$bad_patch" <<<"$CFG")" >/dev/null 2>&1 ); echo $? )"
done

group "a crash after the lock is recorded, not silent"
# A fatal error while holding the lock must still leave a record and a non-zero status.
"$S/config.sh" init tcrash "$(jq -c '.name="tcrash"' <<<"$CFG")" >/dev/null
CRASH_DIR="$SANDBOX/crashbin"; mkdir -p "$CRASH_DIR"
printf '#!/bin/sh\nexit 97\n' > "$CRASH_DIR/jq"; chmod +x "$CRASH_DIR/jq"
( PATH="$CRASH_DIR:$PATH" "$S/run-lane.sh" tcrash intake >/dev/null 2>&1 )
crash_rc=$?
eq "a crashed run exits non-zero" "true" "$([ "$crash_rc" -ne 0 ] && echo true || echo false)"
eq "  and the lock is released" "1" \
   "$( [ -d "$XDG_STATE_HOME/epic-watch/tcrash/intake.lock.d" ] && echo 0 || echo 1 )"
# A run whose jq is broken cannot journal, so the durable evidence is the freed lock plus a
# non-zero status. Prove the recorded path with a failure the wrapper can still write.
"$S/config.sh" init tcrash2 "$(jq -c '.name="tcrash2"' <<<"$CFG")" >/dev/null
mkdir -p "$XDG_STATE_HOME/epic-watch/tcrash2"
printf 'x\n' > "$XDG_STATE_HOME/epic-watch/tcrash2/watermarks.json"
( "$S/run-lane.sh" tcrash2 intake >/dev/null 2>&1 )
# run_end, not merely a non-empty journal: the crash handler also writes a record, so
# "something got written" would stay green if read_json_or stopped tolerating bad input.
eq "a corrupt state file does not stop the run from completing" "run_end" \
   "$(tail -1 "$XDG_STATE_HOME/epic-watch/tcrash2/journal.ndjson" 2>/dev/null | jq -r '.action')"

group "input validation and durable-write guarantees"
eq "an invalid watcher name is refused" "1" \
   "$( ( "$S/config.sh" show "../escape" >/dev/null 2>&1 ); echo $? )"
eq "an empty watcher name is refused" "1" \
   "$( ( "$S/install-schedule.sh" --purge "" >/dev/null 2>&1 ); echo $? )"
eq "a string where an array belongs is refused" "2" \
   "$( ( "$S/config.sh" init tstr "$(jq -c '.name="tstr"|.slack_channels="C1"' <<<"$CFG")" >/dev/null 2>&1 ); echo $? )"
eq "set-env refuses an unparseable config instead of replacing it" "2" \
   "$( printf 'truncated{' > "$XDG_CONFIG_HOME/epic-watch/t1/config.json"
      ( "$S/config.sh" set-env t1 skill_root /x >/dev/null 2>&1 ); echo $? )"
eq "  and leaves the file as it was" "truncated{" \
   "$(cat "$XDG_CONFIG_HOME/epic-watch/t1/config.json")"
"$S/config.sh" init t1 "$CFG" >/dev/null

eq "usage error is 1 even with no token" "1" \
   "$( ( env -u SHORTCUT_API_TOKEN "$S/shortcut.sh" bogus >/dev/null 2>&1 ); echo $? )"
eq "malformed duration is rejected, not crashed" "2" \
   "$( ( "$S/config.sh" init tdur "$(jq -c '.name="tdur"|.lookback="1h30m"' <<<"$CFG")" >/dev/null 2>&1 ); echo $? )"
eq "a bare unit is rejected" "2" \
   "$( ( "$S/config.sh" init tdur2 "$(jq -c '.name="tdur2"|.lookback="h"' <<<"$CFG")" >/dev/null 2>&1 ); echo $? )"
eq "a malformed ask_expiry is rejected at init" "2" \
   "$( ( "$S/config.sh" init tdur3 "$(jq -c '.name="tdur3"|.ask_expiry="1h30m"' <<<"$CFG")" >/dev/null 2>&1 ); echo $? )"
# A dedicated watcher, so this does not perturb the ask counts asserted further down.
"$S/config.sh" init tatomic "$(jq -c '.name="tatomic"' <<<"$CFG")" >/dev/null
"$S/config.sh" ask-set tatomic "C1:9.9" '{"asked_at":1,"ask_ts":"9.8","reaction_baseline":[],"status":"open","story_id":null}'
before_asks="$(wc -c < "$XDG_STATE_HOME/epic-watch/tatomic/asks.json")"
( "$S/config.sh" ask-set tatomic "C1:8.8" 'not-json' >/dev/null 2>&1 )
eq "a failed write leaves the previous state intact" "$before_asks" \
   "$(wc -c < "$XDG_STATE_HOME/epic-watch/tatomic/asks.json")"
"$S/config.sh" init env-a "$(jq -c '.name="env-a"' <<<"$CFG")" '{"SHORTCUT_API_TOKEN":"sc-1","SLACK_USER_TOKEN":"xoxp-1"}' >/dev/null
"$S/config.sh" init env-b "$(jq -c '.name="env-b"' <<<"$CFG")" '{"SHORTCUT_API_TOKEN":"sc-2"}' >/dev/null
eq "a second watcher does not steal the first's tokens" "1" \
   "$(grep -c "SLACK_USER_TOKEN='xoxp-1'" "$XDG_CONFIG_HOME/epic-watch/env")"
eq "  and its own token wins" "1" \
   "$(grep -c "SHORTCUT_API_TOKEN='sc-2'" "$XDG_CONFIG_HOME/epic-watch/env")"

eq "an overflowing duration is out of range, not silently negative" "2" \
   "$( ( "$S/config.sh" init tovf "$(jq -c '.name="tovf"|.lookback="99999999999999999999h"' <<<"$CFG")" >/dev/null 2>&1 ); echo $? )"
eq "a malformed env json is refused" "2" \
   "$( ( "$S/config.sh" init tenv "$(jq -c '.name="tenv"' <<<"$CFG")" 'SHORTCUT_API_TOKEN=oops' >/dev/null 2>&1 ); echo $? )"
eq "an invalid lane is refused by config.sh" "1" \
   "$( ( "$S/config.sh" lock-acquire t1 '../escape' $$ >/dev/null 2>&1 ); echo $? )"
eq "an invalid lane is refused by run-lane.sh" "1" \
   "$( ( "$S/run-lane.sh" t1 nosuchlane >/dev/null 2>&1 ); echo $? )"
eq "list on a machine with no watchers is not an error" "0" \
   "$( ( XDG_CONFIG_HOME="$SANDBOX/absent" "$S/config.sh" list >/dev/null 2>&1 ); echo $? )"
"$S/config.sh" lock-acquire t1 intake $$ >/dev/null 2>&1
rm -f "$XDG_STATE_HOME/epic-watch/t1/intake.lock.d/pid"
eq "a lock whose owner is not yet published reads as held" "3" \
   "$( ( "$S/config.sh" lock-acquire t1 intake $$ >/dev/null 2>&1 ); echo $? )"
"$S/config.sh" lock-release t1 intake
# A private TMPDIR: counting entries in the shared one lets any other process on the machine
# flip this assertion, and this suite gates a required check.
LEAK_TMP="$SANDBOX/leakcheck"; mkdir -p "$LEAK_TMP"
FIX="$(serve slack_paged)"
( TMPDIR="$LEAK_TMP" env -u SLACK_USER_TOKEN "$S/slack.sh" latest-ts C1 >/dev/null 2>&1 )
( TMPDIR="$LEAK_TMP" SLACK_USER_TOKEN=x SLACK_API_BASE="$FIX" "$S/slack.sh" channel-history C1 0 999.9 2 >/dev/null 2>&1 )
( TMPDIR="$LEAK_TMP" SLACK_USER_TOKEN=x SLACK_API_BASE="$FIX" "$S/slack.sh" thread-replies C1 1.1 >/dev/null 2>&1 )
unserve
eq "the clients leave no response bodies behind" "0" \
   "$(find "$LEAK_TMP" -mindepth 1 2>/dev/null | wc -l | tr -d ' ')"

group "env file"
"$S/config.sh" init t4 "$(jq -c '.name="t4"' <<<"$CFG")" '{"SHORTCUT_API_TOKEN":"s3cret"}' >/dev/null
mode="$(stat -c '%a' "$XDG_CONFIG_HOME/epic-watch/env" 2>/dev/null || stat -f '%Lp' "$XDG_CONFIG_HOME/epic-watch/env")"
eq "written 0600" "600" "$mode"

group "watermarks"
"$S/config.sh" watermark-set t1 "intake/C1" "1787257832.925119"
eq "round-trip" "1787257832.925119" "$("$S/config.sh" watermark-get t1 intake/C1)"
eq "other lane untouched" "" "$("$S/config.sh" watermark-get t1 groom/C1)"
# Compared with a tolerance: two `date +%s` forks straddling a second boundary would
# otherwise disagree.
bound_secs="$("$S/config.sh" effective-bound t1 intake/C1 24h)"; bound_secs="${bound_secs%%.*}"
want_secs=$(( $(date +%s) - 86400 ))
eq "stale watermark clamps to lookback" "true" \
   "$([ "$bound_secs" -ge $((want_secs - 2)) ] && [ "$bound_secs" -le $((want_secs + 2)) ] && echo true || echo false)"
fresh=$(( $(date +%s) - 60 )); "$S/config.sh" watermark-set t1 "intake/C1" "${fresh}.000000"
eq "fresh watermark wins over clamp" "${fresh}.000000" "$("$S/config.sh" effective-bound t1 intake/C1 24h)"
seedfmt="$("$S/config.sh" effective-bound t1 intake/CNEW 24h)"
eq "seed is fixed-point, not a bare epoch" "yes" "$(expr "$seedfmt" : '.*\.[0-9][0-9]*$' >/dev/null && echo yes || echo no)"
eq "atomic write leaves no temp files" "0" \
   "$(find "$XDG_STATE_HOME/epic-watch/t1" -name 'watermarks.json.*' 2>/dev/null | wc -l | tr -d ' ')"

group "lock"
"$S/config.sh" lock-acquire t1 intake $$ >/dev/null 2>&1; eq "acquire" "0" "$?"
# 3, not 1: a busy lane is not a usage error, and a caller other than run-lane.sh needs to
# tell the two apart.
( "$S/config.sh" lock-acquire t1 intake $$ >/dev/null 2>&1 ); eq "contended acquire refused with its own code" "3" "$?"
echo 999999 > "$XDG_STATE_HOME/epic-watch/t1/intake.lock.d/pid"
"$S/config.sh" lock-acquire t1 intake $$ >/dev/null 2>&1; eq "stale lock reclaimed" "0" "$?"
"$S/config.sh" lock-release t1 intake
eq "release removes it" "1" "$( [ -d "$XDG_STATE_HOME/epic-watch/t1/intake.lock.d" ] && echo 0 || echo 1 )"

group "a live lock holder is never stepped over"
# Two runs acting at once is worse than a lane that waits, so a live holder is waited for
# inside the staleness window, stopped before the lane changes hands past it, and refused
# outright if it cannot be stopped.
age_lock() { python3 -c "import os,sys,time; t=time.time()-999999; os.utime(sys.argv[1],(t,t))" "$1"; }
LOCKD="$XDG_STATE_HOME/epic-watch/t1/intake.lock.d"
"$S/config.sh" lock-release t1 intake >/dev/null 2>&1 || true
sleep 300 & HOLDER_PID=$!
"$S/config.sh" lock-acquire t1 intake "$HOLDER_PID" >/dev/null 2>&1
eq "a live holder inside the window is waited for" "3" \
   "$( ( "$S/config.sh" lock-acquire t1 intake $$ >/dev/null 2>&1 ); echo $? )"
age_lock "$LOCKD"
eq "a live holder past the window hands over" "0" \
   "$( ( "$S/config.sh" lock-acquire t1 intake $$ >/dev/null 2>&1 ); echo $? )"
eq "  and the old holder is stopped first" "gone" \
   "$(ps -p "$HOLDER_PID" >/dev/null 2>&1 && echo alive || echo gone)"
wait "$HOLDER_PID" 2>/dev/null || true

# pid 1 exists but cannot be signalled by this user, which is the case kill -0 gets wrong:
# EPERM reads as "no such process", so the lock would be taken from a live owner.
"$S/config.sh" lock-release t1 intake $$ >/dev/null 2>&1 || true
"$S/config.sh" lock-acquire t1 intake 1 >/dev/null 2>&1
age_lock "$LOCKD"
eq "a holder that cannot be stopped is refused" "3" \
   "$( ( "$S/config.sh" lock-acquire t1 intake $$ >/dev/null 2>&1 ); echo $? )"
rm -rf "$LOCKD" "$LOCKD.takeover"

group "ask registry"
old=$(( $(date +%s) - 999999 )); recent=$(( $(date +%s) - 60 ))
"$S/config.sh" ask-set t1 "C1:100.1" "{\"asked_at\":$old,\"ask_ts\":\"100.2\",\"reaction_baseline\":[],\"status\":\"open\",\"story_id\":null}"
"$S/config.sh" ask-set t1 "C1:200.2" "{\"asked_at\":$old,\"ask_ts\":\"200.3\",\"reaction_baseline\":[],\"status\":\"pending\",\"story_id\":null}"
"$S/config.sh" ask-set t1 "C1:300.3" "{\"asked_at\":$recent,\"ask_ts\":\"300.4\",\"reaction_baseline\":[],\"status\":\"open\",\"story_id\":null}"
eq "keyed on the reported message, so two asks stay distinct" "3" "$("$S/config.sh" ask-list t1 | wc -l | tr -d ' ')"
"$S/config.sh" ask-reap t1 72h >/dev/null
eq "stale open and pending both expire" "2" "$("$S/config.sh" ask-list t1 expired | wc -l | tr -d ' ')"
eq "recent open survives" "1" "$("$S/config.sh" ask-list t1 open | wc -l | tr -d ' ')"

group "health"
"$S/config.sh" health-set t1 intake '{"consecutive_failures":3,"breaker":"open","fires_since_open":4}'
eq "breaker recorded" "open" "$("$S/config.sh" health-get t1 | jq -r '.lanes.intake.breaker')"
printf '{"ts":1,"lane":"intake","class":"no_root","detail":"x"}\n' > "$XDG_STATE_HOME/epic-watch/t1/launch-failure.json"
eq "launcher failure merged at read time" "no_root" "$("$S/config.sh" health-get t1 | jq -r '.launch_failure.class')"
"$S/config.sh" reset t1 intake
eq "reset closes the breaker" "closed" "$("$S/config.sh" health-get t1 | jq -r '.lanes.intake.breaker')"
eq "reset zeroes failures" "0" "$("$S/config.sh" health-get t1 | jq -r '.lanes.intake.consecutive_failures')"
eq "reset clears the marker" "1" "$( [ -f "$XDG_STATE_HOME/epic-watch/t1/ALERT" ] && echo 0 || echo 1 )"
"$S/config.sh" clear-launch-failure t1
eq "clear-launch-failure removes it" "null" "$("$S/config.sh" health-get t1 | jq -r '.launch_failure // "null"')"

group "two watchers share no state"
"$S/config.sh" watermark-set t1 "intake/C1" "111.000001"
"$S/config.sh" watermark-set t2 "intake/C1" "222.000002"
"$S/config.sh" health-set t2 intake '{"breaker":"open"}'
eq "t1 watermark intact" "111.000001" "$("$S/config.sh" watermark-get t1 intake/C1)"
eq "t2 watermark intact" "222.000002" "$("$S/config.sh" watermark-get t2 intake/C1)"
eq "t1 breaker unaffected by t2" "closed" "$("$S/config.sh" health-get t1 | jq -r '.lanes.intake.breaker')"

group "journal"
"$S/config.sh" journal t1 '{"ts":1,"run_id":"r","watcher":"t1","lane":"intake","action":"quiet","target":null,"sources":[],"detail":null}'
"$S/config.sh" journal t1 '{"ts":2,"run_id":"r","watcher":"t1","lane":"intake","action":"degraded","target":null,"sources":[],"detail":null}'
eq "append-only" "2" "$(wc -l < "$XDG_STATE_HOME/epic-watch/t1/journal.ndjson" | tr -d ' ')"
eq "every record parses" "2" "$(jq -c . "$XDG_STATE_HOME/epic-watch/t1/journal.ndjson" | wc -l | tr -d ' ')"

group "scheduler rendering (no launchctl or systemctl)"
out="$("$S/install-schedule.sh" --render t1 intake)"
eq "renders something" "0" "$?"
eq "points at the stable launcher, not the checkout" "1" \
   "$(printf '%s' "$out" | grep -c "$XDG_DATA_HOME/epic-watch/bin/epic-watch-launch")"
eq "carries no secret" "0" "$(printf '%s' "$out" | grep -ci 'token\|secret')"
eq "deterministic" "$("$S/install-schedule.sh" --render t1 intake | shasum | cut -d' ' -f1)" \
   "$("$S/install-schedule.sh" --render t1 intake | shasum | cut -d' ' -f1)"
( "$S/install-schedule.sh" --render t1 groom >/dev/null 2>&1 ); eq "lane not enabled is refused" "1" "$?"
"$S/config.sh" init t5 "$(jq -c '.name="t5"|.lanes={"intake":"hourly","groom":"daily"}' <<<"$CFG")" >/dev/null
( "$S/install-schedule.sh" --render t5 groom >/dev/null 2>&1 ); eq "unimplemented lane is refused" "1" "$?"
# Parses a plist <integer>N</integer> and a systemd *:N:00 alike.
sched_minute() {
    "$S/install-schedule.sh" --render "$1" intake \
        | sed -n -e 's/.*<key>Minute<\/key><integer>\([0-9]*\)<\/integer>.*/\1/p' \
                 -e 's/^OnCalendar=.*:\([0-9][0-9]*\):00$/\1/p' | head -1
}
mins=""
for n in alpha bravo charlie delta; do
    "$S/config.sh" init "$n" "$(jq -c --arg n "$n" '.name=$n' <<<"$CFG")" >/dev/null
    mins="$mins $(sched_minute "$n")"
done
eq "minutes are spread across names" "true" \
   "$([ "$(printf '%s' "$mins" | tr ' ' '\n' | sort -u | wc -l | tr -d ' ')" -gt 1 ] && echo true || echo false)"

group "precheck wrapper (no credentials present, so Slack degrades)"
( "$S/run-lane.sh" t1 intake >/dev/null 2>&1 ); eq "runs and exits 0" "0" "$?"
eq "journals a run_start" "1" "$(grep -c '"action":"run_start"' "$XDG_STATE_HOME/epic-watch/t1/journal.ndjson")"
( "$S/run-lane.sh" nosuch intake >/dev/null 2>&1 ); eq "unknown watcher is 2" "2" "$?"
mkdir -p "$XDG_STATE_HOME/epic-watch/t1/intake.lock.d"; echo $$ > "$XDG_STATE_HOME/epic-watch/t1/intake.lock.d/pid"
"$S/run-lane.sh" t1 intake >/dev/null 2>&1
eq "held lock yields lock_skip" "lock_skip" "$(tail -1 "$XDG_STATE_HOME/epic-watch/t1/journal.ndjson" | jq -r '.action')"
eq "lock_skip still carries a run_id" "true" "$(tail -1 "$XDG_STATE_HOME/epic-watch/t1/journal.ndjson" | jq -r '.run_id != null')"
rm -rf "$XDG_STATE_HOME/epic-watch/t1/intake.lock.d"

group "launcher failure branches"
L="$S/epic-watch-launch"
"$S/config.sh" set-env t1 skill_root /definitely/not/here >/dev/null
( "$L" t1 intake >/dev/null 2>&1 ); eq "unresolvable root exits nonzero" "1" "$?"
eq "  records a launch failure" "no_skill_root" "$(jq -r .class "$XDG_STATE_HOME/epic-watch/t1/launch-failure.json")"
eq "  and an ALERT" "0" "$( [ -f "$XDG_STATE_HOME/epic-watch/t1/ALERT" ] && echo 0 || echo 1 )"
eq "  but never health.json directly" "closed" "$("$S/config.sh" health-get t1 | jq -r '.lanes.intake.breaker')"
chmod 644 "$XDG_CONFIG_HOME/epic-watch/env"
( "$L" t1 intake >/dev/null 2>&1 ); eq "wrong env mode exits nonzero" "1" "$?"
eq "  with an outcome, not silence" "env_mode" "$(jq -r .class "$XDG_STATE_HOME/epic-watch/t1/launch-failure.json")"
chmod 600 "$XDG_CONFIG_HOME/epic-watch/env"

group "wrapper outcomes driven by fixtures"
export SHORTCUT_API_TOKEN=fixture SLACK_USER_TOKEN=fixture
# Two servers, two runtime dirs: serve() stops the previous one, and this run needs both a
# reachable Shortcut for the credential probe and a Slack to read.
BASE_SC="$("$HERE/fixtures/server.sh" start shortcut "$SANDBOX/fx-w9sc")"
"$S/config.sh" init w9 "$(jq -c '.name="w9"|.epic=1' <<<"$CFG")" >/dev/null
J9="$XDG_STATE_HOME/epic-watch/w9/journal.ndjson"
acts() { jq -r '.action' "$J9" | tr '\n' ' '; }

# No Slack token: the shell path was never configured here, which degrades rather than fails.
( env -u SLACK_USER_TOKEN SHORTCUT_API_BASE="$BASE_SC" "$S/run-lane.sh" w9 intake >/dev/null 2>&1 )
eq "an absent slack token degrades the run" "true" "$(grep -c '"action":"degraded"' "$J9" >/dev/null 2>&1 && echo true || echo false)"
# A refused connection is an upstream error, not an absent capability.
SHORTCUT_API_BASE="$BASE_SC" SLACK_API_BASE="http://127.0.0.1:1" "$S/run-lane.sh" w9 intake >/dev/null 2>&1
eq "an unreachable slack fails the run instead" "failed" "$(tail -2 "$J9" | head -1 | jq -r '.action')"
eq "every run closes with run_end" "true" \
   "$([ "$(grep -c '"action":"run_start"' "$J9")" = "$(grep -c '"action":"run_end"' "$J9")" ] && echo true || echo false)"
eq "degraded run withholds last_success" "none" \
   "$("$S/config.sh" health-get w9 | jq -r '.lanes.intake.last_success // "none"')"
eq "degraded run still records last_run" "true" \
   "$("$S/config.sh" health-get w9 | jq -r '.lanes.intake.last_run != null')"

# The mirror case: Slack fine, Shortcut credential gone. Must not report healthy.
BASE_SL="$("$HERE/fixtures/server.sh" start slack_ok "$SANDBOX/fx-w9sl")"
( env -u SHORTCUT_API_TOKEN SLACK_API_BASE="$BASE_SL" "$S/run-lane.sh" w9 intake >/dev/null 2>&1 )
eq "mirror case fails the run" "failed" "$(tail -2 "$J9" | head -1 | jq -r '.action')"
eq "mirror case leaves last_success unset" "none" \
   "$("$S/config.sh" health-get w9 | jq -r '.lanes.intake.last_success // "none"')"

# Three failures trip the breaker; the next fires throttle rather than halt.
for _ in 1 2 3; do ( env -u SHORTCUT_API_TOKEN "$S/run-lane.sh" w9 intake >/dev/null 2>&1 ); done
eq "breaker trips at three failures" "open" "$("$S/config.sh" health-get w9 | jq -r '.lanes.intake.breaker')"
eq "  and writes an ALERT" "0" "$( [ -f "$XDG_STATE_HOME/epic-watch/w9/ALERT" ] && echo 0 || echo 1 )"
( env -u SHORTCUT_API_TOKEN "$S/run-lane.sh" w9 intake >/dev/null 2>&1 )
eq "an open breaker throttles rather than halting" "throttled" "$(tail -1 "$J9" | jq -r '.action')"
eq "  and counts the fire" "true" \
   "$([ "$("$S/config.sh" health-get w9 | jq -r '.lanes.intake.fires_since_open')" -gt 0 ] && echo true || echo false)"
# A throttled fire also appends a record, so the action is what distinguishes a bypass.
SHORTCUT_API_BASE="$BASE_SC" SLACK_API_BASE="http://127.0.0.1:1" "$S/run-lane.sh" w9 intake --once >/dev/null 2>&1
eq "--once bypasses the breaker rather than throttling" "true" \
   "$([ "$(tail -1 "$J9" | jq -r '.action')" != "throttled" ] && echo true || echo false)"
# The automatic half of the recovery: a clean-enough run closes the breaker without a human.
"$S/config.sh" health-set w9 intake '{"breaker":"open","consecutive_failures":3,"fires_since_open":5}'
"$S/config.sh" alert-set w9 '{"ts":1,"lane":"intake","class":"breaker","detail":"x"}'
( env -u SLACK_USER_TOKEN SHORTCUT_API_BASE="$BASE_SC" "$S/run-lane.sh" w9 intake >/dev/null 2>&1 )
eq "a degraded run closes the breaker on its own" "closed" "$("$S/config.sh" health-get w9 | jq -r '.lanes.intake.breaker')"
eq "  and clears the marker" "null" "$("$S/config.sh" health-get w9 | jq -r '.alert // "null"')"

"$S/config.sh" reset w9 intake
eq "reset zeroes fires_since_open" "0" "$("$S/config.sh" health-get w9 | jq -r '.lanes.intake.fires_since_open')"

# A quiet channel: nothing newer than the clamp.
"$S/config.sh" watermark-set w9 "intake/C1" "$(date +%s).000000"
SHORTCUT_API_BASE="$BASE_SC" SLACK_API_BASE="$BASE_SL" "$S/run-lane.sh" w9 intake >/dev/null 2>&1
eq "fixture messages predate the clamp, so the run is quiet" "quiet" "$(tail -2 "$J9" | head -1 | jq -r '.action')"
eq "quiet run records last_success" "true" \
   "$("$S/config.sh" health-get w9 | jq -r '.lanes.intake.last_success != null')"
eq "source entries carry kind, ref and origin" "true" \
   "$(jq -sr '[.[] | .sources[]?] | (length > 0) and all(has("kind") and has("ref") and has("origin"))' "$J9")"

# An answered ask is work even when the channel is quiet. A stub with a valid result line, so
# the run completes and journals pending_work rather than failing on a missing line.
W9_BIN="$SANDBOX/w9bin"; mkdir -p "$W9_BIN"
w9_env="$(jq -nc --arg r "EPICWATCH_RESULT $(jq -nc '{watcher:"w9",lane:"intake",sources:{},actions:{filed:0,asked:0,commented:0,skipped:0},asks:[]}')" '{result: $r, permission_denials: []}')"
{ printf '#!/bin/bash\ncat <<'"'"'J'"'"'\n'; printf '%s\n' "$w9_env"; printf 'J\n'; } > "$W9_BIN/claude"
chmod +x "$W9_BIN/claude"
"$S/config.sh" ask-set w9 "C1:100.000001" "{\"asked_at\":$(date +%s),\"ask_ts\":\"120.000001\",\"reaction_baseline\":[],\"status\":\"open\",\"story_id\":null}"
PATH="$W9_BIN:$PATH" SHORTCUT_API_BASE="$BASE_SC" SLACK_API_BASE="$BASE_SL" "$S/run-lane.sh" w9 intake >/dev/null 2>&1
eq "an answered ask makes a quiet channel report work" "true" \
   "$(grep -qc '"action":"pending_work"' "$J9" >/dev/null && echo true || echo false)"
"$HERE/fixtures/server.sh" stop "$SANDBOX/fx-w9sc" >/dev/null 2>&1 || true
"$HERE/fixtures/server.sh" stop "$SANDBOX/fx-w9sl" >/dev/null 2>&1 || true
unset SHORTCUT_API_TOKEN SLACK_USER_TOKEN

group "remaining client subcommands and negative ask paths"
export SHORTCUT_API_TOKEN=fixture SLACK_USER_TOKEN=fixture
BASE="$(serve shortcut)"
eq "epic-stories parses (stage-2 surface, no 1a caller)" "42" \
   "$(SHORTCUT_API_BASE="$BASE" "$S/shortcut.sh" epic-stories 1 | jq -r '.[0].id')"
unserve
BASE="$(serve slack_ok)"
eq "search-messages parses" "500.000005" \
   "$(SLACK_API_BASE="$BASE" "$S/slack.sh" search-messages "anything" | jq -r '.messages.matches[0].ts')"
unserve

# A thread holding only the watcher's own question is not answered, and a reaction already in
# the baseline is not an answer either. Both are the cases that decide whether an ignored
# question wakes a model on every quiet run.
# Two servers at once: the run needs a reachable Shortcut for its credential probe, so
# stopping one to start the other would fail the run for the wrong reason.
BASE_SC="$("$HERE/fixtures/server.sh" start shortcut "$SANDBOX/fx-sc")"
BASE_SL="$("$HERE/fixtures/server.sh" start slack_selfonly "$SANDBOX/fx-sl")"
"$S/config.sh" init w10 "$(jq -c '.name="w10"|.epic=1' <<<"$CFG")" >/dev/null
J10="$XDG_STATE_HOME/epic-watch/w10/journal.ndjson"
"$S/config.sh" watermark-set w10 "intake/C1" "$(date +%s).000000"
"$S/config.sh" ask-set w10 "C1:100.000001" "{\"asked_at\":$(date +%s),\"ask_ts\":\"120.000001\",\"reaction_baseline\":[\"eyes\"],\"status\":\"open\",\"story_id\":null}"
SHORTCUT_API_BASE="$BASE_SC" SLACK_API_BASE="$BASE_SL" "$S/run-lane.sh" w10 intake >/dev/null 2>&1
eq "own question plus a baseline reaction is not an answer" "quiet" "$(tail -2 "$J10" | head -1 | jq -r '.action')"
"$HERE/fixtures/server.sh" stop "$SANDBOX/fx-sc" >/dev/null 2>&1 || true
"$HERE/fixtures/server.sh" stop "$SANDBOX/fx-sl" >/dev/null 2>&1 || true
unset SHORTCUT_API_TOKEN SLACK_USER_TOKEN

# The regression the round-4 fix introduced: with an open ask, an absent Slack token was
# classified as a failure instead of a degradation, so a merely unconfigured machine tripped
# its own breaker. The existing degrade test could not catch it, because that watcher has no
# open ask at that point.
"$S/config.sh" init wask "$(jq -c '.name="wask"|.epic=1' <<<"$CFG")" >/dev/null
JASK="$XDG_STATE_HOME/epic-watch/wask/journal.ndjson"
"$S/config.sh" ask-set wask "C1:100.000001" "{\"asked_at\":$(date +%s),\"ask_ts\":\"120.000001\",\"reaction_baseline\":[],\"status\":\"open\",\"story_id\":null}"
BASE_ASK="$("$HERE/fixtures/server.sh" start shortcut "$SANDBOX/fx-ask")"
( env -u SLACK_USER_TOKEN SHORTCUT_API_TOKEN=x SHORTCUT_API_BASE="$BASE_ASK" "$S/run-lane.sh" wask intake >/dev/null 2>&1 )
"$HERE/fixtures/server.sh" stop "$SANDBOX/fx-ask" >/dev/null 2>&1 || true
eq "an open ask plus no slack token still only degrades" "degraded" "$(tail -2 "$JASK" | head -1 | jq -r '.action')"
eq "  and does not touch the breaker" "closed" "$("$S/config.sh" health-get wask | jq -r '.lanes.intake.breaker // "closed"')"
eq "an invalid watcher name is a usage error, not a missing config" "1" \
   "$( ( "$S/run-lane.sh" "../escape" intake >/dev/null 2>&1 ); echo $? )"
eq "a non-numeric workflow_state_id is refused" "2" \
   "$( ( "$S/config.sh" init twf "$(jq -c '.name="twf"|.intake_state.workflow_state_id="nope"' <<<"$CFG")" >/dev/null 2>&1 ); echo $? )"
eq "a malformed lookback still lists the other errors" "true" \
   "$( out="$( ( "$S/config.sh" init tml "$(jq -c '.name="tml"|.lookback="1h30m"|.slack_self_id=null' <<<"$CFG")" ) 2>&1 )"
      printf '%s' "$out" | grep -q 'slack_self_id' && echo true || echo false )"

group "run_id and alert surfacing"
# Asserted by observation rather than by grepping the source for an export statement.
eq "a run adopts an inherited run_id" "probe-456" \
   "$(EPIC_WATCH_RUN_ID=probe-456 "$S/run-lane.sh" w10 intake >/dev/null 2>&1; jq -sr '[.[] | select(.run_id=="probe-456")] | if length > 0 then "probe-456" else "none" end' "$J10")"
"$S/config.sh" alert-set w10 "{\"ts\":$(( $(date +%s) + 300 )),\"lane\":\"intake\",\"class\":\"breaker\",\"detail\":\"x\"}"
eq "health-get surfaces the ALERT marker" "breaker" "$("$S/config.sh" health-get w10 | jq -r '.alert.class')"
printf '{"ts":1,"lane":"intake","class":"no_root","detail":"x"}\n' > "$XDG_STATE_HOME/epic-watch/w10/launch-failure.json"
"$S/config.sh" health-set w10 intake "{\"last_success\":$(date +%s)}"
eq "a launch failure older than the newest success is stale" "null" \
   "$("$S/config.sh" health-get w10 | jq -r '.launch_failure // "null"')"

group "launcher branches"
L="$S/epic-watch-launch"
"$S/config.sh" init w11 "$(jq -c '.name="w11"' <<<"$CFG")" >/dev/null
"$S/config.sh" set-env w11 skill_root "$(cd "$S/.." && pwd)" >/dev/null
"$S/config.sh" set-env w11 claude_bin /definitely/not/executable >/dev/null
( "$L" w11 intake >/dev/null 2>&1 ); eq "unusable claude_bin is reported" "1" "$?"
eq "  with its own class" "no_claude" "$(jq -r .class "$XDG_STATE_HOME/epic-watch/w11/launch-failure.json")"
"$S/config.sh" set-env w11 claude_bin "" >/dev/null
# A config dir with no skill in it: the recorded skill_root is what has to carry the run,
# because a scheduled fire inherits no CLAUDE_CONFIG_DIR and this machine has two of them.
"$S/config.sh" set-env w11 claude_config_dir "$SANDBOX/emptyccd" >/dev/null
mkdir -p "$SANDBOX/emptyccd"
# A stub claude on PATH: the runner has none, and the no_claude branch is a different
# assertion than this one.
STUB_BIN="$SANDBOX/stubbin"; mkdir -p "$STUB_BIN"
printf '#!/bin/sh\nexit 0\n' > "$STUB_BIN/claude"; chmod +x "$STUB_BIN/claude"
( PATH="$STUB_BIN:$PATH" SHORTCUT_API_TOKEN=x SLACK_USER_TOKEN=x "$L" w11 intake >/dev/null 2>&1 )
eq "resolves from env.skill_root with nothing in the config dir" "0" "$?"

group "the lane invocation (stub claude, so no model runs)"
# The wrapper calls `claude` by name, which is what makes every branch of the invocation
# testable without spending a token or touching Shortcut.
STUBC="$SANDBOX/stubclaude"; mkdir -p "$STUBC"
# jq builds the envelope: hand-escaping JSON inside a heredoc inside a shell string loses
# backslashes, which is how an earlier version of this silently stubbed invalid JSON and the
# wrapper correctly reported "no result line".
stub_lane() {
    local envelope
    envelope="$(jq -nc --arg r "$1" --argjson d "${2:-[]}" '{result: $r, permission_denials: $d}')"
    { printf '#!/bin/bash\ncat <<'"'"'STUBJSON'"'"'\n'; printf '%s\n' "$envelope"; printf 'STUBJSON\n'; } > "$STUBC/claude"
    chmod +x "$STUBC/claude"
}
lane_line() {
    printf 'EPICWATCH_RESULT %s' "$(jq -nc --arg w "$1" --argjson src "$2" --argjson act "$3" --argjson asks "${4:-[]}" \
        '{watcher: $w, lane: "intake", sources: $src, actions: $act, asks: $asks}')"
}
NOACT='{"filed":0,"asked":0,"commented":0,"skipped":0}'
src_ok() { jq -nc --arg t "$NEW_TS" --arg k "${1:-intake/C1}" --argjson n "${2:-1}" '{($k):{status:"ok",newest_processed:$t,processed:$n}}'; }

export SHORTCUT_API_TOKEN=fixture SLACK_USER_TOKEN=fixture
BASE_L="$("$HERE/fixtures/server.sh" start shortcut "$SANDBOX/fx-lane")"
mk_watcher() {
    "$S/config.sh" init "$1" "$(jq -c --arg n "$1" '.name=$n|.epic=1' <<<"$CFG")" >/dev/null
    "$S/config.sh" watermark-set "$1" "intake/C1" "1.000000"
}
run_lane_with_work() {
    SHORTCUT_API_BASE="$BASE_L" SLACK_API_BASE="$2" PATH="$STUBC:$PATH" \
        "$S/run-lane.sh" "$1" intake >/dev/null 2>&1
}

# Fixture messages with recent timestamps. The committed fixtures use 1970-era ts values,
# which sit below the now-minus-lookback clamp, so a probe against them is correctly quiet.
FRESH_DIR="$SANDBOX/fixtures-fresh"; mkdir -p "$FRESH_DIR"
NOW_TS="$(date +%s)"
NEW_TS="$((NOW_TS - 60)).000001"
printf '{"ok":true,"messages":[{"ts":"%s","user":"UOTHER","text":"bug: saving a long custom field fails"}]}' \
    "$NEW_TS" > "$FRESH_DIR/GET_conversations.history.200"
printf '{"ok":true,"messages":[{"ts":"%s","user":"UOTHER","text":"parent"}]}' \
    "$NEW_TS" > "$FRESH_DIR/GET_conversations.replies.200"
printf '{"ok":true,"message":{"reactions":[]}}' > "$FRESH_DIR/GET_reactions.get.200"
BASE_SLK="$("$HERE/fixtures/server.sh" start "$FRESH_DIR" "$SANDBOX/fx-lane-slk")"

# A well-formed result line advances the watermark to what the lane reported.
mk_watcher lane1
stub_lane "did the thing
$(lane_line lane1 "$(src_ok intake/C1 3)" "$NOACT")"
run_lane_with_work lane1 "$BASE_SLK"
eq "a reported ok source advances the watermark" "$NEW_TS" "$("$S/config.sh" watermark-get lane1 intake/C1)"
eq "  and the run is not a failure" "true" \
   "$("$S/config.sh" health-get lane1 | jq -r '.lanes.intake.last_error == null')"

# No result line is a failure regardless of exit status.
mk_watcher lane2
stub_lane "I had a lovely time and will not be reporting anything"
run_lane_with_work lane2 "$BASE_SLK"
eq "a missing result line fails the run" "1" "$("$S/config.sh" health-get lane2 | jq -r '.lanes.intake.consecutive_failures')"
eq "  and the watermark does not move" "1.000000" "$("$S/config.sh" watermark-get lane2 intake/C1)"

# A denial is a failure even when the line is well formed.
mk_watcher lane3
stub_lane "$(lane_line lane3 "$(src_ok)" "$NOACT")" '[{"tool_name":"mcp__claude_ai_Slack__slack_send_message"}]'
run_lane_with_work lane3 "$BASE_SLK"
eq "a denial fails the run even with a good line" "1" "$("$S/config.sh" health-get lane3 | jq -r '.lanes.intake.consecutive_failures')"
eq "  and records which tool" "true" \
   "$("$S/config.sh" health-get lane3 | jq -r '(.lanes.intake.last_error.denials | length) > 0')"

# An unknown source key is refused rather than silently advancing nothing.
mk_watcher lane4
stub_lane "$(lane_line lane4 "$(jq -nc --arg t "$NEW_TS" '{"intake/#team-chat":{status:"ok",newest_processed:$t,processed:1}}')" "$NOACT")"
run_lane_with_work lane4 "$BASE_SLK"
eq "an unknown source key fails the run" "1" "$("$S/config.sh" health-get lane4 | jq -r '.lanes.intake.consecutive_failures')"

# ok with no newest_processed cannot advance anything.
mk_watcher lane5
stub_lane "$(lane_line lane5 '{"intake/C1":{"status":"ok","processed":1}}' "$NOACT")"
run_lane_with_work lane5 "$BASE_SLK"
eq "ok without newest_processed fails the run" "1" "$("$S/config.sh" health-get lane5 | jq -r '.lanes.intake.consecutive_failures')"

# Claimed actions must match journaled ones.
mk_watcher lane6
stub_lane "$(lane_line lane6 "$(src_ok)" '{"filed":2,"asked":0,"commented":0,"skipped":0}')"
run_lane_with_work lane6 "$BASE_SLK"
eq "claiming files it did not journal fails the run" "1" "$("$S/config.sh" health-get lane6 | jq -r '.lanes.intake.consecutive_failures')"

# A reported ask becomes an open registry entry the next run can poll.
mk_watcher lane7
stub_lane "$(lane_line lane7 "$(src_ok)" '{"filed":0,"asked":1,"commented":0,"skipped":0}' '[{"channel":"C1","thread_ts":"200.000002","ask_ts":"210.000002","action":"asked","story_id":null,"reaction_baseline":[]}]')"
"$S/config.sh" journal lane7 "$(jq -nc --arg r "$(date +%s)" '{ts:1,run_id:"x",watcher:"lane7",lane:"intake",action:"asked",target:"C1:200.000002",sources:[{kind:"slack_message",ref:"https://gladly.slack.com/archives/C1/p200000002",origin:"window"}],detail:null}')"
run_lane_with_work lane7 "$BASE_SLK"
eq "a reported ask is registered as open" "1" "$("$S/config.sh" ask-list lane7 open | wc -l | tr -d ' ')"

# --dry-run performs no writes, enforced by the scripts rather than by asking nicely.
eq "dry run refuses a Shortcut write" "1" \
   "$( ( EPIC_WATCH_DRY_RUN=1 "$S/shortcut.sh" create-story '{"name":"x"}' >/dev/null 2>&1 ); echo $? )"
eq "dry run refuses a Slack post" "1" \
   "$( ( EPIC_WATCH_DRY_RUN=1 "$S/slack.sh" post-thread-reply C1 1.1 hi >/dev/null 2>&1 ); echo $? )"
eq "dry run still allows reads" "0" \
   "$( ( EPIC_WATCH_DRY_RUN=1 SHORTCUT_API_BASE="$BASE_L" "$S/shortcut.sh" epic 1 >/dev/null 2>&1 ); echo $? )"

"$HERE/fixtures/server.sh" stop "$SANDBOX/fx-lane" >/dev/null 2>&1 || true
"$HERE/fixtures/server.sh" stop "$SANDBOX/fx-lane-slk" >/dev/null 2>&1 || true
unset SHORTCUT_API_TOKEN SLACK_USER_TOKEN

group "the silent class: a run that does nothing must not look healthy"
# Own servers: the lane group stopped its own, and a precheck failure would make every
# assertion below pass for the wrong reason.
BASE_L="$("$HERE/fixtures/server.sh" start shortcut "$SANDBOX/fx-silent-sc")"
BASE_SLK="$("$HERE/fixtures/server.sh" start "$FRESH_DIR" "$SANDBOX/fx-silent-sl")"
export SHORTCUT_API_TOKEN=fixture SLACK_USER_TOKEN=fixture
# Each of these was green before, which is the point: they are the paths where the tool
# reports success while achieving nothing.

# A crash after the lock has to feed the breaker like any other failure. Crashing via an
# unwritable tmp dir rather than by breaking jq, which the crash handler itself needs.
mk_watcher crash1
mkdir -p "$XDG_STATE_HOME/epic-watch/crash1/tmp"
for _ in 1 2 3; do
    chmod 500 "$XDG_STATE_HOME/epic-watch/crash1/tmp"
    ( SHORTCUT_API_BASE="$BASE_L" SLACK_API_BASE="$BASE_SLK" "$S/run-lane.sh" crash1 intake >/dev/null 2>&1 )
    chmod 700 "$XDG_STATE_HOME/epic-watch/crash1/tmp"
done
eq "a crashed run journals crashed" "crashed" \
   "$(tail -1 "$XDG_STATE_HOME/epic-watch/crash1/journal.ndjson" | jq -r '.action')"
eq "  three crashes trip the breaker" "open" "$("$S/config.sh" health-get crash1 | jq -r '.lanes.intake.breaker')"
eq "  and count as failures" "3" "$("$S/config.sh" health-get crash1 | jq -r '.lanes.intake.consecutive_failures')"
eq "  and raise an alert" "crashed" "$("$S/config.sh" health-get crash1 | jq -r '.alert.class // "none"')"

# ok with processed:0 contradicts a precheck that found work; the wrapper holds both facts.
mk_watcher zero1
stub_lane "$(lane_line zero1 "$(jq -nc --arg t "$NEW_TS" '{"intake/C1":{status:"ok",newest_processed:$t,processed:0}}')" "$NOACT")"
run_lane_with_work zero1 "$BASE_SLK"
eq "ok with processed:0 after the precheck found work fails" "1" \
   "$("$S/config.sh" health-get zero1 | jq -r '.lanes.intake.consecutive_failures')"
eq "  and the watermark is held" "1.000000" "$("$S/config.sh" watermark-get zero1 intake/C1)"

# A failing run must not advance a watermark past messages it never read.
mk_watcher hold1
stub_lane "$(lane_line hold1 "$(src_ok)" "$NOACT")" '[{"tool_name":"mcp__claude_ai_Slack__slack_send_message"}]'
run_lane_with_work hold1 "$BASE_SLK"
eq "a denied run holds the watermark" "1.000000" "$("$S/config.sh" watermark-get hold1 intake/C1)"
mk_watcher hold2
stub_lane "$(lane_line hold2 "$(src_ok)" '{"filed":2,"asked":0,"commented":0,"skipped":0}')"
run_lane_with_work hold2 "$BASE_SLK"
eq "a run claiming unjournaled work holds the watermark" "1.000000" \
   "$("$S/config.sh" watermark-get hold2 intake/C1)"

# A posted question is a side effect that already happened, so it is recorded even when the
# run fails; otherwise the next run asks the same thread again.
mk_watcher ask1
stub_lane "$(lane_line ask1 "$(src_ok)" '{"filed":0,"asked":1,"commented":0,"skipped":0}' \
    '[{"channel":"C1","thread_ts":"200.000002","ask_ts":"210.000002","action":"asked","story_id":null,"reaction_baseline":["eyes"]}]')"
run_lane_with_work ask1 "$BASE_SLK"
eq "an ask is registered even though the run failed" "1" "$("$S/config.sh" ask-list ask1 open | wc -l | tr -d ' ')"
eq "  with its baseline intact, not shifted by an empty field" '["eyes"]' \
   "$("$S/config.sh" ask-list ask1 open | jq -c '.value.reaction_baseline')"
eq "  and its ask_ts in the right field" "210.000002" \
   "$("$S/config.sh" ask-list ask1 open | jq -r '.value.ask_ts')"

# The field-collapse bug itself: a null thread_ts must be refused, not silently shifted.
mk_watcher ask2
stub_lane "$(lane_line ask2 "$(src_ok)" '{"filed":0,"asked":1,"commented":0,"skipped":0}' \
    '[{"channel":"C1","thread_ts":null,"ask_ts":"210.000002","action":"asked","story_id":null,"reaction_baseline":["eyes"]}]')"
run_lane_with_work ask2 "$BASE_SLK"
eq "an ask with a null thread_ts is refused, not mis-keyed" "0" \
   "$("$S/config.sh" ask-list ask2 | wc -l | tr -d ' ')"

# --max-turns bounds turns, not wall clock, so a single blocking call could hold the lane
# until the lock aged out. The deadline is enforced in-process because `timeout` is absent
# from the PATH a launchd job gets.
mk_watcher slow1
SLOWBIN="$SANDBOX/slowbin"; mkdir -p "$SLOWBIN"
printf '#!/bin/bash\nsleep 60\n' > "$SLOWBIN/claude"; chmod +x "$SLOWBIN/claude"
( EPIC_WATCH_LANE_DEADLINE=4 PATH="$SLOWBIN:$PATH" SHORTCUT_API_BASE="$BASE_L" \
  SLACK_API_BASE="$BASE_SLK" "$S/run-lane.sh" slow1 intake >/dev/null 2>&1 )
eq "a lane past its deadline is terminated and fails" "1" \
   "$("$S/config.sh" health-get slow1 | jq -r '.lanes.intake.consecutive_failures')"
eq "  with the deadline named" "true" \
   "$("$S/config.sh" health-get slow1 | jq -r '[.lanes.intake.last_error.detail[]] | any(test("deadline"))')"
eq "  and the watermark held" "1.000000" "$("$S/config.sh" watermark-get slow1 intake/C1)"

"$HERE/fixtures/server.sh" stop "$SANDBOX/fx-silent-sc" >/dev/null 2>&1 || true
"$HERE/fixtures/server.sh" stop "$SANDBOX/fx-silent-sl" >/dev/null 2>&1 || true
unset SHORTCUT_API_TOKEN SLACK_USER_TOKEN

group "traceability checker"
eq "resolves a good journal" "0" "$( ( "$HERE/assert-traceable.sh" lane7 >/dev/null 2>&1 ); echo $? )"
"$S/config.sh" journal lane7 '{"ts":9,"run_id":"y","watcher":"lane7","lane":"intake","action":"filed","target":"1","sources":[{"kind":"slack_message","ref":"https://gladly.slack.com/archives/CBOGUS/p1","origin":"window"}],"detail":null}'
eq "rejects an invented channel" "1" "$( ( "$HERE/assert-traceable.sh" lane7 >/dev/null 2>&1 ); echo $? )"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
