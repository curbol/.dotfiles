---
name: audit-command
description: Create or refresh a repository's /audit slash command at .claude/commands/audit.md. Use when asked to write, update, fix, or improve a repo's audit command, or when an existing audit command's paths, packages, invariants, or baseline commands have drifted from the repo.
---

# Audit Command Generator

You are writing a command that later sessions will run unattended, against a
repo they have not read, producing findings a human acts on without
re-deriving them. Its entire authority comes from having been checked. A
reference you did not verify sends an agent to a file that moved, and it will
report the absence as a finding or invent context to fill the gap.

Read `principles.md` from this skill's base directory now. It is the standard
the output is held to, and every derivation below traces back to one of its
rules. `template.md` is the output's shape: VERBATIM blocks are copied
exactly, slots are filled from what you discover.

## Mode

Look for an existing command before anything else: `.claude/commands/` for
`audit.md`, `dev-audit.md`, `review.md`, or any near name, and
`.claude/skills/` in case one was written as a skill instead.

- Nothing found: create mode.
- One found: update mode. It keeps its filename and invocation; renaming
  breaks the muscle memory and any docs that reference it.

Work in the repo the user named, defaulting to cwd. If that repo is not
checked out locally, say so and stop. You cannot run its baseline commands
from a remote read, so you cannot verify anything, and an unverified audit
command is worse than none.

Never start from another repo's audit command. Copying is how the existing
ones accumulated criteria for subsystems their repo does not have.

## Create mode

### 1. Discover

Read these before deriving anything. Each yields specific slots:

| Source | Yields |
|--------|--------|
| `CLAUDE.md`, `AGENTS.md` | stated hard rules and layer boundaries: the best invariant source |
| `docs/` (design, architecture, ADRs) | invariants plus the reasoning that makes them decidable |
| `README` | what the thing is, for the intro line and realistic scope examples |
| `Makefile`, `justfile`, `Taskfile`, `package.json`, `pyproject.toml`, `*.csproj`, `go.mod`, `Cargo.toml` | the repo's own entry points for the baseline block |
| `.github/workflows/` | what CI already enforces mechanically |
| linter and formatter config | which rules are on, off, or unconfigured |
| directory layout and import graph | area boundaries |
| package doc comments, module headers | per-area contracts to hold code to |
| test files | framework, conventions, and guard tests |
| `.gitignore`, generated-code markers, vendor dirs | exclusions |

Two things to notice while reading. Anything CI already decides is a tool
decision and must not become a prose criterion (principle 1). A guard test
usually marks an invariant someone cared enough to defend, so read what it
asserts (principle 4).

Churn is a useful hint for where correctness criteria pay off:

```bash
git log --format= --name-only --since=1.year | sort | uniq -c | sort -rn | head -30
```

### 2. Derive

- **Invariants.** From documents, guard tests, and package contracts only.
  Each gets the rule, the violation shape, and a tier. Cannot write the
  violation shape? It is a preference, not an invariant. Suspect one from
  reading the code that no document states? Ask the human; do not write a
  guess as a hard rule.
- **Areas.** Follow dependency boundaries and stated contracts, not file
  count. Cap at roughly seven. If one agent could hold the whole repo, drop
  Step 3 entirely and audit inline (principle 8).
- **Baseline commands.** Prefer the repo's own targets over hand-rolled
  invocations, since they encode flags and setup you would otherwise miss.
  Leave out anything needing network or credentials, and note it instead.
- **Correctness criteria.** Name the actual functions, parsers, state
  machines, and math that are easy to get wrong. "Verify each branch of
  `classify` against its condition" is worth something; "look for off-by-one"
  is not.
- **Domain sections.** Include only what the repo has: concurrency where it
  fans out or shares state, write integrity where it persists, resource use
  where scale is real, secrets where it handles any, framework lifecycle
  where a framework owns it.
- **Idioms.** Only for languages the repo uses, and only patterns no baseline
  tool already decides. If the linter catches it, delete it.
- **Exclusions.** Name each and say why, and point at the producer where the
  repo generates the excluded output.

### 3. Verify before writing

1. Run every baseline command. Record what passes, what fails, and anything
   slow enough that an unattended run should know.
2. Glob every path and grep every identifier the file will name.
3. Confirm each invariant's check is real: the grep target exists, the trace
   path connects, the guard test runs.
4. If an invariant is already violated today, that is a finding for the human
   now. Report it rather than quietly writing a rule the code breaks.

### 4. Write and report

Write `.claude/commands/audit.md`, then report:

- which slots you filled and from what
- anything you could not verify, and what you left out because of it
- invariants you dropped for lack of evidence, and any you need confirmed
- invariants the code already violates

Then offer a dry run on the narrowest area, which is the only real test that
the file works.

## Update mode

Three passes, then one diff.

### Pass 1: Drift

The mechanical, highest-value half. Extract every concrete reference the
existing file makes (paths, directories, packages, functions, types,
commands, config files, doc references, sub-agent and tool names) and verify
each one. Fix what moved, delete what is gone, and replace commands that are
no longer the repo's entry point. Where a stale reference has no obvious
replacement, ask rather than guessing.

Tool and agent names deserve their own check: an `allowed-tools` entry or a
sub-agent type that no longer exists fails silently, withholding the tool
with no error. The sub-agent tool is `Agent` in current Claude Code and was
`Task` in older versions.

### Pass 2: Coverage

- Directories and packages that belong to no area.
- Invariants added to `CLAUDE.md` or the design docs since the file was
  written.
- Criteria that CI or the linter now decides: delete them (principles 1, 5).
- Languages or frameworks the repo has picked up with no criteria.
- Lint rules available but disabled or unwired, which belong in the audit as
  automation proposals rather than as prose criteria.

### Pass 3: Conformance

Compare against `template.md`. The VERBATIM blocks should match; refresh any
that drifted, which is how an improvement to the template propagates to every
repo. Then hold the FILL sections to `principles.md`: invariants have
violation shapes, tiers are defined by consequence, the finding gate is
present, the report ends in report-and-stop, and silence is stated as a valid
result.

### Then

Write the file and show `git diff` for it. The file is tracked, so nothing is
lost if the human wants it reverted. If it is untracked or the repo is not
git, copy it to the scratchpad first, then write and diff against the copy.

Report the same way create mode does: what changed, what you could not
verify, and what needs the human's confirmation.

## Asking the human

Only intent-level questions, the ones whose answers live in their head:

- an invariant you suspect from the code that no document states
- whether a deviation you found is deliberate
- what is excluded on purpose and why
- for a team repo, constraints that come from people rather than code

Never ask what a tool call answers. Layout, call graphs, test framework,
whether a command exists: read it.

## Do not

- Copy another repo's audit as a starting point.
- Include criteria for a language, framework, or subsystem the repo lacks.
- Write an invariant no document, test, or human confirmed.
- Write an `allowed-tools` list you did not verify against the current
  harness.
- Give the generated command permission to fix what it finds. It reports and
  stops (principle 7).
