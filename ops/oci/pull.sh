#!/usr/bin/env bash
# Pulls the cloud recorder's files into data/live-oci/<instance id>/, append-only. A failed pull prints why to stderr
# and exits 1, leaving data/live-oci/last-pull as it was; ops/diskguard.py alarms when that file is over an hour old.
# Hyperliquid day files in the forward window [2026-11-01, 2027-01-31) stay on the VM (forward-window.exclude);
# everything else is pulled but a writer's transient `*.tmp`, which can vanish mid-transfer.
set -uo pipefail
cd "$(dirname "$0")/../.."
. data/live-oci/host.env
dest="data/live-oci/${MM_OCI_ID: -12}"
mkdir -p "$dest"
stage=$(mktemp -d "$dest/.pull.XXXXXX") || exit 1
trap 'rm -rf -- "$stage"' EXIT
ssh_cmd="ssh -i $HOME/.ssh/mm_oci_ed25519 -o BatchMode=yes -o ConnectTimeout=20"
err=""
for d in live clock datalayer sources_live; do
  mkdir -p "$dest/$d" "$stage/$d"
  skip=(--exclude='*.tmp'); [ "$d" = live ] && skip+=(--exclude-from=ops/oci/forward-window.exclude)
  out=$(rsync -a --link-dest="$PWD/$dest/$d" --timeout=120 "${skip[@]}" -e "$ssh_cmd" \
          "mm@$MM_OCI_IP:/home/mm/$d/" "$stage/$d/" 2>&1 | tail -1 && \
        python ops/oci/publish.py "$stage/$d" "$dest/$d" 2>&1) || err="$err $d: $out"
done
if [ -z "$err" ]; then
  date -u +%FT%TZ > data/live-oci/last-pull
  exit 0
fi
printf '%s\n' "${err//$'\n'/ }" >&2
exit 1
