#!/usr/bin/env bash
# Fresh builder sessions in place of long waits inside one (CLAUDE.md §3, Waiting).
#   ops/builder.sh at <when> <task> [model]   a systemd user timer runs `run` at <when> (OnCalendar, e.g. "2026-11-01 05:30 UTC")
#   ops/builder.sh run <task> [model]         start `claude -p --name "builder: <task>"` now, inside the dev shell; if a builder runs, retry in 30 minutes
# Every schedule, deferral, start and exit is a line of data/builder/log.tsv; a session's output is data/builder/<id>.out.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p data/builder
cmd=$1; shift
[ "$cmd" = at ] && { when=$1; shift; }
task=$1 model=${2:-opus}
log() { printf '%s\t%s\t%s\t%s\t%s\n' "$(date -u +%FT%TZ)" "$1" "$2" "$model" "$task" >> data/builder/log.tsv; }
case $cmd in
at)
  systemd-run --user --quiet --unit="mm-builder-$(date -u +%s%N)" --on-calendar="$when" --timer-property=AccuracySec=1min \
    --working-directory="$PWD" --setenv=PATH=/etc/profiles/per-user/kevin/bin:/run/current-system/sw/bin \
    "$PWD/ops/builder.sh" run "$task" "$model"
  log scheduled "$when" ;;
run)
  exec 9> data/builder/lock
  if ! flock -n 9 || pgrep -f 'claude.* (--name|-n) builder: ' > /dev/null; then
    log busy -
    exec "$0" at "$(date -u -d '+30 min' '+%F %T UTC')" "$task" "$model"
  fi
  id=$(cat /proc/sys/kernel/random/uuid)
  log start "$id"
  status=0
  nix develop -c "$(command -v claude)" -p --name "builder: $task" --model "$model" --permission-mode auto --session-id "$id" \
    "Fresh session, started by ops/builder.sh inside the dev shell: run commands directly, not through nix develop -c. Read CLAUDE.md and PROGRESS.md. Task: the wake-up \"$task\" in PROGRESS's Now." \
    > "data/builder/$id.out" 2>&1 < /dev/null || status=$?
  log "exit $status" "$id" ;;
esac
