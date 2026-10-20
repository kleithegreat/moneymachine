"""Thesis agent sessions in stage 3's arm A sandbox (PROGRESS.md, Stage 10).

The workspace holds only the session's brief, its task file (for an ablation) and `./thesis-agent`,
with a private HOME holding a copy of the CLI credentials. The agent's tools are Read and Write in
the workspace and Bash for `./thesis-agent` only; no MCP, no settings, no web tools.
"""

import hashlib
import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

from gate.agent.harness import claude_binary, sandbox_command

HERE = Path(__file__).resolve().parent
MODEL = "claude-opus-5-5"
MAX_TURNS = 100
WALL_SECONDS = 3600
PERMITTED = {"Read", "Write", "Bash"}
TOOLS = ["--tools", "Read,Write,Bash",
         "--allowedTools", "Bash(./thesis-agent:*)", "Read(//work/**)", "Write(//work/**)",
         "--disallowedTools", "WebFetch", "WebSearch", "Edit", "Glob", "Grep", "Task", "NotebookEdit",
         "--permission-mode", "dontAsk", "--strict-mcp-config", "--setting-sources", "", "--no-session-persistence"]
BRIEFS = {"main": "brief.md", "noread": "brief-noread.md", "ablation": "brief-ablation.md"}
FROZEN = ("brief.md", "brief-noread.md", "brief-ablation.md", "client.py", "daemon.py", "harness.py", "registry.py",
          "positions.py", "scoring.py", "retrieval.py", "market.py", "runner.py")


def manifest_hash():
    """The track version's identity: briefs, tool, daemon and pipeline code, model, limits and flags."""
    h = hashlib.sha256()
    for f in FROZEN:
        h.update(f.encode() + b"\0" + (HERE / f).read_bytes())
    h.update(json.dumps([MODEL, MAX_TURNS, WALL_SECONDS, TOOLS, BRIEFS]).encode())
    return h.hexdigest()


def workspace(workdir, kind, task=None):
    work, home = Path(workdir) / "work", Path(workdir) / "home"
    (home / ".claude").mkdir(parents=True)
    work.mkdir(parents=True)
    shutil.copy(HERE / BRIEFS[kind], work / "brief.md")
    if task is not None:
        (work / "task.json").write_text(json.dumps(task, indent=1))
    (work / "thesis-agent").write_text(f"#!{sys.executable}\n" + (HERE / "client.py").read_text())
    os.chmod(work / "thesis-agent", 0o755)
    creds = home / ".claude" / ".credentials.json"
    shutil.copy(Path.home() / ".claude" / ".credentials.json", creds)
    os.chmod(creds, 0o600)
    return work, home


def run_session(workdir, kind, start_daemon, task=None):
    """Run one session; `start_daemon(socket_path)` returns the session's serving daemon."""
    workdir = Path(workdir)
    work, home = workspace(workdir, kind, task)
    daemon = start_daemon(work / "thesis-agent.sock")
    prompt = "Read brief.md in this directory and do exactly what it says."
    argv = [claude_binary(), "-p", prompt, "--model", MODEL, "--output-format", "stream-json", "--verbose", *TOOLS]
    transcript = workdir / "transcript.jsonl"
    turns, started, stopped = 0, time.time(), "finished"
    with open(transcript, "w") as out:
        proc = subprocess.Popen(sandbox_command(work, home, argv), stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, text=True)
        for line in proc.stdout:
            out.write(line)
            try:
                turns += json.loads(line).get("type") == "assistant"
            except json.JSONDecodeError:
                pass
            if turns > MAX_TURNS or time.time() - started > WALL_SECONDS:
                stopped = "turn limit" if turns > MAX_TURNS else "wall time"
                proc.kill()
                break
        proc.wait()
    daemon.close()
    shutil.rmtree(home)
    return {"kind": kind, "turns": turns, "stopped": stopped, "exit": proc.returncode, "seconds": round(time.time() - started),
            "manifest": manifest_hash(), "transcript_sha256": hashlib.sha256(transcript.read_bytes()).hexdigest()}


def audit(transcript, calls):
    """Client calls in the transcript against the session's daemon call records, and tools outside the set."""
    tools, client_calls = [], 0
    for line in open(transcript):
        try:
            d = json.loads(line)
        except json.JSONDecodeError:
            continue
        if d.get("type") == "assistant":
            for c in d["message"]["content"]:
                if c.get("type") == "tool_use":
                    tools.append(c["name"])
                    client_calls += c["name"] == "Bash" and "./thesis-agent" in c.get("input", {}).get("command", "")
    return {"client_calls": client_calls, "daemon_calls": len(calls), "match": client_calls == len(calls),
            "outside_permitted": sorted(set(tools) - PERMITTED)}
