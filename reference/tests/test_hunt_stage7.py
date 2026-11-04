"""Counterexamples to the stage 7 bug hunt's findings (audit/reviews/2026-11-04-claude-hunt-stage7.md), each a strict
xfail until its finding is fixed. F1 runs the frozen Lean definitions (`lake env lean` on a scratch file); F2 runs
`mm check` against a registry that contradicts the bars role's contract."""

import hashlib
import json
import shutil
import subprocess
from pathlib import Path

import pytest

from gate import kernel

REPO = Path(__file__).resolve().parents[2]

HUNT = "audit/reviews/2026-11-04-claude-hunt-stage7.md"
LEAN = REPO / "reference/lean"

DUAL_ROLE = """
import Ref.Sim
import Ref.Resolve
open Ref

def barsCols : List (String × String) := [("open","o"),("high","h"),("low","l"),("close","c"),("trades","t")]
def mk (roles : List (Role × List (String × String))) (h : String) : Decl :=
  { hash := h, fields := #[], times := ["eventTime", "fetchedAt"], eventColumn := "eventTime", slotColumn := none,
    entityColumns := ["coin"], revisionColumns := ["tombstone"], rule := .field "eventTime", cadence := .held,
    deps := [], roles }
def rev (e : Int) : Revision :=
  { entity := "BTC", coin := some 0, event := e, fetchedAt := e, tombstone := false, upstream := [],
    cells := [("eventTime", .int e), ("o", .num 1), ("h", .num 1), ("l", .num 1), ("c", .num 1), ("t", .int 1),
              ("r", .num 7)] }
def st : Stored := { rows := fun _ => [rev 14400000], identity := fun _ => "" }
def num : Cell → Option Nat | .num b => some b.toNat | _ => none
def prog : Program := { nodes := #[], types := #[], params := #[], convTo := #[], weight := 0, prediction := none }
def adm : Meta where
  bindings := fun s => some ⟨s!"d{s}", s!"k{s}"⟩
  certs := []
  supersessions := []
  position := 0
  policy := ""
  verifier := ""
  holdout := []
  holdoutStart := 0
  intervals := #[((0 : Int), (4611686018427387903 : Int))]
  version := 0
def ven : Venue Nat := { takerFee := 0, minNotional := 0, szDecimals := #[0], minTierLeverage := #[1], costBps := #[] }
def report (reg : Registry) (roles : Roles) : String :=
  match resolveAll num reg st 99999999999 [0, 1] with
  | none => "invalid"
  | some os =>
    let c := Ctx.make reg roles prog adm os ven ⟨120000, 0⟩ 100000000 [0, 1]
    s!"{reg.valid && roles.valid reg && c.admissible} {c.bars.size} {c.rates.size}"
-- 0 provides bars only; 1 offers bars first, then settlement, and is the run's settlement provider.
#eval report { decls := #[mk [(.bars, barsCols)] "b", mk [(.bars, barsCols), (.settlement, [("rate", "r")])] "s"] } ⟨0, 1⟩
-- 0 offers settlement first, then bars, and is the run's bars provider; 1 provides settlement only.
#eval report { decls := #[mk [(.settlement, [("rate", "r")]), (.bars, barsCols)] "b", mk [(.settlement, [("rate", "r")])] "s"] } ⟨0, 1⟩
"""


def test_an_admitted_provider_delivers_the_role_it_was_selected_for(tmp_path):
    if not shutil.which("lake"):
        pytest.skip("no Lean toolchain")
    subprocess.run(["lake", "build", "Ref.Sim", "Ref.Resolve"], cwd=LEAN, check=True, capture_output=True)
    f = tmp_path / "DualRole.lean"
    f.write_text(DUAL_ROLE)
    out = subprocess.run(["lake", "env", "lean", str(f)], cwd=LEAN, capture_output=True, text=True, check=True)
    rows = [l.strip('"').split() for l in out.stdout.splitlines()]
    assert len(rows) == 2, out.stdout
    for admitted, bars, rates in rows:
        assert admitted == "false" or (bars, rates) == ("1", "1"), rows


def registry_with(tmp_path, edit):
    d = tmp_path / "sources"
    shutil.copytree(REPO / "sources", d)
    edit(d)
    reg = json.loads((d / "registry.json").read_text())
    for name, e in reg["declarations"].items():
        e["sha256"] = hashlib.sha256((d / name / f"{e['version']}.json").read_bytes()).hexdigest()
    (d / "registry.json").write_text(json.dumps(reg))
    return d


def test_a_bars_provider_off_the_4h_grid_is_refused(tmp_path):
    mm = kernel.build()

    def hourly(d):
        p = d / "hl-bars-4h/2.json"
        p.write_text(p.read_text().replace('"period_ms": 14400000', '"period_ms": 3600000'))

    sources = registry_with(tmp_path, hourly)
    prog = tmp_path / "p.json"
    prog.write_text(json.dumps({"dsl": 1, "name": "p", "mechanism": {"counterparty": "", "predictions": [], "capacity": ""},
                                "weight": {"input": "premium"}}))
    good = subprocess.run([str(mm), "check", str(prog), "--sources", str(REPO / "sources"), "--ledger",
                           str(tmp_path / "a.sqlite")], capture_output=True, text=True)
    assert good.returncode == 0, good.stdout + good.stderr
    bad = subprocess.run([str(mm), "check", str(prog), "--sources", str(sources), "--ledger", str(tmp_path / "b.sqlite")],
                         capture_output=True, text=True)
    assert bad.returncode == 3 and "registry" in bad.stderr, bad.stdout + bad.stderr
