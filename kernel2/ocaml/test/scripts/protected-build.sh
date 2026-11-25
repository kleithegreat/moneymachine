#!/bin/sh
# Assumed: Engine.Machine start/feed/finish use A18/A19 through Mm2_lean.Machine;
# mm2 start PROGRAM HEADER STATE prints {ok,build,identity}; feed STATE CHUNK,
# finish STATE OUTDIR, inspect HEADER CHUNK have events_support.ml's contract.
# Reader: mm2_archive.Reader, raw/,snapshots/ archive layout, no runtime policy.
# Policy: kernel2/protected-windows.json is a strict JSON array of exactly
# {start:integer-ms,end:integer-ms,released:bool}, compiled as DATA by dune.
# MM2_ENGINE_LIB is step 0's real static library, not a test replacement.
# This script rebuilds COPIES only. It never changes repository sources.
set -eu
baseline=$1
program=$2
header=$3
protected_header=$4
case $baseline in /*) ;; *) baseline=$PWD/$baseline ;; esac
case $program in /*) ;; *) program=$PWD/$program ;; esac
case $header in /*) ;; *) header=$PWD/$header ;; esac
case $protected_header in /*) ;; *) protected_header=$PWD/$protected_header ;; esac
root=${MM2_ENGINE_LIB%/kernel2/lean/.lake/build/lib/libengine_Engine.a}
[ -f "$root/kernel2/protected-windows.json" ]
scratch=$(mktemp -d "${TMPDIR:-/tmp/opencode}/mm2-policy-build.XXXXXX")
trap 'rm -rf "$scratch"' EXIT HUP INT TERM
mkdir -p "$scratch/copy"
(cd "$root" && tar --exclude=_build --exclude=.lake -cf - kernel2) |
  (cd "$scratch/copy" && tar -xf -)
copy=$scratch/copy
policy=$copy/kernel2/protected-windows.json
build() {
  (cd "$copy/kernel2/lean" && lake build Engine:static &&
    cd ../ocaml && MM2_ENGINE_LIB="$copy/kernel2/lean/.lake/build/lib/libengine_Engine.a" \
      dune build --root . bin/mm2.exe) >"$scratch/build.log" 2>&1
}
verdict() {
  "$1" start "$program" "$header" "$scratch/state-$2" >"$scratch/verdict-$2"
}
hash_field() {
  sed -n "s/.*\"$2\"[ ]*:[ ]*\"\([0-9a-f]*\)\".*/\1/p" "$1"
}
verdict "$baseline" original
build || { cat "$scratch/build.log"; exit 1; }
binary=$copy/kernel2/ocaml/_build/default/bin/mm2.exe
verdict "$binary" copied
original_build=$(hash_field "$scratch/verdict-original" build)
copied_build=$(hash_field "$scratch/verdict-copied" build)
[ ${#original_build} = 64 ] && [ "$original_build" = "$copied_build" ]
original_identity=$(hash_field "$scratch/verdict-original" identity)
cp "$policy" "$scratch/policy"
sed 's/false/true/g' "$scratch/policy" >"$policy"
cmp -s "$policy" "$scratch/policy" && { echo 'policy has no unreleased window'; exit 1; }
build || { cat "$scratch/build.log"; exit 1; }
verdict "$binary" released
[ "$(hash_field "$scratch/verdict-released" build)" = "$original_build" ]
[ "$(hash_field "$scratch/verdict-released" identity)" != "$original_identity" ]
"$binary" start "$program" "$protected_header" "$scratch/released-state" >"$scratch/released-start"
grep -q '"ok"[ ]*:[ ]*true' "$scratch/released-start"
cp "$scratch/policy" "$policy"
printf '\n' >>"$copy/kernel2/flake.lock"
build || { cat "$scratch/build.log"; exit 1; }
verdict "$binary" lock-whitespace
[ "$(hash_field "$scratch/verdict-lock-whitespace" build)" = "$original_build" ]
printf '\n' >>"$copy/kernel2/ocaml/src/decimal.ml"
build || { cat "$scratch/build.log"; exit 1; }
verdict "$binary" source
[ "$(hash_field "$scratch/verdict-source" build)" != "$original_build" ]
for invalid in \
  'import Anything' \
  'null' \
  '[{"start":0,"end":1,"released":false,"code":"anything"}]' \
  '[{"start":0,"end":1}]' \
  '[{"start":"0","end":1,"released":false}]' \
  '[{"start":0,"end":1,"released":false,"released":true}]'
do
  printf '%s\n' "$invalid" >"$policy"
  if build; then echo "invalid protected policy built: $invalid"; exit 1; fi
done
echo 'protected policy: build rejects code; release changes identity only; source byte changes build'
