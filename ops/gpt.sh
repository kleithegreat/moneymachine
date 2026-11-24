#!/usr/bin/env bash
# GPT through codex, jailed to one directory (CLAUDE.md, Reviewers): `ops/gpt.sh <dir> <model> <prompt-file> <out-dir>`.
# The jail sees the Nix store, system configuration, codex's own home, <dir> read-only and <out-dir> writable; nothing
# else under $HOME, so no data/, token file or other repository is readable whatever the model runs (opencode's
# permission rules were not such a boundary: audit/gpt-sandbox/findings.md). The reply's last message is
# <out-dir>/reply.md, the event log <out-dir>/run.log. MM_GPT_EXEC replaces `codex exec ...` (tests).
set -euo pipefail
dir=$(realpath "$1") model=$2 prompt=$(realpath "$3") out=$(realpath -m "$4")
mkdir -p "$out"
cmd=(codex exec -m "$model" -c model_reasoning_effort=high -s read-only --ephemeral --skip-git-repo-check -C "$dir"
     -o /out/reply.md -)
[ -z "${MM_GPT_EXEC:-}" ] || cmd=(sh -c "$MM_GPT_EXEC")
bwrap --unshare-all --share-net --die-with-parent --new-session \
  --ro-bind /nix /nix --ro-bind /etc /etc --ro-bind /run/current-system /run/current-system \
  --ro-bind-try /run/systemd/resolve /run/systemd/resolve --ro-bind-try /run/wrappers /run/wrappers \
  --proc /proc --dev /dev --tmpfs /tmp --tmpfs "$HOME" \
  --bind "$HOME/.codex" "$HOME/.codex" --ro-bind "$dir" "$dir" --bind "$out" /out \
  --setenv HOME "$HOME" --setenv PATH "$PATH" --chdir "$dir" \
  "${cmd[@]}" < "$prompt" > "$out/run.log" 2>&1
