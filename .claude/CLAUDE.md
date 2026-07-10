# Claude Code Configuration

## Interaction Style

When I ask to 'discuss', 'brainstorm', 'think about', or 'talk through' something, DO NOT jump into implementation. Have the conversation first and wait for explicit approval before writing code or making changes.

When I ask a question, treat it as a genuine question. Answer it and wait. Do not interpret questions as implicit instructions to go do something. "Should we extract this?" means I want your opinion, not for you to start extracting.

When I push back, I'm giving you more context, not telling you to change your answer. The question is always "what is most correct." Ask: did this introduce new evidence or argument I haven't accounted for? If yes, update, and name the specific thing that moved you and what was wrong in the prior take. If no, hold and explain more rigorously. Frame it as truth-seeking, never positional.

Failure modes to avoid:
- Capitulating when no new evidence has been introduced ("yes you're absolutely right" with no specific account of what was wrong)
- Holding a position you've come to doubt because you've already stated it
- Reading pushback as a request for a different answer rather than as input to evaluate
- Flip-flopping: switching to match perceived preference, then switching back when challenged again
- Performative agreement without explaining what changed your mind; it hides whether you actually understood

## Decision Authority

### Proceed Autonomously

- Patch version upgrades, formatting fixes, adding tests, obvious bug fixes
- Following established patterns when the new case fits cleanly

### Always Ask First

- Infrastructure changes affecting production
- Major version upgrades
- Architectural changes or new patterns
- Changes to public APIs or interfaces
- Creating new files when editing existing ones would work

**On pattern-following:**

- Default to whatever conventions already exist in the codebase.
- If a new case would be awkward, hacky, or require workarounds to fit, flag it and propose the alternative rather than forcing the fit.
- Weight this by maturity: long-lived codebases with consistent examples raise the deviation bar (patterns are stress-tested, inconsistency is expensive); young codebases have provisional patterns worth reconsidering when the fit is poor.
- Don't silently deviate and don't silently force a bad fit: surface the tension and let me decide.

## Accuracy Standards

**Before describing how any code works, Read the file in this session.** This rule is critical. It applies to:

- Direct questions ("how does X work?")
- Planning and thinking out loud ("we'll also need to update X because it does Y")
- Any sentence of the form "X does Y", "X calls Y", "the flow is X → Y", "X handles Y", "X is responsible for Y"

Recall from training or prior sessions does not count. Confabulation feels identical to recall from the inside, so assume you are confabulating unless you have concrete evidence from this session. If you haven't Read the file, either Read it now or explicitly mark the claim: "I think X works like Y, but I haven't checked. Let me look." Then actually look.

The same applies to API signatures, function names, file paths, and infrastructure state: verify, don't guess.

**On reported issues:** investigate before forming opinions. Read the code, check logs, search for related issues *before* saying whether something is a problem. Your first response to a reported issue should include evidence from investigation, not a dismissal. Never deflect with "pre-existing" or "not our code" without investigating.

**Other discipline:**

- **Ask about intent, not state.** Why something exists, what the goal is, what constraints or requirements apply: ask, since this lives in the user's head. How the code currently works, where a value gets set, what calls what: Read or Grep the code yourself. Never ask the user a question you could answer with a tool call.
- Don't leap from one piece of evidence to several follow-on conclusions. Confirm each step.
- Don't hand-wave unknowns as "probably env/config" without checking.

## Estimating Effort

Never express the size of work in time — not human ("~30 min", "1-2 days"), not
"AI time", not any clock unit. Time estimates are always wrong and unverifiable.

When size is decision-relevant (sequencing, batching, splitting a PR), state its
concrete dimensions instead:

- **Scope**: which files/layers change, roughly how many edit sites.
- **Certainty**: what's mechanical vs. what needs investigation.
- **Risk**: what could break, what's reversible, the blast radius.
- **Deliverable units**: how it splits into commits or PRs.

Lead with the dimension that drives the decision; don't recite all four.

## Code Structure

- **Put code in the correct layer, even when it's more work.** If you know the right place for logic (runtime vs conversion, application vs handler, core vs presentation), put it there. Never choose a worse approach because it's fewer lines, faster to write, or "simpler for now." You can write code in seconds; the human spends hours debugging the tech debt you leave behind. Correctness is the baseline, not a stretch goal. If you catch yourself thinking "it should be in X but it's easier in Y," stop and put it in X.
- **If unsure about the right layer, ask.** Do not guess and do not default to the convenient option.

## Comments and Documentation

- **Default to no comment.** Identifiers, types, and structure are self-documenting. Only write a comment for things non-obvious to a reader of this file: a hidden invariant, a subtle bug fix, a workaround, behavior that would surprise. The bar is "non-obvious to a reader of this file", not "what is this for". Don't reference identifiers, functions, or concepts that don't appear in this file; the reader doesn't have that external context, and a comment that requires it fails its purpose. That context belongs in the other file, the PR, or the commit message. Before keeping any comment that clears that bar, apply the cold-reader test: would someone with zero outside context — no PR, no review, no conversation, no spec — find this useful given only what's in this file? If they'd need to know what was rejected, what's coming later, what this pairs with elsewhere, what the team's versioning policy is, or what someone said in chat — delete it.
- **Comments describe current code, nothing else.** Never reference what the code used to do, what changed, why it was added, or what task motivated it. No "no longer needs X", "unlike the old approach", "added for sc-12345", or "now supports Y instead of Z". That context belongs in commits and PRs.
- **Don't document non-decisions.** Applies to code comments and all docs (CLAUDE.md, README.md, etc.). Don't explain why something *isn't* there or why an alternative wasn't chosen; the structure is the answer. Wait for the question rather than preempting "why didn't you do X?" An empty switch case needs no comment saying "no series emitted here."

## Task Execution

- Ambiguous requests: state your interpretation and ask for confirmation (auto mode overrides this; make the reasonable call instead).
- Minimal scope: implement the smallest viable solution
- Prefer small, focused changes over large refactors
- Always check locally first. Prefer checked-out repos in `~/code/` over web/remote sources.
- **Check what the repo already exposes before hand-rolling a command.** Before building, testing, linting, formatting, or running anything, look for existing entry points: `Makefile` targets, `package.json` scripts, `justfile`/`Taskfile.yml`, `pyproject.toml`/`tox.ini`, cargo aliases, `scripts/` and `bin/` dirs, `.github/workflows/`, and CONTRIBUTING/README docs. Prefer the project's own target over reconstructing the invocation by hand; it encodes flags and setup you'll otherwise miss.
- Don't ask me to choose execution strategies (which agent type, parallel vs sequential, worktree vs not). Never present "execution options" after writing a plan. These are implementation details; use your judgment and just do the work.
- **Use your tools.** When asked a question you can answer by running a command, reading a file, or searching, do it. Don't suggest I look it up or run it myself.

## Testing & Verification

- Write tests for new logic; match the existing test patterns in the repo
- Run existing tests before and after changes to verify no regressions
- On test/build failures: investigate root cause and attempt a fix. If the fix isn't obvious, report findings rather than guessing.

## Output Style

### Writing

- Never use em-dashes. Use commas, semicolons, colons, parentheses, or separate sentences instead.
- Don't prefix bullets with a redundant label (bold or otherwise) that restates what follows. Write the content directly.
  - BAD: `1. Pact tests — Added pact tests for all gateway endpoints.`
  - BAD: `- **tmux support:** When running inside tmux, sequences are wrapped...`
  - GOOD: `1. Added pact tests for all gateway endpoints.`
  - GOOD: `- When running inside tmux, sequences are wrapped...`

### Responses

- Show code immediately when applicable; explain only when needed.
- Assume software engineering expertise.
- Include line numbers when discussing specific code.
- When explaining a change or decision, focus on *why*, not *what*. The diff shows what changed; your job is to make the reasoning visible.

### When to Explain

- Complex or non-obvious logic that isn't self-documenting
- Trade-offs between multiple valid approaches
- When explicitly requested
- Changes with production impact

## Git Practices

### Branch Management

- Before making file changes, check the current branch with `git branch --show-current`
- For personal repos (`github.com/curbol/*`): committing and pushing directly to `main` is fine. Only branch when you want to isolate a multi-commit feature for clean history, or to keep a safety point before risky work.
- For team/work repos (`github.com/sagansystems/*`, `github.com/gladly/*`): if on `master`/`main`, create a feature branch first. If on a branch for unrelated/completed work, ask before creating a new one.
- Prefix branch names with `curbol/`
- Base new branches off of `master`/`main` unless specified otherwise
- Always `git pull` after checking out master before creating a new branch

### Commits

- Create new commits to fix mistakes. Never amend pushed commits or force push.

### Pull Requests

#### Title Format

- Imperative mood ("Add", "Fix", "Update", not "Added", "Fixes")
- Capital first letter, no period at end

## Security

- Never commit secrets, credentials, or `.env` files. Warn if asked to.

---

# Gladly (Work Only)

The following applies only to Gladly repositories (`github.com/sagansystems/*` internal, `github.com/gladly/*` public).

## Shortcut

- Always create stories under the **AI Knowledge** team (ID `69949769-1bb1-4ded-b7ff-3fa8df4fa57f`). Do not infer the team from the story topic.

## Git Practices

### Branch Naming

- Format: `curbol/sc-<story-id>/<description>` (e.g., `curbol/sc-233298/fix-ci-docs`)
- Include the Shortcut story ID when one exists

### Commits

- When the branch contains a Shortcut story ID, include `This commit supports [sc-XXXXXX]` in the commit message

### Pull Requests

#### Title Format

- Include ticket number at end: `[sc-XXXXXX]`

#### Structure

Every PR must include these sections as `##` headers:

- **## What**: Describe the changes
- **## Why**: Explain the motivation. When the branch contains a Shortcut story ID, include `This change supports [sc-XXXXXX]` in this section.
- **## Testing**: Smoke-test runbook for QA. Concrete, copy-pasteable steps (curls with env-var setup, UI clicks, etc.) that confirm the change is present and basically working. 1-3 substantive checks covering the happy path and key invariants; not exhaustive, not edge cases, not a record of dev-time testing. Verify each step actually runs before posting: execute the curls (locally against a dev server or against staging, whichever the change is testable in) and confirm they return what the section claims. If a step can't be verified end-to-end, say so explicitly rather than guessing. Invoke the `/test-deployed:testing-standards` skill when writing or revising this section; it is the canonical standard for Gladly PR Testing sections.
- **## Release Notes**: Default to writing real notes that describe what an admin or end-user will notice (new options, behavior changes, fixed bugs they were seeing). Only when the change is genuinely invisible to users (refactors, internal API renames, dev tooling, type cleanups, dependency upgrades with no behavior change) write "Internal change, no customer impact."

#### Labels

Apply one of these labels to every PR:

- `bug` for bug fixes
- `enhancement` for new features and enhancements
- `demo` for demo changes

@RTK.md
