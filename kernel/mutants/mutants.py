"""C1.1 mutants: each one disables an invariant's check and makes the kernel commit the
prohibited behavior; its named test must then fail, while the unpatched tree passes it.

Run inside nix develop: `python kernel/mutants/mutants.py`. Each mutant is a list of exact,
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
        (SIM, "        let scale = if gross > MAX_GROSS { MAX_GROSS / gross } else { 1.0 };", "        let scale = 1.0;"),
        (SIM, "        if gross * scale > MAX_GROSS * (1.0 + 1e-12) {", "        if false {"),
        (SIM, "            if qty.abs() * price > MAX_ORDER_NOTIONAL {", "            if false {"),
        (SIM, "    if f.why == Why::Fill && f.qty.abs() * f.decision_price > MAX_ORDER_NOTIONAL * (1.0 + 1e-12) {", "    if false {")]),
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
        slug = name.split()[0]
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


if __name__ == "__main__":
    main()
