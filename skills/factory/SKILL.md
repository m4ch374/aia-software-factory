---
name: factory
description: Run the software factory on one ticket, from plan to PRs that are ready for review. Use only when the user types /factory.
disable-model-invocation: true
---

# Factory

Usage: `/factory <KEY> [ticket text]`, where `<KEY>` is the ticket ID in the form `ABC-123`. If the key is missing, ask for it and stop.

The ticket text is the text after the key. If there is none, get the ticket with a tool that this session has for the user's ticket tracker, and use its title, description and acceptance criteria. If no tool can get it, ask the user to paste the ticket text, and stop.

You are the orchestrator. You never write code or review it. Agents do the judgment, and you move each subtask to the next step. Ask the user only when the key or the ticket text is missing, or for a blocker. Otherwise, do not ask or wait: use your best judgment and continue until every subtask is done, and record each decision in the PR.

| Step | Who | Result |
|---|---|---|
| Plan | `Plan` agent | One or more subtasks, each with a scope, criteria and at most one parent |
| Setup | `setup-worktree.sh` | One worktree and branch per subtask |
| Build | `factory-builder` | Commits that pass the CI checks of each changed service. Ends with `STATUS: READY` or `STATUS: BLOCKED` |
| Review | `factory-reviewer`, run by the pre-push hook | The push goes through on `VERDICT: PASS`, and fails with the findings on `VERDICT: CHANGES` |
| Publish | you | Push and a PR |

## 1. Plan

Spawn a `Plan` agent with this prompt and the ticket text, verbatim:

> Split ticket `<KEY>` into subtasks, one PR per subtask. Read the code in the repository to decide. Do not edit files, commit, or run anything that changes state. Rules: Use one subtask unless the ticket is too big for one PR that a reviewer can read in one sitting. Each subtask is one PR; merged after its parent, each subtask leaves main working. Number the subtasks 1, 2, 3. Subtasks are built at the same time where they can be, then stacked in id order for review, so number them in the order a reviewer reads them. A subtask that cannot be built or tested without the code of another subtask sets parent to that subtask's id, which must be lower than its own. Every other subtask sets parent to 0 and starts from origin/main, even when it changes the same files as another subtask. criteria are the acceptance criteria that the subtask delivers, taken from the ticket; each acceptance criterion belongs to exactly one subtask. End your reply with a JSON array of `{id, parent, title, scope, criteria}`.

Check the ids are 1..n in order and each parent is 0 or a lower id. Show the plan to the user as a table, then continue.

The plan is stacked when it has more than one subtask. Then subtask `n` uses branch `factory/<KEY>-<n>`, else `factory/<KEY>`. A subtask's base is `origin/main`, or its parent's branch. GitHub shows only a linear stack, so before its first push, subtask `n > 1` is stacked on subtask `n-1` (step 2).

## 2. Each subtask

Start a subtask with parent 0 at once, and any other subtask when its parent's branch is pushed. Subtasks that can start run at the same time as background agents.

Keep each subtask's base SHA: `git -C <worktree> merge-base HEAD <base>` after setup, then the new base SHA after each rebase. When a push adds commits to a branch or rewrites it, send the Builder of each subtask whose base is that branch: `git rebase --onto origin/<that branch> <base SHA>`, then resolve the conflicts. Then push that subtask again (step 3). This does not count as a round.

**Setup.** From the repository root, run `bash .agents/skills/factory/scripts/setup-worktree.sh <KEY>` for one subtask, or `bash .agents/skills/factory/scripts/setup-worktree.sh <KEY> <n> <base>` for a stacked subtask. It prints the worktree path and installs the review hook.

Every agent prompt starts with `Ticket: <KEY>. Worktree: <path>. Branch: <branch>. Base: <base>.`, then the work: the ticket text, or for a stacked subtask, the ticket for context, the subtask's title, scope and criteria, and `Work only on this subtask.` Write the work, without the first sentence, to the path that `git -C <worktree> rev-parse --git-path factory-review.md` prints. The review hook reads it.

Keep for each subtask: the round number, the open findings, the Builder's agent id, and a one-line history per round. Put the head SHA in each history line, for example `Round 2 (a1b2c3d): review PASS`. The history goes into the PR body, so the PR holds the state if this session stops. Then run rounds 1 to 5:

1. **Build.** In round 1, spawn `factory-builder` with the prompt and keep its agent id. In later rounds, send the open findings, verbatim, to that agent with `SendMessage`, so it keeps its context. If that agent is gone, spawn a new one with the prompt and the open findings. On `STATUS: BLOCKED`, ask the user, then send their answer to the Builder. This does not count as a round. Then get the head SHA with `git -C <worktree> rev-parse HEAD`.
2. **Stack.** Before the first push of subtask `n > 1`, wait until subtask `n-1` is pushed. If this subtask's base is not subtask `n-1`'s branch, send the Builder: `git rebase --onto origin/<subtask n-1 branch> <base SHA>`, resolve the conflicts, and run the checks again. Subtask `n-1`'s branch is now this subtask's base and its PR base. This does not count as a round.
3. **Push.** In the worktree, run `git push --force-with-lease -u origin <branch>` in the background. Its pre-push hook runs the review, so you never spawn `factory-reviewer`. If the push fails with `VERDICT: CHANGES`, the blockers in its output become the open findings. Start the next round. If it fails for another reason, send the output to the Builder and push again. This does not count as a round. When the push goes through, continue.
4. **Publish.** If the branch has no PR, open one with `gh pr create --assignee @me --base <main or parent branch>`. The title is the subject of the first commit on the branch, plus ` (<n>/<subtasks>)` when stacked. Write the body in the format of `.github/pull_request_template.md`. Fill "How was it tested?" from the Builder's checks. Add a "Factory rounds" section with the history, and start a stacked body with `Stacked on <parent PR>.` If the PR exists, replace its body with `gh pr edit --body-file`. The subtask is done.

When the rounds are used up, push with `FACTORY_REVIEW=off` before `git push`, and open the PR with `--draft`, with the open findings under "Open findings" in its body. Stop or skip the subtasks below it, and continue with the other subtasks.

## Rules

- Give agents only the permissions the user gave in this session. Never touch lock files.
- Only the Builder commits. Never merge or deploy. Push only with `--force-with-lease`, and only to this run's `factory/<KEY>` branches. Set `FACTORY_REVIEW=off` only for the draft push.
- Tell the user one line per step, for example `CB-1872 subtask 2: round 2, review CHANGES (1 blocker) → Builder`.

## Finish

Report one line per subtask: its id, title, status (`ready`, `stopped` or `skipped`), the reason when not ready, and the PR link.
