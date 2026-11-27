#!/bin/sh
# The fixture imports only Engine.Exact, so it also runs before Laws' sorrys
# are discharged. MM2_ENGINE_LIB selects the same Lake build dune links.
set -eu
fixture=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
lean_dir=$(cd "$(dirname "${MM2_ENGINE_LIB:?same engine archive required}")/../../.." && pwd)
cd "$lean_dir"
lake env lean "$fixture"
