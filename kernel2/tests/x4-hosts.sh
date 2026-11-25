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
case "$engine_lib" in /*) ;; *) echo 'MM2_ENGINE_LIB must be an absolute path' >&2; exit 2;; esac
case "$engine_lib" in *"'"*|*'
'*) echo 'unsupported path character in MM2_ENGINE_LIB' >&2; exit 2;; esac
[ -f "$engine_lib" ] || { echo "missing engine archive: $engine_lib" >&2; exit 1; }
[ -x "$exe" ] || { echo "test executable not executable locally: $exe" >&2; exit 1; }
[ ! -u "$exe" ] && [ ! -g "$exe" ] || { echo "AT_SECURE executable forbidden: $exe" >&2; exit 1; }
[ ! "$engine_lib" -nt "$exe" ] || { echo "stale test executable relative to $engine_lib" >&2; exit 1; }
lean_dir=$(cd "$(dirname "$engine_lib")/../../.." && pwd)
for olean in "$lean_dir/.lake/build/lib/lean/Engine/Exact.olean" "$lean_dir/.lake/build/lib/lean/Engine/Laws.olean"; do
  if [ -f "$olean" ] && [ "$olean" -nt "$engine_lib" ]; then
    echo "stale engine archive $engine_lib relative to $olean (rebuild Engine:static)" >&2
    exit 1
  fi
done
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
case "$mm2_bin" in
  */_build/*) [ ! "$engine_lib" -nt "$mm2_bin" ] || { echo "stale mm2 binary relative to $engine_lib" >&2; exit 1; } ;;
esac

check_engine_symbols() {
  target=$1
  syms=$(nm -u "$target" | sed -n 's/^[[:space:]]*U //p' | sed 's/@.*//')
  if printf '%s\n' "$syms" | grep -Eiq '(mm2_test_mpfr|crlibm|core_math|^cr_(exp|log)|^(exp|expf|expl|exp2|exp2f|exp2l|expm1|expm1f|expm1l|log|logf|logl|log2|log2f|log2l|log10|log10f|log10l|log1p|log1pf|log1pl|lean_float_exp|lean_float_log|lean_float_exp2|lean_float_log2|lean_float_log10)$)'; then
    echo "FORBIDDEN symbol reference in engine object $target:" >&2
    printf '%s\n' "$syms" | grep -Ei '(mm2_test_mpfr|crlibm|core_math|^cr_(exp|log)|^(exp|expf|expl|exp2|exp2f|exp2l|expm1|expm1f|expm1l|log|logf|logl|log2|log2f|log2l|log10|log10f|log10l|log1p|log1pf|log1pl|lean_float_exp|lean_float_log|lean_float_exp2|lean_float_log2|lean_float_log10)$)' >&2
    exit 1
  fi
}

check_engine_symbols "$engine_lib"
engine_all_syms=$(nm "$engine_lib")
printf '%s\n' "$engine_all_syms" | grep -q 'mm2_mpfr_exp' && printf '%s\n' "$engine_all_syms" | grep -q 'mm2_mpfr_log' || {
  echo "missing mm2_mpfr_exp/mm2_mpfr_log in $engine_lib" >&2
  exit 1
}
printf '%s\n' "$engine_all_syms" | grep -q 'mpfr_exp' && printf '%s\n' "$engine_all_syms" | grep -q 'mpfr_log' || {
  echo "missing mpfr_exp/mpfr_log reference in $engine_lib" >&2
  exit 1
}
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
if ! printf '%s\n' "$ldd_out" | grep -Ei 'libmpfr.*/nix/store/' >/dev/null; then
  echo "production mm2 does not link pinned nix libmpfr: $mm2_bin" >&2
  exit 1
fi
mm2_syms=$(
  { nm -u "$mm2_bin" 2>/dev/null || true; nm -D -u "$mm2_bin" 2>/dev/null || true; nm "$mm2_bin" 2>/dev/null || true; }
)
[ -n "$mm2_syms" ] || { echo "unable to read symbol table of $mm2_bin" >&2; exit 1; }
printf '%s\n' "$mm2_syms" | grep -q 'mpfr_exp' && printf '%s\n' "$mm2_syms" | grep -q 'mpfr_log' || {
  echo "missing mpfr_exp/mpfr_log in production mm2: $mm2_bin" >&2
  exit 1
}
if nm "$mm2_bin" >/dev/null 2>&1; then
  nm "$mm2_bin" | grep -q 'mm2_mpfr_exp' && nm "$mm2_bin" | grep -q 'mm2_mpfr_log' || {
    echo "missing mm2_mpfr_exp/mm2_mpfr_log in production mm2: $mm2_bin" >&2
    exit 1
  }
fi
if printf '%s\n' "$mm2_syms" | grep -Eiq '(mm2_test_mpfr|crlibm|core_math|\bcr_(exp|log)\b|lean_float_exp|lean_float_log)'; then
  echo "FORBIDDEN test/CORE-MATH/CRlibm/lean_float symbol in production mm2: $mm2_bin" >&2
  exit 1
fi
exe_syms=$(
  { nm -u "$exe" 2>/dev/null || true; nm -D -u "$exe" 2>/dev/null || true; nm "$exe" 2>/dev/null || true; }
)
if [ -n "$exe_syms" ] && printf '%s\n' "$exe_syms" | grep -Eiq '(crlibm|core_math|\bcr_(exp|log)\b)'; then
  echo "FORBIDDEN CORE-MATH/CRlibm symbol in $exe" >&2
  exit 1
fi

local_exe_sha=$(sha256sum "$exe" | cut -d ' ' -f 1)
local_lib_sha=$(sha256sum "$engine_lib" | cut -d ' ' -f 1)
local_sum_sha=$(sha256sum "$inputs/SHA256SUMS" | cut -d ' ' -f 1)
[ "$local_sum_sha" = "$inputs_sha" ] || {
  echo "local $inputs/SHA256SUMS ($local_sum_sha) != $inputs_sha" >&2; exit 1;
}

repo_root=$(cd "$(dirname "$0")/../.." && pwd)
if [ -f "$repo_root/audit/program/arithmetic.py.txt" ] && grep -q 'def emit_x4_draws' "$repo_root/audit/program/arithmetic.py.txt"; then
  expected_recipe_sha=$(sha256sum "$repo_root/audit/program/arithmetic.py.txt" | cut -d ' ' -f 1)
  grep -F "\"$expected_recipe_sha\"" "$inputs/manifest.json" >/dev/null || {
    echo "manifest.json recipe_sha256 does not match audit/program/arithmetic.py.txt ($expected_recipe_sha)" >&2; exit 1;
  }
fi

mkdir -p "$out"

probe_host() {
  host=$1
  label=$2
  info=$(ssh "$host" "set -eu
    [ -x '$exe' ] && [ ! -u '$exe' ] && [ ! -g '$exe' ]
    [ -f '$engine_lib' ]
    [ -f '$inputs/SHA256SUMS' ]
    exe_sha=\$(sha256sum '$exe' | cut -d ' ' -f 1)
    lib_sha=\$(sha256sum '$engine_lib' | cut -d ' ' -f 1)
    sum_sha=\$(sha256sum '$inputs/SHA256SUMS' | cut -d ' ' -f 1)
    arch=\$(uname -m)
    kern=\$(uname -r)
    model=\$(grep -m1 '^model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ *//')
    flags=\$(grep -m1 '^flags' /proc/cpuinfo | cut -d: -f2- | sed 's/^ *//')
    printf '%s\n%s\n%s\n%s\n%s\n%s\n%s\n' \"\$exe_sha\" \"\$lib_sha\" \"\$sum_sha\" \"\$arch\" \"\$kern\" \"\$model\" \"\$flags\"
  ")
  h_exe=$(printf '%s\n' "$info" | sed -n '1p')
  h_lib=$(printf '%s\n' "$info" | sed -n '2p')
  h_sum=$(printf '%s\n' "$info" | sed -n '3p')
  h_arch=$(printf '%s\n' "$info" | sed -n '4p')
  h_kern=$(printf '%s\n' "$info" | sed -n '5p')
  h_model=$(printf '%s\n' "$info" | sed -n '6p')
  h_flags=$(printf '%s\n' "$info" | sed -n '7p')
  [ "$h_exe" = "$local_exe_sha" ] || { echo "$label ($host) exe sha256 mismatch: $h_exe != $local_exe_sha" >&2; exit 1; }
  [ "$h_lib" = "$local_lib_sha" ] || { echo "$label ($host) engine_lib sha256 mismatch: $h_lib != $local_lib_sha" >&2; exit 1; }
  [ "$h_sum" = "$inputs_sha" ] || { echo "$label ($host) SHA256SUMS mismatch: $h_sum != $inputs_sha" >&2; exit 1; }
  [ "$h_arch" = "x86_64" ] || { echo "$label ($host) uname -m must be x86_64, got $h_arch" >&2; exit 1; }
  [ -n "$h_flags" ] || { echo "$label ($host) missing /proc/cpuinfo flags" >&2; exit 1; }
  if [ "$label" = "host1" ]; then
    printf '%s\n' "$h_flags" | tr ' ' '\n' | grep -qx 'fma' || {
      echo "host1 ($host) CPU lacks fma flag; -FMA path test would be a no-op" >&2; exit 1;
    }
  fi
  printf '%s\thost=%s\tuname_m=%s\tkernel=%s\texe=%s\tlib=%s\tsums=%s\tmodel=%s\tflags=%s\n' \
    "$label" "$host" "$h_arch" "$h_kern" "$h_exe" "$h_lib" "$h_sum" "$h_model" "$h_flags" >> "$out/hosts.txt"
}

: > "$out/hosts.txt"
probe_host "$h1" host1
probe_host "$h2" host2

run_host() {
  host=$1 tunable=$2 errfile=$3
  ssh "$host" "set -eu; d=\$(mktemp -d); trap 'rm -f \"\$d/result\"; rmdir \"\$d\"' EXIT; env GLIBC_TUNABLES='$tunable' '$exe' '$inputs' '$inputs_sha' \"\$d/result\" >&2; cat \"\$d/result\"" 2>"$errfile"
  cat "$errfile" >&2
}
run_host "$h1" '' "$out/host1.err" > "$out/host1.tsv"
run_host "$h2" '' "$out/host2.err" > "$out/host2.tsv"
run_host "$h1" 'glibc.cpu.hwcaps=-FMA' "$out/no-fma.err" > "$out/no-fma.tsv"

exp_fma=$(grep -m1 "^exp: this host's glibc differs from MPFR" "$out/host1.err" || true)
exp_nofma=$(grep -m1 "^exp: this host's glibc differs from MPFR" "$out/no-fma.err" || true)
[ -n "$exp_fma" ] && [ -n "$exp_nofma" ] || {
  echo 'missing glibc mis-rounding probe line from host1 or no-fma' >&2; exit 1;
}
[ "$exp_fma" != "$exp_nofma" ] || {
  echo "GLIBC_TUNABLES=glibc.cpu.hwcaps=-FMA had no observable effect ($exp_fma)" >&2; exit 1;
}

cmp "$out/host1.tsv" "$out/host2.tsv"
cmp "$out/host1.tsv" "$out/no-fma.tsv"
sha256sum "$out/host1.tsv" "$out/host2.tsv" "$out/no-fma.tsv"
sh "$(dirname "$0")/../ocaml/test/scripts/orders-crossings.sh" \
  "$(dirname "$0")/../ocaml/test/fixtures/x4-specials.lean"
