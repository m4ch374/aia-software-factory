#!/usr/bin/env bash
set -euo pipefail

msg=${1:?usage: publish.sh "commit message"}
repo=${FACTORY_REPO:-https://github.com/m4ch374/aia-software-factory.git}
skill=$(cd "$(dirname "$0")/.." && pwd)
root=$(git -C "$skill" rev-parse --show-toplevel)

die() { printf 'publish: %s\n' "$*" >&2; exit 1; }

[ -f "$skill/BASE" ] || die "$skill/BASE is missing; run install.sh first"
base=$(cat "$skill/BASE")

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
git clone -q "$repo" "$tmp" || die "cannot clone $repo"
git -C "$tmp" checkout -q "$base"

rsync -a --delete --exclude BASE "$skill/" "$tmp/skills/factory/"
cp "$root"/.claude/agents/factory-*.md "$tmp/agents/"

git -C "$tmp" add -A
git -C "$tmp" diff --cached --quiet && { printf 'publish: no changes\n' >&2; exit 0; }
git -C "$tmp" diff --cached --stat
git -C "$tmp" commit -qm "$msg"
if ! git -C "$tmp" rebase -q origin/main; then
  trap - EXIT
  die "your changes conflict with newer ones on main; resolve them in $tmp, then run: git -C $tmp rebase --continue && git -C $tmp push origin HEAD:main, then run install.sh"
fi
git -C "$tmp" push -q origin HEAD:main

rsync -a --delete --exclude BASE "$tmp/skills/factory/" "$skill/"
cp "$tmp"/agents/factory-*.md "$root/.claude/agents/"
git -C "$tmp" rev-parse HEAD >"$skill/BASE"
printf 'publish: pushed %s\n' "$(git -C "$tmp" rev-parse --short HEAD)" >&2
