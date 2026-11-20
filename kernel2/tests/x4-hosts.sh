#!/bin/sh
# Step 5 test 12: EACH result on two distinct hosts and glibc's -FMA path.
# Contract: SSH access to HOST1/HOST2 with the same test executable, input
# directory and linked engine at the supplied absolute paths. A shared output
# directory is NOT required. The fixture runner uses MM2_ENGINE_LIB as usual.
# Usage: sh x4-hosts.sh HOST1 HOST2 /absolute/x4_local.exe /absolute/INPUT_DIR INPUTS_SHA256 OUTDIR
# No host attestation is manufactured locally and no missing host is skipped.
set -eu
[ "$#" = 6 ] || { echo 'usage: x4-hosts.sh HOST1 HOST2 EXE INPUT_DIR INPUTS_SHA256 OUTDIR' >&2; exit 2; }
h1=$1 h2=$2 exe=$3 inputs=$4 inputs_sha=$5 out=$6
case "$inputs_sha" in
  *[!0-9a-f]*|'') echo 'INPUTS_SHA256 must be 64 lowercase hex chars' >&2; exit 2;;
esac
[ "${#inputs_sha}" = 64 ] || { echo 'INPUTS_SHA256 must be 64 lowercase hex chars' >&2; exit 2; }
[ "$h1" != "$h2" ] || { echo 'two distinct hosts required' >&2; exit 1; }
id1=$(ssh "$h1" cat /etc/machine-id)
id2=$(ssh "$h2" cat /etc/machine-id)
[ -n "$id1" ] && [ -n "$id2" ] && [ "$id1" != "$id2" ] || {
  echo 'two distinct host identities required' >&2; exit 1;
}
case "$exe:$inputs" in /*:/*) ;; *) echo 'absolute paths required' >&2; exit 2;; esac
# Single quotes/newlines cannot be represented by this intentionally small SSH interface.
case "$exe$inputs" in *"'"*|*'
'*) echo 'unsupported path character' >&2; exit 2;; esac
engine_lib=${MM2_ENGINE_LIB:?MM2_ENGINE_LIB required}
[ -f "$engine_lib" ] || { echo "missing engine archive: $engine_lib" >&2; exit 1; }
mm2_bin=${MM2_BIN:-}
if [ -z "$mm2_bin" ]; then
  if [ -x "$(dirname "$exe")/../bin/mm2.exe" ]; then
    mm2_bin="$(dirname "$exe")/../bin/mm2.exe"
  elif [ -x "$(dirname "$engine_lib")/../../../../ocaml/_build/default/bin/mm2.exe" ]; then
    mm2_bin="$(dirname "$engine_lib")/../../../../ocaml/_build/default/bin/mm2.exe"
  elif command -v mm2 >/dev/null 2>&1; then
    mm2_bin=$(command -v mm2)
  else
    echo 'production mm2 binary not found (build bin/mm2.exe or set MM2_BIN)' >&2
    exit 1
  fi
fi
[ -x "$mm2_bin" ] || { echo "production mm2 not executable: $mm2_bin" >&2; exit 1; }

check_engine_symbols() {
  target=$1
  syms=$(nm -u "$target" | sed -n 's/^[[:space:]]*U //p' | sed 's/@.*//')
  if printf '%s\n' "$syms" | grep -Eiq '(^mpfr_|mpfr|mm2_test_mpfr|crlibm|core_math|^cr_(exp|log)|^(exp|expf|expl|exp2|exp2f|exp2l|expm1|expm1f|expm1l|log|logf|logl|log2|log2f|log2l|log10|log10f|log10l|log1p|log1pf|log1pl|lean_float_exp|lean_float_log|lean_float_exp2|lean_float_log2|lean_float_log10)$)'; then
    echo "FORBIDDEN symbol reference in engine object $target:" >&2
    printf '%s\n' "$syms" | grep -Ei '(^mpfr_|mpfr|mm2_test_mpfr|crlibm|core_math|^cr_(exp|log)|^(exp|expf|expl|exp2|exp2f|exp2l|expm1|expm1f|expm1l|log|logf|logl|log2|log2f|log2l|log10|log10f|log10l|log1p|log1pf|log1pl|lean_float_exp|lean_float_log|lean_float_exp2|lean_float_log2|lean_float_log10)$)' >&2
    exit 1
  fi
}

check_engine_symbols "$engine_lib"
lake_ir_dir=$(dirname "$engine_lib")/../ir
if [ -d "$lake_ir_dir" ]; then
  for obj in $(find "$lake_ir_dir" -type f -name '*.o' | LC_ALL=C sort); do
    check_engine_symbols "$obj"
  done
fi
ocaml_src_dir=$(dirname "$mm2_bin")/../src
if [ -d "$ocaml_src_dir" ]; then
  for arch in $(find "$ocaml_src_dir" -maxdepth 2 -type f \( -name '*mm2_lean*.a' -o -name '*mm2_lean*.o' \) | LC_ALL=C sort); do
    check_engine_symbols "$arch"
  done
fi

ldd_out=$(ldd "$mm2_bin")
if printf '%s\n' "$ldd_out" | grep -qi 'libmpfr'; then
  echo "FORBIDDEN libmpfr linkage in production mm2: $mm2_bin" >&2
  exit 1
fi
mm2_syms=$(
  { nm -u "$mm2_bin" 2>/dev/null || true; nm -D -u "$mm2_bin" 2>/dev/null || true; nm "$mm2_bin" 2>/dev/null || true; }
)
[ -n "$mm2_syms" ] || { echo "unable to read symbol table of $mm2_bin" >&2; exit 1; }
if printf '%s\n' "$mm2_syms" | grep -Eiq '(mpfr_|mm2_test_mpfr|crlibm|core_math|\bcr_(exp|log)\b)'; then
  echo "FORBIDDEN MPFR/CORE-MATH/CRlibm symbol in production mm2: $mm2_bin" >&2
  exit 1
fi
exe_syms=$(
  { nm -u "$exe" 2>/dev/null || true; nm -D -u "$exe" 2>/dev/null || true; nm "$exe" 2>/dev/null || true; }
)
if [ -n "$exe_syms" ] && printf '%s\n' "$exe_syms" | grep -Eiq '(crlibm|core_math|\bcr_(exp|log)\b)'; then
  echo "FORBIDDEN CORE-MATH/CRlibm symbol in $exe" >&2
  exit 1
fi

mkdir -p "$out"
run_host() {
  ssh "$1" "set -eu; d=\$(mktemp -d); trap 'rm -f \"\$d/result\"; rmdir \"\$d\"' EXIT; env GLIBC_TUNABLES='$2' '$exe' '$inputs' '$inputs_sha' \"\$d/result\" >&2; cat \"\$d/result\""
}
run_host "$h1" '' > "$out/host1.tsv"
run_host "$h2" '' > "$out/host2.tsv"
run_host "$h1" 'glibc.cpu.hwcaps=-FMA' > "$out/no-fma.tsv"
cmp "$out/host1.tsv" "$out/host2.tsv"
cmp "$out/host1.tsv" "$out/no-fma.tsv"
sha256sum "$out/host1.tsv" "$out/host2.tsv" "$out/no-fma.tsv"
export MM2_X4_INPUTS="$inputs"
export MM2_X4_INPUTS_SHA256="$inputs_sha"
sh "$(dirname "$0")/../ocaml/test/scripts/orders-crossings.sh" \
  "$(dirname "$0")/../ocaml/test/fixtures/x4-counts.lean"
