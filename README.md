# AIA software factory

A Claude Code skill that takes one task from a grilling session to PRs ready for review. `/factory` grills you on the task, plans the PRs, then runs a Builder agent and a Reviewer agent on each PR until the review passes.

## Requirements

- [Claude Code](https://claude.com/claude-code), with the `claude` CLI on your `PATH`. The pre-push review runs `claude -p`.
- Git 2.54 or later. The review is a config-based `pre-push` hook.
- The [GitHub CLI](https://cli.github.com/) `gh`, signed in.
- For tasks split into stacked PRs, the `gh-stack` extension:

  ```bash
  gh extension install github/gh-stack
  ```

- macOS. The setup script copies `node_modules` with `clonefile`.

## Install

From the root of the repository that the factory will work on:

```bash
curl -fsSL https://raw.githubusercontent.com/m4ch374/aia-software-factory/main/install.sh | bash
```

The repository root must have a `.agents` or a `.claude` folder. The script writes:

| Path | Contents |
|---|---|
| `.agents/skills/factory/`, or `.claude/skills/factory/` when there is no `.agents` | The `/factory` skill and its scripts |
| `.claude/agents/factory-builder.md` | The Builder agent |
| `.claude/agents/factory-reviewer.md` | The Reviewer agent |

To update, run the same command again. When a file is different from the new version, the script asks before it replaces the file.

The Grill step uses the `grilling` skill. When it is missing, `/factory` asks you to install it:

```bash
npx skills@latest add mattpocock/skills --skill grilling -a claude-code
```

## Use

In Claude Code, at the repository root:

```
/factory <task>
```

`<task>` is the task's description, or a ticket key, a URL or a file path that points to it.

To push a factory branch without the review, set `FACTORY_REVIEW=off`.
