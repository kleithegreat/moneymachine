import Base
import ./num.bend as N
import ./machine.bend as M
import ./sim.bend as S
import ./LAWS.bend as Laws

# Proofs of LAWS.bend. A result is "ok" when it is not the unavailable refusal: every step function
# keeps that, since R_INPUT_UNAVAILABLE is raised only by the preflight.

law pick_ok:
  for +b: Bool
  for +x: S.SRes
  for +y: S.SRes
  for hx: {Laws.unav(x) == False{} : Bool}
  for hy: {Laws.unav(y) == False{} : Bool}
  {Laws.unav(Bool.pick(S.SRes, b, x, y)) == False{} : Bool}

def pick_ok(b, x, y, hx, hy):
  match b:
    case True{}:
      hx
    case False{}:
      hy

law then_ok:
  for +r: M.MRes
  for +rest: S.SRes
  for h: {Laws.unav(rest) == False{} : Bool}
  {Laws.unav(S.then_(r, rest)) == False{} : Bool}

def then_ok(r, rest, h):
  match r:
    case M.MErr{k, t}:
      {==}
    case M.MOk{m}:
      h

law deliver_f_ok:
  for +rows: +List<M.FundingRow>
  for +s: S.SState
  for +tick: N.Z
  {Laws.unav(S.deliver_f(rows, s, tick)) == False{} : Bool}

def deliver_f_ok(rows, s, tick):
  match rows:
    case Nil{}:
      {==}
    case Con{f, rest}:
      +d = M.deliver_funding(S.s_machine(s), f, tick)
      pick_ok(N.zlt(tick, S.f_known(f)), S.SOk{s}, S.then_(d, S.deliver_f(rest, S.after(d, s, 0n), tick)), {==},
        then_ok(d, S.deliver_f(rest, S.after(d, s, 0n), tick), deliver_f_ok(rest, S.after(d, s, 0n), tick)))

law deliver_b_ok:
  for +rows: +List<M.BarRow>
  for +s: S.SState
  for +tick: N.Z
  {Laws.unav(S.deliver_b(rows, s, tick)) == False{} : Bool}

def deliver_b_ok(rows, s, tick):
  match rows:
    case Nil{}:
      {==}
    case Con{b, rest}:
      +d = M.deliver_bar(S.s_machine(s), b, tick)
      pick_ok(N.zlt(tick, S.bar_known(b)), S.SOk{s}, S.then_(d, S.deliver_b(rest, S.after(d, s, 1n), tick)), {==},
        then_ok(d, S.deliver_b(rest, S.after(d, s, 1n), tick), deliver_b_ok(rest, S.after(d, s, 1n), tick)))

law deliver_e_ok:
  for +rows: +List<M.EventRow>
  for +s: S.SState
  for +tick: N.Z
  {Laws.unav(S.deliver_e(rows, s, tick)) == False{} : Bool}

def deliver_e_ok(rows, s, tick):
  match rows:
    case Nil{}:
      {==}
    case Con{e, rest}:
      +d = M.deliver_event(S.s_machine(s), e, tick)
      pick_ok(N.zlt(tick, S.e_known(e)), S.SOk{s}, S.then_(d, S.deliver_e(rest, S.after(d, s, 2n), tick)), {==},
        then_ok(d, S.deliver_e(rest, S.after(d, s, 2n), tick), deliver_e_ok(rest, S.after(d, s, 2n), tick)))

law deliver_ev_ok:
  for +c: S.Ctx
  for +tick: N.Z
  for +r: S.SRes
  for h: {Laws.unav(r) == False{} : Bool}
  {Laws.unav(S.deliver_ev(c, tick, r)) == False{} : Bool}

def deliver_ev_ok(c, tick, r, h):
  match r:
    case S.SErr{a}:
      h
    case S.SOk{s}:
      deliver_e_ok(List.drop(&2, M.EventRow, S.ctx_e_rows(c), S.s_ei(s)), s, tick)

law deliver_be_ok:
  for +c: S.Ctx
  for +tick: N.Z
  for +r: S.SRes
  for h: {Laws.unav(r) == False{} : Bool}
  {Laws.unav(S.deliver_be(c, tick, r)) == False{} : Bool}

def deliver_be_ok(c, tick, r, h):
  match r:
    case S.SErr{a}:
      h
    case S.SOk{s}:
      +rows = List.drop(&2, M.BarRow, S.ctx_b_rows(c), S.s_bi(s))
      deliver_ev_ok(c, tick, S.deliver_b(rows, s, tick), deliver_b_ok(rows, s, tick))

law deliver_ok:
  for +c: S.Ctx
  for +s: S.SState
  for +tick: N.Z
  {Laws.unav(S.deliver(c, s, tick)) == False{} : Bool}

def deliver_ok(c, s, tick):
  +rows = List.drop(&2, M.FundingRow, S.ctx_f_rows(c), S.s_fi(s))
  deliver_be_ok(c, tick, S.deliver_f(rows, s, tick), deliver_f_ok(rows, s, tick))

law ticked_ok:
  for +c: S.Ctx
  for +t: N.Z
  for +r: S.SRes
  for h: {Laws.unav(r) == False{} : Bool}
  {Laws.unav(S.ticked(c, t, r)) == False{} : Bool}

def ticked_ok(c, t, r, h):
  match r:
    case S.SErr{a}:
      h
    case S.SOk{s}:
      {==}

def unm(+m: Maybe<&2, S.Abort>) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{a}:
      match a:
        case S.InputUnavailable{}:
          True{}
        case _:
          False{}

law pickm_ok:
  for +b: Bool
  for +x: Maybe<&2, S.Abort>
  for +y: Maybe<&2, S.Abort>
  for hx: {unm(x) == False{} : Bool}
  for hy: {unm(y) == False{} : Bool}
  {unm(Bool.pick(Maybe<&2, S.Abort>, b, x, y)) == False{} : Bool}

def pickm_ok(b, x, y, hx, hy):
  match b:
    case True{}:
      hx
    case False{}:
      hy

law check_bar_ok:
  for +bi: Maybe<&2, Nat>
  for +m: S.Market
  for +v: S.Venue
  for +why: S.Why
  for +coin: Nat
  for +qty: N.Num
  for +dp: N.Num
  for +sub: N.Z
  for +filled: N.Z
  for +ref: N.Num
  for +price: N.Num
  for +fee: N.Num
  {unm(S.check_bar(bi, m, v, why, coin, qty, dp, sub, filled, ref, price, fee)) == False{} : Bool}

def check_bar_ok(bi, m, v, why, coin, qty, dp, sub, filled, ref, price, fee):
  match bi:
    case None{}:
      {==}
    case Some{i}:
      +c2 = Bool.and(S.is_fill(why), N.lt(N.mul(S.max_order_notional(), N.add(N.one(), S.order_slack())), N.mul(N.abs(qty), dp)))
      pickm_ok(Bool.not(Bool.and(S.check_place(m, why, coin, qty, sub, filled, ref, S.bar_index(m, i)), S.check_priced(v, coin, qty, ref, price, fee))),
        Some{S.AFill{}}, Bool.pick(Maybe<&2, S.Abort>, c2, Some{S.Portfolio{}}, None{}), {==},
        pickm_ok(c2, Some{S.Portfolio{}}, None{}, {==}, {==}))

law check_fill_ok:
  for +f: S.Fill
  for +m: S.Market
  for +v: S.Venue
  {unm(S.check_fill(f, m, v)) == False{} : Bool}

def check_fill_ok(f, m, v):
  match f:
    case S.Fill{why, coin, qty, ik, dp, dec, sub, filled, so, ref, price, fee}:
      pickm_ok(Bool.not(Bool.and(N.zle(ik, dec), Bool.and(N.zle(dec, sub), N.zle(sub, filled)))), Some{S.Timing{}},
        S.check_bar(S.bar_at(S.market_bars(m), coin, so), m, v, why, coin, qty, dp, sub, filled, ref, price, fee), {==},
        check_bar_ok(S.bar_at(S.market_bars(m), coin, so), m, v, why, coin, qty, dp, sub, filled, ref, price, fee))

law exec_checked_ok:
  for +chk: Maybe<&2, S.Abort>
  for +s: S.SState
  for +f: S.Fill
  for h: {unm(chk) == False{} : Bool}
  {Laws.unav(S.exec_checked(chk, s, f)) == False{} : Bool}

def exec_checked_ok(chk, s, f, h):
  match chk:
    case None{}:
      {==}
    case Some{a}:
      match a:
        case S.Causality{}:
          {==}
        case S.Timing{}:
          {==}
        case S.AFill{}:
          {==}
        case S.Accounting{}:
          {==}
        case S.Portfolio{}:
          {==}
        case S.Bound{}:
          {==}
        case S.InputUnavailable{}:
          h

law execute_ok:
  for +c: S.Ctx
  for +s: S.SState
  for +f: S.Fill
  {Laws.unav(S.execute(c, s, f)) == False{} : Bool}

def execute_ok(c, s, f):
  exec_checked_ok(S.check_fill(f, S.ctx_m(c), S.ctx_v(c)), s, f, check_fill_ok(f, S.ctx_m(c), S.ctx_v(c)))

law exec_then_ok:
  for +r: S.SRes
  for +c: S.Ctx
  for +f: S.Fill
  for h: {Laws.unav(r) == False{} : Bool}
  {Laws.unav(S.exec_then(r, c, f)) == False{} : Bool}

def exec_then_ok(r, c, f, h):
  match r:
    case S.SErr{a}:
      h
    case S.SOk{t}:
      execute_ok(c, t, f)

law liquidate_ok:
  for +held: +List<S.Entry>
  for +c: S.Ctx
  for +latest: +List<S.LB>
  for +marks: +List<N.Num>
  for +t: N.Z
  for +r: S.SRes
  for h: {Laws.unav(r) == False{} : Bool}
  {Laws.unav(S.liquidate(held, c, latest, marks, t, r)) == False{} : Bool}

def liquidate_ok(held, c, latest, marks, t, r, h):
  match held:
    case Nil{}:
      h
    case Con{e, rest}:
      +f = S.closeout(c, S.entry_k(e), N.neg(S.entry_x(e)), S.adverse(latest, marks, S.entry_k(e), S.entry_x(e)), S.WLiquidation{}, t, S.open_of(S.find_lb(latest, S.entry_k(e))))
      liquidate_ok(rest, c, latest, marks, t, S.exec_then(r, c, f), exec_then_ok(r, c, f, h))

law absorbed_ok:
  for +r: S.SRes
  for h: {Laws.unav(r) == False{} : Bool}
  {Laws.unav(S.absorbed_state(r)) == False{} : Bool}

def absorbed_ok(r, h):
  match r:
    case S.SErr{a}:
      h
    case S.SOk{s}:
      match s:
        case S.SState{machine, book, marks, trace, orders, returns, gross, equity, prev_equity, prev_costs, fi, bi, ei}:
          {==}

law bankrupt_ok:
  for +c: S.Ctx
  for +s: S.SState
  for +b: N.Z
  for +latest: +List<S.LB>
  for +marks: +List<N.Num>
  {Laws.unav(S.bankrupt(c, s, b, latest, marks)) == False{} : Bool}

def bankrupt_ok(c, s, b, latest, marks):
  +l = S.liquidate(S.book_pos(S.s_book(s)), c, latest, marks, N.zadd(b, N.BAR()), S.SOk{s})
  pick_ok(N.lt(N.zero(), S.book_equity(S.s_book(s), S.s_marks(s))), S.SOk{s}, S.absorbed_state(l), {==},
    absorbed_ok(l, liquidate_ok(S.book_pos(S.s_book(s)), c, latest, marks, N.zadd(b, N.BAR()), S.SOk{s}, {==})))

law margin_ok:
  for +c: S.Ctx
  for +b: N.Z
  for +s: S.SState
  for +latest: +List<S.LB>
  {Laws.unav(S.phase_margin(c, b, s, latest)) == False{} : Bool}

def margin_ok(c, b, s, latest):
  +held = S.book_pos(S.s_book(s))
  pick_ok(Bool.and(Bool.not(List.is_empty(&2, S.Entry, held)), N.lt(N.add(S.book_cash(S.s_book(s)), M.total(S.at_adverse(held, latest, S.s_marks(s)))), M.total(S.margins(held, S.ctx_v(c), latest, S.s_marks(s))))),
    S.liquidate(held, c, latest, S.s_marks(s), N.zadd(b, N.BAR()), S.SOk{s}), S.SOk{s},
    liquidate_ok(held, c, latest, S.s_marks(s), N.zadd(b, N.BAR()), S.SOk{s}, {==}), {==})

law delist_one_ok:
  for +r: S.SRes
  for +c: S.Ctx
  for +b: N.Z
  for +latest: +List<S.LB>
  for +e: S.Entry
  for h: {Laws.unav(r) == False{} : Bool}
  {Laws.unav(S.delist_one(r, c, b, latest, e)) == False{} : Bool}

def delist_one_ok(r, c, b, latest, e, h):
  match r:
    case S.SErr{a}:
      h
    case S.SOk{t}:
      +f = S.closeout(c, S.entry_k(e), N.neg(S.entry_x(e)), M.at(N.Num, S.s_marks(t), S.entry_k(e), N.zero()), S.WDelisting{}, N.zadd(b, N.BAR()), S.open_of(S.find_lb(latest, S.entry_k(e))))
      pick_ok(N.zle(S.iv_stop(M.at(S.Iv, S.market_intervals(S.ctx_m(c)), S.entry_k(e), S.Iv{N.z(0n), N.z(0n)})), N.zadd(b, N.BAR())),
        S.execute(c, t, f), S.SOk{t}, execute_ok(c, t, f), {==})

law delist_loop_ok:
  for +held: +List<S.Entry>
  for +c: S.Ctx
  for +b: N.Z
  for +latest: +List<S.LB>
  for +r: S.SRes
  for h: {Laws.unav(r) == False{} : Bool}
  {Laws.unav(S.delist_loop(held, c, b, latest, r)) == False{} : Bool}

def delist_loop_ok(held, c, b, latest, r, h):
  match held:
    case Nil{}:
      h
    case Con{e, rest}:
      delist_loop_ok(rest, c, b, latest, S.delist_one(r, c, b, latest, e), delist_one_ok(r, c, b, latest, e, h))

law delist_ok:
  for +c: S.Ctx
  for +b: N.Z
  for +latest: +List<S.LB>
  for +r: S.SRes
  for h: {Laws.unav(r) == False{} : Bool}
  {Laws.unav(S.phase_delist(c, b, latest, r)) == False{} : Bool}

def delist_ok(c, b, latest, r, h):
  match r:
    case S.SErr{a}:
      h
    case S.SOk{s}:
      delist_loop_ok(S.book_pos(S.s_book(s)), c, b, latest, S.SOk{s}, {==})

law bankrupt_r_ok:
  for +c: S.Ctx
  for +b: N.Z
  for +latest: +List<S.LB>
  for +marks: +List<N.Num>
  for +r: S.SRes
  for h: {Laws.unav(r) == False{} : Bool}
  {Laws.unav(S.bankrupt_r(c, b, latest, marks, r)) == False{} : Bool}

def bankrupt_r_ok(c, b, latest, marks, r, h):
  match r:
    case S.SErr{a}:
      h
    case S.SOk{s}:
      bankrupt_ok(c, s, b, latest, marks)

law account_ok:
  for +s: S.SState
  for +t: N.Z
  {Laws.unav(S.account(s, t)) == False{} : Bool}

def account_ok(s, t):
  +e1 = S.book_equity(S.s_book(s), S.s_marks(s))
  +e2 = S.book_reconciled(S.s_book(s), S.s_marks(s))
  +c2 = Bool.not(N.le(N.neg(N.one()), S.ret_of(S.s_prev(s), e1)))
  pick_ok(Bool.not(N.le(N.abs(N.sub(e1, e2)), S.accounting_tolerance())), S.SErr{S.Accounting{}},
    Bool.pick(S.SRes, c2, S.SErr{S.Bound{}}, S.SOk{S.recorded(s, t, e1, e2)}), {==},
    pick_ok(c2, S.SErr{S.Bound{}}, S.SOk{S.recorded(s, t, e1, e2)}, {==}, {==}))

law account_r_ok:
  for +t: N.Z
  for +r: S.SRes
  for h: {Laws.unav(r) == False{} : Bool}
  {Laws.unav(S.phase_account(t, r)) == False{} : Bool}

def account_r_ok(t, r, h):
  match r:
    case S.SErr{a}:
      h
    case S.SOk{s}:
      account_ok(s, t)

law fill_one_ok:
  for +i: Maybe<&2, Nat>
  for +c: S.Ctx
  for +t: N.Z
  for +e1: N.Num
  for +o: S.Order
  for +s: S.SState
  {Laws.unav(S.fill_one(i, c, t, e1, o, s)) == False{} : Bool}

def fill_one_ok(i, c, t, e1, o, s):
  match i:
    case None{}:
      {==}
    case Some{k}:
      +f = S.order_fill(o, c, t, S.bar_index(S.ctx_m(c), k))
      pick_ok(Bool.and(N.zle(N.z(1n), S.bar_trades(S.bar_index(S.ctx_m(c), k))), N.lt(N.zero(), e1)),
        S.execute(c, s, f), S.SOk{S.push_event(s, S.EUnfilled{t, S.order_coin(o), S.order_qty(o)})}, execute_ok(c, s, f), {==})

law fill_then_ok:
  for +r: S.SRes
  for +c: S.Ctx
  for +t: N.Z
  for +e1: N.Num
  for +o: S.Order
  for h: {Laws.unav(r) == False{} : Bool}
  {Laws.unav(S.fill_then(r, c, t, e1, o)) == False{} : Bool}

def fill_then_ok(r, c, t, e1, o, h):
  match r:
    case S.SErr{a}:
      h
    case S.SOk{s}:
      fill_one_ok(S.bar_at(S.market_bars(S.ctx_m(c)), S.order_coin(o), t), c, t, e1, o, s)

law fill_loop_ok:
  for +due: +List<S.Order>
  for +c: S.Ctx
  for +t: N.Z
  for +e1: N.Num
  for +r: S.SRes
  for h: {Laws.unav(r) == False{} : Bool}
  {Laws.unav(S.fill_loop(due, c, t, e1, r)) == False{} : Bool}

def fill_loop_ok(due, c, t, e1, r, h):
  match due:
    case Nil{}:
      h
    case Con{o, rest}:
      fill_loop_ok(rest, c, t, e1, S.fill_then(r, c, t, e1, o), fill_then_ok(r, c, t, e1, o, h))

law fills_ok:
  for +s: S.SState
  for +c: S.Ctx
  for +b: N.Z
  {Laws.unav(S.fills(s, c, b)) == False{} : Bool}

def fills_ok(s, c, b):
  +t = N.zadd(b, N.BAR())
  +rest = {S.SOk{S.with_orders(s, S.not_due(S.s_orders(s), t))} : S.SRes}
  pick_ok(N.zle(N.zadd(b, N.zmul(N.z(3n), N.BAR())), S.ctx_stop(c)), S.fill_loop(S.due_now(S.s_orders(s), t), c, t, S.s_prev(s), rest), rest,
    fill_loop_ok(S.due_now(S.s_orders(s), t), c, t, S.s_prev(s), rest, {==}), {==})

law fills_r_ok:
  for +c: S.Ctx
  for +b: N.Z
  for +r: S.SRes
  for h: {Laws.unav(r) == False{} : Bool}
  {Laws.unav(S.phase_fills(c, b, r)) == False{} : Bool}

def fills_r_ok(c, b, r, h):
  match r:
    case S.SErr{a}:
      h
    case S.SOk{s}:
      fills_ok(s, c, b)

law deliver_after_ok:
  for +c: S.Ctx
  for +h: N.Z
  for +r: S.SRes
  for hr: {Laws.unav(r) == False{} : Bool}
  {Laws.unav(S.deliver_after(c, h, r)) == False{} : Bool}

def deliver_after_ok(c, h, r, hr):
  match r:
    case S.SErr{a}:
      hr
    case S.SOk{s}:
      deliver_ok(c, s, N.zadd(h, S.pol_delta(S.ctx_pol(c))))

law ticks_ok:
  for +k: Nat
  for +j: Nat
  for +c: S.Ctx
  for +b: N.Z
  for +r: S.SRes
  for h: {Laws.unav(r) == False{} : Bool}
  {Laws.unav(S.phase_ticks(k, j, c, b, r)) == False{} : Bool}

def ticks_ok(k, j, c, b, r, h):
  match k:
    case 0n:
      h
    case 1n+rest:
      +hh = N.zadd(b, N.zmul(N.z(j), N.HOUR()))
      ticks_ok(rest, Nat.add(j, 1n), c, b, S.tick_hour(c, hh, r),
        ticked_ok(c, hh, S.deliver_after(c, hh, r), deliver_after_ok(c, hh, r, h)))

law decide_with_ok:
  for +c: S.Ctx
  for +e1: N.Num
  for +td: N.Z
  for +bigb: N.Z
  for +pk: S.Picked
  {Laws.unav(S.decide_with(c, e1, td, bigb, pk)) == False{} : Bool}

def decide_with_ok(c, e1, td, bigb, pk):
  match pk:
    case S.Picked{s, ws}:
      +big = S.largest(ws, N.zero())
      +rel = M.total(S.rel_terms(ws, big))
      pick_ok(Bool.not(N.le(M.total(S.gross_terms(ws, big, rel)), N.mul(S.max_gross(), N.add(N.one(), S.order_slack())))), S.SErr{S.Portfolio{}},
        S.SOk{S.order_loop(ws, c, e1, big, rel, td, bigb, s)}, {==}, {==})

law decide_ok:
  for +c: S.Ctx
  for +b: N.Z
  for +e1: N.Num
  for +r: S.SRes
  for h: {Laws.unav(r) == False{} : Bool}
  {Laws.unav(S.decide(c, b, e1, r)) == False{} : Bool}

def decide_ok(c, b, e1, r, h):
  match r:
    case S.SErr{a}:
      h
    case S.SOk{s}:
      +bigb = N.zadd(b, N.BAR())
      +td = N.zadd(N.zadd(b, N.BAR()), S.pol_delta(S.ctx_pol(c)))
      decide_with_ok(c, e1, td, bigb, S.pick_loop(S.coins(c), 0n, c, bigb, td, S.Picked{s, Nil{}}))

law step_ok:
  for +c: S.Ctx
  for +s0: S.SState
  for +b: N.Z
  {Laws.unav(S.step(c, s0, b)) == False{} : Bool}

def step_ok(c, s0, b):
  +s1 = S.phase_funding(4n, 1n, c, b, s0)
  +latest = S.latests(S.book_pos(S.s_book(s1)), c, b)
  +s = S.with_marks(s1, S.set_marks(latest, S.s_marks(s1)))
  +r1 = S.phase_margin(c, b, s, latest)
  +r2 = S.phase_delist(c, b, latest, r1)
  +r3 = S.bankrupt_r(c, b, latest, S.s_marks(s), r2)
  +acc = S.phase_account(N.zadd(b, N.BAR()), r3)
  +h_acc = account_r_ok(N.zadd(b, N.BAR()), r3, bankrupt_r_ok(c, b, latest, S.s_marks(s), r2, delist_ok(c, b, latest, r1, margin_ok(c, b, s, latest))))
  +fl = S.phase_fills(c, b, acc)
  decide_ok(c, b, S.prev_of(acc), S.phase_ticks(4n, 1n, c, b, fl), ticks_ok(4n, 1n, c, b, fl, fills_r_ok(c, b, acc, h_acc)))

law step_then_unav:
  for +c: S.Ctx
  for +b: N.Z
  for +r: S.SRes
  {Laws.unav(S.step_then(c, b, r)) == Laws.unav(r) : Bool}

def step_then_unav(c, b, r):
  match r:
    case S.SErr{a}:
      {==}
    case S.SOk{s}:
      step_ok(c, s, b)

law steps_go_unav:
  for +bs: +List<N.Z>
  for +c: S.Ctx
  for +r: S.SRes
  {Laws.unav(S.steps_go(bs, c, r)) == Laws.unav(r) : Bool}

def steps_go_unav(bs, c, r):
  match bs:
    case Nil{}:
      {==}
    case Con{b, rest}:
      Equal.trans(Bool, Laws.unav(S.steps_go(rest, c, S.step_then(c, b, r))), Laws.unav(S.step_then(c, b, r)), Laws.unav(r),
        steps_go_unav(rest, c, S.step_then(c, b, r)), step_then_unav(c, b, r))

law to_run_unav:
  for +r: S.SRes
  {Laws.run_unav(S.to_run(r)) == Laws.unav(r) : Bool}

def to_run_unav(r):
  match r:
    case S.SErr{a}:
      match a:
        case S.Causality{}:
          {==}
        case S.Timing{}:
          {==}
        case S.AFill{}:
          {==}
        case S.Accounting{}:
          {==}
        case S.Portfolio{}:
          {==}
        case S.Bound{}:
          {==}
        case S.InputUnavailable{}:
          {==}
    case S.SOk{s}:
      match s:
        case S.SState{machine, book, marks, trace, orders, returns, gross, equity, prev_equity, prev_costs, fi, bi, ei}:
          {==}

law pick_refuse:
  for +b: Bool
  for +x: S.SRes
  for hx: {Laws.unav(x) == False{} : Bool}
  {Laws.unav(Bool.pick(S.SRes, b, x, S.SErr{S.InputUnavailable{}})) == Bool.not(b) : Bool}

def pick_refuse(b, x, hx):
  match b:
    case True{}:
      hx
    case False{}:
      {==}

law start_unav:
  for +c: S.Ctx
  {Laws.unav(S.start(c)) == Bool.not(S.bound(c)) : Bool}

def start_unav(c):
  +w = S.pol_start(S.ctx_pol(c))
  +t = N.zadd(w, S.pol_delta(S.ctx_pol(c)))
  pick_refuse(S.bound(c), S.ticked(c, w, S.deliver(c, S.state0(c), t)), ticked_ok(c, w, S.deliver(c, S.state0(c), t), deliver_ok(c, S.state0(c), t)))

def Laws.L5_binding(p, m, v, pol, stop):
  +c = S.make(p, m, v, pol, stop)
  +r = S.steps_go(List.take(&2, N.Z, S.bounds(c), M.len(N.Z, S.bounds(c))), c, S.start(c))
  Equal.trans(Bool, Laws.run_unav(S.to_run(r)), Laws.unav(r), Bool.not(S.bound(c)), to_run_unav(r),
    Equal.trans(Bool, Laws.unav(r), Laws.unav(S.start(c)), Bool.not(S.bound(c)),
      steps_go_unav(List.take(&2, N.Z, S.bounds(c), M.len(N.Z, S.bounds(c))), c, S.start(c)), start_unav(c)))

def Laws.L5_preflight(c):
  {==}
