import Engine.Lang.SyntaxProofs
import Engine.Lang.Eval

/-!
# The witness of L2's exact half (B3, L2 units)

A checked program whose probe is the crossing `exact` of a declared float source, and what its evaluator reads.
-/

namespace Engine.Lang

def step5ExactText : String :=
  r#"{"version":2,"tick":1,"decide_every":1,"leverage":1,"sources":[{"name":"vol","unit":"1"}],"params":[],"let":[],"slots":[],"probes":[{"name":"v","is":{"op":"exact","args":[{"input":"vol"}]}}]}"#

def step5ExactProgram : Program :=
  { tick := 1, decideEvery := 1, leverage := .all 1, sources := [("vol", Dim.one)],
    nodes := #[.source "vol" Dim.one, .op .toExact [0]], types := #[.num Dim.one, .exact Dim.one], probeNodes := #[1] }

set_option maxHeartbeats 4000000 in
theorem parse_step5Exact_is :
    (match parse step5ExactText with | .ok p => decide (p = step5ExactProgram) | .error _ => false) = true := by
  decide +kernel

theorem parse_step5Exact_eq : parse step5ExactText = .ok step5ExactProgram := by
  have := parse_step5Exact_is
  cases hp : parse step5ExactText with
  | error _ => rw [hp] at this; simp at this
  | ok p => rw [hp] at this; simp at this; rw [this]

theorem step5Exact_reads {α : Type} (N : NumOps α) (x : α) (r : Rat) (hx : N.finite x = true)
    (hr : N.toExact x = some r) :
    (Mach.run N step5ExactProgram 1
      [⟨fun _ => true, fun _ s => if s = "vol" then some x else none, 0, fun _ _ _ => none⟩]).exacts[1]![0]! = some r := by
  simp [Mach.run, Mach.step, build, nodeStep, nodeFull, exactRow, pointExact, finalize, nodeCore, pointVal, evalNode,
    evalExactNode, evalExactOp, step5ExactProgram, Mach.init, Node.args, argRow, NumOps.keep, hx, hr]

end Engine.Lang
