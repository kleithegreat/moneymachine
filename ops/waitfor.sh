#!/bin/sh
# Waits until a condition holds, or until the process doing the work is gone, whichever comes first, so a crash ends
# the wait instead of hanging it. Usage: ops/waitfor.sh <pid | systemd user unit | ssh-host:unit> '<condition command>'
# Exit 0: the condition holds. Exit 1: the process ended first (its last log lines are the caller's to read).
alive() {
  case "$1" in
    *:*) ssh -o BatchMode=yes "kevin@${1%%:*}" "systemctl is-active --quiet '${1#*:}' || systemctl --user is-active --quiet '${1#*:}'" ;;
    *[!0-9]*) systemctl --user is-active --quiet "$1" ;;
    *) kill -0 "$1" 2>/dev/null ;;
  esac
}
until sh -c "$2"; do
  alive "$1" || { sh -c "$2" && exit 0; echo "waitfor: $1 ended before: $2" >&2; exit 1; }
  sleep 30
done
