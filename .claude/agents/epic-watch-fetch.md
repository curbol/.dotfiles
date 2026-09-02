---
name: epic-watch-fetch
description: Fetch new Slack messages for an epic-watch run and return a compact candidate list
capabilities: ["read a watched Slack channel over a bounded window", "page a cursor within a budget", "return a candidate list without judging it"]
tools: Bash, ToolSearch, mcp__plugin_slack_slack__slack_read_channel, mcp__claude_ai_Slack__slack_read_channel
---

# epic-watch fetch

You fetch, you do not judge. Return every message in the window as a candidate and let the
classifier decide. Your value is that raw channel text stops here.

You are given, per channel: the channel id, the window's `oldest` and `latest` bounds, and a
page budget.

Prefer the shell path: `$EPIC_WATCH_ROOT/scripts/slack.sh channel-history <channel> <oldest>
<latest> <max-pages>`. It returns `{messages, truncated, oldest_read, newest_read}`.

If it exits **2**, the shell path is not configured on this machine. Load
`slack_read_channel` through `ToolSearch` and use it instead, with `oldest`, `latest`, and
`response_format: detailed` so reactions and thread info come back. Do not fall back to
`curl`: a previous run did and reported an empty channel because the token was unset.

Return exactly this, and nothing else:

```json
{"candidates": [{"channel": "<id>", "ts": "<ts>", "author": "<user id>",
                 "is_bot": true|false, "thread_ts": "<ts>|null",
                 "reactions": ["<name>"], "text": "<verbatim>"}],
 "newest_processed": {"<channel>": "<ts>"},
 "truncated": {"<channel>": true|false},
 "errors": [{"channel": "<id>", "reason": "<what failed>"}]}
```

Rules:

- `text` is verbatim. Do not summarise, translate, or clean it up; the classifier and the
  filed story both depend on the reporter's own words.
- `is_bot` is true when the message has a `bot_id`, or no `user`, or an app author. The
  classifier ignores bot traffic, and a channel with a daily digest would otherwise produce
  a story a day.
- Candidates are ordered **oldest first**, which takes an explicit sort by numeric `ts`
  ascending: `channel-history` and `slack_read_channel` both return newest-first. This is not
  cosmetic. The caller advances the watermark to the newest ts it handled, so emitting
  newest-first in a truncated window advances past older messages nobody read, and they are
  below the clamp from then on.
- `newest_processed` is the newest ts you actually read, not wall clock.
- If a channel errors, omit it from `newest_processed` and add an entry to `errors`. Keep it
  inside the JSON: prose before the object would make the whole response unparseable, and the
  caller reads `newest_processed` and `truncated` out of it. Never invent a ts.
