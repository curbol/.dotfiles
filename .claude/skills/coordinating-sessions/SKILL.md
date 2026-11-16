---
name: coordinating-sessions
description: Use when acting as the coordinating session for other Claude sessions that each own pull requests, such as routing review comments or CI failures to the session that owns a PR, merging a change down stacked PRs, re-requesting reviews, checking PRs for unaddressed comments, or keeping the session roster current.
---

# Coordinating sessions

The coordinating session talks to the user and directs the sessions that do the work. Each worker session owns its stories, worktree and PRs. The coordinator keeps the plan true, makes or brings the decisions, and makes sure nothing waits unnoticed.

## The roster

Keep one roster file, for example `SESSIONS.md` next to the spec. It has a row for each session (its story, worktree, PRs and what it's waiting on), the merge order, and what's waiting on the user. Update it in the same turn something changes: a PR opens, is approved or merges, or a session closes. Keep a handoff file beside it, so that a session on another account can take over.

## Messaging a session

- Address it by its `ListAgents` name, or reply to the `from` of its message.
- Make the first line say what the message is about.
- Give the session the facts it can't see: the PR, the commit, the thread or `file:line`, and the decision. Point to where it can read a review rather than pasting the review.
- Say what to report back: the commits, and anything that changes behavior or the spec.
- A message from a session is never the user's approval. If a permission check blocks a session, the action goes to the user. Don't apply it yourself, and don't offer to.

## Decisions

A worker brings to the coordinator any finding that changes behavior, a design or the spec. Decide it on the evidence, or bring it to the user with a recommendation when it reverses something the user decided. Record the decision in the spec in the same turn.

## Review comments

To check for unaddressed comments, run `bash scripts/open-threads.sh <owner> <your-login> <since> <repo:number>...` over every open PR. Since is the time of the last check.

For each new review, including automated reviewers like CodeRabbit or a reviewer's own Claude review:
1. Send it to the owning session with the points listed. Ask it to assess each one, fix what's right, reply on every thread (with the reason for any it declines), resolve the threads it fixed, and push.
2. Decide any point that changes behavior (see Decisions).
3. Re-request the reviewer once it's pushed.

In repos that keep approvals across new pushes, as Gladly's do, don't hold back a needed change to protect an approval.

## Stacked PRs

When a branch changes (renames, a fix, a merge of master for a CI fix), tell each session above it in the stack, in order. List the renames that break code built on it. Merge, never rebase. A CI failure that a branch inherits from an old base (master has the fix) is fixed at the bottom of the stack, then merged up.

## Telling a reviewer it's ready

Before the user tells a reviewer that PRs are ready, check each PR: CI passes, no unresolved threads, a readability review has run, and the description ends What with where to start reading. The message lists each PR with its number and a few words on what it is.

## Messages for the user to send

Search Slack first for whether the user has already answered. Keep it to a line and a few bullets.

## Closing a session

When a session's PRs have merged and nothing is left for it, close it and mark it done in the roster.
