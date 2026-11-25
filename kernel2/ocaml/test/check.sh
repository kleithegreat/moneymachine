#!/bin/sh
# Step 0, test 1, as step 4 has it: `mm2 check FILE` prints Lean's verdict on a program (KERNEL.md A17, "The verdict").
#
# Interface assumed (the builder provides it):
#   - executable `mm2` (dune project kernel2/ocaml, bin/mm2.exe, packaged as packages.mm2), run as `mm2 check FILE`.
#   - the verdict is Lean's `Engine.check : String -> String`, called through the C stub: the JSON {"ok":true} for a
#     program of the grammar, or {"error":CODE,"at":WHERE} for the first fault.
#   - exit codes: 0 verdict ok; 1 verdict an error (stdout is that JSON, one line); 2 usage or unreadable file
#     (nothing on stdout).
# Usage: check.sh PATH_TO_MM2 FIXTURE_DIR
set -u
mm2=$1
fx=$2

out=$("$mm2" check "$fx/ok.prog"); rc=$?
[ "$rc" = 0 ] || { echo "FAIL: ok.prog exit $rc"; exit 1; }
printf '%s\n' "$out" | grep -Eq '^\{ *"ok" *: *true *\}$' || { echo "FAIL: ok.prog printed '$out'"; exit 1; }

out=$("$mm2" check "$fx/bad.prog"); rc=$?
[ "$rc" = 1 ] || { echo "FAIL: bad.prog exit $rc"; exit 1; }
printf '%s\n' "$out" | grep -Eq '"error" *: *"E_PARSE"' || { echo "FAIL: bad.prog printed '$out'"; exit 1; }
[ "$(printf '%s\n' "$out" | wc -l)" = 1 ] || { echo "FAIL: verdict not one line"; exit 1; }

out=$("$mm2" check "$fx/does-not-exist.prog" 2>/dev/null); rc=$?
[ "$rc" = 2 ] && [ -z "$out" ] || { echo "FAIL: missing file exit $rc"; exit 1; }

"$mm2" >/dev/null 2>&1; rc=$?
[ "$rc" = 2 ] || { echo "FAIL: no subcommand exit $rc"; exit 1; }
echo "check: ok"
