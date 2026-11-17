import Engine.Exact
import Engine.Json
import Engine.Policy
import Engine.Lang.Eval
import Engine.Rules

/-!
# The machine of step 3 (KERNEL.md A18, A19; kernel-v2.md A3, A13)

Events, their admission, their order, the protected dates, the clock's ticks and the staleness marks. It
holds no ledger yet: it admits, orders and counts. `feed` is the fold of `step` over the events a chunk
decodes to, and nothing in the state depends on where a chunk ends (C1).
-/

namespace Engine.Machine

open Engine.Json

structure Level where
  price : Number
  size : Number
  deriving Repr, DecidableEq

inductive Payload where
  | listing (rules : Rules)
  | ending (price : Number)
  | funding (hour : Int) (rate : Number) (oracle : Option Number)
  | trade (id : Int) (price size : Number) (seller : Bool)
  | quote (bids asks : List Level)
  | observation (source : Nat) (bits : UInt64)
  deriving Repr, DecidableEq

structure Event where
  coin : Nat
  time : Int
  known : Int
  payload : Payload
  deriving Repr, DecidableEq

/-- A18's chunk: three flat arrays of little-endian bytes, 24 for each record, 8 for each integer and double. -/
structure Chunk where
  records : ByteArray
  integers : ByteArray
  doubles : ByteArray

/-! ### The header -/

structure FeeTier where
  since : Int
  tier : String
  maker : Rat
  taker : Rat
  deriving Repr, DecidableEq

structure Observation where
  name : String
  unit : String
  flow : Bool
  lag : Int
  deriving Repr, DecidableEq

/-- The header (A18) as `start` reads it. `quotes` and `trades` are `some string?` when the source exists. -/
structure Config where
  start : Int
  stop : Int
  pessimistic : Bool
  lambda : Int
  delta : Int
  gap : Int
  cap : Rat
  minimum : Rat
  cash : Rat
  names : List String
  initialRules : List Rules
  fees : List FeeTier
  listingLag : Int
  fundingString : Bool
  fundingLag : Int
  fundingLate : Int
  quotes : Option Bool
  trades : Option Bool
  observations : List Observation
  tickMs : Option Int
  deriving Repr, DecidableEq

/-! ### The state -/

structure CoinState where
  lastQuote : Option Int
  quotes : List Int
  price : Option Rat
  fundingHour : Option Int
  deriving Repr, DecidableEq

def CoinState.fresh : CoinState := ⟨none, [], none, none⟩

structure Fault where
  code : String
  time : Int
  detail : String
  deriving Repr, DecidableEq

/-- What an event shows the program, read when the event was admitted (A18). -/
inductive PView where
  | quote (bid bidSize ask askSize : Rat)
  | trade (price size : Rat)
  | funding (rate : Rat) (oracle : Option Rat)
  | ending
  | observation (source : Nat) (bits : UInt64)
  deriving Repr, DecidableEq

/-- An event the world has met and the view has not yet taken, which waits for its `known`. -/
structure Pending where
  coin : Nat
  known : Int
  what : PView
  deriving Repr, DecidableEq

/-- A declared source's value for a coin: its latest known observation, and what became known since the last tick. -/
structure SrcCell where
  held : Option UInt64
  queue : List UInt64
  deriving Repr, DecidableEq

/-- What the program may read of a coin: the events the view has taken (A3, A5). -/
structure ViewCoin where
  seen : Bool
  bid : Option Rat
  bidSize : Option Rat
  ask : Option Rat
  askSize : Option Rat
  lastMid : Option Rat
  hi : Option Rat
  lo : Option Rat
  traded : Rat
  rate : Option Rat
  oracle : Option Rat
  ended : Bool
  srcs : List SrcCell
  deriving Repr, DecidableEq

def ViewCoin.fresh (sources : Nat) : ViewCoin :=
  ⟨false, none, none, none, none, none, none, none, 0, none, none, false, List.replicate sources ⟨none, []⟩⟩

/-- Everything a run holds between events: the last event, the ids of its timestamp, the coins that ended, the
coins' rules, a few numbers a coin, the next tick and a count. No history (B1). -/
structure State where
  cfg : Config
  count : Nat
  previous : Option Event
  ids : List (Nat × Int)
  ended : List Nat
  rules : List Rules
  coins : List CoinState
  nextTick : Option Int
  traceLines : Nat
  rejected : Option Fault
  prog : Option Engine.Lang.Program
  pending : List Pending
  view : List ViewCoin
  mach : Engine.Lang.Mach UInt64
  deriving Repr, DecidableEq

def State.reject (s : State) (code : String) (time : Int) (detail : String) : State :=
  { s with rejected := some ⟨code, time, detail⟩ }

/-! ### Reading numbers -/

/-- A number read at its field's scale: the integer `readBits` or `putPlaced` gave (A2, A18). Admission reads each
number once and the machine keeps this integer. -/
def readInt (scale : Nat) : Number → Option Int
  | .placed digits places => (Engine.Exact.putPlaced scale digits places).toOption
  | .bits bits => Engine.Exact.readBits scale bits

/-- The rational an integer reading at `scale` stands for. -/
def ofUnits (scale : Nat) (n : Int) : Rat := (n : Rat) / (10 : Rat) ^ scale

/-- The mid of two readings at scale 8. -/
def midPrice (bid ask : Int) : Rat := ((bid + ask : Int) : Rat) / ((2 * 10 ^ 8 : Nat) : Rat)

/-- What admission read of an event's payload (B1): every number as its integer at its field's scale, a size
beside the lots it was read at, and of a quote only its best levels. -/
inductive Reading where
  | listing (rules : Rules)
  | ending (price : Int)
  | funding (hour : Int) (rate : Int) (oracle : Option Int)
  | trade (id : Int) (price size : Int) (sizeScale : Nat) (seller : Bool)
  | quote (bid bidSize ask askSize : Int) (sizeScale : Nat)
  | observation (source : Nat) (bits : UInt64)
  deriving Repr, DecidableEq

abbrev Found := Option (String × String)

def found (code detail : String) : Found := some (code, detail)

/-- A fault, or what was read. -/
abbrev Checked (α : Type) := Except (String × String) α

def fail {α : Type} (code detail : String) : Checked α := .error (code, detail)

/-- A price: readable, above zero and on the coin's grid. -/
def checkPrice (rules : Rules) (number : Number) : Checked Int :=
  match readInt 8 number with
  | none => fail "E_DECIMAL" "a price out of range or with too many places"
  | some price =>
    if price ≤ 0 then fail "R_MARKET" "a price that is not above zero"
    else if Engine.Exact.onGridAt rules.figures rules.decimals 8 price = false then
      fail "R_MARKET" "a price off its coin's grid"
    else .ok price

/-- A size: readable at the coin's lots and above zero. A placed decimal finer than a lot is off the lot grid. -/
def checkSize (rules : Rules) (number : Number) : Checked Int :=
  match number with
  | .placed _ places =>
    if rules.szDecimals < places then fail "E_DECIMAL" "a size with more places than its coin's lots"
    else
      match readInt rules.szDecimals number with
      | none => fail "E_DECIMAL" "a size out of range"
      | some size => if size ≤ 0 then fail "R_MARKET" "a size that is not above zero" else .ok size
  | .bits _ =>
    match readInt rules.szDecimals number with
    | none => fail "E_DECIMAL" "a size out of range or off its coin's lots"
    | some size => if size ≤ 0 then fail "R_MARKET" "a size that is not above zero" else .ok size

/-- The levels after a side's best: every one a price and a size that pass, the prices strictly receding. -/
def scanRest (rules : Rules) (descending : Bool) : List Level → Int → Checked Unit
  | [], _ => .ok ()
  | level :: rest, before =>
    match checkPrice rules level.price with
    | .error fault => .error fault
    | .ok price =>
      match checkSize rules level.size with
      | .error fault => .error fault
      | .ok _ =>
        if (descending && price < before) || (!descending && before < price) then
          scanRest rules descending rest price
        else fail "R_MARKET" "a quote whose levels are not strictly best first"

/-- One side of a quote, best first: the readings of its best level (price, size) once every level passes. -/
def scanSide (rules : Rules) (descending : Bool) (best : Level) (rest : List Level) : Checked (Int × Int) :=
  match checkPrice rules best.price with
  | .error fault => .error fault
  | .ok price =>
    match checkSize rules best.size with
    | .error fault => .error fault
    | .ok size =>
      match scanRest rules descending rest price with
      | .error fault => .error fault
      | .ok _ => .ok (price, size)

/-- Margin tiers: at least one, the first from zero, rising. -/
def tiersRise : List (Number × Int) → Option Int → Bool
  | [], _ => true
  | (bound, _) :: rest, previous =>
    match readInt 2 bound with
    | none => false
    | some b =>
      match previous with
      | none => b == 0 && tiersRise rest (some b)
      | some p => decide (p < b) && tiersRise rest (some b)

/-! ### The order of events (A3, A18) -/

instance {α β : Type} [Ord α] [Ord β] : Ord (α × β) := lexOrd

/-- `(time, class, coin, kind, source)`, A3's order. -/
def eventKey (e : Event) : Int × Nat × Nat × Nat × Nat :=
  let cls : Nat := match e.payload with
    | .listing _ | .ending _ => 1
    | .funding _ _ _ => 2
    | _ => 3
  let kind : Nat := match e.payload with
    | .listing _ | .ending _ => 0
    | .funding _ _ _ => 1
    | .trade _ _ _ _ => 2
    | .quote _ _ => 3
    | .observation _ _ => 4
  let source : Nat := match e.payload with
    | .observation source _ => source
    | _ => 0
  (e.time, cls, e.coin, kind, source)

/-! ### Admission (A3, A13, A18) -/

def checkProtected (e : Event) : Found :=
  if windows.any (fun w => !w.released && decide (w.start ≤ e.time) && decide (e.time < w.stop)) then
    found "R_PROTECTED" "an event dated in an unreleased protected window"
  else none

def checkHorizon (s : State) (e : Event) : Found :=
  if e.time < s.cfg.start || s.cfg.stop ≤ e.time then found "R_MARKET" "an event outside the horizon" else none

def checkOrder (s : State) (e : Event) : Found :=
  match s.previous with
  | some p =>
    match compare (eventKey e) (eventKey p) with
    | .lt => found "R_MARKET" "an event before its predecessor in A3's order"
    | _ => none
  | none => none

def checkEnded (s : State) (e : Event) : Found :=
  if s.ended.contains e.coin then found "R_MARKET" "an event of a coin after its listing's end" else none

def checkRepeated (s : State) (e : Event) (id : Int) : Found :=
  match s.previous with
  | some p =>
    if p.time == e.time && s.ids.any (fun x => x.1 == e.coin && x.2 == id) then
      found "R_MARKET" "a trade id repeated at one timestamp"
    else none
  | none => none

def getCoin (s : State) (i : Nat) : CoinState := s.coins.getD i CoinState.fresh

def setAt {α : Type} : List α → Nat → α → List α
  | [], _, _ => []
  | _ :: rest, 0, v => v :: rest
  | x :: rest, n + 1, v => x :: setAt rest n v

def checkPayload (s : State) (e : Event) (rules : Rules) : Checked Reading :=
  match e.payload with
  | .listing newRules =>
    if newRules.figures = 0 || 8 < newRules.decimals || 12 < newRules.szDecimals then
      fail "R_MARKET" "rules outside A18's bounds"
    else if tiersRise newRules.tiers none = false || newRules.tiers.isEmpty then
      fail "R_MARKET" "margin tiers that do not rise from zero"
    else if e.known < e.time + s.cfg.listingLag then fail "R_MARKET" "a known time before the source's lag"
    else .ok (.listing newRules)
  | .ending price =>
    match readInt 8 price with
    | none => fail "E_DECIMAL" "a settlement price out of range"
    | some value =>
      if value < 0 then fail "R_MARKET" "a settlement price below zero"
      else if 0 < value && Engine.Exact.onGridAt rules.figures rules.decimals 8 value = false then
        fail "R_MARKET" "a settlement price off its coin's grid"
      else if e.known < e.time + s.cfg.listingLag then fail "R_MARKET" "a known time before the source's lag"
      else .ok (.ending value)
  | .funding hour rate oracle =>
    match readInt 12 rate with
    | none => fail "E_DECIMAL" "a funding rate out of range"
    | some rateUnits =>
      let timed (oracleUnits : Option Int) : Checked Reading :=
        if hour % 3600000 != 0 then fail "R_MARKET" "a funding hour that is not a whole hour"
        else if e.time < hour || hour + s.cfg.fundingLate < e.time then
          fail "R_MARKET" "a funding event outside its hour's lateness"
        else if (getCoin s e.coin).fundingHour.any (fun h => hour ≤ h) then
          fail "R_MARKET" "a second funding event for one coin and hour"
        else if e.known < e.time + s.cfg.fundingLag then fail "R_MARKET" "a known time before the source's lag"
        else .ok (.funding hour rateUnits oracleUnits)
      match oracle with
      | none => timed none
      | some price =>
        match readInt 8 price with
        | none => fail "E_DECIMAL" "an oracle price out of range"
        | some priceUnits => timed (some priceUnits)
  | .trade id price size seller =>
    match s.cfg.trades with
    | none => fail "R_MARKET" "a trade on a market with no trades"
    | some _ =>
      match checkPrice rules price with
      | .error fault => .error fault
      | .ok priceUnits =>
        match checkSize rules size with
        | .error fault => .error fault
        | .ok sizeUnits =>
          match checkRepeated s e id with
          | some fault => .error fault
          | none =>
            if e.known != e.time + s.cfg.delta then fail "R_MARKET" "a trade whose known time is not time plus delta"
            else .ok (.trade id priceUnits sizeUnits rules.szDecimals seller)
  | .quote bids asks =>
    match s.cfg.quotes with
    | none => fail "R_MARKET" "a quote on a market with no quotes"
    | some _ =>
      match bids, asks with
      | [], _ => fail "R_MARKET" "a quote with an empty side"
      | _, [] => fail "R_MARKET" "a quote with an empty side"
      | bestBid :: restBids, bestAsk :: restAsks =>
        match scanSide rules true bestBid restBids with
        | .error fault => .error fault
        | .ok bid =>
          match scanSide rules false bestAsk restAsks with
          | .error fault => .error fault
          | .ok ask =>
            if ask.1 ≤ bid.1 then fail "R_MARKET" "a crossed quote"
            else if e.known != e.time + s.cfg.delta then
              fail "R_MARKET" "a quote whose known time is not time plus delta"
            else .ok (.quote bid.1 bid.2 ask.1 ask.2 rules.szDecimals)
  | .observation source bits =>
    match s.cfg.observations[source]? with
    | none => fail "R_MARKET" "an observation of an undeclared source"
    | some o =>
      if e.known < e.time + o.lag then fail "R_MARKET" "a known time before the source's lag"
      else .ok (.observation source bits)

/-- The first fault of an event, in the order protected, horizon, A3's order, ended coin, then its fields; else what
it read. -/
def admit (s : State) (e : Event) : Checked Reading :=
  match checkProtected e with
  | some fault => .error fault
  | none =>
    match checkHorizon s e with
    | some fault => .error fault
    | none =>
      match checkOrder s e with
      | some fault => .error fault
      | none =>
        match checkEnded s e with
        | some fault => .error fault
        | none =>
          match s.rules[e.coin]? with
          | none => fail "R_MARKET" "an event of a coin outside the header"
          | some rules => checkPayload s e rules

/-! ### Rows -/

def fmtRat (q : Rat) : String := if q.den = 1 then toString q.num else toString q.num ++ "/" ++ toString q.den

def fmtOpt : Option Rat → String
  | none => "-"
  | some q => fmtRat q

def fmtBool (b : Bool) : String := if b then "1" else "0"

def coinName (s : State) (i : Nat) : String := s.cfg.names.getD i "?"

/-- A coin is stale before its first quote and from `G` after its latest (A3). -/
def staleAt (gap : Int) (last : Option Int) (t : Int) : Bool :=
  match last with
  | none => true
  | some q => decide (q + gap ≤ t)

/-- The quote times a view may still need: every one after `t` and the newest one at or before it. -/
def keepThrough (t : Int) : List Int → List Int
  | [] => []
  | x :: rest => if x ≤ t then [x] else x :: keepThrough t rest

/-- Replace the `n`th element. -/
def modifyAt {α : Type} (f : α → α) : List α → Nat → List α
  | [], _ => []
  | x :: rest, 0 => f x :: rest
  | x :: rest, n + 1 => x :: modifyAt f rest n

def insertPending (p : Pending) : List Pending → List Pending
  | [] => [p]
  | q :: rest => if p.known < q.known then p :: q :: rest else q :: insertPending p rest

def lessRat (a b : Rat) : Bool := decide (a < b)

def widen (x : Option Rat) (v : Rat) (upward : Bool) : Option Rat :=
  match x with
  | none => some v
  | some w => if upward then (if lessRat w v then some v else some w) else (if lessRat v w then some v else some w)

/-- The view takes one event (A3, A5): what it shows the program. -/
def takeView (cfg : Config) (v : ViewCoin) : PView → ViewCoin
  | .quote bid bidSize ask askSize =>
    let mid := (bid + ask) / 2
    { v with seen := true, bid := some bid, bidSize := some bidSize, ask := some ask, askSize := some askSize,
             lastMid := some mid, hi := widen v.hi mid true, lo := widen v.lo mid false }
  | .trade price size =>
    { v with seen := true, hi := widen v.hi price true, lo := widen v.lo price false, traded := v.traded + size }
  | .funding rate oracle => { v with rate := some rate, oracle := oracle }
  | .ending => { v with ended := true }
  | .observation j bits =>
    let flow := match cfg.observations[j]? with | some o => o.flow | none => false
    let update (cell : SrcCell) : SrcCell :=
      if flow then { cell with queue := cell.queue ++ [bits] } else { cell with held := some bits }
    { v with srcs := modifyAt update v.srcs j }

/-- Every event known by `time` that the view has not taken, in the order of `known` and then of the world (A18). -/
def release (s : State) (time : Int) : State :=
  let (ready, later) := s.pending.span (fun p => decide (p.known ≤ time))
  { s with pending := later,
           view := ready.foldl (fun view p => modifyAt (fun v => takeView s.cfg v p.what) view p.coin) s.view }

/-- A built-in input's exact value for a coin at a tick; the price inputs are undefined while the view is stale. -/
def exactInput (s : State) (v : ViewCoin) (stale : Bool) (name : String) : Option Rat :=
  let priced (x : Option Rat) : Option Rat := if stale then none else x
  let mid : Option Rat := match v.bid, v.ask with | some b, some a => some ((b + a) / 2) | _, _ => none
  match name with
  | "bid" => priced v.bid
  | "ask" => priced v.ask
  | "mid" => priced mid
  | "bid_size" => priced v.bidSize
  | "ask_size" => priced v.askSize
  | "high" => priced (if v.seen then (match v.hi with | some h => some h | none => v.lastMid) else none)
  | "low" => priced (if v.seen then (match v.lo with | some l => some l | none => v.lastMid) else none)
  | "traded" => if v.seen && s.cfg.trades.isSome then some v.traded else none
  | "oracle" => v.oracle
  | "funding" => v.rate
  | "pos" => some 0
  | "equity" => some s.cfg.cash
  | "free_margin" => some s.cfg.cash
  | _ => none

/-- A declared source's value for a coin at a tick: the latest known observation, or the flow's sum since the last tick. -/
def sourceValue (s : State) (c : Nat) (name : String) : Option UInt64 :=
  match s.cfg.observations.findIdx? (·.name == name), s.view[c]? with
  | some j, some v =>
    match s.cfg.observations[j]?, v.srcs[j]? with
    | some o, some cell =>
      if o.flow then (if cell.queue.isEmpty then none else some (Engine.Lang.total Engine.Lang.bitsOps cell.queue))
      else cell.held
    | _, _ => none
  | _, _ => none

def hex64 (b : UInt64) : String :=
  let ds := Nat.toDigits 16 b.toNat
  String.ofList (List.replicate (16 - ds.length) '0' ++ ds)

/-- One tick as the machine had it (KERNEL.md A19): its time, the view's inputs and marks by coin, every node's
value, and the rows' fields without the world's `price` and `world`. -/
structure TickRecord where
  time : Int
  view : List (Bool × Bool × List (Option Rat))
  vals : Array (Array (Option UInt64))
  row : List String
  deriving Repr, DecidableEq

def probeText (p : Engine.Lang.Program) (m : Engine.Lang.Mach UInt64) (exact : String → Option Rat) (c i : Nat) :
    String :=
  match p.types[i]!, p.nodes[i]! with
  | .exact _, .builtin name => fmtOpt (exact name)
  | .bool, _ =>
    match m.vals[i]![c]! with
    | none => "-"
    | some b => fmtBool (!Engine.Lang.bitsOps.isZero b)
  | _, _ =>
    match m.vals[i]![c]! with
    | none => "-"
    | some b => hex64 b

/-- The coin's tick: its next state and the row's world fields; the clock never reads either. -/
def tickCoin (cfg : Config) (time : Int) (c : CoinState) : CoinState × String × Bool × Bool :=
  let world := staleAt cfg.gap c.lastQuote time
  let seen := time - cfg.delta
  let view := staleAt cfg.gap (c.quotes.find? (· ≤ seen)) seen
  ({ c with quotes := keepThrough seen c.quotes }, fmtOpt c.price, world, view)

def clearInterval (v : ViewCoin) : ViewCoin :=
  { v with hi := none, lo := none, traded := 0, srcs := v.srcs.map fun c => { c with queue := [] } }

def tickAt (s : State) (time : Int) : State × String × TickRecord :=
  let s := release s time
  let marks := s.coins.map (tickCoin s.cfg time)
  let inView (c : Nat) : Bool := match s.view[c]? with | some v => !v.ended | none => false
  let tick : Engine.Lang.Tick UInt64 := ⟨inView, sourceValue s, time⟩
  let mach := match s.prog with
    | some p => Engine.Lang.Mach.step Engine.Lang.bitsOps p tick s.mach
    | none => s.mach
  let probes : List Nat := match s.prog with | some p => p.probeNodes.toList | none => []
  let coinIdx := List.range s.coins.length
  let exact (c : Nat) (stale : Bool) (name : String) : Option Rat :=
    match s.view[c]? with | some v => exactInput s v stale name | none => none
  let viewMark (c : Nat) : Bool := match marks[c]? with | some m => m.2.2.2 | none => false
  let fields (c : Nat) : List String :=
    [toString time, coinName s c, fmtBool (viewMark c)] ++
      (match s.prog with
       | some p => probes.map (probeText p mach (exact c (viewMark c)) c)
       | none => [])
  let rows := coinIdx.filter inView |>.map fun c =>
    match marks[c]? with
    | some m =>
      "tick\t" ++ toString time ++ "\t" ++ coinName s c ++ "\t" ++ m.2.1 ++ "\t" ++ fmtBool m.2.2.1 ++ "\t" ++
        "\t".intercalate ((fields c).drop 2)  ++ "\n"
    | none => ""
  let names : List String := match s.prog with
    | some p => p.nodes.toList.filterMap fun n => match n with | .builtin name => some name | _ => none
    | none => []
  let snap := coinIdx.map fun c => (inView c, viewMark c, names.map (exact c (viewMark c)))
  let record : TickRecord :=
    { time := time, view := snap, vals := mach.vals, row := (coinIdx.filter inView).flatMap fields }
  let s' := { s with coins := marks.map (·.1), view := s.view.map clearInterval, mach := mach,
                     traceLines := s.traceLines + (coinIdx.filter inView).length }
  (s', "".intercalate rows, record)

/-- Fire up to `n` ticks, each after every event at or before its time, keeping each tick's record. -/
def fireRec : Nat → State → Rows → List TickRecord → State × Rows × List TickRecord
  | 0, s, acc, recs => (s, acc, recs)
  | n + 1, s, acc, recs =>
    match s.nextTick, s.cfg.tickMs with
    | some time, some ms =>
      let (s', rows, record) := tickAt s time
      fireRec n { s' with nextTick := some (time + ms) } (acc ++ ⟨"", rows⟩) (recs ++ [record])
    | _, _ => (s, acc, recs)

def fireN (n : Nat) (s : State) (acc : Rows) : State × Rows :=
  let r := fireRec n s acc []
  (r.1, r.2.1)

/-- How many ticks lie strictly before `bound` (and inside the horizon). -/
def ticksBefore (s : State) (bound : Int) : Nat :=
  match s.nextTick, s.cfg.tickMs with
  | some time, some ms =>
    let top := min bound s.cfg.stop
    if time < top then ((top - time + ms - 1) / ms).toNat else 0
  | _, _ => 0

/-! ### One event -/

def sideWord (seller : Bool) : String := if seller then "sell" else "buy"

/-- The view's copy of an event, to be taken at its `known`; a run with no program has no view and makes none. -/
def withPending (s : State) (e : Event) (what : Unit → PView) : State :=
  if s.prog.isSome then { s with pending := insertPending ⟨e.coin, e.known, what ()⟩ s.pending } else s

/-- The effect of an admitted event on a coin and the trace row it writes, from what admission read of it. -/
def applyPayload (s : State) (e : Event) (reading : Reading) : State × String :=
  let c := getCoin s e.coin
  let name := coinName s e.coin
  let clock := s.cfg.tickMs.isSome
  match reading with
  | .listing newRules => ({ s with rules := setAt s.rules e.coin newRules }, "")
  | .ending price =>
    let value := ofUnits 8 price
    (withPending { s with ended := e.coin :: s.ended, coins := setAt s.coins e.coin { c with price := some value } } e
        fun _ => .ending,
      "end\t" ++ toString e.time ++ "\t" ++ name ++ "\t" ++ fmtRat value ++ "\n")
  | .funding hour rate oracle =>
    let rateValue := ofUnits 12 rate
    let oracleValue := oracle.map (ofUnits 8)
    let unitPrice := match oracleValue with
      | some p => some p
      | none => c.price
    let perUnit := unitPrice.map (· * rateValue)
    (withPending { s with coins := setAt s.coins e.coin { c with fundingHour := some hour } } e
        (fun _ => .funding rateValue oracleValue),
      "funding\t" ++ toString e.time ++ "\t" ++ name ++ "\t" ++ toString hour ++ "\t" ++ fmtOpt perUnit ++ "\n")
  | .trade id price size sizeScale seller =>
    let p := ofUnits 8 price
    let z := ofUnits sizeScale size
    let stale := staleAt s.cfg.gap c.lastQuote e.time
    (withPending { s with coins := setAt s.coins e.coin { c with price := some p } } e (fun _ => .trade p z),
      "print\t" ++ toString e.time ++ "\t" ++ name ++ "\t" ++ toString id ++ "\t" ++ sideWord seller ++ "\t" ++
        fmtRat p ++ "\t" ++ fmtRat z ++ "\t" ++ fmtBool stale ++ "\n")
  | .quote bid bidSize ask askSize sizeScale =>
    let c' : CoinState :=
      { c with lastQuote := some e.time, quotes := if clock then e.time :: c.quotes else [],
               price := some (midPrice bid ask) }
    (withPending { s with coins := setAt s.coins e.coin c' } e
        (fun _ => .quote (ofUnits 8 bid) (ofUnits sizeScale bidSize) (ofUnits 8 ask) (ofUnits sizeScale askSize)),
      "")
  | .observation source bits => (withPending s e (fun _ => .observation source bits), "")

def newIds (s : State) (e : Event) : List (Nat × Int) :=
  let kept := match s.previous with
    | some p => if p.time == e.time then s.ids else []
    | none => []
  match e.payload with
  | .trade id _ _ _ => (e.coin, id) :: kept
  | _ => kept

/-- An admitted event: the ticks it completes, then its own effect and rows. -/
def advanceRec (s : State) (e : Event) (reading : Reading) : State × Rows × List TickRecord :=
  let (s1, ticks, records) := fireRec (ticksBefore s e.time) s Rows.empty []
  let (s2, row) := applyPayload s1 e reading
  let lines := if row.isEmpty then 0 else 1
  ({ s2 with count := s2.count + 1, previous := some e, ids := newIds s1 e, traceLines := s2.traceLines + lines },
    ticks ++ ⟨"", row⟩, records)

def advance (s : State) (e : Event) (reading : Reading) : State × Rows :=
  let r := advanceRec s e reading
  (r.1, r.2.1)

def step (s : State) (e : Event) : State × Rows :=
  match s.rejected with
  | some _ => (s, Rows.empty)
  | none =>
    match admit s e with
    | .error fault => (s.reject fault.1 e.time fault.2, Rows.empty)
    | .ok reading => advance s e reading

def go : State → List Event → State × Rows
  | s, [] => (s, Rows.empty)
  | s, e :: es =>
    let first := step s e
    let rest := go first.1 es
    (rest.1, first.2 ++ rest.2)

/-! ### Chunks (A18) -/

def byteAt (b : ByteArray) (i : Nat) : Nat := if i < b.size then (b.get! i).toNat else 0

def word (b : ByteArray) (i : Nat) : Nat :=
  byteAt b i + 256 * (byteAt b (i + 1) + 256 * (byteAt b (i + 2) + 256 * (byteAt b (i + 3) +
    256 * (byteAt b (i + 4) + 256 * (byteAt b (i + 5) + 256 * (byteAt b (i + 6) + 256 * byteAt b (i + 7)))))))

def signed (n : Nat) : Int := if n < 2 ^ 63 then (n : Int) else (n : Int) - 2 ^ 64

def int64At (b : ByteArray) (i : Nat) : Int := signed (word b i)

def bitsAt (b : ByteArray) (i : Nat) : UInt64 := UInt64.ofNat (word b i)

/-- One exact field: two integers when the source is `string`, else one double. -/
def readNumber (string : Bool) (c : Chunk) (ints doubles : Nat) : Except String (Number × Nat × Nat) :=
  if string then
    if ints + 2 ≤ c.integers.size / 8 then
      let digits := int64At c.integers (8 * ints)
      let places := int64At c.integers (8 * (ints + 1))
      if places < 0 then .error "negative places" else .ok (.placed digits places.toNat, ints + 2, doubles)
    else .error "integers exhausted"
  else
    if doubles + 1 ≤ c.doubles.size / 8 then .ok (.bits (bitsAt c.doubles (8 * doubles)), ints, doubles + 1)
    else .error "doubles exhausted"

def readLevels (string : Bool) (c : Chunk) : Nat → Nat → Nat → List Level → Except String (List Level × Nat × Nat)
  | 0, ints, doubles, acc => .ok (acc.reverse, ints, doubles)
  | n + 1, ints, doubles, acc => do
    let (price, i1, d1) ← readNumber string c ints doubles
    let (size, i2, d2) ← readNumber string c i1 d1
    readLevels string c n i2 d2 (⟨price, size⟩ :: acc)

def readTiers (c : Chunk) : Nat → Nat → List (Number × Int) → Except String (List (Number × Int) × Nat)
  | 0, ints, acc => .ok (acc.reverse, ints)
  | n + 1, ints, acc => do
    let (bound, i1, _) ← readNumber true c ints 0
    if i1 + 1 ≤ c.integers.size / 8 then
      readTiers c n (i1 + 1) ((bound, int64At c.integers (8 * i1)) :: acc)
    else .error "integers exhausted"

/-- One record at index `i`, with the integers and doubles its predecessors left. -/
def readEvent (cfg : Config) (c : Chunk) (i ints doubles : Nat) : Except String (Event × Nat × Nat) :=
  let base := 24 * i
  let kind := byteAt c.records base
  let a := byteAt c.records (base + 1)
  let b := byteAt c.records (base + 2)
  let c3 := byteAt c.records (base + 3)
  let coin := byteAt c.records (base + 4) + 256 * byteAt c.records (base + 5)
  let source := byteAt c.records (base + 6) + 256 * byteAt c.records (base + 7)
  let time := int64At c.records (base + 8)
  let known := int64At c.records (base + 16)
  if cfg.names.length ≤ coin then .error "a coin that is not in the header"
  else if kind != 4 && source != 0 then .error "a source on an event that has none"
  else
    let make (payload : Payload) : Event := { coin := coin, time := time, known := known, payload := payload }
    match kind with
    | 0 =>
      if a == 1 then
        if b != 0 || c3 != 0 then .error "unused small fields"
        else do
          let (price, i1, d1) ← readNumber true c ints doubles
          .ok (make (.ending price), i1, d1)
      else if a == 0 then
        if ints + 2 ≤ c.integers.size / 8 then
          let decimals := int64At c.integers (8 * ints)
          let count := int64At c.integers (8 * (ints + 1))
          if count < 0 then .error "negative tier count"
          else do
            let (tiers, i1) ← readTiers c count.toNat (ints + 2) []
            .ok (make (.listing ⟨b, c3, decimals, tiers⟩), i1, doubles)
        else .error "integers exhausted"
      else .error "small field out of range"
    | 1 =>
      if a > 1 || b != 0 || c3 != 0 then .error "small field out of range"
      else if ints + 1 ≤ c.integers.size / 8 then
        let hour := int64At c.integers (8 * ints)
        do
          let (rate, i1, d1) ← readNumber cfg.fundingString c (ints + 1) doubles
          if a == 1 then
            let (oracle, i2, d2) ← readNumber cfg.fundingString c i1 d1
            .ok (make (.funding hour rate (some oracle)), i2, d2)
          else .ok (make (.funding hour rate none), i1, d1)
      else .error "integers exhausted"
    | 2 =>
      match cfg.trades with
      | none => .error "a trade on a market with no trades"
      | some string =>
        if a > 1 || b != 0 || c3 != 0 then .error "small field out of range"
        else if ints + 1 ≤ c.integers.size / 8 then
          let id := int64At c.integers (8 * ints)
          do
            let (price, i1, d1) ← readNumber string c (ints + 1) doubles
            let (size, i2, d2) ← readNumber string c i1 d1
            .ok (make (.trade id price size (a == 1)), i2, d2)
        else .error "integers exhausted"
    | 3 =>
      match cfg.quotes with
      | none => .error "a quote on a market with no quotes"
      | some string =>
        if a < 1 || 20 < a || b < 1 || 20 < b || c3 != 0 then .error "small field out of range"
        else do
          let (bids, i1, d1) ← readLevels string c a ints doubles []
          let (asks, i2, d2) ← readLevels string c b i1 d1 []
          .ok (make (.quote bids asks), i2, d2)
    | 4 =>
      if a != 0 || b != 0 || c3 != 0 then .error "unused small fields"
      else if cfg.observations.length ≤ source then .error "a source that is not in the header"
      else if doubles + 1 ≤ c.doubles.size / 8 then
        .ok (make (.observation source (bitsAt c.doubles (8 * doubles))), ints, doubles + 1)
      else .error "doubles exhausted"
    | _ => .error "an unknown kind"

def readEvents (cfg : Config) (c : Chunk) : Nat → Nat → Nat → Nat → List Event → Except String (List Event)
  | 0, _, ints, doubles, acc =>
    if ints == c.integers.size / 8 && doubles == c.doubles.size / 8 then .ok acc.reverse
    else .error "the arrays hold more than their records' values"
  | n + 1, i, ints, doubles, acc => do
    let (e, ints', doubles') ← readEvent cfg c i ints doubles
    readEvents cfg c n (i + 1) ints' doubles' (e :: acc)

/-- A chunk's events, or `R_MARKET`. The structure alone: no date, price or order is judged here. -/
def decodeWith (cfg : Config) (c : Chunk) : Except String (List Event) :=
  if c.records.size % 24 != 0 || c.integers.size % 8 != 0 || c.doubles.size % 8 != 0 then .error "R_MARKET"
  else
    match readEvents cfg c (c.records.size / 24) 0 0 0 [] with
    | .ok events => .ok events
    | .error _ => .error "R_MARKET"

def decodeChunk (s : State) (c : Chunk) : Except String (List Event) := decodeWith s.cfg c

/-- `go` with its rows gathered left to right in `acc`, so each event's rows are appended to a buffer nothing else holds. -/
def goAcc : State → List Event → Rows → State × Rows
  | s, [], acc => (s, acc)
  | s, e :: es, acc =>
    let first := step s e
    goAcc first.1 es (acc ++ first.2)

def feed (s : State) (c : Chunk) : State × Rows :=
  match s.rejected with
  | some _ => (s, Rows.empty)
  | none =>
    match decodeChunk s c with
    | .error code => (s.reject code 0 "a chunk that does not decode", Rows.empty)
    | .ok events => goAcc s events Rows.empty

/-! ### The end of a run -/

def errorText (f : Fault) : String :=
  "\"" ++ f.code ++ "\",\"time\":" ++ toString f.time ++ ",\"detail\":\"" ++ escape f.detail ++ "\"}"

def okText (s : State) : String :=
  "true,\"equity\":\"" ++ fmtRat s.cfg.cash ++ "\",\"report\":0,\"trace\":" ++ toString s.traceLines ++ "}"

/-- The clock runs to the horizon's end; a rejected run has no rows and says why (A19). -/
def finish (s : State) : Rows × String :=
  match s.rejected with
  | some fault => (Rows.empty, "{\"error\":" ++ errorText fault)
  | none =>
    let (last, rows) := fireN (ticksBefore s s.cfg.stop) s Rows.empty
    (rows, "{\"ok\":" ++ okText last)

/-- Every tick's record over a run of admitted events and the clock run out, or none when admission rejects one. -/
def snapshots (s : State) : List Event → Option (List TickRecord)
  | [] => some (fireRec (ticksBefore s s.cfg.stop) s Rows.empty []).2.2
  | e :: es =>
    match s.rejected with
    | some _ => none
    | none =>
      match admit s e with
      | .error _ => none
      | .ok reading =>
        let r := advanceRec s e reading
        (snapshots r.1 es).map (r.2.2 ++ ·)

/-! ### Writing a chunk -/

def le (n : Nat) : Nat → List UInt8
  | 0 => []
  | k + 1 => UInt8.ofNat (n % 256) :: le (n / 256) k

def leInt (n : Int) : List UInt8 := le (n % 2 ^ 64).toNat 8

def numberInts : Number → List Int
  | .placed digits places => [digits, places]
  | .bits _ => []

def numberDoubles : Number → List UInt64
  | .placed _ _ => []
  | .bits bits => [bits]

structure Packed where
  record : List UInt8
  ints : List Int
  doubles : List UInt64

def packEvent (e : Event) : Packed :=
  let head (kind a b c source : Nat) : List UInt8 :=
    [UInt8.ofNat kind, UInt8.ofNat a, UInt8.ofNat b, UInt8.ofNat c] ++ le e.coin 2 ++ le source 2 ++
      leInt e.time ++ leInt e.known
  let levels (ls : List Level) : List Int := ls.flatMap fun l => numberInts l.price ++ numberInts l.size
  let levelDoubles (ls : List Level) : List UInt64 :=
    ls.flatMap fun l => numberDoubles l.price ++ numberDoubles l.size
  match e.payload with
  | .listing r =>
    ⟨head 0 0 r.szDecimals r.figures 0,
      [r.decimals, r.tiers.length] ++ r.tiers.flatMap (fun t => numberInts t.1 ++ [t.2]), []⟩
  | .ending price => ⟨head 0 1 0 0 0, numberInts price, numberDoubles price⟩
  | .funding hour rate oracle =>
    let extraInts := match oracle with | some o => numberInts o | none => []
    let extraDoubles := match oracle with | some o => numberDoubles o | none => []
    ⟨head 1 (if oracle.isSome then 1 else 0) 0 0 0, hour :: numberInts rate ++ extraInts,
      numberDoubles rate ++ extraDoubles⟩
  | .trade id price size seller =>
    ⟨head 2 (if seller then 1 else 0) 0 0 0, id :: numberInts price ++ numberInts size,
      numberDoubles price ++ numberDoubles size⟩
  | .quote bids asks =>
    ⟨head 3 bids.length asks.length 0 0, levels bids ++ levels asks, levelDoubles bids ++ levelDoubles asks⟩
  | .observation source bits => ⟨head 4 0 0 0 source, [], [bits]⟩

def pack (events : List Event) : Chunk :=
  let parts := events.map packEvent
  { records := ByteArray.mk (parts.flatMap (·.record)).toArray
    integers := ByteArray.mk (parts.flatMap fun p => p.ints.flatMap leInt).toArray
    doubles := ByteArray.mk (parts.flatMap fun p => p.doubles.flatMap fun b => le b.toNat 8).toArray }

end Engine.Machine
