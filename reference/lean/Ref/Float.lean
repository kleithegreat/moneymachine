import Ref.Num

/-!
The executable instance: IEEE-754 binary64, with the C library's `log`, `exp` and `sqrt` (the engine's
libm on this platform).
-/

namespace Ref

def floatOps : NumOps Float where
  add := (· + ·)
  sub := (· - ·)
  mul := (· * ·)
  div := (· / ·)
  neg := (- ·)
  abs := Float.abs
  log := Float.log
  exp := Float.exp
  sqrt := Float.sqrt
  trunc := fun x => if x ≥ 0 then x.floor else x.ceil
  signBit := fun x => x.toBits >>> 63 == 1
  lt := (· < ·)
  le := (· ≤ ·)
  eq := (· == ·)
  isZero := (· == 0)
  finite := Float.isFinite
  zero := 0
  one := 1
  ofNat := Float.ofNat
  ofInt := Float.ofInt
  ofBits := Float.ofBits

end Ref
