/-
Step 1 assumed implementation interface (not declarations supplied by this file):

namespace Engine.Exact
  nearestBits : Rat → UInt64
  readBits : Nat → UInt64 → Option Int
  putPlaced : Nat → Int → Nat → Except String Int
  roundDown : Rat → Rat → Rat
  roundUp : Rat → Rat → Rat
  roundSize : Rat → Rat → Rat
  gridStep : Nat → Int → Rat → Rat
  onGrid : Nat → Int → Rat → Bool
  roundPriceBuy : Nat → Int → Rat → Rat
  roundPriceSell : Nat → Int → Rat → Rat
end Engine.Exact

readBits and putPlaced take the field scale first and return its scaled integer.
putPlaced then takes the signed digits and the meaningful fractional places;
its failure is "E_DECIMAL". nearestBits is binary64 nearest, ties to even,
computed on integers, with canonical positive zero. The three uniform rounders
take value then positive step; roundSize truncates toward zero. Grid functions
take figures, decimal places, then price. Decimal places are Int so the tests
also cover arithmetic.py.txt's -1-place grids; market admission remains A18's.
onGrid is A18's positive-price sentence, with significant figures expressed as
multiples, not a string digit counter. No function here uses Lean Float.

OCaml library mm2_lean, modules Mm2_lean.Exact and Mm2_lean.Decimal:
  type rat = string * string  (* reduced numerator, positive denominator *)
  Exact.mul : rat -> rat -> rat                  (* Lean Rat multiplication *)
  Exact.nearest_bits : rat -> int64              (* unchanged UInt64 bits *)
  Exact.read_bits : int -> int64 -> string option
  Exact.put_placed : int -> (string * int) -> (string, string) result
  Exact.round_down, Exact.round_up, Exact.round_size : rat -> rat -> rat
  Exact.grid_step : int -> int -> rat -> rat
  Exact.on_grid : int -> int -> rat -> bool
  Exact.round_price_buy, Exact.round_price_sell : int -> int -> rat -> rat
  Decimal.place : string -> ((string * int), string) result
Decimal.place receives no scale, removes insignificant fractional trailing
zeros, and places digits without float arithmetic. Exact entry points call
the corresponding Lean functions through the existing C-stub boundary;
they do not implement a second arithmetic engine in OCaml or C.
-/

import Engine.Exact
import Engine.Ledger

namespace Engine.Laws

open Engine.Exact

/-- A2/B3 X2: complete and sound decimal reading on bits, including -0. -/
theorem X2 (d : Nat) (hd : d ≤ 12) :
    nearestBits (0 : Rat) = (0 : UInt64) ∧
    readBits d (9223372036854775808 : UInt64) = some 0 ∧
    (∀ (bits : UInt64) (n : Int),
      readBits d bits = some n ↔
        n.natAbs < 1000000000000000 ∧
        nearestBits ((n : Rat) / (10 : Rat) ^ d) =
          (if bits = (9223372036854775808 : UInt64) then 0 else bits)) := by
  refine ⟨nearestBits_zero, readBits_zero (Or.inr rfl), ?_⟩
  intro bits n
  exact readBits_iff hd bits n

/-- Test 5: each uniform rounding is a multiple, directed, and less than a step away. -/
theorem rounding_bounds (p step : Rat) (hstep : 0 < step) :
    (∃ k : Int, roundDown p step = (k : Rat) * step) ∧
    roundDown p step ≤ p ∧ p - roundDown p step < step ∧
    (∃ k : Int, roundUp p step = (k : Rat) * step) ∧
    p ≤ roundUp p step ∧ roundUp p step - p < step ∧
    (∃ k : Int, roundSize p step = (k : Rat) * step) ∧
    (0 ≤ p → 0 ≤ roundSize p step ∧ roundSize p step ≤ p ∧
      p - roundSize p step < step) ∧
    (p ≤ 0 → p ≤ roundSize p step ∧ roundSize p step ≤ 0 ∧
      roundSize p step - p < step) := by
  exact rounding_parts p step hstep

/-- A18: the fixed decimal quantum, significant-figure multiples and whole-number exception. -/
theorem price_grid_characterization
    (figures : Nat) (decimals e : Int) (p : Rat)
    (hfigures : 1 ≤ figures) (hp : 0 < p) :
    let ten : Int → Rat := fun z =>
      if 0 ≤ z then (10 : Rat) ^ z.toNat else 1 / (10 : Rat) ^ (-z).toNat
    ten e ≤ p → p < ten (e + 1) →
      gridStep figures decimals p =
        ten (max (min (e - (figures : Int) + 1) 0) (-decimals)) ∧
      ((onGrid figures decimals p = true) ↔
        ∃ k : Int, p = (k : Rat) * gridStep figures decimals p) ∧
      ((onGrid figures decimals p = true) ↔
        (∃ k : Int, p = (k : Rat) * ten (-decimals)) ∧
        ((∃ k : Int, p = (k : Rat) * ten (e - (figures : Int) + 1)) ∨
          ∃ k : Int, p = (k : Rat))) := by
  intro ten h1 h2
  have hten : ∀ z, ten z = Engine.Exact.ten z := fun z => Engine.Exact.ten_eq z
  simp only [hten] at h1 h2 ⊢
  have hlog : ilog 10 p = e := ilog10_eq h1 h2
  refine ⟨?_, onGrid_iff_step hp, ?_⟩
  · unfold gridStep
    rw [stepExp_eq h1 h2]
  · rw [onGrid_iff, hlog]
    constructor
    · rintro ⟨_, h⟩
      exact h
    · intro h
      exact ⟨hp, h⟩

/-- Tests 5/6: price rounding reaches the actual neighbours, including the zero sentinel. -/
theorem price_rounding_bounds
    (figures : Nat) (decimals : Int) (p : Rat)
    (hfigures : 1 ≤ figures) (hp : 0 < p) :
    let buy := roundPriceBuy figures decimals p
    let sell := roundPriceSell figures decimals p
    (buy = 0 ∨ onGrid figures decimals buy = true) ∧
    0 ≤ buy ∧ buy ≤ p ∧ p - buy < gridStep figures decimals p ∧
    onGrid figures decimals sell = true ∧
    p ≤ sell ∧ sell - p < gridStep figures decimals p ∧
    (∀ q : Rat, onGrid figures decimals q = true → q ≤ p → q ≤ buy) ∧
    (∀ q : Rat, onGrid figures decimals q = true → p ≤ q → sell ≤ q) := by
  intro buy sell
  obtain ⟨b1, b2, b3, b4, b5⟩ := buy_spec hfigures hp
  obtain ⟨s1, s2, s3, s4⟩ := sell_spec hfigures hp
  exact ⟨b1, b2, b3, b4, s1, s2, s3, b5, s4⟩

end Engine.Laws

/-
Step 2 assumed implementation interface, in the running module Engine.Ledger:
  inductive Role | maker | taker
  structure Position where units : Rat; cost : Rat
  structure Tier where start : Int; name : String; maker : Rat; taker : Rat
  inductive Event
    | fill (time : Int) (coin : Nat) (units price : Rat) (role : Role)
    | funding (time hour : Int) (coin : Nat) (oracle rate : Rat)
    | absorb
  structure State where
    cash : Rat; positions : List Position
    realized : Rat; fees : Rat; funding : Rat; absorbed : Rat; bankrupt : Bool
  structure Receipt where
    state : State; fee : Rat; closedPnl : Rat
    tier : Option String; rate : Option Rat
  initial : Rat → Nat → State
  position : State → Nat → Position
  entry : State → Nat → Option Rat
  equity, unrealized : State → List Rat → Rat
  step : List Tier → State → Event → Except String Receipt
  replay : Rat → Nat → List Tier → List Event → Except String (List Receipt)
  checkFunding : Int → Int → Int → List (Nat × Int) → List Event → Except String Unit

OCaml Mm2_lean.Ledger has the same operations through the C stub (rat is the
canonical numerator/denominator string pair); view exposes State, Event's
constructors are Fill/Funding/Absorb, Tier.start is from_ms, closedPnl is
closed_pnl. See ocaml/test/ledger_test.ml for all OCaml record fields.
checkFunding is the pure due-hour completeness check to be used by step 7's
machine: arguments are horizon start/end, lateness, held (coin,hour) pairs,
and funding events. It does not demand funding in a fills-only layer-1 replay.

The builder must add `import Engine.Ledger` to the import header when providing
that module. This appendix does not change any step-1 import or proved theorem.
The two statements below, not their proofs, are frozen. Existence of successful
transitions is part of each characterization, not a premise a reject-all ledger
can evade. The cost of a short is negative; realized PnL excludes fees.
-/

namespace Engine.Laws

/-- B3 A1: exact initialization, views, fills, fees, absorption and prefix conservation. -/
theorem A1 :
    (∀ (cash : Rat) (coins : Nat),
      let s := Engine.Ledger.initial cash coins
      s.cash = cash ∧
      s.positions = List.replicate coins ({ units := 0, cost := 0 } : Engine.Ledger.Position) ∧
      s.realized = 0 ∧ s.fees = 0 ∧ s.funding = 0 ∧ s.absorbed = 0 ∧ s.bankrupt = false) ∧
    (∀ (s : Engine.Ledger.State) (coin : Nat) (marks : List Rat),
      Engine.Ledger.position s coin =
        (s.positions[coin]?).getD ({ units := 0, cost := 0 } : Engine.Ledger.Position) ∧
      Engine.Ledger.entry s coin =
        (let p := Engine.Ledger.position s coin
         if p.units = 0 then none else some (p.cost / p.units)) ∧
      Engine.Ledger.equity s marks = s.cash +
        (s.positions.zip marks).foldl (fun total (p, m) => total + p.units * m) (0 : Rat) ∧
      Engine.Ledger.unrealized s marks =
        (s.positions.zip marks).foldl (fun total (p, m) => total + p.units * m - p.cost) (0 : Rat)) ∧
    (∀ (fees : List Engine.Ledger.Tier) (s : Engine.Ledger.State)
        (time : Int) (coin : Nat) (units price : Rat) (role : Engine.Ledger.Role)
        (active : Engine.Ledger.Tier),
      fees.Pairwise (fun a b => a.start < b.start) →
      (∀ tier ∈ fees, 0 ≤ tier.maker ∧ tier.maker ≤ 1 ∧ 0 ≤ tier.taker ∧ tier.taker ≤ 1) →
      active ∈ fees → active.start ≤ time →
      (∀ tier ∈ fees, tier.start ≤ time → tier.start ≤ active.start) →
      s.bankrupt = false → coin < s.positions.length → units ≠ 0 → 0 < price →
      let old := Engine.Ledger.position s coin
      let next := old.units + units
      let rate := match role with
        | .maker => active.maker
        | .taker => active.taker
      let fee := (if units < 0 then -units else units) * price * rate
      let pnl := if old.units * units < 0 then
          min (if old.units < 0 then -old.units else old.units)
              (if units < 0 then -units else units) *
            (if old.units < 0 then -1 else 1) * (price - old.cost / old.units)
        else 0
      let cost := if old.units = 0 ∨ 0 < old.units * units then old.cost + units * price
        else if next = 0 then 0
        else if 0 < old.units * next then old.cost * next / old.units
        else next * price
      ∃ r : Engine.Ledger.Receipt,
        Engine.Ledger.step fees s (.fill time coin units price role) = .ok r ∧
        r.fee = fee ∧ r.closedPnl = pnl ∧ r.tier = some active.name ∧ r.rate = some rate ∧
        r.state.cash = s.cash - units * price - fee ∧
        r.state.positions.length = s.positions.length ∧
        (Engine.Ledger.position r.state coin).units = next ∧
        (Engine.Ledger.position r.state coin).cost = cost ∧
        (∀ other, other < s.positions.length → other ≠ coin →
          Engine.Ledger.position r.state other = Engine.Ledger.position s other) ∧
        r.state.realized = s.realized + pnl ∧ r.state.fees = s.fees + fee ∧
        r.state.funding = s.funding ∧ r.state.absorbed = s.absorbed ∧ r.state.bankrupt = false) ∧
    (∀ (fees : List Engine.Ledger.Tier) (s : Engine.Ledger.State),
      (∀ tier ∈ fees, 0 ≤ tier.maker ∧ tier.maker ≤ 1 ∧ 0 ≤ tier.taker ∧ tier.taker ≤ 1) →
      s.bankrupt = false → (∀ p ∈ s.positions, p.units = 0 ∧ p.cost = 0) → s.cash ≤ 0 →
      ∃ r : Engine.Ledger.Receipt,
        Engine.Ledger.step fees s .absorb = .ok r ∧
        r.state.cash = 0 ∧ r.state.absorbed = s.absorbed - s.cash ∧
        r.state.positions = s.positions ∧ r.state.realized = s.realized ∧
        r.state.fees = s.fees ∧ r.state.funding = s.funding ∧ r.state.bankrupt = true ∧
        r.fee = 0 ∧ r.closedPnl = 0 ∧ r.tier = none ∧ r.rate = none) ∧
    (∀ (cash : Rat) (coins : Nat) (fees : List Engine.Ledger.Tier)
        (events : List Engine.Ledger.Event),
      (∃ tier ∈ fees, tier.maker < 0 ∨ 1 < tier.maker ∨ tier.taker < 0 ∨ 1 < tier.taker) →
      Engine.Ledger.replay cash coins fees events = .error "E_FEE_SCHEDULE") ∧
    (∀ (cash : Rat) (coins : Nat) (fees : List Engine.Ledger.Tier)
        (events : List Engine.Ledger.Event),
      fees.Pairwise (fun a b => a.start < b.start) →
      (∀ tier ∈ fees, 0 ≤ tier.maker ∧ tier.maker ≤ 1 ∧ 0 ≤ tier.taker ∧ tier.taker ≤ 1) →
      Engine.Ledger.replay cash coins fees events =
        events.foldl (fun acc event => match acc with
          | .error code => .error code
          | .ok receipts =>
            let state := (receipts.getLast?).map Engine.Ledger.Receipt.state
              |>.getD (Engine.Ledger.initial cash coins)
            match Engine.Ledger.step fees state event with
            | .error code => .error code
            | .ok receipt => .ok (receipts ++ [receipt]))
          (.ok ([] : List Engine.Ledger.Receipt))) ∧
    (∀ (cash : Rat) (coins : Nat) (fees : List Engine.Ledger.Tier)
        (events : List Engine.Ledger.Event) (receipts : List Engine.Ledger.Receipt),
      Engine.Ledger.replay cash coins fees events = .ok receipts →
      receipts.length = events.length ∧
      (∀ k : Nat, k ≤ events.length →
        let state := ((receipts.take k).getLast?).map Engine.Ledger.Receipt.state
          |>.getD (Engine.Ledger.initial cash coins)
        let notional := (events.take k).foldl (fun total event => match event with
          | .fill _ _ units price _ => total + units * price
          | .funding _ _ _ _ _ => total
          | .absorb => total) (0 : Rat)
        state.cash = cash - notional - state.fees - state.funding + state.absorbed ∧
        state.cash = cash + state.realized - state.positions.foldl (fun total p => total + p.cost) (0 : Rat) -
          state.fees - state.funding + state.absorbed)) := by
  refine ⟨?_, ?_, ?_, ?_, ?_, ?_, ?_⟩
  · intro cash coins
    simp [Engine.Ledger.initial]
  · intro s coin marks
    refine ⟨rfl, rfl, rfl, rfl⟩
  · intro fees s time coin units price role active hsort hrates hact hstart hmax hbank hcoin hu hp
    have hactive := Engine.Ledger.active_eq fees time active hsort hact hstart hmax
    simp only [Engine.Ledger.step, hbank, Bool.false_eq_true, ↓reduceIte, hactive]
    have hcond : coin < s.positions.length ∧ units ≠ 0 ∧ 0 < price := ⟨hcoin, hu, hp⟩
    rw [if_pos hcond]
    refine ⟨_, rfl, rfl, rfl, rfl, rfl, rfl, ?_, ?_, ?_, ?_, rfl, rfl, rfl, rfl, rfl⟩
    · simp
    · rw [Engine.Ledger.position_set _ s.positions coin _ hcoin rfl]; rfl
    · rw [Engine.Ledger.position_set _ s.positions coin _ hcoin rfl]; rfl
    · intro other hother hne
      rw [Engine.Ledger.position_set_ne _ s.positions coin other _ hne rfl]
      rfl
  · intro fees s hrates hbank hflat hcash
    have hcond : (∀ p ∈ s.positions, p.units = 0 ∧ p.cost = 0) ∧ s.cash ≤ 0 := ⟨hflat, hcash⟩
    simp only [Engine.Ledger.step, hbank, Bool.false_eq_true, ↓reduceIte]
    rw [if_pos hcond]
    exact ⟨_, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl⟩
  · intro cash coins fees events ⟨tier, htier, hbad⟩
    have hs : Engine.Ledger.scheduleOk fees = false := by
      simp only [Engine.Ledger.scheduleOk, Bool.and_eq_false_iff, Bool.not_eq_true]
      left
      rw [List.all_eq_false]
      refine ⟨tier, htier, ?_⟩
      simp only [Engine.Ledger.rateOk, decide_eq_false_iff_not]
      grind
    simp [Engine.Ledger.replay, hs]
  · intro cash coins fees events hsort hrates
    have hs : Engine.Ledger.scheduleOk fees = true := by
      simp only [Engine.Ledger.scheduleOk, Bool.and_eq_true, List.all_eq_true,
        decide_eq_true_eq]
      refine ⟨fun t ht => ?_, hsort⟩
      simp only [Engine.Ledger.rateOk, decide_eq_true_eq]
      exact hrates t ht
    simp only [Engine.Ledger.replay, hs, ↓reduceIte]
    rfl
  · intro cash coins fees events receipts h
    obtain ⟨_, hchain⟩ := Engine.Ledger.replay_chain h
    obtain ⟨hlen, hk⟩ := Engine.Ledger.chain_prefix fees events _ receipts hchain
    refine ⟨hlen, fun k hkle => ?_⟩
    obtain ⟨b1, b2⟩ := hk k hkle
    have hf : (fun (total : Rat) (event : Engine.Ledger.Event) => match event with
          | .fill _ _ units price _ => total + units * price
          | .funding _ _ _ _ _ => total
          | .absorb => total) = fun total event => total + Engine.Ledger.flow event := by
      funext total event
      cases event <;> simp only [Engine.Ledger.flow] <;> grind
    dsimp only
    rw [hf]
    have hz := Engine.Ledger.totalCost_replicate coins
    simp only [Engine.Ledger.initial, Engine.Ledger.foldl_cost] at b1 b2 ⊢
    constructor <;> grind

/-- B3 U1: funding is exactly the held units' payment; missing due hours reject. -/
theorem U1 :
    (∀ (fees : List Engine.Ledger.Tier) (s : Engine.Ledger.State)
        (time hour : Int) (coin : Nat) (oracle rate : Rat),
      (∀ tier ∈ fees, 0 ≤ tier.maker ∧ tier.maker ≤ 1 ∧ 0 ≤ tier.taker ∧ tier.taker ≤ 1) →
      s.bankrupt = false → coin < s.positions.length →
      let held := (s.positions[coin]?).getD ({ units := 0, cost := 0 } : Engine.Ledger.Position)
      let payment := held.units * oracle * rate
      ∃ r : Engine.Ledger.Receipt,
        Engine.Ledger.step fees s (.funding time hour coin oracle rate) = .ok r ∧
        r.state.cash = s.cash - payment ∧ r.state.funding = s.funding + payment ∧
        r.state.positions = s.positions ∧ r.state.realized = s.realized ∧
        r.state.fees = s.fees ∧ r.state.absorbed = s.absorbed ∧ r.state.bankrupt = false ∧
        r.fee = 0 ∧ r.closedPnl = 0 ∧ r.tier = none ∧ r.rate = none) ∧
    (∀ (start finish late : Int) (held : List (Nat × Int))
        (events : List Engine.Ledger.Event),
      start < finish → 0 ≤ late → late < 3600000 →
      let missing := ∃ obligation ∈ held,
        obligation.2 % 3600000 = 0 ∧ start ≤ obligation.2 ∧ obligation.2 + late < finish ∧
        ¬ ∃ event ∈ events, match event with
          | .funding time hour coin _ _ =>
              coin = obligation.1 ∧ hour = obligation.2 ∧ hour ≤ time ∧ time ≤ hour + late
          | _ => False
      (Engine.Ledger.checkFunding start finish late held events =
        .error "R_SETTLEMENT_MISSING" ↔ missing) ∧
      (Engine.Ledger.checkFunding start finish late held events = .ok () ↔ ¬ missing)) := by
  constructor
  · intro fees s time hour coin oracle rate hrates hbank hcoin
    simp only [Engine.Ledger.step, hbank, Bool.false_eq_true, ↓reduceIte, if_pos hcoin]
    exact ⟨_, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl⟩
  · intro start finish late held events _ _ _
    exact ⟨Engine.Ledger.checkFunding_error_iff start finish late held events,
      Engine.Ledger.checkFunding_ok_iff start finish late held events⟩


end Engine.Laws

/-
Step 3 assumed RUNNING interface, reachable through the existing import closure
(this file is append-only; no test-side declarations replace implementation):

namespace Engine.Machine
  inductive Number | placed (digits : Int) (places : Nat) | bits (bits : UInt64)
  structure Level where price : Number; size : Number
  structure Rules where szDecimals : Nat; figures : Nat; decimals : Int
    -- Plus the running margin tiers.
  inductive Payload
    | listing (rules : Rules)
    | ending (price : Number)
    | funding (hour : Int) (rate : Number) (oracle : Option Number)
    | trade (id : Int) (price size : Number) (seller : Bool)
    | quote (bids asks : List Level)
    | observation (source : Nat) (bits : UInt64)
  structure Event where coin : Nat; time : Int; known : Int; payload : Payload
  structure Window where start : Int; stop : Int; released : Bool
  structure Rows where report : String; trace : String
  structure State where
    count : Nat; previous : Option Event; ids : List (Nat × Int)
    ended : List Nat; rules : List Rules
    -- Plus pending timestamp, clock, rejection and other running state.
    -- ids contains ONLY the current timestamp's (coin,id) pairs.
  windows : List Window
  start : String → String → Except String State
  pack : List Event → Chunk  -- A18 byte encoding, every value/bit preserved
  decodeChunk : State → Chunk → Except String (List Event)
    -- The running feed's structural A18 decoder, BEFORE admission. It checks
    -- array lengths/field widths/source encodings, NOT dates, prices or order.
  feed : State → Chunk → State × Rows
  finish : State → Rows × String
end Engine.Machine

OCaml Mm2_lean.Machine mirrors these pure functions and A18 arrays, with
snapshot/count/retained_bytes; see ocaml/test/events_support.ml. CLI:
mm2 start PROGRAM HEADER STATE; feed STATE CHUNK_JSON; finish STATE OUTDIR;
inspect HEADER CHUNK_JSON prints integrity metadata only. The OCaml reader is
mm2_archive.Reader, DuckDB-backed, with untouched doubles, disk-wide coin-day
id checks, and raw/snapshots manifest checks. The compiled policy file is
kernel2/protected-windows.json, strict JSON [{start:integer-ms,end:integer-ms,
released:bool}], no extra fields, code, or runtime overrides.

Each law includes a successful quote, a changed counted state and its exact
tick: an empty, reject-all, constant-state or empty-output engine fails each.
Admission faults are written below, not delegated to a mutable `validEvent`.
All projections are actual running data, not a parallel specification state.
C1/C2's decoding premises mean only that these are representable A18 events,
not that admission accepts them. The decoder is the one used by running feed,
not a second parser or a mutable market-validity predicate. In particular an
out-of-range mathematical Int cannot be packed faithfully into a wire int64.
-/

namespace Engine.Laws

/-- B3 C1: every cutting preserves complete state and ordered output bytes. -/
theorem C1 :
    (∀ (initial : Engine.Machine.State) (parts : List (List Engine.Machine.Event)),
      (∀ events ∈ parts,
        Engine.Machine.decodeChunk initial (Engine.Machine.pack events) = .ok events) →
      Engine.Machine.decodeChunk initial (Engine.Machine.pack parts.flatten) = .ok parts.flatten →
      let empty : Engine.Machine.Rows := { report := "", trace := "" }
      let folded := parts.foldl (fun (acc : Engine.Machine.State × Engine.Machine.Rows) events =>
        let next := Engine.Machine.feed acc.1 (Engine.Machine.pack events)
        (next.1, { report := acc.2.report ++ next.2.report,
                   trace := acc.2.trace ++ next.2.trace })) (initial, empty)
      let whole := Engine.Machine.feed initial (Engine.Machine.pack parts.flatten)
      folded.1 = whole.1 ∧
      (let finalParts := Engine.Machine.finish folded.1
       let finalWhole := Engine.Machine.finish whole.1
       finalParts.2 = finalWhole.2 ∧
       folded.2.report ++ finalParts.1.report = whole.2.report ++ finalWhole.1.report ∧
       folded.2.trace ++ finalParts.1.trace = whole.2.trace ++ finalWhole.1.trace)) ∧
    (let program := "{\"version\":2,\"tick\":1,\"decide_every\":1,\"leverage\":1,\"sources\":[],\"params\":[],\"let\":[],\"slots\":[],\"probes\":[]}"
     let header := "{\"horizon\":{\"start\":1775174400000,\"end\":1775174400001},\"venue\":{\"fill\":\"optimistic\",\"lambda\":0,\"delta\":0,\"stale\":60000,\"cap\":\"10000\",\"minimum\":\"10\"},\"cash\":\"10000\",\"coins\":[{\"name\":\"A\",\"sz_decimals\":2,\"figures\":5,\"decimals\":4,\"tiers\":[{\"from\":\"0\",\"max_leverage\":10}]}],\"fees\":[{\"from\":1775174400000,\"tier\":\"base\",\"maker\":\"0.00015\",\"taker\":\"0.00045\"}],\"sources\":{\"listings\":{\"lag\":0},\"funding\":{\"encoding\":\"string\",\"lag\":0,\"late\":1000},\"quotes\":{\"encoding\":\"string\"},\"trades\":{\"encoding\":\"string\"},\"observations\":[]},\"aliases\":{\"coins\":{},\"sources\":{}}}"
     let quote : Engine.Machine.Event :=
       { coin := 0, time := 1775174400000, known := 1775174400000,
         payload := .quote [{ price := .placed 99 0, size := .placed 2 0 }]
                           [{ price := .placed 101 0, size := .placed 3 0 }] }
     ∃ initial : Engine.Machine.State,
       Engine.Machine.start program header = .ok initial ∧ initial.count = 0 ∧
       Engine.Machine.decodeChunk initial (Engine.Machine.pack [quote]) = .ok [quote] ∧
       (let next := Engine.Machine.feed initial (Engine.Machine.pack [quote])
        let final := Engine.Machine.finish next.1
        next.1.count = 1 ∧ next.1 ≠ initial ∧
        final.2.startsWith "{\"ok\":true" = true ∧
        next.2.trace ++ final.1.trace = "tick\t1775174400000\tA\t100\t0\t0\n")) := by
  sorry

/-- B3 C2: a local admission fault rejects permanently, publishing no final rows. -/
theorem C2 :
    (let readNumber : Nat → Engine.Machine.Number → Option Rat := fun scale number =>
       let n := match number with
         | .placed digits places => (Engine.Exact.putPlaced scale digits places).toOption
         | .bits bits => Engine.Exact.readBits scale bits
       n.map (fun digits => (digits : Rat) / (10 : Rat) ^ scale)
     let key := fun (event : Engine.Machine.Event) =>
       let cls : Nat := match event.payload with
         | .listing _ | .ending _ => 1
         | .funding _ _ _ => 2
         | _ => 3
       let kind : Nat := match event.payload with
         | .listing _ | .ending _ => 0
         | .funding _ _ _ => 1
         | .trade _ _ _ _ => 2
         | .quote _ _ => 3
         | .observation _ _ => 4
       let source : Nat := match event.payload with
         | .observation source _ => source
         | _ => 0
       (event.time, cls, event.coin, kind, source)
     ∀ (program header : String) (initial state : Engine.Machine.State)
       (prefix suffix : List Engine.Machine.Event) (event : Engine.Machine.Event)
       (rules : Engine.Machine.Rules),
       Engine.Machine.start program header = .ok initial →
       (Engine.Machine.feed initial (Engine.Machine.pack prefix)).1 = state →
       Engine.Machine.decodeChunk state (Engine.Machine.pack [event]) = .ok [event] →
       state.rules[event.coin]? = some rules →
       let priceBad := fun (number : Engine.Machine.Number) =>
         match readNumber 8 number with
         | none => True
          | some price => price ≤ 0 ∨ Engine.Exact.onGrid rules.figures rules.decimals price = false
       let sizeBad := fun (number : Engine.Machine.Number) =>
         match readNumber rules.szDecimals number with
         | none => True
         | some size => size ≤ 0
       let fieldsBad := match event.payload with
         | .trade _ price size _ => priceBad price ∨ sizeBad size
         | .quote bids asks =>
           bids = [] ∨ asks = [] ∨
           (∃ level ∈ bids ++ asks, priceBad level.price ∨ sizeBad level.size) ∨
           (∃ bid ask, bids.head? = some bid ∧ asks.head? = some ask ∧
             ∃ b a, readNumber 8 bid.price = some b ∧ readNumber 8 ask.price = some a ∧ a ≤ b)
         | .ending price =>
           match readNumber 8 price with
           | none => True
           | some value => value < 0 ∨ (0 < value ∧ priceBad price)
         | .funding _ rate oracle =>
           readNumber 12 rate = none ∨
           (∃ price, oracle = some price ∧ readNumber 8 price = none)
         | .listing newRules =>
           newRules.figures = 0 ∨ 8 < newRules.decimals ∨ 12 < newRules.szDecimals
         | .observation _ _ => False
       let repeated := match event.payload with
         | .trade id _ _ _ =>
           (∃ previous, state.previous = some previous ∧ previous.time = event.time) ∧
           (event.coin, id) ∈ state.ids
         | _ => False
       let protected := ∃ window ∈ Engine.Machine.windows,
         window.released = false ∧ window.start ≤ event.time ∧ event.time < window.stop
       ((∃ previous, state.previous = some previous ∧ compare (key event) (key previous) = .lt) ∨
         event.coin ∈ state.ended ∨ fieldsBad ∨ repeated ∨ protected) →
       let rejected := Engine.Machine.feed state (Engine.Machine.pack [event])
        let after := Engine.Machine.feed rejected.1 (Engine.Machine.pack suffix)
        let final := Engine.Machine.finish after.1
        rejected.2.report = "" ∧ rejected.2.trace = "" ∧
        after.2.report = "" ∧ after.2.trace = "" ∧
       final.1.report = "" ∧ final.1.trace = "" ∧
       final.2.startsWith "{\"error\":" = true) ∧
    (let program := "{\"version\":2,\"tick\":1,\"decide_every\":1,\"leverage\":1,\"sources\":[],\"params\":[],\"let\":[],\"slots\":[],\"probes\":[]}"
     let header := "{\"horizon\":{\"start\":1775174400000,\"end\":1775174400001},\"venue\":{\"fill\":\"optimistic\",\"lambda\":0,\"delta\":0,\"stale\":60000,\"cap\":\"10000\",\"minimum\":\"10\"},\"cash\":\"10000\",\"coins\":[{\"name\":\"A\",\"sz_decimals\":2,\"figures\":5,\"decimals\":4,\"tiers\":[{\"from\":\"0\",\"max_leverage\":10}]}],\"fees\":[{\"from\":1775174400000,\"tier\":\"base\",\"maker\":\"0.00015\",\"taker\":\"0.00045\"}],\"sources\":{\"listings\":{\"lag\":0},\"funding\":{\"encoding\":\"string\",\"lag\":0,\"late\":1000},\"quotes\":{\"encoding\":\"string\"},\"trades\":{\"encoding\":\"string\"},\"observations\":[]},\"aliases\":{\"coins\":{},\"sources\":{}}}"
     let quote : Engine.Machine.Event :=
       { coin := 0, time := 1775174400000, known := 1775174400000,
         payload := .quote [{ price := .placed 99 0, size := .placed 2 0 }]
                           [{ price := .placed 101 0, size := .placed 3 0 }] }
     ∃ initial : Engine.Machine.State,
       Engine.Machine.start program header = .ok initial ∧ initial.count = 0 ∧
       Engine.Machine.decodeChunk initial (Engine.Machine.pack [quote]) = .ok [quote] ∧
       (let next := Engine.Machine.feed initial (Engine.Machine.pack [quote])
        let final := Engine.Machine.finish next.1
        next.1.count = 1 ∧ next.1 ≠ initial ∧
        final.2.startsWith "{\"ok\":true" = true ∧
        next.2.trace ++ final.1.trace = "tick\t1775174400000\tA\t100\t0\t0\n")) := by
  sorry

end Engine.Laws
