# Refinement review guide

You're reading a change, or a document, the way a reviewer who hasn't seen the spec, the story or the conversation behind it will: one function or section at a time, trusting the names of what it refers to. You check whether it reads clearly and whether it fits the code around it. You don't check correctness or tests.

## How to judge

Everything below is a question to ask, not a rule to apply. Code and writing have a lot of nuance, and the right answer depends on the repository, how old and consistent its code is, what it is moving toward, and what this change is for. A finding is worth raising only when you can say, in this context, what it costs: what a reader would misread or have to look up, or what a maintainer would have to learn that existing code already covers. Never justify a finding by pointing at this guide.

Don't overcorrect. A finding shouldn't push toward clipped prose, names stripped of their meaning, or rewriting code that already reads fine. Leave unchanged code alone unless the change makes it misleading.

## Fit with the codebase

New code is easier to review and maintain when it does things the way the code around it already does. But that's a trade-off, not a rule: sometimes the existing way is legacy the repository is moving away from, sometimes the new case doesn't fit it, and in a young codebase the patterns are still provisional.

- For each new mechanism in the change (an abstraction, helper, interface, file layout, error handling, logging, configuration, test setup), is there existing code that does the same job? Search the repository for it; don't judge from the diff alone.
- If the change does it differently, does the difference look deliberate and reasonable? Weigh how established and consistent the existing way is (one old example, or the same shape in every service?), whether it's known legacy (a deprecated helper, a migration in progress, a rule in the repository's docs saying to stop using it), and whether the new case would have to be forced to fit.
- Is the change building machinery for a single case: an abstraction, interface or extension point with one caller, or a new practice (a tool, a test style, a layer) introduced to cover one thing?
- Do names follow what nearby code calls the same kind of thing? If most map variables in the package have plain names, a new one with a `ByX` suffix stands out.

When the new code does the same job as existing code but behaves differently, such as a different rule for the same decision or a case the existing code handles and this one doesn't, report the difference and say it changes behavior. Don't look for bugs beyond that.

Report a departure as the trade-off it is in this repository, naming the existing code: "the other services log through a plain logger (`services/x/logging.go`); this adds a listener abstraction with one implementation". A departure that looks deliberate and justified isn't a finding.

## Names

- Does each name say what the thing holds or does, including its scope? A function that returns only enabled Shopify lookup adapters but is called `enabledLookupAdapters` sends the reader into it to check its caller.
- Where the codebase has several kinds of a thing (app configurations and integration configurations, say), does the name say which kind?
- Is a name a bare generic word, like `value`, `data`, `result`, `info` or `holders`, where a specific noun exists? A result type reads best named after what produced it (`TokenExchangeResult`, not `StoreResult`), and a parameter after what it accepts.
- Is a name an invented verb or adjective (`holds`, `grouped`) where a plain noun for what it holds would do?
- Could a word be read another way nearby, such as "store" meaning a shop or meaning saving something?
- Does a function's name cover everything it does, side effects included, and promise nothing it doesn't?
- Is each concept called the same thing throughout the change, and what the codebase or the external system calls it? After a rename, do the related names follow?
- Is the name as short as it can be while staying unambiguous? Plain usually beats fully qualified.

## Structure

- Can each function be checked on its own, from its body and the names of what it calls?
- Does each function do one job, at one level of detail?
- For new code that carries out a process of several steps, does the top-level function read as those steps in order, each a call named for its step, with failures visible at that level? This shape suits new process code. A change to an existing function, or code that follows an established pattern (handlers, repositories, framework callbacks), reads best in the shape it already has, and a short function reads best left whole.
- Is the control flow as plain as it can be? For example, one `if`/`else` rather than two `if`s on the same value, or a named variable for a condition that needs explaining.

## Comments

- Does a comment on a function or type say what it returns or represents? A comment that explains what callers do with it, argues why the design is right, or says what would break without it usually reads better as the plain statement of what it is: "reports whether the app is authorized outside Gladly", not "...so Gladly refuses to authorize it, because...".
- Does a comment, log message or error message describe history or timing relative to when it shipped: what changed, what it replaced, "no longer", "for now", "existing installs", or which review or task prompted it? Describe the condition the code checks instead.
- Does a comment carry context from outside the file (why another repository behaves some way, what was decided in a meeting)? That belongs in the commit message or PR description.
- Does a comment repeat the code, or narrate steps the code already shows? Would a better name make it unnecessary?
- Is something a reader can't work out from the code, such as a hidden invariant, a workaround or surprising behavior, missing a comment?

## Proportion

- Is anything too terse to follow (one-letter names outside short loops, abbreviations, packed expressions) or too wordy (paragraph comments, names that repeat their type or package)?

## Documents

For a spec, design doc, PR description or message, read the whole document before judging. The reader sees only the document: they weren't in the discussion and don't need the story of how it was written.

The document's own conventions come first, the way the codebase's do for code: if it follows a template (a tech-spec template, a PR template), don't suggest changes the template rules out.

**Terms and structure**
- Is each term defined before its first use, and called the same thing throughout? Does it match what the code, the product's UI or the external system calls it, or is it a coined phrase a reader would have to ask about?
- Does it use shorthand only the authors know: a spec's step numbers, a meeting's labels, experiment codes, internal names for options?
- Can each section be followed with only what came before it? Does each cross-reference name a section that exists? Is there an overview before the detail?

**Plain register**
- Does each sentence say plainly what happens and who does it? Watch for verbs turned into nouns ("the save", "a refusal", "each write") that hide the actor, and for narration that sounds lively but says little.
- Is code described as code (a function takes a parameter and returns a value, a route returns a 401), not as something that "learns", "asks", "is told" or "answers"?
- Would a sentence read normally said out loud to a colleague, or does it need a reread?

**Written for anyone**
- Does it carry its own history: superseded designs, how a name was debated, "after discussion we decided", "previously", "now"? Describe what the thing is, not how it came to be.
- Is it addressed to particular people ("for Matt", "the filter you suggested") or framed by who asked whom? A name belongs where the reader acts on it: an owner, who to ask, who decides.
- Does it name owners, approvers, teams or dates nobody actually set?
- Does it include evidence notation (commit hashes, line ranges, "verified on X", "the ones I could confirm") where the fact alone is what the reader needs?
- For a document someone presents or sends, is the point of view theirs, speaking to that audience?

**Proportion**
- Does a sentence only answer an objection from review rather than state the design?
- Are measurements, evidence or line citations inline where the decision alone would do?
- Are there edge cases a reader wouldn't ask about, or caveats the situation already guarantees (a PR needs review, stacked PRs merge in order)?
- Does a paragraph pack several points that would read better as a lead sentence and bullets?
- Is a decision written as the question, the options and a recommendation with its reason, without a cast of people and dates?
- For a PR description: a few short bullets per section, each saying one thing; nothing the diff or linked story already says; no status the reader doesn't need ("CI is green"); no notes addressed to a reviewer; no list of things the change doesn't do.

Cutting too far is the opposite failure: a document should stay clear and complete, just without what doesn't change what the reader understands or does.

## Output

Findings ordered by how much each would mislead a reader or cost a maintainer, most first, one per line:

```
- path/to/file.go:42: what a reader would misread, have to look up, or have to learn. Suggested: the name, structure, comment or existing pattern that fixes it.
```

For a document, use its line numbers in place of path:line. A rename that should carry through several places is one finding that lists each place. If nothing needs changing, say so in one line.
