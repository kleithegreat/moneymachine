"""Thesis agent sessions in the shared sandbox (`sandbox/`; audit/criteria.md, stage 10). The workspace holds only
the session's brief, its task file (for an ablation) and `./thesis-agent`."""

import functools
import json
import subprocess
import sys
from pathlib import Path
from typing import Any

from ingest import terms
from sandbox import session
from thesis.daemon import SPEC

HERE = Path(__file__).resolve().parent
REPO = HERE.parent
MODEL = "claude-opus-5-5"
MAX_TURNS = 100
WALL_SECONDS = 3600
CLIENT = "thesis-agent"
BRIEFS = {"main": "brief.md", "noread": "brief-noread.md", "ablation": "brief-ablation.md"}
BRIEF_TEXT = {kind: (HERE / name).read_text() for kind, name in BRIEFS.items()}
DATA = ("policy.json", "venue/hyperliquid/rules.json", "venue/hyperliquid/execution.json",
        "thesis/SCORING.md", "flake.lock", "kernel/Cargo.lock")


@functools.cache
def manifest_files(kernel):
    """Every repo module the runner and the report load (in a fresh interpreter, so the caller's imports do not
    matter), the track's pinned kernel binary `kernel` (it writes the ledger), the briefs and the data files the track
    reads."""
    loaded = subprocess.run([sys.executable, "-c", "import sys, thesis.runner, thesis.report; print(*sorted({m.__file__ "
                             "for m in list(sys.modules.values()) if getattr(m, '__file__', None)}), sep='\\n')"],
                            cwd=REPO, capture_output=True, text=True, check=True).stdout.splitlines()
    code = sorted(p.resolve() for p in map(Path, loaded) if p.resolve().is_relative_to(REPO))
    return code + [Path(kernel)] + [HERE / n for n in BRIEFS.values()] + [REPO / f for f in DATA]


@functools.cache
def manifest_hash(kernel):
    """The track version's identity: its files, the `claude` build (its store path), model, limits and flags, and the
    retrieval allowlist it reads from the source registry (not the registry's other records), hashed once per process,
    as the track reads them once."""
    return session.identity(manifest_files(kernel), [MODEL, MAX_TURNS, WALL_SECONDS, session.PROMPT, session.tools(CLIENT), BRIEFS,
                                                    sorted(terms.allowlist(retrieval=True)), session.claude_binary()])


def workspace(workdir, kind, task=None):
    files = {"brief.md": BRIEF_TEXT[kind]}
    if task is not None:
        files["task.json"] = json.dumps(task, indent=1)
    session.workspace(workdir, files, CLIENT, SPEC)


def run_session(workdir, kind, start_daemon, task=None):
    """Run one session; `start_daemon(socket_path)` returns the session's serving daemon, closed however the session ends."""
    workspace(workdir, kind, task)
    daemon = start_daemon(session.socket_path(workdir, CLIENT))
    try:
        s = session.run(workdir, CLIENT, MODEL, MAX_TURNS, WALL_SECONDS)
    finally:
        daemon.close()
    return {"kind": kind, **s}


BLOCK_TYPES = {"text", "thinking", "redacted_thinking", "fallback", "tool_use", "tool_result"}


def events(transcript: Path) -> list[dict[str, Any]]:
    """The CLI's stream-json events, every line parsed: a torn or corrupt line raises, so a transcript that cannot be read in
    full cannot pass."""
    parsed = [json.loads(line) for line in transcript.read_text().splitlines() if line.strip()]
    if not all(isinstance(e, dict) for e in parsed):
        raise ValueError("a transcript line is not an event")
    return parsed


def audit(transcript: Path, calls: list[dict[str, Any]]) -> dict[str, Any]:
    """The session's daemon call count and the tools it executed outside `session.PERMITTED` (audit/criteria.md, stage 10,
    C10.2 wording (b)). It raises, and the session fails C10.2, unless the transcript is complete: every line parses, it opens
    with the `system/init` event and ends with `result`, and every content block is of a type in `BLOCK_TYPES` (a
    `server_tool_use` or `mcp_tool_use` block is not). A call to a tool outside the set is not counted when the CLI refused it
    (its id is in `permission_denials`) or the tool is not in init's `tools`, so it never ran."""
    stream = events(transcript)
    init = [e for e in stream if e.get("type") == "system" and e.get("subtype") == "init"]
    if not init or stream[-1].get("type") != "result":
        raise ValueError("the transcript lacks its init event or its result")
    available = set(init[0]["tools"])
    denied = {d["tool_use_id"] for d in stream[-1].get("permission_denials", [])}
    executed = set()
    for event in stream:
        content = event.get("message", {}).get("content") if event.get("type") in ("assistant", "user") else None
        for block in content if isinstance(content, list) else []:
            if block.get("type") not in BLOCK_TYPES:
                raise ValueError(f"content block of type {block.get('type')!r}")
            if block["type"] == "tool_use" and block["id"] not in denied and block["name"] in available:
                executed.add(block["name"])
    return {"daemon_calls": len(calls), "outside_permitted": sorted(executed - session.PERMITTED)}
