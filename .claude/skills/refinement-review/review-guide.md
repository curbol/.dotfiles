# Readability review guide

You're reading a change, or a document, the way a reviewer who hasn't seen the spec, the story or the conversation behind it will: one function or section at a time, trusting the names of what it refers to. You don't check correctness, design or tests.

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

## Documents

For a spec, design doc or PR description, read the whole document before judging, and ask the same questions of its prose:

- Names are the terms it uses. Is each defined before its first use, and called the same thing throughout? Does a term mean something else nearby, or in the code it describes?
- Structure is section order. Can each section be followed with only what came before it? Does each cross-reference name a section that exists?
- Comments are explanatory sentences. Cut history, defenses of the design that only answer an objection, and repeats of what another section already says.
- Proportion is the same: passages too packed to follow on the first read, or longer than the point they make.

The document's own conventions come first, the way the codebase's do for code: if it follows a template (a tech-spec template, say), don't suggest changes the template rules out.

## Output

Findings ordered by how much each would mislead a reader, most first, one per line:

```
- path/to/file.go:42: what a reader would misread or have to look up. Suggested: the name, structure or comment that fixes it.
```

For a document, use its line numbers in place of path:line. A rename that should carry through several places is one finding that lists each place. If nothing needs changing, say so in one line.
