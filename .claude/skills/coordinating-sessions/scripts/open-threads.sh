#!/bin/bash
# Lists, for each pull request, its unresolved review threads and the reviews
# posted since a given time by anyone other than the author.
#
# Usage: bash open-threads.sh <owner> <author-login> <since, ISO 8601> <repo:number>...
# Example: bash open-threads.sh sagansystems curbol 2026-11-13T00:00:00Z supernova:19518 connector-service:606

set -u
owner=$1
author=$2
since=$3
shift 3

query='query($o:String!,$r:String!,$n:Int!){repository(owner:$o,name:$r){pullRequest(number:$n){state
  reviewThreads(first:100){nodes{isResolved path line comments(last:1){nodes{author{login} createdAt body}}}}}}}'

for spec in "$@"; do
  repo=${spec%%:*}
  number=${spec##*:}
  env -u GITHUB_TOKEN gh api graphql -f query="$query" -f o="$owner" -f r="$repo" -F n="$number" -q '
    .data.repository.pullRequest as $pr
    | ($pr.reviewThreads.nodes | map(select(.isResolved == false))) as $open
    | "\($pr.state) '"$repo#$number"' unresolved=\($open | length)",
      ($open[] | "  thread \(.path):\(.line) last=\(.comments.nodes[-1].author.login): \(.comments.nodes[-1].body[0:160] | gsub("\n"; " "))")'
  env -u GITHUB_TOKEN gh api "repos/$owner/$repo/pulls/$number/reviews" --paginate -q '.[]
    | select(.submitted_at > "'"$since"'" and .user.login != "'"$author"'")
    | "  review \(.user.login) \(.state) \(.submitted_at[0:16]): \(.body[0:160] | gsub("\n"; " "))"'
done
