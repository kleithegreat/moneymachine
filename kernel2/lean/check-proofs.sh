#!/bin/sh
# Scans `Engine` sources for unapproved attributes/escape hatches under the honest-but-buggy model,
# builds the Lake project in DIR offline, and prints the axioms of every theorem in every module of `Engine`.
# Exits nonzero unless:
#   1. Static scan finds zero `@[implemented_by`, unapproved `@[extern`, `unsafe `, `partial `, or `axiom `; and
#   2. Every theorem rests on `{propext, Classical.choice, Quot.sound}` alone (and `env` holds zero `implemented_by`).
set -eu
dir=${1:?usage: check-proofs.sh DIR}
here=$(cd "$(dirname "$0")" && pwd)
dir=$(cd "$dir" && pwd)
[ -e "$dir/../protected-windows.json" ] || cp "$here/../protected-windows.json" "$dir/../protected-windows.json"

strip_comments() {
  awk '
    BEGIN { depth = 0; in_str = 0 }
    {
      line = $0
      out = ""
      n = length(line)
      i = 1
      while (i <= n) {
        c = substr(line, i, 1)
        c2 = (i < n) ? substr(line, i, 2) : ""
        if (depth > 0) {
          if (c2 == "/-") { depth++; i += 2; continue }
          if (c2 == "-/") { depth--; out = out " "; i += 2; continue }
          i++
          continue
        }
        if (in_str) {
          out = out c
          if (c == "\\" && i < n) { out = out substr(line, i + 1, 1); i += 2; continue }
          if (c == "\"") { in_str = 0 }
          i++
          continue
        }
        if (c2 == "--") { break }
        if (c2 == "/-") { depth++; i += 2; continue }
        if (c == "\"") { in_str = 1; out = out c; i++; continue }
        out = out c
        i++
      }
      print out
    }
  ' "$1"
}

scan_file() {
  f=$1
  cleaned=$(strip_comments "$f" | sed -E \
    -e 's/@\[extern "mm2_mpfr_exp"\]//g' \
    -e 's/@\[extern "mm2_mpfr_log"\]//g' \
    -e 's/@\[export mm2_[A-Za-z0-9_]+\]//g')
  if printf '%s\n' "$cleaned" | grep -Eq '(@\[[^]]*implemented_by|implemented_by|@\[[^]]*extern|(^|[^A-Za-z0-9_])(unsafe|partial|axiom)[[:space:]])'; then
    echo "FAIL: forbidden escape hatch in $f:" >&2
    printf '%s\n' "$cleaned" | grep -En '(@\[[^]]*implemented_by|implemented_by|@\[[^]]*extern|(^|[^A-Za-z0-9_])(unsafe|partial|axiom)[[:space:]])' >&2
    exit 1
  fi
}

[ -f "$dir/Engine.lean" ] && scan_file "$dir/Engine.lean"
if [ -d "$dir/Engine" ]; then
  for lean_file in $(find "$dir/Engine" -type f -name '*.lean' | LC_ALL=C sort); do
    scan_file "$lean_file"
  done
fi

cd "$dir"
lake build
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
script="$tmp/Axioms.lean"
cat >"$script" <<'LEAN'
import Lean
import Lean.Compiler.ImplementedByAttr
import Engine
open Lean

def allowed : List Name := [`propext, `Classical.choice, `Quot.sound]
def allowedExterns : List Name := [`Engine.Exact.exp, `Engine.Exact.log]

def engineModule (m : Name) : Bool := m == `Engine || Name.isPrefixOf `Engine m

#eval show CoreM Unit from do
  let env ← getEnv
  let mut bad := false
  for i in [0:env.header.moduleNames.size] do
    unless engineModule env.header.moduleNames[i]! do continue
    for name in env.header.moduleData[i]!.constNames do
      let some info := env.find? name | continue
      if Compiler.getImplementedBy? env name |>.isSome then
        bad := true
        IO.println s!"FAIL: {name} uses @[implemented_by]"
      if isExtern env name && !allowedExterns.contains name then
        bad := true
        IO.println s!"FAIL: {name} uses unapproved @[extern]"
      if info.isUnsafe then
        bad := true
        IO.println s!"FAIL: {name} is unsafe"
      if info matches .axiomInfo _ then
        bad := true
        IO.println s!"FAIL: {name} is a declared axiom"
      let .thmInfo _ := info | continue
      let axioms ← collectAxioms name
      IO.println s!"{name}: {axioms.toList}"
      if axioms.any (fun a => !allowed.contains a) then
        bad := true
        IO.println s!"FAIL: {name} rests on an axiom outside the allowed three"
  if bad then throwError "engine proofs rest on a forbidden axiom or escape hatch"
LEAN
lake env lean "$script"
