"""One baseline-searcher campaign on a simulated market (market -> searcher -> gate -> holdout), in a directory whose
existence marks it started; a crash, or a start never recorded, counts as a promotion."""

import contextlib
import fcntl
import json
import lzma
import os
import shutil
import time
import traceback
from collections.abc import Iterable, Iterator
from contextlib import contextmanager
from multiprocessing.reduction import DupFd
from pathlib import Path
from typing import IO, Any

from gate import gate, markets, search


def run_campaign(spec: dict[str, Any], out: str | Path) -> dict[str, Any]:
    """spec: {"id", "model", "params", "searcher", "planted", "beta", "cost_cells", "days", "holdout_days"}."""
    t0 = time.time()
    work = Path(out) / spec["id"]
    work.mkdir(parents=True)
    root = work / "m"
    try:
        markets.write(
            root,
            markets.generate(
                spec["model"],
                spec["params"],
                spec["id"],
                spec["days"],
                spec.get("planted", ()),
                spec.get("beta", 0.0),
                spec.get("events"),
            ),
            spec["holdout_days"],
            spec["cost_cells"],
        )
        ledger = root / "ledger.sqlite"
        spent = search.run(spec["searcher"], root, ledger, spec["id"], markets.seed(spec["id"]))
        finalists, report = gate.search_decision(ledger, spec["id"])
        gate.freeze(ledger, spec["id"], finalists, "finalist")
        programs = gate.programs(ledger, spec["id"], finalists)
        promoted, holdout = gate.holdout_decision(root, ledger, spec["id"], programs)
        top = gate.programs(ledger, spec["id"], report.get("top5", []))
        result = {
            "spent": spent,
            "search": report,
            "holdout": holdout,
            "bankrupt": gate.bankrupt(ledger),
            "promoted": [{"hash": h, "program": programs[h]} for h in promoted],
            "top5": [{"hash": h, "program": top[h]} for h in report.get("top5", [])],
        }
    except Exception:
        result = {"crash": traceback.format_exc()}
    for kept in ("ledger.sqlite", "holdout/spent.jsonl"):
        if (root / kept).exists():
            (work / f"{Path(kept).name}.xz").write_bytes(lzma.compress((root / kept).read_bytes()))
    shutil.rmtree(root, ignore_errors=True)
    described = {k: v for k, v in spec.items() if k not in ("params", "events")}
    return {**described, **result, "seconds": round(time.time() - t0, 1)}


def records(path: str | Path) -> list[dict[str, Any]]:
    """Series records; an unparseable line is a retained torn append, not a result."""
    if not Path(path).exists():
        return []
    rows: list[dict[str, Any]] = []
    with open(path, "rb") as source:
        for line in source:
            with contextlib.suppress(json.JSONDecodeError, UnicodeDecodeError):
                rows.append(json.loads(line))
    return rows


def recorded(path: str | Path) -> set[str]:
    return {r["id"] for r in records(path)}


class KeepLock:
    """Pool initializer retaining the parent's flock even if the parent is killed."""

    def __init__(self, file: IO[str]) -> None:
        self.file = file

    def __getstate__(self) -> Any:
        return DupFd(self.file.fileno())

    def __setstate__(self, fd: Any) -> None:
        self.file = os.fdopen(fd.detach(), "a")

    def __call__(self) -> None:
        pass


@contextmanager
def exclusive(log: str | Path) -> Iterator[IO[str]]:
    """`log` opened for appending under an exclusive lock held for the run's lifetime (released when its last process,
    pool workers included, exits), so a second run fails at once."""
    with open(log, "a") as fh:
        try:
            fcntl.flock(fh, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise RuntimeError(f"another run of {log} is alive") from None
        yield fh


@contextmanager
def resume(ids: Iterable[str], log: str | Path, out: str | Path) -> Iterator[tuple[list[str], IO[str]]]:
    """The ids still to run, for the duration of the run. One whose directory under `out` exists with no result in
    `log` was started and interrupted: it is recorded as a crash, which counts as a promotion, and never rerun. That
    holds only if no other run of `log` is alive, which `exclusive` ensures. Yields (ids, locked log); process pools
    retain the lock with KeepLock."""
    with exclusive(log) as fh:
        with open(log, "rb") as source:
            source.seek(0, 2)
            if source.tell():
                source.seek(-1, 2)
                if source.read(1) != b"\n":
                    fh.write("\n")
                    fh.flush()
        done = recorded(log)
        todo: list[str] = []
        for i in ids:
            if i in done:
                continue
            if (Path(out) / i).exists():
                crash = {"id": i, "crash": "interrupted before its result was recorded", "counts_as_promotion": True}
                fh.write(json.dumps(crash) + "\n")
            else:
                todo.append(i)
        fh.flush()
        yield todo, fh


def promoted_anything(result: dict[str, Any]) -> bool:
    return bool(result.get("crash")) or bool(result.get("promoted"))
