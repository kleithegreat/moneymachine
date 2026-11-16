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

import Engine.Check
import Engine.Lang.SyntaxProofs
import Engine.StartProofs
import Engine.Lang.RenameProofs
import Engine.Lang.UnitsProofs
import Engine.Lang.RewriteLaw
import Engine.Lang.Units
import Engine.Lang.Rewrite
import Engine.Exact
import Engine.Ledger
import Engine.Machine
import Engine.MachineConcrete
import Engine.MachineFaults

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
  exact ⟨fun initial parts h1 hw => Engine.Machine.c1_general initial parts h1 hw, Engine.Machine.concrete_run⟩

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
       («prefix» suffix : List Engine.Machine.Event) (event : Engine.Machine.Event)
       (rules : Engine.Machine.Rules),
       Engine.Machine.start program header = .ok initial →
       (Engine.Machine.feed initial (Engine.Machine.pack «prefix»)).1 = state →
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
       let «protected» := ∃ window ∈ Engine.Machine.windows,
         window.released = false ∧ window.start ≤ event.time ∧ event.time < window.stop
       ((∃ previous, state.previous = some previous ∧ compare (key event) (key previous) = .lt) ∨
         event.coin ∈ state.ended ∨ fieldsBad ∨ repeated ∨ «protected») →
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
  refine ⟨?_, Engine.Machine.concrete_run⟩
  intro readNumber key program header initial state «prefix» suffix event rules hstart hstate hdec hrules
  intro priceBad sizeBad fieldsBad repeated «protected» hfault
  have hnn : Engine.Machine.admit state event ≠ none := by
    rcases hfault with ho | he | hf | hr | hp
    · exact Engine.Machine.admit_of_order _ _ (Engine.Machine.checkOrder_ne _ _ ho)
    · exact Engine.Machine.admit_of_ended _ _ (Engine.Machine.checkEnded_ne _ _ he)
    · exact Engine.Machine.admit_of_payload _ _ rules hrules
        (Engine.Machine.checkPayload_of_fields _ _ rules hf)
    · cases hpl : event.payload with
      | trade id price size seller =>
        have hr' : (∃ p, state.previous = some p ∧ p.time = event.time) ∧ (event.coin, id) ∈ state.ids := by
          simpa [repeated, hpl] using hr
        exact Engine.Machine.admit_of_payload _ _ rules hrules
          (Engine.Machine.checkPayload_of_repeated _ _ rules id hr' ⟨price, size, seller, hpl⟩)
      | listing _ => simp [repeated, hpl] at hr
      | ending _ => simp [repeated, hpl] at hr
      | funding _ _ _ => simp [repeated, hpl] at hr
      | quote _ _ => simp [repeated, hpl] at hr
      | observation _ _ => simp [repeated, hpl] at hr
    · exact Engine.Machine.admit_of_protected _ _ (Engine.Machine.checkProtected_ne _ hp)
  exact Engine.Machine.rejected_run state event suffix hdec hnn

end Engine.Laws

/-
Step 4 assumed interface (the builder implements to it; this file is append-only and these statements are frozen
with `sorry` until their proofs). Everything named below is built by step 4 and nothing by a later step: the
float evaluator over declared sources, the clock's ticks, the view, the inputs. Slots, exact expressions and
orders are step 5's, so no statement below mentions them, and the machine of L1a is the machine so far: it
admits, orders, counts and ticks, and its account is the starting cash, never changed.

namespace Engine.Lang
  structure NumOps (α : Type)           -- as reference/lean/Ref/Num.lean: add sub mul div neg abs log exp sqrt
                                        -- trunc signBit lt le eq isZero finite zero one ofNat ofInt ofBits
  NumOps.truth : NumOps α → Bool → α    -- one and zero
  NumOps.Lawful : NumOps α → Prop       -- the numeric obligations of the rewrite rules (criteria stage 6, L3)
  inductive Ty | bool | num (unit : Unit')      -- float sorts and their units; `Unit'` is the unit product of A17
  structure Program  (deriving Inhabited, as Ty does)  -- a checked program: `nodes`, `types : Array Ty` (one per node, in the
                                         -- order arguments before users), `probeNodes : Array Nat` (the node of
                                         -- each probe, in the program's order), its declared sources
  parse : String → Except String Program      -- A17's verdict: the first fault's code, or the program
  Program.WF : Program → Prop                 -- well formed: arguments precede users, `types` is the checker's
  Program.sourceNames : Program → List String -- every source read anywhere (a let, a probe, used or not)
  Program.declared : Program → List (String × String)  -- the (name, canonical unit) the program declares
  Program.readsTraded : Program → Bool
  Program.rename : (String → String) → Program → Program   -- renames declared sources and their occurrences
  validName : String → Bool                   -- A17's `[a-z][a-z0-9_]{0,31}`
  structure Tick (α) where inView : Nat → Bool; input : Nat → String → Option α; time : Int
                                         -- a tick's coins in view and its declared sources' values by coin
  Mach α                                      -- the evaluator's state: windows, `ticks_since`, the views' held values
  Mach.init : NumOps α → Program → Nat → Mach α
  Mach.step : NumOps α → Program → Tick α → Mach α → Mach α
  Mach.run N p coins ts := ts.foldl (fun m t => Mach.step N p t m) (Mach.init N p coins)
  Mach.vals : Mach α → Array (Array (Option α))    -- by node, by coin, as of the last tick
  UMach α                                     -- the unit-instrumented state
  UMach.init : NumOps α → Program → Nat → UMach α
  UMach.step : NumOps α → Program → Tick α → UMach α → Except String (UMach α)   -- an error is a unit or sort error
  UMach.erase : UMach α → Mach α
  UMach.tagged : UMach α → Nat → Nat → Option (α × Ty)    -- node, coin
  structure Rule; Rule.all : List Rule                    -- R version 1's twelve rows
  Rule.apply : Rule → Program → Nat → Option Program      -- the rewrite at a position
  Rule.corr : Rule → Nat → Nat → Nat                      -- the node correspondence, rule and position first
end Engine.Lang

namespace Engine.Machine
  Config.declaresSource : Config → String → String → Bool   -- the header declares (name, unit), units compared canonically
  Config.rename : (String → String) → Config → Config       -- renames the observations' names
  inputNames : List String                                  -- A17's built-in inputs
  bind : Engine.Lang.Program → Config → Except String Unit  -- start's preflight; its one error is "E_UNKNOWN_INPUT"
  structure TickRecord                       -- one tick as the machine had it: `time : Int`; `view` (the running
                                             -- view: held inputs and the view's staleness, by coin); `vals` (every
                                             -- node's value by node and coin, as bits); `row : List String`
                                             -- (= [time, coin, view mark, probes...] of each coin, the world's
                                             -- `price` and `world` fields left out)
  snapshots : State → List Event → Option (List TickRecord)
      -- feeds the events one at a time and then runs the clock out (`finish`), recording each tick's record in
      -- order; `none` exactly when admission rejects an event. It does not ask `finish`'s own verdict to be ok.
  startBeforeBind : String → String → Except String Unit
      -- `start`'s checks that come before `bind`: parse, header, venue, protected dates, leverage
  -- `start program header` is `startBeforeBind`, then `bind`, then whatever else A17 and A18 ask.
end Engine.Machine

`Engine.check : String → String` (already there) is Lean's verdict: JSON beginning {"ok":true or {"error":"CODE".
`Engine.Machine.start` runs `parse`, `parseHeader`, then `bind`, and its other checks (A17, A18).

Each law below has a witness conjunct where an empty, constant or reject-all evaluator would otherwise satisfy it.
-/

namespace Engine.Laws

def step4Header : String :=
  r#"{"horizon":{"start":1775174400000,"end":1775174400001},"venue":{"fill":"optimistic","lambda":0,"delta":0,"stale":60000,"cap":"10000","minimum":"10"},"cash":"10000","coins":[{"name":"A","sz_decimals":2,"figures":5,"decimals":4,"tiers":[{"from":"0","max_leverage":10}]}],"fees":[{"from":1775174400000,"tier":"base","maker":"0.00015","taker":"0.00045"}],"sources":{"listings":{"lag":0},"funding":{"encoding":"string","lag":0,"late":1000},"quotes":{"encoding":"string"},"trades":{"encoding":"string"},"observations":[{"name":"vol","unit":"1","kind":"state","lag":0}]},"aliases":{"coins":{},"sources":{}}}"#

def step4HeaderNoTrades : String :=
  r#"{"horizon":{"start":1775174400000,"end":1775174400001},"venue":{"fill":"optimistic","lambda":0,"delta":0,"stale":60000,"cap":"10000","minimum":"10"},"cash":"10000","coins":[{"name":"A","sz_decimals":2,"figures":5,"decimals":4,"tiers":[{"from":"0","max_leverage":10}]}],"fees":[{"from":1775174400000,"tier":"base","maker":"0.00015","taker":"0.00045"}],"sources":{"listings":{"lag":0},"funding":{"encoding":"string","lag":0,"late":1000},"quotes":{"encoding":"string"},"observations":[{"name":"vol","unit":"1","kind":"state","lag":0}]},"aliases":{"coins":{},"sources":{}}}"#

def step4Vol : String :=
  r#"{"version":2,"tick":1,"decide_every":1,"leverage":1,"sources":[{"name":"vol","unit":"1"}],"params":[],"let":[],"slots":[],"probes":[{"name":"v","is":{"input":"vol"}}]}"#

def step4HeaderNoVol : String :=
  r#"{"horizon":{"start":1775174400000,"end":1775174400001},"venue":{"fill":"optimistic","lambda":0,"delta":0,"stale":60000,"cap":"10000","minimum":"10"},"cash":"10000","coins":[{"name":"A","sz_decimals":2,"figures":5,"decimals":4,"tiers":[{"from":"0","max_leverage":10}]}],"fees":[{"from":1775174400000,"tier":"base","maker":"0.00015","taker":"0.00045"}],"sources":{"listings":{"lag":0},"funding":{"encoding":"string","lag":0,"late":1000},"quotes":{"encoding":"string"},"trades":{"encoding":"string"},"observations":[]},"aliases":{"coins":{},"sources":{}}}"#

def step4Traded : String :=
  r#"{"version":2,"tick":1,"decide_every":1,"leverage":1,"sources":[],"params":[],"let":[],"slots":[],"probes":[{"name":"t","is":{"input":"traded"}}]}"#

def step4NegNeg : String :=
  r#"{"version":2,"tick":1,"decide_every":1,"leverage":1,"sources":[{"name":"vol","unit":"1"}],"params":[],"let":[],"slots":[],"probes":[{"name":"v","is":{"op":"neg","args":[{"op":"neg","args":[{"input":"vol"}]}]}}]}"#

open Engine.Machine in
set_option maxHeartbeats 4000000 in
theorem start_vol_ok : isOk (start step4Vol step4Header) = true := by
  decide +kernel

open Engine.Machine in
set_option maxHeartbeats 4000000 in
theorem start_traded_ok : isOk (start step4Traded step4Header) = true := by
  decide +kernel

open Engine.Machine in
set_option maxHeartbeats 4000000 in
theorem start_traded_refused :
    isError "E_UNKNOWN_INPUT" (start step4Traded step4HeaderNoTrades) = true := by
  decide +kernel

open Engine.Machine in
set_option maxHeartbeats 4000000 in
theorem start_vol_refused :
    isError "E_UNKNOWN_INPUT" (start step4Vol step4HeaderNoVol) = true := by
  decide +kernel

open Engine.Lang in
/-- The checked program of `step4Vol`. -/
def step4VolProgram : Program :=
  { tick := 1, decideEvery := 1, leverage := .all 1, sources := [("vol", Dim.one)],
    nodes := #[.source "vol" Dim.one], types := #[.num Dim.one], probeNodes := #[0] }

open Engine.Lang in
set_option maxHeartbeats 4000000 in
theorem parse_step4Vol_is :
    (match parse step4Vol with | .ok p => decide (p = step4VolProgram) | .error _ => false) = true := by
  decide +kernel

open Engine.Lang in
theorem parse_step4Vol_eq : parse step4Vol = .ok step4VolProgram := by
  have := parse_step4Vol_is
  cases hp : parse step4Vol with
  | error _ => rw [hp] at this; simp at this
  | ok p => rw [hp] at this; simp at this; rw [this]

open Engine.Lang in
theorem step4Vol_reads {α : Type} (N : NumOps α) (x : α) (hx : N.finite x = true) :
    (Mach.run N step4VolProgram 1
      [⟨fun _ => true, fun _ s => if s = "vol" then some x else none, 0⟩]).vals[0]![0]! = some x := by
  simp [Mach.run, Mach.step, build, nodeStep, nodeFull, finalize, nodeCore, pointVal, evalNode, step4VolProgram,
    Mach.init, Node.args, argRow, NumOps.keep, hx]

open Engine.Lang in
/-- The checked program of `step4NegNeg`. -/
def step4NegNegProgram : Program :=
  { tick := 1, decideEvery := 1, leverage := .all 1, sources := [("vol", Dim.one)],
    nodes := #[.source "vol" Dim.one, .op .neg [0], .op .neg [1]],
    types := #[.num Dim.one, .num Dim.one, .num Dim.one], probeNodes := #[2] }

open Engine.Lang in
set_option maxHeartbeats 4000000 in
theorem parse_step4NegNeg_is :
    (match parse step4NegNeg with | .ok p => decide (p = step4NegNegProgram) | .error _ => false) = true := by
  decide +kernel

open Engine.Lang in
theorem parse_step4NegNeg_eq : parse step4NegNeg = .ok step4NegNegProgram := by
  have := parse_step4NegNeg_is
  cases hp : parse step4NegNeg with
  | error _ => rw [hp] at this; simp at this
  | ok p => rw [hp] at this; simp at this; rw [this]

open Engine.Lang in
theorem step4NegNeg_reads {α : Type} (N : NumOps α) (hL : N.Lawful) (x : α) (hx : N.finite x = true) :
    (Mach.run N step4NegNegProgram 1
      [⟨fun _ => true, fun _ s => if s = "vol" then some x else none, 0⟩]).vals[2]![0]! = some x := by
  simp [Mach.run, Mach.step, build, nodeStep, nodeFull, finalize, nodeCore, pointVal, evalNode, evalOp,
    step4NegNegProgram, Mach.init, Node.args, argRow, NumOps.keep, hx, hL.finite_neg x hx, hL.neg_neg x hx]

open Engine.Lang in
theorem step4NegNeg_reads' {α : Type} (N : NumOps α) (x : α) (hx : N.finite x = true) :
    (Mach.run N ((step4NegNegProgram).redirect 2 0) 1
      [⟨fun _ => true, fun _ s => if s = "vol" then some x else none, 0⟩]).vals[0]![0]! = some x := by
  simp [Mach.run, Mach.step, build, nodeStep, nodeFull, finalize, nodeCore, pointVal, evalNode, evalOp,
    step4NegNegProgram, Program.redirect, Mach.init, Node.args, argRow, NumOps.keep, hx]



open Engine.Lang Engine.Machine in
/-- N1's witness: `vol` renamed `vol2` over the step 4 program and header, as a proposition about them. -/
def n1Witness (p : Program) (cfg : Config) : Prop :=
  let ρ : String → String := fun s => if s = "vol" then "vol2" else s
  (∀ s ∈ ["vol"], ∀ s' ∈ ["vol"], ρ s = ρ s' → s = s') ∧
    (∀ s ∈ ["vol"], validName (ρ s) = true ∧ ρ s ∉ inputNames) ∧
    (∀ d ∈ p.declared, d.1 ∈ ["vol"]) ∧ (∀ s ∈ p.sourceNames, s ∈ ["vol"]) ∧
    (∀ o ∈ cfg.observations, o.name ∈ ["vol"]) ∧
    p.rename ρ ≠ p ∧ (match bind (p.rename ρ) (cfg.rename ρ) with | .ok _ => true | .error _ => false) = true

open Engine.Lang Engine.Machine in
instance (p : Program) (cfg : Config) : Decidable (n1Witness p cfg) := by
  unfold n1Witness
  infer_instance

open Engine.Lang Engine.Machine in
set_option maxHeartbeats 4000000 in
theorem n1_witness_holds :
    (match parse step4Vol, parseHeader step4Header with
      | .ok p, .ok cfg => decide (n1Witness p cfg)
      | _, _ => false) = true := by
  decide +kernel



open Engine.Lang in
/-- B3 L2, the checker: its programs are well formed, and `check` is `parse`'s verdict, code for code. The
witnesses: a legal float program is accepted and a text that is no program is refused with E_PARSE. -/
theorem L2_checker :
    (∀ (text : String) (p : Program), parse text = .ok p → p.WF) ∧
    (∀ text : String,
      (Engine.check text).startsWith "{\"ok\":true" = true ↔ ∃ p, parse text = .ok p) ∧
    (∀ (text code : String),
      parse text = .error code →
        (Engine.check text).startsWith ("{\"error\":\"" ++ code ++ "\"") = true) ∧
    ((∃ p, parse step4Vol = .ok p ∧ p.WF) ∧
      (Engine.check step4Vol).startsWith "{\"ok\":true" = true ∧
      parse "not a program" = .error "E_PARSE") := by
  refine ⟨fun text p h => parseAt_wfb (parse_ok_iff.1 h), check_ok_iff, check_error, ?_⟩
  have hvol : (match parse step4Vol with | .ok p => p.wfb | .error _ => false) = true := by decide +kernel
  have hbad : (match parse "not a program" with | .error c => c == "E_PARSE" | .ok _ => false) = true := by
    decide +kernel
  refine ⟨?_, ?_, ?_⟩
  · cases hp : parse step4Vol with
    | ok p => rw [hp] at hvol; exact ⟨p, rfl, hvol⟩
    | error _ => rw [hp] at hvol; simp at hvol
  · exact (check_ok_iff step4Vol).2 (by
      cases hp : parse step4Vol with
      | ok p => exact ⟨p, rfl⟩
      | error _ => rw [hp] at hvol; simp at hvol)
  · cases hp : parse "not a program" with
    | error c => rw [hp] at hbad; simpa using hbad
    | ok _ => rw [hp] at hbad; simp at hbad

open Engine.Lang in
/-- B3 L2, units: on a checked program the unit-instrumented evaluator never raises a unit or sort error at any
tick of any run; erasing its tags gives the executable evaluator's state; every defined value carries its node's
static type, and a defined bool is the number system's `truth` of a bool. The witness: a source read by a probe
comes out as the number read, when it is finite. -/
theorem L2_units {α : Type} :
    (∀ (N : NumOps α) (p : Program), p.WF → ∀ (coins : Nat) (ts : List (Tick α)),
      ∃ m : UMach α,
        ts.foldlM (fun acc t => UMach.step N p t acc) (UMach.init N p coins) = .ok m ∧
        m.erase = Mach.run N p coins ts ∧
        ∀ i, i < p.nodes.size → ∀ c x ty, m.tagged i c = some (x, ty) →
          ty = p.types[i]! ∧ (ty = Ty.bool → ∃ b, x = N.truth b)) ∧
    (∃ p : Program, parse step4Vol = .ok p ∧ ∃ i, p.probeNodes[0]? = some i ∧
      ∀ (N : NumOps α) (x : α), N.finite x = true →
        (Mach.run N p 1 [⟨fun _ => true, fun _ s => if s = "vol" then some x else none, 0⟩]).vals[i]![0]! = some x) := by
  refine ⟨fun N p hwf coins ts => l2_units N hwf coins ts, ?_⟩
  refine ⟨step4VolProgram, parse_step4Vol_eq, 0, rfl, fun N x hx => step4Vol_reads N x hx⟩

open Engine.Lang in
/-- B3 L3 over declared sources: a rewrite of R version 1 keeps a well-formed program well formed, gives every
original node the value of its corresponding node at every tick of every run, and so gives every probe the same
values. Abstract numbers: the numeric obligations are `NumOps.Lawful`. The witnesses: there are twelve rules;
and one of them rewrites the checked program `neg(neg(vol))` into a different program, where under any lawful
number system a finite input reads out as itself from both programs' probes. -/
theorem L3_rewrite {α : Type} :
    (∀ (N : NumOps α), N.Lawful → ∀ (r : Rule) (p p' : Program) (i : Nat), p.WF → r.apply p i = some p' →
      ∀ (coins : Nat) (ts : List (Tick α)),
        p'.WF ∧
        (∀ k, k < p.nodes.size →
          (Mach.run N p' coins ts).vals[r.corr i k]! = (Mach.run N p coins ts).vals[k]!) ∧
        (∀ j, j < p.probeNodes.size →
          (Mach.run N p' coins ts).vals[p'.probeNodes[j]!]! = (Mach.run N p coins ts).vals[p.probeNodes[j]!]!)) ∧
    Rule.all.length = 12 ∧
    (∃ (r : Rule) (p p' : Program) (i : Nat), r ∈ Rule.all ∧ parse step4NegNeg = .ok p ∧ r.apply p i = some p' ∧
      p' ≠ p ∧
      ∀ (N : NumOps α), N.Lawful → ∀ x : α, N.finite x = true →
        (Mach.run N p 1 [⟨fun _ => true, fun _ s => if s = "vol" then some x else none, 0⟩]).vals[p.probeNodes[0]!]![0]!
            = some x ∧
        (Mach.run N p' 1 [⟨fun _ => true, fun _ s => if s = "vol" then some x else none, 0⟩]).vals[p'.probeNodes[0]!]![0]!
            = some x) := by
  refine ⟨fun N hL r p p' i hwf happ coins ts => ?_, rfl, ?_⟩
  · obtain ⟨h1, h2, h3⟩ := rewrite_sound N hL r hwf happ
    exact ⟨h1, fun k hk => h2 coins ts k hk, fun j hj => h3 coins ts j hj⟩
  · refine ⟨.negNeg, step4NegNegProgram, step4NegNegProgram.redirect 2 0, 2, by simp [Rule.all],
      parse_step4NegNeg_eq, rfl, ?_, fun N hL x hx => ⟨?_, ?_⟩⟩
    · intro h
      have := congrArg Program.probeNodes h
      simp [Program.redirect, step4NegNegProgram] at this
    · have h0 : step4NegNegProgram.probeNodes[0]! = 2 := by
        simp [step4NegNegProgram]
      rw [h0]
      exact step4NegNeg_reads N hL x hx
    · have h0 : (step4NegNegProgram.redirect 2 0).probeNodes[0]! = 0 := by
        simp [Program.redirect, step4NegNegProgram]
      rw [h0]
      exact step4NegNeg_reads' N x hx

open Engine.Lang Engine.Machine in
/-- B3 L5 over declared sources: `start`'s preflight, before any event or tick, fails exactly when the program
declares a source the header does not declare under that unit, or reads `traded` on a market with no trade
source, and with its one code. When what comes before `bind` passes and `bind` fails, `start` returns exactly
that code; whenever `start` passes, `bind` did. The witnesses are `start`s: a compatible one succeeds; `traded`
with no trade source, and a source with no header declaration, return E_UNKNOWN_INPUT. -/
theorem L5_binding :
    (∀ (p : Program) (cfg : Config),
      (bind p cfg = .error "E_UNKNOWN_INPUT" ↔
        ((∃ d ∈ p.declared, cfg.declaresSource d.1 d.2 = false) ∨
          (p.readsTraded = true ∧ cfg.trades = none))) ∧
      (bind p cfg = .ok () ↔
        ¬ ((∃ d ∈ p.declared, cfg.declaresSource d.1 d.2 = false) ∨
          (p.readsTraded = true ∧ cfg.trades = none)))) ∧
    (∀ (program header : String) (p : Program) (cfg : Config),
      parse program = .ok p → parseHeader header = .ok cfg →
      startBeforeBind program header = .ok () → bind p cfg = .error "E_UNKNOWN_INPUT" →
      start program header = .error "E_UNKNOWN_INPUT") ∧
    (∀ (program header : String) (st : State),
      start program header = .ok st →
        ∃ (p : Program) (cfg : Config),
          parse program = .ok p ∧ parseHeader header = .ok cfg ∧ bind p cfg = .ok ()) ∧
    ((∃ st, start step4Vol step4Header = .ok st) ∧
      (∃ st, start step4Traded step4Header = .ok st) ∧
      start step4Traded step4HeaderNoTrades = .error "E_UNKNOWN_INPUT" ∧
      start step4Vol step4HeaderNoVol = .error "E_UNKNOWN_INPUT") := by
  refine ⟨fun p cfg => ⟨bind_error_iff p cfg, bind_ok_iff p cfg⟩,
    fun program header p cfg hp hc hb he => start_bind_error hp hc hb he,
    fun program header st h => start_ok_bind h, ?_⟩
  exact ⟨exists_ok_of start_vol_ok, exists_ok_of start_traded_ok, eq_error_of start_traded_refused,
    eq_error_of start_vol_refused⟩

open Engine.Lang Engine.Machine in
/-- B3 N1: a consistent renaming of the declared sources, in the program and in the header, leaves the
preflight's verdict and every node's value at every tick of every run as they were. The renaming is one-to-one,
and what it yields a legal name that is no built-in input's, on the names it renames: every source the program declares or
reads, and those of the header. No code selects behaviour by a source's name. The witness: `vol` renamed `vol2` meets every
hypothesis, changes the program, and the renamed program binds to the renamed header. -/
theorem N1_renaming {α : Type} :
    (∀ (names : List String) (ρ : String → String),
      (∀ s ∈ names, ∀ s' ∈ names, ρ s = ρ s' → s = s') →
      (∀ s ∈ names, validName (ρ s) = true ∧ ρ s ∉ inputNames) →
      ∀ (N : NumOps α) (p : Program) (cfg : Config), p.WF →
        (∀ d ∈ p.declared, d.1 ∈ names) → (∀ s ∈ p.sourceNames, s ∈ names) →
        (∀ o ∈ cfg.observations, o.name ∈ names) →
        ∀ (coins : Nat) (ts ts' : List (Tick α)),
          ts'.length = ts.length →
          (∀ (i : Nat) (t t' : Tick α), ts[i]? = some t → ts'[i]? = some t' →
            t'.inView = t.inView ∧ t'.time = t.time ∧
              ∀ c s, s ∈ p.sourceNames → t'.input c (ρ s) = t.input c s) →
          (p.rename ρ).WF ∧
          bind (p.rename ρ) (cfg.rename ρ) = bind p cfg ∧
          (Mach.run N (p.rename ρ) coins ts').vals = (Mach.run N p coins ts).vals) ∧
    (∃ (p : Program) (cfg : Config),
      parse step4Vol = .ok p ∧ parseHeader step4Header = .ok cfg ∧
      (let ρ : String → String := fun s => if s = "vol" then "vol2" else s
       (∀ s ∈ ["vol"], ∀ s' ∈ ["vol"], ρ s = ρ s' → s = s') ∧
       (∀ s ∈ ["vol"], validName (ρ s) = true ∧ ρ s ∉ inputNames) ∧
       (∀ d ∈ p.declared, d.1 ∈ ["vol"]) ∧ (∀ s ∈ p.sourceNames, s ∈ ["vol"]) ∧ (∀ o ∈ cfg.observations, o.name ∈ ["vol"]) ∧
       p.rename ρ ≠ p ∧ bind (p.rename ρ) (cfg.rename ρ) = .ok ())) := by
  refine ⟨?_, ?_⟩
  · intro names ρ hinj _ N p cfg hwf hd hs ho coins ts ts' hlen hrel
    refine ⟨wf_rename ρ hwf, bind_rename ρ names hinj p cfg hd ho, ?_⟩
    have hrun := run_rename N ρ p coins ts ts' hlen (fun i t t' h1 h2 => by
      obtain ⟨hv, _, hi⟩ := hrel i t t' h1 h2
      refine ⟨hv, fun name u hmem c => hi c name ?_⟩
      simp only [Program.sourceNames, List.mem_filterMap]
      exact ⟨.source name u, hmem, rfl⟩)
    rw [hrun]
  · cases hp : parse step4Vol with
    | error _ => have := n1_witness_holds; rw [hp] at this; simp at this
    | ok p =>
      cases hc : parseHeader step4Header with
      | error _ => have := n1_witness_holds; rw [hp, hc] at this; simp at this
      | ok cfg =>
        have := n1_witness_holds
        rw [hp, hc] at this
        have hw : n1Witness p cfg := of_decide_eq_true this
        obtain ⟨h1, h2, h3, h4, h5, h6, h7⟩ := hw
        refine ⟨p, cfg, rfl, rfl, h1, h2, h3, h4, h5, h6, ?_⟩
        cases hb : bind (p.rename fun s => if s = "vol" then "vol2" else s)
            (cfg.rename fun s => if s = "vol" then "vol2" else s) with
        | ok u => rfl
        | error e => rw [hb] at h7; simp at h7

open Engine.Machine in
/-- B3 L1a ★ for the machine so far, over a common successful `start` and admitted event streams: two markets
equal on the events known by `τ`, and on the events with `time` at most `τ − δ`, give equal ticks through `τ`:
the running view, every node's evaluated value and, as a consequence, the rows of the trace. The world's `price`
and `world` fields are not claimed. Admitted means `snapshots` is `some`: no event was rejected; the ticks are
observed as the machine had them and `finish`'s own verdict is not asked. The witnesses: two admitted streams
of one declared float observation, `3` and `5`, that start and finish ok, and whose probes read `3` and `5`. -/
theorem L1a :
    (∀ (program header : String) (initial : State), start program header = .ok initial →
      ∀ (es₁ es₂ : List Event) (τ : Int),
      es₁.filter (fun e => decide (e.known ≤ τ)) = es₂.filter (fun e => decide (e.known ≤ τ)) →
      es₁.filter (fun e => decide (e.time ≤ τ - initial.cfg.delta)) =
        es₂.filter (fun e => decide (e.time ≤ τ - initial.cfg.delta)) →
      ∀ r₁ r₂ : List TickRecord, snapshots initial es₁ = some r₁ → snapshots initial es₂ = some r₂ →
        r₁.filter (fun r => decide (r.time ≤ τ)) = r₂.filter (fun r => decide (r.time ≤ τ)) ∧
        (r₁.filter (fun r => decide (r.time ≤ τ))).map (·.row) =
          (r₂.filter (fun r => decide (r.time ≤ τ))).map (·.row)) ∧
    (let seen (bits : UInt64) : Event :=
       { coin := 0, time := 1775174400000, known := 1775174400000, payload := .observation 0 bits }
     ∃ initial : State, start step4Vol step4Header = .ok initial ∧
       (finish (feed initial (pack [seen 4613937818241073152])).1).2.startsWith "{\"ok\":true" = true ∧
       (finish (feed initial (pack [seen 4617315517961601024])).1).2.startsWith "{\"ok\":true" = true ∧
       (∃ r₁ r₂, snapshots initial [seen 4613937818241073152] = some r₁ ∧
         snapshots initial [seen 4617315517961601024] = some r₂ ∧
         r₁.map (fun r => r.row.getLast?) = [some "4008000000000000"] ∧
         r₂.map (fun r => r.row.getLast?) = [some "4014000000000000"])) := by
  sorry

end Engine.Laws
