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
