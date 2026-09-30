# Rewriting a description as current state

A story or epic description states what is true now: scope, shape, evidence, ordering, and
open questions. It is not a log. The story's comments are the log.

## Replace, don't annotate

When a fact changes, replace the sentence that states it. Never append a dated entry, and
drop the ones already there:

| Instead of | Write |
|---|---|
| "**Decided 2026-09-25 with Sam:** renewal stays reactive." | "Renewal is reactive." |
| "Revised 2026-09-22 for the one-registration decision: …" | the current statement, alone |
| "An earlier revision claimed 20+ commits; the real figure is 8." | "8 commits in the last 90 days." |
| "Two plan items are struck by measurement, do not re-derive them:" | the measured facts, as facts |
| "(superseded, see comment)" | the superseding fact |

Before a decision leaves a description, check that it is stated in the design doc or in its
own story. A decision that still shapes the design belongs in the design doc, in the present
tense.

## Keep

- Dated measurements. A count is a fact about a point in time, so it keeps its date: "171
  shops across 128 orgs (596-org capture, 2026-08-26)".
- Deadlines.
- Every still-current file path, line number, PR, story reference and acceptance criterion.
  A rewrite corrects; it doesn't summarize.
- A link to a thread that justifies a still-current decision, as a plain reference.

## Drop

- Narration of how the team got here, and "we first thought X" passages.
- Rejected alternatives nobody is reconsidering. Keep one only when a reader would otherwise
  propose it again, as one sentence on why it doesn't work.
- People as the frame for content: "met with Sam", "to answer Sam's questions", "Sam
  wants". A name stays only where the reader uses it: an owner, who to ask, who a review is
  waiting on, who is building a piece the story depends on.

## Fold in what the comments settled

Later comments often hold the current truth: a changed approach, a new count, a closed
question. The rewritten description states those facts, citing the comment where that
helps. Where a comment and the description conflict and the latest word isn't clear, keep
the description's wording and raise the conflict instead of guessing.

## Never invent

Every sentence comes from the old description, the story's comments, code read in this
session, or a decision the person made. A description that is visibly incomplete is better
than one that is confidently wrong.
