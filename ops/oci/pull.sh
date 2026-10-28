#!/usr/bin/env bash
# Pulls the cloud recorder's files into data/live-oci/<instance id>/, append-only; a failed pull adds a line under
# PROGRESS.md's Blockers, which the next good pull removes.
set -uo pipefail
cd "$(dirname "$0")/../.."
. data/live-oci/host.env
dest="data/live-oci/${MM_OCI_ID: -12}"
mark="**Cloud recorder pull failing"
ssh_cmd="ssh -i $HOME/.ssh/mm_oci_ed25519 -o BatchMode=yes -o ConnectTimeout=20"
err=""
for d in live clock datalayer sources_live; do
  mkdir -p "$dest/$d"
  out=$(rsync -a --append-verify --timeout=120 -e "$ssh_cmd" "mm@$MM_OCI_IP:/home/mm/$d/" "$dest/$d/" 2>&1) || err="$err $d: $(echo "$out" | tail -1)"
done
if [ -z "$err" ]; then
  date -u +%FT%TZ > data/live-oci/last-pull
  grep -q "$mark" PROGRESS.md && sed -i "/$(printf '%s' "$mark" | sed 's/\*/\\*/g')/d" PROGRESS.md
  exit 0
fi
if ! grep -q "$mark" PROGRESS.md; then
  line="- $mark (since $(date -u +%FT%TZ)):$err.** Last good pull: $(cat data/live-oci/last-pull 2>/dev/null || echo never). If this PC's public IP changed, rerun ops/oci/provision.sh, which updates the VM's SSH rule. Files already pulled are safe; the VM keeps recording meanwhile."
  awk -v l="$line" '{print} /^## Blockers$/ {getline; print; print l}' PROGRESS.md > PROGRESS.md.tmp && mv PROGRESS.md.tmp PROGRESS.md
fi
exit 1
