# Commands, shapes, and the facts behind them

Every script is in `$EPIC_WATCH_ROOT/scripts/`. All of them share one exit contract:
**0** ok, **1** usage, **2** configuration absent, **3** upstream API error,
**4** credential rejected.

`shortcut.sh` exit 2 is a hard failure: there is no Shortcut MCP to fall back to.
`slack.sh` exit 2 means the shell path was never configured on this machine, and your
instruction in that case is to use the Slack MCP tools instead.

## Shortcut

```
shortcut.sh epic <id>                      # cheap; the credential probe
shortcut.sh story <id>
shortcut.sh story-by-external-link <url>   # 200 [] means not filed; any error means DO NOT file
shortcut.sh search-stories "<query>" [n]   # results under .data[]; scope with epic:<id>
shortcut.sh create-story '<json>'
shortcut.sh update-story <id> '<json>'     # labels is a REPLACEMENT array
shortcut.sh comment <id> "<text>"
```

Route facts, each verified rather than assumed:

- The dedup route is `external-link/stories`, **singular**. The plural spelling 404s.
- A URL with no story returns `200 []`. Absence is an empty array, not a 404, which is what
  lets you fail closed: file only on a 200 whose body is empty.
- There is **no external-links sub-resource**. `external_links` and `labels` are story
  fields, so filing is one `create-story` call. Create-then-attach would leave a window in
  which the dedup key does not exist and the next run files a duplicate.
- `epic-stories` is 187KB for a real epic. Never call it. Use `search-stories`.

A filing body:

```json
{"name": "<title>", "story_type": "bug", "epic_id": <epic>,
 "group_id": "<team>", "workflow_state_id": <intake_state.workflow_state_id>,
 "external_links": ["<canonical permalink>"],
 "labels": [{"name": "epic-watch"}, {"name": "epic-watch:unreplied"}],
 "description": "<traced description>"}
```

`epic_id` is load-bearing and easy to forget: only `name` is required by the API, so a body
without it returns 201 and files the story **outside** the watched epic.

## Slack

```
slack.sh permalink <workspace> <channel> <ts>     # pure construction, no API call
slack.sh latest-ts <channel>
slack.sh channel-history <channel> <oldest> <latest> [max-pages]
slack.sh thread-replies <channel> <ts>            # paged; includes the parent
slack.sh reactions <channel> <ts>
slack.sh search-messages "<query>" [channel-name] # channel NAME, not an ID
slack.sh post-thread-reply <channel> <thread-ts> "<text>"
slack.sh auth-test
```

- **No read path returns a permalink**, so it is constructed:
  `https://<workspace>.slack.com/archives/<CHANNEL>/p<ts with the dot removed>`. Always via
  `slack.sh permalink`, never by hand, because it is the dedup key.
- History is **newest-first**. A truncated walk has read the newest part of the window and
  left older messages unread.
- `channel-history` returns one envelope: `{messages, truncated, oldest_read, newest_read}`.
- `search-messages` scopes by channel **name**; an ID in an `in:` filter matches nothing.

MCP equivalents when `slack.sh` exits 2: `slack_read_channel` (accepts `oldest`, `latest`,
`limit`, `cursor`; `detailed` includes reactions), `slack_read_thread`, `slack_get_reactions`,
`slack_send_message` with a `thread_ts`. Load them through `ToolSearch` first. Server names
differ between contexts, so search for the tool rather than assuming a prefix.

## State

```
config.sh show <watcher>
config.sh journal <watcher> '<json>'
config.sh ask-set <watcher> "<channel>:<message_ts>" '<json>'
config.sh ask-list <watcher> [status]
```

A journal record:

```json
{"ts": <epoch>, "run_id": "<from $EPIC_WATCH_RUN_ID>", "watcher": "<name>",
 "lane": "intake", "action": "filed|asked|commented|skipped_cap",
 "target": "<story id or channel:ts>",
 "sources": [{"kind": "slack_message|file|story|notion_page", "ref": "<permalink|file:line|id>",
              "origin": "window|exploration"}],
 "detail": null}
```

`origin` matters: `window` means you read it inside this run's own fetch window, and the
traceability checker requires such a citation to fall inside that window. `exploration`
means the explorer found it elsewhere, which is expected to be outside the window.

An ask registry entry:

```json
{"asked_at": <epoch>, "ask_ts": "<ts of YOUR question message>",
 "reaction_baseline": ["<names on the reported message when you asked>"],
 "status": "pending", "story_id": null}
```

The key is `<channel>:<reported message ts>`, never the thread ts, which is null for a
top-level message.

## The result line

Exactly one line, last thing you output:

```
EPICWATCH_RESULT {"watcher":"<name>","lane":"intake","sources":{"intake/<channel>":{"status":"ok|partial|denied|error","newest_processed":"<ts>","processed":<n>}},"actions":{"filed":<n>,"asked":<n>,"commented":<n>,"skipped":<n>},"asks":[{"channel":"<id>","thread_ts":"<ts>","ask_ts":"<ts>","action":"asked","story_id":null,"reaction_baseline":[]}]}
```

- Source keys are `<lane>/<source>`, where a Slack source is its **channel ID**, never a name.
  A key the config does not contain fails the run.
- `newest_processed` is the newest ts you actually handled. The watermark advances to it and
  no further, so consume candidates oldest-first.
- `status: "partial"` means the window held more than you took. It still needs
  `newest_processed`.
- `actions` counts must match the journal records you wrote for this `run_id`; the wrapper
  compares them and fails the run on a mismatch.
