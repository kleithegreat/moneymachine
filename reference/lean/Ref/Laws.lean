import Ref.Sim

/-!
The five laws of stage 6 (PROGRESS.md, Stage 6), stated over the model of reference/SEMANTICS.md.
Each is quantified over every number structure `N` (the binary64 instance is `floatOps`); L3's
obligations are explicit hypotheses. These statements are frozen with SEMANTICS.md before any proof.
-/

namespace Ref

variable {α : Type} [Inhabited α]

/-- Programs the frozen checker accepts, from parsed JSON. -/
def WellTyped (p : Program) : Prop := ∃ v st, (program v).run {} = .ok (p, st)

/-! ## L1 non-interference -/

/-- The ordered delivery prefix by time t (SEMANTICS.md §3): every funding row, bar and bound
event row with knownAt ≤ t, in delivery order, with multiplicity. -/
def Ctx.deliveryPrefix (c : Ctx α) (t : Int) : List (FundingRow α) × List (BarRow α) × List (EventRow α) :=
  ((c.fOrder.toList.map (c.m.funding[·]!)).filter (·.known ≤ t),
   (c.bOrder.toList.map (c.m.bars[·]!)).filter (·.known ≤ t),
   (c.eOrder.toList.map (c.m.events[·]!)).filter (·.known ≤ t))

/-- What execution reads by event time t: settled rates with eventTime ≤ t; every field of bars
closed by t; the open and trade count of bars opened by t; and the listing intervals. -/
def Ctx.execView (c : Ctx α) (t : Int) :
    List (Nat × Int × α) × List (BarRow α) × List (Nat × Int × α × Int) × Array (Int × Int) :=
  ((c.m.funding.toList.filter (·.event ≤ t)).map (fun f => (f.coin, f.event, f.rate)),
   c.m.bars.toList.filter (fun b => b.openTime + BAR ≤ t),
   (c.m.bars.toList.filter (·.openTime ≤ t)).map (fun b => (b.coin, b.openTime, b.o, b.trades)),
   c.m.intervals)

/-- The machine after the tick at hour wStart + n·HOUR: the engine's schedule of deliveries and
ticks, which never reads the book. -/
def Ctx.machineAfter (N : NumOps α) (c : Ctx α) (n : Nat) : Except Abort (MState α) := do
  let mut s ← c.start N
  for k in [1:n + 1] do
    let h := c.pol.wStart + (k : Int) * HOUR
    s ← c.deliver s (h + c.pol.delta)
    s := { s with machine := s.machine.tick N c.p (c.mask h) h }
  return s.machine

/-- The decision tick of step k (0-based): its boundary plus BAR plus δ. -/
def Ctx.decisionTime (c : Ctx α) (k : Nat) : Int := c.pol.wStart + ((k : Int) + 1) * BAR + c.pol.delta

theorem L1_values (N : NumOps α) (p : Program) (_ : WellTyped p) (m₁ m₂ : Market α) (v : Venue α) (pol : Policy)
    (stop : Int) (n : Nat)
    (hI : m₁.intervals = m₂.intervals) (hB : m₁.present = m₂.present)
    (hP : (Ctx.make p m₁ v pol stop).deliveryPrefix (pol.wStart + (n : Int) * HOUR + pol.delta)
        = (Ctx.make p m₂ v pol stop).deliveryPrefix (pol.wStart + (n : Int) * HOUR + pol.delta)) :
    ∀ k ≤ n, (Ctx.make p m₁ v pol stop).machineAfter N k = (Ctx.make p m₂ v pol stop).machineAfter N k := by
  sorry

theorem L1_decisions (N : NumOps α) (p : Program) (_ : WellTyped p) (m₁ m₂ : Market α) (v : Venue α) (pol : Policy)
    (stop : Int) (k : Nat)
    (hI : m₁.intervals = m₂.intervals) (hB : m₁.present = m₂.present)
    (hP : (Ctx.make p m₁ v pol stop).deliveryPrefix ((Ctx.make p m₁ v pol stop).decisionTime k)
        = (Ctx.make p m₂ v pol stop).deliveryPrefix ((Ctx.make p m₂ v pol stop).decisionTime k))
    (hE : (Ctx.make p m₁ v pol stop).execView ((Ctx.make p m₁ v pol stop).decisionTime k)
        = (Ctx.make p m₂ v pol stop).execView ((Ctx.make p m₂ v pol stop).decisionTime k)) :
    ((Ctx.make p m₁ v pol stop).steps N (k + 1)).map (·.trace)
      = ((Ctx.make p m₂ v pol stop).steps N (k + 1)).map (·.trace) := by
  sorry

/-! ## L2 unit soundness -/

/-- The dynamic unit semantics: the tag of node i's defined values, computed from its arguments'
tags with DSL.md's operand checks and unit transformations, or `none` on a unit error. -/
def dynTag (p : Program) : Nat → Option Ty
  | i =>
    match p.nodes[i]! with
    | .input inp => some (.num inp.unit)
    | .const _ u => some (.num u)
    | .param k => if k < p.params.size then some p.types[i]! else none
    | .op o args =>
      let tag (k : Nat) : Option Ty := if h : args[k]! < i then dynTag p args[k]! else none
      let num (k : Nat) : Option Dim := match tag k with | some (.num u) => some u | _ => none
      let bool (k : Nat) : Bool := tag k == some .bool
      match o with
      | .add | .sub | .min | .max => do let a ← num 0; let b ← num 1; if a == b then some (.num a) else none
      | .mul => do let a ← num 0; let b ← num 1; return .num (← Dim.mul a b)
      | .div => do let a ← num 0; let b ← num 1; return .num (← Dim.div a b)
      | .neg | .abs => do return .num (← num 0)
      | .sign => do discard (num 0); return .num Dim.one
      | .log | .exp => do let a ← num 0; if a == Dim.one then some (.num a) else none
      | .sqrt => do return .num (← Dim.sqrt (← num 0))
      | .clip => do let a ← num 0; let b ← num 1; let c ← num 2; if a == b && b == c then some (.num a) else none
      | .gt | .ge | .lt | .le => do let a ← num 0; let b ← num 1; if a == b then some .bool else none
      | .and | .or => if bool 0 && bool 1 then some .bool else none
      | .not => if bool 0 then some .bool else none
      | .ite => if !bool 0 then none else match tag 1, tag 2 with
        | some .bool, some .bool => some .bool
        | some (.num a), some (.num b) => if a == b then some (.num a) else none
        | _, _ => none
      | .convert _ => match p.types[i]! with
        | .num to => do let a ← num 0; discard (Dim.conversion a to); return .num to
        | .bool => none
      | .window _ _ => do return .num (← num 0)
      | .xsMean | .xsDemean => do return .num (← num 0)
      | .xsRank => do let a ← num 0; if a == Dim.one then some (.num a) else none
      | .hoursSince => if bool 0 then some (.num (Dim.base "h").get!) else none
termination_by i => i
decreasing_by all_goals assumption

theorem L2_units (p : Program) (_ : WellTyped p) : ∀ i < p.nodes.size, dynTag p i = some p.types[i]! := by
  sorry

/-! ## L3 rewrite soundness -/

/-- The number identities R version 1 relies on, with finiteness preserved (SEMANTICS.md §1). -/
structure NumOps.Lawful (N : NumOps α) : Prop where
  neg_neg : ∀ x, N.neg (N.neg x) = x
  abs_abs : ∀ x, N.abs (N.abs x) = N.abs x
  abs_neg : ∀ x, N.abs (N.neg x) = N.abs x
  mul_one : ∀ x, N.mul x (N.ofBits 0x3FF0000000000000) = x
  div_one : ∀ x, N.div x (N.ofBits 0x3FF0000000000000) = x
  sub_zero : ∀ x, N.sub x (N.ofBits 0) = x
  add_comm : ∀ x y, N.add x y = N.add y x
  mul_comm : ∀ x y, N.mul x y = N.mul y x
  one_ne_zero : N.isZero (N.ofBits 0x3FF0000000000000) = false
  truth_zero : ∀ b, N.isZero (N.truth b) = !b

/-- The rule schemas of R version 1 (kernel/CANONICAL.md), each direction a separate schema. -/
inductive Rule where
  | negNeg | absAbs | absNeg | mulOne | divOne | subZero
  | addComm | mulComm | andComm | orComm | notNot
  | ifNot | ifNotRev | gtLt | ltGt | geLe | leGe
  deriving DecidableEq, Repr

/-- Redirect every use of node i to node j (j < i), including the weight and the prediction. -/
def Program.redirect (p : Program) (i j : Nat) : Program :=
  let f (k : Nat) := if k == i then j else k
  { p with nodes := p.nodes.map fun n => match n with | .op o args => .op o (args.map f) | n => n,
           weight := f p.weight, prediction := p.prediction.map f }

/-- Insert node `n` at position k, shifting later indices by one. -/
def Program.insertAt (p : Program) (k : Nat) (n : Node) (t : Ty) : Program :=
  let f (j : Nat) := if j ≥ k then j + 1 else j
  let shift (n : Node) := match n with | .op o args => .op o (args.map f) | n => n
  { p with nodes := (p.nodes.map shift).insertIdx! k n, types := p.types.insertIdx! k t,
           weight := f p.weight, prediction := p.prediction.map f }

def isConst (p : Program) (j : Nat) (bits : UInt64) (u : Dim) : Bool := p.nodes[j]! == .const bits u

/-- Apply a rule at node i, if it matches there. -/
def Rule.apply (r : Rule) (p : Program) (i : Nat) : Option Program :=
  match r, p.nodes[i]! with
  | .negNeg, .op .neg [a] => match p.nodes[a]! with | .op .neg [x] => some (p.redirect i x) | _ => none
  | .absAbs, .op .abs [a] => match p.nodes[a]! with | .op .abs [_] => some (p.redirect i a) | _ => none
  | .absNeg, .op .abs [a] => match p.nodes[a]! with | .op .neg [x] => some { p with nodes := p.nodes.set! i (.op .abs [x]) } | _ => none
  | .mulOne, .op .mul [x, c] => if isConst p c 0x3FF0000000000000 Dim.one then some (p.redirect i x) else none
  | .divOne, .op .div [x, c] => if isConst p c 0x3FF0000000000000 Dim.one then some (p.redirect i x) else none
  | .subZero, .op .sub [x, c] => match p.types[x]! with
    | .num u => if isConst p c 0 u then some (p.redirect i x) else none
    | .bool => none
  | .addComm, .op .add [a, b] => some { p with nodes := p.nodes.set! i (.op .add [b, a]) }
  | .mulComm, .op .mul [a, b] => some { p with nodes := p.nodes.set! i (.op .mul [b, a]) }
  | .andComm, .op .and [a, b] => some { p with nodes := p.nodes.set! i (.op .and [b, a]) }
  | .orComm, .op .or [a, b] => some { p with nodes := p.nodes.set! i (.op .or [b, a]) }
  | .notNot, .op .not [a] => match p.nodes[a]! with | .op .not [c] => some (p.redirect i c) | _ => none
  | .ifNot, .op .ite [nc, a, b] => match p.nodes[nc]! with
    | .op .not [c] => some { p with nodes := p.nodes.set! i (.op .ite [c, b, a]) }
    | _ => none
  | .ifNotRev, .op .ite [c, b, a] =>
    let q := p.insertAt i (.op .not [c]) .bool
    some { q with nodes := q.nodes.set! (i + 1) (.op .ite [i, a, b]) }
  | .gtLt, .op .gt [a, b] => some { p with nodes := p.nodes.set! i (.op .lt [b, a]) }
  | .ltGt, .op .lt [a, b] => some { p with nodes := p.nodes.set! i (.op .gt [b, a]) }
  | .geLe, .op .ge [a, b] => some { p with nodes := p.nodes.set! i (.op .le [b, a]) }
  | .leGe, .op .le [a, b] => some { p with nodes := p.nodes.set! i (.op .ge [b, a]) }
  | _, _ => none

/-- The rewritten program is well-typed, and every run is identical: weights, holds, decisions,
orders, fills, fees, settlements, equity and returns, or the same abort. -/
theorem L3_rewrite (N : NumOps α) (hN : N.Lawful) (r : Rule) (p p' : Program) (i : Nat) (_ : WellTyped p)
    (h : r.apply p i = some p') :
    (∀ j < p'.nodes.size, dynTag p' j = some p'.types[j]!) ∧
    ∀ (m : Market α) (v : Venue α) (pol : Policy) (stop : Int), run N p' m v pol stop = run N p m v pol stop := by
  sorry

/-! ## L4 fill ordering -/

def firstBarAtOrAfter (m : Market α) (coin : Nat) (t : Int) : Option (BarRow α) :=
  let bars := (m.bars.toList.filter (fun b => b.coin == coin && t ≤ b.openTime))
  bars.foldl (fun acc b => match acc with | some a => if b.openTime < a.openTime then some b else acc | none => some b) none

/-- Every ordinary fill is the order's selected bar's open, after its decision, priced and charged by
the cost table; every closeout uses its own reference; every delivered observation was known at the
decision. -/
theorem L4_fills (N : NumOps α) (p : Program) (_ : WellTyped p) (m : Market α) (v : Venue α) (pol : Policy) (stop : Int)
    (r : Run α) (hr : run N p m v pol stop = .ok r) :
    ∀ e ∈ r.trace.toList, ∀ f, e = .fill f →
      N.isZero f.qty = false ∧ f.inputsKnown ≤ f.decided ∧ f.decided ≤ f.submitted ∧ f.submitted ≤ f.filled ∧
      f.price = fillPrice N v f.coin f.qty f.reference ∧ f.fee = N.mul (N.mul (N.abs f.qty) f.price) v.takerFee ∧
      (f.why = .fill →
        f.submitted = f.decided ∧
        ∃ bar, firstBarAtOrAfter m f.coin f.submitted = some bar ∧ bar.trades ≥ 1 ∧
          f.sourceOpen = bar.openTime ∧ f.filled = bar.openTime ∧ f.reference = bar.o) := by
  sorry

/-- The converse: an order decided at t = B + δ is due at B + BAR. Once its step runs
(B + 3·BAR ≤ stop), it is filled if its selected bar opens at B + BAR and traded, and is recorded
unfilled otherwise; it never rolls to a later bar. -/
theorem L4_orders (N : NumOps α) (p : Program) (_ : WellTyped p) (m : Market α) (v : Venue α) (pol : Policy) (stop : Int)
    (r : Run α) (hr : run N p m v pol stop = .ok r) :
    ∀ t c w q, Event.decision t c w q ∈ r.trace.toList → t - pol.delta + 3 * BAR ≤ stop →
      (∃ bar, firstBarAtOrAfter m c t = some bar ∧ bar.openTime = t - pol.delta + BAR ∧ bar.trades ≥ 1 ∧
        ∃ f, Event.fill f ∈ r.trace.toList ∧ f.why = .fill ∧ f.coin = c ∧ f.decided = t ∧ f.qty = q ∧ f.filled = bar.openTime) ∨
      ((∀ bar, firstBarAtOrAfter m c t = some bar → bar.openTime ≠ t - pol.delta + BAR ∨ bar.trades < 1) ∧
        Event.unfilled (t - pol.delta + BAR) c q ∈ r.trace.toList) := by
  sorry

/-! ## L5 binding -/

/-- A run is refused as unavailable exactly when some event source the program names is unbound,
before any delivery or tick; with every source bound, that refusal never occurs. -/
theorem L5_binding (N : NumOps α) (p : Program) (_ : WellTyped p) (m : Market α) (v : Venue α) (pol : Policy) (stop : Int) :
    (run N p m v pol stop = .error .inputUnavailable ↔ ∃ s ∈ p.eventSlots, s ∉ m.present) ∧
    ((∃ s ∈ p.eventSlots, s ∉ m.present) → (Ctx.make p m v pol stop).start N = .error .inputUnavailable) := by
  sorry

end Ref
