#!/bin/bash
# Prints one line for each new review or approval, reviewer comment, unresolved
# thread reply from someone else, failed check, or merge or close on the pull
# requests listed in a file, polling until it's killed.
#
# Usage: bash watch-prs.sh <pr-list-file> <author-login> [interval-seconds]
# The list file has one owner/repo#number per line (lines starting with # are
# skipped). It's reread on every poll, so PRs can be added or removed while it
# runs. What has been reported is kept in <pr-list-file without extension>.seen,
# and the first poll with an empty .seen file records the current state without
# printing it.

set -u
list=$1
author=$2
interval=${3:-180}
seen="${list%.*}.seen"
touch "$seen"
announce=1
[ -s "$seen" ] || announce=0

query='query($o:String!,$r:String!,$n:Int!){repository(owner:$o,name:$r){pullRequest(number:$n){state
  reviews(last:50){nodes{id author{login} state}}
  comments(last:50){nodes{id author{login} body}}
  reviewThreads(first:100){nodes{isResolved path line comments(last:1){nodes{id author{login} body}}}}
  commits(last:1){nodes{commit{oid statusCheckRollup{contexts(first:100){nodes{__typename
    ... on CheckRun{name conclusion} ... on StatusContext{context state}}}}}}}}}}'

events_for() {
  local ref=$1 owner repo number
  owner=${ref%%/*}
  repo=${ref#*/}; repo=${repo%%#*}
  number=${ref##*#}
  env -u GITHUB_TOKEN gh api graphql -f query="$query" -f o="$owner" -f r="$repo" -F n="$number" 2>/dev/null |
    jq -r --arg ref "$ref" --arg me "$author" '
      def text: (. // "") | gsub("[\t\r\n]+"; " ") | .[0:160];
      def ci_bot: test("^(github-actions|dependabot|renovate|codecov)(\\[bot\\])?$");
      .data.repository.pullRequest as $pr
      | select($pr != null)
      | (if $pr.state != "OPEN" then "\($ref) \($pr.state)\t\($ref) is \($pr.state | ascii_downcase)" else empty end),
        ($pr.reviews.nodes[] | select(.author.login != $me)
          | "\(.id)\t\($ref) review by \(.author.login): \(.state | ascii_downcase)"),
        ($pr.comments.nodes[] | select(.author.login != $me and (.author.login | ci_bot | not))
          | "\(.id)\t\($ref) comment by \(.author.login): \(.body | text)"),
        ($pr.reviewThreads.nodes[] | select(.isResolved | not) | .comments.nodes[-1] as $last
          | select($last.author.login != $me)
          | "\($last.id)\t\($ref) unresolved thread \(.path):\(.line // "file") by \($last.author.login): \($last.body | text)"),
        ($pr.commits.nodes[0].commit as $c | $c.statusCheckRollup.contexts.nodes[]?
          | (if .__typename == "CheckRun" then {name, failed: (.conclusion | IN("FAILURE", "TIMED_OUT", "ACTION_REQUIRED"))}
             else {name: .context, failed: (.state | IN("FAILURE", "ERROR"))} end)
          | select(.failed)
          | "\($c.oid) \(.name)\t\($ref) check failed: \(.name) on \($c.oid[0:10])")'
}

while true; do
  while read -r ref; do
    [[ -z "$ref" || "$ref" == \#* ]] && continue
    events_for "$ref"
  done < "$list" |
    while IFS=$'\t' read -r key message; do
      grep -qxF "$key" "$seen" && continue
      echo "$key" >> "$seen"
      [ "$announce" = 1 ] && echo "$message"
    done
  announce=1
  sleep "$interval"
done
