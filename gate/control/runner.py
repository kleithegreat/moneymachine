"""The agent's arm (step 8): one session a market in the manifest's order, each judged on the pick in its ledger,
one line a market in `audit/control-1/results.jsonl`. `python -m gate.control.runner`, and `--end` to end early.

A line is a function of files that are kept (the run record, the transcript, the ledger, `searcher.jsonl`), so a
restart writes again any line that a kill lost."""

import argparse
import json
import os
import shutil
import sys
import tempfile
import time
from collections.abc import Callable, Mapping
from pathlib import Path
from typing import Any

from gate.agent import campaigns, harness
from gate.control import manifest as manifest_module
from gate.control import pairs
from gate.control.judge import judge as judge_programs
from gate.control.pick import pick
from gate.control.sequential import decide, outcome

AGENT = "A"
ENDED_EARLY = "ended early"
ENDING = ("claim", "futility", "undecided")
ROOM_LOG = manifest_module.OUT / "control-room.log"
WORK = manifest_module.REPO / "data" / "control-1"
NO_PICK: dict[str, Any] = {
    "pick": None,
    "reads": None,
    "pairs_won": None,
    "reference_median": None,
    "pick_median": None,
    "earns": False,
}

Line = dict[str, Any]


def model_ids(transcript: Path, notice: str | None) -> list[tuple[str, int]]:
    """The `message.model` of the transcript's assistant lines, each with its count, in order of first appearance.
    A line that does not parse is passed over, and so is an assistant line whose id is `notice`."""
    counts: dict[str, int] = {}
    if not transcript.exists():
        return []
    for raw in transcript.read_bytes().split(b"\n"):
        try:
            line = json.loads(raw)
        except ValueError:
            continue
        if not isinstance(line, dict) or line.get("type") != "assistant":
            continue
        message = line.get("message")
        model = message.get("model") if isinstance(message, dict) else None
        if isinstance(model, str) and model != notice:
            counts[model] = counts.get(model, 0) + 1
    return list(counts.items())


def read_lines(path: Path) -> list[Line]:
    if not path.exists():
        return []
    return [json.loads(raw) for raw in path.read_bytes().split(b"\n") if raw]


def append(path: Path, line: Line) -> None:
    """One write, never rewritten, no fsync."""
    descriptor = os.open(path, os.O_WRONLY | os.O_APPEND | os.O_CREAT)
    try:
        os.write(descriptor, (json.dumps(line) + "\n").encode())
    finally:
        os.close(descriptor)


def is_market_line(line: Line) -> bool:
    return "outcome" in line


def ends_study(line: Line) -> bool:
    if is_market_line(line):
        return bool(line["decision"] in ENDING)
    return bool(line.get("state") == ENDED_EARLY)


def names(ledger: Path) -> bool:
    """Whether some process's command line names the ledger."""
    needle = os.fsencode(str(ledger))
    for entry in Path("/proc").iterdir():
        if not entry.name.isdigit() or int(entry.name) == os.getpid():
            continue
        try:
            command = (entry / "cmdline").read_bytes()
        except OSError:
            continue
        if needle in command:
            return True
    return False


def wait_until_unnamed(ledger: Path) -> None:
    """The session's `claude` dies with the runner, but the daemon's kernel process may still commit an evaluation
    and names the ledger on its command line, so a kept ledger is final once no process names it."""
    while names(ledger):
        time.sleep(0.05)


def count_evaluations(ledger: Path, campaign: str, workdir: Path) -> int:
    return campaigns.evaluations_made(ledger, campaign, workdir) if ledger.exists() else 0


def judge_ledger(market_id: str, strength: float, ledger: Path) -> Line:
    """The pick of the agent's ledger, classified on the market's fresh pairs."""
    program = pick(ledger, market_id, AGENT)
    if program is None:
        return dict(NO_PICK)
    with tempfile.TemporaryDirectory(dir=os.environ.get("TMPDIR")) as scratch:
        return judge_programs([program], strength, market_id, Path(scratch), Path(scratch))[0]


def wait_for_room() -> object | None:
    waited: object | None = campaigns.wait_for_room(ROOM_LOG)
    return waited


def read_record(workdir: Path) -> Line | None:
    try:
        record: Line = json.loads((workdir / "run.json").read_text())
    except (FileNotFoundError, ValueError):
        return None
    return record


def ended(record: Line | None) -> str:
    if record is None:
        return "killed"
    return "crashed" if campaigns.crashed(record) else str(record["stopped"])


def market_line(
    market_id: str,
    index: int,
    previous: Line | None,
    own: Path,
    content: Mapping[str, Any],
    searcher: Mapping[str, Line],
    spent: Callable[[Path, str, Path], int],
    judge: Callable[[str, float, Path], Line],
) -> Line:
    ledger, workdir = own / "ledger.sqlite", own / "run"
    wait_until_unnamed(ledger)
    record = read_record(workdir)
    models = model_ids(workdir / "transcript.jsonl", content["constants"]["NOTICE"])
    is_agent = all(model in content["constants"]["SERVED"] for model, _ in models)
    evaluations = spent(ledger, market_id, workdir)
    judged = judge(market_id, content["strength"], ledger) if is_agent and evaluations > 0 else NO_PICK
    earns = bool(judged["earns"]) and judged["pick"] is not None
    searcher_earns = bool(searcher[market_id]["earns"])
    result = outcome(earns, searcher_earns)
    wins = (previous["running_wins"] if previous else 0) + (result == "win")
    losses = (previous["running_losses"] if previous else 0) + (result == "loss")
    return {
        "id": market_id,
        "run": record,
        "models": [[model, count] for model, count in models],
        "is_agent": is_agent,
        "evaluations": evaluations,
        "ended": ended(record),
        "pick": judged["pick"],
        "reads": judged["reads"],
        "pairs_won": judged["pairs_won"],
        "reference_median": judged["reference_median"],
        "pick_median": judged["pick_median"],
        "agent_earns": earns,
        "searcher_earns": searcher_earns,
        "outcome": result,
        "running_wins": wins,
        "running_losses": losses,
        "decision": decide(wins, losses, index + 1),
    }


def stop_for_a_person(line: Line, served: list[str]) -> None:
    """With the study going on, a crashed session or one that an unnamed id answered stops the runner."""
    causes = []
    if line["ended"] == "crashed":
        causes.append("crash")
    if not line["is_agent"]:
        unnamed = [model for model, _ in line["models"] if model not in served]
        causes.append(f"ids outside SERVED: {unnamed}")
    if line["decision"] == "continue" and causes:
        raise RuntimeError(f"{line['id']}: {'; '.join(causes)}")


def run(
    out: Path,
    work: Path,
    *,
    verify: Callable[[], Mapping[str, Any]] = manifest_module.verify,
    room: Callable[[], object | None] = wait_for_room,
    market: Callable[[Path, str, float], Path] = pairs.write_market,
    session: Callable[[Path, Path, str, Path], Any] = harness.run_agent,
    spent: Callable[[Path, str, Path], int] = count_evaluations,
    judge: Callable[[str, float, Path], Line] = judge_ledger,
) -> None:
    """Run the study from where its results leave off. Returns at an end of the study or when there is no room, and
    raises for a person after a line that needs one."""
    content = verify()
    results = out / "results.jsonl"
    searcher = {line["id"]: line for line in read_lines(out / "searcher.jsonl")}
    while True:
        lines = read_lines(results)
        if lines and ends_study(lines[-1]):
            return
        judged = [line for line in lines if is_market_line(line)]
        if len(judged) == len(content["markets"]):
            return
        market_id = content["markets"][len(judged)]
        own = work / "agent" / market_id
        if not (own / "launched").exists():
            if room() is None:
                return
            shutil.rmtree(own, ignore_errors=True)
            own.mkdir(parents=True)
            written = market(own / "market", market_id, content["strength"])
            (own / "launched").write_text("")
            session(written, own / "ledger.sqlite", market_id, own / "run")
        line = market_line(market_id, len(judged), judged[-1] if judged else None, own, content, searcher, spent, judge)
        append(results, line)
        stop_for_a_person(line, content["constants"]["SERVED"])


def end(out: Path, *, verify: Callable[[], Mapping[str, Any]] = manifest_module.verify) -> None:
    """`--end`: after it the runner starts no session."""
    verify()
    results = out / "results.jsonl"
    judged = [line for line in read_lines(results) if is_market_line(line)]
    append(results, {"state": ENDED_EARLY, "markets": len(judged)})


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--end", action="store_true")
    if parser.parse_args().end:
        end(manifest_module.OUT)
    else:
        run(manifest_module.OUT, WORK)
    return 0


if __name__ == "__main__":
    sys.exit(main())
