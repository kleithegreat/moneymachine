#!/usr/bin/env bash
# Local check of the commit-msg and pre-commit hooks and of ops/check-times.sh (plan, step 2, points 1 and 2). It clones
# this repository (the scan runs from the history's marked commit, and pre-commit builds the flake) and drives the hooks
# from outside in the clone. The time patterns are assembled here so that nothing in this file is itself a bare time.
set -uo pipefail
repo=$(git rev-parse --show-toplevel)
scratch=$(mktemp -d "${TMPDIR:-/tmp}/mm-test-hooks.XXXXXX")
trap 'rm -rf "$scratch"' EXIT
fails=0
utc=UTC
est=EDT

pass() { echo "ok   $1"; }
fail() { echo "FAIL $1"; fails=$((fails + 1)); }

git clone -q --no-hardlinks "$repo" "$scratch/c"
c=$scratch/c
git -C "$c" config user.name t
git -C "$c" config user.email t@t
for f in ops/check-times.sh .githooks/commit-msg .githooks/pre-commit; do
  [ -e "$repo/$f" ] && cp "$repo/$f" "$c/$f"
done
[ -e "$c/ops/check-times.sh" ] || { fail "ops/check-times.sh exists"; exit 1; }

# msg_case <name> <accept|refuse> <message text>: the commit-msg hook's verdict; a refusal names the offending line.
msg_case() {
  local name=$1 want=$2 text=$3 out code
  printf '%s\n' "$text" >"$scratch/msg"
  out=$(cd "$c" && .githooks/commit-msg "$scratch/msg" 2>&1)
  code=$?
  if [ "$want" = accept ] && [ $code -eq 0 ]; then
    pass "$name"
  elif [ "$want" = refuse ] && [ $code -ne 0 ] && grep -qF -- "$text" <<<"$out"; then
    pass "$name"
  else
    fail "$name (exit $code: $out)"
  fi
}

msg_case "1a. a UTC time alone is refused" refuse "at 20:13 $utc"
msg_case "1b. two UTC times against one Eastern are refused" refuse "20:13 $utc (16:13 $est) and 21:00 $utc"
msg_case "1c. a UTC time with its Eastern time is accepted" accept "at 20:13 $utc (16:13 $est)"
msg_case "1d. no time is accepted" accept "no time here"
msg_case "1e. a line beginning with # is ignored" accept "# at 20:13 $utc"
msg_case "1f. seconds count as a time" refuse "at 20:13:05 $utc"
msg_case "1g. no space before UTC counts as a time" refuse "at 20:13$utc"
msg_case "1h. three digits before the colon are no time" accept "at 120:13 $utc"
msg_case "1i. a letter straight after UTC is no time" accept "at 20:13 ${utc}x"

(cd "$c" && ops/check-times.sh <(printf 'at 20:13 %s\n' "$utc")) >/dev/null 2>&1 && fail "1j. check-times.sh FILE refuses a bare time" || pass "1j. check-times.sh FILE refuses a bare time"
(cd "$c" && ops/check-times.sh <(printf 'at 20:13 %s (16:13 %s)\n' "$utc" "$est")) >/dev/null 2>&1 && pass "1k. check-times.sh FILE accepts a paired time" || fail "1k. check-times.sh FILE accepts a paired time"

if (cd "$repo" && ops/check-times.sh >/dev/null 2>&1); then
  pass "2a. ops/check-times.sh passes on this tree's history"
else
  fail "2a. ops/check-times.sh passes on this tree's history"
fi

# hook_case <name> <accept|refuse> <setup, run in the clone and staging what it changes>: pre-commit's verdict, then the clone is reset.
hook_case() {
  local name=$1 want=$2 setup=$3 code
  (cd "$c" && eval "$setup")
  (cd "$c" && .githooks/pre-commit >"$scratch/hook.log" 2>&1)
  code=$?
  if { [ "$want" = accept ] && [ $code -eq 0 ]; } || { [ "$want" = refuse ] && [ $code -ne 0 ]; }; then
    pass "$name"
  else
    fail "$name (exit $code)"
    tail -5 "$scratch/hook.log"
  fi
  (cd "$c" && git reset -q --hard && git clean -qfd)
}

bare="note at 20:13 $utc"
hook_case "2b. pre-commit accepts a clean tree" accept ":"
hook_case "2c. a staged PROGRESS.md over 12,288 bytes is refused" refuse "head -c 13000 /dev/zero | tr '\\0' x >> PROGRESS.md; echo >> PROGRESS.md; git add PROGRESS.md"
hook_case "2d. a staged unpaired line of audit/decisions.md is refused" refuse "echo '$bare' >> audit/decisions.md; git add audit/decisions.md"
hook_case "2e. the same line in audit/reviews/ is accepted" accept "mkdir -p audit/reviews; echo '$bare' > audit/reviews/x-test.md; git add audit/reviews/x-test.md"
hook_case "2f. an untracked unpaired line under audit/ is refused" refuse "echo '$bare' > audit/untracked-test.md"

exit $((fails > 0))
