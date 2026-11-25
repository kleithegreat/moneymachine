#!/bin/sh
# Step 5 test 13. Build stage 6's FROZEN source, not the current evaluator.
# Contract: SOURCE/SOURCE_SHA256SUMS is the advisor's complete frozen source
# manifest (Lean files, Lake files and toolchain); EXPECTED_SHA pins its bytes.
# A fresh BUILD directory is required. MPFR/GMP and Lean are from pinned Nix.
# Usage: sh x4-reference.sh SOURCE EXPECTED_SHA BUILD
# stdout: absolute refmm path; all build output goes to stderr. The caller
# runs the original corpus and mk-*.json with refmm run, and stores its streams.
# This script never runs the glibc reference again and never edits SOURCE.
set -eu
[ "$#" = 3 ] || { echo 'usage: x4-reference.sh SOURCE EXPECTED_SHA BUILD' >&2; exit 2; }
source=$(cd "$1" && pwd)
expected=$2
build=$3
test_dir=$(cd "$(dirname "$0")/.." && pwd)
actual=$(sha256sum "$source/SOURCE_SHA256SUMS" | cut -d ' ' -f 1)
[ "$actual" = "$expected" ] || { echo 'frozen reference source hash differs' >&2; exit 1; }
(cd "$source" && sha256sum -c --quiet SOURCE_SHA256SUMS)
[ ! -e "$build" ] || { echo 'fresh reference build directory required' >&2; exit 1; }
mkdir -p "$build"
build=$(cd "$build" && pwd)
(cd "$source" && tar --exclude=./.lake -cf - .) | (cd "$build" && tar -xf -)
cc ${NIX_CFLAGS_COMPILE:-} $(pkg-config --cflags mpfr) -DMM2_TEST_REFERENCE -c \
  "$test_dir/x4_mpfr_stubs.c" -o "$build/x4-mpfr.o"
cc ${NIX_CFLAGS_COMPILE:-} -c "$test_dir/x4_reference_wrap.c" -o "$build/x4-wrap.o"
# Only the executable's link inputs change; every frozen .lean stays byte-identical.
printf '\nmoreLinkArgs = ["%s/x4-mpfr.o", "%s/x4-wrap.o", "-Wl,--wrap=exp", "-Wl,--wrap=log", "-lmpfr", "-lgmp"]\n' \
  "$build" "$build" >> "$build/lakefile.toml"
(cd "$build" && lake build refmm >&2)
(cd "$build" && grep '\.lean$' SOURCE_SHA256SUMS | sha256sum -c --quiet)
printf '%s\n' "$build/.lake/build/bin/refmm"
