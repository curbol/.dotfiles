# Claude Code Configuration

## Interaction Style

When I ask to 'discuss', 'brainstorm', 'think about', or 'talk through' something, DO NOT jump into implementation. Have the conversation first and wait for explicit approval before writing code or making changes.

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

- Git operations (commits, pushes, PR creation) — only when explicitly requested

## Accuracy Standards

- Never assume API signatures, function names, file paths, or infrastructure state — always verify
- Ask when uncertain about business logic or domain rules
- **Don't leap to conclusions**: one piece of evidence does not justify assuming several follow-on things — confirm each step
- **Don't dismiss reported issues**: if someone says there's a problem, verify it rather than concluding "the code looks correct, probably not an issue" — the issue may manifest elsewhere or under different conditions
- **Don't hand-wave unknowns**: don't brush off failures as "probably env/config" without checking — confirm what can be confirmed

## Task Execution

- Ambiguous requests: state your interpretation and ask for confirmation
- Minimal scope: implement the smallest viable solution
- Prefer small, focused changes over large refactors
- Always check locally first — prefer checked-out repos in `~/code/` over web/remote sources

## Testing & Verification

- Write tests for new logic; match the existing test patterns in the repo
- Run existing tests before and after changes to verify no regressions
- On test/build failures: investigate root cause and attempt a fix. If the fix isn't obvious, report findings rather than guessing.

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

- Never push directly to the `master`/`main` branch
- Always work in a feature branch. Create one only if needed.
- Prefix branch names with `<username>/` where <username> is the GitHub username (use `gh api user --jq '.login'` to look it up)
- Base new branches off of `master`/`main` unless specified otherwise
- Always `git pull` after checking out master before creating a new branch

### Commits

- Commit only when requested
- Create new commits to fix mistakes — never amend pushed commits or force push

### Pull Requests

Create PRs only when requested.

#### Title Format

- Imperative mood ("Add", "Fix", "Update", not "Added", "Fixes")
- Capital first letter, no period at end
- Include ticket number at end if provided: `[sc-XXXXXX]`

#### Structure

- **What**: Describe the changes
- **Why**: Explain the motivation
- **Testing**: How to verify the change worked *after* it's deployed
- **Release Notes**: User-facing changes (when applicable)

## Security

- Never commit secrets, credentials, or `.env` files. Warn if asked to.

## Repository Access

- Always check for repos locally in `~/code/` first
- Prefer CLI (`gh` via Bash tool) over MCP tools for GitHub operations

## Architectural Guidance

Primary reference: [Clean Architecture](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)

Apply strictly for new features/services/domain models. Match existing patterns for bug fixes and small enhancements. For refactoring or tech debt, propose improvements and explain trade-offs — don't assume approval.
