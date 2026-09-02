# epic-watch

Keeps a Shortcut epic curated on a schedule. You point a watcher at an epic, some Slack
channels, some repos, and some Notion pages, and it notices the things that otherwise rot:
bugs reported in Slack that never get filed, stories that go stale as related work ships,
and setup docs that stop mentioning what shipped last month.

**What this version does:** the intake lane. A watcher reads its watched Slack channels,
classifies what it finds, and files genuine bug and feature reports into the epic, replying
in-thread with the story link. Borderline messages get one question in the thread instead of a
story. The groom and docs lanes described in `design.md` are not built.

## Install

`setup.sh` symlinks the skill, its three commands, and its three subagents into both
`~/.claude` and `~/.claude-work`. Nothing else is needed:

```bash
sh ~/code/.dotfiles/setup.sh
```

Then create a watcher. The command asks for anything you do not supply:

```
/epic-watch
```

Check on it, and stop it:

```
/epic-watch-status
/epic-watch-stop
```

The scheduler runs the lane through `claude -p`, which loads the skill and the subagents from
the config dir recorded at install time. A scheduled run inherits no environment, so the
launcher at `~/.local/share/epic-watch/bin/epic-watch-launch` rebuilds `PATH`,
`CLAUDE_CONFIG_DIR`, and the skill's location from the watcher's config before calling in.

## Credentials

| Variable | Needed for | If absent |
|---|---|---|
| `SHORTCUT_API_TOKEN` | everything | hard failure; there is no fallback, since both Shortcut MCP servers are unusable here (one deprecated, one interactive-auth) |
| `SLACK_USER_TOKEN` | the shell Slack path | the Slack sources report **degraded** rather than failing, and the lane routes those reads through the Slack MCP connector instead |

Both live in a single 0600 file at `${XDG_CONFIG_HOME:-~/.config}/epic-watch/env`, written
by the setup command. They are deliberately never written into a launchd plist:
`~/Library/LaunchAgents` is plaintext, world-readable by default, and swept into backups.

A Slack user token (`xoxp`) needs `search:read`, `channels:history`, `groups:history`,
`reactions:read`, and `chat:write`. `reactions:read` is not optional: a reaction
on the watcher's own question is the likeliest way a human answers it, and without the scope
that signal is simply absent.

## What a run does

Each fire takes a per-lane lock, records the window it is about to consider, then answers
one question: is there anything to do?

- New messages in a watched channel, measured against `max(watermark, now - lookback)`. The
  clamp is not decoration: a message older than the lookback can never be fetched, so
  comparing against the bare watermark would report work forever.
- An **answered** ask. An unanswered one is never work, or an ignored question would wake a
  model on every quiet run for the rest of time.
- A Shortcut reachability probe, whose only job is proving the scheduled environment has
  the credential. Without it a watcher could soak for a week and tell you nothing about the
  thing most likely to be broken.

When the answer is yes, and only then, it invokes `claude -p` to run the lane. So a quiet
channel costs nothing beyond a couple of API reads.

The lane then fetches candidates in a subagent, classifies them on Haiku, explores each
keeper for context and duplicates, and files. Every filed story carries the Slack permalink
as an external link, which is the deduplication key: a rerun over the same window files
nothing. Filing is one call, and the story is labelled `epic-watch:unreplied` until the
threaded reply lands, so a run that dies between the two is recoverable.

Outcomes land in `journal.ndjson` (append-only) and `health.json`, both under
`${XDG_STATE_HOME:-~/.local/state}/epic-watch/<watcher>/`. Every write cites the source that
justified it; `tests/assert-traceable.sh <watcher>` resolves those citations rather than
counting them, so an invented one fails.

## Verified end to end

Against a scratch epic with a fixture Slack holding three messages (a real bug report, a
bot digest, and "nice, thanks for the update"):

- The bot digest and the chatter were ignored, each with a stated reason in the journal.
- On a report matching an existing story, the lane commented on that story instead of filing
  a second one, having verified the match by reading the story rather than by keyword.
- On a novel report it filed one story into the configured epic and state, with the permalink
  attached, the reporter's own words quoted, and `Unknown:` lines for everything no source
  stated.
- A rerun over the same window was quiet. A rerun with the watermark rewound found the story
  by permalink and skipped, leaving exactly one story in the epic.

## Trying it without writing anything

```bash
scripts/run-lane.sh <watcher> intake --once --dry-run
```

The scripts refuse every write while that is set, so this is enforced rather than requested.
The journal shows what the lane would have filed.

## What it will not do

Move a story between workflow states, edit an existing story's description, touch Notion, file
into any epic but the configured one, or ask twice in one thread. Those are the later lanes,
and the rubric in `skills/watching-an-epic/classification.md` is where the filing bar lives if
you want to tune it.

## Reading health

`last_success` refreshes only when **no** source was degraded, denied, or errored. So a
machine with no Slack token shows runs happening and `last_success` unset, which is the
honest report: something is not configured. A watcher that has quietly done nothing for a
week cannot look healthy.

Three consecutive failures trip a breaker. It **throttles** to one fire in six rather than
halting, so a transient outage heals without you: the first success closes it. `config.sh reset
<watcher> <lane>` exists for when you have fixed the cause yourself.

`launch_failure` comes from the launcher, which runs before any of the skill's own scripts
are reachable. It covers a missing config, an env file whose mode is not 0600, and a
recorded skill root it cannot resolve. Every one of those writes a record and an `ALERT`, because a scheduled fire that
writes nothing is indistinguishable from a healthy quiet run.

## Tests

```bash
tests/run.sh          # offline, hermetic; no credentials, no network, no scheduler
tests/run-platform.sh # drives launchctl/systemctl and plutil; installs and removes real units
tests/run-live.sh     # needs SHORTCUT_API_TOKEN; talks to Shortcut
```

The offline suite drives the real `curl` paths against a local fixture server, so status-code
mapping and cursor paging are covered without a credential or the network. It also asserts
that every component has frontmatter and that the commands and subagents are where the skill
expects them, because a component the loader skips produces no error at all: the lane simply
cannot do that step.

There is no CI here, so run all three yourself when you touch a template, a client, or a
command.

## Platform notes

Scripts target `/bin/bash` 3.2, which is what macOS ships and what a launchd job gets.

Several things differ between macOS and the Linux CI runner, and each one is a place where a
green CI can hide a broken target (or the reverse). The ones handled so far: `flock`, absent
on macOS, so locking is an atomic `mkdir`; `date -v` versus `date -d`, each rejected by the
other platform, so durations are `date +%s` plus integer arithmetic; and `stat`, where GNU
reads `-f` as `--file-system` and prints a filesystem dump to stdout before failing, so the
GNU form is always tried first. Treat this as a list of the ones found, not a closed set:
when you add a system call, check both platforms.
