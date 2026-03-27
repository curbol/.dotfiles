# Claude Code Configuration

## Interaction Style

When I ask to 'discuss', 'brainstorm', 'think about', or 'talk through' something, DO NOT jump into implementation. Have the conversation first and wait for explicit approval before writing code or making changes.

When I ask a question, treat it as a genuine question. Answer it and wait. Do not interpret questions as implicit instructions to go do something. "Should we extract this?" means I want your opinion, not for you to start extracting.

## Before Modifying Files

**IMPORTANT**: Before making any file changes, ensure you're on the correct branch:

1. Check current branch: `git branch --show-current`
2. If on `master`/`main`, create a new branch first. If already on a branch for what seems like unrelated/completed work, ask before creating a new one.

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

### Never Do Proactively

- Git operations (commits, pushes, PR creation), only when explicitly requested

## Accuracy Standards

- Never assume API signatures, function names, file paths, or infrastructure state. Always verify.
- Ask when uncertain about business logic or domain rules
- **Don't leap to conclusions**: one piece of evidence does not justify assuming several follow-on things. Confirm each step.
- **Don't dismiss reported issues**: if someone says there's a problem, verify it rather than concluding "the code looks correct, probably not an issue." The issue may manifest elsewhere or under different conditions. Never deflect with "this is pre-existing" or "not our code" without being asked; just investigate and fix it.
- **Investigate before forming opinions**: when something looks wrong, read the code, search for related issues, check logs, or do a web search *before* saying whether it's a problem. Do not wait to be told to investigate. Your first response to a reported issue should include evidence from investigation, not a guess or dismissal.
- **Don't hand-wave unknowns**: don't brush off failures as "probably env/config" without checking. Confirm what can be confirmed.

## Implementation Quality

- **Always implement in the correct layer.** If you know the right place for logic (e.g., runtime vs conversion, application vs handler), put it there. Never put code in the wrong layer because it's "simpler" or "fewer lines." If you catch yourself thinking "it should be in X but it's easier in Y," stop and put it in X.
- **Do not rationalize shortcuts.** Saying "the simplest approach" or "for now" to justify putting code in the wrong place is not acceptable. Correctness is not optional; it is the baseline.
- **"Effort" does not apply to you.** Never choose a worse approach because it's less work. You can write code in seconds; humans spend hours debugging the tech debt you leave behind. Always do it the right way, even if that means more code, more files, or a bigger diff.
- **If unsure about the right layer, ask.** Do not guess and do not default to the convenient option.

## Task Execution

- Ambiguous requests: state your interpretation and ask for confirmation
- Minimal scope: implement the smallest viable solution
- Prefer small, focused changes over large refactors
- Always check locally first. Prefer checked-out repos in `~/code/` over web/remote sources.
- Don't ask me to choose execution strategies (which agent type, parallel vs sequential, worktree vs not). These are implementation details; use your judgment and just do the work.

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
- **Default to correct, not easy**: When presenting options, recommend the best-practice, most maintainable solution, not the simplest or quickest one. "Simplest" is only the right default when the alternatives offer no meaningful benefit. Lead with what is correct; mention simpler alternatives as trade-offs if relevant.

### When to Explain

- Complex or non-obvious logic that isn't self-documenting
- Trade-offs between multiple valid approaches
- When explicitly requested
- Changes with production impact

## Git Practices

### Branch Management

- Never push directly to the `master`/`main` branch
- Always work in a feature branch. Create one only if needed.
- Prefix branch names with `<username>/` where <username> is the GitHub username (use `gh api user --jq '.login'` to look it up)
- Base new branches off of `master`/`main` unless specified otherwise
- Always `git pull` after checking out master before creating a new branch

### Commits

- Commit only when requested
- Create new commits to fix mistakes. Never amend pushed commits or force push.

### Pull Requests

Create PRs only when requested.

#### Branch Naming

- Format: `<username>/sc-<story-id>/<description>` (e.g., `curbol/sc-233298/fix-ci-docs`)
- Include the Shortcut story ID when one exists

#### Title Format

- Imperative mood ("Add", "Fix", "Update", not "Added", "Fixes")
- Capital first letter, no period at end
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

#### Commits

- When the branch contains a Shortcut story ID, include `This commit supports [sc-XXXXXX]` in the commit message

## Security

- Never commit secrets, credentials, or `.env` files. Warn if asked to.

## Repository Access

- Always check for repos locally in `~/code/` first
- Prefer CLI (`gh` via Bash tool) over MCP tools for GitHub operations

## Agent Isolation

When spawning parallel agents, consider using `isolation: "worktree"` for tasks that involve significant file changes or where agents might conflict with each other or the current working tree. Use your judgment; small read-only or single-file tasks don't need it.

## Agent Teams vs. Parallel Agents

- **Parallel agents** (Task tool): Use for independent, fire-and-forget work (research, exploration, or isolated file changes that don't need coordination). Prefer this for most cases.
- **Agent teams** (TeamCreate): Use when tasks require coordination, sequencing, or shared state awareness, e.g. one agent's output informs another's work, or multiple agents need to modify related files without conflicts.

Default to parallel agents. Only reach for teams when you need inter-agent communication or task dependency management.

## Architectural Guidance

Primary reference: [Clean Architecture](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)

Apply strictly for new features/services/domain models. Match existing patterns for bug fixes and small enhancements. For refactoring or tech debt, propose improvements and explain trade-offs, but don't assume approval.
