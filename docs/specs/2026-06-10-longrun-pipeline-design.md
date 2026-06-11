# Longrun: Long-Leash Autonomous Pipeline

Working name: `/longrun`. Design for a Claude Code skill that runs a full
problem-to-verified-implementation pipeline autonomously for hours at a time.

## Goal

Decouple capacity from productivity. Today a session needs human input every
1-20 minutes; with several parallel sessions that cadence makes the human the
bottleneck. Longrun front-loads all human input into a kickoff phase, then runs
autonomously for 1-4+ hours (overnight is possible but incidental), producing
output that is cheap to review and cheap to correct.

The hypothesis under test: it is faster overall to let the AI build on
documented assumptions and verify afterward than to stay closely involved
throughout. Wrong assumptions are acceptable if they are easy to find and fix.

Pilot runs are documented (loop statistics land in each run's report) so
results can be shared with the team.

## Form factor

A skill in this repo at `.claude/skills/longrun/`, symlinked into
`~/.claude/skills/` and `~/.claude-work/skills/` by `setup.sh` (the per-file
symlink list needs a directory entry added). Once stable, promote to a plugin
in `gladly-claude-tools` for team distribution; the skill uses only portable
primitives (subagents via the Agent tool, markdown reference files), so
promotion is packaging, not rework.

```
.claude/skills/longrun/
├── SKILL.md             orchestration: phases, loop mechanics, exit criteria
├── rubric.md            significance rubric (reviewer and adjudicator only)
├── principles.md        correctness principles (author and implementer only)
└── report-template.md   REPORT.md structure
```

The two rubric files encode opposing biases and are deliberately role-scoped:

- `principles.md` (author/implementer): always do what is most correct.
  "Simple now, better later" reasoning is banned; later never comes, and
  whatever gets written becomes the next session's definition of the right
  way. If something can be made more generic at low cost, do it. This file
  never reaches reviewers.
- `rubric.md` (reviewer/adjudicator): defines significance (below) and holds
  the over-engineering filter: findings demanding genericity that is costly
  and not currently needed are not significant. This file never reaches the
  implementer, so it cannot become a scope-cutting excuse.

## Pipeline

Phases 1-2 are interactive; everything after is autonomous.

1. **Clarify.** Take the problem statement and use-cases. Ask clarifying
   questions immediately, scaled to how ambiguous the prompt is. Write
   `BRIEF.md`.
2. **Preflight.** Verify the leash will hold while the human is still
   present: permission mode will not prompt mid-run; each MCP server the
   brief needs answers a cheap read call; tilt is up if QA needs it; a
   dedicated git worktree exists for the run. Exercise the risky operations
   once now so failures happen at kickoff, not at 1am.
3. **Explore.** Repos, Slack, Notion, Gong, whatever the brief calls for.
   Write `CONTEXT.md`.
4. **Plan + review loop.** Author drafts `PLAN.md`, then the loop below runs
   until it exits. The plan must declare a verification mechanism per
   deliverable (unit tests, tsc/lint, tilt + curl, Playwright where
   feasible) and prefer machine-verifiable designs.
5. **Implement.** Derive an explicit task checklist from the plan and work
   through it with small, narrative commits. Questions that arise are parked
   (see FOLLOWUPS.md), never blocking.
6. **Completeness loop.** Fresh auditor compares the diff against `PLAN.md`
   item by item and produces a done/partial/missing table with file:line
   evidence. Author fixes gaps. Repeat until the table is clean, capped at 5
   rounds.
7. **QA loop.** Execute the verification mechanism declared for each
   deliverable. Fix, retest. Exit when clean, or after 2 consecutive rounds
   with no progress, or at 10 rounds. Unresolved issues become known-issues
   entries in the report.
8. **Report.** Synthesize `REPORT.md` from the run directory.

## Run directory

Lives at `.longrun/` in the worktree, committed on the branch. Whether it
survives to merge is decided at merge time. Every file is honest current
state, safe for any subagent to read.

```
.longrun/
├── BRIEF.md       what was asked: problem, use-cases, clarifying Q&A
├── CONTEXT.md     what was learned: exploration findings
├── PLAN.md        what it intends to do (living document)
├── FOLLOWUPS.md   what it wants to discuss (living notebook, sections below)
└── REPORT.md      what happened
```

`FOLLOWUPS.md` sections:

- **Open questions**: things only the human can answer. When one is parked,
  the author makes a documented assumption and proceeds; the question is also
  emitted as a visible session message so the human can course-correct
  opportunistically if watching (terminal or remote control). Load-bearing
  assumptions (expensive to reverse) additionally trigger a push notification
  where the harness supports it.
- **Contested calls**: flip-flop areas (see review loop), with the call made
  and the positions considered.
- **Assumptions and decisions**: choice, rationale, cost to reverse.
- **Nits**: sub-significant review findings. The implementer skims this
  section for cheap wins during phase 5.

## Plan review loop

Three roles, strictly separated:

- **Author** (the main session) writes and revises the plan. It never decides
  significance and never decides termination.
- **Reviewer**: a fresh subagent each round with a rotating lens:
  requirements coverage → codebase feasibility → simplicity/over-engineering
  → failure modes → repeat. Reviewers receive the brief, context, plan, and
  `rubric.md`. They report **everything** they find but must tag each finding
  significant or nit, and must answer one operational test per finding: what
  would it cost to fix this at code stage instead of plan stage? High
  deferral cost makes it significant; low makes it a nit.
- **Adjudicator**: a fresh subagent each round. Receives `rubric.md`, the
  findings, and relevant plan excerpts; does not receive the round number or
  the author's conversation. Answers one question per finding: is this worth
  addressing in the plan?

**Significance** (in `rubric.md`): acting on the finding would change an
interface or data shape, add or remove a deliverable, change the verification
strategy, or invalidate an assumption the plan depends on. Explicitly not
significant: asking the plan to state what the codebase already implies,
specificity the implementer can decide, style, and genericity that is costly
and not currently needed.

**Each round:** reviewer reports → adjudicator triages → author applies
accepted findings, files nits, and updates the plan.

**Termination:** the loop exits the first round the adjudicator accepts zero
findings. Hard cap at 15 rounds; if the cap fires while findings are still
material, the report says so and flags it as a decomposition signal: a plan
still churning at the cap is usually two plans.

**Disputes:** if the author believes an accepted finding is factually wrong,
it investigates against the codebase, records the evidence in `FOLLOWUPS.md`
(contested calls), and skips it. Reviewers are blind to history, so the same
finding may recur; the author rebuts again from context. Recurrence is
bounded by the round cap.

**Flip-flops:** the author is the only participant with round history (its
own context). When a round's feedback reverses or re-litigates something an
earlier round changed, that is a flip-flop: a genuine gray area, not a
mistake. Decisions are sticky unless feedback brings new evidence or
argument. The author makes the most-correct call it can, records the area and
positions under contested calls, and stops oscillating.

## Report

Ordered for fast re-entry, structure in `report-template.md`:

1. TL;DR with honest status: complete, partial, or blocked.
2. Load-bearing assumptions, first because they gate everything else.
3. Coverage table from the completeness loop.
4. Notable design choices and contested calls.
5. Open questions.
6. Known issues and QA results.
7. Suggested review order through the commits.
8. Loop statistics (rounds per loop, findings accepted/rejected, caps hit)
   for trial documentation.

## Parallelism and recovery

One run per session per worktree; parallel runs are just parallel sessions.
A crashed or interrupted run resumes by re-entering the pipeline against the
existing run directory: every phase grounds itself in the files, not in
conversation memory. Re-running a single phase (replan, re-QA) works the same
way.

## Open experiments

Settled empirically over pilot runs, using report loop statistics:

- Adjudicator subagent vs. main-session triage of findings.
- The lens set and rotation order.
- Cap values (15/5/10) and the one-clean-round exit.
- Whether the report alone makes re-entry fast enough, or an interactive
  debrief mode earns its place.

## Success criteria for pilots

- Sessions run for 1+ hours without needing human input.
- Re-entry (reading the report, deciding keep/redo) costs a small fraction
  of the run length.
- The keep ratio: how much of a run's output survives human review without
  redo. Track per run; rising keep ratio means the rubrics are working.
