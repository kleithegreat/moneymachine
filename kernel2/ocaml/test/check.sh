#!/bin/sh
# Step 0, test 1: `mm2 check FILE` prints Lean's verdict.
#
# Interface assumed (the builder provides it):
#   - executable `mm2` (dune project kernel2/ocaml, bin/mm2.exe, packaged as packages.mm2), run as `mm2 check FILE`.
#   - the verdict comes from the Lean function `Engine.check : String -> String` (file contents in, verdict out), called
#     through the C stub. Step 0's stub verdict: "ok" when the first line is exactly `mm2-program 0`,
#     otherwise a single line starting `rejected:`. Real grammar arrives with step 4.
#   - exit codes: 0 verdict ok (stdout is exactly `ok\n`); 1 verdict rejected (stdout one line starting `rejected:`);
#     2 usage or unreadable file (nothing on stdout).
# Usage: check.sh PATH_TO_MM2 FIXTURE_DIR
set -u
mm2=$1
fx=$2

out=$("$mm2" check "$fx/ok.prog"); rc=$?
[ "$rc" = 0 ] || { echo "FAIL: ok.prog exit $rc"; exit 1; }
[ "$out" = ok ] || { echo "FAIL: ok.prog printed '$out'"; exit 1; }

out=$("$mm2" check "$fx/bad.prog"); rc=$?
[ "$rc" = 1 ] || { echo "FAIL: bad.prog exit $rc"; exit 1; }
case $out in rejected:*) ;; *) echo "FAIL: bad.prog printed '$out'"; exit 1;; esac
[ "$(printf '%s\n' "$out" | wc -l)" = 1 ] || { echo "FAIL: verdict not one line"; exit 1; }

out=$("$mm2" check "$fx/does-not-exist.prog" 2>/dev/null); rc=$?
[ "$rc" = 2 ] && [ -z "$out" ] || { echo "FAIL: missing file exit $rc"; exit 1; }

"$mm2" >/dev/null 2>&1; rc=$?
[ "$rc" = 2 ] || { echo "FAIL: no subcommand exit $rc"; exit 1; }
echo "check: ok"
