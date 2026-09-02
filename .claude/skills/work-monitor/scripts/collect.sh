#!/usr/bin/env bash
# Gather a work snapshot into state.json. No model is involved, so this is free
# to run on every invocation and the snapshot is never stale.
#
# A source that fails records itself in .errors rather than dropping out of the
# snapshot: a silently missing source is indistinguishable from a quiet one.

set -uo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATA_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/work-monitor"
CONFIG="$DATA_DIR/config.json"
STATE="$DATA_DIR/state.json"
PREV="$DATA_DIR/state.prev.json"
NOTES="$DATA_DIR/notes.md"

command -v jq >/dev/null || { echo "work-monitor requires jq" >&2; exit 1; }

mkdir -p "$DATA_DIR"
[ -f "$CONFIG" ] || cp "$SKILL_DIR/config.example.json" "$CONFIG"
[ -f "$NOTES" ] || printf '# Notes\n\nWhat I told work-monitor. Newest last.\n' > "$NOTES"

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
: > "$TMP/errors"
note_error() { printf '%s\n' "$1" >> "$TMP/errors"; }

days_ago() {
  if date -v-1d >/dev/null 2>&1; then date -v-"$1"d +%Y-%m-%d
  else date -d "$1 days ago" +%Y-%m-%d; fi
}

RECENT_DAYS=$(jq -r '.shortcut.recent_days // 7' "$CONFIG")
SINCE=$(days_ago "$RECENT_DAYS")
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

sc_api() {
  curl -sS --max-time 25 -H "Shortcut-Token: ${SHORTCUT_API_TOKEN:-}" "$@"
}

# ---------- Shortcut lookups ----------
echo '{}' > "$TMP/states.json"
echo '{}' > "$TMP/members.json"
MY_ID=""

if [ -z "${SHORTCUT_API_TOKEN:-}" ]; then
  note_error "SHORTCUT_API_TOKEN is unset; all Shortcut data is missing"
else
  sc_api "https://api.app.shortcut.com/api/v3/workflows" \
    | jq '[.[] | .states[] | {key: (.id|tostring), value: .name}] | from_entries' \
    > "$TMP/states.json" 2>/dev/null || note_error "could not load Shortcut workflow states"
  sc_api "https://api.app.shortcut.com/api/v3/members" \
    | jq '[.[] | {key: .id, value: .profile.mention_name}] | from_entries' \
    > "$TMP/members.json" 2>/dev/null || note_error "could not load Shortcut members"
  MY_ID=$(sc_api "https://api.app.shortcut.com/api/v3/member" | jq -r '.id // empty' 2>/dev/null)
  [ -n "$MY_ID" ] || note_error "could not resolve the current Shortcut member"
fi

# ---------- Epics ----------
: > "$TMP/epics.ndjson"
while read -r epic_id; do
  [ -n "$epic_id" ] || continue
  epic=$(sc_api "https://api.app.shortcut.com/api/v3/epics/$epic_id")
  if ! jq -e '.id' <<<"$epic" >/dev/null 2>&1; then
    note_error "epic $epic_id could not be read"
    continue
  fi
  recent=$(sc_api -G \
    --data-urlencode "query=epic:$epic_id updated:$SINCE..*" \
    --data-urlencode "page_size=25" \
    "https://api.app.shortcut.com/api/v3/search/stories")
  jq -e '.data' <<<"$recent" >/dev/null 2>&1 || { recent='{"data":[]}'; note_error "recent stories for epic $epic_id could not be read"; }

  jq -n \
    --argjson epic "$epic" \
    --argjson recent "$recent" \
    --slurpfile states "$TMP/states.json" \
    --slurpfile members "$TMP/members.json" \
    --arg me "$MY_ID" '
    ($states[0] // {}) as $S | ($members[0] // {}) as $M |
    {
      id: $epic.id,
      name: $epic.name,
      url: $epic.app_url,
      state: $epic.state,
      done: $epic.stats.num_stories_done,
      total: $epic.stats.num_stories_total,
      started: $epic.stats.num_stories_started,
      unstarted: $epic.stats.num_stories_unstarted,
      last_story_update: $epic.stats.last_story_update,
      recent_total: ($recent.total // ($recent.data | length)),
      recent: [ $recent.data[] | {
        id, name,
        url: .app_url,
        state: ($S[(.workflow_state_id|tostring)] // "unknown"),
        requested_by: ($M[.requested_by_id] // "unknown"),
        mine: (.owner_ids | index($me) != null),
        updated: .updated_at
      } ]
    }' >> "$TMP/epics.ndjson" 2>/dev/null || note_error "epic $epic_id could not be assembled"
done < <(jq -r '.shortcut.epics[]? // empty' "$CONFIG")

# ---------- Pull requests ----------
echo '[]' > "$TMP/prs.json"
echo '[]' > "$TMP/reviews.json"
if command -v gh >/dev/null; then
  PR_QUERY=$(jq -r '.github.search // "author:@me is:pr is:open archived:false"' "$CONFIG")
  gh api graphql -f query='
    query($q: String!) {
      search(query: $q, type: ISSUE, first: 50) {
        nodes { ... on PullRequest {
          number title url updatedAt isDraft mergeable reviewDecision headRefName
          repository { nameWithOwner }
          commits(last: 1) { nodes { commit { statusCheckRollup { state } } } }
        } }
      }
    }' -f q="$PR_QUERY" 2>/dev/null \
    | jq '[ .data.search.nodes[] | select(.number != null) | {
        repo: .repository.nameWithOwner,
        number, title, url,
        updated: .updatedAt,
        draft: .isDraft,
        review: (.reviewDecision // "NONE"),
        mergeable: .mergeable,
        checks: (.commits.nodes[0].commit.statusCheckRollup.state // "NONE"),
        branch: .headRefName,
        story: ((.title + " " + .headRefName) | capture("sc-(?<n>[0-9]+)").n // null)
      } ]' > "$TMP/prs.json" 2>/dev/null || note_error "could not read your open pull requests"

  gh search prs --review-requested=@me --state=open --limit 30 \
      --json repository,number,title,url,updatedAt 2>/dev/null \
    | jq '[ .[] | {repo: .repository.nameWithOwner, number, title, url, updated: .updatedAt} ]' \
    > "$TMP/reviews.json" 2>/dev/null || note_error "could not read PRs awaiting your review"
else
  note_error "gh is not installed; all GitHub data is missing"
fi

# ---------- Story -> epic, so PRs can be grouped ----------
STORY_EPICS='{}'
if [ -n "${SHORTCUT_API_TOKEN:-}" ]; then
  for sid in $(jq -r '[.[].story] | map(select(. != null)) | unique[]' "$TMP/prs.json" 2>/dev/null); do
    eid=$(sc_api "https://api.app.shortcut.com/api/v3/stories/$sid" | jq -r '.epic_id // empty' 2>/dev/null)
    [ -n "$eid" ] && STORY_EPICS=$(jq --arg s "$sid" --argjson e "$eid" '. + {($s): $e}' <<<"$STORY_EPICS")
  done
fi

# ---------- Local repos ----------
# Only repos with something in flight: uncommitted or unpushed work, a longrun
# inbox, or a feature branch touched inside the activity window. A checkout left
# on a feature branch a year ago is not in flight.
ACTIVE_DAYS=$(jq -r '.local.active_days // 30' "$CONFIG")
ACTIVE_CUTOFF=$(days_ago "$ACTIVE_DAYS")
: > "$TMP/local.ndjson"
while read -r root; do
  [ -n "$root" ] || continue
  root="${root/#\~/$HOME}"
  [ -d "$root" ] || { note_error "local root $root does not exist"; continue; }
  for dir in "$root"/*/; do
    dir="${dir%/}"
    [ -e "$dir/.git" ] || continue
    branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null) || continue
    dirty=$(git -C "$dir" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    ahead=$(git -C "$dir" rev-list --count '@{upstream}..HEAD' 2>/dev/null || echo 0)
    last=$(git -C "$dir" log -1 --format=%cI 2>/dev/null)
    decisions=""
    [ -f "$dir/.longrun/DECISIONS.md" ] && decisions=$(date -u -r "$dir/.longrun/DECISIONS.md" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)
    case "$branch" in main|master) on_feature=false ;; *) on_feature=true ;; esac
    recent_branch=false
    if [ "$on_feature" = true ] && [ -n "${last:-}" ] && [[ "${last:0:10}" > "$ACTIVE_CUTOFF" ]]; then
      recent_branch=true
    fi
    if [ "$recent_branch" = true ] || [ "${dirty:-0}" -gt 0 ] || [ "${ahead:-0}" -gt 0 ] || [ -n "$decisions" ]; then
      jq -n --arg name "$(basename "$dir")" --arg path "$dir" --arg branch "$branch" \
            --argjson dirty "${dirty:-0}" --argjson ahead "${ahead:-0}" \
            --arg last "${last:-}" --arg decisions "$decisions" \
            --arg story "$(printf '%s' "$branch" | grep -oE 'sc-[0-9]+' | head -1 | tr -d 'sc-')" '
        {name: $name, path: $path, branch: $branch, dirty: $dirty, ahead: $ahead,
         last_commit: (if $last == "" then null else $last end),
         decisions_updated: (if $decisions == "" then null else $decisions end),
         story: (if $story == "" then null else $story end)}' >> "$TMP/local.ndjson"
    fi
  done
done < <(jq -r '.local.roots[]? // empty' "$CONFIG")

# ---------- Assemble ----------
# Keep the prior snapshot so the skill can report what moved, not just what is.
[ -f "$STATE" ] && cp "$STATE" "$PREV"

jq -n \
  --arg generated_at "$NOW" \
  --arg since "$SINCE" \
  --slurpfile epics "$TMP/epics.ndjson" \
  --slurpfile prs "$TMP/prs.json" \
  --slurpfile reviews "$TMP/reviews.json" \
  --slurpfile local "$TMP/local.ndjson" \
  --argjson story_epics "$STORY_EPICS" \
  --rawfile errors "$TMP/errors" '
  {
    generated_at: $generated_at,
    since: $since,
    epics: $epics,
    prs: [ ($prs[0] // [])[] | . + {epic: ($story_epics[.story // ""] // null)} ],
    review_requests: ($reviews[0] // []),
    local: $local,
    errors: ($errors | split("\n") | map(select(length > 0)))
  }' > "$STATE"

echo "$STATE"
