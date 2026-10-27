# Stacked plans

A stacked plan has more than one subtask, one PR each. GitHub shows only a linear stack, so the PRs stack in id order: subtask `n`'s PR is based on subtask `n-1`'s branch. These rules change the steps in [SKILL.md](SKILL.md).

- **Branch and base.** Subtask `n` uses branch `factory/<KEY>-<n>`. Its base is `origin/main` when its parent is 0, else its parent's branch.
- **Start.** Start each subtask with parent 0 at once, and each other subtask when its parent's branch is pushed. Subtasks that can start run at the same time as background agents.
- **Setup.** Run `bash .agents/skills/factory/scripts/setup-worktree.sh <KEY> <n> <base>`.
- **Prompt.** The work is the ticket for context, the subtask's title, scope and criteria, and `Work only on this subtask.`
- **Rebase.** Keep each subtask's base SHA: `git -C <worktree> merge-base HEAD <base>` after Setup, and the new base SHA after each rebase. When a push adds commits to a branch or rewrites it, send the Builder of each subtask based on that branch: `git rebase --onto origin/<that branch> <base SHA>`, then resolve the conflicts and run the checks again. Then push that subtask again.
- **Restack.** Before the first push of subtask `n > 1`, wait until subtask `n-1` is pushed. If this subtask's base is not subtask `n-1`'s branch, send the Builder the same rebase onto `origin/<subtask n-1 branch>`. Subtask `n-1`'s branch is now this subtask's base and its PR base.
- **Publish.** Add ` (<n>/<subtasks>)` to the PR title, and start the body with `Stacked on <parent PR>.`
- **Stopped.** When a subtask is stopped, the subtasks stacked on it are **skipped**: stop the ones that run, and start none of the others. Continue with the rest.
