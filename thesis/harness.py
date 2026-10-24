"""Thesis agent sessions in the shared sandbox (`sandbox/`; audit/criteria.md, stage 10). The workspace holds only
the session's brief, its task file (for an ablation) and `./thesis-agent`."""

import json
from pathlib import Path

from ingest import terms
from sandbox import session
from thesis.daemon import SPEC

HERE = Path(__file__).resolve().parent
MODEL = "claude-opus-5-5"
MAX_TURNS = 100
WALL_SECONDS = 3600
CLIENT = "thesis-agent"
BRIEFS = {"main": "brief.md", "noread": "brief-noread.md", "ablation": "brief-ablation.md"}
FROZEN = ("brief.md", "brief-noread.md", "brief-ablation.md", "daemon.py", "harness.py", "registry.py",
          "positions.py", "scoring.py", "retrieval.py", "market.py", "runner.py")


def manifest_hash():
    """The track version's identity: briefs, daemon and pipeline code, the shared sandbox, model, limits and flags."""
    return session.identity([HERE / f for f in FROZEN] + [terms.REGISTRY],
                            [MODEL, MAX_TURNS, WALL_SECONDS, session.PROMPT, session.tools(CLIENT), BRIEFS])


def workspace(workdir, kind, task=None):
    files = {"brief.md": (HERE / BRIEFS[kind]).read_text()}
    if task is not None:
        files["task.json"] = json.dumps(task, indent=1)
    session.workspace(workdir, files, CLIENT, SPEC)


def run_session(workdir, kind, start_daemon, task=None):
    """Run one session; `start_daemon(socket_path)` returns the session's serving daemon."""
    workspace(workdir, kind, task)
    daemon = start_daemon(session.socket_path(workdir, CLIENT))
    s = session.run(workdir, CLIENT, MODEL, MAX_TURNS, WALL_SECONDS)
    daemon.close()
    return {"kind": kind, **s, "manifest": manifest_hash()}


def audit(transcript, calls):
    """Client calls in the transcript against the session's daemon call records, and tools outside the set."""
    use = session.tool_use(transcript, CLIENT)
    return {"client_calls": use["client_calls"], "daemon_calls": len(calls), "match": use["client_calls"] == len(calls),
            "outside_permitted": use["outside_permitted"]}
