import Ref.Sim

/-!
A performance-oriented executable of the reference machine (Ref/Machine.lean), on binary64 only, unverified.
It performs the reference's floating-point operations in the same order, so its results are bit-identical,
with different data structures: times as `Int64` (the reference's timestamps exceed Lean's small `Int`s, so
every comparison and sum there is a bignum operation), values flat in a `FloatArray` indexed `node * coins +
coin`, windows as ring buffers, and every array updated in place.

A stored value is finite or undefined, so undefined is encoded as NaN: every operation reads stored values
only, and an operation's result is stored through `keep`, which maps NaN to undefined as the reference's
`keep` maps it to `none`. Operations that do not propagate NaN (comparisons, min and max, sign, the logical
operators, `if`) test their arguments' definedness explicitly.
-/

namespace Fast
open Ref

def HOUR : Int64 := 3600000
def BAR : Int64 := 14400000
def NA : Float := 0 / 0

@[inline] def isNaN (x : Float) : Bool := x != x
@[inline] def def? (x : Float) : Bool := x == x
/-- Finite iff x − x is 0 (∞ − ∞ and NaN − NaN are NaN). -/
@[inline] def keep (x : Float) : Float := if x - x == 0 then x else NA
@[inline] def truth (b : Bool) : Float := if b then 1 else 0
@[inline] def fmin (a b : Float) : Float := if isNaN a then b else if isNaN b then a else if b < a then b else a
@[inline] def fmax (a b : Float) : Float := if isNaN a then b else if isNaN b then a else if a < b then b else a
@[inline] def sign (x : Float) : Float := if 0 < x then 1 else if x < 0 then -1 else 0
@[inline] def signum (x : Float) : Float := if x.toBits >>> 63 == 1 then -1 else 1
@[inline] def trunc (x : Float) : Float := if x ≥ 0 then x.floor else x.ceil
@[inline] def imax (a b : Int64) : Int64 := if a < b then b else a

structure FRow where
  coin : Nat
  event : Int64
  known : Int64
  rate : Float
  premium : Float
  deriving Inhabited

structure BRow where
  coin : Nat
  openTime : Int64
  event : Int64
  known : Int64
  o : Float
  h : Float
  l : Float
  c : Float
  v : Float
  trades : Int64
  deriving Inhabited

structure ERow where
  slot : Nat
  coin : Nat
  event : Int64
  known : Int64
  count : Float
  deriving Inhabited

/-- A node, its argument indices resolved (unused ones 0). -/
inductive K where
  | input (i : Input)
  | const (x : Float)
  | op (o : Op) (a0 a1 a2 : Nat)
  deriving Inhabited

def K.ofNode (params : Array (UInt64 × Dim)) : Node → K
  | .input i => .input i
  | .const bits _ => .const (Float.ofBits bits)
  | .param k => .const (Float.ofBits params[k]!.1)
  | .op o args => .op o (args.getD 0 0) (args.getD 1 0) (args.getD 2 0)

/-- Windows (Ref `Win`): ring buffers holding the last values oldest first from `start`, NaN for undefined. -/
inductive Win where
  | none
  | lag (buf : FloatArray) (start len : Nat)
  | sums (kind : Window) (buf : FloatArray) (start len : Nat) (sum sumsq : Float) (nones since : Nat)
  /-- The monotone deque from `lo`; `lastNone` 0 when no undefined value was pushed (seq starts at 1). -/
  | extreme (isMax : Bool) (n seq lastNone : Nat) (qs : Array Nat) (qv : Array Float) (lo : Nat)
  | ema (n : Nat) (alpha s : Float) (seen : Nat)
  deriving Inhabited

def Win.new : Window → Nat → Win
  | .lag, n => .lag (.mk (Array.replicate (n + 1) 0)) 0 0
  | .minOver, n => .extreme false n 0 0 #[] #[] 0
  | .maxOver, n => .extreme true n 0 0 #[] #[] 0
  | .ema, n => .ema n (Float.ofNat 2 / (Float.ofNat n + 1)) 0 0
  | w, n => .sums w (.mk (Array.replicate n 0)) 0 0 0 0 0 0

/-- Σ of the defined values of a ring, oldest first, as the left fold from −0.0; `sq` sums their squares. -/
def ringTotal (buf : FloatArray) (start len : Nat) (sq : Bool) : Float := Id.run do
  let cap := buf.size
  let mut acc : Float := -0.0
  for k in [0:len] do
    let v := buf[(start + k) % cap]!
    if def? v then acc := acc + (if sq then v * v else v)
  return acc

/-- One push (Ref `Win.push`): the new state and the output, NaN if undefined. -/
def Win.push (w : Win) (x : Float) : Win × Float :=
  match w with
  | .none => (.none, NA)
  | .lag buf start len =>
    let cap := buf.size
    let (buf, start, len) := if len < cap then (buf.set! ((start + len) % cap) x, start, len + 1)
      else (buf.set! start x, (start + 1) % cap, len)
    (.lag buf start len, if len == cap then buf[start]! else NA)
  | .sums kind buf start len sum sumsq nones since =>
    let n := buf.size
    let (sum, sumsq, nones) := if def? x then (sum + x, sumsq + x * x, nones) else (sum, sumsq, nones + 1)
    let (buf, start, len, sum, sumsq, nones) := if len < n then (buf.set! ((start + len) % n) x, start, len + 1, sum, sumsq, nones)
      else
        let old := buf[start]!
        let (sum, sumsq, nones) := if def? old then (sum - old, sumsq - old * old, nones) else (sum, sumsq, nones - 1)
        (buf.set! start x, (start + 1) % n, len, sum, sumsq, nones)
    let since := since + 1
    let (since, sum, sumsq) := if since ≥ n then (0, ringTotal buf start len false, ringTotal buf start len true)
      else (since, sum, sumsq)
    let out := if len < n || nones > 0 then NA else
      let m := sum / Float.ofNat n
      match kind with
      | .sum => sum
      | .mean => m
      | _ => Float.sqrt (fmax (sumsq / Float.ofNat n - m * m) 0)
    (.sums kind buf start len sum sumsq nones since, out)
  | .extreme isMax n seq lastNone qs qv lo =>
    let seq := seq + 1
    let (lastNone, qs, qv) := if isNaN x then (seq, qs, qv) else Id.run do
      let mut qs := qs
      let mut qv := qv
      while qs.size > lo && (if isMax then qv[qv.size - 1]! ≤ x else x ≤ qv[qv.size - 1]!) do
        qs := qs.pop
        qv := qv.pop
      return (lastNone, qs.push seq, qv.push x)
    let start : Int := (seq : Int) - n + 1
    let lo := Id.run do
      let mut lo := lo
      while lo < qs.size && (qs[lo]! : Int) < start do lo := lo + 1
      return lo
    let (qs, qv, lo) := if lo ≥ 64 && 2 * lo ≥ qs.size then (qs.extract lo qs.size, qv.extract lo qv.size, 0)
      else (qs, qv, lo)
    let out := if start < 1 || (lastNone != 0 && (lastNone : Int) ≥ start) then NA
      else if lo < qs.size then qv[lo]! else NA
    (.extreme isMax n seq lastNone qs qv lo, out)
  | .ema n alpha s seen =>
    if isNaN x then (.ema n alpha s seen, NA) else
    let s := if seen == 0 then x else alpha * x + (1 - alpha) * s
    let seen := seen + 1
    (.ema n alpha s seen, if seen ≥ n then s else NA)

/-- What a run fixes before its first step: the program's nodes and the market, indexed. -/
structure Cx where
  coins : Nat
  nodes : Array K
  weight : Nat
  /-- Rows in delivery order (Ref `Ctx.make`), events restricted to bound slots. -/
  fRows : Array FRow
  bRows : Array BRow
  eRows : Array ERow
  /-- Per coin, its bars by (openTime, row) and its funding by (event, row): the last of equal keys is the
  reference's `barAt`/`rateAt`, which keep the last row inserted. -/
  barsBy : Array (Array BRow)
  fundBy : Array (Array FRow)
  listFrom : Array Int64
  listTo : Array Int64
  takerFee : Float
  minNotional : Float
  szDecimals : Array Nat
  minTierLeverage : FloatArray
  /-- [coin][side][size] flattened. -/
  costBps : FloatArray
  delta : Int64
  wStart : Int64
  stop : Int64
  stopInt : Int
  wStartInt : Int
  bound : Bool

/-- The machine's state (Ref `MState`); a delivered row is held as its index in the delivery order plus 1. -/
structure M where
  val : FloatArray
  wins : Array Win
  since : Array Int64
  funding : Array Nat
  bar : Array Nat
  events : Array Nat
  hour : Int64
  maxKnown : Int64
  fi : Nat
  bi : Nat
  ei : Nat

def NOSINCE : Int64 := Int64.ofInt (-(2 ^ 63))

def M.init (cx : Cx) : M :=
  let n := cx.nodes.size * cx.coins
  { val := .mk (Array.replicate n NA)
    wins := cx.nodes.foldl (init := Array.emptyWithCapacity n) fun ws k => match k with
      | .op (.window w h) .. => (List.range cx.coins).foldl (fun ws _ => ws.push (Win.new w h)) ws
      | _ => (List.range cx.coins).foldl (fun ws _ => ws.push .none) ws
    since := Array.replicate n NOSINCE
    funding := Array.replicate cx.coins 0
    bar := Array.replicate cx.coins 0
    events := Array.replicate (eventInputs.length * cx.coins) 0
    hour := 0, maxKnown := NOSINCE, fi := 0, bi := 0, ei := 0 }

/-- Delivery of the funding rows from `i` known by `tick`: each coin's latest row and the latest known time. -/
def deliverFunding (rows : Array FRow) (tick : Int64) (i : Nat) (held : Array Nat) (maxKnown : Int64) :
    Array Nat × Int64 × Nat :=
  if h : i < rows.size then
    let f := rows[i]
    if f.known > tick then (held, maxKnown, i)
    else deliverFunding rows tick (i + 1) (held.set! f.coin (i + 1)) (imax maxKnown f.known)
  else (held, maxKnown, i)
termination_by rows.size - i

def deliverBars (rows : Array BRow) (tick : Int64) (i : Nat) (held : Array Nat) (maxKnown : Int64) :
    Array Nat × Int64 × Nat :=
  if h : i < rows.size then
    let b := rows[i]
    if b.known > tick then (held, maxKnown, i)
    else deliverBars rows tick (i + 1) (held.set! b.coin (i + 1)) (imax maxKnown b.known)
  else (held, maxKnown, i)
termination_by rows.size - i

def deliverEvents (rows : Array ERow) (coins : Nat) (tick : Int64) (i : Nat) (held : Array Nat) (maxKnown : Int64) :
    Array Nat × Int64 × Nat :=
  if h : i < rows.size then
    let e := rows[i]
    if e.known > tick then (held, maxKnown, i)
    else
      let held := if e.coin < coins then held.set! (e.slot * coins + e.coin) (i + 1) else held
      deliverEvents rows coins tick (i + 1) held (imax maxKnown e.known)
  else (held, maxKnown, i)
termination_by rows.size - i

/-- Deliver every row known by `tick` not yet delivered: funding, then bars, then events (Ref `Ctx.deliver`). -/
def M.deliver (cx : Cx) (m : M) (tick : Int64) : M :=
  let ⟨val, wins, since, funding, bar, events, hour, maxKnown, fi, bi, ei⟩ := m
  let (funding, maxKnown, fi) := deliverFunding cx.fRows tick fi funding maxKnown
  let (bar, maxKnown, bi) := deliverBars cx.bRows tick bi bar maxKnown
  let (events, maxKnown, ei) := deliverEvents cx.eRows cx.coins tick ei events maxKnown
  ⟨val, wins, since, funding, bar, events, hour, maxKnown, fi, bi, ei⟩

@[inline] def M.input (cx : Cx) (m : M) (i : Input) (c : Nat) : Float :=
  match i with
  | .event s =>
    let k := m.events[s * cx.coins + c]!
    if k == 0 then NA else
    let e := cx.eRows[k - 1]!
    if e.event == m.hour then e.count else NA
  | .funding | .premium =>
    let k := m.funding[c]!
    if k == 0 then NA else
    let f := cx.fRows[k - 1]!
    if i matches .funding then f.rate else f.premium
  | _ =>
    let k := m.bar[c]!
    if k == 0 then NA else
    let b := cx.bRows[k - 1]!
    match i with
    | .open => b.o | .high => b.h | .low => b.l | .close => b.c | _ => b.v

/-- A pointwise operation on its arguments' stored values (Ref `MState.eval`), before `keep`. -/
@[inline] def apply (o : Op) (x y z : Float) : Float :=
  match o with
  | .add => x + y
  | .sub => x - y
  | .mul => x * y
  | .div => if isNaN y || y == 0 then NA else x / y
  | .min => if isNaN x || isNaN y then NA else fmin x y
  | .max => if isNaN x || isNaN y then NA else fmax x y
  | .neg => -x
  | .abs => x.abs
  | .sign => if isNaN x then NA else sign x
  | .log => if 0 < x then x.log else NA
  | .exp => x.exp
  | .sqrt => if 0 ≤ x then x.sqrt else NA
  | .clip => if isNaN x || isNaN y || isNaN z then NA else fmin (fmax x y) z
  | .gt => if isNaN x || isNaN y then NA else truth (y < x)
  | .ge => if isNaN x || isNaN y then NA else truth (y ≤ x)
  | .lt => if isNaN x || isNaN y then NA else truth (x < y)
  | .le => if isNaN x || isNaN y then NA else truth (x ≤ y)
  | .and => if isNaN x || isNaN y then NA else truth (x != 0 && y != 0)
  | .or => if isNaN x || isNaN y then NA else truth (x != 0 || y != 0)
  | .not => if isNaN x then NA else truth (x == 0)
  | .ite => if isNaN x then NA else if x != 0 then y else z
  | .convert f => x * Float.ofBits f
  | .window .. => x
  | _ => NA

def rank (xs : FloatArray) (v : Float) : Float := Id.run do
  if xs.size == 1 then return 1 / Float.ofNat 2
  let mut below := 0
  let mut equal := 0
  for x in xs do
    if x < v then below := below + 1
    if x == v then equal := equal + 1
  return (Float.ofNat below + (Float.ofNat equal - 1) / Float.ofNat 2) / (Float.ofNat xs.size - 1)

/-- Coins c, c+1, … of an operation node from its argument rows r0, r1, r2 (Ref `MState.eval`), kept. -/
@[specialize] def lanes (f : Float → Float → Float → Float) (coins r0 r1 r2 base : Nat) (listed : Array Bool) (c : Nat)
    (val : FloatArray) : FloatArray :=
  if c < coins then
    let v := if listed[c]! then keep (f val[r0 + c]! val[r1 + c]! val[r2 + c]!) else NA
    lanes f coins r0 r1 r2 base listed (c + 1) (val.set! (base + c) v)
  else val
termination_by coins - c

/-- An operation node, with a loop specialized to its operation. -/
def opLanes (o : Op) (coins r0 r1 r2 base : Nat) (listed : Array Bool) (val : FloatArray) : FloatArray :=
  match o with
  | .add => lanes (apply .add) coins r0 r1 r2 base listed 0 val
  | .sub => lanes (apply .sub) coins r0 r1 r2 base listed 0 val
  | .mul => lanes (apply .mul) coins r0 r1 r2 base listed 0 val
  | .div => lanes (apply .div) coins r0 r1 r2 base listed 0 val
  | .min => lanes (apply .min) coins r0 r1 r2 base listed 0 val
  | .max => lanes (apply .max) coins r0 r1 r2 base listed 0 val
  | .neg => lanes (apply .neg) coins r0 r1 r2 base listed 0 val
  | .abs => lanes (apply .abs) coins r0 r1 r2 base listed 0 val
  | .sign => lanes (apply .sign) coins r0 r1 r2 base listed 0 val
  | .log => lanes (apply .log) coins r0 r1 r2 base listed 0 val
  | .exp => lanes (apply .exp) coins r0 r1 r2 base listed 0 val
  | .sqrt => lanes (apply .sqrt) coins r0 r1 r2 base listed 0 val
  | .clip => lanes (apply .clip) coins r0 r1 r2 base listed 0 val
  | .gt => lanes (apply .gt) coins r0 r1 r2 base listed 0 val
  | .ge => lanes (apply .ge) coins r0 r1 r2 base listed 0 val
  | .lt => lanes (apply .lt) coins r0 r1 r2 base listed 0 val
  | .le => lanes (apply .le) coins r0 r1 r2 base listed 0 val
  | .and => lanes (apply .and) coins r0 r1 r2 base listed 0 val
  | .or => lanes (apply .or) coins r0 r1 r2 base listed 0 val
  | .not => lanes (apply .not) coins r0 r1 r2 base listed 0 val
  | .ite => lanes (apply .ite) coins r0 r1 r2 base listed 0 val
  | o => lanes (apply o) coins r0 r1 r2 base listed 0 val

/-- An input or constant node. -/
def leaves (cx : Cx) (m : M) (k : K) (listed : Array Bool) (base c : Nat) (val : FloatArray) : FloatArray :=
  if c < cx.coins then
    let v := if !listed[c]! then NA else match k with
      | .input i => keep (m.input cx i c)
      | .const x => keep x
      | .op .. => NA
    leaves cx m k listed base (c + 1) (val.set! (base + c) v)
  else val
termination_by cx.coins - c

/-- Coins c, c+1, … of a window node: its argument's value pushed into the coin's window if listed. -/
def windows (cx : Cx) (listed : Array Bool) (base a0 c : Nat) (val : FloatArray) (wins : Array Win) :
    FloatArray × Array Win :=
  if c < cx.coins then
    if !listed[c]! then windows cx listed base a0 (c + 1) (val.set! (base + c) NA) wins
    else
      let w := wins[base + c]!
      let wins := wins.set! (base + c) .none
      let (w, out) := w.push val[a0 * cx.coins + c]!
      windows cx listed base a0 (c + 1) (val.set! (base + c) (keep out)) (wins.set! (base + c) w)
  else (val, wins)
termination_by cx.coins - c

/-- One tick: every node in index order, each coin in order (Ref `MState.tick`). -/
def M.tick (cx : Cx) (m : M) (listed : Array Bool) (hour : Int64) : M := Id.run do
  let ⟨val, wins, since, funding, bar, events, _, maxKnown, fi, bi, ei⟩ := m
  let m0 : M := { val := .empty, wins := #[], since := #[], funding, bar, events, hour, maxKnown, fi, bi, ei }
  let coins := cx.coins
  let mut val := val
  let mut wins := wins
  let mut since := since
  for h : i in [0:cx.nodes.size] do
    let base := i * coins
    match cx.nodes[i] with
    | .op .hoursSince a0 _ _ =>
      for c in [0:coins] do
        let cond := val[a0 * coins + c]!
        if listed[c]! && def? cond && cond != 0 then since := since.set! (base + c) hour
        let t := since[base + c]!
        let v := if listed[c]! && t != NOSINCE then keep (Float.ofInt ((hour - t) / HOUR).toInt) else NA
        val := val.set! (base + c) v
    | .op o@.xsMean a0 _ _ | .op o@.xsDemean a0 _ _ | .op o@.xsRank a0 _ _ =>
      let mut values : FloatArray := .empty
      for c in [0:coins] do
        let x := val[a0 * coins + c]!
        if listed[c]! && def? x then values := values.push x
      let mean := (values.foldl (· + ·) (-0.0)) / Float.ofNat values.size
      for c in [0:coins] do
        let x := val[a0 * coins + c]!
        let v := if !(listed[c]! && def? x) then NA else match o with
          | .xsMean => keep mean
          | .xsDemean => keep (x - mean)
          | _ => keep (rank values x)
        val := val.set! (base + c) v
    | .op (.window ..) a0 _ _ =>
      let (v, w) := windows cx listed base a0 0 val wins
      val := v
      wins := w
    | .op o a0 a1 a2 => val := opLanes o coins (a0 * coins) (a1 * coins) (a2 * coins) base listed val
    | k => val := leaves cx m0 k listed base 0 val
  return { m0 with val, wins, since }

end Fast
