#!/bin/sh
# Builder contract: the Lean-only signatures/records in fixtures/orders.lean
# and fixtures/orders-crossings.lean; no new OCaml calls or mm2 commands.
# Also fixtures/x4-specials.lean: Exact.exp/log : UInt64 -> UInt64, Lean only;
# fixtures/x4-counts.lean reads the frozen law-owned X4 definitions.
# MM2_ENGINE_LIB selects the existing Lake build linked by this test suite.
set -eu
fixture=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
lean_dir=$(cd "$(dirname "${MM2_ENGINE_LIB:?same engine archive required}")/../../.." && pwd)
cd "$lean_dir"
lake env lean "$fixture"
