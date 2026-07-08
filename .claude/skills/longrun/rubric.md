# Longrun Review Rubric

For reviewer and adjudicator subagents in a longrun plan-review loop.
Never give this file to the implementer.

## Significance

A finding is significant when acting on it would change an interface or
data shape, add or remove a deliverable, change what must be verified or
what a passing verification proves, or invalidate an assumption the plan
depends on.

Explicitly not significant: asking the plan to state what the codebase
already implies, specificity the implementer can decide, style, and
genericity that is costly and not currently needed. Refinements to how
the QA procedure executes are nits when their absence would surface as a
loud failure during QA (the QA loop hits the failure and fixes the
procedure then); a procedure gap is significant only when it would let a
wrong result pass silently.

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

- Audit the whole plan, covering every dimension each time: requirements
  coverage against the brief; feasibility against the actual codebase;
  simplicity and over-engineering; failure modes and edge cases.
- Claims about how existing code behaves (behavior, signatures, paths)
  must come from files you read this round; cite file:line. Claims that
  something does not exist must cite the search you performed (pattern and
  scope).
- Report everything you find, each finding tagged significant or nit with
  its deferral-cost answer, ordered by severity.

## Code review (diff reviews, after implementation)

For reviews of the actual diff (self-review and automated-feedback
triage): a finding is significant when merging without it would ship
incorrect behavior, a security problem, a broken invariant or contract,
or a violation the repo's conventions block on. Style and
alternative-approach preferences are nits. The evidence rules above apply
unchanged.

Comments and documentation the diff adds or changes get a cold-reader
test: each line must earn its place for someone reading only this file,
who never saw the run, the plan, the review loop, the story, or the code's
prior state. A comment or doc line is significant when it says what the
code used to do or why it changed, names a task, ticket, or rejected
alternative, justifies an absence, or only restates what the code and its
identifiers already make plain. This is where the run's own context leaks,
and it reads as noise to the human reading the diff, so these are fixed,
not filed. The fix is deletion or a trim to what the file's reader needs,
never a rewrite of working code.

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
- In plan reviews, tag every accepted finding `build` (changes what gets
  built: an interface or shape, a deliverable, or what a passing
  verification proves) or `procedure` (refines how verification executes);
  the tag drives loop termination. Diff reviews use no such tag.
