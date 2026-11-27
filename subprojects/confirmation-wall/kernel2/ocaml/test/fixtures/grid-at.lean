/- Step 3 test 8. Requires Engine.Exact.onGridAt : Nat → Int → Nat → Int → Bool.
   Calls the actual Lean functions, not an extra test FFI or a second grid.
   price_grid's ranges are the step-1 test's 336,000 (rules,price) cases. -/
import Engine.Exact

open Engine.Exact

def checkGridAt (figures : Nat) (decimals : Int) (scale : Nat) (n : Int) : IO Unit := do
  let price : Rat := (n : Rat) / (10 : Rat) ^ scale
  unless onGridAt figures decimals scale n == onGrid figures decimals price do
    throw (IO.userError "onGridAt differs from onGrid")

#eval show IO Unit from do
  let cases : List (Nat × List Int × Nat) :=
    [(1, [-1, 0, 1, 2], 12000), (2, [-1, 0, 1, 2], 12000),
     (3, [0, 1], 120000)]
  let mut prices : Nat := 0
  let mut comparisons : Nat := 0
  for (figures, decimalsTried, top) in cases do
    for decimals in decimalsTried do
      for hundredths in [1:top + 1] do
        prices := prices + 1
        for scale in [0:13] do
          let units : Nat := hundredths * 10 ^ scale
          if units % 100 == 0 then
            checkGridAt figures decimals scale (Int.ofNat (units / 100))
            comparisons := comparisons + 1
  unless prices == 336000 && comparisons > 336000 do
    throw (IO.userError "incomplete price_grid coverage")
  for figures in ([0, 1, 5] : List Nat) do
    for decimals in ([-12, -1, 0, 1, 8, 12] : List Int) do
      for scale in [0:13] do
        for n in ([0, -1, -(10 ^ scale)] : List Int) do
          checkGridAt figures decimals scale n
          unless !(onGridAt figures decimals scale n) &&
              !(onGrid figures decimals ((n : Rat) / (10 : Rat) ^ scale)) do
            throw (IO.userError "nonpositive price is on a grid")
  for scale in ([13, 24] : List Nat) do
    for n in ([0, -1, 1, 10 ^ 40] : List Int) do
      checkGridAt 0 (-1) scale n
      checkGridAt 5 8 scale n
  IO.println s!"step3_8_grid_at: {prices} prices, {comparisons} integral-scale comparisons"
