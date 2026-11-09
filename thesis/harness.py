"""Thesis agent sessions in the shared sandbox (`sandbox/`; audit/criteria.md, stage 10). The workspace holds only
the session's brief, its task file (for an ablation) and `./thesis-agent`."""

import functools
import json
import re
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
    files = {"brief.md": BRIEF_TEXT[kind] + "\nUse exactly one literal ./thesis-agent command per Bash call. "
             "Separate arguments with spaces or tabs; use whole single-quoted arguments for URLs and reasons, "
             "or whole double-quoted arguments without expansions or escapes. No shell operators, redirections, "
             "substitutions, variables, globs, loops or scripts: these fail the session audit.\n"}
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


LITERAL = r"(?:[a-zA-Z0-9_./:@%+,=-]+|'[^'\r\n\x00]*'|\"[^\"$`\\\r\n\x00]*\")"
EXECUTION = re.compile(r"[ \t]*\./thesis-agent(?:[ \t]+" + LITERAL + r")*[ \t]*")


def results(transcript):
    """Tool uses, results and denials from a complete, unambiguous transcript; malformed or truncated fails closed."""
    uses, out, denied, complete = {}, {}, [], False
    for line in open(transcript):
        d = json.loads(line)
        if d.get("type") == "result":
            complete = True
            denied = [x["tool_use_id"] for x in d.get("permission_denials", [])]
        content = d.get("message", {}).get("content") if d.get("type") in ("assistant", "user") else None
        for c in content if isinstance(content, list) else []:
            if c.get("type") == "tool_use":
                if c["id"] in uses:
                    raise ValueError("duplicate tool use id")
                uses[c["id"]] = c
            if c.get("type") == "tool_result":
                if c["tool_use_id"] in out:
                    raise ValueError("duplicate tool result id")
                out[c["tool_use_id"]] = c
    if not complete or out.keys() - uses.keys() or set(denied) - uses.keys():
        raise ValueError("incomplete or unattributable transcript")
    return uses, out, denied


def audit(transcript, calls):
    """C10.2: daemon records are the call list, refusals included. The transcript proves only an execution count and no
    bypass: every non-denied Bash must be one literal client command with a result. No shell program is interpreted."""
    try:
        uses, outputs, denied = results(transcript)
    except (ValueError, KeyError, TypeError) as e:
        return {"match": False, "transcript_error": str(e)}
    executions, unattributable = 0, []
    for i, u in uses.items():
        if u["name"] == "Bash" and i not in denied:
            if EXECUTION.fullmatch(u["input"].get("command", "")) and i in outputs:
                executions += 1
            else:
                unattributable.append(i)
    requests = [c["request"] for c in calls]
    valid = all(isinstance(r.get("argv"), list) and all(isinstance(a, str) for a in r["argv"])
                and "refusal" in r and (r["refusal"] is None or isinstance(r["refusal"], str) and bool(r["refusal"]))
                for r in requests)
    outside = sorted({u["name"] for u in uses.values()} - session.PERMITTED)
    return {"client_executions": executions, "client_calls": len(calls), "daemon_calls": len(calls),
            "refused": sum(bool(r.get("refusal")) for r in requests), "unattributable": unattributable,
            "match": valid and not outside and not unattributable and executions == len(calls), "outside_permitted": outside}
