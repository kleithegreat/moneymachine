#!/bin/sh
# Lets agy's Claude write and run commands for one build, then restores its read-only reviewer profile.
# The read-only profile is what keeps outside reviewers (Neon) unable to edit or execute (CLAUDE.md, Reviewers),
# so no review may run while it is "on".
# Usage: sh ops/agy-write.sh on DIR... | off   (on while on adds DIR to the trusted directories)
set -eu
settings="$HOME/.gemini/antigravity-cli/settings.json"
backup="$HOME/.cache/agy-settings.readonly.json"
case "${1:-}" in
  on)
    [ "$#" -ge 2 ] || { echo 'usage: agy-write.sh on DIR...' >&2; exit 2; }
    shift
    [ -e "$backup" ] || cp "$settings" "$backup"
    current=$(cat "$settings")
    for dir in "$@"; do
      dir=$(cd "$dir" && pwd)
      current=$(printf '%s' "$current" | jq --arg w "$dir" '
        .enableTerminalSandbox = false
        | .permissions.allow = ["read_file(*)", "write_file(*)", "command(*)"]
        | .permissions.deny = ["read_url(*)", "execute_url(*)", "mcp(*)"]
        | .trustedWorkspaces = ((.trustedWorkspaces + [$w]) | unique)')
      echo "agy may write and run commands in $dir until 'off'"
    done
    printf '%s\n' "$current" > "$settings"
    ;;
  off)
    [ -e "$backup" ] || { echo 'already off' >&2; exit 0; }
    cp "$backup" "$settings"
    rm "$backup"
    echo 'agy is read-only again'
    ;;
  *)
    echo 'usage: agy-write.sh on WORKTREE | off' >&2
    exit 2
    ;;
esac
