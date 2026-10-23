#!/usr/bin/env bash
# Hourly (mm-diskguard.timer): if free space on the data filesystem falls below LIMIT_GB, add one dated line under
# PROGRESS.md's Blockers, before space threatens the recorders (human decision 2026-10-23). It never deletes.
set -euo pipefail
cd "$(dirname "$0")/.."
LIMIT_GB=${LIMIT_GB:-20}
free=$(df -BG --output=avail data | tail -1 | tr -dc 0-9)
mark="**Disk space low"
if [ "$free" -lt "$LIMIT_GB" ] && ! grep -q "$mark" PROGRESS.md; then
  line="- $mark ($(date -u +%FT%TZ)): ${free} GB free on the filesystem holding data/, under ${LIMIT_GB} GB.** The recorders append about 150 MB a day. Compress closed day files, delete regenerable data with hashes recorded, or add disk."
  awk -v l="$line" '{print} /^## Blockers$/ {getline; print; print l}' PROGRESS.md > PROGRESS.md.tmp && mv PROGRESS.md.tmp PROGRESS.md
fi
