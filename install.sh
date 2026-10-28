#!/usr/bin/env bash
set -euo pipefail

repo=${FACTORY_REPO:-https://github.com/m4ch374/aia-software-factory.git}
home=${FACTORY_HOME:-$HOME/Development/aia-software-factory}

die() { printf 'install: %s\n' "$*" >&2; exit 1; }

if [ -d .agents ]; then skills=.agents/skills
elif [ -d .claude ]; then skills=.claude/skills
else die "no .agents or .claude folder in $PWD"; fi

src=$(cd "$(dirname "${BASH_SOURCE[0]:-}")" && pwd)
if [ ! -f "$src/skills/factory/SKILL.md" ]; then
  src=$home
  [ -d "$src/.git" ] || git clone -q "$repo" "$src" || die "cannot clone $repo"
fi

link() {
  local from=$1 to=$2 answer
  [ "$(readlink "$to")" = "$from" ] && return
  if [ -e "$to" ] || [ -L "$to" ]; then
    read -rp "install: replace $to? [y/N] " answer </dev/tty || answer=n
    [[ $answer == [yY]* ]] || { printf 'install: kept %s\n' "$to" >&2; return; }
    rm -rf "$to"
  fi
  mkdir -p "$(dirname "$to")"
  ln -s "$from" "$to"
  printf 'install: linked %s\n' "$to" >&2
}

link "$src/skills/factory" "$skills/factory"
for f in "$src"/agents/*.md; do link "$f" ".claude/agents/${f##*/}"; done
