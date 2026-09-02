#!/bin/bash
# Shortcut REST v3 client.
#
# Exit codes, shared by every script in this skill:
#   0 ok  1 usage  2 configuration absent  3 upstream API error  4 credential rejected
#
# A missing SHORTCUT_API_TOKEN is exit 2 and, unlike the Slack equivalent, is a hard
# failure for the caller: no Shortcut MCP fallback exists to escalate to.

set -euo pipefail

BASE="${SHORTCUT_API_BASE:-https://api.app.shortcut.com/api/v3}"

BODY_DIR="$(mktemp -d)"
cleanup() { rm -rf "$BODY_DIR" 2>/dev/null; return 0; }
trap cleanup EXIT
die() { printf '%s\n' "$2" >&2; printf '{"ok":false,"error":%s}\n' "$(printf '%s' "$2" | jq -Rs .)"; exit "$1"; }

command -v jq >/dev/null 2>&1 || die 2 "jq is required but not installed"

require_token() { [ -n "${SHORTCUT_API_TOKEN:-}" ] || die 2 "SHORTCUT_API_TOKEN is not set"; }
refuse_if_dry_run() {
    [ "${EPIC_WATCH_DRY_RUN:-0}" = 1 ] && die 1 "refusing $1: EPIC_WATCH_DRY_RUN is set"
    return 0
}

# Emits the body on stdout. Maps HTTP status onto the shared exit contract, which is why
# the status is captured separately rather than inferred from the body.
request() {
    local method="$1" path="$2" payload="${3:-}" body_file
    body_file="$(mktemp "$BODY_DIR/body.XXXXXX")"
    local code
    if [ -n "$payload" ]; then
        code=$(curl -sS --connect-timeout 10 --max-time 30 -X "$method" \
            -H "Shortcut-Token: ${SHORTCUT_API_TOKEN}" \
            -H "Content-Type: application/json" \
            --data-binary "$payload" \
            -o "$body_file" -w '%{http_code}' \
            "${BASE}${path}" ) || die 3 "curl failed for ${method} ${path}"
    else
        code=$(curl -sS --connect-timeout 10 --max-time 30 -X "$method" \
            -H "Shortcut-Token: ${SHORTCUT_API_TOKEN}" \
            -H "Content-Type: application/json" \
            -o "$body_file" -w '%{http_code}' \
            "${BASE}${path}" ) || die 3 "curl failed for ${method} ${path}"
    fi
    case "$code" in
        2*) cat "$body_file"; return 0 ;;
        401|403) die 4 "credential rejected by Shortcut (HTTP ${code})" ;;
        *) die 3 "Shortcut returned HTTP ${code} for ${method} ${path}" ;;
    esac
}

urlencode() { printf '%s' "$1" | jq -Rr @uri; }

usage() {
    cat >&2 <<'USAGE'
Usage: shortcut.sh <command> [args...]
  create-story <json>              POST /stories; include epic_id, external_links, labels
  update-story <id> <json>         PUT /stories/<id>; labels is a replacement array
  comment <id> <text>              POST /stories/<id>/comments
  epic <id>                        one small GET /epics/<id>; the credential probe
  story <id>                       GET /stories/<id>
  story-by-external-link <url>     GET /external-link/stories (singular route)
  search-stories <query> [size]    GET /search/stories; results under .data[]
  workflow-states <workflow-id>    GET /workflows/<id>
  epic-stories <epic-id>           GET /epics/<id>/stories (stage 2 only; ~187KB)
USAGE
    exit 1
}

cmd="${1:-}"; shift || usage

# After the dispatch, so an unknown subcommand is a usage error rather than a configuration
# one no matter what the environment holds.
case "$cmd" in
    epic|story|story-by-external-link|search-stories|workflow-states|epic-stories) require_token ;;
    create-story|update-story|comment) require_token ;;
esac

case "$cmd" in
    epic)
        [ $# -eq 1 ] || usage
        request GET "/epics/$1"
        ;;
    story)
        [ $# -eq 1 ] || usage
        request GET "/stories/$1"
        ;;
    story-by-external-link)
        # Singular "external-link". The plural spelling 404s. A URL with no story
        # returns 200 [], so absence is an empty array rather than a 404, which is what
        # lets a caller fail closed: file only on 200 with an empty array.
        [ $# -eq 1 ] || usage
        request GET "/external-link/stories?external_link=$(urlencode "$1")"
        ;;
    search-stories)
        [ $# -ge 1 ] || usage
        request GET "/search/stories?query=$(urlencode "$1")&page_size=${2:-5}"
        ;;
    workflow-states)
        [ $# -eq 1 ] || usage
        request GET "/workflows/$1"
        ;;
    epic-stories)
        [ $# -eq 1 ] || usage
        request GET "/epics/$1/stories"
        ;;
    create-story)
        refuse_if_dry_run create-story
        [ $# -eq 1 ] || usage
        jq -e . >/dev/null 2>&1 <<<"$1" || die 1 "create-story needs valid JSON"
        request POST "/stories" "$1"
        ;;
    update-story)
        refuse_if_dry_run update-story
        [ $# -eq 2 ] || usage
        jq -e . >/dev/null 2>&1 <<<"$2" || die 1 "update-story needs valid JSON"
        request PUT "/stories/$1" "$2"
        ;;
    comment)
        refuse_if_dry_run comment
        [ $# -eq 2 ] || usage
        request POST "/stories/$1/comments" "$(jq -nc --arg t "$2" '{text: $t}')"
        ;;
    *) usage ;;
esac
