#!/bin/sh
# Step 3 test 7, full gate on ONE build. Run from any directory:
#   sh kernel2/tests/fast-readings.sh REPO_ROOT ARCHIVE_ROOT NEW_OUTPUT_DIR REF_DIR [AUDIT_DIR]
# Original step-1, step-3 tests 1..5 and all step-4 tests run UNEDITED, through public entry
# points. No alternate FFI, engine flag, tolerance or twin-specific fixtures.
# Local test 5 needs the real, pre-protected archive and is never a Nix input.
# This gate intentionally fails until X3's statements have real proofs.
set -eu
repo=$(cd "${1:?REPO_ROOT required}" && pwd)
archive=$(cd "${2:?ARCHIVE_ROOT required}" && pwd)
out=${3:?NEW_OUTPUT_DIR required}
reference=$(cd "${4:?B4 REF_DIR required}" && pwd)
audit=$(cd "${5:-$repo/audit/stage6}" && pwd)
mkdir "$out"
out=$(cd "$out" && pwd)
cd "$repo"

# The same dune build links every test to the engine used by the rate guard.
dune build --force --root kernel2/ocaml @test/step3-fast-readings >"$out/suite.log" 2>&1
dune exec --root kernel2/ocaml test/archive_local.exe -- "$archive" "$repo" >"$out/archive.log" 2>&1
dune exec --root kernel2/ocaml test/b4_local.exe -- "$reference" "$audit" >"$out/b4.log" 2>&1
# Also hold the literal archived day, not only the sandbox's day-shaped load.
dune exec --root kernel2/ocaml test/scale_local.exe -- --day "$archive" "$repo" "$out/day.json" >"$out/day.log" 2>&1
sh kernel2/lean/check-proofs.sh "$repo/kernel2/lean" >"$out/axioms.log" 2>&1
for law in X2 C1 C2 X3_readBits X3_onGrid X1 R1 S1; do
  grep -F "Engine.Laws.$law:" "$out/axioms.log"
done
printf '%s\n' 'step 3 test 7: earlier tests unchanged, step 5 orders included; X3/X2/C1/C2/X1/R1/S1 listed under the admitted axioms' >"$out/passed"
