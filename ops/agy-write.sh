#!/bin/sh
# Lets agy's Claude write and run commands for one build, then restores its read-only reviewer profile.
# The read-only profile is what keeps outside reviewers (Neon) unable to edit or execute (CLAUDE.md, Reviewers),
# so no review may run while it is "on".
# Usage: sh ops/agy-write.sh on WORKTREE | off
set -eu
settings="$HOME/.gemini/antigravity-cli/settings.json"
backup="$HOME/.cache/agy-settings.readonly.json"
case "${1:-}" in
  on)
    [ "$#" = 2 ] || { echo 'usage: agy-write.sh on WORKTREE' >&2; exit 2; }
    worktree=$(cd "$2" && pwd)
    [ ! -e "$backup" ] || { echo "already on: $backup exists; run 'off' first" >&2; exit 1; }
    cp "$settings" "$backup"
    jq --arg w "$worktree" '
      .enableTerminalSandbox = false
      | .permissions.allow = ["read_file(*)", "write_file(*)", "command(*)"]
      | .permissions.deny = ["read_url(*)", "execute_url(*)", "mcp(*)"]
      | .trustedWorkspaces += [$w]' "$backup" > "$settings"
    echo "agy may write and run commands in $worktree until 'off'"
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
