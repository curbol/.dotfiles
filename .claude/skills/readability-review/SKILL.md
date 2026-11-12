---
name: readability-review
description: Use before opening a pull request or pushing new commits to one, when a reviewer says code is hard to follow or names are unclear, or when asked whether code reads clearly to someone new to it.
---

# Readability review

A reviewer who hasn't seen the spec, the story or the conversation behind a change reads it one function at a time, trusting the names of what each function calls. This review reads a change the way that reviewer will. It doesn't check correctness, design or tests.

The session that wrote the code already knows what its names mean, so it can't judge them. The review runs in a fresh agent.

## Steps

1. Work out the target: a PR number or URL, a branch, or a commit range. By default it's the current branch against the repository's default branch.
2. Start one Agent (general-purpose, not a fork) with only this prompt, filled in:

   > Review <target> in <repository path> for readability. Follow the "Considerations" and "Output" sections of <absolute path of this SKILL.md>. Get the change with `git diff` or `gh pr diff`, and read each changed file in full, with the code around it, before judging. Don't read the PR's review comments, don't post anything, and don't start subagents.

3. Treat the findings the way you'd treat a colleague's suggestions. Apply the ones that make the code clearer. Skip any that would make it worse or go against the codebase's conventions, and say which you skipped and why.

## Considerations

These are questions to ask, not rules to apply. Suggest a change only when you can say what a reader would misread, or would have to go and look up, without it. The codebase's existing names, structure and patterns come first: match them, and leave unchanged code alone unless the change makes it misleading.

### Names

- Does each name say what the thing holds or does, including its scope? A function that returns only enabled Shopify lookup adapters but is called `enabledLookupAdapters` sends the reader into it to check its caller.
- Where the codebase has several kinds of a thing (app configurations and integration configurations, say), does the name say which kind?
- Is a name a bare generic word, like `value`, `data`, `result`, `info` or `holders`, where a specific noun exists? A result type reads best named after what produced it (`TokenExchangeResult`, not `StoreResult`), and a parameter after what it accepts.
- Could a word be read another way nearby, such as "store" meaning a shop or meaning saving something?
- Does a function's name cover everything it does, side effects included, and promise nothing it doesn't?
- Is each concept called the same thing throughout the change, and what the codebase or the external system calls it? After a rename, do the related names follow?
- Is the name as short as it can be while staying unambiguous?

### Structure

- Can each function be checked on its own, from its body and the names of what it calls?
- Does each function do one job, at one level of detail?
- For new code that carries out a process of several steps, does the top-level function read as those steps in order, each a call named for its step, with failures visible at that level? Does each step do the same one level down? This shape suits new process code. A change to an existing function, or code that follows an established pattern (handlers, repositories, framework callbacks), reads best in the shape it already has, and a short function reads best left whole.
- Is the control flow as plain as it can be? For example, one `if`/`else` rather than two `if`s on the same value, or a named variable for a condition that needs explaining.

### Comments

- Does a comment on a function or type say what it returns or represents? A comment that explains what callers do with it, argues why the design is right, or says what would break without it usually reads better as the plain statement of what it is: "reports whether the app is authorized outside Gladly", not "...so Gladly refuses to authorize it, because...".
- Does a comment describe history: what changed, what it replaced, what was fixed, or which review or task prompted it?
- Does a comment repeat the code, or narrate steps the code already shows? Would a better name make it unnecessary?
- Is something a reader can't work out from the code, such as a hidden invariant, a workaround or surprising behavior, missing a comment?

### Proportion

- Is anything too terse to follow (one-letter names outside short loops, abbreviations, packed expressions) or too wordy (paragraph comments, names that repeat their type or package)?

## Output

Findings in the order of the diff, one per line:

```
- path/to/file.go:42: what a reader would misread or have to look up. Suggested: the name, structure or comment that fixes it.
```

A rename that should carry through several places is one finding that lists each place. If nothing needs changing, say so in one line.
