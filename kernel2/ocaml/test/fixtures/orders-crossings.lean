/- Step 5 test 1's TWO float evaluators, not two changed markets.
Builder supplies through `import Engine.Machine`:
   Engine.Lang.bitsOps : Engine.Lang.NumOps UInt64 (existing, gains crossings).
   Engine.Machine.orderRun : {α : Type} → Engine.Lang.NumOps α → Engine.Machine.State →
     List Engine.Machine.Move → Option Engine.Orders.Run
  Engine.Machine.start : String → String → Except String State (existing).
   NumOps.add : NumOps UInt64 → UInt64 → UInt64 → UInt64 (existing accessor).
  Run.placed : List Placement; Placement.order : Order (DecidableEq);
  Run.whenValues : List (Int × Nat × Nat × Option Bool);
    Run.exactValues : List (Int × Nat × Nat × Option Rat).
     The values are the rationals returned by each evaluator's exact(·),
     not the floats its crossings read (including undefined values).
     Move.event : Event → Move; Move.offer : Nat → Nat → List (Nat × Rat) → Ledger.Role → Move.
   All other records and transition contracts are in fixtures/orders.lean and
   Laws.lean. No export, C stub, OCaml binding or command is needed.
Run is the running evaluator/slot/machine instrumentation specified above X1
in Laws.lean, not an alternate engine. A17 program fields: version,tick,
decide_every,leverage,sources,params,let,slots,probes; slots have name,side,
when,price,size,tif,reduce_only. A18 header fields below are all required.
This file deliberately does NOT import Laws or depend on its sorry proofs.
-/
import Engine.Machine

open Engine.Lang Engine.Machine Engine.Orders

namespace Step5Crossings

def header : String :=
  r#"{"horizon":{"start":1775174400000,"end":1775174400001},"venue":{"fill":"optimistic","lambda":0,"delta":0,"stale":60000,"cap":"10000","minimum":"0"},"cash":"10000","coins":[{"name":"A","sz_decimals":2,"figures":5,"decimals":4,"tiers":[{"from":"0","max_leverage":10}]}],"fees":[{"from":1775174400000,"tier":"base","maker":"0","taker":"0"}],"sources":{"listings":{"lag":0},"funding":{"encoding":"string","lag":0,"late":1000},"quotes":{"encoding":"string"},"trades":{"encoding":"string"},"observations":[]},"aliases":{"coins":{},"sources":{}}}"#

def yes : String :=
  r#"{"op":"gt","args":[{"exact":"1","unit":"1"},{"exact":"0","unit":"1"}]}"#

def signal : String :=
  r#"{"op":"add","args":[{"const":1,"unit":"1"},{"const":1,"unit":"1"}]}"#

def program (condition price : String) : String :=
  r#"{"version":2,"tick":1,"decide_every":1,"leverage":1,"sources":[],"params":[],"let":[],"slots":[{"name":"entry","side":"buy","when":"# ++
    condition ++ r#", "price":"# ++ price ++
    r#", "size":{"exact":"1","unit":"coin"},"tif":"gtc","reduce_only":false}],"probes":[{"name":"signal","is":"# ++
    signal ++ "}]}"

def quote : Event :=
  {coin := 0, time := 1775174400000, known := 1775174400000,
   payload := .quote [{price := .placed 99 0, size := .placed 10 0}]
                     [{price := .placed 101 0, size := .placed 10 0}]}

def altered : NumOps UInt64 :=
  {bitsOps with add := fun a b => (Float.ofBits (bitsOps.add a b) + 1.0).toBits}

def runs (p : String) : IO (Run × Run) := do
  let initial ← match start p header with
    | .ok initial => pure initial
    | .error code => throw (IO.userError s!"crossing fixture start: {code}")
  match orderRun bitsOps initial [.event quote], orderRun altered initial [.event quote] with
  | some a, some b => pure (a, b)
  | _, _ => throw (IO.userError "crossing fixture rejected an admitted market")

def require (name : String) (ok : Bool) : IO Unit := do
  unless ok do throw (IO.userError name)
  IO.println s!"{name}: passed"

#eval show IO Unit from do
  let fixed := r#"{"op":"mul","args":[{"exact":"100","unit":"usd/coin"},{"op":"exact","args":[{"const":1,"unit":"1"}]}]}"#
  let condition := r#"{"op":"gt","args":["# ++ signal ++ r#",{"const":2.5,"unit":"1"}]}"#
  let (a, b) ← runs (program condition fixed)
  require "step5_1_evaluators_disagree_when"
    (decide (a.whenValues ≠ b.whenValues) && a.placed.isEmpty && !b.placed.isEmpty)
  let (a, b) ← runs (program yes fixed)
  require "step5_1_evaluators_agree_at_crossings"
      (decide (a.whenValues = b.whenValues) && decide (a.exactValues = b.exactValues) &&
       !a.exactValues.isEmpty && decide (a.wishes = b.wishes) &&
      !a.placed.isEmpty && decide (a.placed.map (·.order) = b.placed.map (·.order)))
  let crossed := r#"{"op":"mul","args":[{"exact":"100","unit":"usd/coin"},{"op":"exact","args":["# ++ signal ++ "]}]}"
  let (a, b) ← runs (program yes crossed)
  require "step5_1_evaluators_disagree_exact_value"
    (decide (a.whenValues = b.whenValues) && decide (a.exactValues ≠ b.exactValues) &&
     !a.placed.isEmpty && !b.placed.isEmpty &&
     decide (a.placed.map (·.order) ≠ b.placed.map (·.order)))

end Step5Crossings
