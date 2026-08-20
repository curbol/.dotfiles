# What Makes an Audit Command Good

The standard the generated file is held to. Every derivation choice in
`SKILL.md` traces back to one of these; when a repo tempts you to deviate,
the deviation needs a reason you can name.

An audit is not PR review. PR review is diff-scoped and catches what a change
got wrong. An audit is repo-scoped and catches what accumulated: drift from
invariants, a pattern that spread to twelve files, a subsystem whose tests
never grew, a layer boundary that eroded one commit at a time. Anything a
diff review would have caught is not what the audit is for.

## 1. Tools decide the mechanical; agents decide the judgmental

Build, test, race, vet, format, lint, dead-code, and coverage are commands
with exit codes. Run them in the baseline step and report what they say.
Never spend agent prose re-deciding them: an agent reading for unformatted
code is slower and less accurate than the formatter, and the paragraph it
takes up displaces judgment only an agent can supply.

Agent judgment is for what no tool decides: whether an invariant still holds,
whether a layer boundary leaks, whether duplication is worth extracting,
whether a test suite covers what matters, whether a refactor removes
something real.

A criterion that a tool in this repo already decides does not belong in the
generated file.

## 2. Every finding names a failure scenario, or it is dropped

A finding must name the trigger: the input, call sequence, or state that
produces the wrong outcome. "This could race" is not a finding; "two
concurrent POSTs to /api/tags both read the map before either writes, and
the second save clobbers the first" is.

This is the strongest available filter against confabulated findings, because
a misread of the code usually cannot produce a coherent trigger. A finding
that cannot name one is dropped, not downgraded to a lower tier. Downgrading
is how noise survives.

## 3. Tiers are consequence, not category

Category lists ("Tier 1: bugs, races, unatomic writes") give an agent nothing
to reason with when a finding fits no listed category, so it guesses.
Define by consequence and let categories be examples:

- **Tier 1** produces behavior a user or the data can observe as wrong, or
  violates a stated invariant.
- **Tier 2** is correct today but is a bug factory (the next change in this
  area is likely to break it) or leaves a real invariant untested.
- **Tier 3** removes something concrete. If it does not, it is not Tier 3, it
  is nothing.

## 4. Invariants are the centerpiece

The invariant list is the only part of an audit command a generic code
reviewer could not have written. It is what makes the audit about this repo.

Each invariant needs three parts:

1. **The rule**, stated so a violation is decidable rather than a matter of
   taste.
2. **The violation shape**: what code would breach it. "Any path that writes
   the lockfile after an enumeration error" is checkable; "be careful with
   sessions" is not.
3. **The check**: the grep target, the trace path across packages, or the
   guard test that settles it.

If you cannot write the violation shape, it is a preference, not an
invariant. Preferences go in review criteria or nowhere.

Invariants are discovered, never invented. They come from CLAUDE.md hard
rules, design docs, package doc comments, guard tests, and comments marking a
workaround. An invariant you inferred from reading the code once, and that no
document or test states, is a guess: either confirm it with the human or
leave it out.

## 5. A mechanizable class becomes one automation proposal

When the widen step finds many instances of a class that a tool could decide,
report one automation proposal (enable rule X in the lint config, add a vet
check, add a guard test) rather than N findings. The instances are evidence
for the proposal, not the deliverable.

Check the repo's lint configuration first: a rule that exists but is disabled,
unconfigured, or not wired into CI is the cheapest fix available, and it beats
both a prose criterion and a list of findings.

The audit has no memory across runs. Breadth within a single run is the only
evidence available for this, and it is enough.

## 6. Nothing unverified reaches the file

Every command in the generated baseline block is one you ran. Every path,
package, and identifier it names is one you globbed or grepped. Every
invariant is one you traced or a document states.

A stale audit is worse than no audit: it sends unattended agents to read
files that moved, and they report the absence as a finding or invent context
to fill the gap. The generated file's authority comes entirely from having
been checked.

## 7. Report and stop

No edits, no memory writes, no findings file. The audit presents and the
human triages in the session.

Findings go stale fast, and a saved findings file becomes a source of
confident wrong context in later sessions. This also keeps the audit's
incentives clean: a command that fixes what it finds is motivated to find
things.

## 8. Areas follow dependency boundaries and size

Split by what can be understood independently: a package with a stated
contract, a layer, a self-contained frontend bundle. Do not split by file
count alone, and do not split a package whose contract only makes sense whole.

A small repo skips the fan-out entirely. Parallel agents cost context and
buy nothing when one agent could read everything, and the cross-cutting step
already assumes a single reader with the whole picture. Fan out when no
single agent could hold the scope, not on principle.

## 9. Exclusions are explicit

Vendored third-party drops, generated code, captured fixtures, and minified
assets are named and skipped. Audit the generator, not its output: the scrub
script, not the scrubbed fixtures.

Left unstated, an agent will spend its budget reviewing three.js.

## 10. Silence is a valid result

An area with no findings says so. An audit whose report is short because the
code is sound is a successful audit.

State this in the generated file. Without it, an agent that found nothing
manufactures a Tier 3 list to look diligent, and that noise is what trains
the human to stop reading audit output.
