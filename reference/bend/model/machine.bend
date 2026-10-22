import Base
import ./bin.bend as B
import ./num.bend as N

# The causal machine (reference/SEMANTICS.md §3–§6), ported from the Lean model's Ref/Machine.lean
# definition for definition over the concrete number type of num.bend.

# xs[i]! with the default d out of range.
def at(-A: Data, +xs: +List<A>, +i: Nat, +d: A) -> A:
  match xs:
    case Nil{}:
      d
    case Con{h, t}:
      match i:
        case 0n:
          h
        case 1n+p:
          at(A, t, p, d)

# xs.set! i x: unchanged out of range.
def put(-A: Data, +xs: +List<A>, +i: Nat, +x: A) -> List<&2, A>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      match i:
        case 0n:
          Con{x, t}
        case 1n+p:
          Con{h, put(A, t, p, x)}

def len(-A: Data, +xs: +List<A>) -> Nat:
  List.length(&2, A, xs)

def snoc(-A: Data, +xs: +List<A>, +x: A) -> List<&2, A>:
  List.append(&2, A, xs, Con{x, Nil{}})

def rep(-A: Data, +n: Nat, +x: A) -> List<&2, A>:
  List.replicate(A, n, x)

type FundingRow is Data:
  FundingRow{coin: Nat, event: N.Z, known: N.Z, rate: N.Num, premium: N.Num}

type BarRow is Data:
  BarRow{coin: Nat, open_time: N.Z, event: N.Z, known: N.Z, o: N.Num, h: N.Num, l: N.Num, c: N.Num, v: N.Num, trades: N.Z}

type EventRow is Data:
  EventRow{slot: Nat, coin: Nat, event: N.Z, known: N.Z, count: N.Num}

type WKind is Data:
  Lag{}
  Mean{}
  Sum{}
  Std{}
  MinOver{}
  MaxOver{}
  Ema{}

type Input is Data:
  IFunding{}
  IPremium{}
  IOpen{}
  IHigh{}
  ILow{}
  IClose{}
  IVolume{}
  IEvent{slot: Nat}

type Op is Data:
  Add{}
  Sub{}
  Mul{}
  Div{}
  OMin{}
  OMax{}
  ONeg{}
  OAbs{}
  OSign{}
  OLog{}
  OExp{}
  OSqrt{}
  Clip{}
  Gt{}
  Ge{}
  Lt{}
  Le{}
  And{}
  Or{}
  Not{}
  Ite{}
  Convert{factor: B.Bin}
  OWindow{w: WKind, hours: Nat}
  XsMean{}
  XsDemean{}
  XsRank{}
  HoursSince{}

type Node is Data:
  NInput{i: Input}
  NConst{bits: B.Bin}
  NParam{k: Nat}
  NOp{o: Op, args: List<&2, Nat>}

# The parts of a checked program the machine and the simulator read: types and units only gate the
# checker, which the laws take as given.
type Program is Data:
  Program{nodes: List<&2, Node>, params: List<&2, B.Bin>, weight: Nat}

# A value: Some number, or None (undefined).
type Val is Data:
  VNone{}
  VSome{x: N.Num}

type Slot is Data:
  Slot{seq: Nat, x: N.Num}

type Win is Data:
  WLag{k: Nat, buf: List<&2, Val>}
  WSums{kind: WKind, n: Nat, buf: List<&2, Val>, sum: N.Num, sumsq: N.Num, nones: Nat, since: Nat}
  WExtreme{is_max: Bool, n: Nat, seq: Nat, last_none: Maybe<&2, Nat>, dq: List<&2, Slot>}
  WEma{n: Nat, alpha: N.Num, s: N.Num, seen: Nat}

type Pushed is Data:
  Pushed{w: Win, out: Val}

def win_new(+w: WKind, +n: Nat) -> Win:
  match w:
    case Lag{}:
      WLag{n, Nil{}}
    case MinOver{}:
      WExtreme{False{}, n, 0n, None{}, Nil{}}
    case MaxOver{}:
      WExtreme{True{}, n, 0n, None{}, Nil{}}
    case Ema{}:
      WEma{n, N.div(N.of_nat(2n), N.add(N.of_nat(n), N.one())), N.zero(), 0n}
    case Mean{}:
      WSums{Mean{}, n, Nil{}, N.zero(), N.zero(), 0n, 0n}
    case Sum{}:
      WSums{Sum{}, n, Nil{}, N.zero(), N.zero(), 0n, 0n}
    case Std{}:
      WSums{Std{}, n, Nil{}, N.zero(), N.zero(), 0n, 0n}

# Σ as the left fold from −0 (SEMANTICS.md §1).
def total_go(+xs: +List<N.Num>, +acc: N.Num) -> N.Num:
  match xs:
    case Nil{}:
      acc
    case Con{h, t}:
      total_go(t, N.add(acc, h))

def total(+xs: +List<N.Num>) -> N.Num:
  total_go(xs, N.neg(N.zero()))

# The engine's f64::max/min: a NaN operand yields the other; a tie yields the first.
def nmax(+a: N.Num, +b: N.Num) -> N.Num:
  Bool.pick(N.Num, N.is_nan(a), b, Bool.pick(N.Num, N.is_nan(b), a, Bool.pick(N.Num, N.lt(a, b), b, a)))

def nmin(+a: N.Num, +b: N.Num) -> N.Num:
  Bool.pick(N.Num, N.is_nan(a), b, Bool.pick(N.Num, N.is_nan(b), a, Bool.pick(N.Num, N.lt(b, a), b, a)))

def defined(+xs: +List<Val>) -> List<&2, N.Num>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      match h:
        case VNone{}:
          defined(t)
        case VSome{x}:
          Con{x, defined(t)}

def squares(+xs: +List<N.Num>) -> List<&2, N.Num>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      Con{N.mul(h, h), squares(t)}

def head_val(+xs: +List<Val>) -> Val:
  at(Val, xs, 0n, VNone{})

def push_lag(+k: Nat, +buf: +List<Val>, +x: Val) -> Pushed:
  +b0 = snoc(Val, buf, x)
  +b = Bool.pick(List<&2, Val>, Nat.is_gt(len(Val, b0), 1n+k), List.tail(&2, Val, b0), b0)
  Pushed{WLag{k, b}, Bool.pick(Val, Nat.is_eq(len(Val, b), 1n+k), head_val(b), VNone{})}

type Acc is Data:
  Acc{buf: List<&2, Val>, sum: N.Num, sumsq: N.Num, nones: Nat}

def acc_in(+x: Val, +a: Acc) -> Acc:
  match x:
    case VSome{v}:
      match a:
        case Acc{buf, sum, sumsq, nones}:
          Acc{snoc(Val, buf, VSome{v}), N.add(sum, v), N.add(sumsq, N.mul(v, v)), nones}
    case VNone{}:
      match a:
        case Acc{buf, sum, sumsq, nones}:
          Acc{snoc(Val, buf, VNone{}), sum, sumsq, 1n+nones}

def acc_out(+first: Val, +a: Acc) -> Acc:
  match first:
    case VSome{v}:
      match a:
        case Acc{buf, sum, sumsq, nones}:
          Acc{List.tail(&2, Val, buf), N.sub(sum, v), N.sub(sumsq, N.mul(v, v)), nones}
    case VNone{}:
      match a:
        case Acc{buf, sum, sumsq, nones}:
          Acc{List.tail(&2, Val, buf), sum, sumsq, Nat.sub(nones, 1n)}

def spread(+n: Nat, +sum: N.Num, +sumsq: N.Num) -> Val:
  +m = N.div(sum, N.of_nat(n))
  VSome{N.sqrt(nmax(N.sub(N.div(sumsq, N.of_nat(n)), N.mul(m, m)), N.zero()))}

def sums_out(+kind: WKind, +n: Nat, +sum: N.Num, +sumsq: N.Num) -> Val:
  match kind:
    case Sum{}:
      VSome{sum}
    case Mean{}:
      VSome{N.div(sum, N.of_nat(n))}
    case Lag{}:
      spread(n, sum, sumsq)
    case Std{}:
      spread(n, sum, sumsq)
    case MinOver{}:
      spread(n, sum, sumsq)
    case MaxOver{}:
      spread(n, sum, sumsq)
    case Ema{}:
      spread(n, sum, sumsq)

def push_sums_fin(+kind: WKind, +n: Nat, +a: Acc, +since0: Nat) -> Pushed:
  match a:
    case Acc{b, sum0, sumsq0, nones}:
      +since1 = Nat.add(1n, since0)
      +reset = Nat.is_ge(since1, n)
      +ds = defined(b)
      +since = Bool.pick(Nat, reset, 0n, since1)
      +sum = Bool.pick(N.Num, reset, total(ds), sum0)
      +sumsq = Bool.pick(N.Num, reset, total(squares(ds)), sumsq0)
      +out = Bool.pick(Val, Bool.or(Nat.is_lt(len(Val, b), n), Nat.is_gt(nones, 0n)), VNone{}, sums_out(kind, n, sum, sumsq))
      Pushed{WSums{kind, n, b, sum, sumsq, nones, since}, out}

def push_sums_trim(+kind: WKind, +n: Nat, +since: Nat, +a: Acc) -> Pushed:
  match a:
    case Acc{b, s, q, k}:
      push_sums_fin(kind, n, Bool.pick(Acc, Nat.is_gt(len(Val, b), n), acc_out(head_val(b), Acc{b, s, q, k}), Acc{b, s, q, k}), since)

def push_sums(+kind: WKind, +n: Nat, +buf: +List<Val>, +sum: N.Num, +sumsq: N.Num, +nones: Nat, +since: Nat, +x: Val) -> Pushed:
  push_sums_trim(kind, n, since, acc_in(x, Acc{buf, sum, sumsq, nones}))

# dq with its dominated tail removed: the reversed list's prefix of dominated entries is dropped.
def dominated(+is_max: Bool, +e: Slot, +v: N.Num) -> Bool:
  match e:
    case Slot{seq, x}:
      Bool.pick(Bool, is_max, N.le(x, v), N.le(v, x))

def drop_dominated(+is_max: Bool, +rdq: +List<Slot>, +v: N.Num) -> List<&2, Slot>:
  match rdq:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      Bool.pick(List<&2, Slot>, dominated(is_max, h, v), drop_dominated(is_max, t, v), Con{h, t})

def stale(+e: Slot, +n: Nat, +seq: Nat) -> Bool:
  match e:
    case Slot{s, x}:
      Nat.is_le(Nat.add(s, n), seq)

def drop_stale(+dq: +List<Slot>, +n: Nat, +seq: Nat) -> List<&2, Slot>:
  match dq:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      Bool.pick(List<&2, Slot>, stale(h, n, seq), drop_stale(t, n, seq), Con{h, t})

def slot_x(+e: Slot) -> N.Num:
  match e:
    case Slot{s, x}:
      x

def dq_head(+dq: +List<Slot>) -> Val:
  match dq:
    case Nil{}:
      VNone{}
    case Con{h, t}:
      VSome{slot_x(h)}

def recent_none(+last_none: Maybe<&2, Nat>, +n: Nat, +seq: Nat) -> Bool:
  match last_none:
    case None{}:
      False{}
    case Some{s}:
      Nat.is_gt(Nat.add(s, n), seq)

def push_extreme_fin(+is_max: Bool, +n: Nat, +seq: Nat, +last_none: Maybe<&2, Nat>, +dq0: +List<Slot>) -> Pushed:
  +dq = drop_stale(dq0, n, seq)
  +out = Bool.pick(Val, Bool.or(Nat.is_lt(seq, n), recent_none(last_none, n, seq)), VNone{}, dq_head(dq))
  Pushed{WExtreme{is_max, n, seq, last_none, dq}, out}

def push_extreme(+is_max: Bool, +n: Nat, +seq0: Nat, +last_none: Maybe<&2, Nat>, +dq: +List<Slot>, +x: Val) -> Pushed:
  match x:
    case VNone{}:
      push_extreme_fin(is_max, n, 1n+seq0, Some{1n+seq0}, dq)
    case VSome{v}:
      +kept = List.reverse(&2, Slot, drop_dominated(is_max, List.reverse(&2, Slot, dq), v))
      push_extreme_fin(is_max, n, 1n+seq0, last_none, snoc(Slot, kept, Slot{1n+seq0, v}))

def push_ema(+n: Nat, +alpha: N.Num, +s0: N.Num, +seen0: Nat, +x: Val) -> Pushed:
  match x:
    case VNone{}:
      Pushed{WEma{n, alpha, s0, seen0}, VNone{}}
    case VSome{v}:
      +s = Bool.pick(N.Num, Nat.is_eq(seen0, 0n), v, N.add(N.mul(alpha, v), N.mul(N.sub(N.one(), alpha), s0)))
      +seen = Nat.add(1n, seen0)
      Pushed{WEma{n, alpha, s, seen}, Bool.pick(Val, Nat.is_ge(seen, n), VSome{s}, VNone{})}

def win_push(+w: Win, +x: Val) -> Pushed:
  match w:
    case WLag{k, buf}:
      push_lag(k, buf, x)
    case WSums{kind, n, buf, sum, sumsq, nones, since}:
      push_sums(kind, n, buf, sum, sumsq, nones, since, x)
    case WExtreme{is_max, n, seq, last_none, dq}:
      push_extreme(is_max, n, seq, last_none, dq, x)
    case WEma{n, alpha, s, seen}:
      push_ema(n, alpha, s, seen, x)

type MState is Data:
  MState{vals: List<&2, List<&2, Val>>, wins: List<&2, List<&2, Maybe<&2, Win>>>, since: List<&2, List<&2, Maybe<&2, N.Z>>>, funding: List<&2, Maybe<&2, FundingRow>>, bar: List<&2, Maybe<&2, BarRow>>, events: List<&2, List<&2, Maybe<&2, EventRow>>>, hour: N.Z, max_known: N.Z}

def node_win(+coins: Nat, +nd: Node) -> List<&2, Maybe<&2, Win>>:
  match nd:
    case NOp{o, args}:
      match o:
        case OWindow{w, h}:
          rep(Maybe<&2, Win>, coins, Some{win_new(w, h)})
        case _:
          rep(Maybe<&2, Win>, coins, None{})
    case _:
      rep(Maybe<&2, Win>, coins, None{})

def init_wins(+coins: Nat, +nodes: +List<Node>) -> List<&2, List<&2, Maybe<&2, Win>>>:
  match nodes:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      Con{node_win(coins, h), init_wins(coins, t)}

# Two event inputs: forum_posts and gov_proposals.
def init(+p: Program, +coins: Nat) -> MState:
  match p:
    case Program{nodes, params, weight}:
      MState{rep(List<&2, Val>, len(Node, nodes), rep(Val, coins, VNone{})), init_wins(coins, nodes), rep(List<&2, Maybe<&2, N.Z>>, len(Node, nodes), rep(Maybe<&2, N.Z>, coins, None{})), rep(Maybe<&2, FundingRow>, coins, None{}), rep(Maybe<&2, BarRow>, coins, None{}), rep(List<&2, Maybe<&2, EventRow>>, 2n, rep(Maybe<&2, EventRow>, coins, None{})), N.z(0n), N.Z{True{}, B.pow2(63n)}}

# An observation known after the tick: the engine's R_CAUSALITY.
type MRes is Data:
  MErr{known: N.Z, tick: N.Z}
  MOk{m: MState}

def deliver_funding(+m: MState, +f: FundingRow, +tick: N.Z) -> MRes:
  match m:
    case MState{vals, wins, since, funding, bar, events, hour, max_known}:
      match f:
        case FundingRow{coin, event, known, rate, premium}:
          Bool.pick(MRes, N.zlt(tick, known), MErr{known, tick}, MOk{MState{vals, wins, since, put(Maybe<&2, FundingRow>, funding, coin, Some{FundingRow{coin, event, known, rate, premium}}), bar, events, hour, N.zmax(max_known, known)}})

def deliver_bar(+m: MState, +b: BarRow, +tick: N.Z) -> MRes:
  match m:
    case MState{vals, wins, since, funding, bar, events, hour, max_known}:
      match b:
        case BarRow{coin, open_time, event, known, o, h, l, c, v, trades}:
          Bool.pick(MRes, N.zlt(tick, known), MErr{known, tick}, MOk{MState{vals, wins, since, funding, put(Maybe<&2, BarRow>, bar, coin, Some{BarRow{coin, open_time, event, known, o, h, l, c, v, trades}}), events, hour, N.zmax(max_known, known)}})

def deliver_event(+m: MState, +e: EventRow, +tick: N.Z) -> MRes:
  match m:
    case MState{vals, wins, since, funding, bar, events, hour, max_known}:
      match e:
        case EventRow{slot, coin, event, known, count}:
          Bool.pick(MRes, N.zlt(tick, known), MErr{known, tick}, MOk{MState{vals, wins, since, funding, bar, put(List<&2, Maybe<&2, EventRow>>, events, slot, put(Maybe<&2, EventRow>, at(List<&2, Maybe<&2, EventRow>>, events, slot, Nil{}), coin, Some{EventRow{slot, coin, event, known, count}})), hour, N.zmax(max_known, known)}})

def f_rate(+r: Maybe<&2, FundingRow>) -> Val:
  match r:
    case None{}:
      VNone{}
    case Some{f}:
      match f:
        case FundingRow{coin, event, known, rate, premium}:
          VSome{rate}

def f_premium(+r: Maybe<&2, FundingRow>) -> Val:
  match r:
    case None{}:
      VNone{}
    case Some{f}:
      match f:
        case FundingRow{coin, event, known, rate, premium}:
          VSome{premium}

def b_field(+which: Nat, +r: Maybe<&2, BarRow>) -> Val:
  match r:
    case None{}:
      VNone{}
    case Some{b}:
      match b:
        case BarRow{coin, open_time, event, known, o, h, l, c, v, trades}:
          VSome{at(N.Num, Con{o, Con{h, Con{l, Con{c, Con{v, Nil{}}}}}}, which, o)}

def e_count(+r: Maybe<&2, EventRow>, +hour: N.Z) -> Val:
  match r:
    case None{}:
      VNone{}
    case Some{e}:
      match e:
        case EventRow{slot, coin, event, known, count}:
          Bool.pick(Val, N.zeq(event, hour), VSome{count}, VNone{})

def input(+m: MState, +i: Input, +c: Nat) -> Val:
  match m:
    case MState{vals, wins, since, funding, bar, events, hour, max_known}:
      match i:
        case IFunding{}:
          f_rate(at(Maybe<&2, FundingRow>, funding, c, None{}))
        case IPremium{}:
          f_premium(at(Maybe<&2, FundingRow>, funding, c, None{}))
        case IOpen{}:
          b_field(0n, at(Maybe<&2, BarRow>, bar, c, None{}))
        case IHigh{}:
          b_field(1n, at(Maybe<&2, BarRow>, bar, c, None{}))
        case ILow{}:
          b_field(2n, at(Maybe<&2, BarRow>, bar, c, None{}))
        case IClose{}:
          b_field(3n, at(Maybe<&2, BarRow>, bar, c, None{}))
        case IVolume{}:
          b_field(4n, at(Maybe<&2, BarRow>, bar, c, None{}))
        case IEvent{s}:
          e_count(at(Maybe<&2, EventRow>, at(List<&2, Maybe<&2, EventRow>>, events, s, Nil{}), c, None{}), hour)

def truth(+b: Bool) -> N.Num:
  Bool.pick(N.Num, b, N.one(), N.zero())

def sign(+x: N.Num) -> N.Num:
  Bool.pick(N.Num, N.lt(N.zero(), x), N.one(), Bool.pick(N.Num, N.lt(x, N.zero()), N.neg(N.one()), N.zero()))

def keep(+x: N.Num) -> Val:
  Bool.pick(Val, N.finite(x), VSome{x}, VNone{})

def keep_val(+v: Val) -> Val:
  match v:
    case VNone{}:
      VNone{}
    case VSome{x}:
      keep(x)

def apply1(+o: Op, +x: N.Num) -> Val:
  match o:
    case ONeg{}:
      VSome{N.neg(x)}
    case OAbs{}:
      VSome{N.abs(x)}
    case OSign{}:
      VSome{sign(x)}
    case OLog{}:
      Bool.pick(Val, N.lt(N.zero(), x), VSome{N.log(x)}, VNone{})
    case OExp{}:
      VSome{N.exp(x)}
    case OSqrt{}:
      Bool.pick(Val, N.le(N.zero(), x), VSome{N.sqrt(x)}, VNone{})
    case Not{}:
      VSome{truth(N.is_zero(x))}
    case Convert{f}:
      VSome{N.mul(x, N.of_bits(f))}
    case _:
      VNone{}

def apply2(+o: Op, +x: N.Num, +y: N.Num) -> Val:
  match o:
    case Add{}:
      VSome{N.add(x, y)}
    case Sub{}:
      VSome{N.sub(x, y)}
    case Mul{}:
      VSome{N.mul(x, y)}
    case Div{}:
      Bool.pick(Val, N.is_zero(y), VNone{}, VSome{N.div(x, y)})
    case OMin{}:
      VSome{nmin(x, y)}
    case OMax{}:
      VSome{nmax(x, y)}
    case Gt{}:
      VSome{truth(N.lt(y, x))}
    case Ge{}:
      VSome{truth(N.le(y, x))}
    case Lt{}:
      VSome{truth(N.lt(x, y))}
    case Le{}:
      VSome{truth(N.le(x, y))}
    case And{}:
      VSome{truth(Bool.and(Bool.not(N.is_zero(x)), Bool.not(N.is_zero(y))))}
    case Or{}:
      VSome{truth(Bool.or(Bool.not(N.is_zero(x)), Bool.not(N.is_zero(y))))}
    case _:
      VNone{}

def lift1(+o: Op, +a: Val) -> Val:
  match a:
    case VNone{}:
      VNone{}
    case VSome{x}:
      apply1(o, x)

def lift2(+o: Op, +a: Val, +b: Val) -> Val:
  match a:
    case VNone{}:
      VNone{}
    case VSome{x}:
      match b:
        case VNone{}:
          VNone{}
        case VSome{y}:
          apply2(o, x, y)

def clip3(+a: Val, +b: Val, +c: Val) -> Val:
  match a:
    case VNone{}:
      VNone{}
    case VSome{x}:
      match b:
        case VNone{}:
          VNone{}
        case VSome{lo}:
          match c:
            case VNone{}:
              VNone{}
            case VSome{hi}:
              VSome{nmin(nmax(x, lo), hi)}

def ite3(+a: Val, +b: Val, +c: Val) -> Val:
  match a:
    case VNone{}:
      VNone{}
    case VSome{x}:
      Bool.pick(Val, N.is_zero(x), c, b)

# The pointwise value of an op node from its arguments' values (SEMANTICS.md §5).
def eval_op(+o: Op, +a0: Val, +a1: Val, +a2: Val) -> Val:
  match o:
    case Clip{}:
      clip3(a0, a1, a2)
    case Ite{}:
      ite3(a0, a1, a2)
    case OWindow{w, h}:
      a0
    case XsMean{}:
      VNone{}
    case XsDemean{}:
      VNone{}
    case XsRank{}:
      VNone{}
    case HoursSince{}:
      VNone{}
    case Add{}:
      lift2(Add{}, a0, a1)
    case Sub{}:
      lift2(Sub{}, a0, a1)
    case Mul{}:
      lift2(Mul{}, a0, a1)
    case Div{}:
      lift2(Div{}, a0, a1)
    case OMin{}:
      lift2(OMin{}, a0, a1)
    case OMax{}:
      lift2(OMax{}, a0, a1)
    case Gt{}:
      lift2(Gt{}, a0, a1)
    case Ge{}:
      lift2(Ge{}, a0, a1)
    case Lt{}:
      lift2(Lt{}, a0, a1)
    case Le{}:
      lift2(Le{}, a0, a1)
    case And{}:
      lift2(And{}, a0, a1)
    case Or{}:
      lift2(Or{}, a0, a1)
    case _:
      lift1(o, a0)

def row(+m: MState, +k: Nat) -> List<&2, Val>:
  match m:
    case MState{vals, wins, since, funding, bar, events, hour, max_known}:
      at(List<&2, Val>, vals, k, Nil{})

def argv(+m: MState, +args: +List<Nat>, +k: Nat, +c: Nat) -> Val:
  at(Val, row(m, at(Nat, args, k, 0n)), c, VNone{})

def eval_node(+nd: Node, +params: +List<B.Bin>, +m: MState, +c: Nat) -> Val:
  match nd:
    case NInput{inp}:
      input(m, inp, c)
    case NConst{bits}:
      VSome{N.of_bits(bits)}
    case NParam{k}:
      VSome{N.of_bits(at(B.Bin, params, k, B.BE{}))}
    case NOp{o, args}:
      eval_op(o, argv(m, args, 0n, c), argv(m, args, 1n, c), argv(m, args, 2n, c))

def node_at(+p: Program, +i: Nat) -> Node:
  match p:
    case Program{nodes, params, weight}:
      at(Node, nodes, i, NInput{IFunding{}})

def params_of(+p: Program) -> List<&2, B.Bin>:
  match p:
    case Program{nodes, params, weight}:
      params

def eval(+p: Program, +m: MState, +i: Nat, +c: Nat) -> Val:
  eval_node(node_at(p, i), params_of(p), m, c)

def count_lt(+xs: +List<N.Num>, +v: N.Num) -> Nat:
  match xs:
    case Nil{}:
      0n
    case Con{h, t}:
      Nat.add(Bool.pick(Nat, N.lt(h, v), 1n, 0n), count_lt(t, v))

def count_eq(+xs: +List<N.Num>, +v: N.Num) -> Nat:
  match xs:
    case Nil{}:
      0n
    case Con{h, t}:
      Nat.add(Bool.pick(Nat, N.eq(h, v), 1n, 0n), count_eq(t, v))

def rank(+xs: +List<N.Num>, +v: N.Num) -> N.Num:
  Bool.pick(N.Num, Nat.is_eq(len(N.Num, xs), 1n), N.div(N.one(), N.of_nat(2n)),
    N.div(N.add(N.of_nat(count_lt(xs, v)), N.div(N.sub(N.of_nat(count_eq(xs, v)), N.one()), N.of_nat(2n))),
      N.sub(N.of_nat(len(N.Num, xs)), N.one())))

# Row i, entry c, replaced: the engine's `modify i (·.set! c x)`.
def mod2(-A: Data, +xs: +List<List<&2, A>>, +i: Nat, +c: Nat, +x: A) -> List<&2, List<&2, A>>:
  put(List<&2, A>, xs, i, put(A, at(List<&2, A>, xs, i, Nil{}), c, x))

def with_vals(+m: MState, +vals: +List<List<&2, Val>>) -> MState:
  match m:
    case MState{v0, wins, since, funding, bar, events, hour, max_known}:
      MState{vals, wins, since, funding, bar, events, hour, max_known}

def with_since(+m: MState, +since: +List<List<&2, Maybe<&2, N.Z>>>) -> MState:
  match m:
    case MState{vals, wins, s0, funding, bar, events, hour, max_known}:
      MState{vals, wins, since, funding, bar, events, hour, max_known}

def with_hour(+m: MState, +hour: N.Z) -> MState:
  match m:
    case MState{vals, wins, since, funding, bar, events, h0, max_known}:
      MState{vals, wins, since, funding, bar, events, hour, max_known}

def vals_of(+m: MState) -> List<&2, List<&2, Val>>:
  match m:
    case MState{vals, wins, since, funding, bar, events, hour, max_known}:
      vals

def wins_of(+m: MState) -> List<&2, List<&2, Maybe<&2, Win>>>:
  match m:
    case MState{vals, wins, since, funding, bar, events, hour, max_known}:
      wins

def since_of(+m: MState) -> List<&2, List<&2, Maybe<&2, N.Z>>>:
  match m:
    case MState{vals, wins, since, funding, bar, events, hour, max_known}:
      since

# A coin of an ordinary node: its pointwise value, pushed through its window if it has one.
type VW is Data:
  VW{v: Val, w: Maybe<&2, Win>}

def pushed_vw(+r: Pushed) -> VW:
  match r:
    case Pushed{w, out}:
      VW{out, Some{w}}

def through(+w: Maybe<&2, Win>, +listed: Bool, +v: Val) -> VW:
  match w:
    case None{}:
      VW{v, None{}}
    case Some{win}:
      match listed:
        case True{}:
          pushed_vw(win_push(win, v))
        case False{}:
          VW{v, Some{win}}

def ordinary_put(+vw: VW, +i: Nat, +c: Nat, +m: MState) -> MState:
  match vw:
    case VW{v, w}:
      match m:
        case MState{vals, wins, since, funding, bar, events, hour, max_known}:
          MState{mod2(Val, vals, i, c, keep_val(v)), mod2(Maybe<&2, Win>, wins, i, c, w), since, funding, bar, events, hour, max_known}

def ordinary_coin(+p: Program, +l: Bool, +i: Nat, +c: Nat, +m: MState) -> MState:
  ordinary_put(through(at(Maybe<&2, Win>, at(List<&2, Maybe<&2, Win>>, wins_of(m), i, Nil{}), c, None{}), l, Bool.pick(Val, l, eval(p, m, i, c), VNone{})), i, c, m)

def holds(+cond: Val) -> Bool:
  match cond:
    case VNone{}:
      False{}
    case VSome{v}:
      Bool.not(N.is_zero(v))

def hours_val(+t: Maybe<&2, N.Z>, +hour: N.Z) -> Val:
  match t:
    case None{}:
      VNone{}
    case Some{t0}:
      keep(N.of_z(N.zdiv(N.zsub(hour, t0), N.HOUR())))

def since_coin(+a0: Nat, +l: Bool, +hour: N.Z, +i: Nat, +c: Nat, +m: MState) -> MState:
  +m1 = Bool.pick(MState, Bool.and(l, holds(at(Val, row(m, a0), c, VNone{}))), with_since(m, mod2(Maybe<&2, N.Z>, since_of(m), i, c, Some{hour})), m)
  with_vals(m1, mod2(Val, vals_of(m1), i, c, Bool.pick(Val, l, hours_val(at(Maybe<&2, N.Z>, at(List<&2, Maybe<&2, N.Z>>, since_of(m1), i, Nil{}), c, None{}), hour), VNone{})))

def since_loop(+a0: Nat, +listed: +List<Bool>, +hour: N.Z, +i: Nat, +k: Nat, +c: Nat, +m: MState) -> MState:
  match k:
    case 0n:
      m
    case 1n+r:
      since_loop(a0, listed, hour, i, r, Nat.add(c, 1n), since_coin(a0, at(Bool, listed, c, False{}), hour, i, c, m))

def ordinary_loop(+p: Program, +listed: +List<Bool>, +i: Nat, +k: Nat, +c: Nat, +m: MState) -> MState:
  match k:
    case 0n:
      m
    case 1n+r:
      ordinary_loop(p, listed, i, r, Nat.add(c, 1n), ordinary_coin(p, at(Bool, listed, c, False{}), i, c, m))

def xs_cons(+v: Val, +c: Nat, +rest: +List<Slot>) -> List<&2, Slot>:
  match v:
    case VNone{}:
      rest
    case VSome{x}:
      Con{Slot{c, x}, rest}

# The listed coins' defined values of row a0, as (coin, value).
def xs_pairs(+r0: +List<Val>, +listed: +List<Bool>, +k: Nat, +c: Nat) -> List<&2, Slot>:
  match k:
    case 0n:
      Nil{}
    case 1n+r:
      Bool.pick(List<&2, Slot>, at(Bool, listed, c, False{}), xs_cons(at(Val, r0, c, VNone{}), c, xs_pairs(r0, listed, r, Nat.add(c, 1n))), xs_pairs(r0, listed, r, Nat.add(c, 1n)))

def slot_values(+xs: +List<Slot>) -> List<&2, N.Num>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      Con{slot_x(h), slot_values(t)}

def slot_seq(+e: Slot) -> Nat:
  match e:
    case Slot{s, x}:
      s

def find_slot(+xs: +List<Slot>, +c: Nat) -> Val:
  match xs:
    case Nil{}:
      VNone{}
    case Con{h, t}:
      Bool.pick(Val, Nat.is_eq(slot_seq(h), c), VSome{slot_x(h)}, find_slot(t, c))

def xs_value(+found: Val, +o: Op, +vals: +List<N.Num>, +mean: N.Num) -> Val:
  match found:
    case VNone{}:
      VNone{}
    case VSome{v}:
      match o:
        case XsMean{}:
          keep(mean)
        case XsDemean{}:
          keep(N.sub(v, mean))
        case _:
          keep(rank(vals, v))

def xs_out(+o: Op, +xs: +List<Slot>, +mean: N.Num, +k: Nat, +c: Nat) -> List<&2, Val>:
  match k:
    case 0n:
      Nil{}
    case 1n+r:
      Con{xs_value(find_slot(xs, c), o, slot_values(xs), mean), xs_out(o, xs, mean, r, Nat.add(c, 1n))}

def xs_row(+o: Op, +xs: +List<Slot>, +coins: Nat) -> List<&2, Val>:
  Bool.pick(List<&2, Val>, List.is_empty(&2, Slot, xs), rep(Val, coins, VNone{}),
    xs_out(o, xs, N.div(total(slot_values(xs)), N.of_nat(len(Slot, xs))), coins, 0n))

def xs_node(+o: Op, +a0: Nat, +listed: +List<Bool>, +i: Nat, +m: MState) -> MState:
  with_vals(m, put(List<&2, Val>, vals_of(m), i, xs_row(o, xs_pairs(row(m, a0), listed, len(Bool, listed), 0n), len(Bool, listed))))

# One node's step of a tick, for every coin.
def tick_kind(+nd: Node, +p: Program, +listed: +List<Bool>, +hour: N.Z, +i: Nat, +m: MState) -> MState:
  match nd:
    case NOp{o, args}:
      match o:
        case HoursSince{}:
          since_loop(at(Nat, args, 0n, 0n), listed, hour, i, len(Bool, listed), 0n, m)
        case XsMean{}:
          xs_node(XsMean{}, at(Nat, args, 0n, 0n), listed, i, m)
        case XsDemean{}:
          xs_node(XsDemean{}, at(Nat, args, 0n, 0n), listed, i, m)
        case XsRank{}:
          xs_node(XsRank{}, at(Nat, args, 0n, 0n), listed, i, m)
        case _:
          ordinary_loop(p, listed, i, len(Bool, listed), 0n, m)
    case _:
      ordinary_loop(p, listed, i, len(Bool, listed), 0n, m)

def tick_node(+p: Program, +listed: +List<Bool>, +hour: N.Z, +i: Nat, +m: MState) -> MState:
  tick_kind(node_at(p, i), p, listed, hour, i, m)

def tick_nodes(+p: Program, +listed: +List<Bool>, +hour: N.Z, +k: Nat, +i: Nat, +m: MState) -> MState:
  match k:
    case 0n:
      m
    case 1n+r:
      tick_nodes(p, listed, hour, r, Nat.add(i, 1n), tick_node(p, listed, hour, i, m))

def size(+p: Program) -> Nat:
  match p:
    case Program{nodes, params, weight}:
      len(Node, nodes)

# One tick: every node in index order.
def tick(+p: Program, +m: MState, +listed: +List<Bool>, +hour: N.Z) -> MState:
  tick_nodes(p, listed, hour, size(p), 0n, with_hour(m, hour))
