# Audit Command Template

The shape of the generated `.claude/commands/audit.md`.

Lines beginning with `>>` are instructions to you and never appear in the
output. `{{NAME}}` marks a slot to fill from what you discovered. Blocks
marked VERBATIM are copied exactly: they encode the standard from
`principles.md`, they are identical across every repo, and that sameness is
what lets update mode detect drift by comparison. Do not paraphrase them,
reorder them, or "improve" them per repo. Blocks marked FILL are the whole
reason the command is repo-specific.

>> Frontmatter. `description` and `argument-hint` only.
>> Omit `allowed-tools` unless you verify the current tool names: the
>> sub-agent tool is `Agent` in current Claude Code and was `Task` in older
>> versions, and an unrecognized entry silently withholds the tool, which
>> would break the fan-out with no error. The no-edit rule is enforced in
>> prose instead (Step 6).

---
description: {{ONE_LINE_DESCRIPTION}}
argument-hint: "[scope]"
---

# Audit

>> FILL: name the repo and what it is. One or two sentences, then the scope
>> line verbatim.

Deep review of the {{REPO_NAME}} codebase: {{WHAT_IT_IS}}. Reviews everything
by default. If the user provides a scope (e.g. {{TWO_REALISTIC_SCOPE_EXAMPLES}}),
narrow to those areas.

Scope: $ARGUMENTS

## Step 1: Determine scope

>> FILL: the concrete file sets. Name real directories and extensions, and
>> the root-level files that are easy to forget.

- **No arguments:** review {{FULL_FILE_SET}}.
- **With scope:** interpret the user's wording to identify which
  {{PACKAGES_OR_DIRS}} to review. When in doubt, include more rather than less.

>> FILL: exclusions, one line each, with the reason. Omit the paragraph only
>> if the repo genuinely has nothing vendored, generated, or captured.

Do not review {{EXCLUSIONS}}: {{WHY_EACH_IS_EXCLUDED}}. Where an exclusion is
produced by code in this repo, review the producer instead.

## Step 2: Run baseline checks

>> VERBATIM (first paragraph):

Run these first. Proceed with the audit either way, since area findings may
explain a failure or reveal it as pre-existing. Report any failure as Tier 1,
ahead of new findings. Do not re-decide in prose what these commands decide:
if the formatter is clean, formatting is not a finding.

>> FILL: the repo's own entry points, preferred over hand-rolled invocations
>> (Makefile targets, package.json scripts, justfile recipes). Every line here
>> is one you ran. Annotate any check that is slow, or that needs network or
>> credentials, and leave those out of the block.

```bash
{{BASELINE_COMMANDS}}
```

>> FILL: what the suite does and does not cover, so an agent knows whether a
>> green run means anything. Note hermeticity, gated integration tests, and
>> anything that needs a live dependency.

{{SUITE_CHARACTER}}

## Step 3: Dispatch review sub-agents

>> FILL or DROP. Drop this whole step for a small repo and audit inline: fan
>> out only when no single agent could hold the scope. If dropped, keep the
>> tiers, the finding gate, and the review criteria as your own working
>> standard, and renumber the steps.

Use `feature-dev:code-reviewer` sub-agents to review the scoped files. Split
by area so agents run in parallel:

{{AREAS}}

>> Each area entry: bold name, its file list, and one line naming what that
>> area is responsible for and what tends to go wrong in it. Areas follow
>> dependency boundaries, not file count.

>> VERBATIM:

For each sub-agent, provide:
- The full list of files in its area, not a diff.
- The scope description from the user, if any, so it knows what to focus on.
- The review criteria below that apply to its area, plus the core invariants,
  which apply everywhere.

Tell sub-agents to read entire files rather than scanning for patterns.
Finding a real issue requires the surrounding context. Where a package
documents its own contract, hold the code to that contract.

### Priority tiers

Tier by consequence, not by category. The categories under each tier are
examples, not the definition.

**Tier 1 (must fix):** produces behavior a user or the data can observe as
wrong, or violates a core invariant. Bugs, races, corrupt or non-atomic
writes, swallowed errors that hide a failure, layer violations.

**Tier 2 (should fix):** correct today, but the next change in this area is
likely to break it, or a real invariant has no test. Significant duplication,
resource leaks, API shapes that invite misuse, meaningful refactors.

**Tier 3 (consider):** removes something concrete. If you cannot name what it
removes, leave it out.

### The finding gate

Every finding must name its failure scenario: the input, call sequence, or
state that produces the wrong outcome. "This could race" is not a finding.
"Two concurrent writes both read before either writes, so the second save
clobbers the first" is.

A finding that cannot name a trigger is dropped, not downgraded. Report file
and line, what goes wrong, and a fix specific enough to act on.

### Review criteria

>> FILL, and this is the highest-value block in the file. Each invariant gets
>> the rule, the violation shape, and the tier. Discovered from documents,
>> guard tests, and package contracts, never invented.

**Core invariants (hard rules, violations are Tier 1)**

These are the contracts the whole {{THING}} rests on. See {{DOC_REFERENCES}}.

{{INVARIANTS}}

>> FILL: correctness criteria specific to this repo's logic. Name the actual
>> functions, parsers, state machines, and math that are easy to get wrong,
>> with the tier. Generic "look for off-by-one" lines are worth little; "verify
>> each branch of classify() against its condition" is worth a lot.

**Correctness**

{{CORRECTNESS_CRITERIA}}

>> FILL: whichever of these the repo actually has. Drop the headings that do
>> not apply. Concurrency for anything that fans out or shares state; write
>> integrity for anything that persists; resource use where scale is real;
>> paths and portability where config resolution is documented; secrets where
>> the repo handles any; plus any framework-specific section (lifecycle,
>> signals, hooks, migrations).

{{DOMAIN_CRITERIA_SECTIONS}}

>> VERBATIM:

**Duplication and extraction**

- Repeated blocks (5 or more lines, similar structure) across files that
  should be a shared helper. Tier 2.
- Ignore trivial similarity: both call the same stdlib helper, both have an
  error check. Only flag duplication where extracting it measurably reduces
  the bug surface or eases a likely change.

**Refactoring opportunities**

- Code that grew incrementally and would benefit from restructuring now that
  its shape is clear: a function doing three things that should be three; a
  type that accumulated responsibilities; data flow that got indirect when a
  simpler path exists. Tier 2.
- Every suggestion must name a concrete improvement. It **removes** something
  (an indirection, a duplicated pattern, a coordination point, a way for two
  things to get out of sync), **enables** something (makes X testable,
  unblocks a use case, lets a change land in one place instead of N), or
  **generalizes meaningfully** (one shape replaces N near-duplicate variants).
  "Same behavior, different shape" does not qualify, however elegant. If you
  cannot name what improved, leave it out.

**Test quality (assess each suite as a whole, not test by test)**

>> FILL the first line with the repo's test framework and conventions, then
>> VERBATIM from the bullets down.

{{TEST_FRAMEWORK_NOTE}}

- Significant production behavior with no test at all, especially the core
  invariants above and every branch of the logic named under Correctness.
  Tier 2.
- Clusters of overlapping tests that could consolidate into fewer, clearer
  cases. Tier 2.
- Tests asserting implementation details (internal call order, private
  fields) instead of observable behavior. They break on refactor for no
  value. Tier 2.
- Duplicated test setup or helpers that could be shared. Tier 2.
- Weak assertions (a count checked but not the values, the wrong field
  asserted). Tier 2 only where the weakness could mask a real bug.
- Do not suggest tests for trivial edge cases, for every possible nil input,
  or splitting working tests for purity. Fewer, stronger tests beat many
  fragile ones.

>> FILL: idioms for the languages this repo actually uses, and only for
>> patterns no tool in the baseline block already decides. Drop anything the
>> linter catches.

**{{LANGUAGE}} idioms**

{{IDIOM_CRITERIA}}

>> VERBATIM:

**Cross-boundary consistency (flag here, synthesized in Step 4)**

When reviewing an area, note any exported API that looks easy to misuse
(parameter order, unclear units, implicit preconditions) and any call into
another area that assumes something about what it returns. These are inputs
for the cross-cutting analysis, which no single area agent can do.

## Step 4: Cross-cutting analysis

>> VERBATIM (first line), then FILL one numbered trace per core invariant.

After the area agents report, trace each core invariant end to end across
boundaries, which no single agent could do:

{{INVARIANT_TRACES}}

>> Each trace names the files to read in order and states what the trace must
>> confirm. "Follow X from where it is computed, through Y, into Z, and
>> confirm W" beats "check that X is stable".

## Step 5: Verify and widen

>> VERBATIM:

For every finding from an area agent or from the cross-cutting analysis:

1. **Verify it yourself.** Read the file and line. Confirm the trigger is
   real. Drop anything speculative, cosmetic, or already handled elsewhere.
2. **Widen it.** Grep or glob for the same pattern across the whole
   codebase and report every occurrence, not just the one an agent happened
   to open.
3. **Mechanize what widens.** If a class has many instances and a tool could
   decide it, report one automation proposal instead of N findings: enable the
   lint rule, add the check, add a guard test. Check the lint configuration
   first, since a rule that exists but is disabled or not wired into CI is
   the cheapest fix available.
4. **Drop non-actionable observations.** Anything amounting to "noting this
   but it is fine" comes out.
5. **Deduplicate.** Merge findings that different agents reached from
   different angles into one item.

## Step 6: Report

>> VERBATIM:

Present the report and stop. Do not fix anything, do not write findings to
memory, and do not leave a findings file behind: the human triages in the
session, and saved findings become confidently wrong context later.

Organize by tier, then by category within a tier. Within a tier, order by
value against effort.

Each finding gets:
- File path and line numbers
- The failure scenario: what goes wrong and what triggers it
- A fix specific enough to act on
- One entry per pattern, with all occurrences grouped under it

**Test quality findings** are a cohesive assessment per area, not a list of
files. "The syncer tests cover classify and dedup well but nothing exercises
the expired-session abort" beats "syncer_test.go:42: missing test".

**Refactor findings** include a sketch of the target structure, or at minimum
name the functions and types that would result.

**Automation proposals** name the rule or check, the config file it goes in,
and roughly how many current findings it subsumes.

An area with no findings says so. A short report on sound code is a successful
audit, not a lazy one. No nits, no cosmetic notes, no "just flagging this".
