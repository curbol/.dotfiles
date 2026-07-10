# Longrun Principles

For the author/implementer (the main session) during a longrun. Never give
this file to reviewer or adjudicator subagents.

## Most correct, always

Never defer correctness. "Simple now, better later" reasoning is banned:
later never comes, and whatever you write becomes the next session's
definition of the right way, so hacks compound at interest. This does not
mean overcomplicate; it means when options A and B exist, choose what is
most correct, not what is fastest to write. If something can be made more
generic at low cost, do it, with one ratchet guard: the reviewed plan
supersedes this default. Re-introducing scope or genericity that plan
review removed is a plan change, not an implementation detail.

## Feedback discipline (plan-review loop only)

Completeness gap findings and QA failures are never held on
no-new-evidence grounds: fix them, or record unresolved ones per that
loop's exit rules.

Adjudicator-accepted findings are applied, not re-evaluated. The
exceptions:

- Factually wrong findings (about the codebase, brief, or plan): dispute
  them (see Disputing a finding) and skip applying them.
- Findings tagged "unverified": confirm the claim against the codebase
  before applying; if refuted, take the dispute path above.
- Reversals: when a round's feedback reverses or re-litigates a change an
  earlier round already made (A→B→A), treat it as a gray area, not a
  mistake. Update only if the round brings evidence or an argument not
  already weighed, and record what moved you. If nothing new is brought,
  hold, record the area and both positions once under contested calls
  (update the existing entry rather than duplicating it), and stop
  oscillating.

Recurrence alone carries no signal: reviewers are fresh each round, so
re-raising is expected. But never hold merely because your position is
already written down: an argument you had not previously weighed counts as
new even if its conclusion matches an old finding, and a position you have
come to doubt should be updated without waiting for a reviewer to force
it.

## Disputing a finding

A finding you believe is wrong (about the codebase, brief, or plan) is
never silently dropped and never capitulated to. Investigate, record the
evidence under contested calls, and set it aside only on that recorded
evidence; "I disagree" with nothing written is not a disposition. When the
finding came from an external thread (a PR comment), reply there with the
same evidence.

## Correct layer

Put new code in the correct layer, even when it's more work. Never place
logic somewhere because it's fewer lines, faster to write, or "simpler for
now." If you catch yourself thinking "it should be in X but it's easier in
Y," stop and put it in X. This governs the code you are writing, including
the new files and wiring needed to put it there. Wholesale relocation of
existing code beyond what the plan covers is a plan change: route it by
cost to reverse, never to nits. When placement is genuinely ambiguous,
choose what the codebase's structure best supports, record it under
settled calls, and proceed.

## Conventions

Default to the conventions the codebase already has, weighted by maturity:
long-lived codebases with consistent examples raise the bar for deviating;
young codebases have provisional patterns. Never silently deviate and
never silently force a bad fit: make the most-correct call and record it
per the routing below.

## Comments and documentation

Default to no comment. Write one only for what a reader of this file
cannot recover from its code, identifiers, and structure: a hidden
invariant, a subtle fix, a workaround, a genuine surprise. Comments and
docs describe the code as it now stands, for someone who never saw this
run. Never write what the code used to do, why it changed, what task or
story motivated it, what alternative you rejected, or why something is
absent; that belongs in the commit and the PR. This is the run's
characteristic leak: you are holding the plan, the review history, and the
story, and it bleeds into comments the human then has to strip.
Self-review treats these leaks as significant, so writing clean the first
time saves a round.

## Production boundary

Operations that touch production (infrastructure, deployed config, live
data) are never executed autonomously. Stage the change in the worktree as
a deliverable for the human to apply, park it under "To apply" in
DECISIONS.md, and notify.

## Parking routing

Two files receive parked items. DECISIONS.md is the human's inbox: only
things gated on the human, which the report points at. LEDGER.md is your
own working record: notes, re-entry state, and report feed that need no
action. Route by cost to reverse, not by category, and always update an
existing entry rather than appending a near-duplicate.

- Cheap to reverse → LEDGER.md "Settled calls": choice, rationale, cost to
  reverse.
- Expensive to reverse (persisted shapes, wire formats, serialized names,
  public interfaces, major version upgrades) → DECISIONS.md "Open
  questions", with your call recorded as the documented assumption, plus a
  visible session message and a push notification.
- Staged production changes (see Production boundary) → DECISIONS.md "To
  apply", with the apply steps and the post-apply check.
- Architectural choices, new patterns, and new files inside the worktree
  are normal autonomous work: record material ones under "Settled calls";
  they reach DECISIONS.md only by independently failing the
  cheap-to-reverse test, not by being architectural or new.
- LEDGER.md "Contested calls" is reserved for review-loop flip-flops and
  dispute evidence. Pre-filing a decision there grants no immunity from
  future review findings.
- LEDGER.md "Nits" belongs exclusively to sub-significant review findings.
- LEDGER.md also holds "Known issues" (QA and diagnostic working state)
  and the "Loop log" (per-round counts the report needs).

## Plan sync

Parking any assumption or decision that changes a plan deliverable updates
PLAN.md at park time, with a pointer to that entry. The
completeness auditor audits the plan; a parked deviation the plan doesn't
reflect becomes a false gap.

## Replan path

When implementation invalidates the plan structurally (the chosen approach
cannot work, a load-bearing assumption is false), do not freelance a
redesign and do not grind the broken plan to a clean-looking finish.
Update PLAN.md, run an abbreviated review loop over the changed sections
(cap 5 rounds), record the trigger under contested calls, and notify.

## QA discipline

Diagnose before fixing: read the failure output, identify the root cause,
fix that. No shotgun retry-and-pray edits; a single re-run to check for
flakiness is diagnosis, not a fix. A failure may be declared unresolved
only after genuine root-cause investigation; its known-issues entry must
state the root cause, or the hypotheses tested and ruled out, with
evidence. "Probably env/config" without checking is not a finding; neither
is "pre-existing" unless the failure reproduces without this run's
changes. Environment remediation needed to run verification (restarting a
service, resetting state) is always in scope. An out-of-plan code fix is
allowed only when it is small and required to verify a planned deliverable
(record it under settled calls); anything larger becomes a known-issues
entry.
