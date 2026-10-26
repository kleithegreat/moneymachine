import Fast.Machine

/-!
The simulation loop of Ref/Sim.lean, on the fast machine: positions and entries as arrays by coin (a coin is
held when its position is nonzero, as the reference keeps exactly the nonzero positions in its association
list, and iterating coins in order is iterating that sorted list), market lookups by binary search, and the
same floating-point operations in the same order.
-/

namespace Fast
open Ref

def initial : Float := Float.ofNat 10000
def maxGross : Float := Float.ofNat 2
def maxOrderNotional : Float := Float.ofNat 10000
def EPS : Float := Float.ofBits 0x3D719799812DEA11

structure F where
  why : Why
  coin : Nat
  qty : Float
  inputsKnown : Int64
  decisionPrice : Float
  decided : Int64
  submitted : Int64
  filled : Int64
  sourceOpen : Int64
  reference : Float
  price : Float
  fee : Float

inductive Ev where
  | decision (t : Int64) (coin : Nat) (weight qty : Float)
  | hold (t : Int64) (coin : Nat) (stale : Bool)
  | fill (f : F)
  | unfilled (t : Int64) (coin : Nat) (qty : Float)
  | funding (t : Int64) (coin : Nat) (rate price paid : Float)
  | equity (t : Int64) (equity reconciled : Float)

def Ev.toRef : Ev → Ref.Event Float
  | .decision t c w q => .decision t.toInt c w q
  | .hold t c stale => .hold t.toInt c (if stale then "stale" else "undefined")
  | .fill f => .fill
    { why := f.why, coin := f.coin, qty := f.qty, inputsKnown := f.inputsKnown.toInt,
      decisionPrice := f.decisionPrice, decided := f.decided.toInt, submitted := f.submitted.toInt,
      filled := f.filled.toInt, sourceOpen := f.sourceOpen.toInt, reference := f.reference, price := f.price, fee := f.fee }
  | .unfilled t c q => .unfilled t.toInt c q
  | .funding t c r p paid => .funding t.toInt c r p paid
  | .equity t e r => .equity t.toInt e r

/-- How many of `rows` (sorted by open time) open by `t`, or (`strict`) before it: Rust's partition_point. -/
def openCount (rows : Array BRow) (t : Int64) (strict : Bool) (lo hi : Nat) : Nat :=
  if lo < hi then
    let mid := (lo + hi) / 2
    let x := rows[mid]!.openTime
    if (if strict then x < t else x ≤ t) then openCount rows t strict (mid + 1) hi else openCount rows t strict lo mid
  else lo
termination_by hi - lo

/-- How many of `rows` (sorted by event time) have their event by `t`. -/
def eventCount (rows : Array FRow) (t : Int64) (lo hi : Nat) : Nat :=
  if lo < hi then
    let mid := (lo + hi) / 2
    if rows[mid]!.event ≤ t then eventCount rows t (mid + 1) hi else eventCount rows t lo mid
  else lo
termination_by hi - lo

/-- The bar of `coin` opening at `t` (the reference's `barAt`), as its index in `barsBy[coin]`, or none. -/
@[inline] def Cx.barAt (cx : Cx) (coin : Nat) (t : Int64) : Option Nat :=
  let rows := cx.barsBy[coin]!
  let k := openCount rows t false 0 rows.size
  if k > 0 && rows[k - 1]!.openTime == t then some (k - 1) else none

@[inline] def Cx.rateAt (cx : Cx) (coin : Nat) (t : Int64) : Option Nat :=
  let rows := cx.fundBy[coin]!
  let k := eventCount rows t 0 rows.size
  if k > 0 && rows[k - 1]!.event == t then some (k - 1) else none

@[inline] def Cx.costBpsOf (cx : Cx) (coin : Nat) (qty ref : Float) : Float :=
  let side := if 0 < qty then 0 else 1
  let size := if qty.abs * ref ≤ Float.ofNat 1000 then 0 else 1
  cx.costBps[coin * 4 + side * 2 + size]!

@[inline] def Cx.fillPrice (cx : Cx) (coin : Nat) (qty ref : Float) : Float :=
  ref * (1 + (signum qty * cx.costBpsOf coin qty ref) / Float.ofNat 10000)

def truncate (x : Float) (dec : Nat) : Float :=
  let f := Float.ofNat (10 ^ dec)
  trunc (x * f) / f

structure Book where
  cash : Float
  pos : FloatArray
  entry : FloatArray
  realized : Float
  fees : Float
  slippage : Float
  funding : Float
  absorbed : Float

def Book.fill (b : Book) (coin : Nat) (qty price fee : Float) : Book :=
  let ⟨cash, pos, entry, realized, fees, slippage, funding, absorbed⟩ := b
  let old := pos[coin]!
  let new := old + qty
  let realized := if old != 0 && ((0 < old) != (0 < qty)) then
      let closed := fmin qty.abs old.abs * signum old
      realized + closed * (price - entry[coin]!)
    else realized
  let (pos, entry) := if new == 0 then (pos.set! coin 0, entry.set! coin 0) else
    let entry := if old == 0 || ((0 < old) != (0 < new)) then entry.set! coin price
      else if (0 < old) == (0 < qty) then entry.set! coin ((old * entry[coin]! + qty * price) / new)
      else entry
    (pos.set! coin new, entry)
  { cash := cash - (qty * price + fee), pos, entry, realized, fees := fees + fee, slippage, funding, absorbed }

def Book.equity (b : Book) (marks : FloatArray) : Float := Id.run do
  let mut acc : Float := -0.0
  for c in [0:b.pos.size] do
    let q := b.pos[c]!
    if q != 0 then acc := acc + q * marks[c]!
  return b.cash + acc

def Book.reconciled (b : Book) (marks : FloatArray) : Float := Id.run do
  let mut acc : Float := -0.0
  for c in [0:b.pos.size] do
    let q := b.pos[c]!
    if q != 0 then acc := acc + q * (marks[c]! - b.entry[c]!)
  return initial + b.realized + acc - b.fees + b.funding + b.absorbed

structure Ord where
  due : Int64
  coin : Nat
  qty : Float
  price : Float
  inputsKnown : Int64
  decided : Int64

structure S where
  m : M
  book : Book
  marks : FloatArray
  trace : Array Ev
  orders : Array Ord
  returns : FloatArray
  gross : FloatArray
  equity : FloatArray
  prevEquity : Float
  prevCosts : Float

/-- I2 and I3 (and the I9 order cap) for one fill (Ref `checkFill`). -/
def Cx.checkFill (cx : Cx) (f : F) : Except Abort Unit := do
  if !(f.inputsKnown ≤ f.decided && f.decided ≤ f.submitted && f.submitted ≤ f.filled) then throw .timing
  let rows := cx.barsBy[f.coin]!
  let some k := cx.barAt f.coin f.sourceOpen | throw .fill
  let bar := rows[k]!
  let fee := f.qty.abs * f.price * cx.takerFee
  let priced := f.qty != 0 && f.price == cx.fillPrice f.coin f.qty f.reference && f.fee == fee
  let ok := match f.why with
    | .fill =>
      let i := openCount rows f.submitted true 0 rows.size
      i < rows.size && rows[i]!.openTime == bar.openTime && bar.openTime ≤ f.filled && bar.trades ≥ 1 && f.reference == bar.o
    | w => Id.run do
      let mut latest : Option Int64 := none
      let mut i := rows.size
      while i > 0 do
        i := i - 1
        let t := rows[i]!.openTime
        let last := openCount rows t false 0 rows.size
        if rows[last - 1]!.event ≤ f.filled then
          latest := some t
          break
      let reference := if w == .delisting then bar.c else if 0 < f.qty then bar.h else bar.l
      return latest == some bar.openTime && f.reference == reference
  if !(ok && priced) then throw .fill
  if f.why == .fill && maxOrderNotional * (1 + EPS) < f.qty.abs * f.decisionPrice then throw .portfolio

def Cx.execute (cx : Cx) (book : Book) (trace : Array Ev) (f : F) : Except Abort (Book × Array Ev) := do
  cx.checkFill f
  let book := book.fill f.coin f.qty f.price f.fee
  return ({ book with slippage := book.slippage + f.qty * (f.price - f.reference) }, trace.push (.fill f))

def Cx.closeout (cx : Cx) (coin : Nat) (qty ref : Float) (why : Why) (t sourceOpen : Int64) : F :=
  let price := cx.fillPrice coin qty ref
  { why, coin, qty, inputsKnown := t, decisionPrice := ref, decided := t, submitted := t, filled := t, sourceOpen,
    reference := ref, price, fee := qty.abs * price * cx.takerFee }

def Cx.maskFrom (cx : Cx) (t : Int64) (c : Nat) (acc : Array Bool) : Array Bool :=
  if c < cx.coins then cx.maskFrom t (c + 1) (acc.push (cx.listFrom[c]! ≤ t && t < cx.listTo[c]!)) else acc
termination_by cx.coins - c

/-- Which coins are listed at t. -/
def Cx.mask (cx : Cx) (t : Int64) : Array Bool := cx.maskFrom t 0 (Array.emptyWithCapacity cx.coins)

/-- One 4h step from b (Ref `Ctx.step`, items 1 to 9). -/
def Cx.step (cx : Cx) (s : S) (b : Int64) : Except Abort S := do
  let ⟨m, book, marks, trace, orders, returns, gross, equity, prevEquity, prevCosts⟩ := s
  let mut m := m
  let mut book := book
  let mut marks := marks
  let mut trace := trace
  let coins := cx.coins
  -- 1. funding
  for k in [1:5] do
    let h := b + k.toInt64 * HOUR
    let held := book.pos
    for coin in [0:coins] do
      if held[coin]! == 0 then continue
      let hBar := let r := h % BAR; h - (if r < 0 then r + BAR else r)
      match cx.rateAt coin h, cx.barAt coin hBar with
      | some ri, some bi =>
        let rate := cx.fundBy[coin]![ri]!.rate
        let price := cx.barsBy[coin]![bi]!.o
        let paid := book.pos[coin]! * price * rate
        book := { book with cash := book.cash - paid, funding := book.funding - paid }
        trace := trace.push (.funding h coin rate price paid)
      | _, _ => pure ()
  -- 2. marks: `latest[c]` is 1 + the index of c's latest bar opening by b, 0 if c is not held or has none
  let held := book.pos
  let mut latest : Array Nat := Array.replicate coins 0
  for c in [0:coins] do
    if held[c]! == 0 then continue
    let rows := cx.barsBy[c]!
    let k := openCount rows b false 0 rows.size
    if k > 0 then
      latest := latest.set! c k
      marks := marks.set! c rows[k - 1]!.c
  let latestOpen (c : Nat) : Int64 := if latest[c]! == 0 then 0 else cx.barsBy[c]![latest[c]! - 1]!.openTime
  -- 3. margin
  let marks3 := marks
  let adverse (c : Nat) (q : Float) : Float :=
    if latest[c]! == 0 then marks3[c]! else
    let bar := cx.barsBy[c]![latest[c]! - 1]!
    if 0 < q then bar.l else bar.h
  let mut eqA : Float := -0.0
  let mut maint : Float := -0.0
  let mut any := false
  for c in [0:coins] do
    let q := held[c]!
    if q == 0 then continue
    any := true
    eqA := eqA + q * adverse c q
    maint := maint + q.abs * adverse c q / (Float.ofNat 2 * cx.minTierLeverage[c]!)
  if any && book.cash + eqA < maint then
    for c in [0:coins] do
      let q := held[c]!
      if q == 0 then continue
      let (b', t') ← cx.execute book trace (cx.closeout c (-q) (adverse c q) .liquidation (b + BAR) (latestOpen c))
      book := b'
      trace := t'
  -- 4. delisting
  let held := book.pos
  for c in [0:coins] do
    let q := held[c]!
    if q == 0 then continue
    if b + BAR ≥ cx.listTo[c]! then
      let (b', t') ← cx.execute book trace (cx.closeout c (-q) marks[c]! .delisting (b + BAR) (latestOpen c))
      book := b'
      trace := t'
  -- 5. bankruptcy
  if !(0 < book.equity marks) then
    let held := book.pos
    for c in [0:coins] do
      let q := held[c]!
      if q == 0 then continue
      let (b', t') ← cx.execute book trace (cx.closeout c (-q) (adverse c q) .liquidation (b + BAR) (latestOpen c))
      book := b'
      trace := t'
    book := { book with absorbed := book.absorbed - book.cash, cash := 0 }
  -- 6. accounting
  let e1 := book.equity marks
  let e2 := book.reconciled marks
  if !((e1 - e2).abs ≤ Float.ofBits 0x3EE4F8B588E368F1) then throw .accounting
  let costs := book.fees + book.slippage
  let (r, g) := if 0 < prevEquity then
      (if 0 < e1 then e1 / prevEquity - 1 else -1, (e1 - prevEquity + costs - prevCosts) / prevEquity)
    else (0, 0)
  if !(-1 ≤ r) then throw .bound
  trace := trace.push (.equity (b + BAR) e1 e2)
  -- 7. fills
  let due := orders.filter (·.due == b + BAR)
  let mut orders := orders.filter (·.due != b + BAR)
  if b + 3 * BAR ≤ cx.stop then
    for o in due do
      match cx.barAt o.coin (b + BAR) with
      | some i =>
        let bar := cx.barsBy[o.coin]![i]!
        if bar.trades ≥ 1 && 0 < e1 then
          let price := cx.fillPrice o.coin o.qty bar.o
          let f : F :=
            { why := .fill, coin := o.coin, qty := o.qty, inputsKnown := o.inputsKnown, decisionPrice := o.price,
              decided := o.decided, submitted := o.decided, filled := b + BAR, sourceOpen := b + BAR, reference := bar.o,
              price, fee := o.qty.abs * price * cx.takerFee }
          let (b', t') ← cx.execute book trace f
          book := b'
          trace := t'
        else trace := trace.push (.unfilled (b + BAR) o.coin o.qty)
      | none => trace := trace.push (.unfilled (b + BAR) o.coin o.qty)
  -- 8. ticks
  for k in [1:5] do
    let h := b + k.toInt64 * HOUR
    m := (m.deliver cx (h + cx.delta)).tick cx (cx.mask h) h
  -- 9. decision
  let bigB := b + BAR
  let td := bigB + cx.delta
  let mut wc : Array Nat := #[]
  let mut wv : FloatArray := .empty
  for c in [0:coins] do
    if !(cx.listFrom[c]! ≤ bigB && bigB + 2 * BAR ≤ cx.listTo[c]!) then continue
    let fk := m.funding[c]!
    let bk := m.bar[c]!
    let fresh := (fk != 0 && cx.fRows[fk - 1]!.event == bigB) && (bk != 0 && cx.bRows[bk - 1]!.event == bigB)
    if !fresh then
      trace := trace.push (.hold td c true)
      continue
    let w := m.val[cx.weight * coins + c]!
    if def? w then
      wc := wc.push c
      wv := wv.push w
    else trace := trace.push (.hold td c false)
  let largest := wv.foldl (fun a w => fmax a w.abs) 0
  let relative := wv.foldl (fun a w => a + w.abs / largest) (-0.0)
  let scale := maxGross < relative * largest
  let scaled (w : Float) : Float := if scale then w / largest * (maxGross / relative) else w
  let grossW := wv.foldl (fun a w => a + (scaled w).abs) (-0.0)
  if !(grossW ≤ maxGross * (1 + EPS)) then throw .portfolio
  for j in [0:wc.size] do
    let c := wc[j]!
    let w := scaled wv[j]!
    let price := cx.bRows[m.bar[c]! - 1]!.c
    let heldQ := book.pos[c]!
    let dec := cx.szDecimals[c]!
    let mut qty := if w == 0 then -heldQ else truncate (w * e1 / price - heldQ) dec
    if maxOrderNotional < qty.abs * price then
      qty := signum qty * truncate (maxOrderNotional / price) dec
    if qty != 0 && (cx.minNotional ≤ qty.abs * price || w == 0) then
      trace := trace.push (.decision td c w qty)
      orders := orders.push ⟨bigB + BAR, c, qty, price, m.maxKnown, td⟩
  return ⟨m, book, marks, trace, orders, returns.push r, gross.push g, equity.push e1, e1, costs⟩

/-- A loaded market: its rows with `Int64` times, its listing intervals and its venue (the reference's
`Market` and `Venue`, as the loader leaves them). -/
structure Mkt where
  fr : Array FRow
  br : Array BRow
  er : Array ERow
  bound : List Nat
  listFrom : Array Int64
  listTo : Array Int64
  takerFee : Float
  minNotional : Float
  szDecimals : Array Nat
  minTierLeverage : FloatArray
  costBps : FloatArray

def Mkt.ofRef (mk : Market Float) (v : Venue Float) : Mkt :=
  let coins := mk.intervals.size
  { fr := mk.funding.map fun f =>
      { coin := f.coin, event := .ofInt f.event, known := .ofInt f.known, rate := f.rate, premium := f.premium }
    br := mk.bars.map fun b =>
      { coin := b.coin, openTime := .ofInt b.openTime, event := .ofInt b.event, known := .ofInt b.known,
        o := b.o, h := b.h, l := b.l, c := b.c, v := b.v, trades := .ofInt b.trades }
    er := mk.events.map fun e =>
      { slot := e.slot, coin := e.coin, event := .ofInt e.event, known := .ofInt e.known, count := e.count }
    bound := mk.bound
    listFrom := mk.intervals.map (.ofInt ·.1), listTo := mk.intervals.map (.ofInt ·.2)
    takerFee := v.takerFee, minNotional := v.minNotional, szDecimals := v.szDecimals
    minTierLeverage := .mk v.minTierLeverage
    costBps := .mk ((Array.range coins).flatMap fun c => #[0, 1].flatMap fun s => #[0, 1].map fun z => v.costBps[c]![s]![z]!) }

/-- Merge src[l, mid) and src[mid, hi) into dst from k, taking the left on ties. -/
@[specialize] def merge (le : Nat → Nat → Bool) (src : Array Nat) (l mid r hi k : Nat) (dst : Array Nat) : Array Nat :=
  if k < hi then
    if l < mid && (r ≥ hi || le src[l]! src[r]!) then merge le src (l + 1) mid r hi (k + 1) (dst.set! k src[l]!)
    else merge le src l mid (r + 1) hi (k + 1) (dst.set! k src[r]!)
  else dst
termination_by hi - k

/-- Where the maximal non-decreasing runs of `a` from i start, and its size last. -/
@[specialize] def runs (le : Nat → Nat → Bool) (a : Array Nat) (i : Nat) (acc : Array Nat) : Array Nat :=
  if i < a.size then runs le a (i + 1) (if le a[i - 1]! a[i]! then acc else acc.push i)
  else acc.push a.size
termination_by a.size - i

/-- One pass: merge each pair of adjacent runs (boundaries `bs`) of src into dst; the halved boundaries. -/
@[specialize] def pass (le : Nat → Nat → Bool) (src : Array Nat) (bs : Array Nat) (j : Nat) (dst : Array Nat)
    (out : Array Nat) : Array Nat × Array Nat :=
  if j + 1 < bs.size then
    let lo := bs[j]!
    let mid := bs[j + 1]!
    let hi := if j + 2 < bs.size then bs[j + 2]! else mid
    pass le src bs (j + 2) (merge le src lo mid mid hi lo dst) (out.push lo)
  else (dst, out.push src.size)
termination_by bs.size - j

/-- A stable natural merge sort of indices by `le`: maximal runs merged pairwise (sorted input costs one
scan, as with Rust's stable sort). -/
@[specialize] def msort (a : Array Nat) (le : Nat → Nat → Bool) : Array Nat := Id.run do
  let mut bs := runs le a 1 #[0]
  let mut src := a
  let mut dst := Array.replicate a.size 0
  while bs.size > 2 do
    let (d, b) := pass le src bs 0 dst #[]
    dst := src
    src := d
    bs := b
  return src

/-- 0, 1, …, n − 1. -/
def iota (n : Nat) (i : Nat := 0) (acc : Array Nat := Array.emptyWithCapacity n) : Array Nat :=
  if i < n then iota n (i + 1) (acc.push i) else acc
termination_by n - i

/-- (k1, c1, e1) ≤ (k2, c2, e2) lexicographically: the reference's `lexLe` on three keys. -/
@[inline] def lexLe (k1 c1 e1 k2 c2 e2 : Int64) : Bool :=
  k1 < k2 || (k1 == k2 && (c1 < c2 || (c1 == c2 && e1 ≤ e2)))

/-- Rows grouped by coin, each group in row order. -/
@[specialize] def group {β} [Inhabited β] (coins : Nat) (rows : Array β) (coin : β → Nat) : Array (Array β) :=
  rows.foldl (init := Array.replicate coins #[]) fun acc r =>
    if coin r < coins then acc.modify (coin r) (·.push r) else acc

def barsByOpen (rows : Array BRow) : Array BRow :=
  (msort (iota rows.size) fun i j => rows[i]!.openTime ≤ rows[j]!.openTime).map (rows[·]!)

def fundingByEvent (rows : Array FRow) : Array FRow :=
  (msort (iota rows.size) fun i j => rows[i]!.event ≤ rows[j]!.event).map (rows[·]!)

/-- The fast context of a checked program on a loaded market (Ref `Ctx.make`). -/
def Cx.make (p : Program) (mk : Mkt) (pol : Policy) (stop : Int) : Cx :=
  let coins := mk.listFrom.size
  let fOrder := msort (iota mk.fr.size) fun i j =>
    let a := mk.fr[i]!; let b := mk.fr[j]!
    lexLe a.known (.ofNat a.coin) a.event b.known (.ofNat b.coin) b.event
  let bOrder := msort (iota mk.br.size) fun i j =>
    let a := mk.br[i]!; let b := mk.br[j]!
    lexLe a.known (.ofNat a.coin) a.event b.known (.ofNat b.coin) b.event
  let eOrder := msort ((iota mk.er.size).filter (mk.bound.contains mk.er[·]!.slot)) fun i j =>
    let a := mk.er[i]!; let b := mk.er[j]!
    lexLe a.known (.ofNat a.coin) (.ofNat a.slot) b.known (.ofNat b.coin) (.ofNat b.slot)
  let slots := (p.nodes.toList.filterMap Node.slot).eraseDups
  { coins, nodes := p.nodes.map (K.ofNode p.params), weight := p.weight
    fRows := fOrder.map (mk.fr[·]!), bRows := bOrder.map (mk.br[·]!), eRows := eOrder.map (mk.er[·]!)
    barsBy := (group coins mk.br (·.coin)).map barsByOpen, fundBy := (group coins mk.fr (·.coin)).map fundingByEvent
    listFrom := mk.listFrom, listTo := mk.listTo
    takerFee := mk.takerFee, minNotional := mk.minNotional, szDecimals := mk.szDecimals
    minTierLeverage := mk.minTierLeverage, costBps := mk.costBps
    delta := .ofInt pol.delta, wStart := .ofInt pol.wStart, stop := .ofInt stop, stopInt := stop, wStartInt := pol.wStart
    bound := !slots.any (!mk.bound.contains ·) }

/-- The binding preflight, then the first delivery and tick (Ref `Ctx.start`). -/
def Cx.start (cx : Cx) : Except Abort M := do
  if !cx.bound then throw .inputUnavailable
  return ((M.init cx).deliver cx (cx.wStart + cx.delta)).tick cx (cx.mask cx.wStart) cx.wStart

/-- How many steps a run takes (Ref `Ctx.bounds`, a prefix of b = wStart + k·BAR). -/
def Cx.steps (cx : Cx) : Nat :=
  ((List.range (((cx.stopInt - cx.wStartInt) / 14400000).toNat + 1)).filter fun (k : Nat) =>
    cx.wStartInt + (k : Int) * 14400000 + 2 * 14400000 ≤ cx.stopInt).length

structure Out where
  trace : Array Ev
  returns : FloatArray
  gross : FloatArray
  equity : FloatArray

def Cx.run (cx : Cx) : Except Abort Out := do
  let m ← cx.start
  let book : Book :=
    { cash := initial, pos := .mk (Array.replicate cx.coins 0), entry := .mk (Array.replicate cx.coins 0),
      realized := 0, fees := 0, slippage := 0, funding := 0, absorbed := 0 }
  let mut s : S := ⟨m, book, .mk (Array.replicate cx.coins NA), #[], #[], .empty, .empty, .empty, initial, 0⟩
  for k in [0:cx.steps] do
    s ← cx.step s (cx.wStart + k.toInt64 * BAR)
  return ⟨s.trace, s.returns, s.gross, s.equity⟩

end Fast
