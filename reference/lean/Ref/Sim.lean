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

structure Venue (α : Type) where
  takerFee : α
  minNotional : α
  szDecimals : Array Nat
  minTierLeverage : Array α
  /-- [coin][buy = 0, sell = 1][≤ $1k = 0, ≤ $10k = 1] bps. -/
  costBps : Array (Array (Array α))

structure Policy where
  delta : Int
  wStart : Int

/-- The tick offset is inside the hour. -/
def Policy.valid (pol : Policy) : Bool := 0 < pol.delta && pol.delta < HOUR

structure Run (α : Type) where
  trace : Array (Event α)
  returns : Array α
  grossReturns : Array α
  equity : Array α

variable {α : Type} [Inhabited α] (N : NumOps α)

def initial : α := N.ofNat 10000
def maxGross : α := N.ofNat 2
def maxOrderNotional : α := N.ofNat 10000

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

def Index.of (bars : Array (BarRow α)) (rates : Array (RateRow α)) (coins : Nat) : Index α :=
  { barAt := bars.foldl (init := (HashMap.emptyWithCapacity, 0)) (fun (h, i) b => (h.insert (b.coin, b.openTime) i, i + 1)) |>.1
    barTimes := (Array.range coins).map fun c => ((bars.filter (·.coin == c)).map (·.openTime)).mergeSort (· ≤ ·)
    rateAt := rates.foldl (init := HashMap.emptyWithCapacity) fun h f => h.insert (f.coin, f.event) f.rate }

/-- First index in a sorted array whose element satisfies `p` (monotone): Rust's partition_point. -/
def partitionPoint (xs : Array Int) (p : Int → Bool) : Nat := (xs.findIdx? (!p ·)).getD xs.size

/-- A held coin's latest bar opened by t, keyed by the coin. -/
def latestOf (ix : Index α) (bars : Array (BarRow α)) (t : Int) (x : Nat × α) : Option (Nat × BarRow α) :=
  if (partitionPoint ix.barTimes[x.1]! (fun u => decide (u ≤ t)) == 0) = true then none
  else some (x.1, bars[ix.barAt[(x.1, ix.barTimes[x.1]![(partitionPoint ix.barTimes[x.1]! fun u => decide (u ≤ t)) - 1]!)]!]!)

/-- I2 and I3 (and the I9 order cap) for one fill, recomputed from the source bars. -/
def checkFill (f : Fill α) (bars : Array (BarRow α)) (ix : Index α) (v : Venue α) : Except Abort Unit := do
  if !(f.inputsKnown ≤ f.decided && f.decided ≤ f.submitted && f.submitted ≤ f.filled) then throw .timing
  let some bi := ix.barAt[(f.coin, f.sourceOpen)]? | throw .fill
  let bar := bars[bi]!
  let fee := N.mul (N.mul (N.abs f.qty) f.price) v.takerFee
  let priced := !N.isZero f.qty && N.eq f.price (fillPrice N v f.coin f.qty f.reference) && N.eq f.fee fee
  let times := ix.barTimes[f.coin]!
  let ok := match f.why with
    | .fill =>
      let first := times[partitionPoint times (· < f.submitted)]?
      first == some bar.openTime && bar.openTime ≤ f.filled && bar.trades ≥ 1 && N.eq f.reference bar.o
    | w =>
      let latest := times.reverse.find? fun t => bars[ix.barAt[(f.coin, t)]!]!.event ≤ f.filled
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
  /-- The largest |equity| reached at an earlier step (I5's scale, revision of 2026-10-27). -/
  peak : α
  /-- Observations delivered so far, as a position in the delivery order. -/
  oi : Nat

/-- Lexicographic order (≤) on equal-length integer keys. -/
def lexLe : List Int → List Int → Bool
  | a :: as, b :: bs => a < b || (a == b && lexLe as bs)
  | _, _ => true

/-- The bars provider's final role records, as execution reads them (venue state: the key's last revision). -/
def barRow (roles : Roles) (o : Obs α) : Option (BarRow α) := match o.role with
  | some (.bar op h l cl tr) =>
    if o.source == roles.bars && o.final then some ⟨o.coin, o.key - BAR, o.key, o.known, op, h, l, cl, tr⟩ else none
  | _ => none

/-- The settlement provider's final role records, as execution reads them. -/
def rateRow (roles : Roles) (o : Obs α) : Option (RateRow α) := match o.role with
  | some (.rate x) => if o.source == roles.settlement && o.final then some ⟨o.coin, o.key, o.known, x⟩ else none
  | _ => none

/-- Everything a run fixes before its first step. -/
structure Ctx (α : Type) where
  reg : Registry
  roles : Roles
  p : Program
  adm : Meta
  v : Venue α
  pol : Policy
  stop : Int
  required : List Nat
  obs : Array (Obs α)
  oOrder : Array Nat
  bars : Array (BarRow α)
  rates : Array (RateRow α)
  ix : Index α

/-- The delivered observations in order (knownAt, source, coin, tie), the tie being (event time, recording time) for
a held source, version 1's, and (recording time, event time) for an event source, version 1's array order on an
append-ordered store; it depends on the observations, never on stored row order. -/
def Ctx.make (reg : Registry) (roles : Roles) (p : Program) (adm : Meta) (resolved : Array (Obs α)) (v : Venue α)
    (pol : Policy) (stop : Int) (required : List Nat) : Ctx α :=
  let delivered := adm.delivered reg
  let obs := resolved.filter (delivered.contains ·.source)
  let tie (o : Obs α) : List Int :=
    if (reg.decls[o.source]!).cadence == .event then [o.recorded, o.key] else [o.key, o.recorded]
  let bars := obs.filterMap (barRow roles)
  let rates := obs.filterMap (rateRow roles)
  { reg, roles, p, adm, v, pol, stop, required, obs, bars, rates, ix := Index.of bars rates adm.intervals.size
    oOrder := (Array.range obs.size).mergeSort fun i j =>
      let x := obs[i]!; let y := obs[j]!
      lexLe ([x.known, x.source, x.coin] ++ tie x ++ [(i : Int)]) ([y.known, y.source, y.coin] ++ tie y ++ [(j : Int)]) }

def Ctx.coins (c : Ctx α) : Nat := c.adm.intervals.size

def Ctx.listed (c : Ctx α) (coin : Nat) (t : Int) : Bool := c.adm.intervals[coin]!.1 ≤ t && t < c.adm.intervals[coin]!.2

def Ctx.mask (c : Ctx α) (t : Int) : Array Bool := (Array.range c.coins).map (c.listed · t)

/-- Deliver every observation known by `tick` not delivered yet, in delivery order (SEMANTICS.md §3). -/
def Ctx.deliver (c : Ctx α) (s : SState α) (tick : Int) : Except Abort (SState α) :=
  if h : s.oi < c.oOrder.size then
    let o := c.obs[c.oOrder[s.oi]]!
    if o.known > tick then .ok s else
    match s.machine.deliver o tick with
    | .error _ => .error .causality
    | .ok mach => c.deliver { s with machine := mach, oi := s.oi + 1 } tick
  else .ok s
termination_by c.oOrder.size - s.oi

def Ctx.execute (c : Ctx α) (s : SState α) (f : Fill α) : Except Abort (SState α) := do
  checkFill N f c.bars c.ix c.v
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

/-- The state before any delivery. -/
def Ctx.state0 (c : Ctx α) : SState α :=
  let book0 : Book α :=
    { cash := initial N, pos := [], entry := [], realized := N.zero, fees := N.zero, slippage := N.zero, funding := N.zero,
      absorbed := N.zero }
  { machine := MState.init N c.p c.reg.decls.size c.coins, book := book0, marks := Array.replicate c.coins (N.div N.zero N.zero),
    trace := #[], orders := [], returns := #[], gross := #[], equity := #[], prevEquity := initial N,
    prevCosts := N.zero, peak := N.zero, oi := 0 }

/-- The first delivery and tick (SEMANTICS.md §4). -/
def Ctx.start (c : Ctx α) : Except Abort (SState α) := do
  let s ← c.deliver (c.state0 N) (c.pol.wStart + c.pol.delta)
  return { s with machine := s.machine.tick N c.p (c.mask c.pol.wStart) c.pol.wStart }

/-- I5: the two equities agree within 1e-9 of max(10,000, |e1|, `peak`), `peak` being the largest |e1| reached at an
earlier step (revision of 2026-10-27); a non-finite e1 fails. -/
def accountingOk (N : NumOps α) (e1 e2 peak : α) : Bool :=
  let scale := N.max (N.max (N.ofNat 10000) (N.abs e1)) peak
  N.le (N.div (N.abs (N.sub e1 e2)) scale) (N.ofBits 0x3E112E0BE826D695)

/-- One 4h step from b (SEMANTICS.md §7, items 1 to 9). -/
def Ctx.step (c : Ctx α) (s : SState α) (b : Int) : Except Abort (SState α) := do
  let p := c.p
  let adm := c.adm
  let roles := c.roles
  let bars := c.bars
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
    for x in s.book.pos.filter (c.listed ·.1 h) do
      let coin := x.1
      match ix.rateAt[(coin, h)]?, latestOf ix bars h x with
      | some rate, some (_, bar) =>
        let price := bar.o
        let (book, paid) := s.book.settle N coin price rate
        s := { s with book, trace := s.trace.push (.funding h coin rate price paid) }
      | _, _ => throw .settlementMissing
  -- 2. marks
  let held := s.book.pos
  let latest : List (Nat × BarRow α) := held.filterMap (latestOf ix bars b)
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
    if b + BAR ≥ adm.intervals[c]!.2 then
      s ← execute s (closeout c (N.neg q) s.marks[c]! .delisting (b + BAR) (assoc? latest c).get!.openTime)
  -- 5. bankruptcy
  s ← c.bankrupt N s b adverse latest
  -- 6. accounting
  let e1 := s.book.equity N s.marks
  let e2 := s.book.reconciled N s.marks
  if !accountingOk N e1 e2 s.peak then throw .accounting
  let costs := N.add s.book.fees s.book.slippage
  let (r, g) := if N.lt N.zero s.prevEquity then
      (if N.lt N.zero e1 then N.sub (N.div e1 s.prevEquity) N.one else N.neg N.one, N.div (N.sub (N.add (N.sub e1 s.prevEquity) costs) s.prevCosts) s.prevEquity)
    else (N.zero, N.zero)
  if !N.le (N.neg N.one) r then throw .bound
  s := { s with trace := s.trace.push (.equity (b + BAR) e1 e2), returns := s.returns.push r, gross := s.gross.push g,
                equity := s.equity.push e1, prevEquity := e1, prevCosts := costs, peak := N.max s.peak (N.abs e1) }
  -- 7. fills
  let due := (s.orders.filter (·.1 == b + BAR)).map (·.2)
  s := { s with orders := s.orders.filter (·.1 != b + BAR) }
  if b + 3 * BAR ≤ stop then
    for o in due do
      match ix.barAt[(o.coin, b + BAR)]? with
      | some i =>
        let bar := bars[i]!
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
    let (start, stop') := adm.intervals[c]!
    if !(start ≤ bigB && bigB + 2 * BAR ≤ stop') then continue
    let latestOf' (src : Nat) : Option (Obs α) := s.machine.latest[src]![c]!
    let fresh := ((latestOf' roles.bars).map (fun o => o.key == bigB && o.role.isSome)).getD false &&
      ((latestOf' roles.settlement).map (fun o => o.key == bigB && o.role.isSome)).getD false
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
    let price := match (s.machine.latest[roles.bars]![c]!).bind (·.role) with
      | some (.bar _ _ _ cl _) => cl
      | _ => N.zero
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

/-- Evaluation (SEMANTICS.md §7): its trace and returns, or the abort. -/
def Ctx.evaluate (c : Ctx α) : Except Abort (Run α) := do
  let s ← c.steps N c.bounds.length
  return { trace := s.trace, returns := s.returns, grossReturns := s.gross, equity := s.equity }

def Ctx.firstTick (c : Ctx α) : Int := c.pol.wStart + c.pol.delta
def Ctx.lastTick (c : Ctx α) : Int := c.pol.wStart + (c.bounds.length : Int) * BAR + c.pol.delta
/-- The end of every use interval: `stop`, or past the first tick, which `start` always runs. -/
def Ctx.useEnd (c : Ctx α) : Int := max c.stop (c.firstTick + 1)

/-- Run admission on resolved observations (R_BINDING), version 1's structural conditions: one final record per key;
declaration and coin in range; one value per field; a role payload exactly on the providers' records that are not
retractions, of the provider's kind; a slot exactly on event sources' records. It reads no value. -/
def Ctx.admissible (c : Ctx α) : Bool :=
  let keys := (c.obs.toList.filter (·.final)).map fun o => (o.source, o.coin, o.key)
  let capable (o : Obs α) (r : Role) := (c.reg.decls[o.source]!).roles.any (·.1 == r)
  let roleOk (o : Obs α) : Bool := match o.role with
    | none => o.retraction || (c.reg.decls[o.source]!).roles.isEmpty
    | some (.bar ..) => capable o .bars && !o.retraction
    | some (.rate _) => capable o .settlement && !o.retraction
  keys.eraseDups.length == keys.length &&
  c.obs.all fun o =>
    o.source < c.reg.decls.size && o.coin < c.coins && o.vals.size == (c.reg.decls[o.source]!).fields.size &&
    roleOk o && ((c.reg.decls[o.source]!).cadence == .event) == o.slot.isSome

/-- When the run first reads an observation: from delivery (or the first tick, for one carried in), or from
execution's read of a role record by open or event time, whichever is earlier and before `useEnd`. -/
def Ctx.readFrom (c : Ctx α) (o : Obs α) : Option Int :=
  let delivered := if o.known ≤ c.lastTick then some (max o.known c.firstTick) else none
  let executed := (if !o.final then none else match o.role with
    | some (.bar ..) => if o.source == c.roles.bars then some (o.key - BAR) else none
    | some (.rate _) => if o.source == c.roles.settlement then some o.key else none
    | none => none).filter (· < c.useEnd)
  match delivered, executed with
  | some a, some b => some (max (min a b) c.firstTick)
  | some a, none => some (max a c.firstTick)
  | none, some b => some (max b c.firstTick)
  | none, none => none

/-- Every value column the run uses, with its use interval: each read observation's value columns from its first
read to `useEnd`. Control columns are authorized by the certificates' `controls` (stage 1). -/
def Ctx.accesses (c : Ctx α) : List (Nat × Access) :=
  c.obs.toList.flatMap fun o => match c.readFrom o with
    | none => []
    | some t => (c.reg.decls[o.source]!).values.map fun col => (o.source, ⟨o.coin, col, o.key, (t, c.useEnd)⟩)

def Ctx.inScope (c : Ctx α) : Bool :=
  c.accesses.all fun (s, x) => match c.adm.bindings s with
    | none => false
    | some b => (c.adm.cert b.cert).any fun k => k.grants.any (·.covers x)

/-- Admission (laws-v2-draft.md §4): metadata checks, I8 on event times, resolution, run admission and scope. -/
def admit (reg : Registry) (roles : Roles) (p : Program) (adm : Meta) (ld : Loader α) (v : Venue α) (pol : Policy)
    (stop : Int) (mode : Mode) : Except Abort (Ctx α) := do
  let req ← stage1 reg roles p adm mode
  stage2 adm mode (ld.rows req)
  let some obs := ld.resolve req | throw .binding
  let c := Ctx.make reg roles p adm obs v pol stop req
  if !c.admissible then throw .binding
  if !c.inScope then throw .uncertified
  return c

def runProgram (reg : Registry) (roles : Roles) (p : Program) (adm : Meta) (ld : Loader α) (v : Venue α)
    (pol : Policy) (stop : Int) (mode : Mode) : Except Abort (Run α) := do
  (← admit reg roles p adm ld v pol stop mode).evaluate N

/-- The run from the program's text: a valid registry and policy, the checker, admission, evaluation. -/
def run (reg : Registry) (roles : Roles) (text : String) (adm : Meta) (ld : Loader α) (v : Venue α) (pol : Policy)
    (stop : Int) (mode : Mode) : Except Abort (Run α) := do
  if !reg.valid || !pol.valid then throw .invalid
  let p ← (check reg.inputs text).mapError fun _ => .invalid
  runProgram N reg roles p adm ld v pol stop mode

end Ref
