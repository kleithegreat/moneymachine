#!/usr/bin/env bash
# Every UTC time names its Eastern time beside it (CLAUDE.md, Read the clock). Given a file, checks that file's lines
# (the commit-msg hook's mode). Given none, checks every line added to PROGRESS.md or audit/ outside audit/reviews/
# since the rule began, untracked files included (the pre-commit hook's mode); audit/reviews/ holds outside
# reviewers' text verbatim, which is never edited.
set -euo pipefail
since=a71111fa92aee5acb33f73ec5c448d387020d6fd
utc='\b[0-9]{1,2}:[0-9]{2}(:[0-9]{2})?[[:space:]]*UTC\b'
eastern='\b[0-9]{1,2}:[0-9]{2}(:[0-9]{2})?[[:space:]]*E[DS]T\b'

count() { grep -oE "$1" <<<"$2" | wc -l; }

unpaired() {
  local line
  while IFS= read -r line; do
    [ "$(count "$utc" "$line")" -gt "$(count "$eastern" "$line")" ] || continue
    echo "UTC time without its Eastern time: $line"
    status=1
  done < <(grep -aE "$utc" || true)
}

added() {
  git diff "$since" -- PROGRESS.md audit ':!audit/reviews' | grep -a '^+' | grep -av '^+++' | cut -c2- || true
  git ls-files --others --exclude-standard -z -- audit ':!audit/reviews' | xargs -0 -r cat
}

status=0
if [ $# -ge 1 ]; then
  unpaired <"$1"
else
  cd "$(git rev-parse --show-toplevel)"
  unpaired < <(added)
fi
exit $status
