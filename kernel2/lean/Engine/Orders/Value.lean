/-!
# What a slot wishes (KERNEL.md A17; kernel-v2.md A5, A6)

The part of the orders' records the expression evaluator produces, so that `Engine.Lang` can name it before the
machine that places orders exists.
-/

namespace Engine.Orders

inductive Side where
  | buy
  | sell
  deriving DecidableEq, Repr, Inhabited

inductive Tif where
  | gtc
  | alo
  | ioc
  deriving DecidableEq, Repr, Inhabited

/-- A wish's value: an exact price and a target; `target = none` is `close`. A notional has already been divided
by the slot's unrounded exact price. -/
structure Value where
  price : Rat
  target : Option Rat
  deriving DecidableEq, Repr, Inhabited

/-- One tick's unrounded slot values `(coin, slot, value)`, including inactive ones (`none`), and every evaluated
`when` and `exact(·)` value `(coin, node-or-slot, …)`. -/
structure SlotEval where
  wishes : List (Nat × Nat × Option Value)
  whenValues : List (Nat × Nat × Option Bool)
  exactValues : List (Nat × Nat × Option Rat)
  deriving DecidableEq, Repr

end Engine.Orders
