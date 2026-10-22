import Base
import ./num.bend as N
import ./machine.bend as M

# The simulation loop (reference/SEMANTICS.md §7–§8), ported from the Lean model's Ref/Sim.lean
# definition for definition: decisions, orders, fills, funding, marks, margin, delisting, bankruptcy,
# accounting and returns, step for step as the engine runs them.

type Why is Data:
  WFill{}
  WLiquidation{}
  WDelisting{}

type Fill is Data:
  Fill{why: Why, coin: Nat, qty: N.Num, inputs_known: N.Z, decision_price: N.Num, decided: N.Z, submitted: N.Z, filled: N.Z, source_open: N.Z, reference: N.Num, price: N.Num, fee: N.Num}

type HoldWhy is Data:
  Stale{}
  Undefined{}

type SEvent is Data:
  EDecision{t: N.Z, coin: Nat, weight: N.Num, qty: N.Num}
  EHold{t: N.Z, coin: Nat, why: HoldWhy}
  EFill{f: Fill}
  EUnfilled{t: N.Z, coin: Nat, qty: N.Num}
  EFunding{t: N.Z, coin: Nat, rate: N.Num, price: N.Num, paid: N.Num}
  EEquity{t: N.Z, equity: N.Num, reconciled: N.Num}

type Abort is Data:
  Causality{}
  Timing{}
  AFill{}
  Accounting{}
  Portfolio{}
  Bound{}
  InputUnavailable{}

# Costs by coin, then side (buy, sell), then size (≤ $1k, ≤ $10k), in bps.
type Venue is Data:
  Venue{taker_fee: N.Num, min_notional: N.Num, sz_decimals: List<&2, Nat>, min_tier_leverage: List<&2, N.Num>, cost_bps: List<&2, List<&2, List<&2, N.Num>>>}

type Iv is Data:
  Iv{start: N.Z, stop: N.Z}

type Market is Data:
  Market{funding: List<&2, M.FundingRow>, bars: List<&2, M.BarRow>, events: List<&2, M.EventRow>, bound: List<&2, Nat>, intervals: List<&2, Iv>}

type Policy is Data:
  Policy{delta: N.Z, w_start: N.Z}

type Run is Data:
  Run{trace: List<&2, SEvent>, returns: List<&2, N.Num>, gross: List<&2, N.Num>, equity: List<&2, N.Num>}

def initial() -> N.Num:
  N.of_nat(10000n)

def max_gross() -> N.Num:
  N.of_nat(2n)

def max_order_notional() -> N.Num:
  N.of_nat(10000n)

def truncate(+x: N.Num, +dec: Nat) -> N.Num:
  N.div(N.trunc(N.mul(x, N.of_nat(Nat.pow(10n, dec)))), N.of_nat(Nat.pow(10n, dec)))

def venue_costs(+v: Venue) -> List<&2, List<&2, List<&2, N.Num>>>:
  match v:
    case Venue{taker_fee, min_notional, sz_decimals, min_tier_leverage, cost_bps}:
      cost_bps

def cost_bps(+v: Venue, +coin: Nat, +qty: N.Num, +ref: N.Num) -> N.Num:
  +side = Bool.pick(Nat, N.lt(N.zero(), qty), 0n, 1n)
  +size = Bool.pick(Nat, N.le(N.mul(N.abs(qty), ref), N.of_nat(1000n)), 0n, 1n)
  M.at(N.Num, M.at(List<&2, N.Num>, M.at(List<&2, List<&2, N.Num>>, venue_costs(v), coin, Nil{}), side, Nil{}), size, N.zero())

def signum(+x: N.Num) -> N.Num:
  Bool.pick(N.Num, N.sign_bit(x), N.neg(N.one()), N.one())

def fill_price(+v: Venue, +coin: Nat, +qty: N.Num, +ref: N.Num) -> N.Num:
  N.mul(ref, N.add(N.one(), N.div(N.mul(signum(qty), cost_bps(v, coin, qty, ref)), N.of_nat(10000n))))

# A (coin, value) entry of an association list, kept sorted by coin.
type Entry is Data:
  Entry{k: Nat, x: N.Num}

def entry_k(+e: Entry) -> Nat:
  match e:
    case Entry{k, x}:
      k

def entry_x(+e: Entry) -> N.Num:
  match e:
    case Entry{k, x}:
      x

def assoc(+l: +List<Entry>, +k: Nat) -> Maybe<&2, N.Num>:
  match l:
    case Nil{}:
      None{}
    case Con{h, t}:
      Bool.pick(Maybe<&2, N.Num>, Nat.is_eq(entry_k(h), k), Some{entry_x(h)}, assoc(t, k))

def get_d(+m: Maybe<&2, N.Num>, +d: N.Num) -> N.Num:
  match m:
    case None{}:
      d
    case Some{x}:
      x

def assoc_del(+l: +List<Entry>, +k: Nat) -> List<&2, Entry>:
  match l:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      Bool.pick(List<&2, Entry>, Nat.is_eq(entry_k(h), k), assoc_del(t, k), Con{h, assoc_del(t, k)})

# Insert into a list sorted by key, after every entry whose key is ≤ k: a stable sort of l ++ [e].
def insert_sorted(+l: +List<Entry>, +e: Entry) -> List<&2, Entry>:
  match l:
    case Nil{}:
      Con{e, Nil{}}
    case Con{h, t}:
      Bool.pick(List<&2, Entry>, Nat.is_le(entry_k(h), entry_k(e)), Con{h, insert_sorted(t, e)}, Con{e, Con{h, t}})

def assoc_set(+l: +List<Entry>, +k: Nat, +x: N.Num) -> List<&2, Entry>:
  insert_sorted(assoc_del(l, k), Entry{k, x})

type Book is Data:
  Book{cash: N.Num, pos: List<&2, Entry>, entry: List<&2, Entry>, realized: N.Num, fees: N.Num, slippage: N.Num, funding: N.Num, absorbed: N.Num}

def book_fill(+b: Book, +coin: Nat, +qty: N.Num, +price: N.Num, +fee: N.Num) -> Book:
  match b:
    case Book{cash, pos, entry, realized, fees, slippage, funding, absorbed}:
      +old = get_d(assoc(pos, coin), N.zero())
      +new = N.add(old, qty)
      +flips = Bool.and(Bool.not(N.is_zero(old)), Bool.xor(N.lt(N.zero(), old), N.lt(N.zero(), qty)))
      +realized2 = Bool.pick(N.Num, flips, N.add(realized, N.mul(N.mul(M.nmin(N.abs(qty), N.abs(old)), signum(old)), N.sub(price, get_d(assoc(entry, coin), N.zero())))), realized)
      +fresh = Bool.or(N.is_zero(old), Bool.xor(N.lt(N.zero(), old), N.lt(N.zero(), new)))
      +same = Bool.not(Bool.xor(N.lt(N.zero(), old), N.lt(N.zero(), qty)))
      +entry_open = Bool.pick(List<&2, Entry>, fresh, assoc_set(entry, coin, price), Bool.pick(List<&2, Entry>, same, assoc_set(entry, coin, N.div(N.add(N.mul(old, get_d(assoc(entry, coin), N.zero())), N.mul(qty, price)), new)), entry))
      +closed = N.is_zero(new)
      Book{N.sub(cash, N.add(N.mul(qty, price), fee)), Bool.pick(List<&2, Entry>, closed, assoc_del(pos, coin), assoc_set(pos, coin, new)), Bool.pick(List<&2, Entry>, closed, assoc_del(entry, coin), entry_open), realized2, N.add(fees, fee), slippage, funding, absorbed}

type Settled is Data:
  Settled{b: Book, paid: N.Num}

def book_settle(+b: Book, +coin: Nat, +price: N.Num, +rate: N.Num) -> Settled:
  match b:
    case Book{cash, pos, entry, realized, fees, slippage, funding, absorbed}:
      +paid = N.mul(N.mul(get_d(assoc(pos, coin), N.zero()), price), rate)
      Settled{Book{N.sub(cash, paid), pos, entry, realized, fees, slippage, N.sub(funding, paid), absorbed}, paid}

def value_at(+pos: +List<Entry>, +marks: +List<N.Num>) -> List<&2, N.Num>:
  match pos:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      Con{N.mul(entry_x(h), M.at(N.Num, marks, entry_k(h), N.zero())), value_at(t, marks)}

def book_equity(+b: Book, +marks: +List<N.Num>) -> N.Num:
  match b:
    case Book{cash, pos, entry, realized, fees, slippage, funding, absorbed}:
      N.add(cash, M.total(value_at(pos, marks)))

def unrealized(+pos: +List<Entry>, +entry: +List<Entry>, +marks: +List<N.Num>) -> List<&2, N.Num>:
  match pos:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      Con{N.mul(entry_x(h), N.sub(M.at(N.Num, marks, entry_k(h), N.zero()), get_d(assoc(entry, entry_k(h)), N.zero()))), unrealized(t, entry, marks)}

def book_reconciled(+b: Book, +marks: +List<N.Num>) -> N.Num:
  match b:
    case Book{cash, pos, entry, realized, fees, slippage, funding, absorbed}:
      N.add(N.add(N.sub(N.add(N.add(initial(), realized), M.total(unrealized(pos, entry, marks))), fees), funding), absorbed)

# Losses are capped at equity: once flat, the venue absorbs a negative balance.
def book_absorb(+b: Book) -> Book:
  match b:
    case Book{cash, pos, entry, realized, fees, slippage, funding, absorbed}:
      Book{N.zero(), pos, entry, realized, fees, slippage, funding, N.sub(absorbed, cash)}

def bar_of(+b: M.BarRow) -> N.Z & N.Z:
  match b:
    case M.BarRow{coin, open_time, event, known, o, h, l, c, v, trades}:
      (open_time, event)

def bar_coin(+b: M.BarRow) -> Nat:
  match b:
    case M.BarRow{coin, open_time, event, known, o, h, l, c, v, trades}:
      coin

def bar_open(+b: M.BarRow) -> N.Z:
  match b:
    case M.BarRow{coin, open_time, event, known, o, h, l, c, v, trades}:
      open_time

def bar_event(+b: M.BarRow) -> N.Z:
  match b:
    case M.BarRow{coin, open_time, event, known, o, h, l, c, v, trades}:
      event

def bar_known(+b: M.BarRow) -> N.Z:
  match b:
    case M.BarRow{coin, open_time, event, known, o, h, l, c, v, trades}:
      known

def bar_trades(+b: M.BarRow) -> N.Z:
  match b:
    case M.BarRow{coin, open_time, event, known, o, h, l, c, v, trades}:
      trades

def bar_px(+which: Nat, +b: M.BarRow) -> N.Num:
  match b:
    case M.BarRow{coin, open_time, event, known, o, h, l, c, v, trades}:
      M.at(N.Num, Con{o, Con{h, Con{l, Con{c, Con{v, Nil{}}}}}}, which, o)

def default_bar() -> M.BarRow:
  M.BarRow{0n, N.z(0n), N.z(0n), N.z(0n), N.zero(), N.zero(), N.zero(), N.zero(), N.zero(), N.z(0n)}

# The index's barAt: the last bar inserted with this (coin, openTime), as a HashMap built by inserts keeps.
def bar_at_go(+bars: +List<M.BarRow>, +coin: Nat, +t: N.Z, +i: Nat, +acc: Maybe<&2, Nat>) -> Maybe<&2, Nat>:
  match bars:
    case Nil{}:
      acc
    case Con{h, rest}:
      bar_at_go(rest, coin, t, Nat.add(i, 1n), Bool.pick(Maybe<&2, Nat>, Bool.and(Nat.is_eq(bar_coin(h), coin), N.zeq(bar_open(h), t)), Some{i}, acc))

def bar_at(+bars: +List<M.BarRow>, +coin: Nat, +t: N.Z) -> Maybe<&2, Nat>:
  bar_at_go(bars, coin, t, 0n, None{})

def f_coin(+f: M.FundingRow) -> Nat:
  match f:
    case M.FundingRow{coin, event, known, rate, premium}:
      coin

def f_event(+f: M.FundingRow) -> N.Z:
  match f:
    case M.FundingRow{coin, event, known, rate, premium}:
      event

def f_known(+f: M.FundingRow) -> N.Z:
  match f:
    case M.FundingRow{coin, event, known, rate, premium}:
      known

def f_rate(+f: M.FundingRow) -> N.Num:
  match f:
    case M.FundingRow{coin, event, known, rate, premium}:
      rate

def rate_at_go(+fs: +List<M.FundingRow>, +coin: Nat, +t: N.Z, +acc: Maybe<&2, N.Num>) -> Maybe<&2, N.Num>:
  match fs:
    case Nil{}:
      acc
    case Con{h, rest}:
      rate_at_go(rest, coin, t, Bool.pick(Maybe<&2, N.Num>, Bool.and(Nat.is_eq(f_coin(h), coin), N.zeq(f_event(h), t)), Some{f_rate(h)}, acc))

def rate_at(+fs: +List<M.FundingRow>, +coin: Nat, +t: N.Z) -> Maybe<&2, N.Num>:
  rate_at_go(fs, coin, t, None{})

def insert_z(+xs: +List<N.Z>, +x: N.Z) -> List<&2, N.Z>:
  match xs:
    case Nil{}:
      Con{x, Nil{}}
    case Con{h, t}:
      Bool.pick(List<&2, N.Z>, N.zle(h, x), Con{h, insert_z(t, x)}, Con{x, Con{h, t}})

# A coin's bar openTimes, sorted (a stable sort, as the model's mergeSort).
def bar_times_go(+bars: +List<M.BarRow>, +coin: Nat, +acc: +List<N.Z>) -> List<&2, N.Z>:
  match bars:
    case Nil{}:
      acc
    case Con{h, rest}:
      bar_times_go(rest, coin, Bool.pick(List<&2, N.Z>, Nat.is_eq(bar_coin(h), coin), insert_z(acc, bar_open(h)), acc))

def bar_times(+bars: +List<M.BarRow>, +coin: Nat) -> List<&2, N.Z>:
  bar_times_go(bars, coin, Nil{})

# Rust's partition_point on sorted times: the first index whose time is not below t (strict) or above it.
def pp_lt(+xs: +List<N.Z>, +t: N.Z) -> Nat:
  match xs:
    case Nil{}:
      0n
    case Con{h, rest}:
      Bool.pick(Nat, N.zlt(h, t), Nat.add(1n, pp_lt(rest, t)), 0n)

def pp_le(+xs: +List<N.Z>, +t: N.Z) -> Nat:
  match xs:
    case Nil{}:
      0n
    case Con{h, rest}:
      Bool.pick(Nat, N.zle(h, t), Nat.add(1n, pp_le(rest, t)), 0n)

def market_bars(+m: Market) -> List<&2, M.BarRow>:
  match m:
    case Market{funding, bars, events, bound, intervals}:
      bars

def market_funding(+m: Market) -> List<&2, M.FundingRow>:
  match m:
    case Market{funding, bars, events, bound, intervals}:
      funding

def market_events(+m: Market) -> List<&2, M.EventRow>:
  match m:
    case Market{funding, bars, events, bound, intervals}:
      events

def market_bound(+m: Market) -> List<&2, Nat>:
  match m:
    case Market{funding, bars, events, bound, intervals}:
      bound

def market_intervals(+m: Market) -> List<&2, Iv>:
  match m:
    case Market{funding, bars, events, bound, intervals}:
      intervals

def bar_index(+m: Market, +i: Nat) -> M.BarRow:
  M.at(M.BarRow, market_bars(m), i, default_bar())

def taker_fee(+v: Venue) -> N.Num:
  match v:
    case Venue{taker_fee, min_notional, sz_decimals, min_tier_leverage, cost_bps}:
      taker_fee

def fill_why(+f: Fill) -> Why:
  match f:
    case Fill{why, coin, qty, inputs_known, decision_price, decided, submitted, filled, source_open, reference, price, fee}:
      why

def is_fill(+w: Why) -> Bool:
  match w:
    case WFill{}:
      True{}
    case _:
      False{}

def is_delisting(+w: Why) -> Bool:
  match w:
    case WDelisting{}:
      True{}
    case _:
      False{}

def maybe_z_eq(+a: Maybe<&2, N.Z>, +b: N.Z) -> Bool:
  match a:
    case None{}:
      False{}
    case Some{x}:
      N.zeq(x, b)

def at_z(+xs: +List<N.Z>, +i: Nat) -> Maybe<&2, N.Z>:
  List.get(&2, N.Z, xs, i)

def get_nat(+x: Maybe<&2, Nat>, +d: Nat) -> Nat:
  match x:
    case None{}:
      d
    case Some{y}:
      y

# The latest time in the sorted list whose bar's event is known by `filled`.
def latest_time(+m: Market, +coin: Nat, +rev: +List<N.Z>, +filled: N.Z) -> Maybe<&2, N.Z>:
  match rev:
    case Nil{}:
      None{}
    case Con{h, rest}:
      Bool.pick(Maybe<&2, N.Z>, N.zle(bar_event(bar_index(m, get_nat(bar_at(market_bars(m), coin, h), 0n))), filled), Some{h}, latest_time(m, coin, rest, filled))


# A 64-bit constant from its two 32-bit halves (Bend's Nat literals stop at 2^32 - 1).
def bits(+hi: Nat, +lo: Nat) -> Nat:
  Nat.add(Nat.mul(hi, Nat.pow(2n, 32n)), lo)

def order_slack() -> N.Num:
  N.of_bits(bits(1030854553n, 2167269905n))

def accounting_tolerance() -> N.Num:
  N.of_bits(bits(1055193269n, 2296604913n))

def check_priced(+v: Venue, +coin: Nat, +qty: N.Num, +ref: N.Num, +price: N.Num, +fee: N.Num) -> Bool:
  Bool.and(Bool.not(N.is_zero(qty)), Bool.and(N.eq(price, fill_price(v, coin, qty, ref)), N.eq(fee, N.mul(N.mul(N.abs(qty), price), taker_fee(v)))))

def check_place(+m: Market, +why: Why, +coin: Nat, +qty: N.Num, +submitted: N.Z, +filled: N.Z, +ref: N.Num, +bar: M.BarRow) -> Bool:
  match why:
    case WFill{}:
      Bool.and(maybe_z_eq(at_z(bar_times(market_bars(m), coin), pp_lt(bar_times(market_bars(m), coin), submitted)), bar_open(bar)), Bool.and(N.zle(bar_open(bar), filled), Bool.and(N.zle(N.z(1n), bar_trades(bar)), N.eq(ref, bar_px(0n, bar)))))
    case WDelisting{}:
      Bool.and(maybe_z_eq(latest_time(m, coin, List.reverse(&2, N.Z, bar_times(market_bars(m), coin)), filled), bar_open(bar)), N.eq(ref, bar_px(3n, bar)))
    case WLiquidation{}:
      Bool.and(maybe_z_eq(latest_time(m, coin, List.reverse(&2, N.Z, bar_times(market_bars(m), coin)), filled), bar_open(bar)), N.eq(ref, Bool.pick(N.Num, N.lt(N.zero(), qty), bar_px(1n, bar), bar_px(2n, bar))))

def check_bar(+bi: Maybe<&2, Nat>, +m: Market, +v: Venue, +why: Why, +coin: Nat, +qty: N.Num, +decision_price: N.Num, +submitted: N.Z, +filled: N.Z, +ref: N.Num, +price: N.Num, +fee: N.Num) -> Maybe<&2, Abort>:
  match bi:
    case None{}:
      Some{AFill{}}
    case Some{i}:
      Bool.pick(Maybe<&2, Abort>, Bool.not(Bool.and(check_place(m, why, coin, qty, submitted, filled, ref, bar_index(m, i)), check_priced(v, coin, qty, ref, price, fee))), Some{AFill{}},
        Bool.pick(Maybe<&2, Abort>, Bool.and(is_fill(why), N.lt(N.mul(max_order_notional(), N.add(N.one(), order_slack())), N.mul(N.abs(qty), decision_price))), Some{Portfolio{}}, None{}))

# I2 and I3 (and the I9 order cap) for one fill, recomputed from the source bars.
def check_fill(+f: Fill, +m: Market, +v: Venue) -> Maybe<&2, Abort>:
  match f:
    case Fill{why, coin, qty, inputs_known, decision_price, decided, submitted, filled, source_open, reference, price, fee}:
      Bool.pick(Maybe<&2, Abort>, Bool.not(Bool.and(N.zle(inputs_known, decided), Bool.and(N.zle(decided, submitted), N.zle(submitted, filled)))), Some{Timing{}},
        check_bar(bar_at(market_bars(m), coin, source_open), m, v, why, coin, qty, decision_price, submitted, filled, reference, price, fee))

type Order is Data:
  Order{coin: Nat, qty: N.Num, price: N.Num, inputs_known: N.Z, decided: N.Z}

type Due is Data:
  Due{at: N.Z, o: Order}

type SState is Data:
  SState{machine: M.MState, book: Book, marks: List<&2, N.Num>, trace: List<&2, SEvent>, orders: List<&2, Due>, returns: List<&2, N.Num>, gross: List<&2, N.Num>, equity: List<&2, N.Num>, prev_equity: N.Num, prev_costs: N.Num, fi: Nat, bi: Nat, ei: Nat}

type SRes is Data:
  SErr{a: Abort}
  SOk{s: SState}

# Everything a run fixes before its first step; the index is recomputed from the market where read.
type Ctx is Data:
  Ctx{p: M.Program, m: Market, v: Venue, pol: Policy, stop: N.Z, f_order: List<&2, Nat>, b_order: List<&2, Nat>, e_order: List<&2, Nat>}

# Lexicographic order (≤) on equal-length integer keys.
def lex_le(+a: +List<N.Z>, +b: +List<N.Z>) -> Bool:
  match a:
    case Nil{}:
      True{}
    case Con{x, xs}:
      match b:
        case Nil{}:
          True{}
        case Con{y, ys}:
          Bool.or(N.zlt(x, y), Bool.and(N.zeq(x, y), lex_le(xs, ys)))

def f_key(+fs: +List<M.FundingRow>, +i: Nat) -> List<&2, N.Z>:
  +f = M.at(M.FundingRow, fs, i, M.FundingRow{0n, N.z(0n), N.z(0n), N.zero(), N.zero()})
  Con{f_known(f), Con{N.z(f_coin(f)), Con{f_event(f), Nil{}}}}

def b_key(+bars: +List<M.BarRow>, +i: Nat) -> List<&2, N.Z>:
  +b = M.at(M.BarRow, bars, i, default_bar())
  Con{bar_known(b), Con{N.z(bar_coin(b)), Con{bar_event(b), Nil{}}}}

def e_fields(+e: M.EventRow) -> List<&2, N.Z>:
  match e:
    case M.EventRow{slot, coin, event, known, count}:
      Con{known, Con{N.z(coin), Con{N.z(slot), Nil{}}}}

def e_key(+es: +List<M.EventRow>, +i: Nat) -> List<&2, N.Z>:
  List.append(&2, N.Z, e_fields(M.at(M.EventRow, es, i, M.EventRow{0n, 0n, N.z(0n), N.z(0n), N.zero()})), Con{N.z(i), Nil{}})

# Stable insertion of index i, after every index whose key is ≤ its key: the model's stable mergeSort.
def ins_f(+fs: +List<M.FundingRow>, +sorted: +List<Nat>, +i: Nat) -> List<&2, Nat>:
  match sorted:
    case Nil{}:
      Con{i, Nil{}}
    case Con{h, t}:
      Bool.pick(List<&2, Nat>, lex_le(f_key(fs, h), f_key(fs, i)), Con{h, ins_f(fs, t, i)}, Con{i, Con{h, t}})

def sort_f(+fs: +List<M.FundingRow>, +idx: +List<Nat>, +acc: +List<Nat>) -> List<&2, Nat>:
  match idx:
    case Nil{}:
      acc
    case Con{h, t}:
      sort_f(fs, t, ins_f(fs, acc, h))

def ins_b(+bars: +List<M.BarRow>, +sorted: +List<Nat>, +i: Nat) -> List<&2, Nat>:
  match sorted:
    case Nil{}:
      Con{i, Nil{}}
    case Con{h, t}:
      Bool.pick(List<&2, Nat>, lex_le(b_key(bars, h), b_key(bars, i)), Con{h, ins_b(bars, t, i)}, Con{i, Con{h, t}})

def sort_b(+bars: +List<M.BarRow>, +idx: +List<Nat>, +acc: +List<Nat>) -> List<&2, Nat>:
  match idx:
    case Nil{}:
      acc
    case Con{h, t}:
      sort_b(bars, t, ins_b(bars, acc, h))

def ins_e(+es: +List<M.EventRow>, +sorted: +List<Nat>, +i: Nat) -> List<&2, Nat>:
  match sorted:
    case Nil{}:
      Con{i, Nil{}}
    case Con{h, t}:
      Bool.pick(List<&2, Nat>, lex_le(e_key(es, h), e_key(es, i)), Con{h, ins_e(es, t, i)}, Con{i, Con{h, t}})

def sort_e(+es: +List<M.EventRow>, +idx: +List<Nat>, +acc: +List<Nat>) -> List<&2, Nat>:
  match idx:
    case Nil{}:
      acc
    case Con{h, t}:
      sort_e(es, t, ins_e(es, acc, h))

def mem_nat(+x: Nat, +xs: +List<Nat>) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case Con{h, t}:
      Bool.or(Nat.is_eq(x, h), mem_nat(x, t))

def e_slot(+e: M.EventRow) -> Nat:
  match e:
    case M.EventRow{slot, coin, event, known, count}:
      slot

# Indices of events whose slot is bound.
def bound_events(+es: +List<M.EventRow>, +bound: +List<Nat>, +idx: +List<Nat>) -> List<&2, Nat>:
  match idx:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      Bool.pick(List<&2, Nat>, mem_nat(e_slot(M.at(M.EventRow, es, h, M.EventRow{0n, 0n, N.z(0n), N.z(0n), N.zero()})), bound), Con{h, bound_events(es, bound, t)}, bound_events(es, bound, t))

def make(+p: M.Program, +m: Market, +v: Venue, +pol: Policy, +stop: N.Z) -> Ctx:
  Ctx{p, m, v, pol, stop,
    sort_f(market_funding(m), List.range(M.len(M.FundingRow, market_funding(m))), Nil{}),
    sort_b(market_bars(m), List.range(M.len(M.BarRow, market_bars(m))), Nil{}),
    sort_e(market_events(m), bound_events(market_events(m), market_bound(m), List.range(M.len(M.EventRow, market_events(m)))), Nil{})}

def ctx_m(+c: Ctx) -> Market:
  match c:
    case Ctx{p, m, v, pol, stop, f_order, b_order, e_order}:
      m

def ctx_v(+c: Ctx) -> Venue:
  match c:
    case Ctx{p, m, v, pol, stop, f_order, b_order, e_order}:
      v

def ctx_p(+c: Ctx) -> M.Program:
  match c:
    case Ctx{p, m, v, pol, stop, f_order, b_order, e_order}:
      p

def ctx_pol(+c: Ctx) -> Policy:
  match c:
    case Ctx{p, m, v, pol, stop, f_order, b_order, e_order}:
      pol

def ctx_stop(+c: Ctx) -> N.Z:
  match c:
    case Ctx{p, m, v, pol, stop, f_order, b_order, e_order}:
      stop

def coins(+c: Ctx) -> Nat:
  M.len(Iv, market_intervals(ctx_m(c)))

def iv_listed(+iv: Iv, +t: N.Z) -> Bool:
  match iv:
    case Iv{start, stop}:
      Bool.and(N.zle(start, t), N.zlt(t, stop))

def listed(+c: Ctx, +coin: Nat, +t: N.Z) -> Bool:
  iv_listed(M.at(Iv, market_intervals(ctx_m(c)), coin, Iv{N.z(0n), N.z(0n)}), t)

def mask_go(+c: Ctx, +t: N.Z, +k: Nat, +i: Nat) -> List<&2, Bool>:
  match k:
    case 0n:
      Nil{}
    case 1n+r:
      Con{listed(c, i, t), mask_go(c, t, r, Nat.add(i, 1n))}

def mask(+c: Ctx, +t: N.Z) -> List<&2, Bool>:
  mask_go(c, t, coins(c), 0n)

def s_machine(+s: SState) -> M.MState:
  match s:
    case SState{machine, book, marks, trace, orders, returns, gross, equity, prev_equity, prev_costs, fi, bi, ei}:
      machine

def s_book(+s: SState) -> Book:
  match s:
    case SState{machine, book, marks, trace, orders, returns, gross, equity, prev_equity, prev_costs, fi, bi, ei}:
      book

def s_marks(+s: SState) -> List<&2, N.Num>:
  match s:
    case SState{machine, book, marks, trace, orders, returns, gross, equity, prev_equity, prev_costs, fi, bi, ei}:
      marks

def s_fi(+s: SState) -> Nat:
  match s:
    case SState{machine, book, marks, trace, orders, returns, gross, equity, prev_equity, prev_costs, fi, bi, ei}:
      fi

def s_bi(+s: SState) -> Nat:
  match s:
    case SState{machine, book, marks, trace, orders, returns, gross, equity, prev_equity, prev_costs, fi, bi, ei}:
      bi

def s_ei(+s: SState) -> Nat:
  match s:
    case SState{machine, book, marks, trace, orders, returns, gross, equity, prev_equity, prev_costs, fi, bi, ei}:
      ei

def set_machine(+s: SState, +mach: M.MState) -> SState:
  match s:
    case SState{machine, book, marks, trace, orders, returns, gross, equity, prev_equity, prev_costs, fi, bi, ei}:
      SState{mach, book, marks, trace, orders, returns, gross, equity, prev_equity, prev_costs, fi, bi, ei}

# One delivered row: its machine and its cursor advanced by one.
def advance(+s: SState, +which: Nat, +mach: M.MState) -> SState:
  match s:
    case SState{machine, book, marks, trace, orders, returns, gross, equity, prev_equity, prev_costs, fi, bi, ei}:
      SState{mach, book, marks, trace, orders, returns, gross, equity, prev_equity, prev_costs,
        Bool.pick(Nat, Nat.is_eq(which, 0n), Nat.add(fi, 1n), fi), Bool.pick(Nat, Nat.is_eq(which, 1n), Nat.add(bi, 1n), bi), Bool.pick(Nat, Nat.is_eq(which, 2n), Nat.add(ei, 1n), ei)}

def after(+r: M.MRes, +s: SState, +which: Nat) -> SState:
  match r:
    case M.MErr{known, tick}:
      s
    case M.MOk{mach}:
      advance(s, which, mach)

def then_(+r: M.MRes, +rest: SRes) -> SRes:
  match r:
    case M.MErr{known, tick}:
      SErr{Causality{}}
    case M.MOk{mach}:
      rest

# The cursor walks (SEMANTICS.md §3): deliver rows in delivery order while they are known by the tick.
def deliver_f(+rows: +List<M.FundingRow>, +s: SState, +tick: N.Z) -> SRes:
  match rows:
    case Nil{}:
      SOk{s}
    case Con{f, rest}:
      Bool.pick(SRes, N.zlt(tick, f_known(f)), SOk{s},
        then_(M.deliver_funding(s_machine(s), f, tick), deliver_f(rest, after(M.deliver_funding(s_machine(s), f, tick), s, 0n), tick)))

def deliver_b(+rows: +List<M.BarRow>, +s: SState, +tick: N.Z) -> SRes:
  match rows:
    case Nil{}:
      SOk{s}
    case Con{b, rest}:
      Bool.pick(SRes, N.zlt(tick, bar_known(b)), SOk{s},
        then_(M.deliver_bar(s_machine(s), b, tick), deliver_b(rest, after(M.deliver_bar(s_machine(s), b, tick), s, 1n), tick)))

def e_known(+e: M.EventRow) -> N.Z:
  match e:
    case M.EventRow{slot, coin, event, known, count}:
      known

def deliver_e(+rows: +List<M.EventRow>, +s: SState, +tick: N.Z) -> SRes:
  match rows:
    case Nil{}:
      SOk{s}
    case Con{e, rest}:
      Bool.pick(SRes, N.zlt(tick, e_known(e)), SOk{s},
        then_(M.deliver_event(s_machine(s), e, tick), deliver_e(rest, after(M.deliver_event(s_machine(s), e, tick), s, 2n), tick)))

def rows_f(+fs: +List<M.FundingRow>, +order: +List<Nat>) -> List<&2, M.FundingRow>:
  match order:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      Con{M.at(M.FundingRow, fs, h, M.FundingRow{0n, N.z(0n), N.z(0n), N.zero(), N.zero()}), rows_f(fs, t)}

def rows_b(+bars: +List<M.BarRow>, +order: +List<Nat>) -> List<&2, M.BarRow>:
  match order:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      Con{M.at(M.BarRow, bars, h, default_bar()), rows_b(bars, t)}

def rows_e(+es: +List<M.EventRow>, +order: +List<Nat>) -> List<&2, M.EventRow>:
  match order:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      Con{M.at(M.EventRow, es, h, M.EventRow{0n, 0n, N.z(0n), N.z(0n), N.zero()}), rows_e(es, t)}

def ctx_f_rows(+c: Ctx) -> List<&2, M.FundingRow>:
  match c:
    case Ctx{p, m, v, pol, stop, f_order, b_order, e_order}:
      rows_f(market_funding(m), f_order)

def ctx_b_rows(+c: Ctx) -> List<&2, M.BarRow>:
  match c:
    case Ctx{p, m, v, pol, stop, f_order, b_order, e_order}:
      rows_b(market_bars(m), b_order)

def ctx_e_rows(+c: Ctx) -> List<&2, M.EventRow>:
  match c:
    case Ctx{p, m, v, pol, stop, f_order, b_order, e_order}:
      rows_e(market_events(m), e_order)

def deliver_ev(+c: Ctx, +tick: N.Z, +r: SRes) -> SRes:
  match r:
    case SErr{a}:
      SErr{a}
    case SOk{s}:
      deliver_e(List.drop(&2, M.EventRow, ctx_e_rows(c), s_ei(s)), s, tick)

def deliver_be(+c: Ctx, +tick: N.Z, +r: SRes) -> SRes:
  match r:
    case SErr{a}:
      SErr{a}
    case SOk{s}:
      deliver_ev(c, tick, deliver_b(List.drop(&2, M.BarRow, ctx_b_rows(c), s_bi(s)), s, tick))

# Deliver every row known by the tick not yet delivered: funding, then bars, then events (SEMANTICS.md §3).
def deliver(+c: Ctx, +s: SState, +tick: N.Z) -> SRes:
  deliver_be(c, tick, deliver_f(List.drop(&2, M.FundingRow, ctx_f_rows(c), s_fi(s)), s, tick))

def pol_delta(+pol: Policy) -> N.Z:
  match pol:
    case Policy{delta, w_start}:
      delta

def pol_start(+pol: Policy) -> N.Z:
  match pol:
    case Policy{delta, w_start}:
      w_start

def fill_coin(+f: Fill) -> Nat:
  match f:
    case Fill{why, coin, qty, inputs_known, decision_price, decided, submitted, filled, source_open, reference, price, fee}:
      coin

def with_slippage(+b: Book, +d: N.Num) -> Book:
  match b:
    case Book{cash, pos, entry, realized, fees, slippage, funding, absorbed}:
      Book{cash, pos, entry, realized, fees, N.add(slippage, d), funding, absorbed}

def with_fill(+s: SState, +f: Fill) -> SState:
  match s:
    case SState{machine, book, marks, trace, orders, returns, gross, equity, prev_equity, prev_costs, fi, bi, ei}:
      match f:
        case Fill{why, coin, qty, inputs_known, decision_price, decided, submitted, filled, source_open, reference, price, fee}:
          SState{machine, with_slippage(book_fill(book, coin, qty, price, fee), N.mul(qty, N.sub(price, reference))), marks,
            M.snoc(SEvent, trace, EFill{Fill{why, coin, qty, inputs_known, decision_price, decided, submitted, filled, source_open, reference, price, fee}}),
            orders, returns, gross, equity, prev_equity, prev_costs, fi, bi, ei}


def exec_checked(+chk: Maybe<&2, Abort>, +s: SState, +f: Fill) -> SRes:
  match chk:
    case Some{a}:
      SErr{a}
    case None{}:
      SOk{with_fill(s, f)}

def execute(+c: Ctx, +s: SState, +f: Fill) -> SRes:
  exec_checked(check_fill(f, ctx_m(c), ctx_v(c)), s, f)

def closeout(+c: Ctx, +coin: Nat, +qty: N.Num, +ref: N.Num, +why: Why, +t: N.Z, +src: N.Z) -> Fill:
  +price = fill_price(ctx_v(c), coin, qty, ref)
  Fill{why, coin, qty, t, ref, t, t, t, src, ref, price, N.mul(N.mul(N.abs(qty), price), taker_fee(ctx_v(c)))}

# A held coin's latest bar with openTime ≤ b.
type LB is Data:
  LB{coin: Nat, bar: M.BarRow}

def find_lb(+l: +List<LB>, +coin: Nat) -> Maybe<&2, M.BarRow>:
  match l:
    case Nil{}:
      None{}
    case Con{h, t}:
      match h:
        case LB{k, bar}:
          Bool.pick(Maybe<&2, M.BarRow>, Nat.is_eq(k, coin), Some{bar}, find_lb(t, coin))

def adverse_of(+found: Maybe<&2, M.BarRow>, +marks: +List<N.Num>, +coin: Nat, +q: N.Num) -> N.Num:
  match found:
    case None{}:
      M.at(N.Num, marks, coin, N.zero())
    case Some{bar}:
      Bool.pick(N.Num, N.lt(N.zero(), q), bar_px(2n, bar), bar_px(1n, bar))

def adverse(+latest: +List<LB>, +marks: +List<N.Num>, +coin: Nat, +q: N.Num) -> N.Num:
  adverse_of(find_lb(latest, coin), marks, coin, q)

def open_of(+found: Maybe<&2, M.BarRow>) -> N.Z:
  match found:
    case None{}:
      bar_open(default_bar())
    case Some{bar}:
      bar_open(bar)

def exec_then(+r: SRes, +c: Ctx, +f: Fill) -> SRes:
  match r:
    case SErr{a}:
      SErr{a}
    case SOk{t}:
      execute(c, t, f)

# Liquidate each listed position at its adverse price (a closeout at b + BAR from its latest bar).
def liquidate(+held: +List<Entry>, +c: Ctx, +latest: +List<LB>, +marks: +List<N.Num>, +t: N.Z, +r: SRes) -> SRes:
  match held:
    case Nil{}:
      r
    case Con{e, rest}:
      liquidate(rest, c, latest, marks, t, exec_then(r, c, closeout(c, entry_k(e), N.neg(entry_x(e)), adverse(latest, marks, entry_k(e), entry_x(e)), WLiquidation{}, t, open_of(find_lb(latest, entry_k(e))))))

def book_pos(+b: Book) -> List<&2, Entry>:
  match b:
    case Book{cash, pos, entry, realized, fees, slippage, funding, absorbed}:
      pos

def absorbed_state(+r: SRes) -> SRes:
  match r:
    case SErr{a}:
      SErr{a}
    case SOk{s}:
      match s:
        case SState{machine, book, marks, trace, orders, returns, gross, equity, prev_equity, prev_costs, fi, bi, ei}:
          SOk{SState{machine, book_absorb(book), marks, trace, orders, returns, gross, equity, prev_equity, prev_costs, fi, bi, ei}}

# Bankruptcy (SEMANTICS.md §7, item 5): unless equity is positive, every position still held is liquidated
# at its adverse price and the venue absorbs the negative balance.
def bankrupt(+c: Ctx, +s: SState, +b: N.Z, +latest: +List<LB>, +marks: +List<N.Num>) -> SRes:
  Bool.pick(SRes, N.lt(N.zero(), book_equity(s_book(s), s_marks(s))), SOk{s},
    absorbed_state(liquidate(book_pos(s_book(s)), c, latest, marks, N.zadd(b, N.BAR()), SOk{s})))

def node_slot(+nd: M.Node) -> Maybe<&2, Nat>:
  match nd:
    case M.NInput{i}:
      match i:
        case M.IEvent{s}:
          Some{s}
        case _:
          None{}
    case _:
      None{}

def slot_cons(+s: Maybe<&2, Nat>, +rest: +List<Nat>) -> List<&2, Nat>:
  match s:
    case None{}:
      rest
    case Some{x}:
      Con{x, rest}

def slots_go(+nodes: +List<M.Node>) -> List<&2, Nat>:
  match nodes:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      slot_cons(node_slot(h), slots_go(t))

# Event slots the program reads (SEMANTICS.md §8); duplicates do not change binding.
def all_in(+xs: +List<Nat>, +ys: +List<Nat>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case Con{h, t}:
      Bool.and(mem_nat(h, ys), all_in(t, ys))

def program_nodes(+p: M.Program) -> List<&2, M.Node>:
  match p:
    case M.Program{nodes, params, weight}:
      nodes

def bound(+c: Ctx) -> Bool:
  all_in(slots_go(program_nodes(ctx_p(c))), market_bound(ctx_m(c)))

def state0(+c: Ctx) -> SState:
  SState{M.init(ctx_p(c), coins(c)), Book{initial(), Nil{}, Nil{}, N.zero(), N.zero(), N.zero(), N.zero(), N.zero()},
    M.rep(N.Num, coins(c), N.div(N.zero(), N.zero())), Nil{}, Nil{}, Nil{}, Nil{}, Nil{}, initial(), N.zero(), 0n, 0n, 0n}

def ticked(+c: Ctx, +t: N.Z, +r: SRes) -> SRes:
  match r:
    case SErr{a}:
      SErr{a}
    case SOk{s}:
      SOk{set_machine(s, M.tick(ctx_p(c), s_machine(s), mask(c, t), t))}

# The binding preflight, then the first delivery and tick (SEMANTICS.md §4, §8).
def start(+c: Ctx) -> SRes:
  Bool.pick(SRes, bound(c),
    ticked(c, pol_start(ctx_pol(c)), deliver(c, state0(c), N.zadd(pol_start(ctx_pol(c)), pol_delta(ctx_pol(c))))),
    SErr{InputUnavailable{}})

def set_book_trace(+s: SState, +book: Book, +ev: SEvent) -> SState:
  match s:
    case SState{machine, b0, marks, trace, orders, returns, gross, equity, prev_equity, prev_costs, fi, bi, ei}:
      SState{machine, book, marks, M.snoc(SEvent, trace, ev), orders, returns, gross, equity, prev_equity, prev_costs, fi, bi, ei}

def push_event(+s: SState, +ev: SEvent) -> SState:
  set_book_trace(s, s_book(s), ev)

def settle_with(+st: Settled, +s: SState, +h: N.Z, +coin: Nat, +rate: N.Num, +price: N.Num) -> SState:
  match st:
    case Settled{book, paid}:
      set_book_trace(s, book, EFunding{h, coin, rate, price, paid})

def settle_bar(+i: Maybe<&2, Nat>, +rate: N.Num, +c: Ctx, +s: SState, +h: N.Z, +coin: Nat) -> SState:
  match i:
    case None{}:
      s
    case Some{k}:
      settle_with(book_settle(s_book(s), coin, bar_px(0n, bar_index(ctx_m(c), k)), rate), s, h, coin, rate, bar_px(0n, bar_index(ctx_m(c), k)))

def settle_rate(+r: Maybe<&2, N.Num>, +c: Ctx, +s: SState, +h: N.Z, +coin: Nat) -> SState:
  match r:
    case None{}:
      s
    case Some{rate}:
      settle_bar(bar_at(market_bars(ctx_m(c)), coin, N.zsub(h, N.zmod(h, N.BAR()))), rate, c, s, h, coin)

def settle_held(+held: +List<Entry>, +c: Ctx, +h: N.Z, +s: SState) -> SState:
  match held:
    case Nil{}:
      s
    case Con{e, rest}:
      settle_held(rest, c, h, settle_rate(rate_at(market_funding(ctx_m(c)), entry_k(e), h), c, s, h, entry_k(e)))

# 1. Funding at each hour of the step, for each held coin.
def phase_funding(+k: Nat, +j: Nat, +c: Ctx, +b: N.Z, +s: SState) -> SState:
  match k:
    case 0n:
      s
    case 1n+r:
      phase_funding(r, Nat.add(j, 1n), c, b, settle_held(book_pos(s_book(s)), c, N.zadd(b, N.zmul(N.z(j), N.HOUR())), s))

# 2. Marks: each held coin's latest bar with openTime ≤ b, and its close as the mark.
def latest_at(+c: Ctx, +coin: Nat, +times: +List<N.Z>, +k: Nat) -> Maybe<&2, LB>:
  match k:
    case 0n:
      None{}
    case 1n+j:
      Some{LB{coin, bar_index(ctx_m(c), get_nat(bar_at(market_bars(ctx_m(c)), coin, M.at(N.Z, times, j, N.z(0n))), 0n))}}


def latest_bar(+c: Ctx, +coin: Nat, +b: N.Z) -> Maybe<&2, LB>:
  latest_at(c, coin, bar_times(market_bars(ctx_m(c)), coin), pp_le(bar_times(market_bars(ctx_m(c)), coin), b))

def lb_cons(+x: Maybe<&2, LB>, +rest: +List<LB>) -> List<&2, LB>:
  match x:
    case None{}:
      rest
    case Some{lb}:
      Con{lb, rest}


def latests(+held: +List<Entry>, +c: Ctx, +b: N.Z) -> List<&2, LB>:
  match held:
    case Nil{}:
      Nil{}
    case Con{e, rest}:
      lb_cons(latest_bar(c, entry_k(e), b), latests(rest, c, b))

def set_marks(+latest: +List<LB>, +marks: +List<N.Num>) -> List<&2, N.Num>:
  match latest:
    case Nil{}:
      marks
    case Con{lb, rest}:
      match lb:
        case LB{coin, bar}:
          set_marks(rest, M.put(N.Num, marks, coin, bar_px(3n, bar)))

def with_marks(+s: SState, +marks: +List<N.Num>) -> SState:
  match s:
    case SState{machine, book, m0, trace, orders, returns, gross, equity, prev_equity, prev_costs, fi, bi, ei}:
      SState{machine, book, marks, trace, orders, returns, gross, equity, prev_equity, prev_costs, fi, bi, ei}

def venue_lev(+v: Venue, +coin: Nat) -> N.Num:
  match v:
    case Venue{taker_fee, min_notional, sz_decimals, min_tier_leverage, cost_bps}:
      M.at(N.Num, min_tier_leverage, coin, N.zero())

def at_adverse(+held: +List<Entry>, +latest: +List<LB>, +marks: +List<N.Num>) -> List<&2, N.Num>:
  match held:
    case Nil{}:
      Nil{}
    case Con{e, rest}:
      Con{N.mul(entry_x(e), adverse(latest, marks, entry_k(e), entry_x(e))), at_adverse(rest, latest, marks)}

def margins(+held: +List<Entry>, +v: Venue, +latest: +List<LB>, +marks: +List<N.Num>) -> List<&2, N.Num>:
  match held:
    case Nil{}:
      Nil{}
    case Con{e, rest}:
      Con{N.div(N.mul(N.abs(entry_x(e)), adverse(latest, marks, entry_k(e), entry_x(e))), N.mul(N.of_nat(2n), venue_lev(v, entry_k(e)))), margins(rest, v, latest, marks)}

def book_cash(+b: Book) -> N.Num:
  match b:
    case Book{cash, pos, entry, realized, fees, slippage, funding, absorbed}:
      cash

# 3. Margin at each held coin's adverse extreme; a breach liquidates every position there.
def phase_margin(+c: Ctx, +b: N.Z, +s: SState, +latest: +List<LB>) -> SRes:
  +held = book_pos(s_book(s))
  Bool.pick(SRes, Bool.and(Bool.not(List.is_empty(&2, Entry, held)), N.lt(N.add(book_cash(s_book(s)), M.total(at_adverse(held, latest, s_marks(s)))), M.total(margins(held, ctx_v(c), latest, s_marks(s))))),
    liquidate(held, c, latest, s_marks(s), N.zadd(b, N.BAR()), SOk{s}), SOk{s})

def iv_stop(+iv: Iv) -> N.Z:
  match iv:
    case Iv{start, stop}:
      stop

def delist_one(+r: SRes, +c: Ctx, +b: N.Z, +latest: +List<LB>, +e: Entry) -> SRes:
  match r:
    case SErr{a}:
      SErr{a}
    case SOk{t}:
      Bool.pick(SRes, N.zle(iv_stop(M.at(Iv, market_intervals(ctx_m(c)), entry_k(e), Iv{N.z(0n), N.z(0n)})), N.zadd(b, N.BAR())),
        execute(c, t, closeout(c, entry_k(e), N.neg(entry_x(e)), M.at(N.Num, s_marks(t), entry_k(e), N.zero()), WDelisting{}, N.zadd(b, N.BAR()), open_of(find_lb(latest, entry_k(e))))),
        SOk{t})

def delist_loop(+held: +List<Entry>, +c: Ctx, +b: N.Z, +latest: +List<LB>, +r: SRes) -> SRes:
  match held:
    case Nil{}:
      r
    case Con{e, rest}:
      delist_loop(rest, c, b, latest, delist_one(r, c, b, latest, e))

# 4. Delisting closeouts at the mark, for each position whose interval ends by b + BAR.
def phase_delist(+c: Ctx, +b: N.Z, +latest: +List<LB>, +r: SRes) -> SRes:
  match r:
    case SErr{a}:
      SErr{a}
    case SOk{s}:
      delist_loop(book_pos(s_book(s)), c, b, latest, SOk{s})

def bankrupt_r(+c: Ctx, +b: N.Z, +latest: +List<LB>, +marks: +List<N.Num>, +r: SRes) -> SRes:
  match r:
    case SErr{a}:
      SErr{a}
    case SOk{s}:
      bankrupt(c, s, b, latest, marks)

def book_costs(+b: Book) -> N.Num:
  match b:
    case Book{cash, pos, entry, realized, fees, slippage, funding, absorbed}:
      N.add(fees, slippage)

def ret_of(+prev: N.Num, +e1: N.Num) -> N.Num:
  Bool.pick(N.Num, N.lt(N.zero(), prev), Bool.pick(N.Num, N.lt(N.zero(), e1), N.sub(N.div(e1, prev), N.one()), N.neg(N.one())), N.zero())

def gross_of(+prev: N.Num, +e1: N.Num, +costs: N.Num, +prev_costs: N.Num) -> N.Num:
  Bool.pick(N.Num, N.lt(N.zero(), prev), N.div(N.sub(N.add(N.sub(e1, prev), costs), prev_costs), prev), N.zero())

def recorded(+s: SState, +t: N.Z, +e1: N.Num, +e2: N.Num) -> SState:
  match s:
    case SState{machine, book, marks, trace, orders, returns, gross, equity, prev_equity, prev_costs, fi, bi, ei}:
      SState{machine, book, marks, M.snoc(SEvent, trace, EEquity{t, e1, e2}), orders,
        M.snoc(N.Num, returns, ret_of(prev_equity, e1)), M.snoc(N.Num, gross, gross_of(prev_equity, e1, book_costs(book), prev_costs)),
        M.snoc(N.Num, equity, e1), e1, book_costs(book), fi, bi, ei}

def s_prev(+s: SState) -> N.Num:
  match s:
    case SState{machine, book, marks, trace, orders, returns, gross, equity, prev_equity, prev_costs, fi, bi, ei}:
      prev_equity

# 6. Accounting (NaN-aware), the return and its bound, and the step's equity record.
def account(+s: SState, +t: N.Z) -> SRes:
  +e1 = book_equity(s_book(s), s_marks(s))
  +e2 = book_reconciled(s_book(s), s_marks(s))
  Bool.pick(SRes, Bool.not(N.le(N.abs(N.sub(e1, e2)), accounting_tolerance())), SErr{Accounting{}},
    Bool.pick(SRes, Bool.not(N.le(N.neg(N.one()), ret_of(s_prev(s), e1))), SErr{Bound{}}, SOk{recorded(s, t, e1, e2)}))

def phase_account(+t: N.Z, +r: SRes) -> SRes:
  match r:
    case SErr{a}:
      SErr{a}
    case SOk{s}:
      account(s, t)

def due_at(+d: Due) -> N.Z:
  match d:
    case Due{t, o}:
      t

def due_order(+d: Due) -> Order:
  match d:
    case Due{t, o}:
      o

def due_now(+ds: +List<Due>, +t: N.Z) -> List<&2, Order>:
  match ds:
    case Nil{}:
      Nil{}
    case Con{d, rest}:
      Bool.pick(List<&2, Order>, N.zeq(due_at(d), t), Con{due_order(d), due_now(rest, t)}, due_now(rest, t))

def not_due(+ds: +List<Due>, +t: N.Z) -> List<&2, Due>:
  match ds:
    case Nil{}:
      Nil{}
    case Con{d, rest}:
      Bool.pick(List<&2, Due>, N.zeq(due_at(d), t), not_due(rest, t), Con{d, not_due(rest, t)})

def s_orders(+s: SState) -> List<&2, Due>:
  match s:
    case SState{machine, book, marks, trace, orders, returns, gross, equity, prev_equity, prev_costs, fi, bi, ei}:
      orders

def with_orders(+s: SState, +orders: +List<Due>) -> SState:
  match s:
    case SState{machine, book, marks, trace, o0, returns, gross, equity, prev_equity, prev_costs, fi, bi, ei}:
      SState{machine, book, marks, trace, orders, returns, gross, equity, prev_equity, prev_costs, fi, bi, ei}

def order_fill(+o: Order, +c: Ctx, +t: N.Z, +bar: M.BarRow) -> Fill:
  match o:
    case Order{coin, qty, price, inputs_known, decided}:
      Fill{WFill{}, coin, qty, inputs_known, price, decided, decided, t, t, bar_px(0n, bar), fill_price(ctx_v(c), coin, qty, bar_px(0n, bar)),
        N.mul(N.mul(N.abs(qty), fill_price(ctx_v(c), coin, qty, bar_px(0n, bar))), taker_fee(ctx_v(c)))}

def order_coin(+o: Order) -> Nat:
  match o:
    case Order{coin, qty, price, inputs_known, decided}:
      coin

def order_qty(+o: Order) -> N.Num:
  match o:
    case Order{coin, qty, price, inputs_known, decided}:
      qty

def fill_one(+i: Maybe<&2, Nat>, +c: Ctx, +t: N.Z, +e1: N.Num, +o: Order, +s: SState) -> SRes:
  match i:
    case None{}:
      SOk{push_event(s, EUnfilled{t, order_coin(o), order_qty(o)})}
    case Some{k}:
      Bool.pick(SRes, Bool.and(N.zle(N.z(1n), bar_trades(bar_index(ctx_m(c), k))), N.lt(N.zero(), e1)),
        execute(c, s, order_fill(o, c, t, bar_index(ctx_m(c), k))),
        SOk{push_event(s, EUnfilled{t, order_coin(o), order_qty(o)})})

def fill_then(+r: SRes, +c: Ctx, +t: N.Z, +e1: N.Num, +o: Order) -> SRes:
  match r:
    case SErr{a}:
      SErr{a}
    case SOk{s}:
      fill_one(bar_at(market_bars(ctx_m(c)), order_coin(o), t), c, t, e1, o, s)

def fill_loop(+due: +List<Order>, +c: Ctx, +t: N.Z, +e1: N.Num, +r: SRes) -> SRes:
  match due:
    case Nil{}:
      r
    case Con{o, rest}:
      fill_loop(rest, c, t, e1, fill_then(r, c, t, e1, o))

# 7. The orders due at b + BAR fill at that bar's open if it traded and the step's equity is positive;
# otherwise they are unfilled. None executes when the run's horizon ends first.
def fills(+s: SState, +c: Ctx, +b: N.Z) -> SRes:
  +t = N.zadd(b, N.BAR())
  Bool.pick(SRes, N.zle(N.zadd(b, N.zmul(N.z(3n), N.BAR())), ctx_stop(c)),
    fill_loop(due_now(s_orders(s), t), c, t, s_prev(s), SOk{with_orders(s, not_due(s_orders(s), t))}),
    SOk{with_orders(s, not_due(s_orders(s), t))})

def phase_fills(+c: Ctx, +b: N.Z, +r: SRes) -> SRes:
  match r:
    case SErr{a}:
      SErr{a}
    case SOk{s}:
      fills(s, c, b)

def deliver_after(+c: Ctx, +h: N.Z, +r: SRes) -> SRes:
  match r:
    case SErr{a}:
      SErr{a}
    case SOk{s}:
      deliver(c, s, N.zadd(h, pol_delta(ctx_pol(c))))

# 8. For each hour of the step, delivery up to the hour plus δ, then a tick.
def tick_hour(+c: Ctx, +h: N.Z, +r: SRes) -> SRes:
  ticked(c, h, deliver_after(c, h, r))

def phase_ticks(+k: Nat, +j: Nat, +c: Ctx, +b: N.Z, +r: SRes) -> SRes:
  match k:
    case 0n:
      r
    case 1n+rest:
      phase_ticks(rest, Nat.add(j, 1n), c, b, tick_hour(c, N.zadd(b, N.zmul(N.z(j), N.HOUR())), r))

# A coin's target weight.
type CW is Data:
  CW{coin: Nat, w: N.Num}

type Picked is Data:
  Picked{s: SState, ws: List<&2, CW>}

def iv_start(+iv: Iv) -> N.Z:
  match iv:
    case Iv{start, stop}:
      start

def fresh_f(+r: Maybe<&2, M.FundingRow>, +t: N.Z) -> Bool:
  match r:
    case None{}:
      False{}
    case Some{f}:
      N.zeq(f_event(f), t)

def fresh_b(+r: Maybe<&2, M.BarRow>, +t: N.Z) -> Bool:
  match r:
    case None{}:
      False{}
    case Some{bar}:
      N.zeq(bar_event(bar), t)

def m_funding(+m: M.MState) -> List<&2, Maybe<&2, M.FundingRow>>:
  match m:
    case M.MState{vals, wins, since, funding, bar, events, hour, max_known}:
      funding

def m_bar(+m: M.MState) -> List<&2, Maybe<&2, M.BarRow>>:
  match m:
    case M.MState{vals, wins, since, funding, bar, events, hour, max_known}:
      bar

def m_known(+m: M.MState) -> N.Z:
  match m:
    case M.MState{vals, wins, since, funding, bar, events, hour, max_known}:
      max_known

def weight_of(+v: M.Val, +pk: Picked, +coin: Nat, +td: N.Z) -> Picked:
  match v:
    case M.VSome{w}:
      match pk:
        case Picked{s, ws}:
          Picked{s, M.snoc(CW, ws, CW{coin, w})}
    case M.VNone{}:
      match pk:
        case Picked{s, ws}:
          Picked{push_event(s, EHold{td, coin, Undefined{}}), ws}

def weight_idx(+p: M.Program) -> Nat:
  match p:
    case M.Program{nodes, params, weight}:
      weight

def pick_coin(+c: Ctx, +bigb: N.Z, +td: N.Z, +coin: Nat, +pk: Picked) -> Picked:
  match pk:
    case Picked{s, ws}:
      Bool.pick(Picked, Bool.not(Bool.and(N.zle(iv_start(M.at(Iv, market_intervals(ctx_m(c)), coin, Iv{N.z(0n), N.z(0n)})), bigb), N.zle(N.zadd(bigb, N.zmul(N.z(2n), N.BAR())), iv_stop(M.at(Iv, market_intervals(ctx_m(c)), coin, Iv{N.z(0n), N.z(0n)}))))),
        Picked{s, ws},
        Bool.pick(Picked, Bool.not(Bool.and(fresh_f(M.at(Maybe<&2, M.FundingRow>, m_funding(s_machine(s)), coin, None{}), bigb), fresh_b(M.at(Maybe<&2, M.BarRow>, m_bar(s_machine(s)), coin, None{}), bigb))),
          Picked{push_event(s, EHold{td, coin, Stale{}}), ws},
          weight_of(M.at(M.Val, M.row(s_machine(s), weight_idx(ctx_p(c))), coin, M.VNone{}), Picked{s, ws}, coin, td)))

def pick_loop(+k: Nat, +coin: Nat, +c: Ctx, +bigb: N.Z, +td: N.Z, +pk: Picked) -> Picked:
  match k:
    case 0n:
      pk
    case 1n+r:
      pick_loop(r, Nat.add(coin, 1n), c, bigb, td, pick_coin(c, bigb, td, coin, pk))

def largest(+ws: +List<CW>, +acc: N.Num) -> N.Num:
  match ws:
    case Nil{}:
      acc
    case Con{h, t}:
      match h:
        case CW{coin, w}:
          largest(t, M.nmax(acc, N.abs(w)))

def rel_terms(+ws: +List<CW>, +big: N.Num) -> List<&2, N.Num>:
  match ws:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      match h:
        case CW{coin, w}:
          Con{N.div(N.abs(w), big), rel_terms(t, big)}

def scaled(+w: N.Num, +big: N.Num, +rel: N.Num) -> N.Num:
  Bool.pick(N.Num, N.lt(max_gross(), N.mul(rel, big)), N.mul(N.div(w, big), N.div(max_gross(), rel)), w)

def gross_terms(+ws: +List<CW>, +big: N.Num, +rel: N.Num) -> List<&2, N.Num>:
  match ws:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      match h:
        case CW{coin, w}:
          Con{N.abs(scaled(w, big, rel)), gross_terms(t, big, rel)}

def venue_dec(+v: Venue, +coin: Nat) -> Nat:
  match v:
    case Venue{taker_fee, min_notional, sz_decimals, min_tier_leverage, cost_bps}:
      M.at(Nat, sz_decimals, coin, 0n)

def venue_min(+v: Venue) -> N.Num:
  match v:
    case Venue{taker_fee, min_notional, sz_decimals, min_tier_leverage, cost_bps}:
      min_notional

def bar_close(+r: Maybe<&2, M.BarRow>) -> N.Num:
  match r:
    case None{}:
      bar_px(3n, default_bar())
    case Some{bar}:
      bar_px(3n, bar)

def capped(+qty: N.Num, +price: N.Num, +dec: Nat) -> N.Num:
  Bool.pick(N.Num, N.lt(max_order_notional(), N.mul(N.abs(qty), price)), N.mul(signum(qty), truncate(N.div(max_order_notional(), price), dec)), qty)

def decided_order(+s: SState, +coin: Nat, +w: N.Num, +qty: N.Num, +price: N.Num, +td: N.Z, +bigb: N.Z) -> SState:
  match s:
    case SState{machine, book, marks, trace, orders, returns, gross, equity, prev_equity, prev_costs, fi, bi, ei}:
      SState{machine, book, marks, M.snoc(SEvent, trace, EDecision{td, coin, w, qty}),
        M.snoc(Due, orders, Due{N.zadd(bigb, N.BAR()), Order{coin, qty, price, m_known(machine), td}}), returns, gross, equity, prev_equity, prev_costs, fi, bi, ei}

def place(+c: Ctx, +s: SState, +coin: Nat, +w: N.Num, +price: N.Num, +td: N.Z, +bigb: N.Z, +qty: N.Num) -> SState:
  Bool.pick(SState, Bool.and(Bool.not(N.is_zero(qty)), Bool.or(N.le(venue_min(ctx_v(c)), N.mul(N.abs(qty), price)), N.is_zero(w))),
    decided_order(s, coin, w, qty, price, td, bigb), s)

def order_one(+c: Ctx, +e1: N.Num, +big: N.Num, +rel: N.Num, +td: N.Z, +bigb: N.Z, +cw: CW, +s: SState) -> SState:
  match cw:
    case CW{coin, w0}:
      +w = scaled(w0, big, rel)
      +price = bar_close(M.at(Maybe<&2, M.BarRow>, m_bar(s_machine(s)), coin, None{}))
      +held = get_d(assoc(book_pos(s_book(s)), coin), N.zero())
      place(c, s, coin, w, price, td, bigb,
        capped(Bool.pick(N.Num, N.is_zero(w), N.neg(held), truncate(N.sub(N.div(N.mul(w, e1), price), held), venue_dec(ctx_v(c), coin))), price, venue_dec(ctx_v(c), coin)))

def order_loop(+ws: +List<CW>, +c: Ctx, +e1: N.Num, +big: N.Num, +rel: N.Num, +td: N.Z, +bigb: N.Z, +s: SState) -> SState:
  match ws:
    case Nil{}:
      s
    case Con{cw, rest}:
      order_loop(rest, c, e1, big, rel, td, bigb, order_one(c, e1, big, rel, td, bigb, cw, s))

def decide_with(+c: Ctx, +e1: N.Num, +td: N.Z, +bigb: N.Z, +pk: Picked) -> SRes:
  match pk:
    case Picked{s, ws}:
      +big = largest(ws, N.zero())
      +rel = M.total(rel_terms(ws, big))
      Bool.pick(SRes, Bool.not(N.le(M.total(gross_terms(ws, big, rel)), N.mul(max_gross(), N.add(N.one(), order_slack())))), SErr{Portfolio{}},
        SOk{order_loop(ws, c, e1, big, rel, td, bigb, s)})

# 9. The decision at B + δ, B = b + BAR: eligibility, holds, weights, gross scaling and orders.
def decide(+c: Ctx, +b: N.Z, +e1: N.Num, +r: SRes) -> SRes:
  match r:
    case SErr{a}:
      SErr{a}
    case SOk{s}:
      decide_with(c, e1, N.zadd(N.zadd(b, N.BAR()), pol_delta(ctx_pol(c))), N.zadd(b, N.BAR()),
        pick_loop(coins(c), 0n, c, N.zadd(b, N.BAR()), N.zadd(N.zadd(b, N.BAR()), pol_delta(ctx_pol(c))), Picked{s, Nil{}}))

def prev_of(+r: SRes) -> N.Num:
  match r:
    case SErr{a}:
      N.zero()
    case SOk{s}:
      s_prev(s)

def after_marks(+c: Ctx, +b: N.Z, +s: SState, +latest: +List<LB>) -> SRes:
  +acc = phase_account(N.zadd(b, N.BAR()), bankrupt_r(c, b, latest, s_marks(s), phase_delist(c, b, latest, phase_margin(c, b, s, latest))))
  decide(c, b, prev_of(acc), phase_ticks(4n, 1n, c, b, phase_fills(c, b, acc)))

# One 4h step from b (SEMANTICS.md §7, items 1 to 9).
def step(+c: Ctx, +s0: SState, +b: N.Z) -> SRes:
  +s1 = phase_funding(4n, 1n, c, b, s0)
  +latest = latests(book_pos(s_book(s1)), c, b)
  after_marks(c, b, with_marks(s1, set_marks(latest, s_marks(s1))), latest)

# The step boundaries of a run: b = wStart, wStart + BAR, … while b + 2·BAR ≤ stop.
def bounds_go(+k: Nat, +j: Nat, +c: Ctx) -> List<&2, N.Z>:
  match k:
    case 0n:
      Nil{}
    case 1n+r:
      Bool.pick(List<&2, N.Z>, N.zle(N.zadd(N.zadd(pol_start(ctx_pol(c)), N.zmul(N.z(j), N.BAR())), N.zmul(N.z(2n), N.BAR())), ctx_stop(c)),
        Con{N.zadd(pol_start(ctx_pol(c)), N.zmul(N.z(j), N.BAR())), bounds_go(r, Nat.add(j, 1n), c)},
        bounds_go(r, Nat.add(j, 1n), c))

def zto_nat(+z: N.Z) -> Nat:
  match z:
    case N.Z{neg, mag}:
      Bool.pick(Nat, neg, 0n, mag)

def bounds(+c: Ctx) -> List<&2, N.Z>:
  bounds_go(Nat.add(zto_nat(N.zdiv(N.zsub(ctx_stop(c), pol_start(ctx_pol(c))), N.BAR())), 1n), 0n, c)

def step_then(+c: Ctx, +b: N.Z, +r: SRes) -> SRes:
  match r:
    case SErr{a}:
      SErr{a}
    case SOk{s}:
      step(c, s, b)

def steps_go(+bs: +List<N.Z>, +c: Ctx, +r: SRes) -> SRes:
  match bs:
    case Nil{}:
      r
    case Con{b, rest}:
      steps_go(rest, c, step_then(c, b, r))

# The state after the first k steps (or the abort).
def steps(+c: Ctx, +k: Nat) -> SRes:
  steps_go(List.take(&2, N.Z, bounds(c), k), c, start(c))

type RunRes is Data:
  RErr{a: Abort}
  ROk{r: Run}

def to_run(+r: SRes) -> RunRes:
  match r:
    case SErr{a}:
      RErr{a}
    case SOk{s}:
      match s:
        case SState{machine, book, marks, trace, orders, returns, gross, equity, prev_equity, prev_costs, fi, bi, ei}:
          ROk{Run{trace, returns, gross, equity}}

# The run (SEMANTICS.md §7): its trace and returns, or the abort.
def run(+p: M.Program, +m: Market, +v: Venue, +pol: Policy, +stop: N.Z) -> RunRes:
  to_run(steps(make(p, m, v, pol, stop), M.len(N.Z, bounds(make(p, m, v, pol, stop)))))
