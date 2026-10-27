"""C1.1 and C5.5 mutants: each one disables an invariant's check and makes the kernel or the data layer
commit the prohibited behavior; its named test must then fail, while the unpatched tree passes it.

Run inside nix develop: `python -m cli mutants`. Each mutant is a list of exact,
unique (file, old, new) replacements applied to a fresh copy of the working tree.
"""

import os
import queue
import shutil
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
LOGS = REPO / "data" / "mutants"
FX = "cd kernel && cargo test -q --release --test fixtures"
SIM, MACHINE, MAIN, MARKET, DSL = (f"kernel/mm/src/{f}.rs" for f in ["sim", "machine", "main", "market", "dsl"])
EVENTS = "ingest/events.py"
STORE = "ingest/store.py"
I2 = "    if !(f.inputs_known <= f.decided && f.decided <= f.submitted && f.submitted <= f.filled) {"

MUTANTS = {
    "I1 future bars delivered": (f"{FX} decision_sees_only_closed_bars", [
        (MACHINE, "        if b.known > tick {", "        if false {"),
        (SIM, "market.bars[b_order[bi]].known <= tick {", "market.bars[b_order[bi]].known <= tick + BAR {"),
        (SIM, I2, "    if false {")]),
    "I2 submission before decision": (f"{FX} timing_order_holds_for_every_fill", [
        (SIM, "                        submitted: o.decided,\n", "                        submitted: o.decided - HOUR,\n"),
        (SIM, I2, "    if false {"),
        (SIM, "            first == Some(bar.open_time) && bar.open_time", "            bar.open_time")]),
    "I3 fill at the close": (f"{FX} delayed_fill_fees_funding_and_rebalance", [
        (SIM, "let price = fill_price(venue, o.coin, o.qty, bar.open);", "let price = fill_price(venue, o.coin, o.qty, bar.close);"),
        (SIM, "                        reference: bar.open,", "                        reference: bar.close,"),
        (SIM, "bar.trades >= 1 && f.reference == bar.open\n", "bar.trades >= 1\n")]),
    "I4 add ignores units": ("cd kernel && cargo test -q --release --test adversarial type_checker_rejects_with_expected_code", [
        (DSL, "            Op::Add | Op::Sub | Op::Min | Op::Max => Ty::Num(same(num(0)?, num(1)?)?),",
         "            Op::Add | Op::Sub | Op::Min | Op::Max => {\n                num(1)?;\n                Ty::Num(num(0)?)\n            }")]),
    "I5 funding off the books": (f"{FX} equity_reconciles_every_step", [
        (SIM, "        self.funding -= paid;\n", ""),
        (SIM, "        if !accounting_ok(e1, e2, peak_equity) {", "        if false {")]),
    "I6 print before commit": ("pytest -q kernel/tests/cli/test_cli.py -k unwritable", [
        (MAIN, "    let id = ledger\n        .disclose_result(", "    println!(\"{content}\");\n    let id = ledger\n        .disclose_result(")]),
    "I7 wall clock in result": ("pytest -q kernel/tests/cli/test_cli.py -k fresh_processes", [
        (MAIN, "    json!({\n        \"steps\": r.len(),",
         "    json!({\n        \"at\": std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_nanos() as u64,\n        \"steps\": r.len(),")]),
    "I8 holdout rows admitted": ("pytest -q kernel/tests/cli/test_cli.py -k copied_holdout", [
        (MARKET, "            if event >= h {", "            if false {")]),
    "I9 no leverage or notional limit": (f"{FX} leverage_scale_and_notional_cap", [
        (SIM, "        let scaled = |w: f64| if relative * largest > MAX_GROSS { w / largest * (MAX_GROSS / relative) } else { w };",
         "        let scaled = |w: f64| w;"),
        (SIM, "        if !(gross <= MAX_GROSS * (1.0 + 1e-12)) {", "        if false {"),
        (SIM, "            if qty.abs() * price > MAX_ORDER_NOTIONAL {", "            if false {"),
        (SIM, "    if f.why == Why::Fill && f.qty.abs() * f.decision_price > MAX_ORDER_NOTIONAL * (1.0 + 1e-12) {", "    if false {")]),
    "I10 losses beyond equity": (f"{FX} bankruptcy_caps_the_loss_at_equity", [
        (SIM, "        if !(book.equity(&marks) > 0.0) {", "        if false {"),
        (SIM, "        if !(r >= -LOSS_BOUND) {", "        if false {")]),
    "I1 events delivered early": ("cd kernel && cargo test -q --release --test events counts_are_fresh_only_and_respect_known_at", [
        (MACHINE, "        if e.known > tick {", "        if e.known > tick + HOUR {")]),
    "C5 derivation without the availability margin": ("pytest -q ingest/tests/test_events.py", [
        (EVENTS, '"key": "forum", "margin": 60_000}', '"key": "forum", "margin": 0}')]),
    "C5 knownAt from the claimed time": ("pytest -q ingest/tests/test_events.py", [
        (EVENTS, '[w + margin for (fk, _), (c, w) in first.items()', '[c + margin for (fk, _), (c, w) in first.items()')]),
    "C5 derivation counts future items": ("pytest -q ingest/tests/test_events.py", [
        (EVENTS, 'counts = np.searchsorted(k, hours + DELTA, side="right") - np.searchsorted(k, hours + DELTA - HOUR, side="right")',
         'counts = np.searchsorted(k, hours + DELTA + HOUR, side="right") - np.searchsorted(k, hours + DELTA, side="right")')]),
    "C5 coverage reads a later poll": ("pytest -q ingest/tests/test_derived.py -k later", [
        (EVENTS, 'np.searchsorted(p, b, side="right") - 1', 'np.searchsorted(p, b + GAP, side="right") - 1')]),
    "C5 as_of returns the latest content": ("pytest -q ingest/tests/test_store.py", [
        (STORE, '.filter(pl.col("knownAt") <= t))', ')')]),
    "C5 tombstones dropped": ("pytest -q ingest/tests/test_store.py", [
        (STORE, "complete & live(latest)", "complete & pl.lit(False)")]),
}


# Peak memory of one slot (a cold cargo build of the copied tree, then the mutant's test): 1,725 MiB measured
# 2026-10-27, with margin.
SLOT_BYTES = 2_200_000_000


def run(cmd, cwd, log, env):
    with open(log, "w") as fh:
        return subprocess.run(["bash", "-c", cmd], cwd=cwd, stdout=fh, stderr=subprocess.STDOUT, env=env).returncode


def check(name, slot):
    """Whether the mutant's named test passes on a clean copy of the tree and fails on the mutated one."""
    test, edits = MUTANTS[name]
    slug = "-".join(name.split())
    env = os.environ | {"CARGO_TARGET_DIR": str(REPO / "kernel" / f"target-mutants-{slot}")}
    ignore = shutil.ignore_patterns(".git", "data", "target*", "__pycache__", ".hypothesis")
    with tempfile.TemporaryDirectory() as wt:
        shutil.copytree(REPO, wt, ignore=ignore, dirs_exist_ok=True, copy_function=shutil.copy)
        clean = run(test, wt, LOGS / f"{slug}.clean.log", env)
        for f, old, new in edits:
            path = Path(wt) / f
            text = path.read_text()
            if text.count(old) != 1:
                return f"BROKEN {name}: edit does not match exactly once in {f}: {old!r}"
            path.write_text(text.replace(old, new))
        mutated = run(test, wt, LOGS / f"{slug}.mutated.log", env)
    return ("caught " if clean == 0 and mutated != 0 else "MISSED ") + name + (
        "" if clean == 0 and mutated != 0 else f" (clean={clean}, mutated={mutated})")


def main(n=None):
    """Every mutant, `n` at a time (by default as many as memory allows); each slot keeps its own cargo target, reused
    across its mutants."""
    from gate import compute

    n = n or compute.workers(SLOT_BYTES)
    LOGS.mkdir(parents=True, exist_ok=True)
    slots = queue.Queue()
    for i in range(n):
        slots.put(i)

    def one(name):
        slot = slots.get()
        try:
            return check(name, slot)
        finally:
            slots.put(slot)

    with ThreadPoolExecutor(n) as pool:
        results = list(pool.map(one, MUTANTS))
    for r in results:
        print(r, flush=True)
    sys.exit(0 if all(r.startswith("caught ") for r in results) else 1)
