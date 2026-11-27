#!/bin/sh
# Step 0, test 2: kernel2/flake.lock is byte-identical to its pinned lock.
set -eu
RECORDED=415c302c51d5ef65241ba0c845256bceca418b90da4df45cc0d71e4eb139153b
k2=$(cd "$(dirname "$0")/.." && pwd)
got=$(sha256sum "$k2/flake.lock" | cut -d' ' -f1)
[ "$got" = "$RECORDED" ] || { echo "kernel2/flake.lock changed: $got" >&2; exit 1; }
echo "flake.lock unchanged"
