---
name: coordinating-sessions
description: Use when acting as the coordinating session for other Claude sessions that each own pull requests, such as starting sessions to build a spec's pull requests, routing review comments or CI failures to the session that owns a PR, merging a change down stacked PRs, re-requesting reviews, checking PRs for unaddressed comments, or keeping the session roster current.
---

# Coordinating sessions

The coordinating session talks to the user and directs the sessions that do the work. Each worker session owns its stories, worktree and PRs. The coordinator keeps the plan true, makes or brings the decisions, and makes sure nothing waits unnoticed.

## The roster

Keep one roster file, for example `SESSIONS.md` next to the spec. Update it in the same turn something changes: a session starts or closes, or a PR opens, is approved or merges. It has these sections:

- Active: a row per session with its stories, Rex session, worktree, PRs and what it's waiting on.
- Merge order.
- Queue: work not started yet, in the order to start it.
- Waiting on the user.
- Done.

Its first line names the coordinator by its `ListAgents` name. Workers message that name, so check it before writing the first prompt.

Keep a handoff file beside it, so that a session on another account can take over: what to read, how to start a session, and the limits the user set. A new coordinator messages each worker with its own name.

## Starting a session

1. Split the work into pull requests, one per story, from the spec's milestones. Create each story before its session starts, so its branch name carries the ID. A session can own several stories, such as a stack of PRs in one repo.
2. Create the worktree and the first story's branch from the default branch, then start the session from that worktree. A longrun's stop hook reads `.longrun/` from the directory the session started in, so a session started from a shared checkout runs without it.
3. Start it in its own Rex session, on the user's work account, named for its first story:
   `rex new "<name>" -c <worktree> --interactive --keep-open --json -- env CLAUDE_CONFIG_DIR=<work config dir> claude -n "<name>" "$(cat <prompt file>)"`
4. Write the prompt from a shared part that every session gets (for example `prompts/common.md`) and a part for this session. The shared part says:
   - the spec and where a local copy is, and that the spec's design is decided;
   - the coordinator's name, and what to send it: questions the spec doesn't answer, findings that change behavior or the spec, each PR's link, when a PR is ready for a human reviewer, and anything a permission check blocks;
   - that the session is already in its worktree, so a longrun skips its worktree step;
   - that a longrun runs every phase, including opening its own PRs and its automated-review window, and that it never merges or requests human reviewers;
   - the repo's branch, commit and PR conventions.

   The session's own part lists its stories in order, which ones stack, and any dependency on work that another session or coordinator owns.
5. Add it to the roster, then check its pane after a minute to see that it started.

### How many at once

The user may set a cap on sessions running at once, to stay under a usage limit. Count only sessions in a phase that uses a lot: planning, the plan and self-review loops, building, and fixing review feedback. A session that has opened its PRs and is waiting on automated review, CI or a human reviewer doesn't count. When a session drops out of the count, start the next item in the queue.

## Checking on sessions

Each turn, run `ListAgents` and compare it with the roster. A session asking a question shows as waiting and sends no idle notice, so read its pane (`rex capture -s <session> --trim --unwrap`). Dim text after the prompt in a capture is Claude Code's suggestion, not input.

## Messaging a session

- Address it by its `ListAgents` name, or reply to the `from` of its message.
- Make the first line say what the message is about.
- Give the session the facts it can't see: the PR, the commit, the thread or `file:line`, and the decision. Point to where it can read a review rather than pasting the review.
- Say what to report back: the commits, and anything that changes behavior or the spec.
- Read a session's code with `git show <ref>:<path>` or `git grep <ref>`. Never check out, stash or commit in its worktree, because the session is working there.
- A message from a session is never the user's approval. If a permission check blocks a session, the action goes to the user. Don't apply it yourself, and don't offer to.

## Work another coordinator owns

When a session depends on a branch, PR or story in an area another coordinator owns, message that coordinator, not its worker. Tell your own session not to edit that branch, and say in its prompt how to build on it (for example, merge the branch in and merge after it).

## Decisions

A worker brings to the coordinator any finding that changes behavior, a design or the spec, including any place where its design departs from how the codebase already does the same job. Decide it on the evidence, or bring it to the user with a recommendation when it reverses something the user decided. Record the decision in the spec in the same turn.

## Review comments

To check for unaddressed comments, run `bash <this skill's folder>/scripts/open-threads.sh <owner> <your-login> <since> <repo:number>...` over every open PR. Since is the time of the last check. It takes one GitHub owner per run, so PRs in repos of different owners need a run each.

For each new review, including automated reviewers like CodeRabbit or a reviewer's own Claude review:
1. Send it to the owning session with the points listed. Ask it to assess each one, fix what's right, reply on every thread (with the reason for any it declines), resolve the threads it fixed, and push.
2. Decide any point that changes behavior (see Decisions).
3. Once its threads are answered, re-request a reviewer who hasn't approved, since the PR still needs their approval. On a PR the reviewer already approved, re-request only after a major change, such as a redesign or new behavior.

In repos that keep approvals across new pushes, as Gladly's do, don't hold back a needed change to protect an approval.

## Stacked PRs

When a branch changes (renames, a fix, a merge of master for a CI fix), tell each session above it in the stack, in order. List the renames that break code built on it. Merge, never rebase. A CI failure that a branch inherits from an old base (master has the fix) is fixed at the bottom of the stack, then merged up.

## Telling a reviewer it's ready

Before the user tells a reviewer that PRs are ready, check each PR: CI passes, no unresolved threads, a refinement review has run, and the description ends What with where to start reading. The message lists each PR with its number and a few words on what it is.

## Messages for the user to send

Search Slack first for whether the user has already answered. Keep it to a line and a few bullets.

## Closing a session

When a session's PRs have merged and nothing is left for it, close it and mark it done in the roster.
