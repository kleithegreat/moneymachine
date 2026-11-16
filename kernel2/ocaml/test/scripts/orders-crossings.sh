#!/bin/sh
# Builder contract: the Lean-only signatures/records in fixtures/orders.lean
# and fixtures/orders-crossings.lean; no new OCaml calls or mm2 commands.
# MM2_ENGINE_LIB selects the existing Lake build linked by this test suite.
set -eu
fixture=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
lean_dir=$(cd "$(dirname "${MM2_ENGINE_LIB:?same engine archive required}")/../../.." && pwd)
cd "$lean_dir"
lake env lean "$fixture"
