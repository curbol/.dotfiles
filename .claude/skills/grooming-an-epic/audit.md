# Auditing an epic

One question for every open story: is it needed in the epic's end state? The audit catches
stories and PRs built on a premise that has since changed. Run it when asked, or when a
change reaches the epic's core premise.

## 1. Write down the end state

From the epic description and its design doc, write `<dir>/END_STATE.md`:

- the system when the epic is done: what installs, stores, reads and renews what
- the decisions in force, and the stories closed because of them
- the ordering rules
- known, accepted caveats
- what is out of scope, and where it lives
- links to the design docs

Stories are judged against this, never against their own text. If writing it turns up a
contradiction between the epic and the design doc, resolve that with the person first.

## 2. Snapshot and batch

Snapshot every open story in the epic (`sc.py snapshot <dir> <ids...>`), leaving out
Completed and Won't Fix. Split them into batches of about ten by area, so each reviewer holds
one part of the system in its head.

## 3. Review, read-only

Give each batch to a subagent with the brief below, filled in. The subagents write findings
to files and never write to Shortcut, GitHub, Notion or a repo.

````markdown
# Audit: is every story in this batch needed in the end state?

The failure being prevented: a story or PR whose "why" rests on a premise that has since
changed, so it gets built although the end state no longer needs it.

Read `END_STATE.md` first. Your batch: <ids>. Each `story-<id>.json` in <dir> is the full
story: description, comments oldest first, links.

For each story:
1. State its premise in one or two sentences: the problem it exists to solve, in terms of the
   end state.
2. Verify that premise independently. Don't trust the story's own text. Where the premise
   is about code, read the code on the default branch (`git grep` / `git show
   origin/<default>:<path>`; never checkout or modify). Where it is about a decision, check it
   against END_STATE.md and the story's latest comments. Read every story it depends on or is
   blocked by, and check that it's still open and still means the same thing.
3. Give one verdict:
   - NEEDED: required for the end state, as scoped.
   - NEEDED, RESCOPE: required, but its scope or dependencies are wrong. Say exactly what
     changes.
   - NOT NEEDED FOR DEADLINE: valid, but not required by the epic. Say where it belongs.
   - NOT NEEDED: the end state doesn't need it. Say why.
   - DUPLICATE: covered by another story. Say which one, and what overlaps.
   - DONE PENDING VERIFICATION: its code is merged. Say whether any step remains.
   - UNCLEAR: say what single fact would decide it.
4. Give evidence: file:line, PR number, story or comment ID. Every verdict other than NEEDED
   needs it.
5. Note a gap (something the end state needs that no story covers) only if one is obvious.

Be skeptical in both directions: old doesn't mean unneeded, and a confident description
doesn't mean needed. Read-only. Write `result_<batch>.md`, one section per story (Premise,
Check, Verdict, Evidence), and return a table of id, verdict and one-line reason.
````

## 4. Check before acting

Read every result. Verify in code yourself any claim that would change the plan rather than
the wording: a new ordering constraint, a mechanism that doesn't work the way the epic
assumes, a population count. Watch for stories in Ready for Test with none of their work on
the default branch. PR automation puts them there (see SKILL.md, Correct states).

## 5. Apply

In this order, so later steps see earlier ones:

1. Closures (Won't Fix with the reason), completions, moves out of the epic, and state
   resets, each with a comment.
2. New stories for real gaps.
3. Links: remove the stale ones, add the real blockers.
4. Rescoped descriptions. Snapshot again, then give the drafting to subagents with the brief
   below. Review each draft, and apply it with `sc.py apply`.
5. The epic description and the design doc.

````markdown
# Rescope these story descriptions

Apply the audit's RESCOPE items for your stories (`result_*.md` in <dir>), plus these
decisions: <decisions made while checking, and new story IDs to reference>.

For each story, read `story-<id>.json`. Write the complete new description to
`story-<id>.new.md`, and 2-5 lines to `story-<id>.note.md`: what changed, and any audit item
you didn't apply, with the reason. Follow rewriting.md. Keep every still-current fact; this
is a rescope, not a summary. Don't invent anything. Read-only everywhere.
````

## 6. Report

Counts by verdict, then the findings that change the plan (not just wording), each with its
evidence, then the decisions for the person, each with a recommendation.
