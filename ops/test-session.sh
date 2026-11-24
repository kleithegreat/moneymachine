#!/usr/bin/env bash
# Tests of ops/session.sh from outside, with claude, pgrep, systemd-run and nix stubbed on PATH (plan, step 2, point 3).
# A flake check: it needs no network, no user namespaces and no git history.
set -uo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
scratch=$(mktemp -d "${TMPDIR:-/tmp}/mm-test-session.XXXXXX")
trap 'rm -rf "$scratch"' EXIT
fails=0

check() {
  local name=$1
  shift
  if "$@"; then echo "ok   $name"; else echo "FAIL $name"; fails=$((fails + 1)); fi
}

# start <busy:0|1> <argv...>: a fresh work directory $w with the stubs, and `session.sh run <argv>` run in it.
start() {
  local busy=$1 pgrep_code=1
  shift
  [ "$busy" = 1 ] && pgrep_code=0
  w=$(mktemp -d "$scratch/w.XXXXXX")
  mkdir -p "$w/ops" "$w/stubs" "$w/data/builder"
  cp "$here/session.sh" "$w/ops/session.sh"
  local name code
  for name in claude pgrep; do
    code=0
    [ "$name" = pgrep ] && code=$pgrep_code
    cat >"$w/stubs/$name" <<STUB
#!/bin/sh
echo "\$@" >> $w/$name.args
echo "\$TMPDIR \$CLAUDE_CODE_TMPDIR \$(test -d "\$TMPDIR" && echo exists)" > $w/$name.env
exit $code
STUB
  done
  cat >"$w/stubs/systemd-run" <<STUB
#!/bin/sh
echo "\$@" >> $w/systemd-run.args
case " \$* " in *" --scope "*) while [ "\$1" != env ]; do shift; done; exec "\$@";; esac
STUB
  cat >"$w/stubs/nix" <<STUB
#!/bin/sh
echo "\$@" >> $w/nix.args
shift 2
exec "\$@"
STUB
  chmod +x "$w"/stubs/*
  [ -z "${PRE:-}" ] || eval "$PRE"
  (cd "$w" && PATH="$w/stubs:$PATH" ./ops/session.sh run "$@" >"$w/stdout" 2>"$w/stderr")
}

# waitlog <lines>: wait until data/builder/log.tsv in $w has that many lines.
waitlog() {
  local i
  for i in $(seq 200); do
    [ -f "$w/data/builder/log.tsv" ] && [ "$(wc -l <"$w/data/builder/log.tsv")" -ge "$1" ] && return 0
    sleep 0.05
  done
  return 1
}

field() { sed -n "${1}p" "$w/data/builder/log.tsv" | cut -f"$2"; }

builder_run() {
  start 0 builder "stage 3 check" sonnet || return 1
  waitlog 2 || return 1
  local id
  id=$(field 1 3)
  [ "$(field 1 2)" = start ] && [ "$(field 2 2)" = "exit 0" ] || return 1
  [ "$(field 2 3)" = "$id" ] || return 1
  [ "$(field 1 4)" = sonnet ] && [ "$(field 1 5)" = "builder: stage 3 check" ] || return 1
  grep -q -- "-p --name builder: stage 3 check --model sonnet --permission-mode auto --session-id $id " "$w/claude.args" || return 1
  grep -q "^develop -c " "$w/nix.args" || return 1
  [ -e "$w/data/builder/$id.out" ] || return 1
}
check "3a. a builder's run logs start and exit 0 under one id and names the session" builder_run

own_tmp() {
  start 0 builder "stage 3 check" sonnet || return 1
  waitlog 2 || return 1
  local id tmp
  id=$(field 1 3)
  tmp=$(cut -d' ' -f1 "$w/claude.env")
  [ "$(cat "$w/claude.env")" = "$tmp $tmp exists" ] || return 1
  [ "$tmp" != "${TMPDIR:-/tmp}" ] || return 1
  case $tmp in *"${id:0:4}"*) ;; *) return 1 ;; esac
  [ ! -e "$tmp" ]
}
check "3b. its own temporary directory exists during the run and is gone after" own_tmp

stop_time() {
  start 0 builder "stage 3 check" sonnet "+1 hour" || return 1
  local limit
  limit=$(grep -o 'RuntimeMaxSec=[0-9]*' "$w/systemd-run.args" | head -1 | cut -d= -f2)
  [ -n "$limit" ] && [ "$limit" -ge 3590 ] && [ "$limit" -le 3600 ]
}
check "3c. a stop time of +1 hour gives RuntimeMaxSec from 3590 to 3600" stop_time

defers() {
  start 1 builder "stage 3 check" sonnet || return 1
  waitlog 2 || return 1
  [ "$(field 1 2)" = busy ] && [ "$(field 2 2)" = scheduled ] || return 1
  [ ! -e "$w/claude.args" ] || return 1
  grep -q 'ops/session.sh run builder stage 3 check sonnet *$' "$w/systemd-run.args"
}
check "3d. a builder started while another runs logs busy, then scheduled, and starts nothing" defers

architect() {
  printf 'HEADER\n' >"$scratch/header.txt"
  printf 'BRIEF\n' >"$scratch/brief.txt"
  PRE='printf "HEADER\n" > "$w/data/builder/architect-header.txt"'
  start 0 architect design --brief "$scratch/brief.txt" --dir "$scratch" || return 1
  unset PRE
  waitlog 2 || return 1
  local id
  id=$(field 1 3)
  [ "$(tr -d '[:space:]' <"$w/stdout")" = "$id" ] && [ "$(field 2 3)" = "$id" ] || return 1
  [ "$(field 1 2)" = start ] && [ "$(field 2 2)" = "exit 0" ] || return 1
  [ "$(field 1 4)" = claude-opus-5-5 ] && [ "$(field 1 5)" = "architect: design" ] || return 1
  grep -q -- "--model claude-opus-5-5 --effort max --permission-mode auto --session-id $id" "$w/claude.args" || return 1
  [ "$(tail -n 2 "$w/claude.args" | sed "s/^.* $id //")" = "$(printf 'HEADER\nBRIEF')" ]
}
check "3e. an architect detaches, prints its id, runs claude-opus-5-5 at max effort, header then brief" architect

exit $((fails > 0))
