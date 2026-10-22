import Base

# The concrete exact number type the Bend laws are stated over (FINDINGS.md, human decision of
# 2026-10-21): integers with a sign bit, so +0 and -0 differ as in binary64, plus the infinities and NaN.
# Every operation of the Lean model's NumOps is total here. L1, L4 and L5 are structural, so they hold
# for this one instance; they are weaker than the Lean laws, which hold for every NumOps.
type Num is Data:
  NaN{}
  Fin{neg: Bool, mag: Nat}
  Inf{neg: Bool}

type Z is Data:
  Z{neg: Bool, mag: Nat}

def zero() -> Num:
  Fin{False{}, 0n}

def one() -> Num:
  Fin{False{}, 1n}

def of_nat(n: Nat) -> Num:
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
def diff(+a: Nat, +b: Nat) -> Num:
  Bool.pick(Num, Nat.is_ge(a, b), Fin{False{}, Nat.sub(a, b)}, Fin{True{}, Nat.sub(b, a)})

def signed_sum(+an: Bool, +a: Nat, +bn: Bool, +b: Nat) -> Num:
  match an:
    case False{}:
      match bn:
        case False{}:
          Fin{False{}, Nat.add(a, b)}
        case True{}:
          diff(a, b)
    case True{}:
      match bn:
        case True{}:
          Fin{True{}, Nat.add(a, b)}
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
          Bool.pick(Num, Nat.is_eq(ym, 0n), NaN{}, Inf{Bool.xor(neg, yn)})
    case Fin{neg, mag}:
      match y:
        case NaN{}:
          NaN{}
        case Inf{yn}:
          Bool.pick(Num, Nat.is_eq(mag, 0n), NaN{}, Inf{Bool.xor(neg, yn)})
        case Fin{yn, ym}:
          Fin{Bool.xor(neg, yn), Nat.mul(mag, ym)}

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
          Fin{Bool.xor(neg, yn), 0n}
        case Fin{yn, ym}:
          Bool.pick(Num, Nat.is_eq(ym, 0n),
            Bool.pick(Num, Nat.is_eq(mag, 0n), NaN{}, Inf{Bool.xor(neg, yn)}),
            Fin{Bool.xor(neg, yn), Nat.div(mag, ym)})

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
      Nat.is_eq(mag, 0n)
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

# A real-number key for ordering: (rank, magnitude), with -inf < negatives < 0 < positives < +inf.
def lt_fin(+an: Bool, +a: Nat, +bn: Bool, +b: Nat) -> Bool:
  match an:
    case False{}:
      match bn:
        case False{}:
          Nat.is_lt(a, b)
        case True{}:
          False{}
    case True{}:
      match bn:
        case True{}:
          Nat.is_lt(b, a)
        case False{}:
          Bool.not(Bool.and(Nat.is_eq(a, 0n), Nat.is_eq(b, 0n)))

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
          Bool.pick(Bool, Nat.is_eq(mag, 0n), Nat.is_eq(ym, 0n), Bool.and(Bool.not(Bool.xor(neg, yn)), Nat.is_eq(mag, ym)))

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
def of_bits(bits: Nat) -> Num:
  Fin{False{}, bits}

# Times (ms), which the model keeps as integers.
def z(n: Nat) -> Z:
  Z{False{}, n}

def zneg(+a: Z) -> Z:
  match a:
    case Z{neg, mag}:
      Z{Bool.not(neg), mag}

def zdiff(+a: Nat, +b: Nat) -> Z:
  Bool.pick(Z, Nat.is_ge(a, b), Z{False{}, Nat.sub(a, b)}, Z{True{}, Nat.sub(b, a)})

def zsum(+an: Bool, +am: Nat, +bn: Bool, +bm: Nat) -> Z:
  match an:
    case False{}:
      match bn:
        case False{}:
          Z{False{}, Nat.add(am, bm)}
        case True{}:
          zdiff(am, bm)
    case True{}:
      match bn:
        case True{}:
          Z{True{}, Nat.add(am, bm)}
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
          Z{Bool.xor(an, bn), Nat.mul(am, bm)}

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
          Bool.pick(Bool, Nat.is_eq(am, 0n), Nat.is_eq(bm, 0n), Bool.and(Bool.not(Bool.xor(an, bn)), Nat.is_eq(am, bm)))

def zle(+a: Z, +b: Z) -> Bool:
  Bool.or(zlt(a, b), zeq(a, b))

def zmax(+a: Z, +b: Z) -> Z:
  Bool.pick(Z, zlt(a, b), b, a)

# Truncating division, as Lean's Int `/` is not; the model only divides nonnegative times by HOUR.
def zdiv(+a: Z, +b: Z) -> Z:
  match a:
    case Z{an, am}:
      match b:
        case Z{bn, bm}:
          Z{Bool.xor(an, bn), Nat.div(am, bm)}

def zmod(+a: Z, +b: Z) -> Z:
  match a:
    case Z{an, am}:
      match b:
        case Z{bn, bm}:
          Z{an, Nat.mod(am, bm)}

def HOUR() -> Z:
  Z{False{}, 3600000n}

def BAR() -> Z:
  Z{False{}, 14400000n}
