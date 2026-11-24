#!/usr/bin/env bash
# Local check of the flake check `python-left` (plan, step 0): the Python files of the flake's source outside audit/ equal the
# list kept in flake.nix. Each case copies the tracked tree into a throwaway git repository, mutates it, and builds the check.
set -uo pipefail
repo=$(git rev-parse --show-toplevel)
scratch=$(mktemp -d "${TMPDIR:-/tmp}/mm-pyleft.XXXXXX")
trap 'rm -rf "$scratch"' EXIT
fails=0

fresh() {
  rm -rf "$scratch/t"
  mkdir "$scratch/t"
  (cd "$repo" && git ls-files -z | grep -zv '^data/' | xargs -0 cp --parents -t "$scratch/t")
  (cd "$scratch/t" && git init -q && git add -A && git -c user.name=t -c user.email=t@t commit -qm fixture)
}

build() {
  (cd "$scratch/t" && git add -A && nix build --no-link .#checks.x86_64-linux.python-left 2>&1)
}

expect_pass() {
  local name=$1 out
  out=$(build) && echo "ok   $name" || { echo "FAIL $name (should pass)"; echo "$out" | tail -5; fails=$((fails + 1)); }
}

expect_fail_naming() {
  local name=$1 needle=$2 out
  if out=$(build); then
    echo "FAIL $name (should fail)"
    fails=$((fails + 1))
  elif grep -q -- "$needle" <<<"$out"; then
    echo "ok   $name"
  else
    echo "FAIL $name (failed without naming $needle)"
    echo "$out" | tail -5
    fails=$((fails + 1))
  fi
}

fresh
expect_pass "1. main's tree passes"

fresh
mkdir -p "$scratch/t/gate/control"
echo 'print(1)' >"$scratch/t/gate/control/pick.py"
expect_fail_naming "2a. an unlisted .py names it" 'gate/control/pick.py'

fresh
printf '#!/usr/bin/env python3\nprint(1)\n' >"$scratch/t/ops/x"
chmod +x "$scratch/t/ops/x"
expect_fail_naming "2b. an extensionless python-shebang file names it" 'ops/x'

fresh
git -C "$scratch/t" rm -q cli.py
expect_fail_naming "3. a listed file that is gone names it" 'cli.py'

fresh
mkdir -p "$scratch/t/audit/new"
echo 'print(1)' >"$scratch/t/audit/new/record.py"
printf '#!/usr/bin/env python3\n' >"$scratch/t/audit/new/tool"
expect_pass "4. Python under audit/ changes nothing"

exit $((fails > 0))
