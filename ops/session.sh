#!/usr/bin/env bash
# Headless Claude sessions for the project's roles (CLAUDE.md §3, Orchestration and Waiting), run from the checkout whose
# data/builder holds the log: `nix run .#session -- ...`.
#   session at <when> <role> <task> [model] [stop] [flags]   a transient systemd timer runs `run` at <when> (OnCalendar)
#   session run <role> <task> [model] [stop] [flags]         start `claude -p --name "<role>: <task>"` now, in the dev shell
# Roles: `builder` (default model opus, blocks, retries in 30 minutes while another builder runs) and `architect`
# (Fable 5.2 named with `[1m]`: below Claude Code 2.1.321 `fable` is 5.1, and an id a version does not know gets an
# assumed 200k window; detaches and prints its id).
# Flags: --brief FILE (the prompt; an architect's follows data/builder/architect-header.txt), --resume ID, --dir DIR (the
# worktree it works in), --effort E (architect: xhigh).
# <stop> is a time `date -d` reads; there the session and everything it started are stopped. A session is one scope,
# capped so that its heaviest process dies alone (OOMPolicy=continue), never this PC's other work.
# Every schedule, deferral, start and exit is a line of data/builder/log.tsv; output is data/builder/<id>.out.
# Its temporary files (nix shells, pytest, Claude Code's own) live in /tmp/<role letter><id prefix>, deleted at exit:
# /tmp is a small tmpfs that leaked shells filled twice on 2026-11-08, and the short path keeps Unix sockets under their limit.
set -euo pipefail
root=$PWD
mkdir -p data/builder
cmd=$1; shift
[ "$cmd" = at ] && { when=$1; shift; }
args=("$@")
role=$1 task=$2; shift 2
positional=() brief='' resume='' dir=$root effort='' id=''
while [ $# -gt 0 ]; do
  case $1 in
  --brief) brief=$(realpath "$2"); shift 2 ;;
  --resume) resume=$2; shift 2 ;;
  --dir) dir=$(realpath "$2"); shift 2 ;;
  --effort) effort=$2; shift 2 ;;
  --id) id=$2; shift 2 ;;
  *) positional+=("$1"); shift ;;
  esac
done
case $role in
builder) model=${positional[0]:-opus} ;;
architect) model=${positional[0]:-'claude-fable-5-2[1m]'}; effort=${effort:-xhigh} ;;
*) echo "unknown role: $role" >&2; exit 2 ;;
esac
stop=${positional[1]:-}
label="$role: $task"
log() { printf '%s\t%s\t%s\t%s\t%s\n' "$(date -u +%FT%TZ)" "$1" "$2" "$model" "$label" >> data/builder/log.tsv; }
case $cmd in
at)
  systemd-run --user --quiet --unit="mm-$role-$(date -u +%s%N)" --on-calendar="$when" --timer-property=AccuracySec=1min \
    --working-directory="$root" --setenv=PATH="$PATH" "$0" run "${args[@]}"
  log scheduled "$when" ;;
run)
  if [ "$role" = builder ]; then
    exec 9> data/builder/lock
    if ! flock -n 9 || pgrep -f 'claude.* (--name|-n) builder: ' > /dev/null; then
      log busy -
      exec "$0" at "$(date -u -d '+30 min' '+%F %T UTC')" "${args[@]}"
    fi
  fi
  if [ -z "$id" ]; then
    id=${resume:-$(cat /proc/sys/kernel/random/uuid)}
    if [ "$role" = architect ]; then
      setsid -f "$0" run "${args[@]}" --id "$id" > /dev/null 2>&1 < /dev/null
      echo "$id"
      exit 0
    fi
  fi
  session=(--session-id "$id")
  [ -z "$resume" ] || session=(--resume "$id")
  if [ -z "$brief" ]; then
    prompt="Fresh session, started by the session app inside the dev shell: run commands directly, not through nix develop -c. Read CLAUDE.md and PROGRESS.md. Task: the wake-up \"$task\" in PROGRESS's Now."
  elif [ -n "$resume" ]; then
    prompt=$(cat "$brief")
  else
    prompt=$(cat "data/builder/$role-header.txt" "$brief")
  fi
  effortflag=(); [ -z "$effort" ] || effortflag=(--effort "$effort")
  limit=(); [ -z "$stop" ] || limit=(-p "RuntimeMaxSec=$(( $(date -d "$stop" +%s) - $(date +%s) ))")
  tmp=/tmp/${role:0:1}${id:0:4}
  mkdir -p "$tmp"
  log start "$id"
  status=0
  (
    cd "$dir"
    systemd-run --user --scope --quiet --unit="mm-$role-$id" -p MemoryMax=11G -p MemorySwapMax=2G -p OOMPolicy=continue "${limit[@]}" \
      env TMPDIR="$tmp" CLAUDE_CODE_TMPDIR="$tmp" nix develop -c "$(command -v claude)" -p --name "$label" --model "$model" \
      "${effortflag[@]}" --permission-mode auto "${session[@]}" "$prompt"
  ) > "data/builder/$id.out" 2>&1 < /dev/null || status=$?
  rm -rf "$tmp"
  log "exit $status" "$id" ;;
esac
