#!/usr/bin/env bash
# Hourly (mm-diskguard.timer): below LIMIT_GB free on the data filesystem, add one line under PROGRESS.md's Blockers.
set -euo pipefail
cd "$(dirname "$0")/.."
LIMIT_GB=${LIMIT_GB:-20}
free=$(df -BG --output=avail data | tail -1 | tr -dc 0-9)
mark="**Disk space low"
if [ "$free" -lt "$LIMIT_GB" ] && ! grep -q "$mark" PROGRESS.md; then
  line="- $mark ($(date -u +%FT%TZ)): ${free} GB free on the filesystem holding data/, under ${LIMIT_GB} GB.** The recorders append about 150 MB a day. Compress closed day files, delete regenerable data with hashes recorded, or add disk."
  awk -v l="$line" '{print} /^## Blockers$/ {getline; print; print l}' PROGRESS.md > PROGRESS.md.tmp && mv PROGRESS.md.tmp PROGRESS.md
fi
