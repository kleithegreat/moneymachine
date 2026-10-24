#!/usr/bin/env bash
# At login (mm-recorders-up.service): start every local recorder whose pidfile names no live process, through
# recorder-restart, so a reboot needs no manual step. A running recorder is never touched.
cd "$(dirname "$0")/.."
for d in data/sources_live data/live data/datalayer; do
  nix develop -c python -c "import json, sys; from ingest import live; r = json.load(open('$d/recorder.json')); sys.exit(live.alive(r['pid'], r['command']))" \
    && nix develop -c python -m cli recorder-restart "$d"
done
exit 0
