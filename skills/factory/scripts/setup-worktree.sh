#!/usr/bin/env bash
set -euo pipefail

key=${1:?usage: .agents/skills/factory/scripts/setup-worktree.sh DEV-123 [part base]}
part=${2:-}
base=${3:-origin/main}
[[ $key =~ ^[A-Z][A-Z0-9]*-[0-9]+$ ]] || { echo "not a Jira key: $key" >&2; exit 1; }
[[ -z $part || $part =~ ^[0-9]+$ ]] || { echo "not a part number: $part" >&2; exit 1; }
[[ $base == origin/main || $base =~ ^factory/$key-[0-9]+$ ]] || { echo "not a factory base: $base" >&2; exit 1; }

name=$key${part:+-$part}
main=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
dir="$main/.claude/worktrees/factory-$name"

if [ ! -d "$dir" ]; then
  git -C "$main" fetch -q origin main
  git -C "$main" worktree add -q -b "factory/$name" "$dir" "$base"
fi
hook=$(cd "$(dirname "$0")" && pwd)/review-pre-push.sh
git -C "$main" config extensions.worktreeConfig true
git -C "$dir" config --worktree hook.factory-review.event pre-push
git -C "$dir" config --worktree hook.factory-review.command "f='$hook'; [ ! -f \"\$f\" ] || exec bash \"\$f\""

agents=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)/.claude/agents
mkdir -p "$dir/.claude/agents"
cp "$agents"/factory-*.md "$dir/.claude/agents/"
printf 'factory-*.md\n.gitignore\n' >"$dir/.claude/agents/.gitignore"

[ "$(git -C "$dir" branch --show-current)" = "factory/$name" ] && git -C "$dir" merge-base --is-ancestor "$base" HEAD ||
  { echo "stale worktree: $dir is not factory/$name on $base" >&2; exit 1; }

find "$main" -maxdepth 3 -path "$main/.claude" -prune -o -name node_modules -type d -prune -print |
  while IFS= read -r m; do
    t=$dir${m#"$main"}
    [ -e "$t" ] || [ ! -d "$(dirname "$t")" ] ||
      python3 -c 'import ctypes, sys; sys.exit(ctypes.CDLL(None).clonefile(sys.argv[1].encode(), sys.argv[2].encode(), 0))' "$m" "$t"
  done

git -C "$main" ls-files -z --others --ignored --exclude-standard -- \
  ':(glob)**/.env*' ':(exclude,glob)**/node_modules/**' |
  while IFS= read -r -d '' f; do
    [ -f "$main/$f" ] && [ ! -e "$dir/$f" ] || continue
    mkdir -p "$dir/$(dirname "$f")"
    cp "$main/$f" "$dir/$f"
  done

echo "$dir"
