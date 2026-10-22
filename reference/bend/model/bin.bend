import Base

# Binary naturals, least significant bit first. Magnitudes and times are 64-bit values, which unary Nat
# cannot carry: the checker would expand them. Zero may have leading-zero forms; every operation reads
# values, never forms.
type Bin is Data:
  BE{}
  B0{h: Bin}
  B1{h: Bin}

def succ(+a: Bin) -> Bin:
  match a:
    case BE{}:
      B1{BE{}}
    case B0{h}:
      B1{h}
    case B1{h}:
      B0{succ(h)}

def of_nat(+n: Nat) -> Bin:
  match n:
    case 0n:
      BE{}
    case 1n+p:
      succ(of_nat(p))

def add(+a: Bin, +b: Bin) -> Bin:
  match a:
    case BE{}:
      b
    case B0{x}:
      match b:
        case BE{}:
          B0{x}
        case B0{y}:
          B0{add(x, y)}
        case B1{y}:
          B1{add(x, y)}
    case B1{x}:
      match b:
        case BE{}:
          B1{x}
        case B0{y}:
          B1{add(x, y)}
        case B1{y}:
          B0{succ(add(x, y))}

def is_zero(+a: Bin) -> Bool:
  match a:
    case BE{}:
      True{}
    case B0{h}:
      is_zero(h)
    case B1{h}:
      False{}

def low(+c: Cmp, +below: Cmp) -> Cmp:
  match c:
    case EQ{}:
      below
    case LT{}:
      LT{}
    case GT{}:
      GT{}

def cmp(+a: Bin, +b: Bin) -> Cmp:
  match a:
    case BE{}:
      Bool.pick(Cmp, is_zero(b), EQ{}, LT{})
    case B0{x}:
      match b:
        case BE{}:
          Bool.pick(Cmp, is_zero(x), EQ{}, GT{})
        case B0{y}:
          cmp(x, y)
        case B1{y}:
          low(cmp(x, y), LT{})
    case B1{x}:
      match b:
        case BE{}:
          GT{}
        case B0{y}:
          low(cmp(x, y), GT{})
        case B1{y}:
          cmp(x, y)

def is_lt_c(+c: Cmp) -> Bool:
  match c:
    case LT{}:
      True{}
    case _:
      False{}

def is_eq_c(+c: Cmp) -> Bool:
  match c:
    case EQ{}:
      True{}
    case _:
      False{}

def lt(+a: Bin, +b: Bin) -> Bool:
  is_lt_c(cmp(a, b))

def eq(+a: Bin, +b: Bin) -> Bool:
  is_eq_c(cmp(a, b))

def le(+a: Bin, +b: Bin) -> Bool:
  Bool.not(lt(b, a))

# Truncated subtraction (0 when b > a), with a borrow.
def sub_b(+a: Bin, +b: Bin, +borrow: Bool) -> Bin:
  match a:
    case BE{}:
      BE{}
    case B0{x}:
      match b:
        case BE{}:
          match borrow:
            case False{}:
              B0{x}
            case True{}:
              B1{sub_b(x, BE{}, True{})}
        case B0{y}:
          match borrow:
            case False{}:
              B0{sub_b(x, y, False{})}
            case True{}:
              B1{sub_b(x, y, True{})}
        case B1{y}:
          match borrow:
            case False{}:
              B1{sub_b(x, y, True{})}
            case True{}:
              B0{sub_b(x, y, True{})}
    case B1{x}:
      match b:
        case BE{}:
          match borrow:
            case False{}:
              B1{x}
            case True{}:
              B0{x}
        case B0{y}:
          match borrow:
            case False{}:
              B1{sub_b(x, y, False{})}
            case True{}:
              B0{sub_b(x, y, False{})}
        case B1{y}:
          match borrow:
            case False{}:
              B0{sub_b(x, y, False{})}
            case True{}:
              B1{sub_b(x, y, True{})}

def sub(+a: Bin, +b: Bin) -> Bin:
  Bool.pick(Bin, lt(a, b), BE{}, sub_b(a, b, False{}))

def mul(+a: Bin, +b: Bin) -> Bin:
  match a:
    case BE{}:
      BE{}
    case B0{x}:
      B0{mul(x, b)}
    case B1{x}:
      add(B0{mul(x, b)}, b)

type QR is Data:
  QR{q: Bin, r: Bin}

# One step of long division: the remainder doubled plus a bit, against the divisor.
def qr_step(+bit: Bool, +b: Bin, +qr: QR) -> QR:
  match qr:
    case QR{q, r}:
      +r2 = Bool.pick(Bin, bit, B1{r}, B0{r})
      Bool.pick(QR, le(b, r2), QR{B1{q}, sub(r2, b)}, QR{B0{q}, r2})

def divmod(+a: Bin, +b: Bin) -> QR:
  match a:
    case BE{}:
      QR{BE{}, BE{}}
    case B0{x}:
      qr_step(False{}, b, divmod(x, b))
    case B1{x}:
      qr_step(True{}, b, divmod(x, b))

def qr_q(+qr: QR) -> Bin:
  match qr:
    case QR{q, r}:
      q

def qr_r(+qr: QR) -> Bin:
  match qr:
    case QR{q, r}:
      r

# a / b and a % b, truncating; b = 0 gives 0 and a.
def div(+a: Bin, +b: Bin) -> Bin:
  Bool.pick(Bin, is_zero(b), BE{}, qr_q(divmod(a, b)))

def mod(+a: Bin, +b: Bin) -> Bin:
  Bool.pick(Bin, is_zero(b), a, qr_r(divmod(a, b)))

def pow2(+k: Nat) -> Bin:
  match k:
    case 0n:
      B1{BE{}}
    case 1n+p:
      B0{pow2(p)}

def pow(+a: Bin, +k: Nat) -> Bin:
  match k:
    case 0n:
      B1{BE{}}
    case 1n+p:
      mul(a, pow(a, p))

# Bin to Nat, for counts that are small (step counts, indices).
def to_nat(+a: Bin) -> Nat:
  match a:
    case BE{}:
      0n
    case B0{h}:
      Nat.double(to_nat(h))
    case B1{h}:
      1n+Nat.double(to_nat(h))

def shift8(+a: Bin) -> Bin:
  B0{B0{B0{B0{B0{B0{B0{B0{a}}}}}}}}

# A 64-bit word from its eight bytes, most significant first.
def word(+b7: Nat, +b6: Nat, +b5: Nat, +b4: Nat, +b3: Nat, +b2: Nat, +b1: Nat, +b0: Nat) -> Bin:
  add(shift8(add(shift8(add(shift8(add(shift8(add(shift8(add(shift8(add(shift8(of_nat(b7)), of_nat(b6))), of_nat(b5))), of_nat(b4))), of_nat(b3))), of_nat(b2))), of_nat(b1))), of_nat(b0))
