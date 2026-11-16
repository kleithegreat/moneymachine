(* Step 2 test 4's countermodels, shared by the sandbox and local layer 1.
   These are independent, deliberately WRONG ledgers, not engine wrappers.
   Money/cost/price below are in millionths; units are whole synthetic lots.
   Both compatibility ties must accept BOTH ledgers on BOTH constructions. *)
module L = Mm2_lean.Ledger
module Q = Ledger_oracle.Q
module V = Venue_oracle

let check name condition = if not condition then failwith ("FAIL: " ^ name)
let micro n = Q.make (string_of_int n) "1000000"
let scaled wire = Q.mul (Q.of_wire wire) (Q.integer 1000000)
let rate = Q.make "3" "20000"

type defect = Printed_fee | Venue_cost
type state = { cash : Q.t; units : int; cost : Q.t; fee : Q.t; pnl : Q.t }

let initial =
  { cash = Q.integer 1000000000; units = 0; cost = Q.zero;
    fee = Q.zero; pnl = Q.zero }

let entry state = Q.div state.cost (Q.integer state.units)

let fill defect state units price =
  let notional = V.product (abs units) price in
  let fee = match defect with
    | Printed_fee -> Q.integer (V.fee notional rate)
    | Venue_cost -> Q.mul (Q.integer notional) rate in
  let next = state.units + units in
  let cost, pnl =
    if units > 0 then Q.add state.cost (Q.integer notional), Q.zero
    else begin
      check "countermodel only closes a held long" (units < 0 && next >= 0);
      let pnl = Q.mul (Q.integer (-units)) (Q.sub (Q.integer price) (entry state)) in
      let cost = if next = 0 then Q.zero else match defect with
        | Printed_fee -> Q.mul state.cost (Q.make (string_of_int next) (string_of_int state.units))
        | Venue_cost ->
          check "venue-cost countermodel stores whole millionths" (state.cost.d = "1");
          Q.integer (V.cut (int_of_string state.cost.n) (V.ratio next state.units)) in
      cost, pnl
    end in
  { cash = Q.sub (Q.sub state.cash (Q.integer (V.product units price))) fee;
    units = next; cost; fee; pnl }

let run_wrong defect fills =
  let rec loop state venue_cost partials = function
    | [] -> []
    | (units, price) :: rest ->
      let kept, next_partials = if units > 0 then
          venue_cost + V.product units price, partials
        else begin
          check "wrong ledger passes the cost tie before each close"
            (V.cost_compatible venue_cost partials state.cost);
          let _, kept = V.close venue_cost state.units (-units) price in
          kept, if state.units + units = 0 then 0 else partials + 1
        end in
      let next = fill defect state units price in
      check "wrong ledger passes the fee tie on each fill"
        (V.fee_compatible (V.fee (V.product (abs units) price) rate) next.fee);
      check "wrong ledger passes the cost tie after each fill"
        (V.cost_compatible kept next_partials next.cost);
      next :: loop next kept next_partials rest
  in
  loop initial 0 0 fills

let engine fills =
  let tier : L.tier =
    { from_ms = 0L; name = "base"; maker = Q.wire rate; taker = ("9", "20000") } in
  let events = List.mapi (fun index (units, price) ->
    L.Fill { time = Int64.of_int index; coin = 0;
      units = Q.wire (Q.integer units); price = Q.wire (micro price); role = L.Maker }) fills in
  match L.replay ~cash:("1000", "1") ~coins:1 [tier] events with
  | Ok receipts -> receipts
  | Error code -> failwith ("exact countermodel construction rejected: " ^ code)

let position (receipt : L.receipt) = List.hd (L.view receipt.state).positions

let check_cases () =
  let fee_fills = [1, 100000; -1, 100000] in
  let cost_fills = [11, 1234; -8, 2000; -3, 2000] in
  let countermodels = List.map (fun defect ->
    defect, run_wrong defect fee_fills, run_wrong defect cost_fills)
    [Printed_fee; Venue_cost] in
  let fee_rows = engine fee_fills and cost_rows = engine cost_fills in
  let bought = List.hd fee_rows in
  check "engine maker fee is exactly 15 millionths"
    (Q.equal (scaled bought.fee) (Q.integer 15));
  let cash_down = Q.sub initial.cash (scaled (L.view bought.state).cash) in
  check "engine buy cash falls by exactly 100015 millionths"
    (Q.equal cash_down (Q.integer 100015));
  let reduced = List.nth cost_rows 1 and closed = List.nth cost_rows 2 in
  check "engine keeps cost exactly 3702 millionths"
    (Q.equal (scaled (position reduced).cost) (Q.integer 3702));
  check "engine keeps entry exactly 1234 price units"
    ((position reduced).entry = Some (Q.wire (micro 1234)));
  check "engine last three realize exactly 2298 millionths"
    (Q.equal (scaled closed.closed_pnl) (Q.integer 2298));
  List.iter (fun (defect, fee_states, cost_states) -> match defect with
    | Printed_fee ->
      let wrong = List.hd fee_states in
      check "printed-fee ledger charges 14 against printed 14"
        (Q.equal wrong.fee (Q.integer 14));
      check "printed-fee ledger's cash falls by 100014, not 100015"
        (Q.equal (Q.sub initial.cash wrong.cash) (Q.integer 100014)
         && not (Q.equal wrong.cash (scaled (L.view bought.state).cash)));
      check "A1's exact fee assertion rejects the printed-fee ledger"
        (not (Q.equal wrong.fee (Q.mul (Q.integer 100000) rate)))
    | Venue_cost ->
      let wrong = List.nth cost_states 1 and last = List.nth cost_states 2 in
      check "venue-cost ledger keeps 3701 against E of 3701"
        (Q.equal wrong.cost (Q.integer 3701));
      check "venue-cost ledger's entry differs from exact open-position entry"
        (Q.equal (entry wrong) (Q.make "3701" "3")
         && not (Q.equal (entry wrong) (Q.integer 1234)));
      check "venue-cost ledger realizes 2299, not 2298 or printed 2301"
        (Q.equal last.pnl (Q.integer 2299)
         && not (Q.equal last.pnl (scaled closed.closed_pnl)));
      check "A1's unrounded proportional-cost assertion rejects venue cost"
        (not (Q.equal wrong.cost (scaled (position reduced).cost)))) countermodels
