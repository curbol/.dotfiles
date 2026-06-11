# Longrun Review Rubric

For reviewer and adjudicator subagents in a longrun plan-review loop.
Never give this file to the implementer.

## Significance

A finding is significant when acting on it would change an interface or
data shape, add or remove a deliverable, change the verification strategy,
or invalidate an assumption the plan depends on.

Explicitly not significant: asking the plan to state what the codebase
already implies, specificity the implementer can decide, style, and
genericity that is costly and not currently needed.

## Scope guard (deliverable-adding findings)

A finding that would add a deliverable to the plan is significant only if:

- the brief requires it, or
- the plan's existing deliverables entail it (a persisted-shape change
  entails its migration; a new behavior entails its declared verification;
  a new external input entails its validation), or
- omitting it would invalidate an assumption the plan depends on.

Deliverable additions for general completeness, polish, or future-proofing
are nits. Deliverable removal stays under the ordinary significance test.

## Deferral cost

Answer "what would it cost to fix this at code stage instead of plan
stage?" in concrete dimensions, never in time estimates:

- Rework scope: which already-built files or interfaces would need rework,
  roughly how many edit sites.
- Lock-in: would the deferred fix collide with an interface, data shape,
  or persisted state that is hard to reverse.
- Certainty: would the later fix be mechanical, or require
  re-investigation.
- Rework deliverables: would fixing later add a migration, backfill, or
  follow-up change.

Lead with the dimension that drives the call; do not recite all of them.
If even the strongest dimension is cheap (few edit sites, fully
reversible, mechanical, nothing added), deferral cost is low and the
finding is a nit.

## Reviewer rules

- Claims about how existing code behaves (behavior, signatures, paths)
  must come from files you read this round; cite file:line. Claims that
  something does not exist must cite the search you performed (pattern and
  scope).
- Report everything you find, each finding tagged significant or nit with
  its deferral-cost answer. At most 10 findings, ordered by severity;
  state explicitly when more exist beyond the cap.

## Adjudicator rules

- Judge significance on plan impact, never on citation hygiene.
- Before rejecting any finding, read what it points at: the cited code, or
  the plan/brief passage for design-level findings. Never reject on
  plausibility alone.
- Do not verify claims on the accept side: a code-behavior finding that
  would be significant if true but whose claim you cannot confirm is
  accepted, tagged "unverified: author must confirm against the codebase
  before applying." If material you did read contradicts the claim, reject
  and record why.
- Findings grounded in the plan or brief are judged on the rubric, not
  penalized for lacking code citations.
- Triage only: do not add findings, and do not re-review the plan from
  what you read.
- Dispute history is not evidence on the merits. But a finding whose
  substance is already recorded under contested calls with no new argument
  is triaged "re-raise", not accepted.
