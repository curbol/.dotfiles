---
name: pr-walkthrough
description: Use when the user wants to be walked through a pull request's code, or a stack of PRs, to understand what it does and how its code paths connect, with the code shown in a Neovim pane beside the chat.
---

# Walking through a PR

The user didn't write the code and may not know these parts of the codebase. Show each piece of code in a read-only Neovim pane beside the chat and explain it in the chat, one stop at a time, so they never have to hunt through calls themselves. This is read-only: change no code and post nothing.

## Setup

1. Make a detached worktree at the PR's head, so nobody's working copy is involved:
   `git -C <repo> fetch -q origin && git -C <repo> worktree add --detach ~/code/worktrees/walkthrough-<pr> origin/<head branch>`
   The PR's own changes are `git diff <merge-base>...HEAD`, where the merge base is `git merge-base origin/<base branch> HEAD`. Use the merge base, not the base branch's tip, which can show changes the PR doesn't make. Never check out branches in the user's own checkout.
2. Read the PR description (`env -u GITHUB_TOKEN gh pr view <pr>`), the diff, and enough code around it to plan the stops. Start from the description's "Where to start reading" if it has one, then follow the calls a reader would follow: the route, the top-level action, then each helper in call order. Show the plan as a short numbered list before the first stop.
3. Open a dedicated read-only Neovim in a Rex split beside the chat, in the same tab:
   `rex split -s "$REX_SESSION" -b "$REX_BLOCK" --split=right --ratio 60 --label Walkthrough --focus=false -c <worktree> --json -- nvim -R --listen <scratchpad>/walk.sock <first file>`
   Use your own instance, not one of the user's. You own it, so `:only`, splits and `:qa!` are safe in it.
4. If the user's config has gitsigns, color the PR's changes: run `:Gitsigns change_base <merge-base> true` and `:Gitsigns toggle_linehl true`. Run `change_base` again in each window after opening a file there, because a file opened later doesn't always pick up the global base.

## Driving Neovim

Send keys with `nvim --server <sock> --remote-send '<keys>'`, starting with `<C-\><C-N>`, and read state with `--remote-expr`.
- Open a file with `:e <path>`, jump with `:<line>`, and center with `zz` on a line in the middle of the code you're showing. The user's `scrolloff` can push `zt` far off, so check the view with `line('w0', win)` and `line('w$', win)`.
- Mark the lines you're talking about with `:call matchaddpos('Underlined', [lines])`, which stays readable over diff colors. Matches belong to a window, so run `:call clearmatches()` in each window before the next stop.
- To show a caller and a callee together, use `:rightbelow vsplit <file>`: the caller stays on the left. For a third function, use `:rightbelow split`.
- When listing windows, skip floating ones (`nvim_win_get_config(w).relative != ''`), which plugins like scrollview and noice create.
- A new pane reports 24x80 until it's drawn, so read its size only after the user has looked at it.

## Each stop

- Say which file and function you're showing, and give the line numbers in the message (for example "**1362:** ..."), matching the lines you underlined.
- Say what the code does and why, in a few plain sentences: the problem each piece solves, not a line-by-line reading. Then wait for "go on" or a question.
- When the code calls something that matters, show the callee, then come back.
- Answer questions from the code you've read, and compare with the default branch when the question is what changed. A small concrete example (v4.2 versus v4.3) often helps.
- For code you haven't opened, such as another repository's, say "I haven't read X" instead of describing it. If you said something wrong, correct it at the start of the next stop.
- If the user asks you to pass feedback to the PR's owner or a coordinating session, send it.

## When the PR changes

PRs often change during a walkthrough. When the user asks to refresh:
1. `git fetch` and `git checkout --detach origin/<head branch>` in the worktree.
2. Find the line numbers again (`grep -n`); don't reuse earlier ones.
3. Restart Neovim: `:qa!` through the socket, remove the socket file, and run the `rex split` again. Do the same when the user changes their Neovim config. A "connection refused" from a pane that already closed is harmless.
4. Put the view back where you were.

## A stack of PRs

Walk the PRs in merge order, each against its own base. Use a new worktree and a new merge base for each, and reuse the same pane.

## At the end

Offer a short summary. When the user says they're done, close the pane with `:qa!` and remove the worktree with `git -C <repo> worktree remove ~/code/worktrees/walkthrough-<pr>`.
