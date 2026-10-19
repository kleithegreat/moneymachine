"""Run the stage 3 research agent (arm A) in a bubblewrap sandbox against an mm-agent daemon.

Inside the sandbox: the Nix store, a minimal /etc, /bin and /usr read-only, the workspace (/work) and a
private HOME (/home/agent, holding only a copy of the CLI credentials). No repo, no data/, no
ledger, no real HOME. The agent's tools are Read and Write in the workspace and Bash for
./mm-agent only, with no MCP servers, no setting sources and no web tools.
"""

import hashlib
import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

from gate.agent.daemon import Daemon

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
MODEL = "claude-opus-5-5"
MAX_TURNS = 200
WALL_SECONDS = 2 * 3600
PROMPT = "Read brief.md in this directory and do exactly what it says."
TOOLS = ["--tools", "Read,Write,Bash",
         "--allowedTools", "Bash(./mm-agent:*)", "Read(./**)", "Write(./**)",
         "--disallowedTools", "WebFetch", "WebSearch", "Edit", "Glob", "Grep", "Task", "NotebookEdit",
         "--permission-mode", "dontAsk", "--strict-mcp-config", "--setting-sources", "",
         "--no-session-persistence"]


def claude_binary():
    return str(Path(shutil.which("claude")).resolve())


def build_workspace(workdir):
    work, home = Path(workdir) / "work", Path(workdir) / "home"
    (home / ".claude").mkdir(parents=True)
    work.mkdir(parents=True)
    for src, dst in [(REPO / "kernel/DSL.md", "DSL.md"), (HERE / "brief.md", "brief.md"), (HERE / "research.md", "research.md")]:
        shutil.copy(src, work / dst)
    (work / "mm-agent").write_text(f"#!{sys.executable}\n" + (HERE / "client.py").read_text())
    os.chmod(work / "mm-agent", 0o755)
    creds = home / ".claude" / ".credentials.json"
    shutil.copy(Path.home() / ".claude" / ".credentials.json", creds)
    os.chmod(creds, 0o600)
    return work, home


def sandbox_path():
    """Python and coreutils from the Nix store; which commands run is decided by the tool permissions."""
    coreutils = os.path.dirname(os.path.realpath(shutil.which("ls")))
    return ":".join([os.path.dirname(sys.executable), coreutils, "/bin", "/usr/bin"])


ETC = ("resolv.conf", "hosts", "passwd", "group", "localtime", "ssl", "static")


def sandbox_command(work, home, argv):
    """A fresh /etc holding only what the CLI needs. The host's nsswitch resolves through
    systemd-resolved's socket under /run, which is not mounted, so the sandbox gets plain DNS (the
    resolver stub is reachable on the shared network)."""
    nss = Path(home).parent / "nsswitch.conf"
    nss.write_text("passwd: files\ngroup: files\nhosts: files dns\n")
    etc = []
    for name in ETC:
        if os.path.exists(f"/etc/{name}"):
            etc += ["--ro-bind", os.path.realpath(f"/etc/{name}"), f"/etc/{name}"]
    return ["bwrap", "--unshare-all", "--share-net", "--die-with-parent", "--new-session",
            "--ro-bind", "/nix", "/nix", "--tmpfs", "/etc", *etc, "--ro-bind", str(nss), "/etc/nsswitch.conf",
            "--ro-bind", "/bin", "/bin", "--ro-bind", "/usr", "/usr", "--proc", "/proc", "--dev", "/dev", "--tmpfs", "/tmp",
            "--bind", str(home), "/home/agent", "--bind", str(work), "/work",
            "--setenv", "HOME", "/home/agent", "--setenv", "PATH", sandbox_path(),
            "--chdir", "/work", *argv]


def harness_hash():
    """Identity of the frozen harness: brief, notes, client, daemon, this file, model and flags."""
    h = hashlib.sha256()
    for f in ("brief.md", "research.md", "client.py", "daemon.py", "harness.py"):
        h.update((HERE / f).read_bytes())
    h.update(json.dumps([MODEL, MAX_TURNS, WALL_SECONDS, PROMPT, TOOLS]).encode())
    return h.hexdigest()


def run_agent(market, ledger, campaign, workdir, budget=100, prompt=PROMPT):
    workdir = Path(workdir)
    work, home = build_workspace(workdir)
    daemon = Daemon(work / "mm-agent.sock", REPO / "kernel/target/release/mm", market, ledger, campaign, "A", budget,
                    workdir / "daemon.log").serve()
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
    return {"campaign": campaign, "spent": daemon.spent, "turns": turns, "stopped": stopped, "exit": proc.returncode,
            "seconds": round(time.time() - started), "harness": harness_hash(),
            "transcript_sha256": hashlib.sha256(transcript.read_bytes()).hexdigest()}
