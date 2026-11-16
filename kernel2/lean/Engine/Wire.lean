import Engine.Exact

namespace Engine.Exact

/-- The entry point of the C stub for `Mm2_lean.Exact`: an operation and its arguments as
space-separated decimal integers; a rational is a numerator then a positive denominator. -/
def call (op : String) (args : String) : Option String :=
  let rat (n d : String) : Option Rat := do
    let num ← n.toInt?
    let den ← d.toNat?
    if den = 0 then none else some (mkRat num den)
  let out (r : Rat) : String := s!"{r.num}/{r.den}"
  match op, args.splitOn " " with
  | "mul", [an, ad, bn, bd] => do
    let a ← rat an ad
    let b ← rat bn bd
    some (out (a * b))
  | "nearest_bits", [n, d] => do
    let q ← rat n d
    some (toString (nearestBits q).toNat)
  | "read_bits", [scale, bits] => do
    let d ← scale.toNat?
    let b ← bits.toNat?
    match readBits d (UInt64.ofNat b) with
    | some n => some s!"some {n}"
    | none => some "none"
  | "put_placed", [scale, digits, places] => do
    let d ← scale.toNat?
    let n ← digits.toInt?
    let w ← places.toNat?
    match putPlaced d n w with
    | .ok v => some s!"ok {v}"
    | .error code => some s!"error {code}"
  | "round_down", [pn, pd, sn, sd] => do
    let p ← rat pn pd
    let s ← rat sn sd
    some (out (roundDown p s))
  | "round_up", [pn, pd, sn, sd] => do
    let p ← rat pn pd
    let s ← rat sn sd
    some (out (roundUp p s))
  | "round_size", [pn, pd, sn, sd] => do
    let p ← rat pn pd
    let s ← rat sn sd
    some (out (roundSize p s))
  | "grid_step", [figures, decimals, pn, pd] => do
    let f ← figures.toNat?
    let dec ← decimals.toInt?
    let p ← rat pn pd
    some (out (gridStep f dec p))
  | "on_grid", [figures, decimals, pn, pd] => do
    let f ← figures.toNat?
    let dec ← decimals.toInt?
    let p ← rat pn pd
    some (toString (onGrid f dec p))
  | "round_price_buy", [figures, decimals, pn, pd] => do
    let f ← figures.toNat?
    let dec ← decimals.toInt?
    let p ← rat pn pd
    some (out (roundPriceBuy f dec p))
  | "round_price_sell", [figures, decimals, pn, pd] => do
    let f ← figures.toNat?
    let dec ← decimals.toInt?
    let p ← rat pn pd
    some (out (roundPriceSell f dec p))
  | _, _ => none

@[export mm2_exact_call]
def callExported (op : String) (args : String) : String :=
  (call op args).getD "malformed"

end Engine.Exact
