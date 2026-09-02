#!/bin/bash
# Slack Web API client.
#
# Exit codes: 0 ok  1 usage  2 configuration absent  3 upstream API error
#             4 credential rejected
#
# Slack answers a rejected token with ok:false over HTTP 200, so the body is inspected
# rather than the status. Exit 2 (no token at all) and exit 4 (token refused) are kept
# apart because the caller escalates on 2 and fails on 4: only 2 means "this machine was
# never configured for the shell path, use MCP instead".

set -euo pipefail

BASE="${SLACK_API_BASE:-https://slack.com/api}"
MAX_PAGES_DEFAULT=10

# A directory rather than a variable: `api` runs on the left of a pipeline in places, where a
# variable assignment lands in a subshell the parent trap never sees, and `channel-history`
# calls it once per page.
BODY_DIR="$(mktemp -d)"
cleanup() { rm -rf "$BODY_DIR" 2>/dev/null; return 0; }
trap cleanup EXIT
die() { printf '%s\n' "$2" >&2; printf '{"ok":false,"error":%s}\n' "$(printf '%s' "$2" | jq -Rs .)"; exit "$1"; }

command -v jq >/dev/null 2>&1 || die 2 "jq is required but not installed"

require_token() { [ -n "${SLACK_USER_TOKEN:-}" ] || die 2 "SLACK_USER_TOKEN is not set"; }
refuse_if_dry_run() {
    [ "${EPIC_WATCH_DRY_RUN:-0}" = 1 ] && die 1 "refusing $1: EPIC_WATCH_DRY_RUN is set"
    return 0
}

# Returns the parsed body. A Slack error is classified here so every caller inherits the
# same mapping rather than re-deriving it.
api() {
    local path="$1"; shift
    local out; out="$(mktemp "$BODY_DIR/body.XXXXXX")"
    local code
    code=$(curl -sS --connect-timeout 10 --max-time 30 -G -H "Authorization: Bearer ${SLACK_USER_TOKEN}" \
        "$@" -o "$out" -w '%{http_code}' "${BASE}/${path}") || die 3 "curl failed for ${path}"
    [ "$code" = 200 ] || die 3 "Slack returned HTTP ${code} for ${path}"
    if [ "$(jq -r '.ok' "$out")" != true ]; then
        local err; err="$(jq -r '.error // "unknown"' "$out")"
        case "$err" in
            invalid_auth|not_authed|token_revoked|token_expired|account_inactive)
                die 4 "Slack rejected the credential: ${err}" ;;
            *) die 3 "Slack error for ${path}: ${err}" ;;
        esac
    fi
    cat "$out"
}

# Slack answers a rejected token with ok:false over HTTP 200 here too, so the same
# classification applies to writes as to reads.
post() {
    local path="$1" payload="$2"
    local out; out="$(mktemp "$BODY_DIR/post.XXXXXX")"
    local code
    code=$(curl -sS --connect-timeout 10 --max-time 30 -X POST \
        -H "Authorization: Bearer ${SLACK_USER_TOKEN}" \
        -H "Content-Type: application/json; charset=utf-8" \
        --data-binary "$payload" \
        -o "$out" -w '%{http_code}' "${BASE}/${path}") || die 3 "curl failed for ${path}"
    [ "$code" = 200 ] || die 3 "Slack returned HTTP ${code} for ${path}"
    if [ "$(jq -r '.ok' "$out")" != true ]; then
        local err; err="$(jq -r '.error // "unknown"' "$out")"
        case "$err" in
            invalid_auth|not_authed|token_revoked|token_expired|account_inactive|missing_scope)
                die 4 "Slack rejected the credential for ${path}: ${err}" ;;
            *) die 3 "Slack error for ${path}: ${err}" ;;
        esac
    fi
    cat "$out"
}

# A Slack ts and its permalink form differ only by the dot, so this is pure string work.
# It is the deduplication key, and nothing else in the skill carries config into this
# script, which is why the workspace is an argument rather than an assumption.
make_permalink() { printf 'https://%s.slack.com/archives/%s/p%s\n' "$1" "$2" "${3//./}"; }

usage() {
    cat >&2 <<'USAGE'
Usage: slack.sh <command> [args...]
  permalink <workspace> <channel> <ts>          pure construction, no API call, no token
  latest-ts <channel>                           limit=1 probe: newest ts, or empty
  channel-history <channel> <oldest> <latest> [max-pages]
                                                envelope {messages,truncated,oldest_read,newest_read}
  thread-replies <channel> <ts>                 conversations.replies (includes the parent)
  reactions <channel> <ts>                      reactions.get
  search-messages <query> [channel-name]        search.messages; channel NAME, not an ID
  post-thread-reply <channel> <thread-ts> <text>  chat.postMessage into a thread
  add-reaction <channel> <ts> <emoji>           reactions.add
  auth-test                                     auth.test; derives workspace and self id
USAGE
    exit 1
}

cmd="${1:-}"; shift || usage

case "$cmd" in
    permalink)
        [ $# -eq 3 ] || usage
        make_permalink "$1" "$2" "$3"
        ;;
    latest-ts)
        [ $# -eq 1 ] || usage
        require_token
        api conversations.history --data-urlencode "channel=$1" --data-urlencode "limit=1" \
            | jq -r '.messages[0].ts // ""'
        ;;
    channel-history)
        [ $# -ge 3 ] || usage
        require_token
        channel="$1"; oldest="$2"; latest="$3"; max_pages="${4:-$MAX_PAGES_DEFAULT}"
        # Slack pages newest-first, so a walk that stops early has read the NEWEST part of
        # the window and left older messages unread. The envelope reports what was read at
        # both ends so a caller can narrow the window from the top rather than advancing
        # past messages it never saw.
        agg="$(mktemp "$BODY_DIR/agg.XXXXXX")"
        echo '[]' > "$agg"
        cursor=""; pages=0; truncated=false
        while :; do
            args=(--data-urlencode "channel=$channel" --data-urlencode "oldest=$oldest"
                  --data-urlencode "latest=$latest" --data-urlencode "inclusive=false"
                  --data-urlencode "limit=200")
            [ -n "$cursor" ] && args+=(--data-urlencode "cursor=$cursor")
            page="$(api conversations.history "${args[@]}")"
            jq -s '.[0] + .[1]' "$agg" <(printf '%s' "$page" | jq '.messages') > "$agg.new"
            mv "$agg.new" "$agg"
            pages=$((pages + 1))
            cursor="$(printf '%s' "$page" | jq -r '.response_metadata.next_cursor // ""')"
            [ -n "$cursor" ] || break
            if [ "$pages" -ge "$max_pages" ]; then truncated=true; break; fi
        done
        jq -c --argjson truncated "$truncated" \
            '{messages: ., truncated: $truncated,
              newest_read: (if length > 0 then (max_by(.ts | tonumber).ts) else null end),
              oldest_read: (if length > 0 then (min_by(.ts | tonumber).ts) else null end)}' "$agg"
        ;;
    thread-replies)
        [ $# -eq 2 ] || usage
        require_token
        # Paged: an answer can sit past the first hundred replies, and the caller only looks
        # at what this returns.
        agg="$(mktemp "$BODY_DIR/replies.XXXXXX")"; echo '[]' > "$agg"
        cursor=""; pages=0; truncated=false
        while :; do
            args=(--data-urlencode "channel=$1" --data-urlencode "ts=$2" --data-urlencode "limit=100")
            [ -n "$cursor" ] && args+=(--data-urlencode "cursor=$cursor")
            page="$(api conversations.replies "${args[@]}")"
            jq -s '.[0] + .[1]' "$agg" <(printf '%s' "$page" | jq '.messages // []') > "$agg.new"
            mv "$agg.new" "$agg"
            pages=$((pages + 1))
            cursor="$(printf '%s' "$page" | jq -r '.response_metadata.next_cursor // ""')"
            [ -n "$cursor" ] || break
            if [ "$pages" -ge "$MAX_PAGES_DEFAULT" ]; then truncated=true; break; fi
        done
        jq -c --argjson truncated "$truncated" '{ok: true, messages: ., truncated: $truncated}' "$agg"
        ;;
    reactions)
        [ $# -eq 2 ] || usage
        require_token
        api reactions.get --data-urlencode "channel=$1" --data-urlencode "timestamp=$2"
        ;;
    search-messages)
        [ $# -ge 1 ] || usage
        require_token
        q="$1"
        # search.messages scopes by channel NAME; an ID in an in: filter matches nothing.
        [ $# -ge 2 ] && q="in:$2 $1"
        api search.messages --data-urlencode "query=$q" --data-urlencode "count=20" \
            --data-urlencode "sort=timestamp" --data-urlencode "sort_dir=desc"
        ;;
    post-thread-reply)
        refuse_if_dry_run post-thread-reply
        [ $# -eq 3 ] || usage
        require_token
        post chat.postMessage "$(jq -nc --arg c "$1" --arg t "$2" --arg x "$3" \
            '{channel: $c, thread_ts: $t, text: $x}')"
        ;;
    add-reaction)
        refuse_if_dry_run add-reaction
        [ $# -eq 3 ] || usage
        require_token
        post reactions.add "$(jq -nc --arg c "$1" --arg t "$2" --arg n "$3" \
            '{channel: $c, timestamp: $t, name: $n}')"
        ;;
    auth-test)
        [ $# -eq 0 ] || usage
        require_token
        api auth.test | jq -c '{workspace: (.url | sub("^https://";"") | sub("\\.slack\\.com/?$";"")), self_id: .user_id, team: .team}'
        ;;
    *) usage ;;
esac
