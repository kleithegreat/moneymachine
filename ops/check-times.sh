#!/usr/bin/env bash
# Every UTC time names its Eastern time beside it (CLAUDE.md, Read the clock). Given a file, checks that file's lines
# (the commit-msg hook's mode). Given none, checks every line added to PROGRESS.md or audit/ outside audit/reviews/
# since the rule began, untracked files included (the pre-commit hook's mode); audit/reviews/ holds outside
# reviewers' text verbatim, which is never edited. It fails closed: a failed git command or an unreadable file fails
# the check, and only grep's "no match" (status 1) is absorbed.
set -euo pipefail
shopt -s inherit_errexit
since=a71111fa92aee5acb33f73ec5c448d387020d6fd
utc='\b[0-9]{1,2}:[0-9]{2}(:[0-9]{2})?[[:space:]]*UTC\b'
eastern='\b[0-9]{1,2}:[0-9]{2}(:[0-9]{2})?[[:space:]]*E[DS]T\b'

count() {
  local matches
  matches=$(grep -oE "$1" <<<"$2" || [ $? -eq 1 ])
  if [ -z "$matches" ]; then echo 0; else wc -l <<<"$matches"; fi
}

unpaired() {
  local text=$1 candidates line utc_count eastern_count
  candidates=$(grep -aE "$utc" <<<"$text" || [ $? -eq 1 ])
  while IFS= read -r line; do
    utc_count=$(count "$utc" "$line")
    eastern_count=$(count "$eastern" "$line")
    [ "$utc_count" -gt "$eastern_count" ] || continue
    echo "UTC time without its Eastern time: $line"
    status=1
  done <<<"$candidates"
}

untracked_text() {
  local names f
  names=$(mktemp "${TMPDIR:-/tmp}/check-times.XXXXXX")
  git ls-files --others --exclude-standard -z -- audit ':!audit/reviews' >"$names"
  while IFS= read -r -d '' f; do
    cat -- "$f"
  done <"$names"
  rm -f "$names"
}

status=0
if [ $# -ge 1 ]; then
  text=$(cat -- "$1")
else
  cd "$(git rev-parse --show-toplevel)"
  diff_out=$(git diff "$since" -- PROGRESS.md audit ':!audit/reviews')
  tracked=$(sed -n -e '/^+++/d' -e 's/^+//p' <<<"$diff_out")
  untracked=$(untracked_text)
  text=$tracked$'\n'$untracked
fi
unpaired "$text"
exit $status
