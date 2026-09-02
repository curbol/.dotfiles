---
description: Create or reconfigure an epic-watch watcher and schedule it
---

The scripts live in this skill's directory. Resolve it once per session:

```bash
EW="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/watching-an-epic"
```

# Create an epic-watch watcher

Set up a named watcher over a Shortcut epic. Several watchers coexist on one machine, one
per epic, sharing no state.

Ask for anything the user did not supply. Do not guess any of it.

| Field | How to get it |
|---|---|
| watcher name | short kebab-case, unique on this machine; `$EW/scripts/config.sh list` shows the existing ones |
| epic | numeric Shortcut epic id |
| team | Shortcut team (group) id that new stories will belong to |
| intake state | the workflow and state new stories land in; `$EW/scripts/shortcut.sh workflow-states <workflow-id>` lists them |
| Slack channels | channel **IDs** (`C…`), not names |
| repos | absolute paths to local checkouts, for later stages; may be empty |
| doc surfaces | path-glob to Notion page mappings, for later stages; may be empty |
| lanes | which lanes run and how often; this version implements `intake` only, so `{"intake": "hourly"}` unless the user wants a different cadence |

Derive rather than ask, in this order:

1. `$EW/scripts/slack.sh auth-test` gives `workspace` and `self_id` when `SLACK_USER_TOKEN` is
   set. Prefer this.
2. If it is not set, read the workspace and the user's own Slack member id through the
   Slack MCP tools available in this session.
3. Only if neither works, ask, and tell the user the values are unverified.

Both are required. `slack_workspace` builds the permalink that deduplicates stories, and
`slack_self_id` is what tells the watcher's own question apart from a human's reply.

Then:

```bash
$EW/scripts/config.sh init <name> "$CONFIG_JSON" "$ENV_JSON"
$EW/scripts/install-schedule.sh --install <name>
```

Record an absolute path to `claude` if it is a version-manager shim. A shim resolves its own
configuration through `XDG_CONFIG_HOME`, which a scheduled run repoints at its own state,
so the shim can fail in a scheduled run while working perfectly in your shell:

```bash
$EW/scripts/config.sh set-env <name> claude_bin "$(command -v claude)"
```

A Slack user token needs `search:read`, `channels:history`, `groups:history`,
`reactions:read`, and `chat:write`. `chat:write` is only exercised by a real run, so a token
missing it passes the dry run and then fails at the threaded reply, leaving the story it just
filed marked `epic-watch:unreplied` until a later run recovers it.

`ENV_JSON` carries the tokens (`SHORTCUT_API_TOKEN`, and `SLACK_USER_TOKEN` if there is
one). They go into a 0600 env file, never into a scheduler entry: `~/Library/LaunchAgents`
is plaintext and gets backed up.

Only lanes this version implements are scheduled. Report which lanes were skipped.

Finish by running the lane once, **in dry-run first**, so the user sees what it would do
before it does anything:

```bash
$EW/scripts/run-lane.sh <name> intake --once --dry-run
$EW/scripts/config.sh health-get <name>
```

Show them the journal entries it produced and what it would have filed. Then, once they are
happy with the classification, run it for real:

```bash
$EW/scripts/run-lane.sh <name> intake --once
```

If the classification is wrong for their channel, the bar lives in
`skills/watching-an-epic/classification.md` and is meant to be edited.
