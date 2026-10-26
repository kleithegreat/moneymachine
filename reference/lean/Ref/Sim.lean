import Std.Data.HashMap
import Ref.Machine

/-!
The simulation loop (reference/SEMANTICS.md §7–§8): decisions, orders, fills, funding, marks,
margin, delisting, accounting and returns, step for step as the engine runs them.
-/

namespace Ref
open Std

inductive Why where
  | fill | liquidation | delisting
  deriving DecidableEq, Repr, Inhabited

structure Fill (α : Type) where
  why : Why
  coin : Nat
  qty : α
  inputsKnown : Int
  decisionPrice : α
  decided : Int
  submitted : Int
  filled : Int
  sourceOpen : Int
  reference : α
  price : α
  fee : α
  deriving Inhabited

inductive Event (α : Type) where
  | decision (t : Int) (coin : Nat) (weight qty : α)
  | hold (t : Int) (coin : Nat) (why : String)
  | fill (f : Fill α)
  | unfilled (t : Int) (coin : Nat) (qty : α)
  | funding (t : Int) (coin : Nat) (rate price paid : α)
  | equity (t : Int) (equity reconciled : α)
  deriving Inhabited

inductive Abort where
  | causality | timing | fill | accounting | portfolio | bound | inputUnavailable | settlementMissing
  deriving DecidableEq, Repr

def Abort.code : Abort → String
  | .causality => "R_CAUSALITY" | .timing => "R_TIMING" | .fill => "R_FILL" | .accounting => "R_ACCOUNTING"
  | .portfolio => "R_PORTFOLIO" | .bound => "R_BOUND" | .inputUnavailable => "R_INPUT_UNAVAILABLE"
  | .settlementMissing => "R_SETTLEMENT_MISSING"

structure Venue (α : Type) where
  takerFee : α
  minNotional : α
  szDecimals : Array Nat
  minTierLeverage : Array α
  /-- [coin][buy = 0, sell = 1][≤ $1k = 0, ≤ $10k = 1] bps. -/
  costBps : Array (Array (Array α))

structure Market (α : Type) where
  funding : Array (FundingRow α)
  bars : Array (BarRow α)
  events : Array (EventRow α)
  /-- Event slots whose dataset is in the store (bound). -/
  bound : List Nat
  intervals : Array (Int × Int)

structure Policy where
  delta : Int
  wStart : Int

structure Run (α : Type) where
  trace : Array (Event α)
  returns : Array α
  grossReturns : Array α
  equity : Array α

variable {α : Type} [Inhabited α] (N : NumOps α)

def initial : α := N.ofNat 10000
def maxGross : α := N.ofNat 2
def maxOrderNotional : α := N.ofNat 10000

/-- The event slot a node reads, if it is an event input. -/
def Node.slot : Node → Option Nat
  | .input (.event s) => some s
  | _ => none

/-- Event slots the program reads (SEMANTICS.md §8). -/
def Program.eventSlots (p : Program) : List Nat := (p.nodes.toList.filterMap Node.slot).eraseDups

def truncate (x : α) (dec : Nat) : α :=
  let f := N.ofNat (10 ^ dec)
  N.div (N.trunc (N.mul x f)) f

def costBps (v : Venue α) (coin : Nat) (qty ref : α) : α :=
  let side := if N.lt N.zero qty then 0 else 1
  let size := if N.le (N.mul (N.abs qty) ref) (N.ofNat 1000) then 0 else 1
  v.costBps[coin]![side]![size]!

def fillPrice (v : Venue α) (coin : Nat) (qty ref : α) : α :=
  N.mul ref (N.add N.one (N.div (N.mul (N.signum qty) (costBps N v coin qty ref)) (N.ofNat 10000)))

structure Book (α : Type) where
  cash : α
  pos : List (Nat × α)
  entry : List (Nat × α)
  realized : α
  fees : α
  slippage : α
  funding : α
  /-- Shortfalls the venue absorbed at bankruptcy. -/
  absorbed : α

def assoc? {β} (l : List (Nat × β)) (k : Nat) : Option β := (l.find? (·.1 == k)).map (·.2)
def assocSet {β} (l : List (Nat × β)) (k : Nat) (v : β) : List (Nat × β) :=
  ((l.filter (·.1 != k)) ++ [(k, v)]).mergeSort (fun a b => a.1 ≤ b.1)
def assocDel {β} (l : List (Nat × β)) (k : Nat) : List (Nat × β) := l.filter (·.1 != k)

def Book.fill (b : Book α) (coin : Nat) (qty price fee : α) : Book α :=
  let old := (assoc? b.pos coin).getD N.zero
  let new := N.add old qty
  let realized := if !N.isZero old && (N.lt N.zero old != N.lt N.zero qty) then
      let closed := N.mul (N.min (N.abs qty) (N.abs old)) (N.signum old)
      N.add b.realized (N.mul closed (N.sub price (assoc? b.entry coin).get!))
    else b.realized
  let (pos, entry) := if N.isZero new then (assocDel b.pos coin, assocDel b.entry coin) else
    let entry := if N.isZero old || (N.lt N.zero old != N.lt N.zero new) then assocSet b.entry coin price
      else if N.lt N.zero old == N.lt N.zero qty then
        assocSet b.entry coin (N.div (N.add (N.mul old (assoc? b.entry coin).get!) (N.mul qty price)) new)
      else b.entry
    (assocSet b.pos coin new, entry)
  { b with pos, entry, realized, cash := N.sub b.cash (N.add (N.mul qty price) fee), fees := N.add b.fees fee }

def Book.settle (b : Book α) (coin : Nat) (price rate : α) : Book α × α :=
  let paid := N.mul (N.mul ((assoc? b.pos coin).getD N.zero) price) rate
  ({ b with cash := N.sub b.cash paid, funding := N.sub b.funding paid }, paid)

def Book.equity (b : Book α) (marks : Array α) : α :=
  N.add b.cash (total N (b.pos.map fun (c, q) => N.mul q marks[c]!))

def Book.reconciled (b : Book α) (marks : Array α) : α :=
  let unrealized := total N (b.pos.map fun (c, q) => N.mul q (N.sub marks[c]! (assoc? b.entry c).get!))
  N.add (N.add (N.sub (N.add (N.add (initial N) b.realized) unrealized) b.fees) b.funding) b.absorbed

/-- Losses are capped at equity: once flat, the venue absorbs a negative balance. -/
def Book.absorb (b : Book α) : Book α := { b with absorbed := N.sub b.absorbed b.cash, cash := N.zero }

structure Index (α : Type) where
  barAt : HashMap (Nat × Int) Nat
  barTimes : Array (Array Int)
  rateAt : HashMap (Nat × Int) α

def Market.index (m : Market α) (coins : Nat) : Index α :=
  { barAt := m.bars.foldl (init := (HashMap.emptyWithCapacity, 0)) (fun (h, i) b => (h.insert (b.coin, b.openTime) i, i + 1)) |>.1
    barTimes := (Array.range coins).map fun c => ((m.bars.filter (·.coin == c)).map (·.openTime)).mergeSort (· ≤ ·)
    rateAt := m.funding.foldl (init := HashMap.emptyWithCapacity) fun h f => h.insert (f.coin, f.event) f.rate }

/-- First index in a sorted array whose element satisfies `p` (monotone): Rust's partition_point. -/
def partitionPoint (xs : Array Int) (p : Int → Bool) : Nat := (xs.findIdx? (!p ·)).getD xs.size

/-- A held coin's latest bar opened by t, keyed by the coin. -/
def latestOf (ix : Index α) (bars : Array (BarRow α)) (t : Int) (x : Nat × α) : Option (Nat × BarRow α) :=
  if (partitionPoint ix.barTimes[x.1]! (fun u => decide (u ≤ t)) == 0) = true then none
  else some (x.1, bars[ix.barAt[(x.1, ix.barTimes[x.1]![(partitionPoint ix.barTimes[x.1]! fun u => decide (u ≤ t)) - 1]!)]!]!)

/-- I2 and I3 (and the I9 order cap) for one fill, recomputed from the source bars. -/
def checkFill (f : Fill α) (m : Market α) (ix : Index α) (v : Venue α) : Except Abort Unit := do
  if !(f.inputsKnown ≤ f.decided && f.decided ≤ f.submitted && f.submitted ≤ f.filled) then throw .timing
  let some bi := ix.barAt[(f.coin, f.sourceOpen)]? | throw .fill
  let bar := m.bars[bi]!
  let fee := N.mul (N.mul (N.abs f.qty) f.price) v.takerFee
  let priced := !N.isZero f.qty && N.eq f.price (fillPrice N v f.coin f.qty f.reference) && N.eq f.fee fee
  let times := ix.barTimes[f.coin]!
  let ok := match f.why with
    | .fill =>
      let first := times[partitionPoint times (· < f.submitted)]?
      first == some bar.openTime && bar.openTime ≤ f.filled && bar.trades ≥ 1 && N.eq f.reference bar.o
    | w =>
      let latest := times.reverse.find? fun t => m.bars[ix.barAt[(f.coin, t)]!]!.event ≤ f.filled
      let reference := if w == .delisting then bar.c else if N.lt N.zero f.qty then bar.h else bar.l
      latest == some bar.openTime && N.eq f.reference reference
  if !(ok && priced) then throw .fill
  if f.why == .fill && N.lt (N.mul (maxOrderNotional N) (N.add N.one (N.ofBits 0x3D719799812DEA11))) (N.mul (N.abs f.qty) f.decisionPrice) then
    throw .portfolio

structure Order (α : Type) where
  coin : Nat
  qty : α
  price : α
  inputsKnown : Int
  decided : Int

structure SState (α : Type) where
  machine : MState α
  book : Book α
  marks : Array α
  trace : Array (Event α)
  orders : List (Int × Order α)
  returns : Array α
  gross : Array α
  equity : Array α
  prevEquity : α
  prevCosts : α
  fi : Nat
  bi : Nat
  ei : Nat

/-- Lexicographic order (≤) on equal-length integer keys. -/
def lexLe : List Int → List Int → Bool
  | a :: as, b :: bs => a < b || (a == b && lexLe as bs)
  | _, _ => true

/-- Everything a run fixes before its first step. -/
structure Ctx (α : Type) where
  p : Program
  m : Market α
  v : Venue α
  pol : Policy
  stop : Int
  ix : Index α
  fOrder : Array Nat
  bOrder : Array Nat
  eOrder : Array Nat

def Ctx.make (p : Program) (m : Market α) (v : Venue α) (pol : Policy) (stop : Int) : Ctx α :=
  { p, m, v, pol, stop, ix := m.index m.intervals.size
    fOrder := (Array.range m.funding.size).mergeSort fun i j =>
      let a := m.funding[i]!; let b := m.funding[j]!
      lexLe [a.known, a.coin, a.event] [b.known, b.coin, b.event]
    bOrder := (Array.range m.bars.size).mergeSort fun i j =>
      let a := m.bars[i]!; let b := m.bars[j]!
      lexLe [a.known, a.coin, a.event] [b.known, b.coin, b.event]
    eOrder := (Array.range m.events.size).filter (m.bound.contains m.events[·]!.slot) |>.mergeSort fun i j =>
      let a := m.events[i]!; let b := m.events[j]!
      lexLe [a.known, a.coin, a.slot, i] [b.known, b.coin, b.slot, j] }

def Ctx.coins (c : Ctx α) : Nat := c.m.intervals.size

def Ctx.listed (c : Ctx α) (coin : Nat) (t : Int) : Bool := c.m.intervals[coin]!.1 ≤ t && t < c.m.intervals[coin]!.2

def Ctx.mask (c : Ctx α) (t : Int) : Array Bool := (Array.range c.coins).map (c.listed · t)

def Ctx.deliverFunding (c : Ctx α) (s : SState α) (tick : Int) : Except Abort (SState α) :=
  if h : s.fi < c.fOrder.size then
    let f := c.m.funding[c.fOrder[s.fi]]!
    if f.known > tick then .ok s else
    match s.machine.deliverFunding f tick with
    | .error _ => .error .causality
    | .ok mach => c.deliverFunding { s with machine := mach, fi := s.fi + 1 } tick
  else .ok s
termination_by c.fOrder.size - s.fi

def Ctx.deliverBars (c : Ctx α) (s : SState α) (tick : Int) : Except Abort (SState α) :=
  if h : s.bi < c.bOrder.size then
    let b := c.m.bars[c.bOrder[s.bi]]!
    if b.known > tick then .ok s else
    match s.machine.deliverBar b tick with
    | .error _ => .error .causality
    | .ok mach => c.deliverBars { s with machine := mach, bi := s.bi + 1 } tick
  else .ok s
termination_by c.bOrder.size - s.bi

def Ctx.deliverEvents (c : Ctx α) (s : SState α) (tick : Int) : Except Abort (SState α) :=
  if h : s.ei < c.eOrder.size then
    let e := c.m.events[c.eOrder[s.ei]]!
    if e.known > tick then .ok s else
    match s.machine.deliverEvent e tick with
    | .error _ => .error .causality
    | .ok mach => c.deliverEvents { s with machine := mach, ei := s.ei + 1 } tick
  else .ok s
termination_by c.eOrder.size - s.ei

/-- Deliver every row known by `tick` that has not been delivered yet: funding, then bars, then
events, each in delivery order (SEMANTICS.md §3). -/
def Ctx.deliver (c : Ctx α) (s : SState α) (tick : Int) : Except Abort (SState α) := do
  let s ← c.deliverFunding s tick
  let s ← c.deliverBars s tick
  c.deliverEvents s tick

def Ctx.execute (c : Ctx α) (s : SState α) (f : Fill α) : Except Abort (SState α) := do
  checkFill N f c.m c.ix c.v
  let book := s.book.fill N f.coin f.qty f.price f.fee
  return { s with book := { book with slippage := N.add book.slippage (N.mul f.qty (N.sub f.price f.reference)) },
                  trace := s.trace.push (.fill f) }

def Ctx.closeout (c : Ctx α) (coin : Nat) (qty ref : α) (why : Why) (t sourceOpen : Int) : Fill α :=
  let price := fillPrice N c.v coin qty ref
  { why, coin, qty, inputsKnown := t, decisionPrice := ref, decided := t, submitted := t, filled := t, sourceOpen,
    reference := ref, price, fee := N.mul (N.mul (N.abs qty) price) c.v.takerFee }

/-- Bankruptcy (SEMANTICS.md §7, item 5): unless equity is positive, every position still held is liquidated
at its adverse price and the venue absorbs the negative balance. -/
def Ctx.bankrupt (c : Ctx α) (s : SState α) (b : Int) (adverse : Nat → α → α) (latest : List (Nat × BarRow α)) :
    Except Abort (SState α) := do
  if N.lt N.zero (s.book.equity N s.marks) then return s
  let mut t := s
  for (coin, q) in s.book.pos do
    t ← c.execute N t (c.closeout N coin (N.neg q) (adverse coin q) .liquidation (b + BAR) (assoc? latest coin).get!.openTime)
  return { t with book := t.book.absorb N }

/-- Whether every event source the program reads is bound (SEMANTICS.md §8). -/
def Ctx.bound (c : Ctx α) : Bool := !c.p.eventSlots.any (!c.m.bound.contains ·)

/-- The state before any delivery. -/
def Ctx.state0 (c : Ctx α) : SState α :=
  let book0 : Book α :=
    { cash := initial N, pos := [], entry := [], realized := N.zero, fees := N.zero, slippage := N.zero, funding := N.zero,
      absorbed := N.zero }
  { machine := MState.init N c.p c.coins, book := book0, marks := Array.replicate c.coins (N.div N.zero N.zero),
    trace := #[], orders := [], returns := #[], gross := #[], equity := #[], prevEquity := initial N,
    prevCosts := N.zero, fi := 0, bi := 0, ei := 0 }

/-- The binding preflight, then the first delivery and tick (SEMANTICS.md §4, §8). -/
def Ctx.start (c : Ctx α) : Except Abort (SState α) := do
  if !c.bound then throw .inputUnavailable
  let s ← c.deliver (c.state0 N) (c.pol.wStart + c.pol.delta)
  return { s with machine := s.machine.tick N c.p (c.mask c.pol.wStart) c.pol.wStart }

/-- I5: the two equities agree within 1e-9 of max(|e1|, 10,000); a non-finite e1 fails. -/
def accountingOk (N : NumOps α) (e1 e2 : α) : Bool :=
  let scale := if N.lt (N.abs e1) (N.ofNat 10000) then N.ofNat 10000 else N.abs e1
  N.le (N.div (N.abs (N.sub e1 e2)) scale) (N.ofBits 0x3E112E0BE826D695)

/-- One 4h step from b (SEMANTICS.md §7, items 1 to 9). -/
def Ctx.step (c : Ctx α) (s : SState α) (b : Int) : Except Abort (SState α) := do
  let p := c.p
  let m := c.m
  let v := c.v
  let pol := c.pol
  let stop := c.stop
  let ix := c.ix
  let coins := c.coins
  let mask := c.mask
  let deliver := c.deliver
  let execute := c.execute N
  let closeout := c.closeout N
  let mut s := s
  -- 1. funding
  for k in [1:5] do
    let h := b + k * HOUR
    for x in s.book.pos do
      let coin := x.1
      match ix.rateAt[(coin, h)]?, latestOf ix m.bars h x with
      | some rate, some (_, bar) =>
        let price := bar.o
        let (book, paid) := s.book.settle N coin price rate
        s := { s with book, trace := s.trace.push (.funding h coin rate price paid) }
      | _, _ => throw .settlementMissing
  -- 2. marks
  let held := s.book.pos
  let latest : List (Nat × BarRow α) := held.filterMap (latestOf ix m.bars b)
  for (c, bar) in latest do
    s := { s with marks := s.marks.set! c bar.c }
  -- 3. margin
  let adverse (c : Nat) (q : α) : α := match assoc? latest c with
    | some bar => if N.lt N.zero q then bar.l else bar.h
    | none => s.marks[c]!
  let eqAdverse := N.add s.book.cash (total N (held.map fun (c, q) => N.mul q (adverse c q)))
  let maintenance := total N (held.map fun (c, q) =>
    N.div (N.mul (N.abs q) (adverse c q)) (N.mul (N.ofNat 2) v.minTierLeverage[c]!))
  if !held.isEmpty && N.lt eqAdverse maintenance then
    for (c, q) in held do
      s ← execute s (closeout c (N.neg q) (adverse c q) .liquidation (b + BAR) (assoc? latest c).get!.openTime)
  -- 4. delisting
  for (c, q) in s.book.pos do
    if b + BAR ≥ m.intervals[c]!.2 then
      s ← execute s (closeout c (N.neg q) s.marks[c]! .delisting (b + BAR) (assoc? latest c).get!.openTime)
  -- 5. bankruptcy
  s ← c.bankrupt N s b adverse latest
  -- 6. accounting
  let e1 := s.book.equity N s.marks
  let e2 := s.book.reconciled N s.marks
  if !accountingOk N e1 e2 then throw .accounting
  let costs := N.add s.book.fees s.book.slippage
  let (r, g) := if N.lt N.zero s.prevEquity then
      (if N.lt N.zero e1 then N.sub (N.div e1 s.prevEquity) N.one else N.neg N.one, N.div (N.sub (N.add (N.sub e1 s.prevEquity) costs) s.prevCosts) s.prevEquity)
    else (N.zero, N.zero)
  if !N.le (N.neg N.one) r then throw .bound
  s := { s with trace := s.trace.push (.equity (b + BAR) e1 e2), returns := s.returns.push r, gross := s.gross.push g,
                equity := s.equity.push e1, prevEquity := e1, prevCosts := costs }
  -- 7. fills
  let due := (s.orders.filter (·.1 == b + BAR)).map (·.2)
  s := { s with orders := s.orders.filter (·.1 != b + BAR) }
  if b + 3 * BAR ≤ stop then
    for o in due do
      match ix.barAt[(o.coin, b + BAR)]? with
      | some i =>
        let bar := m.bars[i]!
        if bar.trades ≥ 1 && N.lt N.zero e1 then
          let price := fillPrice N v o.coin o.qty bar.o
          let f : Fill α := {
            why := .fill
            coin := o.coin
            qty := o.qty
            inputsKnown := o.inputsKnown
            decisionPrice := o.price
            decided := o.decided
            submitted := o.decided
            filled := b + BAR
            sourceOpen := b + BAR
            reference := bar.o
            price := price
            fee := N.mul (N.mul (N.abs o.qty) price) v.takerFee }
          s ← execute s f
        else s := { s with trace := s.trace.push (.unfilled (b + BAR) o.coin o.qty) }
      | none => s := { s with trace := s.trace.push (.unfilled (b + BAR) o.coin o.qty) }
  -- 8. ticks
  for k in [1:5] do
    let h := b + k * HOUR
    s ← deliver s (h + pol.delta)
    s := { s with machine := s.machine.tick N p (mask h) h }
  -- 9. decision
  let bigB := b + BAR
  let td := bigB + pol.delta
  let mut weights : List (Nat × α) := []
  for c in [0:coins] do
    let (start, stop') := m.intervals[c]!
    if !(start ≤ bigB && bigB + 2 * BAR ≤ stop') then continue
    let fresh := (s.machine.funding[c]!.map (·.event == bigB)).getD false && (s.machine.bar[c]!.map (·.event == bigB)).getD false
    if !fresh then
      s := { s with trace := s.trace.push (.hold td c "stale") }
      continue
    match s.machine.vals[p.weight]![c]! with
    | some w => weights := weights ++ [(c, w)]
    | none => s := { s with trace := s.trace.push (.hold td c "undefined") }
  let largest := weights.foldl (fun a (_, w) => N.max a (N.abs w)) N.zero
  let relative := total N (weights.map fun (_, w) => N.div (N.abs w) largest)
  let scaled (w : α) : α := if N.lt (maxGross N) (N.mul relative largest) then N.mul (N.div w largest) (N.div (maxGross N) relative) else w
  let gross := total N (weights.map fun (_, w) => N.abs (scaled w))
  if !(N.le gross (N.mul (maxGross N) (N.add N.one (N.ofBits 0x3D719799812DEA11)))) then throw .portfolio
  for (c, w) in weights do
    let w := scaled w
    let price := s.machine.bar[c]!.get!.c
    let held := (assoc? s.book.pos c).getD N.zero
    let dec := v.szDecimals[c]!
    let mut qty := if N.isZero w then N.neg held else truncate N (N.sub (N.div (N.mul w e1) price) held) dec
    if N.lt (maxOrderNotional N) (N.mul (N.abs qty) price) then
      qty := N.mul (N.signum qty) (truncate N (N.div (maxOrderNotional N) price) dec)
    if !N.isZero qty && (N.le v.minNotional (N.mul (N.abs qty) price) || N.isZero w) then
      s := { s with trace := s.trace.push (.decision td c w qty),
                    orders := s.orders ++ [(bigB + BAR, ⟨c, qty, price, s.machine.maxKnown, td⟩)] }
  return s

/-- The step boundaries of a run: b = wStart, wStart + BAR, … while b + 2·BAR ≤ stop. -/
def Ctx.bounds (c : Ctx α) : List Int :=
  (List.range (((c.stop - c.pol.wStart) / BAR).toNat + 1)).filterMap fun (k : Nat) =>
    let b := c.pol.wStart + (k : Int) * BAR
    if b + 2 * BAR ≤ c.stop then some b else none

/-- The state after the first k steps (or the abort). -/
def Ctx.steps (c : Ctx α) (k : Nat) : Except Abort (SState α) := do
  let mut s ← c.start N
  for b in c.bounds.take k do
    s ← c.step N s b
  return s

/-- The run (SEMANTICS.md §7): its trace and returns, or the abort. -/
def run (p : Program) (m : Market α) (v : Venue α) (pol : Policy) (stop : Int) : Except Abort (Run α) := do
  let c := Ctx.make p m v pol stop
  let s ← c.steps N c.bounds.length
  return { trace := s.trace, returns := s.returns, grossReturns := s.gross, equity := s.equity }

end Ref
