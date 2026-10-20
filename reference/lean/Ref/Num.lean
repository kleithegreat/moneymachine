/-!
The number structure the laws quantify over (reference/SEMANTICS.md §1, §5). Every operation the
semantics uses on numbers is a field, so a law proved for every `NumOps` holds for the binary64
instance (`Ref.floatOps`) and for any other. Derived operators are defined here once, from the fields,
exactly as §5 states them.
-/

namespace Ref

structure NumOps (α : Type) where
  add : α → α → α
  sub : α → α → α
  mul : α → α → α
  div : α → α → α
  neg : α → α
  abs : α → α
  log : α → α
  exp : α → α
  sqrt : α → α
  lt : α → α → Bool
  le : α → α → Bool
  eq : α → α → Bool
  /-- x = 0, true for both zeros. -/
  isZero : α → Bool
  /-- Not ±∞ and not NaN. -/
  finite : α → Bool
  zero : α
  one : α
  ofNat : Nat → α
  ofInt : Int → α
  /-- A program constant or conversion factor, given as binary64 bits. -/
  ofBits : UInt64 → α

/-- A node's value: numbers and booleans (1 and 0) alike, `none` when undefined. -/
abbrev Val (α : Type) := Option α

namespace NumOps
variable {α : Type} (N : NumOps α)

def truth (b : Bool) : α := if b then N.one else N.zero
def sign (x : α) : α := if N.lt N.zero x then N.one else if N.lt x N.zero then N.neg N.one else N.zero
def min (a b : α) : α := if N.lt b a then b else a
def max (a b : α) : α := if N.lt a b then b else a
def clip (x lo hi : α) : α := N.min (N.max x lo) hi
def keep (x : α) : Val α := if N.finite x then some x else none

end NumOps
end Ref
