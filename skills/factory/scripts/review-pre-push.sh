#!/usr/bin/env bash
set -uo pipefail

[ "${FACTORY_REVIEW:-on}" = off ] && exit 0
remote=${1:-origin}
zero=0000000000000000000000000000000000000000
ticket=$(git rev-parse --git-path factory-review.md)
last=$(git rev-parse --git-path factory-review.last)

say() { printf '%s\n' "$*" >&2; }

review() {
  local key=$1 branch=$2 sha=$3 base=$4 base_sha old_range verdict out rd since=""
  base_sha=$(git merge-base "$base" "$sha") || { say "factory-review: no merge-base with $base"; return 1; }

  if [ -f "$last" ]; then
    old_range=$(head -1 "$last")
    if [ "$(sed -n 2p "$last")" = "VERDICT: PASS" ] &&
      rd=$(git range-diff "$old_range" "$base_sha..$sha") && [ -n "$rd" ] &&
      ! grep -qvE '^[0-9-]+: +[0-9a-f-]+ = ' <<<"$rd"; then
      say "factory-review: $branch passed (clean since ${old_range})"
      return 0
    fi
    if [ "$old_range" = "$base_sha..$sha" ]; then
      tail -n +2 "$last" >&2
      return 1
    fi
    since="Since: $old_range. The previous review follows; check each of its findings again.
$(tail -n +2 "$last")"
  fi

  [ -f "$ticket" ] || { say "factory-review: $ticket is missing; the orchestrator writes it at setup"; return 1; }
  command -v claude >/dev/null || { say "factory-review: claude CLI not found"; return 1; }

  local allowed=(Read Glob Grep Skill "Bash(cd *)") c
  for c in diff log show blame range-diff merge-base rev-parse; do allowed+=("Bash(command git $c *)"); done

  say "factory-review: reviewing $branch ($base_sha..$sha); this takes a few minutes"
  out=$(printf 'Ticket: %s. Worktree: %s. Branch: %s. Base: %s.\n%s\n%s\n' "$key" "$PWD" "$branch" "$base" "$(cat "$ticket")" "$since" |
    claude -p --agent factory-reviewer --output-format stream-json --verbose --allowedTools "${allowed[@]}" --disallowedTools Edit Write NotebookEdit |
    tee >(jq -r --unbuffered 'select(.type == "assistant") | .message.content[] | if .type == "text" then .text elif .type == "tool_use" then "factory-review: \(.name) \(.input.command // .input.file_path // .input.pattern // .input.skill // "")" else empty end' >&2) |
    jq -r 'select(.type == "result") | .result')
  verdict=$(printf '%s\n' "$out" | grep -m1 -E '^VERDICT: (PASS|CHANGES)$')
  [ -n "$verdict" ] || { say "factory-review: no VERDICT line in the review"; return 1; }

  printf '%s\n%s\n%s\n' "$base_sha..$sha" "$verdict" "$(printf '%s\n' "$out" | grep -v '^VERDICT:')" >"$last"
  [ "$verdict" = "VERDICT: PASS" ]
}

status=0
while read -r _ sha remote_ref _; do
  branch=${remote_ref#refs/heads/}
  [[ $sha != "$zero" && $branch =~ ^factory/([A-Z][A-Z0-9]*-[0-9]+)(-([0-9]+))?$ ]] || continue
  key=${BASH_REMATCH[1]} n=${BASH_REMATCH[3]:-1}
  base=$remote/main
  ((n > 1)) && base=$remote/factory/$key-$((n - 1))
  review "$key" "$branch" "$sha" "$base" || status=1
done
exit $status
