# epic-watch: scheduled Shortcut epic curation

Design doc for `epic-watch`. Supports [sc-256601].

Written when this was built as a plugin under `sagansystems/gladly-claude-tools`. It now
ships as a personal skill in the dotfiles repo; the layout below reflects the original, and
the rest, including the groom and docs lanes that are still unbuilt, stands as written.

## Problem

A Shortcut epic decays in three ways at once. Bugs and feature requests get
reported in Slack and never filed. Stories that were accurate when written go
stale as related work ships, especially downstream stories nobody reopens.
Documentation that describes how to set something up stops mentioning the
capability that shipped last month.

All three are noticing problems, not doing problems, and noticing is what a
scheduled agent is good at. This plugin gives an engineer a watcher they point
at an epic, a set of Slack channels, a set of repos, and a set of Notion
pages, and it keeps the epic honest without being asked.

## Non-goals

Not a Slack bot: it polls on a schedule and owns no socket, no webhook, and no
hosted app. Not a planning tool: it does not estimate, prioritize, or assign,
and the only workflow transitions it makes are the two corrections described
in Groom. Not a reporter: a run that finds nothing produces no
Slack message, no comment, and no summary.

## Constraints established by spike

These were measured on 2026-08-20 against Claude Code 2.1.237 on macOS, not
assumed. Each one invalidates an obvious implementation, so they are recorded
with their evidence.

**MCP servers connect asynchronously, and turn one often has none.** A
headless run asked to list its `mcp__` tools answered that it had none and
that Notion, Slack, context7, playwright, and shortcut were "still
connecting". In an earlier run, a model told to call the Slack tool instead
fell back to `curl https://slack.com/api/search.channels` with an unset
`$SLACK_BOT_TOKEN`, which fails in a way that looks like an empty channel.
Every run must reach its MCP tools through `ToolSearch`, which waits for
connecting servers, and must be told never to substitute Bash for a missing
tool.

**Slack resolves to a different server headless than interactively.**
`claude mcp list` shows `plugin:slack:slack` at `https://mcp.slack.com/mcp`.
The same machine running `claude -p` resolved the tool as
`mcp__claude_ai_Slack__slack_search_channels`. An `--allowedTools` rule naming
only `mcp__plugin_slack_slack` denied the call. Permission rules must cover
both prefixes, and no prompt or script may hardcode one server name.

**A headless permission denial is not an error.** The denied run returned
`is_error: false`, an empty `result`, and a `permission_denials` entry, and the
model's reply was the sentence "The tool ... requires permission to use."
Nothing about the process exit or the JSON envelope distinguishes it from a
run that correctly found nothing to do. A watcher that cannot write will look
like a quiet epic for as long as nobody checks.

**Shortcut is fully reachable from the shell.** `GET /api/v3/epics/249969/stories`
with a `Shortcut-Token` header returned 200 and 123 stories in 186,725 bytes,
including `updated_at`, `labels`, `external_links`, `story_links`, and
`workflow_state_id`. Every fetch and diff the watcher needs on the Shortcut
side is therefore a `curl` and a `jq` away, and the model never has to read a
story list to find out what changed. `short` is not installed and is not a
dependency.

## Architecture

### Layout

```
plugins/epic-watch/
├── commands/
│   ├── epic-watch.md          # create or reconfigure a watcher
│   ├── epic-watch-status.md   # per-watcher, per-lane health
│   └── epic-watch-stop.md     # unschedule, keep state
├── skills/
│   └── watching-an-epic/
│       ├── SKILL.md           # lane logic, invoked by a run or by hand
│       ├── classification.md  # the file / ask / ignore rubric
│       └── reference.md       # REST recipes, jq filters, tool names
└── scripts/
    ├── run-lane.sh            # wrapper: precheck, invoke, verify, journal
    ├── shortcut.sh            # curl + jq helpers
    ├── install-schedule.sh    # launchd or systemd entry generation
    └── templates/
        ├── launchd.plist.tmpl
        └── systemd.timer.tmpl
```

The skill is the deliverable, not the schedule. Running
`/epic-watch:watching-an-epic groom` by hand in an interactive session does
the same work as the scheduled run, which is how the logic gets tested and how
someone without a scheduler still gets value.

### Watchers are named

Several watchers coexist on one machine, one per epic, with no shared state.

```
${XDG_CONFIG_HOME:-$HOME/.config}/epic-watch/<name>/config.json
${XDG_STATE_HOME:-$HOME/.local/state}/epic-watch/<name>/watermarks.json
${XDG_STATE_HOME:-$HOME/.local/state}/epic-watch/<name>/journal.ndjson
${XDG_STATE_HOME:-$HOME/.local/state}/epic-watch/<name>/health.json
```

`config.json`:

```json
{
  "name": "sunco-standalone",
  "epic": 249969,
  "team": "69949769-1bb1-4ded-b7ff-3fa8df4fa57f",
  "intake_state": { "name": "Unprioritized", "workflow_state_id": 500000038 },
  "slack_channels": ["C0123ABCD"],
  "repos": ["/Users/curtis/code/glados"],
  "doc_surfaces": [
    { "paths": ["services/sunco/**"], "notion_page": "<page-id>" }
  ],
  "docs_major": { "min_estimate": 3, "labels": ["enhancement"] },
  "lanes": { "intake": "hourly", "groom": "daily", "docs": "weekly" }
}
```

`intake_state` stores the resolved `workflow_state_id` alongside the name
because state names are not unique across workflows; the name is kept only so
a human reading the config can tell what it points at. Lane cadences are
aliases that `install-schedule.sh` translates to concrete times, choosing an
off-peak minute rather than the top of the hour so a team installing the same
watcher does not synchronize its API load.

`watermarks.json` holds the last processed Slack timestamp per channel, the
last commit SHA per repo, and the last `updated_at` seen on the epic. It is a
cache, not a ledger: deleting it causes redundant work, never duplicate
stories, because deduplication is Shortcut-side (see Intake).

`journal.ndjson` is append-only, one object per action taken, with the lane,
the target, what changed, and the source that justified it. It is how a human
audits a week of autonomous edits in one `jq` pass.

### Install and scheduling

`/epic-watch` collects epic, channels, repos, and doc surfaces, asking for
whatever was not supplied, writes `config.json`, then generates one scheduler
entry per enabled lane: `com.gladly.epic-watch.<name>.<lane>` for launchd,
`epic-watch@<name>-<lane>.timer` for systemd. Each entry runs
`run-lane.sh <name> <lane>`.

`run-lane.sh` is the part that must not need a model:

1. Read config and watermarks.
2. Run the lane's shell precheck. For `groom` and `docs` this is a `curl` plus
   `jq` against Shortcut and a `git log` per repo. If nothing changed, append a
   journal line and exit, having spent zero model tokens.
3. Otherwise invoke `claude -p` with the lane prompt, an explicit
   `--allowedTools` list covering both Slack server prefixes, a `--model`
   appropriate to the lane, `--max-turns`, and `--output-format json`.
4. Parse the run's machine-readable result line. Update watermarks only for
   the sources the run reports as successfully processed.
5. Append to the journal, update `health.json`.

Watermarks advance per source, not per run, so a run where Slack succeeded and
Notion was denied does not skip the Notion work forever.

## Lane: intake

Default hourly. Purpose: nothing reported in a watched channel goes unfiled,
and nothing unreported gets invented.

### Fetch

For each channel, read messages newer than that channel's watermark. This runs
in a subagent that returns a compact candidate list, so raw channel text never
enters the run's context.

### Classify

Full rubric in `classification.md`. Three buckets, and the bar is the shape of
the message, not a keyword.

**File** when the message is a first-person report of a defect or a request
for a capability, names a concrete subject, and carries enough detail to write
a title plus either a repro or an ask. Openers like "bug:", "new feature:",
"X is broken when Y", or "can we add" are strong signal and neither required
nor sufficient on their own.

**Ask** when it reads like a report but is missing what makes it actionable,
or when it is genuinely unclear whether the person is reporting a problem or
asking about intended behavior. One threaded reply, once ever per thread,
naming the epic and asking whether to file. The next intake run looks for a
yes or a 👍 in that thread and files then. Recorded in state so a declined or
ignored question is never asked twice.

**Ignore** everything else: questions already answered in-thread, opinions,
status chatter, links with no claim attached.

### Explore before writing

A story written from one Slack message is usually wrong in the ways that
matter. Before filing, each candidate in the File bucket gets one bounded
exploration pass, in a subagent with a turn cap, across four sources:

- Shortcut, for a semantic duplicate. Search the epic and the team for stories
  covering the same behavior, not just the same words. A hit means comment on
  the existing story with the new thread instead of filing.
- The configured repos, for where the reported behavior actually lives. A file
  path and a function name in the story is the difference between a triageable
  bug and a shrug.
- Slack, for earlier threads on the same symptom, which frequently carry the
  repro the new message lacks.
- Notion, for whether documented behavior matches what the reporter expected,
  which distinguishes a bug from a documentation gap.

Exploration adds context to the story. It never adds claims: see
Anti-invention.

### File

Deduplicate first: `stories-get-by-external-link` on the Slack permalink. If
absent, create the story in the configured `intake_state`, attach the
permalink with `stories-add-external-link`, apply an `epic-watch` label, and
reply in the thread with the story link. The permalink is the deduplication
key rather than a local file, so a wiped state directory cannot cause a
duplicate and two teammates watching the same channel cannot double-file.

The threaded reply is load-bearing rather than courtesy: it is the correction
channel. The person who reported the thing sees what was filed, in the place
they reported it, and can say so if it is wrong.

## Lane: groom

Default daily. Two jobs.

**Enrich.** For each story with a Slack permalink in `external_links`, check
whether its thread gained substantive detail since the watermark. Substantive
means a repro, an affected org, a severity observation, or a decision. Append
it as a comment quoting the new material with a link, never a silent
description rewrite.

**Re-check what shipped.** The stale story is rarely the one being worked; it
is the story related to it. For every story that reached a done state since
the last run, walk `story_links` to its related and downstream stories, and
compare each one's description against what actually shipped, using the
merged work in the configured repos and the resolution of the story that
moved.

Narrow factual drift is corrected in place: a renamed flag, a moved endpoint,
a dependency the description calls pending that is now in place. Anything
broader gets a comment naming what changed and which part of the description
it contradicts, because a description rewrite that guesses at intent is worse
than a description that is visibly out of date.

**Correct the two transitions PR automation cannot see.** Shortcut already
moves a story to In Development when a branch or PR appears and to Ready for
Test when its PR merges. Groom never duplicates those rules. It corrects the
two cases they get wrong:

A story in Ready for Test whose testing is recorded somewhere moves to
Completed. The only acceptable evidence is an explicit statement that it was
verified, in a story comment, a linked Slack thread, or a PR comment, naming
what was tested and where. Absence of evidence is not evidence: a story nobody
has mentioned stays in Ready for Test indefinitely, which is the correct
outcome, and "the PR merged" is the fact that already put it there rather than
a reason to advance it.

A story moved to Ready for Test by one merged PR, while other PRs for the same
story are still open, moves back to In Development. Evidence is an open PR
whose branch carries the story ID or whose body references it, read with `gh`
in the configured repos.

Both transitions are journaled with the evidence that justified them, and no
other transition is ever made.

## Lane: docs

Default weekly, and deliberately the narrowest lane. It considers a Notion
page only when the epic completed something `docs_major` marks as such: a
story carrying one of its `labels`, or estimated at `min_estimate` or above,
or touching a `doc_surfaces` path glob. Small fixes never reach this lane.

For a page that qualifies, the question is whether it now describes the system
incorrectly, not whether it could be improved.

**Clear drift is rewritten.** The page says a setup step is required that the
shipped work removed; the page enumerates supported options and a new one is
missing; the page names a flag or endpoint that was renamed. The edit is
confined to the affected prose, the before and after go in the journal, and
Notion page history makes it revertable.

**Ambiguous drift is asked about, not guessed at.** When the page is merely
thin, or when correcting it requires deciding what the intended behavior is,
the lane posts a Notion comment on the specific block describing the suspected
drift, plus one line in the first configured Slack channel so the question
does not rot unseen in Notion.

Pages are edited only if listed in `doc_surfaces`. The lane never discovers a
page to edit on its own, so the blast radius is exactly what the installer
opted into.

## Anti-invention

The hard constraint across every lane, stated in the skill in these terms:
every field written to Shortcut or Notion must be traceable to a specific
source the run actually read, and the journal records which one.

No inferred severity. No reconstructed repro steps. No guessed customer, org,
or environment. No "presumably" or "likely" in a story description. Where a
field would be useful and the sources do not supply it, the story says
`Unknown: <what is missing>`, which is a better prompt for the reporter than a
confident wrong answer. Exploration widens the set of things the watcher may
cite; it never lowers this bar.

## Cost model

Five levers, in descending order of effect.

Lanes run on different cadences, so the expensive reasoning is not paid
hourly. The shell does all Shortcut and git fetching and diffing, so the model
never reads a raw API response; the measured epic is 187KB of JSON that `jq`
reduces to a handful of changed stories. Groom and docs exit in the wrapper
before any model tokens when the precheck finds nothing new. Intake cannot
precheck Slack from the shell, so it runs a cheap classifier first and only
escalates to a stronger model when there are candidates to write up. Raw Slack
reads and per-candidate exploration happen in subagents whose output is a
digest, so the run's own context stays small.

`--max-turns` caps every lane so a confused run cannot spiral, and a run that
finds nothing writes only a journal line.

## Failure visibility

Because a denial is not an error, each lane's prompt ends by emitting one line
of the form `EPICWATCH_RESULT {json}` reporting per-source status and per-lane
counts. `run-lane.sh` treats a missing or unparseable line as a failed run,
regardless of exit code, and records it in `health.json` with the denial list
from the run's JSON envelope. Three consecutive failures for a lane cause the
wrapper to say so once, and to stop advancing that lane's watermarks.

`/epic-watch:status` reads every watcher's `health.json` and prints last
success per lane, consecutive failure count, and the last error, so a watcher
that has silently done nothing for a week is visible in one command.

## Testing

The shell layer is testable without a model: `shortcut.sh` helpers and the
lane prechecks get fixture-driven tests using recorded API responses, covering
the empty-diff early exit, watermark advancement per source, and treating a
missing result line as failure.

The classification rubric gets a fixture set of real channel messages labeled
File, Ask, or Ignore, run through the classifier prompt. This is the part most
likely to regress when the rubric is edited, and the part where a regression
is most expensive, since it files noise into a team's epic.

End to end, a watcher is pointed at a scratch epic and a scratch channel, and
the assertions are that a clear report is filed once with a permalink
attached, a rerun files nothing, a borderline message produces exactly one
threaded question, and a denied permission is reported as a failure rather
than a quiet success.

## To verify during implementation

Each item has a defined fallback, so none of them blocks the design.

Whether `claude -p` resolves a plugin skill by slash command. The `--bare`
documentation states skills resolve via `/skill-name`; if a plugin-scoped
skill does not, the wrapper passes the lane instruction as a prompt with
`--append-system-prompt` pointing at the skill file instead.

The exact Slack tool and parameters for reading a channel from a timestamp,
and whether thread replies are reachable in the same call or need a second
one. Affects how many calls the intake fetch costs, not whether it works.

Whether Notion block-level comments are reachable through the connector. If
not, the ambiguous-drift path posts a page-level comment plus the Slack line.

Whether launchd runs a missed interval on wake. If it does not, the wrapper's
watermarks already make a skipped run harmless, and the next run covers the
gap.

## Delivery order

Three stages, each independently useful and independently shippable.

The first stage is the plumbing plus the intake lane: config, install,
`run-lane.sh`, the result-line contract, `/epic-watch:status`, and Slack to
Shortcut filing with exploration and permalink deduplication. This is the
stage that has to be right, because it is the one that writes new things into
a shared epic, and it is worth living with for a week before the others land.

The second stage adds groom, which needs no new plumbing and only reads
sources stage one already reaches.

The third stage adds docs, last because it has the widest blast radius and
because a week of journal entries from the first two stages is the evidence
for whether autonomous editing is behaving.
