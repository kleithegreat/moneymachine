(* Brief 3, step 2 test 4's made-up cases. Runs in @runtest/Nix without
   any vault fills, checking the same venue oracle used by layer1.ml. *)
module L = Mm2_lean.Ledger
module Q = Ledger_oracle.Q
module V = Venue_oracle

let check name condition = if not condition then failwith ("FAIL: " ^ name)
let micro n = Q.make (string_of_int n) "1000000"
let scaled wire = Q.mul (Q.of_wire wire) (Q.integer 1000000)
let expect name wire expected = check name (Q.equal (Q.of_wire wire) expected)
let base : L.tier =
  { from_ms = 0L; name = "base"; maker = ("3", "20000"); taker = ("9", "20000") }

let fill role units price =
  L.Fill { time = 1L; coin = 0; units = Q.wire (Q.integer units);
    price = Q.wire price; role }

let replay events =
  match L.replay ~cash:("1000", "1") ~coins:1 [base] events with
  | Ok receipts -> receipts
  | Error code -> failwith ("ledger rejected: " ^ code)

let position (receipt : L.receipt) = List.hd (L.view receipt.state).positions

let fee_cases () =
  List.iter
    (fun (role, rate, printed, exact) ->
      let receipt = List.hd (replay [fill role 1 (micro 100000)]) in
      check "receipt has base rate" (receipt.rate = Some rate);
      check "double product's printed fee" (V.fee 100000 (Q.of_wire rate) = printed);
      expect "ledger fee stays exact" receipt.fee (micro exact);
      let fee = scaled receipt.fee in
      check "printed fee <= ledger fee <= printed fee + one millionth"
        (Q.le (Q.integer printed) fee && Q.le fee (Q.integer (printed + 1))))
    [L.Maker, base.maker, 14, 15; L.Taker, base.taker, 45, 45];
  check "maker's nonintegral fee is cut" (V.fee 33333 (Q.of_wire base.maker) = 4);
  check "exact floor would miss maker boundary"
    (V.floor_scaled 100000 3 20000 = 15 && V.cut 100000 0.00015 = 14);
  check "taker boundary does not lose one" (V.cut 100000 0.00045 = 45)

let average_case () =
  let rows = replay
    [fill L.Maker 1 (Q.integer 100); fill L.Maker 2 (Q.integer 101);
     fill L.Maker (-3) (Q.integer 102)] in
  let opened = List.nth rows 1 and closed = List.nth rows 2 in
  let entry = V.product 1 (V.whole 6 "100") + V.product 2 (V.whole 6 "101") in
  check "entry notional equals ledger cost before any partial close"
    (Q.equal (Q.integer entry) (scaled (position opened).cost));
  let printed, kept = V.close entry 3 3 (V.whole 6 "102") in
  check "integer entry quotient prints 4000002" (printed = 4000002 && kept = 0);
  expect "ledger closedPnl is four, never rounded" closed.closed_pnl (Q.integer 4);
  check "printed close is above ledger close" (Q.le (scaled closed.closed_pnl) (Q.integer printed));
  expect "flat ledger cost" (position closed).cost Q.zero

let partial_case () =
  let rows = replay
    [fill L.Maker 11 (micro 1234); fill L.Maker (-8) (micro 2000);
     fill L.Maker (-3) (micro 2000)] in
  let opened = List.nth rows 0 and reduced = List.nth rows 1 and flat = List.nth rows 2 in
  let entry = V.product 11 1234 in
  check "eleven lots' entry is 13574" (entry = 13574);
  check "clean entry equals ledger cost" (Q.equal (Q.integer entry) (scaled (position opened).cost));
  let printed, kept = V.close entry 11 8 2000 in
  check "first close prints 6128 and keeps 3701" (printed = 6128 && kept = 3701);
  expect "first exact closedPnl" reduced.closed_pnl (micro 6128);
  check "whole-number scaling would incorrectly keep 3702" (V.floor_scaled entry 3 11 = 3702);
  expect "ledger keeps exact cost 3702" (position reduced).cost (micro 3702);
  let cost = scaled (position reduced).cost in
  check "one partial close: cost - 1 <= E <= cost"
    (Q.le (Q.sub cost Q.one) (Q.integer kept) && Q.le (Q.integer kept) cost);
  check "venue entry is 1233" (kept / 3 = 1233);
  let last, remaining = V.close kept 3 3 2000 in
  check "last three print 2301 and clear E" (last = 2301 && remaining = 0);
  expect "last exact closedPnl is 2298" flat.closed_pnl (micro 2298);
  check "last printed close is above ledger close" (Q.le (scaled flat.closed_pnl) (Q.integer last));
  expect "flat exact cost" (position flat).cost Q.zero

let () =
  fee_cases ();
  average_case ();
  partial_case ();
  Printf.printf "ledger: step 2 test 4 made-up venue arithmetic cases passed\n%!"
