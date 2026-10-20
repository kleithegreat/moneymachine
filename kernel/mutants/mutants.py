"""C1.1 and C5.5 mutants: each one disables an invariant's check and makes the kernel or the data layer
commit the prohibited behavior; its named test must then fail, while the unpatched tree passes it.

Run inside nix develop: `python -m cli mutants`. Each mutant is a list of exact,
unique (file, old, new) replacements applied to a fresh copy of the working tree.
"""

import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
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
        (SIM, "        if (e1 - e2).abs() > ACCOUNTING_TOLERANCE {", "        if false {")]),
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
    "I1 events delivered early": ("cd kernel && cargo test -q --release --test events counts_are_fresh_only_and_respect_known_at", [
        (MACHINE, "        if e.known > tick {", "        if e.known > tick + HOUR {")]),
    "C5 derivation without the availability lag": ("pytest -q ingest/tests/test_events.py", [
        (EVENTS, "RULE_MS = 600_000", "RULE_MS = 0")]),
    "C5 derivation counts future items": ("pytest -q ingest/tests/test_events.py", [
        (EVENTS, 'counts = np.searchsorted(k, hours, side="right") - np.searchsorted(k, hours - HOUR, side="right")',
         'counts = np.searchsorted(k, hours + HOUR, side="right") - np.searchsorted(k, hours, side="right")')]),
    "C5 as_of returns the latest content": ("pytest -q ingest/tests/test_store.py", [
        (STORE, '(pl.col("fetchedAt") <= version) & (pl.col("knownAt") <= t)', '(pl.col("fetchedAt") <= version)')]),
    "C5 tombstones dropped": ("pytest -q ingest/tests/test_store.py", [
        (STORE, "complete & live(latest)", "complete & pl.lit(False)")]),
}


def run(cmd, cwd, log):
    with open(log, "w") as fh:
        return subprocess.run(["bash", "-c", cmd], cwd=cwd, stdout=fh, stderr=subprocess.STDOUT).returncode


def main():
    os.environ["CARGO_TARGET_DIR"] = str(REPO / "kernel" / "target-mutants")
    logs = REPO / "data" / "mutants"
    logs.mkdir(parents=True, exist_ok=True)
    ignore = shutil.ignore_patterns(".git", "data", "target", "target-mutants", "__pycache__", ".hypothesis")
    missed = 0
    for name, (test, edits) in MUTANTS.items():
        slug = "-".join(name.split())
        with tempfile.TemporaryDirectory() as wt:
            shutil.copytree(REPO, wt, ignore=ignore, dirs_exist_ok=True, copy_function=shutil.copy)
            clean = run(test, wt, logs / f"{slug}.clean.log")
            for f, old, new in edits:
                path = Path(wt) / f
                text = path.read_text()
                if text.count(old) != 1:
                    sys.exit(f"{name}: edit does not match exactly once in {f}: {old!r}")
                path.write_text(text.replace(old, new))
            mutated = run(test, wt, logs / f"{slug}.mutated.log")
        ok = clean == 0 and mutated != 0
        missed += not ok
        print(("caught " if ok else "MISSED ") + name + ("" if ok else f" (clean={clean}, mutated={mutated})"), flush=True)
    sys.exit(1 if missed else 0)

