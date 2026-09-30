---
name: grooming-an-epic
description: Keeps a Shortcut epic's plan true as the work changes it. When something an epic depends on changes (a decision, a finding, a merged PR, stories closed elsewhere), works out which stories and PRs that affects and updates them; keeps story and epic descriptions as current state; fixes story states PR automation got wrong; audits whether each open story is still needed; lists the epic's PRs waiting on review. Use during work on an epic whenever such a change happens, before editing a Shortcut story or epic description, when asked to audit or clean up an epic, or when asked which of its PRs are waiting on review.
---

# Grooming an epic

The expensive way an epic goes wrong is not stale wording. It is a story or PR still being
built for a reason that stopped being true. Grooming is mostly propagation: when something
changes, work out what it means for the rest of the plan, and update the plan.

It writes to the epic; work-monitor only reads.

## When to act

Whenever the work changes what's true for an epic: something decided, learned, or shipped.
Act in the same turn, without waiting to be asked, and say what you changed.

Changes made outside the session show up only as their aftermath: stories closed or moved by
someone else. `sc.py changed <epic>` lists them since the last groom (`--since <ISO time>`
the first time). Find out why each one moved before propagating it.

## Propagate a change

1. Say what changed, and what it invalidates or makes possible.
2. Find what rested on it: search the epic's open story descriptions, open PR bodies and the
   design doc for it, and follow `sc.py links` from any story that records it.
3. Re-derive each dependent from the current state of things, reading the code where the
   question is about code. Re-derive what each option now costs too; an earlier estimate of
   an option's size goes stale the same way its reasons do.
4. Act: close, rescope, relink or file, each with a comment saying why. Anything that needs
   the person's judgment goes to them with a recommendation.
5. `sc.py changed <epic> --advance` once you're caught up.

When a change is big enough that you can't tell what it touches, audit instead
([audit.md](audit.md)).

## Keep descriptions current

A description says what is true now, not how it got that way. The rules are in
[rewriting.md](rewriting.md). To edit one safely:

1. `sc.py snapshot <dir> <refs...>` into a scratch directory. A ref is a story ID or
   `epic:<id>`.
2. Write the draft to `<dir>/story-<id>.new.md` (or `epic-<id>.new.md`).
3. `sc.py apply <dir> <refs...>`. It refuses any description that changed after its
   snapshot, because someone else may be editing it. Re-snapshot and redo that draft.

## Fix states PR automation got wrong

Shortcut moves a story when a branch or PR mentions it, and it gets three cases wrong:

- A merged PR puts a story in Ready for Test. It moves to Completed only on an explicit record
  that someone verified it.
- A story moved to Ready for Test while its other PRs are still open goes back to In
  Development.
- A story moved by a PR that isn't its work goes back to its previous state. Shortcut links
  every story whose ID appears in a PR's body or comments, even one mentioned as out of scope.
  So never write another story's `sc-` ID in PR text; describe it in words.

## PRs waiting on review

When asked for the epic's PRs waiting on review, run `scripts/pr-digest.sh <epic-id>...` (list
every epic the work spans). It collects a fresh work-monitor snapshot and prints the open,
unapproved, non-draft PRs grouped under their story, with changes-requested ones separate.
Post or draft it only when asked, laid out the way the person wants it.

## Rules

- Every claim traces to something read in this session. Label anything unverified.
- A teammate's view is input to weigh, not proof.
- Subagents gather and verify, read-only. You write, after checking what they found.
- `sc.py --help` lists the Shortcut operations: snapshot, apply, get, comment, state, move,
  links, link, unlink, changed.

## Report

What changed and why, one line each, then the decisions for the person, each with the action
you recommend. Skip stories that needed nothing.
