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
