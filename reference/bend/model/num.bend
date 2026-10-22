import Base
import ./bin.bend as B

# The concrete exact number type the Bend laws are stated over (FINDINGS.md, human decision of
# 2026-10-21): integers with a sign bit, so +0 and -0 differ as in binary64, plus the infinities and NaN,
# with binary magnitudes (bin.bend). Every operation of the Lean model's NumOps is total here. L1, L4 and
# L5 are structural, so they hold for this one instance; they are weaker than the Lean laws, which hold
# for every NumOps.
type Num is Data:
  NaN{}
  Fin{neg: Bool, mag: B.Bin}
  Inf{neg: Bool}

type Z is Data:
  Z{neg: Bool, mag: B.Bin}

def zero() -> Num:
  Fin{False{}, B.BE{}}

def one() -> Num:
  Fin{False{}, B.B1{B.BE{}}}

def of_nat(+n: Nat) -> Num:
  Fin{False{}, B.of_nat(n)}

def of_bin(+n: B.Bin) -> Num:
  Fin{False{}, n}

def of_z(+z: Z) -> Num:
  match z:
    case Z{neg, mag}:
      Fin{neg, mag}

def neg(+x: Num) -> Num:
  match x:
    case NaN{}:
      NaN{}
    case Fin{neg, mag}:
      Fin{Bool.not(neg), mag}
    case Inf{neg}:
      Inf{Bool.not(neg)}

def abs(+x: Num) -> Num:
  match x:
    case NaN{}:
      NaN{}
    case Fin{neg, mag}:
      Fin{False{}, mag}
    case Inf{neg}:
      Inf{False{}}

# Signed magnitude sum: a - b when the signs differ.
def diff(+a: B.Bin, +b: B.Bin) -> Num:
  Bool.pick(Num, B.le(b, a), Fin{False{}, B.sub(a, b)}, Fin{True{}, B.sub(b, a)})

def signed_sum(+an: Bool, +a: B.Bin, +bn: Bool, +b: B.Bin) -> Num:
  match an:
    case False{}:
      match bn:
        case False{}:
          Fin{False{}, B.add(a, b)}
        case True{}:
          diff(a, b)
    case True{}:
      match bn:
        case True{}:
          Fin{True{}, B.add(a, b)}
        case False{}:
          diff(b, a)

def add(+x: Num, +y: Num) -> Num:
  match x:
    case NaN{}:
      NaN{}
    case Inf{neg}:
      match y:
        case NaN{}:
          NaN{}
        case Fin{yn, ym}:
          Inf{neg}
        case Inf{yn}:
          Bool.pick(Num, Bool.xor(neg, yn), NaN{}, Inf{neg})
    case Fin{neg, mag}:
      match y:
        case NaN{}:
          NaN{}
        case Inf{yn}:
          Inf{yn}
        case Fin{yn, ym}:
          signed_sum(neg, mag, yn, ym)

def sub(+x: Num, +y: Num) -> Num:
  add(x, neg(y))

def mul(+x: Num, +y: Num) -> Num:
  match x:
    case NaN{}:
      NaN{}
    case Inf{neg}:
      match y:
        case NaN{}:
          NaN{}
        case Inf{yn}:
          Inf{Bool.xor(neg, yn)}
        case Fin{yn, ym}:
          Bool.pick(Num, B.is_zero(ym), NaN{}, Inf{Bool.xor(neg, yn)})
    case Fin{neg, mag}:
      match y:
        case NaN{}:
          NaN{}
        case Inf{yn}:
          Bool.pick(Num, B.is_zero(mag), NaN{}, Inf{Bool.xor(neg, yn)})
        case Fin{yn, ym}:
          Fin{Bool.xor(neg, yn), B.mul(mag, ym)}

# Truncating division; x/0 is NaN for x = 0 and a signed infinity otherwise; finite/inf is 0.
def div(+x: Num, +y: Num) -> Num:
  match x:
    case NaN{}:
      NaN{}
    case Inf{neg}:
      match y:
        case NaN{}:
          NaN{}
        case Inf{yn}:
          NaN{}
        case Fin{yn, ym}:
          Inf{Bool.xor(neg, yn)}
    case Fin{neg, mag}:
      match y:
        case NaN{}:
          NaN{}
        case Inf{yn}:
          Fin{Bool.xor(neg, yn), B.BE{}}
        case Fin{yn, ym}:
          Bool.pick(Num, B.is_zero(ym),
            Bool.pick(Num, B.is_zero(mag), NaN{}, Inf{Bool.xor(neg, yn)}),
            Fin{Bool.xor(neg, yn), B.div(mag, ym)})

def is_nan(+x: Num) -> Bool:
  match x:
    case NaN{}:
      True{}
    case Fin{neg, mag}:
      False{}
    case Inf{neg}:
      False{}

def finite(+x: Num) -> Bool:
  match x:
    case NaN{}:
      False{}
    case Fin{neg, mag}:
      True{}
    case Inf{neg}:
      False{}

def is_zero(+x: Num) -> Bool:
  match x:
    case NaN{}:
      False{}
    case Fin{neg, mag}:
      B.is_zero(mag)
    case Inf{neg}:
      False{}

def sign_bit(+x: Num) -> Bool:
  match x:
    case NaN{}:
      False{}
    case Fin{neg, mag}:
      neg
    case Inf{neg}:
      neg

# Order on signed magnitudes, with -0 = +0.
def lt_fin(+an: Bool, +a: B.Bin, +bn: Bool, +b: B.Bin) -> Bool:
  match an:
    case False{}:
      match bn:
        case False{}:
          B.lt(a, b)
        case True{}:
          False{}
    case True{}:
      match bn:
        case True{}:
          B.lt(b, a)
        case False{}:
          Bool.not(Bool.and(B.is_zero(a), B.is_zero(b)))

def eq_fin(+an: Bool, +a: B.Bin, +bn: Bool, +b: B.Bin) -> Bool:
  Bool.pick(Bool, B.is_zero(a), B.is_zero(b), Bool.and(Bool.not(Bool.xor(an, bn)), B.eq(a, b)))

def lt(+x: Num, +y: Num) -> Bool:
  match x:
    case NaN{}:
      False{}
    case Inf{neg}:
      match neg:
        case False{}:
          False{}
        case True{}:
          match y:
            case NaN{}:
              False{}
            case Fin{yn, ym}:
              True{}
            case Inf{yn}:
              Bool.not(yn)
    case Fin{neg, mag}:
      match y:
        case NaN{}:
          False{}
        case Inf{yn}:
          Bool.not(yn)
        case Fin{yn, ym}:
          lt_fin(neg, mag, yn, ym)

def eq(+x: Num, +y: Num) -> Bool:
  match x:
    case NaN{}:
      False{}
    case Inf{neg}:
      match y:
        case NaN{}:
          False{}
        case Fin{yn, ym}:
          False{}
        case Inf{yn}:
          Bool.not(Bool.xor(neg, yn))
    case Fin{neg, mag}:
      match y:
        case NaN{}:
          False{}
        case Inf{yn}:
          False{}
        case Fin{yn, ym}:
          eq_fin(neg, mag, yn, ym)

def le(+x: Num, +y: Num) -> Bool:
  Bool.or(lt(x, y), eq(x, y))

# Transcendentals: any total functions serve the structural laws; these keep finiteness.
def log(+x: Num) -> Num:
  x

def exp(+x: Num) -> Num:
  x

def sqrt(+x: Num) -> Num:
  x

def trunc(+x: Num) -> Num:
  x

# A program constant's binary64 bits, read as an integer.
def of_bits(+bits: B.Bin) -> Num:
  Fin{False{}, bits}

# Times (ms), which the model keeps as integers.
def z(+n: Nat) -> Z:
  Z{False{}, B.of_nat(n)}

def zneg(+a: Z) -> Z:
  match a:
    case Z{neg, mag}:
      Z{Bool.not(neg), mag}

def zdiff(+a: B.Bin, +b: B.Bin) -> Z:
  Bool.pick(Z, B.le(b, a), Z{False{}, B.sub(a, b)}, Z{True{}, B.sub(b, a)})

def zsum(+an: Bool, +am: B.Bin, +bn: Bool, +bm: B.Bin) -> Z:
  match an:
    case False{}:
      match bn:
        case False{}:
          Z{False{}, B.add(am, bm)}
        case True{}:
          zdiff(am, bm)
    case True{}:
      match bn:
        case True{}:
          Z{True{}, B.add(am, bm)}
        case False{}:
          zdiff(bm, am)

def zadd(+a: Z, +b: Z) -> Z:
  match a:
    case Z{an, am}:
      match b:
        case Z{bn, bm}:
          zsum(an, am, bn, bm)

def zsub(+a: Z, +b: Z) -> Z:
  zadd(a, zneg(b))

def zmul(+a: Z, +b: Z) -> Z:
  match a:
    case Z{an, am}:
      match b:
        case Z{bn, bm}:
          Z{Bool.xor(an, bn), B.mul(am, bm)}

def zlt(+a: Z, +b: Z) -> Bool:
  match a:
    case Z{an, am}:
      match b:
        case Z{bn, bm}:
          lt_fin(an, am, bn, bm)

def zeq(+a: Z, +b: Z) -> Bool:
  match a:
    case Z{an, am}:
      match b:
        case Z{bn, bm}:
          eq_fin(an, am, bn, bm)

def zle(+a: Z, +b: Z) -> Bool:
  Bool.or(zlt(a, b), zeq(a, b))

def zmax(+a: Z, +b: Z) -> Z:
  Bool.pick(Z, zlt(a, b), b, a)

# Truncating division and remainder; the model divides only nonnegative times by HOUR and BAR.
def zdiv(+a: Z, +b: Z) -> Z:
  match a:
    case Z{an, am}:
      match b:
        case Z{bn, bm}:
          Z{Bool.xor(an, bn), B.div(am, bm)}

def zmod(+a: Z, +b: Z) -> Z:
  match a:
    case Z{an, am}:
      match b:
        case Z{bn, bm}:
          Z{an, B.mod(am, bm)}

def z_to_nat(+a: Z) -> Nat:
  match a:
    case Z{neg, mag}:
      Bool.pick(Nat, neg, 0n, B.to_nat(mag))

def HOUR() -> Z:
  Z{False{}, B.mul(B.of_nat(3600n), B.of_nat(1000n))}

def BAR() -> Z:
  Z{False{}, B.mul(B.of_nat(4n), B.mul(B.of_nat(3600n), B.of_nat(1000n)))}
