#!/usr/bin/env bash
# Local check of ops/gpt.sh's jail (plan, step 2, point 4); local because bwrap needs user namespaces. The jailed command
# reads the reviewed directory, cannot write to it, writes only to its output directory, and sees nothing else of $HOME.
set -uo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo=$(dirname "$here")
scratch=$(mktemp -d "${TMPDIR:-/tmp}/mm-test-gpt.XXXXXX")
trap 'rm -rf "$scratch"' EXIT
fails=0

# jailed <command>: runs gpt.sh with MM_GPT_EXEC=<command> over a fresh review and output directory; sets $code and $log.
jailed() {
  rm -rf "$scratch/review" "$scratch/out"
  mkdir "$scratch/review"
  echo visible >"$scratch/review/seen.txt"
  echo unused >"$scratch/prompt.txt"
  MM_GPT_EXEC=$1 bash "$here/gpt.sh" "$scratch/review" model "$scratch/prompt.txt" "$scratch/out" >/dev/null 2>&1
  code=$?
  log=$(cat "$scratch/out/run.log" 2>/dev/null)
}

check() {
  if [ "$2" = ok ]; then echo "ok   $1"; else echo "FAIL $1"; fails=$((fails + 1)); fi
}

jailed "cat seen.txt"
[ $code -eq 0 ] && [ "$log" = visible ] && check "4a. reads the reviewed directory" ok || check "4a. reads the reviewed directory" no

jailed "echo x > seen.txt"
[ $code -ne 0 ] && [ "$(cat "$scratch/review/seen.txt")" = visible ] && check "4b. cannot write the reviewed directory" ok || check "4b. cannot write the reviewed directory" no

jailed "echo reply > /out/reply.md"
[ $code -eq 0 ] && [ "$(cat "$scratch/out/reply.md" 2>/dev/null)" = reply ] && check "4c. writes its output directory" ok || check "4c. writes its output directory" no

jailed "echo x > $HOME/jail-escape-test"
[ $code -ne 0 ] || [ ! -e "$HOME/jail-escape-test" ] && check "4d. writes nothing outside its output directory" ok || check "4d. writes nothing outside its output directory" no
rm -f "$HOME/jail-escape-test"

jailed "ls -A $repo $HOME/repos; cat $repo/CLAUDE.md"
[ $code -ne 0 ] && grep -q "No such file" <<<"$log" && ! grep -q "spiritual idea" <<<"$log" && check "4e. sees nothing else of HOME" ok || check "4e. sees nothing else of HOME" no

exit $((fails > 0))
