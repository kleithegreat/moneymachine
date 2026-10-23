#!/usr/bin/env bash
# Pulls the cloud recorder's files into data/live-oci/<instance id>/ (ops/oci/provision.sh). Append-only: nothing is
# ever deleted or truncated here, and a recreated VM lands in a new directory.
set -euo pipefail
cd "$(dirname "$0")/../.."
. data/live-oci/host.env
dest="data/live-oci/${MM_OCI_ID: -12}"
mkdir -p "$dest"
rsync -a --append-verify --timeout=120 -e "ssh -i $HOME/.ssh/mm_oci_ed25519 -o BatchMode=yes -o ConnectTimeout=20" \
  "mm@$MM_OCI_IP:/home/mm/live/" "$dest/"
date -u +%FT%TZ > data/live-oci/last-pull
