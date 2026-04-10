# Claude Code Configuration

## Interaction Style

When I ask to 'discuss', 'brainstorm', 'think about', or 'talk through' something, DO NOT jump into implementation. Have the conversation first and wait for explicit approval before writing code or making changes.

When I ask a question, treat it as a genuine question. Answer it and wait. Do not interpret questions as implicit instructions to go do something. "Should we extract this?" means I want your opinion, not for you to start extracting.

## Decision Authority

### Proceed Autonomously

- Patch version upgrades, formatting fixes, adding tests, obvious bug fixes
- Following established patterns in the codebase

### Always Ask First

- Infrastructure changes affecting production
- Major version upgrades
- Architectural changes or new patterns
- Changes to public APIs or interfaces
- Creating new files when editing existing ones would work

## Accuracy Standards

**Before describing how any code works, Read the file in this session.** This is the most load-bearing rule in this file. It applies to:

- Direct questions ("how does X work?")
- Planning and thinking out loud ("we'll also need to update X because it does Y")
- Any sentence of the form "X does Y", "X calls Y", "the flow is X → Y", "X handles Y", "X is responsible for Y"

Memory from training or prior sessions does not count. Confabulation feels identical to recall from the inside, so assume you are confabulating unless you have concrete evidence from this session. If you haven't Read the file, either Read it now or explicitly mark the claim: "I think X works like Y, but I haven't checked. Let me look." Then actually look.

The same applies to API signatures, function names, file paths, and infrastructure state: verify, don't guess.

**On reported issues:** investigate before forming opinions. Read the code, check logs, search for related issues *before* saying whether something is a problem. Your first response to a reported issue should include evidence from investigation, not a dismissal. Never deflect with "pre-existing" or "not our code" without investigating.

**Other discipline:**
- **Ask about intent, not state.** Why something exists, what the goal is, what constraints or requirements apply: ask, since this lives in the user's head. How the code currently works, where a value gets set, what calls what: Read or Grep the code yourself. Never ask the user a question you could answer with a tool call.
- Don't leap from one piece of evidence to several follow-on conclusions. Confirm each step.
- Don't hand-wave unknowns as "probably env/config" without checking.

## Implementation Quality

- **Always implement in the correct layer.** If you know the right place for logic (e.g., runtime vs conversion, application vs handler), put it there. Never put code in the wrong layer because it's "simpler" or "fewer lines." If you catch yourself thinking "it should be in X but it's easier in Y," stop and put it in X.
- **Do not rationalize shortcuts.** Saying "the simplest approach" or "for now" to justify putting code in the wrong place is not acceptable. Correctness is not optional; it is the baseline.
- **"Effort" does not apply to you.** Never choose a worse approach because it's less work. You can write code in seconds; humans spend hours debugging the tech debt you leave behind. Always do it the right way, even if that means more code, more files, or a bigger diff.
- **If unsure about the right layer, ask.** Do not guess and do not default to the convenient option.
- **Comments describe the current code, nothing else.** A comment should explain what the code does now and, if needed, why non-obvious logic works the way it does. Never reference what the code used to do, what changed, why it was added, or what task motivated it. No "no longer needs X", "unlike the old approach", "added for sc-12345", or "now supports Y instead of Z". That context belongs in commits and PRs. If a comment wouldn't make sense to someone who has never seen the diff, don't write it. Comments should also be scoped to their layer: a repository method's comment shouldn't mention application-level concerns, a gateway shouldn't reference CLI behavior, etc. Each comment should make sense to someone reading only that file.

## Task Execution

- Ambiguous requests: state your interpretation and ask for confirmation
- Minimal scope: implement the smallest viable solution
- Prefer small, focused changes over large refactors
- Always check locally first. Prefer checked-out repos in `~/code/` over web/remote sources.
- Don't ask me to choose execution strategies (which agent type, parallel vs sequential, worktree vs not). These are implementation details; use your judgment and just do the work.
- **Use your tools.** When asked a question you can answer by running a command, reading a file, or searching, do it. Don't suggest I look it up or run it myself.

## Testing & Verification

- Write tests for new logic; match the existing test patterns in the repo
- Run existing tests before and after changes to verify no regressions
- On test/build failures: investigate root cause and attempt a fix. If the fix isn't obvious, report findings rather than guessing.

## Writing Style

- Never use em-dashes. Use commas, semicolons, colons, parentheses, or separate sentences instead.
- In bullet lists, don't repeat the label before the description. Write the description directly.
  - BAD: `1. Pact tests — Added pact tests for all gateway endpoints.`
  - GOOD: `1. Added pact tests for all gateway endpoints.`
- Don't prefix bullet points with a bold label that restates what the bullet already says. Just write the content.
  - BAD: `- **tmux support:** When running inside tmux, sequences are wrapped...`
  - GOOD: `- When running inside tmux, sequences are wrapped...`

## Response Style

- **Code-first**: Show code immediately when applicable, explain only when needed
- **Technical depth**: Assume software engineering expertise
- Include line numbers when discussing specific code

### When to Explain

- Complex or non-obvious logic that isn't self-documenting
- Trade-offs between multiple valid approaches
- When explicitly requested
- Changes with production impact

## Git Practices

### Branch Management

- Before making file changes, check the current branch with `git branch --show-current`
- If on `master`/`main`, create a feature branch first. If on a branch for unrelated/completed work, ask before creating a new one.
- Pushing to `main` is fine for personal repos (https://github.com/curbol/*). For team/work repos, always use feature branches.
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

The following applies only to Gladly repositories (https://github.com/sagansystems/ internal, https://github.com/gladly/ public).

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
- **## Testing**: Steps to verify the change worked after it's deployed
- **## Release Notes**: Customer-facing impact. If internal-only, write "Internal change, no customer impact."

#### Labels

Apply one of these labels to every PR:
- `bug` for bug fixes
- `enhancement` for new features and enhancements
- `demo` for demo changes
