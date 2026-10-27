---
name: factory
description: Run the software factory on one ticket, from plan to PRs that are ready for review.
disable-model-invocation: true
---

# Factory

Usage: `/factory <KEY> [ticket text]`, where `<KEY>` is the ticket ID, such as `ABC-123`.

You are the orchestrator: agents write and review the code, and you move each subtask through its steps until the run is done. Run autonomously, and record each decision you make in the PR. Ask the user in three cases only, and wait for the answer:

- The key is missing.
- The message has no ticket text, and no tool in this session can get the ticket from the user's tracker. With such a tool, use the ticket's title, description and acceptance criteria.
- A step cannot continue without a person, such as a Builder's `STATUS: BLOCKED`, or a push or PR that GitHub refuses. Continue that step with the answer, and send it to the agent that asked.

## 1. Plan

Spawn a `Plan` agent with this prompt, then the ticket text verbatim:

> Split ticket `<KEY>` into subtasks, one PR per subtask. Estimate the lines the ticket changes, without tests, generated files and lock files. Use one subtask when the estimate is 300 lines or less. Above 300, split by service first: one subtask per service that the ticket changes, such as one for `client/` and one for `legal-frontdoor/`. When one service still has more than 300 lines, split its work into vertical slices: each slice delivers one acceptance criterion, or a usable part of one, through every layer it needs, never one layer such as all the models or all the routes. Each subtask, merged after its parent, leaves main working. Subtasks are built at the same time where they can be, then stacked in id order for review, so number them 1, 2, 3 in the order a reviewer reads them. A subtask that cannot be built or tested without the code of another subtask sets parent to that subtask's id, which is lower than its own. Every other subtask sets parent to 0 and starts from origin/main, even when it changes the same files as another subtask. criteria are the ticket's acceptance criteria that the subtask delivers; each criterion belongs to exactly one subtask. End your reply with a JSON array of `{id, parent, title, scope, criteria}`.

The plan is done when the ids are 1..n in order and each parent is 0 or a lower id. Show it to the user as a table, then continue. A plan with more than one subtask is **stacked**: read [stacked.md](stacked.md) now, and apply it to every step below.

## 2. Each subtask

**Setup.** From the repository root, run `bash .agents/skills/factory/scripts/setup-worktree.sh <KEY>`. It prints the worktree path and installs the review hook. The branch is `factory/<KEY>`, and the base is `origin/main`.

**Prompt.** Every agent prompt is `Ticket: <KEY>. Worktree: <path>. Branch: <branch>. Base: <base>.`, then the **work**: the ticket text. Write the work to the path that `git -C <worktree> rev-parse --git-path factory-review.md` prints. The review hook reads it from there.

**State.** Keep for each subtask: the round number, the open findings, the Builder's agent id, and one history line per round with the head SHA, such as `Round 2 (a1b2c3d): review PASS`. The history goes into the PR body, so the PR holds the state if this session stops.

A **round** is one Build and one push. Run rounds 1 to 5. A user's answer, a rebase and a push retry stay inside the current round. When round 5 ends without a pass, the subtask is **stopped**: publish it as a draft PR with the open findings under "Open findings" in its body. Its push skips the review, with `FACTORY_REVIEW=off`.

1. **Build.** In round 1, spawn `factory-builder` with the prompt and keep its agent id. In later rounds, send the open findings, verbatim, to that agent with `SendMessage`, so it keeps its context. If that agent is gone, spawn a new one with the prompt and the open findings. The Build is done on `STATUS: READY`. Record the head SHA from `git -C <worktree> rev-parse HEAD`.
2. **Push.** In the worktree, run `git push --force-with-lease -u origin <branch>` in the background. Its pre-push hook runs `factory-reviewer`. When the push fails with `VERDICT: CHANGES`, the blockers in its output become the open findings: start the next round. When it fails for another reason, send the output to the Builder and push again. The Push is done when it goes through.
3. **Publish.** Open a PR with `gh pr create --assignee @me --base <base branch>`, or replace the body of the existing PR with `gh pr edit --body-file`. The title is the subject of the first commit on the branch. Write the body in the format of `.github/pull_request_template.md`, fill "How was it tested?" from the Builder's checks, and add a "Factory rounds" section with the history. The subtask is **ready**.

## Rules

- The Builder makes every commit. Push only to this run's `factory/<KEY>` branches. Merges and deploys belong to people.
- Tell the user one line per step, such as `CB-1872 subtask 2: round 2, review CHANGES (1 blocker) → Builder`.

## Finish

The run is done when every subtask is ready, stopped or skipped. Report one line per subtask: its id, title, status, the reason when not ready, and the PR link.
