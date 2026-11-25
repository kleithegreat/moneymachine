#!/bin/sh
# Step 3 test 6's two wall-clock speed tests, LOCAL ONLY: their limits (470 s, 22 s on one core)
# hold on the reference desktop, not on whichever builder a flake check lands on.
#   sh kernel2/tests/speed-local.sh [REPO_ROOT]
# Each test pins itself to one core; exits nonzero if either fails.
set -eu
repo=$(cd "${1:-.}" && pwd)
cd "$repo"
dune build --root kernel2/ocaml test/scale_test.exe test/strings_scale_test.exe
dune exec --root kernel2/ocaml test/scale_test.exe
dune exec --root kernel2/ocaml test/strings_scale_test.exe
