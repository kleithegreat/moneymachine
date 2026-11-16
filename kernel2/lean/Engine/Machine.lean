import Engine.Exact
import Engine.Json
import Engine.Policy

/-!
# The machine of step 3 (KERNEL.md A18, A19; kernel-v2.md A3, A13)

Events, their admission, their order, the protected dates, the clock's ticks and the staleness marks. It
holds no ledger yet: it admits, orders and counts. `feed` is the fold of `step` over the events a chunk
decodes to, and nothing in the state depends on where a chunk ends (C1).
-/

namespace Engine.Machine

open Engine.Json

inductive Number where
  | placed (digits : Int) (places : Nat)
  | bits (bits : UInt64)
  deriving Repr, DecidableEq

structure Level where
  price : Number
  size : Number
  deriving Repr, DecidableEq

/-- A coin's rules: its lots, its price grid (A18) and its margin tiers, each a bound and a greatest leverage. -/
structure Rules where
  szDecimals : Nat
  figures : Nat
  decimals : Int
  tiers : List (Number × Int)
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

structure Rows where
  report : String
  trace : String
  deriving Repr, DecidableEq

def Rows.empty : Rows := ⟨"", ""⟩

instance : Append Rows := ⟨fun a b => ⟨a.report ++ b.report, a.trace ++ b.trace⟩⟩

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
  deriving Repr, DecidableEq

def State.reject (s : State) (code : String) (time : Int) (detail : String) : State :=
  { s with rejected := some ⟨code, time, detail⟩ }

/-! ### Reading numbers -/

/-- A number read at its field's scale, as a rational (A2, A18). -/
def readRat (scale : Nat) (number : Number) : Option Rat :=
  let n := match number with
    | .placed digits places => (Engine.Exact.putPlaced scale digits places).toOption
    | .bits bits => Engine.Exact.readBits scale bits
  n.map (fun digits => (digits : Rat) / (10 : Rat) ^ scale)

abbrev Found := Option (String × String)

def found (code detail : String) : Found := some (code, detail)

/-- A price: readable, above zero and on the coin's grid. -/
def checkPrice (rules : Rules) (number : Number) : Found :=
  match readRat 8 number with
  | none => found "E_DECIMAL" "a price out of range or with too many places"
  | some price =>
    if price ≤ 0 then found "R_MARKET" "a price that is not above zero"
    else if Engine.Exact.onGrid rules.figures rules.decimals price = false then
      found "R_MARKET" "a price off its coin's grid"
    else none

/-- A size: readable at the coin's lots and above zero. A placed decimal finer than a lot is off the lot grid. -/
def checkSize (rules : Rules) (number : Number) : Found :=
  match number with
  | .placed _ places =>
    if rules.szDecimals < places then found "E_DECIMAL" "a size with more places than its coin's lots"
    else
      match readRat rules.szDecimals number with
      | none => found "E_DECIMAL" "a size out of range"
      | some size => if size ≤ 0 then found "R_MARKET" "a size that is not above zero" else none
  | .bits _ =>
    match readRat rules.szDecimals number with
    | none => found "E_DECIMAL" "a size out of range or off its coin's lots"
    | some size => if size ≤ 0 then found "R_MARKET" "a size that is not above zero" else none

/-- One side of a quote, best first: every level a price and a size that pass, the prices strictly receding. -/
def scanSide (rules : Rules) (descending : Bool) : List Level → Option Rat → Found
  | [], _ => none
  | level :: rest, previous =>
    match readRat 8 level.price with
    | none => found "E_DECIMAL" "a price out of range or with too many places"
    | some price =>
      if price ≤ 0 then found "R_MARKET" "a price that is not above zero"
      else if Engine.Exact.onGrid rules.figures rules.decimals price = false then
        found "R_MARKET" "a price off its coin's grid"
      else
        match checkSize rules level.size with
        | some fault => some fault
        | none =>
          match previous with
          | some before =>
            if (descending && price < before) || (!descending && before < price) then
              scanSide rules descending rest (some price)
            else found "R_MARKET" "a quote whose levels are not strictly best first"
          | none => scanSide rules descending rest (some price)

def crossed (bids asks : List Level) : Bool :=
  match bids.head?, asks.head? with
  | some bid, some ask =>
    match readRat 8 bid.price, readRat 8 ask.price with
    | some b, some a => decide (a ≤ b)
    | _, _ => false
  | _, _ => false

/-- Margin tiers: at least one, the first from zero, rising. -/
def tiersRise : List (Number × Int) → Option Rat → Bool
  | [], _ => true
  | (bound, _) :: rest, previous =>
    match readRat 2 bound with
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

def checkPayload (s : State) (e : Event) (rules : Rules) : Found :=
  match e.payload with
  | .listing newRules =>
    if newRules.figures = 0 || 8 < newRules.decimals || 12 < newRules.szDecimals then
      found "R_MARKET" "rules outside A18's bounds"
    else if tiersRise newRules.tiers none = false || newRules.tiers.isEmpty then
      found "R_MARKET" "margin tiers that do not rise from zero"
    else if e.known < e.time + s.cfg.listingLag then found "R_MARKET" "a known time before the source's lag"
    else none
  | .ending price =>
    match readRat 8 price with
    | none => found "E_DECIMAL" "a settlement price out of range"
    | some value =>
      if value < 0 then found "R_MARKET" "a settlement price below zero"
      else if 0 < value && Engine.Exact.onGrid rules.figures rules.decimals value = false then
        found "R_MARKET" "a settlement price off its coin's grid"
      else if e.known < e.time + s.cfg.listingLag then found "R_MARKET" "a known time before the source's lag"
      else none
  | .funding hour rate oracle =>
    match readRat 12 rate with
    | none => found "E_DECIMAL" "a funding rate out of range"
    | some _ =>
      match oracle.bind (fun price => (readRat 8 price).map fun _ => ()) , oracle with
      | none, some _ => found "E_DECIMAL" "an oracle price out of range"
      | _, _ =>
        if hour % 3600000 != 0 then found "R_MARKET" "a funding hour that is not a whole hour"
        else if e.time < hour || hour + s.cfg.fundingLate < e.time then
          found "R_MARKET" "a funding event outside its hour's lateness"
        else if (getCoin s e.coin).fundingHour.any (fun h => hour ≤ h) then
          found "R_MARKET" "a second funding event for one coin and hour"
        else if e.known < e.time + s.cfg.fundingLag then found "R_MARKET" "a known time before the source's lag"
        else none
  | .trade id price size _ =>
    match s.cfg.trades with
    | none => found "R_MARKET" "a trade on a market with no trades"
    | some _ =>
      match checkPrice rules price with
      | some fault => some fault
      | none =>
        match checkSize rules size with
        | some fault => some fault
        | none =>
          match checkRepeated s e id with
          | some fault => some fault
          | none =>
            if e.known != e.time + s.cfg.delta then found "R_MARKET" "a trade whose known time is not time plus delta"
            else none
  | .quote bids asks =>
    match s.cfg.quotes with
    | none => found "R_MARKET" "a quote on a market with no quotes"
    | some _ =>
      if bids.isEmpty || asks.isEmpty then found "R_MARKET" "a quote with an empty side"
      else
        match scanSide rules true bids none with
        | some fault => some fault
        | none =>
          match scanSide rules false asks none with
          | some fault => some fault
          | none =>
            if crossed bids asks then found "R_MARKET" "a crossed quote"
            else if e.known != e.time + s.cfg.delta then
              found "R_MARKET" "a quote whose known time is not time plus delta"
            else none
  | .observation source _ =>
    match s.cfg.observations[source]? with
    | none => found "R_MARKET" "an observation of an undeclared source"
    | some o => if e.known < e.time + o.lag then found "R_MARKET" "a known time before the source's lag" else none

/-- The first fault of an event, in the order protected, horizon, A3's order, ended coin, then its fields. -/
def admit (s : State) (e : Event) : Found :=
  match checkProtected e with
  | some fault => some fault
  | none =>
    match checkHorizon s e with
    | some fault => some fault
    | none =>
      match checkOrder s e with
      | some fault => some fault
      | none =>
        match checkEnded s e with
        | some fault => some fault
        | none =>
          match s.rules[e.coin]? with
          | none => found "R_MARKET" "an event of a coin outside the header"
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

def tickRow (cfg : Config) (time : Int) (name : String) (c : CoinState) : CoinState × String :=
  let world := staleAt cfg.gap c.lastQuote time
  let seen := time - cfg.delta
  let view := staleAt cfg.gap (c.quotes.find? (· ≤ seen)) seen
  ({ c with quotes := keepThrough seen c.quotes },
    "tick\t" ++ toString time ++ "\t" ++ name ++ "\t" ++ fmtOpt c.price ++ "\t" ++ fmtBool world ++ "\t" ++
      fmtBool view ++ "\n")

def tickCoins (cfg : Config) (time : Int) : List String → List CoinState → List CoinState × String
  | name :: names, c :: cs =>
    let (c', row) := tickRow cfg time name c
    let (rest, rows) := tickCoins cfg time names cs
    (c' :: rest, row ++ rows)
  | _, _ => ([], "")

def tickAt (s : State) (time : Int) : State × String :=
  let (coins, rows) := tickCoins s.cfg time s.cfg.names s.coins
  ({ s with coins := coins, traceLines := s.traceLines + s.coins.length }, rows)

/-- Fire up to `n` ticks, each after every event at or before its time. -/
def fireN : Nat → State → Rows → State × Rows
  | 0, s, acc => (s, acc)
  | n + 1, s, acc =>
    match s.nextTick, s.cfg.tickMs with
    | some time, some ms =>
      let (s', rows) := tickAt s time
      fireN n { s' with nextTick := some (time + ms) } (acc ++ ⟨"", rows⟩)
    | _, _ => (s, acc)

/-- How many ticks lie strictly before `bound` (and inside the horizon). -/
def ticksBefore (s : State) (bound : Int) : Nat :=
  match s.nextTick, s.cfg.tickMs with
  | some time, some ms =>
    let top := min bound s.cfg.stop
    if time < top then ((top - time + ms - 1) / ms).toNat else 0
  | _, _ => 0

/-! ### One event -/

def midOf (bids asks : List Level) : Option Rat :=
  match bids.head?, asks.head? with
  | some bid, some ask =>
    match readRat 8 bid.price, readRat 8 ask.price with
    | some b, some a => some ((b + a) / 2)
    | _, _ => none
  | _, _ => none

def sideWord (seller : Bool) : String := if seller then "sell" else "buy"

/-- The effect of an admitted event on a coin and the trace row it writes. -/
def applyPayload (s : State) (e : Event) : State × String :=
  let c := getCoin s e.coin
  let name := coinName s e.coin
  let rules := (s.rules[e.coin]?).getD ⟨0, 1, 0, []⟩
  let clock := s.cfg.tickMs.isSome
  match e.payload with
  | .listing newRules => ({ s with rules := setAt s.rules e.coin newRules }, "")
  | .ending price =>
    let value := (readRat 8 price).getD 0
    ({ s with ended := e.coin :: s.ended, coins := setAt s.coins e.coin { c with price := some value } },
      "end\t" ++ toString e.time ++ "\t" ++ name ++ "\t" ++ fmtRat value ++ "\n")
  | .funding hour rate oracle =>
    let unitPrice := match oracle.bind (readRat 8) with
      | some p => some p
      | none => c.price
    let perUnit := match unitPrice, readRat 12 rate with
      | some p, some r => some (p * r)
      | _, _ => none
    ({ s with coins := setAt s.coins e.coin { c with fundingHour := some hour } },
      "funding\t" ++ toString e.time ++ "\t" ++ name ++ "\t" ++ toString hour ++ "\t" ++ fmtOpt perUnit ++ "\n")
  | .trade id price size seller =>
    let p := (readRat 8 price).getD 0
    let z := (readRat rules.szDecimals size).getD 0
    let stale := staleAt s.cfg.gap c.lastQuote e.time
    ({ s with coins := setAt s.coins e.coin { c with price := some p } },
      "print\t" ++ toString e.time ++ "\t" ++ name ++ "\t" ++ toString id ++ "\t" ++ sideWord seller ++ "\t" ++
        fmtRat p ++ "\t" ++ fmtRat z ++ "\t" ++ fmtBool stale ++ "\n")
  | .quote bids asks =>
    let mid := match midOf bids asks with
      | some m => some m
      | none => c.price
    let c' : CoinState :=
      { c with lastQuote := some e.time, quotes := if clock then e.time :: c.quotes else [], price := mid }
    ({ s with coins := setAt s.coins e.coin c' }, "")
  | .observation _ _ => (s, "")

def newIds (s : State) (e : Event) : List (Nat × Int) :=
  let kept := match s.previous with
    | some p => if p.time == e.time then s.ids else []
    | none => []
  match e.payload with
  | .trade id _ _ _ => (e.coin, id) :: kept
  | _ => kept

/-- An admitted event: the ticks it completes, then its own effect and rows. -/
def advance (s : State) (e : Event) : State × Rows :=
  let (s1, ticks) := fireN (ticksBefore s e.time) s Rows.empty
  let (s2, row) := applyPayload s1 e
  let lines := if row.isEmpty then 0 else 1
  ({ s2 with count := s2.count + 1, previous := some e, ids := newIds s1 e, traceLines := s2.traceLines + lines },
    ticks ++ ⟨"", row⟩)

def step (s : State) (e : Event) : State × Rows :=
  match s.rejected with
  | some _ => (s, Rows.empty)
  | none =>
    match admit s e with
    | some fault => (s.reject fault.1 e.time fault.2, Rows.empty)
    | none => advance s e

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

def feed (s : State) (c : Chunk) : State × Rows :=
  match s.rejected with
  | some _ => (s, Rows.empty)
  | none =>
    match decodeChunk s c with
    | .error code => (s.reject code 0 "a chunk that does not decode", Rows.empty)
    | .ok events => go s events

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
