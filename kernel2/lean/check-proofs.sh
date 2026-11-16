#!/bin/sh
# Builds the Lake project in DIR offline and prints the axioms of every theorem in every module of `Engine`.
# Exits nonzero unless each theorem rests on propext, Classical.choice and Quot.sound alone: sorry (sorryAx), a declared
# axiom and native_decide (Lean.ofReduceBool) all fail it.
set -eu
dir=${1:?usage: check-proofs.sh DIR}
here=$(cd "$(dirname "$0")" && pwd)
dir=$(cd "$dir" && pwd)
# The library compiles in `../protected-windows.json` (Engine.Policy). A scratch copy of this directory has none beside it, so it gets the policy of the tree this script belongs to.
[ -e "$dir/../protected-windows.json" ] || cp "$here/../protected-windows.json" "$dir/../protected-windows.json"
cd "$dir"
lake build
script=$(mktemp -d)/Axioms.lean
cat >"$script" <<'LEAN'
import Lean
import Engine
open Lean

def allowed : List Name := [`propext, `Classical.choice, `Quot.sound]

def engineModule (m : Name) : Bool := m == `Engine || Name.isPrefixOf `Engine m

#eval show CoreM Unit from do
  let env ← getEnv
  let mut bad := false
  for i in [0:env.header.moduleNames.size] do
    unless engineModule env.header.moduleNames[i]! do continue
    for name in env.header.moduleData[i]!.constNames do
      let some (.thmInfo _) := env.find? name | continue
      let axioms ← collectAxioms name
      IO.println s!"{name}: {axioms.toList}"
      if axioms.any (fun a => !allowed.contains a) then
        bad := true
        IO.println s!"FAIL: {name} rests on an axiom outside the allowed three"
  if bad then throwError "engine proofs rest on a forbidden axiom"
LEAN
lake env lean "$script"
