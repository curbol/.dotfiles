---
name: work-monitor
description: Brief the human on everything in flight across their epics and projects, then stay in the conversation. Use when they invoke /work-monitor, ask what they should be working on, ask for a status briefing, or ask what moved since they last looked.
---

# Work Monitor

A reader. It assembles one briefing across every epic and project in flight so
the human does not have to remember which sources to check.

**Never writes.** No Shortcut stories, no GitHub comments, no Slack messages, no
branch or commit operations. Writing to an epic is `epic-watch`'s job, and one
writer per epic is its invariant. Breaking that here would double-write.

## On invoke

1. Run `scripts/collect.sh` from this skill's directory. It prints the path to
   `state.json`. This costs no tokens, so never skip it to save time and never
   brief from a stale snapshot.
2. Read `state.json`, and `notes.md` beside it.
3. If `.errors` is non-empty, lead with one line naming what could not be read.
   A source that failed must never look like a source that was quiet.
4. Brief, in the format below.
5. Stay in the conversation.

Enrich from MCP only when a server is already connected and it adds something
the snapshot lacks. Never block on MCP and never substitute a shell call for a
tool that failed to connect; note the gap instead.

## Format

Group by epic, largest claim on the human's attention first. Work with no
watched epic goes in a final group.

    AI Vision — 12/27
    - Content warnings: 3 PRs open across the stack, unreviewed since Aug 28
      (glados#9209, supernova#18996, agent-desktop#19820)
    - Phoebe asked for custom-fields copy (sc-257407); glados#9313 up, no review
    - Process Attachment optional context is in Ready for Test

    Express SunCo — 99/119
    - thankful#4550 approved and mergeable, ready to merge
    - Sarah filed two this week: post-handoff fallback never expires, and
      integration coverage for the handoff lifecycle (assigned to you)

    Elsewhere
    - supernova-longrun-appcfg-read left you an open question in DECISIONS.md,
      unanswered since Aug 29

On later runs in the same session, report only what moved since
`state.prev.json`. Never reprint the whole briefing unless asked.

## Concision

The briefing is the product. A long one is a failed one.

- Every bullet must change what the human does next. If it does not, cut it.
- One screen total. If it does not fit, you are including things that do not matter.
- Never enumerate open stories. The recent window is already the filter, and
  `recent_total` tells you when it truncated: say "and 16 more" rather than listing them.
- Collapse related items into one bullet. Three PRs for one story is one bullet.
- Name people who are waiting on something. "Phoebe asked" beats "a request was filed".
- Links inline and sparse. Never a bare list of URLs.
- Say how long something has been stuck when it is stuck. Staleness is the signal.

## Conversation

After briefing, talk normally. Expect plain text, not commands: "I'm on content
warnings today", "what's blocking the SunCo merge", "remind me about Ulta".

When the human says something worth carrying past this session, append it to
`notes.md` as a dated line. Do this silently, without confirming each one, and
without inventing a task format: the file is prose, not a tracker. Carry open
items from `notes.md` into later briefings; drop them once they are clearly done.

## Recurring updates

If the human wants updates on an interval, use `CronCreate` with a prompt that
re-runs this skill. Session-scoped is correct here: the monitor lives in the
session and dies with it, by design. Report deltas only.

## Config

`config.json` sits next to `state.json` under
`${CLAUDE_CONFIG_DIR:-$HOME/.claude}/work-monitor/`, seeded from
`config.example.json` on first run. It lists watched epics, the GitHub search,
and local roots. Adding a source means a config entry plus a collector function,
never a change to this file's shape.
