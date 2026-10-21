import Ref.Sim
import Ref.Units

/-!
The definitions the stage 6 laws use (PROGRESS.md, Stage 6, with its revisions): admissible inputs, the
machine's schedule alone and instrumented, delivery prefixes and execution views, the R version 1
rewrite rules, and the bar lookups of L4. They are frozen with the laws (`Ref/Laws.lean`).
-/

namespace Ref

variable {α : Type} [Inhabited α]

/-! ## Admissible inputs -/

/-- Programs the frozen checker accepts. -/
def CheckerAccepted (p : Program) : Prop := ∃ text, check text = .ok p

/-- The typing rule of one operator over its arguments' types (SEMANTICS.md §2). -/
def opTy (o : Op) (ts : List Ty) (to : Option Dim) : Option Ty :=
  let num (k : Nat) : Option Dim := match ts[k]? with | some (.num u) => some u | _ => none
  let isBool (k : Nat) : Bool := ts[k]? == some .bool
  match o with
  | .add | .sub | .min | .max => do let a ← num 0; let b ← num 1; if a == b then some (.num a) else none
  | .mul => do return .num (← Dim.mul (← num 0) (← num 1))
  | .div => do return .num (← Dim.div (← num 0) (← num 1))
  | .neg | .abs => do return .num (← num 0)
  | .sign => do discard (num 0); return .num Dim.one
  | .log | .exp => do let a ← num 0; if a == Dim.one then some (.num a) else none
  | .sqrt => do return .num (← Dim.sqrt (← num 0))
  | .clip => do let a ← num 0; let b ← num 1; let c ← num 2; if a == b && b == c then some (.num a) else none
  | .gt | .ge | .lt | .le => do let a ← num 0; let b ← num 1; if a == b then some .bool else none
  | .and | .or => if isBool 0 && isBool 1 then some .bool else none
  | .not => if isBool 0 then some .bool else none
  | .ite => if !isBool 0 then none else match (ts[1]? : Option Ty), (ts[2]? : Option Ty) with
    | some .bool, some .bool => some .bool
    | some (.num a), some (.num b) => if a == b then some (.num a) else none
    | _, _ => none
  | .convert f => do
    let a ← num 0; let t ← to
    if Dim.conversion a t == some f then some (.num t) else none
  | .window _ h => if 1 ≤ h && h ≤ maxHours then do return .num (← num 0) else none
  | .xsMean | .xsDemean => do return .num (← num 0)
  | .xsRank => do let a ← num 0; if a == Dim.one then some (.num a) else none
  | .hoursSince => if isBool 0 then some (.num (Dim.base "h").get!) else none

/-- Structural well-formedness: sizes agree, arguments precede their users, every node is typed by
its rule, the weight is a dimensionless number and the prediction a boolean. -/
def Program.WF (p : Program) : Prop :=
  p.types.size = p.nodes.size ∧ p.convTo.size = p.nodes.size ∧
  p.weight < p.nodes.size ∧ p.types[p.weight]! = .num Dim.one ∧
  (∀ q, p.prediction = some q → q < p.nodes.size ∧ p.types[q]! = .bool) ∧
  ∀ i < p.nodes.size, match p.nodes[i]! with
    | .input inp => p.types[i]! = .num inp.unit
    | .const _ u => p.types[i]! = .num u
    | .param k => k < p.params.size ∧ p.types[i]! = .num p.params[k]!.2
    | .op o args => (∀ a ∈ args, a < i) ∧ opTy o (args.map (p.types[·]!)) p.convTo[i]! = some p.types[i]!

/-- An admissible market: unique keys, correctly timed bars, coin and slot indices in range. -/
structure Market.Admissible (m : Market α) : Prop where
  fundingKeys : (m.funding.toList.map fun f => (f.coin, f.event)).Nodup
  barKeys : (m.bars.toList.map fun b => (b.coin, b.openTime)).Nodup
  eventKeys : (m.events.toList.map fun e => (e.slot, e.coin, e.event)).Nodup
  barEvent : ∀ b ∈ m.bars.toList, b.event = b.openTime + BAR
  fundingCoin : ∀ f ∈ m.funding.toList, f.coin < m.intervals.size
  barCoin : ∀ b ∈ m.bars.toList, b.coin < m.intervals.size
  eventIndex : ∀ e ∈ m.events.toList, e.coin < m.intervals.size ∧ e.slot < eventInputs.length

structure Venue.Valid (v : Venue α) (coins : Nat) : Prop where
  sizes : v.szDecimals.size = coins ∧ v.minTierLeverage.size = coins ∧ v.costBps.size = coins
  cells : ∀ c < coins, v.costBps[c]!.size = 2 ∧ ∀ s < 2, v.costBps[c]![s]!.size = 2

structure Policy.Valid (pol : Policy) : Prop where
  delta : 0 < pol.delta ∧ pol.delta < HOUR

/-! ## The machine's schedule, alone and instrumented -/

/-- The machine after the tick at hour wStart + n·HOUR: the engine's schedule of deliveries and
ticks, which never reads the book. -/
def Ctx.machineAfter (N : NumOps α) (c : Ctx α) (n : Nat) : Except Abort (MState α) := do
  let mut s ← c.start N
  for k in [1:n + 1] do
    let h := c.pol.wStart + (k : Int) * HOUR
    s ← c.deliver s (h + c.pol.delta)
    s := { s with machine := s.machine.tick N c.p (c.mask h) h }
  return s.machine

/-- The same schedule with the unit-instrumented tick. -/
def Ctx.umachineAfter (N : NumOps α) (c : Ctx α) (n : Nat) : Except (Abort ⊕ UnitError) (UState α) := do
  if !c.bound then throw (.inl .inputUnavailable)
  let mut u := UState.init N c.p c.coins
  let mut s := c.state0 N
  for k in [0:n + 1] do
    let h := c.pol.wStart + (k : Int) * HOUR
    s ← (c.deliver { s with machine := u.m } (h + c.pol.delta)).mapError .inl
    u ← ({ u with m := s.machine }.tick N c.p (c.mask h) h).mapError .inr
  return u

/-- The decision tick of step k (0-based): its boundary plus BAR plus δ. -/
def Ctx.decisionTime (c : Ctx α) (k : Nat) : Int := c.pol.wStart + ((k : Int) + 1) * BAR + c.pol.delta

/-! ## L1 non-interference -/

/-- The ordered delivery prefix by time t (SEMANTICS.md §3): every resolved funding row, bar and bound
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

/-! ## L3 rewrite soundness -/

/-- The obligations of R version 1 (kernel/CANONICAL.md), on finite operands, with finiteness
preserved where a rule removes or reorders an operation. -/
structure NumOps.Lawful (N : NumOps α) : Prop where
  neg_neg : ∀ x, N.finite x → N.neg (N.neg x) = x
  abs_abs : ∀ x, N.finite x → N.abs (N.abs x) = N.abs x
  abs_neg : ∀ x, N.finite x → N.abs (N.neg x) = N.abs x
  mul_one : ∀ x, N.finite x → N.mul x (N.ofBits 0x3FF0000000000000) = x
  div_one : ∀ x, N.finite x → N.div x (N.ofBits 0x3FF0000000000000) = x
  sub_zero : ∀ x, N.finite x → N.sub x (N.ofBits 0) = x
  add_comm : ∀ x y, N.add x y = N.add y x
  mul_comm : ∀ x y, N.mul x y = N.mul y x
  finite_neg : ∀ x, N.finite x → N.finite (N.neg x)
  finite_abs : ∀ x, N.finite x → N.finite (N.abs x)
  finite_one : N.finite (N.ofBits 0x3FF0000000000000)
  finite_zero : N.finite (N.ofBits 0)
  one_ne_zero : N.isZero (N.ofBits 0x3FF0000000000000) = false
  truth_zero : ∀ b, N.isZero (N.truth b) = !b
  finite_truth : ∀ b, N.finite (N.truth b)

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
           convTo := p.convTo.insertIdx! k none, weight := f p.weight, prediction := p.prediction.map f }

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

/-- Where each original node lives in the rewritten program. -/
def Rule.corr (r : Rule) (i j : Nat) : Nat := if r == .ifNotRev && j ≥ i then j + 1 else j

/-! ## L4 fill ordering -/

def barAt (m : Market α) (coin : Nat) (t : Int) : Option (BarRow α) :=
  m.bars.toList.find? fun b => b.coin == coin && b.openTime == t

/-- The latest bar of a coin with eventTime ≤ t. -/
def latestClosed (m : Market α) (coin : Nat) (t : Int) : Option (BarRow α) :=
  (m.bars.toList.filter fun b => b.coin == coin && b.event ≤ t).foldl
    (fun acc b => match acc with | some a => if a.openTime < b.openTime then some b else acc | none => some b) none

/-! ## L6 bounded loss (added 2026-10-21 with I10) -/

/-- The facts about numbers the loss bound needs. Each holds in binary64: an equity within the accounting
tolerance of another value is finite; a finite positive equity over a positive previous equity, minus 1,
is at least −1 (the quotient is ≥ +0, or +∞); and −1 ≤ −1, −1 ≤ 0. -/
structure NumOps.Bounded (N : NumOps α) : Prop where
  acc_finite : ∀ x y, N.le (N.abs (N.sub x y)) (N.ofBits 0x3EE4F8B588E368F1) = true → N.finite x = true
  ret : ∀ x y, N.finite x = true → N.lt N.zero x = true → N.lt N.zero y = true →
    N.le (N.neg N.one) (N.sub (N.div x y) N.one) = true
  floor : N.le (N.neg N.one) (N.neg N.one) = true
  flat : N.le (N.neg N.one) N.zero = true

end Ref
