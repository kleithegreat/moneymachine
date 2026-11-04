"""Thesis agent sessions in the shared sandbox (`sandbox/`; audit/criteria.md, stage 10). The workspace holds only
the session's brief, its task file (for an ablation) and `./thesis-agent`."""

import functools
import json
import subprocess
import sys
from pathlib import Path

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
    """Run one session; `start_daemon(socket_path)` returns the session's serving daemon."""
    workspace(workdir, kind, task)
    daemon = start_daemon(session.socket_path(workdir, CLIENT))
    s = session.run(workdir, CLIENT, MODEL, MAX_TURNS, WALL_SECONDS)
    daemon.close()
    return {"kind": kind, **s}


def audit(transcript, calls):
    """Client calls in the transcript against the session's daemon call records, and tools outside the set."""
    use = session.tool_use(transcript, CLIENT)
    return {"client_calls": use["client_calls"], "daemon_calls": len(calls), "match": use["client_calls"] == len(calls),
            "outside_permitted": use["outside_permitted"]}
