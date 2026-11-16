#!/bin/sh
# Step 0, test 2: flake.lock is byte-identical to main's.
#
# Interface assumed: run from anywhere inside the repository; exit 0 when identical, nonzero otherwise.
# Compares against `main` when that ref exists, and always against the hash recorded from main on 2026-11-15
# (a build sandbox has no git history; there only the recorded hash is checked).
set -eu
RECORDED=415c302c51d5ef65241ba0c845256bceca418b90da4df45cc0d71e4eb139153b
root=$(cd "$(dirname "$0")/../.." && pwd)
got=$(sha256sum "$root/flake.lock" | cut -d' ' -f1)
[ "$got" = "$RECORDED" ] || { echo "flake.lock changed: $got" >&2; exit 1; }
if git -C "$root" rev-parse --verify -q main >/dev/null 2>&1; then
  git -C "$root" show main:flake.lock | cmp - "$root/flake.lock" || { echo "flake.lock differs from main's" >&2; exit 1; }
fi
echo "flake.lock unchanged"
