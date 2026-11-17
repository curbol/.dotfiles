---
name: refinement-review
description: Use before opening a pull request or pushing new commits to one, when a reviewer says code is hard to follow, names are unclear or it doesn't match how the codebase does things, or when asked whether code, or a spec, design doc, PR description or message, reads clearly to someone new to it. Reviews naming, structure, comments, fit with existing patterns, and prose; not correctness or tests.
---

# Refinement review

A reviewer who hasn't seen the spec, the story or the conversation behind a change reads it one function at a time, trusting the names of what each function calls, and compares it with how the code around it already does things. This review reads a change, or a document, the way that reviewer will. It raises things to consider, weighed against the repository's context; none of it is a rule. It doesn't check correctness or tests.

The session that wrote the code or the document already knows what its names mean and why it chose its approach, so it can't judge them. The review runs in a fresh agent, which reads only `review-guide.md` in this directory.

## Steps

1. Work out the target: a PR number or URL, a branch, a commit range, or a document. By default it's the current branch against the repository's default branch. A document is reviewed from a local file; fetch a Notion page or other remote document to a file first.
2. Start one Agent (general-purpose, not a fork) with only one of these prompts, filled in.

   For code:

   > Review <target> in <repository path>. Follow <absolute path of review-guide.md>. Get the change with `git diff` or `gh pr diff`, and read each changed file in full, with the code around it, before judging. Search the repository for existing code that does the same jobs as the change's new mechanisms, and read the repository's own guidance (CLAUDE.md, AGENTS.md, contributing docs) for patterns it prefers or is moving away from. Don't read the PR's review comments, don't post anything, and don't start subagents.

   For a document:

   > Review the document at <absolute path>. Follow <absolute path of review-guide.md>, including its Documents section. Read the whole document before judging. Don't post anything, don't edit any file, and don't start subagents.

3. Treat the findings the way you'd treat a colleague's suggestions: judge each on its merits in this repository, never apply one because the review raised it. Apply the ones that make the code or document clearer or fit the codebase better. Skip any that would make it worse, go against the codebase's or document's conventions, or ask for consistency with a pattern that doesn't suit this case, and say which you skipped and why. A finding that states how the code or system works (what a name means, what a field holds, where something is declared, what pattern the codebase uses) is a claim: check it against the code before applying it or its suggested fix.
