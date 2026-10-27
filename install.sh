#!/usr/bin/env bash
set -euo pipefail

repo=${FACTORY_REPO:-https://github.com/m4ch374/aia-software-factory.git}

die() { printf 'install: %s\n' "$*" >&2; exit 1; }

if [ -d .agents ]; then skills=.agents/skills
elif [ -d .claude ]; then skills=.claude/skills
else die "no .agents or .claude folder in $PWD"; fi

src=$(cd "$(dirname "${BASH_SOURCE[0]:-}")" && pwd)
if [ ! -f "$src/skills/factory/SKILL.md" ]; then
  src=$(mktemp -d)
  trap 'rm -rf "$src"' EXIT
  git clone -q --depth 1 "$repo" "$src" || die "cannot clone $repo"
fi

copy() {
  local from=$1 to=$2 answer
  if [ -e "$to" ]; then
    cmp -s "$from" "$to" && return
    read -rp "install: replace $to? [y/N] " answer </dev/tty || answer=n
    [[ $answer == [yY]* ]] || { printf 'install: kept %s\n' "$to" >&2; return; }
  fi
  mkdir -p "$(dirname "$to")"
  cp "$from" "$to"
  printf 'install: wrote %s\n' "$to" >&2
}

while IFS= read -r f; do copy "$src/skills/$f" "$skills/$f"; done < <(cd "$src/skills" && find factory -type f)
for f in "$src"/agents/*.md; do copy "$f" ".claude/agents/${f##*/}"; done
git -C "$src" rev-parse HEAD >"$skills/factory/BASE"
