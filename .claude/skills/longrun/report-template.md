# Longrun Report Template

REPORT.md structure, ordered for fast re-entry. Keep each section tight;
link to FOLLOWUPS.md entries rather than restating them.

## TL;DR

Honest status: complete, partial, or blocked. What was attempted, what
shipped, in a few sentences.

## Load-bearing assumptions

The assumptions that gate everything else, including staged production
changes awaiting human application (with their apply steps and post-apply
checks). Read this before the diff.

## Coverage

The completeness loop's final table: every plan item done/partial/missing
with evidence, plus not-in-plan rows. Unresolved rows appear here and
under known issues.

## Design choices and contested calls

Notable decisions, and flip-flop areas with the call made and the
positions considered.

## Open questions

Parked questions needing the human, from FOLLOWUPS.md.

## Known issues and QA results

Per-deliverable verification outcomes; unresolved failures with root cause
or ruled-out hypotheses; quarantined flaky tests with evidence.

## Suggested review order

The commits (or files) in the order a human should read them, with one
line each on why.

## Loop statistics

Rounds per loop; findings accepted/rejected/re-raised per round;
unverified tags issued and how many were refuted; invalid rounds; caps
hit; per-round subagent cost where available.
