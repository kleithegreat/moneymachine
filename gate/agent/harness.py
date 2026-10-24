"""The research agent (stage 3's arm A, stage 4's swarm) in the shared sandbox (`sandbox/`), against an
mm-agent daemon. Its workspace holds DSL.md, brief.md, research.md (and swarm.md in a swarm) and `./mm-agent`."""

import json
import subprocess
from pathlib import Path

from gate.agent.daemon import SPEC, Daemon, Swarm
from gate.kernel import command
from sandbox import session

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
MODEL = "claude-opus-5-5"
MAX_TURNS = 200
WALL_SECONDS = 2 * 3600
SWARM_PROMPT = "Read brief.md and swarm.md in this directory and do exactly what they say."
CLIENT = "mm-agent"


def build_workspace(workdir, swarm=False):
    files = [REPO / "kernel/DSL.md", HERE / "brief.md", HERE / "research.md"] + ([HERE / "swarm.md"] if swarm else [])
    session.workspace(workdir, {f.name: f.read_text() for f in files}, CLIENT, SPEC)


def harness_hash():
    """Identity of the frozen harness: brief, notes, daemon, this file, the shared sandbox, model and limits."""
    return session.identity([HERE / f for f in ("brief.md", "research.md", "swarm.md", "daemon.py", "harness.py")],
                            [MODEL, MAX_TURNS, WALL_SECONDS, session.PROMPT, SWARM_PROMPT, session.tools(CLIENT)])


def run_agent(market, ledger, campaign, workdir, budget=100, prompt=session.PROMPT, agent="A", swarm=None):
    workdir = Path(workdir)
    build_workspace(workdir, swarm is not None)
    daemon = Daemon(session.socket_path(workdir, CLIENT), market, ledger, campaign, agent, budget, workdir / "daemon.log",
                    swarm).serve()
    s = session.run(workdir, CLIENT, MODEL, MAX_TURNS, WALL_SECONDS, prompt)
    daemon.close()
    run = {"campaign": campaign, "agent": agent, "spent": daemon.spent, "history_calls": daemon.history_calls, **s,
           "harness": harness_hash()}
    (workdir / "run.json").write_text(json.dumps(run))
    subprocess.run(command("disclose", workdir / "run.json", campaign, agent, ledger, None, "--kind", "run"),
                   check=True, capture_output=True)
    return run


def run_swarm(market, ledger, campaign, workdir, agents=4, budget=100):
    """K agents in parallel, each in its own sandbox and socket, sharing one history (stage 4)."""
    from concurrent.futures import ThreadPoolExecutor

    swarm = Swarm()
    with ThreadPoolExecutor(agents) as pool:
        runs = list(pool.map(lambda i: run_agent(market, ledger, campaign, Path(workdir) / f"A{i + 1}", budget,
                                                 SWARM_PROMPT, f"A{i + 1}", swarm), range(agents)))
    return {"runs": runs, "evaluations": len(swarm.snapshot())}
