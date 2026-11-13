"""The report (step 9): `audit/control-1/report.md` from the manifest, `searcher.jsonl` and `results.jsonl`. It
recounts lines and judges nothing, and reads no ledger and no kernel. `python -m gate.control.report`."""

import json
import sys
from collections.abc import Callable, Mapping, Sequence
from pathlib import Path
from typing import Any

from scipy import stats

from gate.control import manifest

Line = dict[str, Any]
Summary = dict[str, Any]

NAMES = {
    "claim": "The agent's sessions end on a program that earns from the plant more often than G100's 100 evaluations do",
    "futility": "Not shown",
    "undecided": "Inconclusive",
    "ended early": "Inconclusive at the markets judged",
}
SETS = "The sets are not arms: which ids answer a session depends on how long it runs"
NO_DESIGNED_END = ("crashed", "killed")


def read_lines(path: Path) -> list[Line]:
    return [json.loads(raw) for raw in path.read_bytes().split(b"\n") if raw]


def is_market_line(line: Line) -> bool:
    return "outcome" in line


def state_of(line: Line) -> str | None:
    """The end that a line is, or None."""
    if is_market_line(line):
        return str(line["decision"]) if line["decision"] != "continue" else None
    return str(line["state"]) if line.get("state") == "ended early" else None


def interval(earned: int, n: int) -> tuple[float, float]:
    """The exact (Clopper-Pearson) 95% interval of a rate."""
    low = 0.0 if earned == 0 else float(stats.beta.ppf(0.025, earned, n - earned + 1))
    high = 1.0 if earned == n else float(stats.beta.ppf(0.975, earned + 1, n - earned))
    return low, high


def rate(earned: int, n: int) -> Summary:
    if n == 0:
        return {"earned": earned, "rate": None, "interval": None}
    return {"earned": earned, "rate": earned / n, "interval": interval(earned, n)}


def model_set(line: Line) -> str:
    return ", ".join(sorted(model for model, _ in line["models"]))


def g100_at(line: Line, searcher: Mapping[str, Line]) -> Summary:
    """G100's last earlier best at or before the agent's count of evaluations on the market."""
    k = line["evaluations"]
    earlier = [best for best in searcher[line["id"]]["earlier"] if best["evaluation"] <= k]
    best = earlier[-1] if earlier else {"pick": None, "earns": False}
    return {"id": line["id"], "k": k, "pick": best["pick"], "earns": best["earns"]}


def summary(out: Path, *, verify: Callable[[], Mapping[str, Any]] = manifest.verify) -> Summary:
    verify()
    lines = read_lines(out / "results.jsonl")
    searcher = {line["id"]: line for line in read_lines(out / "searcher.jsonl")}
    end = next((i for i, line in enumerate(lines) if state_of(line) is not None), None)
    counted = [line for line in (lines if end is None else lines[: end + 1]) if is_market_line(line)]
    beyond = [] if end is None else [line["id"] for line in lines[end + 1 :] if is_market_line(line)]
    state = "running" if end is None else state_of(lines[end])
    n = len(counted)
    sets: dict[str, list[Line]] = {}
    for line in counted:
        sets.setdefault(model_set(line), []).append(line)
    by_models = {
        key: {
            "sessions": len(group),
            "share": len(group) / n,
            **rate(sum(bool(line["agent_earns"]) for line in group), len(group)),
        }
        for key, group in sets.items()
    }
    outcomes = [line["outcome"] for line in counted]
    return {
        "state": state,
        "ended": end is not None,
        "name": NAMES.get(state) if state else None,
        "markets": n,
        "wins": outcomes.count("win"),
        "losses": outcomes.count("loss"),
        "concordant": outcomes.count("concordant"),
        "agent": rate(sum(bool(line["agent_earns"]) for line in counted), n),
        "searcher": rate(sum(bool(line["searcher_earns"]) for line in counted), n),
        "by_models": by_models,
        "g100_at_k": [g100_at(line, searcher) for line in counted],
        "cut_off": [line["id"] for line in counted if line["ended"] in NO_DESIGNED_END],
        "unnamed": [line["id"] for line in counted if not line["is_agent"]],
        "beyond": beyond,
        "lines": counted,
    }


def three(value: float) -> str:
    return f"{value:.3f}"


def arm_row(name: str, arm: Summary, n: int) -> str:
    if arm["rate"] is None:
        return f"| {name} | 0/0 | | |"
    low, high = arm["interval"]
    return f"| {name} | {arm['earned']}/{n} | {three(arm['rate'])} | {three(low)} to {three(high)} |"


def table(header: Sequence[str], rows: Sequence[Sequence[Any]]) -> list[str]:
    head = ["| " + " | ".join(header) + " |", "|" + "---|" * len(header)]
    return [*head, *("| " + " | ".join(str(cell) for cell in row) + " |" for row in rows)]


def text_of(found: Summary) -> str:
    n = found["markets"]
    out = ["# Study 1, the positive control of the search", ""]
    if found["ended"]:
        out += [f"**Result: {found['name']}.**", ""]
    else:
        out += ["The study has not ended: this is what the lines hold so far.", ""]
    if found["state"] == "claim":
        answered = sorted({model for line in found["lines"] for model, _ in line["models"]})
        out += [f"Models that answered a counted session: {', '.join(answered)}.", ""]
    out += [
        f"Markets counted: {n}. Agent wins {found['wins']}, losses {found['losses']}, concordant {found['concordant']}."
    ]
    out += ["Each rate's interval is the exact (Clopper-Pearson) 95% interval. Power is in architecture 5.3.", ""]
    out += table(["Arm", "Earned", "Rate", "95% interval"], [])
    out += [arm_row("Agent", found["agent"], n), arm_row("G100", found["searcher"], n), ""]
    if n:
        rows = [
            (
                key,
                group["sessions"],
                three(group["share"]),
                f"{group['earned']}/{group['sessions']}",
                three(group["rate"]),
                f"{three(group['interval'][0])} to {three(group['interval'][1])}",
            )
            for key, group in sorted(found["by_models"].items())
        ]
        out += ["## Sessions by the set of ids that answered", "", SETS, ""]
        out += table(["Ids", "Sessions", "Share", "Earned", "Rate", "95% interval"], rows) + [""]
    by_id = {row["id"]: row for row in found["g100_at_k"]}
    market_rows = [
        (
            line["id"],
            line["evaluations"],
            line["ended"],
            "; ".join(f"{model} x{count}" for model, count in line["models"]),
            line["pairs_won"],
            line["pick_median"],
            line["reference_median"],
            ", ".join(line["reads"] or []),
            line["agent_earns"],
            line["searcher_earns"],
            f"{by_id[line['id']]['pick']} ({by_id[line['id']]['earns']})",
        )
        for line in found["lines"]
    ]
    header = ["Market", "Evaluations", "Ended", "Model ids", "Pairs won", "Pick median", "Reference median"]
    out += ["## Markets", ""]
    out += table([*header, "Reads", "Agent earns", "G100 earns", "G100 at the agent's count"], market_rows) + [""]
    if found["cut_off"]:
        out += ["Sessions with no designed end: " + ", ".join(found["cut_off"]), ""]
    if found["unnamed"]:
        out += ["Sessions that an unnamed id answered: " + ", ".join(found["unnamed"]), ""]
    if found["beyond"]:
        out += ["## Sessions beyond the stop, in no rate", "", ", ".join(found["beyond"]), ""]
    return "\n".join(out)


def write(out: Path, *, verify: Callable[[], Mapping[str, Any]] = manifest.verify) -> None:
    found = summary(out, verify=verify)
    (out / "report.md").write_text(text_of(found))


def main() -> int:
    write(manifest.OUT)
    return 0


if __name__ == "__main__":
    sys.exit(main())
