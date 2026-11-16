#!/bin/sh
# Step 0, test 3: `checks.engine-proofs` rejects sorry, a declared axiom and native_decide, and accepts the library without them.
#
# Interface assumed (the builder provides it):
#   - kernel2/lean/check-proofs.sh DIR   DIR is a Lake project root holding the library `Engine` (root module DIR/Engine.lean).
#     It builds it offline, prints `#print axioms` for every theorem in every module of Engine, and exits 0 only if each
#     depends on no axiom besides propext, Classical.choice and Quot.sound (so sorryAx, a declared axiom and
#     Lean.ofReduceBool, which native_decide introduces, all fail it). `checks.engine-proofs` is this script run on kernel2/lean.
#   - This test is wired as the flake check `checks.engine-proofs-fixtures`, with lean on PATH, run from the repository root.
#
# Each fixture in kernel2/lean/test-fixtures/ is copied into a scratch copy of kernel2/lean as module Engine.Fixture and imported
# by Engine.lean; the real kernel2/lean is never touched.
set -eu
root=$(cd "$(dirname "$0")/../.." && pwd)
check="$root/kernel2/lean/check-proofs.sh"
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT

with_fixture() {
  d="$scratch/$1"
  mkdir -p "$d"
  cp -r "$root/kernel2/lean/." "$d/"
  rm -rf "$d/test-fixtures" "$d/.lake"
  if [ "$1" != none ]; then
    mkdir -p "$d/Engine"
    cp "$root/kernel2/lean/test-fixtures/$2.lean" "$d/Engine/Fixture.lean"
    printf '\nimport Engine.Fixture\n' | cat - "$d/Engine.lean" > "$d/Engine.lean.new"
    mv "$d/Engine.lean.new" "$d/Engine.lean"
  fi
}

with_fixture none
if ! sh "$check" "$scratch/none" >"$scratch/none.out" 2>&1; then
  cat "$scratch/none.out" >&2; echo "FAIL: the library without fixtures must pass" >&2; exit 1
fi

# Step 3 test 7: a successful generic scan is insufficient if the fast-reading
# laws (or the original laws they connect to) were left out of its imports.
for law in X2 C1 C2 X3_readBits X3_onGrid; do
  if ! grep -F "Engine.Laws.$law:" "$scratch/none.out"; then
    echo "FAIL: checks.engine-proofs did not list Engine.Laws.$law" >&2
    exit 1
  fi
done

with_fixture clean Clean
if ! sh "$check" "$scratch/clean" >"$scratch/clean.out" 2>&1; then
  cat "$scratch/clean.out" >&2; echo "FAIL: a clean theorem must pass" >&2; exit 1
fi

for name in Sorry Axiom NativeDecide; do
  with_fixture "bad$name" "$name"
  if sh "$check" "$scratch/bad$name" >"$scratch/bad$name.out" 2>&1; then
    cat "$scratch/bad$name.out" >&2; echo "FAIL: $name fixture must fail the check" >&2; exit 1
  fi
done
echo "engine-proofs: sorry, axiom, native_decide rejected; clean accepted"
