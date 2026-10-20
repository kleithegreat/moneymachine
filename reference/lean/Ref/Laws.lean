import Ref.Sim
import Ref.Units
import Ref.Proof.Errors
import Ref.Proof.Checker

/-!
The five laws of stage 6 (PROGRESS.md, Stage 6, with its revisions), stated over the model of
reference/SEMANTICS.md. Each holds for every number structure `N`; L3's obligations are explicit
hypotheses. Abstract statements are proved here; the binary64 instance (`floatOps`) is not, because
Lean's `Float` is opaque, and it is tested instead (C6.4). These statements and the definitions they
use are frozen with SEMANTICS.md before any proof.
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

/-- Equal delivery prefixes give equal machine states (values, windows, held inputs, `hours_since`
state) at every tick through t. -/
theorem L1_values (N : NumOps α) (p : Program) (_ : CheckerAccepted p) (m₁ m₂ : Market α)
    (_ : m₁.Admissible) (_ : m₂.Admissible) (v : Venue α) (pol : Policy) (_ : pol.Valid) (stop : Int) (n : Nat)
    (hI : m₁.intervals = m₂.intervals) (hB : m₁.bound = m₂.bound)
    (hP : (Ctx.make p m₁ v pol stop).deliveryPrefix (pol.wStart + (n : Int) * HOUR + pol.delta)
        = (Ctx.make p m₂ v pol stop).deliveryPrefix (pol.wStart + (n : Int) * HOUR + pol.delta)) :
    ∀ k ≤ n, (Ctx.make p m₁ v pol stop).machineAfter N k = (Ctx.make p m₂ v pol stop).machineAfter N k := by
  sorry

/-- The simulator's machine is that schedule: after j steps, it is the machine after the tick at
wStart + 4j·HOUR. -/
theorem L1_simulator (N : NumOps α) (p : Program) (_ : CheckerAccepted p) (m : Market α) (_ : m.Admissible)
    (v : Venue α) (pol : Policy) (_ : pol.Valid) (stop : Int) (j : Nat) (s : SState α)
    (h : (Ctx.make p m v pol stop).steps N j = .ok s) :
    (Ctx.make p m v pol stop).machineAfter N (4 * j) = .ok s.machine := by
  sorry

/-- Equal delivery prefixes and execution views through step k's decision give the same observations
at every step through it: the same trace, or the same rejection. -/
theorem L1_decisions (N : NumOps α) (p : Program) (_ : CheckerAccepted p) (m₁ m₂ : Market α)
    (_ : m₁.Admissible) (_ : m₂.Admissible) (v : Venue α) (_ : v.Valid m₁.intervals.size) (pol : Policy) (_ : pol.Valid)
    (stop : Int) (k : Nat)
    (hI : m₁.intervals = m₂.intervals) (hB : m₁.bound = m₂.bound)
    (hP : (Ctx.make p m₁ v pol stop).deliveryPrefix ((Ctx.make p m₁ v pol stop).decisionTime k)
        = (Ctx.make p m₂ v pol stop).deliveryPrefix ((Ctx.make p m₂ v pol stop).decisionTime k))
    (hE : (Ctx.make p m₁ v pol stop).execView ((Ctx.make p m₁ v pol stop).decisionTime k)
        = (Ctx.make p m₂ v pol stop).execView ((Ctx.make p m₂ v pol stop).decisionTime k)) :
    ∀ j ≤ k + 1, ((Ctx.make p m₁ v pol stop).steps N j).map (·.trace)
      = ((Ctx.make p m₂ v pol stop).steps N j).map (·.trace) := by
  sorry

/-! ## L2 unit soundness -/

/-- The instrumented machine never raises a unit error; its defined values carry their nodes' static
types, booleans are canonical, and erasing the tags gives the executable machine's values and state
(or the same rejection). -/
theorem L2_units (N : NumOps α) (p : Program) (_ : CheckerAccepted p) (m : Market α) (_ : m.Admissible)
    (v : Venue α) (pol : Policy) (_ : pol.Valid) (stop : Int) (n : Nat) :
    let c := Ctx.make p m v pol stop
    (∀ e, c.umachineAfter N n ≠ .error (.inr e)) ∧
    (∀ a, c.umachineAfter N n = .error (.inl a) ↔ c.machineAfter N n = .error a) ∧
    (∀ u, c.umachineAfter N n = .ok u →
      ∃ ms, c.machineAfter N n = .ok ms ∧ u.erase = ms.vals ∧ u.m.wins = ms.wins ∧ u.m.since = ms.since ∧
        u.m.funding = ms.funding ∧ u.m.bar = ms.bar ∧ u.m.events = ms.events ∧
        ∀ i < p.nodes.size, ∀ (coin : Nat) (x : α) (t : Ty), u.tv[i]![coin]! = some (x, t) →
          t = p.types[i]! ∧ (t = .bool → ∃ b, x = N.truth b)) := by
  sorry

/-- The checker's programs are well-formed. -/
theorem L2_checker (p : Program) (_ : CheckerAccepted p) : p.WF := by
  have sound : TypeOpSound opTy := by
    intro name op arity ts kvs hmem hlen st op' ty st' h
    simp only [ops, List.mem_cons, Prod.mk.injEq, List.not_mem_nil, or_false] at hmem
    rcases hmem with ⟨-, rfl, rfl⟩ | ⟨-, rfl, rfl⟩ | ⟨-, rfl, rfl⟩ | ⟨-, rfl, rfl⟩ | ⟨-, rfl, rfl⟩ | ⟨-, rfl, rfl⟩ | ⟨-, rfl, rfl⟩ | ⟨-, rfl, rfl⟩ |
      ⟨-, rfl, rfl⟩ | ⟨-, rfl, rfl⟩ | ⟨-, rfl, rfl⟩ | ⟨-, rfl, rfl⟩ | ⟨-, rfl, rfl⟩ | ⟨-, rfl, rfl⟩ | ⟨-, rfl, rfl⟩ | ⟨-, rfl, rfl⟩ |
      ⟨-, rfl, rfl⟩ | ⟨-, rfl, rfl⟩ | ⟨-, rfl, rfl⟩ | ⟨-, rfl, rfl⟩ | ⟨-, rfl, rfl⟩ | ⟨-, rfl, rfl⟩ | ⟨-, rfl, rfl⟩ | ⟨-, rfl, rfl⟩ |
      ⟨-, rfl, rfl⟩ | ⟨-, rfl, rfl⟩ | ⟨-, rfl, rfl⟩ | ⟨-, rfl, rfl⟩ | ⟨-, rfl, rfl⟩ | ⟨-, rfl, rfl⟩ | ⟨-, rfl, rfl⟩ | ⟨-, rfl, rfl⟩ |
      ⟨-, rfl, rfl⟩
    all_goals rcases ts with _ | ⟨a, _ | ⟨b, _ | ⟨c, _ | ⟨d, _⟩⟩⟩⟩ <;> simp at hlen
    all_goals (try cases a) <;> (try cases b) <;> (try cases c)
    all_goals replace h := h.symm
    all_goals tsimp
    all_goals try (simp_all [opTy]; done)
    all_goals try (simp_all [opTy]; rfl)
    all_goals try (generalize hm : Dim.mul _ _ = o at h; cases o <;> tsimp <;> simp_all [opTy]; done)
    all_goals try (generalize hm : Dim.div _ _ = o at h; cases o <;> tsimp <;> simp_all [opTy]; done)
    all_goals try (generalize hm : Dim.sqrt _ = o at h; cases o <;> tsimp <;> simp_all [opTy]; done)
    all_goals try (obtain ⟨a, b, hab, h⟩ := h; obtain rfl := unitOf_keeps _ _ _ _ hab.symm
                   generalize hm : Dim.conversion _ _ = o at h; cases o <;> tsimp <;> simp_all [opTy]; done)
    all_goals try (generalize field kvs "hours" = j at h; cases j <;> tsimp; rename_i i
                   by_cases hw : 1 ≤ i ∧ i ≤ (maxHours : Int) <;> simp [hw] at h <;> tsimp <;> simp_all [opTy] <;> omega)
    all_goals try grind [opTy]
  obtain ⟨_, h⟩ := ‹CheckerAccepted p›
  exact check_wf opTy sound h

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

/-- Rewriting keeps a well-formed program well-formed; at every tick every original node's values
equal its corresponding node's; and every step's observations are identical (the same trace, or the
same rejection), hence the whole run. -/
theorem L3_rewrite (N : NumOps α) (hN : N.Lawful) (r : Rule) (p p' : Program) (i : Nat) (_ : p.WF)
    (h : r.apply p i = some p') (m : Market α) (_ : m.Admissible) (v : Venue α) (pol : Policy) (_ : pol.Valid)
    (stop : Int) :
    p'.WF ∧
    (∀ n, ((Ctx.make p' m v pol stop).machineAfter N n).isOk = ((Ctx.make p m v pol stop).machineAfter N n).isOk ∧
      ∀ ms ms', (Ctx.make p m v pol stop).machineAfter N n = .ok ms → (Ctx.make p' m v pol stop).machineAfter N n = .ok ms' →
        ∀ k < p.nodes.size, ms'.vals[r.corr i k]! = ms.vals[k]!) ∧
    (∀ j, ((Ctx.make p' m v pol stop).steps N j).map (·.trace) = ((Ctx.make p m v pol stop).steps N j).map (·.trace)) ∧
    run N p' m v pol stop = run N p m v pol stop := by
  sorry

/-! ## L4 fill ordering -/

def barAt (m : Market α) (coin : Nat) (t : Int) : Option (BarRow α) :=
  m.bars.toList.find? fun b => b.coin == coin && b.openTime == t

/-- The latest bar of a coin with eventTime ≤ t. -/
def latestClosed (m : Market α) (coin : Nat) (t : Int) : Option (BarRow α) :=
  (m.bars.toList.filter fun b => b.coin == coin && b.event ≤ t).foldl
    (fun acc b => match acc with | some a => if a.openTime < b.openTime then some b else acc | none => some b) none

/-- Every fill is nonzero, ordered in time, priced by the cost table and charged the fee. An ordinary
fill is its order's scheduled bar's open, after its decision, and its recorded input bound is the
decision machine's latest knownAt, no later than the decision. A closeout is at its own time, from
the coin's latest closed bar: the adverse extreme for a liquidation, the close for a delisting. -/
theorem L4_fills (N : NumOps α) (p : Program) (_ : CheckerAccepted p) (m : Market α) (_ : m.Admissible)
    (v : Venue α) (_ : v.Valid m.intervals.size) (pol : Policy) (_ : pol.Valid) (stop : Int)
    (r : Run α) (hr : run N p m v pol stop = .ok r) :
    ∀ f, Event.fill f ∈ r.trace.toList →
      N.isZero f.qty = false ∧ f.inputsKnown ≤ f.decided ∧ f.decided ≤ f.submitted ∧ f.submitted ≤ f.filled ∧
      f.price = fillPrice N v f.coin f.qty f.reference ∧ f.fee = N.mul (N.mul (N.abs f.qty) f.price) v.takerFee ∧
      (f.why = .fill →
        f.submitted = f.decided ∧ f.filled = f.decided - pol.delta + BAR ∧
        (∃ bar, barAt m f.coin f.filled = some bar ∧ bar.trades ≥ 1 ∧ f.sourceOpen = bar.openTime ∧ f.reference = bar.o) ∧
        ∃ (n : Nat) (ms : MState α), pol.wStart + (n : Int) * HOUR + pol.delta = f.decided ∧
          (Ctx.make p m v pol stop).machineAfter N n = .ok ms ∧ ms.maxKnown = f.inputsKnown) ∧
      (f.why ≠ .fill →
        f.inputsKnown = f.filled ∧ f.decided = f.filled ∧ f.submitted = f.filled ∧
        ∃ bar, latestClosed m f.coin f.filled = some bar ∧ f.sourceOpen = bar.openTime ∧
          f.reference = (if f.why = .delisting then bar.c else if N.lt N.zero f.qty then bar.h else bar.l)) := by
  sorry

/-- Exactly once: every order whose due step runs (B + 3·BAR ≤ stop, with B its decision's boundary)
has exactly one later resolution in the trace, the fill at its scheduled bar if that bar exists and
traded and otherwise its Unfilled record; and every ordinary fill has exactly one earlier decision
it resolves. -/
theorem L4_orders (N : NumOps α) (p : Program) (_ : CheckerAccepted p) (m : Market α) (_ : m.Admissible)
    (v : Venue α) (_ : v.Valid m.intervals.size) (pol : Policy) (_ : pol.Valid) (stop : Int)
    (r : Run α) (hr : run N p m v pol stop = .ok r) :
    let resolves (t : Int) (c : Nat) (q : α) (e : Event α) : Prop :=
      (∃ f : Fill α, e = Event.fill f ∧ f.why = .fill ∧ f.coin = c ∧ f.decided = t ∧ f.qty = q) ∨ e = Event.unfilled (t - pol.delta + BAR) c q
    (∀ (i : Nat) (t : Int) (c : Nat) (w q : α), r.trace[i]? = some (Event.decision t c w q) → t - pol.delta + 3 * BAR ≤ stop →
      (∃ j : Nat, i < j ∧ ∃ e : Event α, r.trace[j]? = some e ∧ resolves t c q e ∧
        ∀ (j' : Nat) (e' : Event α), r.trace[j']? = some e' → resolves t c q e' → j' = j) ∧
      ((∃ bar, barAt m c (t - pol.delta + BAR) = some bar ∧ bar.trades ≥ 1) ↔
        ∃ f : Fill α, Event.fill f ∈ r.trace.toList ∧ f.why = .fill ∧ f.coin = c ∧ f.decided = t)) ∧
    (∀ (j : Nat) (f : Fill α), r.trace[j]? = some (Event.fill f) → f.why = .fill →
      ∃ (i : Nat) (w : α), i < j ∧ r.trace[i]? = some (Event.decision f.decided f.coin w f.qty) ∧
        ∀ (i' : Nat) (w' : α), r.trace[i']? = some (Event.decision f.decided f.coin w' f.qty) → i' = i) := by
  sorry

/-! ## L5 binding -/

/-- A run is refused as unavailable exactly when some event source the program names is unbound,
before any delivery or tick; with every source bound, preflight passes and the run is the ordinary
evaluation. -/
theorem L5_binding (N : NumOps α) (p : Program) (_ : CheckerAccepted p) (m : Market α) (v : Venue α) (pol : Policy)
    (stop : Int) :
    (run N p m v pol stop = .error .inputUnavailable ↔ ∃ s ∈ p.eventSlots, s ∉ m.bound) ∧
    ((∃ s ∈ p.eventSlots, s ∉ m.bound) → (Ctx.make p m v pol stop).start N = .error .inputUnavailable) ∧
    ((∀ s ∈ p.eventSlots, s ∈ m.bound) →
      (Ctx.make p m v pol stop).start N = (do
        let s ← (Ctx.make p m v pol stop).deliver ((Ctx.make p m v pol stop).state0 N) (pol.wStart + pol.delta)
        return { s with machine := s.machine.tick N p ((Ctx.make p m v pol stop).mask pol.wStart) pol.wStart })) := by
  refine ⟨⟨fun hr => ?_, fun h => ?_⟩, fun h => start_unbound N _ h, fun h => start_bound N _ h⟩
  · refine Classical.byContradiction fun hn => ?_
    have hb : ∀ s ∈ p.eventSlots, s ∈ m.bound := fun s hs => Classical.byContradiction fun hm => hn ⟨s, hs, hm⟩
    have hs : Except.Avoids .inputUnavailable ((Ctx.make p m v pol stop).start N) := by
      rw [start_bound N _ hb]
      exact .bind (deliver_avoids _ _ _) fun _ => .pure _
    exact Except.Avoids.bind (steps_avoids_of_start N _ _ hs) (fun _ => .pure _) hr
  · simp only [run, Ctx.steps, start_unbound N (Ctx.make p m v pol stop) h]; rfl

end Ref
