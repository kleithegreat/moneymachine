import Engine.Exact

/-!
# The numbers the float language is stated over (reference/SEMANTICS.md §1, §5)

Every operation the semantics uses on numbers is a field of `NumOps`, so a law proved for every `NumOps` holds
for the binary64 instance (`bitsOps`) and for any other.
-/

namespace Engine.Lang

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
  trunc : α → α
  signBit : α → Bool
  lt : α → α → Bool
  le : α → α → Bool
  eq : α → α → Bool
  isZero : α → Bool
  finite : α → Bool
  zero : α
  one : α
  ofNat : Nat → α
  ofInt : Int → α
  ofBits : UInt64 → α
  toExact : α → Option Rat
  ofExact : Rat → α

namespace NumOps
variable {α : Type} (N : NumOps α)

def truth (b : Bool) : α := if b then N.one else N.zero
def sign (x : α) : α := if N.lt N.zero x then N.one else if N.lt x N.zero then N.neg N.one else N.zero
def isNaN (x : α) : Bool := !N.eq x x
def min (a b : α) : α := if N.isNaN a then b else if N.isNaN b then a else if N.lt b a then b else a
def max (a b : α) : α := if N.isNaN a then b else if N.isNaN b then a else if N.lt a b then b else a
def clip (x lo hi : α) : α := N.min (N.max x lo) hi
def keep (x : α) : Option α := if N.finite x then some x else none

/-- The obligations of R version 1 (kernel/CANONICAL.md) on finite operands. -/
structure Lawful : Prop where
  neg_neg : ∀ x, N.finite x → N.neg (N.neg x) = x
  abs_abs : ∀ x, N.finite x → N.abs (N.abs x) = N.abs x
  abs_neg : ∀ x, N.finite x → N.abs (N.neg x) = N.abs x
  mul_one : ∀ x, N.finite x → N.mul x (N.ofBits 0x3FF0000000000000) = x
  div_one : ∀ x, N.finite x → N.div x (N.ofBits 0x3FF0000000000000) = x
  sub_zero : ∀ x, N.finite x → N.sub x (N.ofBits 0) = x
  add_comm : ∀ x y, N.add x y = N.add y x
  mul_comm : ∀ x y, N.mul x y = N.mul y x
  finite_neg : ∀ x, N.finite x → N.finite (N.neg x)
  finite_abs : ∀ x, N.finite x → N.finite (N.abs x)
  finite_one : N.finite (N.ofBits 0x3FF0000000000000)
  finite_zero : N.finite (N.ofBits 0)
  one_ne_zero : N.isZero (N.ofBits 0x3FF0000000000000) = false
  truth_zero : ∀ b, N.isZero (N.truth b) = !b
  finite_truth : ∀ b, N.finite (N.truth b)

end NumOps

/-- Binary64 carried as its bits: `exp` and `log` are X4's, the crossings are `Exact.decode` and `Exact.nearestBits`, and
`finite` is `decode`'s own test, a magnitude under `infBits`. -/
def bitsOps : NumOps UInt64 where
  add a b := (Float.ofBits a + Float.ofBits b).toBits
  sub a b := (Float.ofBits a - Float.ofBits b).toBits
  mul a b := (Float.ofBits a * Float.ofBits b).toBits
  div a b := (Float.ofBits a / Float.ofBits b).toBits
  neg a := (-Float.ofBits a).toBits
  abs a := (Float.abs (Float.ofBits a)).toBits
  log := Engine.Exact.log
  exp := Engine.Exact.exp
  sqrt a := (Float.sqrt (Float.ofBits a)).toBits
  trunc a := (let x := Float.ofBits a; if x ≥ 0 then x.floor else x.ceil).toBits
  signBit a := a >>> 63 == 1
  lt a b := Float.ofBits a < Float.ofBits b
  le a b := Float.ofBits a ≤ Float.ofBits b
  eq a b := Float.ofBits a == Float.ofBits b
  isZero a := Float.ofBits a == 0
  finite a := decide (a.toNat % 2 ^ 63 < Engine.Exact.infBits)
  zero := (0 : Float).toBits
  one := (1 : Float).toBits
  ofNat n := (Float.ofNat n).toBits
  ofInt n := (Float.ofInt n).toBits
  ofBits b := b
  toExact := Engine.Exact.decode
  ofExact := Engine.Exact.nearestBits

end Engine.Lang
