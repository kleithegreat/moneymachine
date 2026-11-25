(* Assumed implementation interface; these are contracts, not test doubles.
   Engine.Ledger (Lean): Role.maker/taker; Position {units cost : Rat};
   Tier {start : Int, name : String, maker taker : Rat};
   Event.fill(time : Int, coin : Nat, units price : Rat, role : Role),
   Event.funding(time hour : Int, coin : Nat, oracle rate : Rat), Event.absorb;
   State {cash : Rat, positions : List Position, realized fees funding absorbed
   : Rat, bankrupt : Bool}; Receipt {state : State, fee closedPnl : Rat,
   tier : Option String, rate : Option Rat}.
   initial : Rat -> Nat -> State; position : State -> Nat -> Position;
   entry : State -> Nat -> Option Rat; equity, unrealized : State -> List Rat -> Rat;
   step : List Tier -> State -> Event -> Except String Receipt;
   replay : Rat -> Nat -> List Tier -> List Event -> Except String (List Receipt).
   checkFunding : Int -> Int -> Int -> List (Nat * Int) -> List Event -> Except String Unit
   is the due-hour check (horizon start/end, lateness, held coin/hour pairs,
   events) characterized by U1; step 7 will call it from the full machine.

   OCaml module Mm2_lean.Ledger, using Exact.rat = string * string:
   type rat = Mm2_lean.Exact.rat
   type role = Maker | Taker
   type tier = { from_ms : int64; name : string; maker : rat; taker : rat }
   type event = Fill of { time : int64; coin : int; units : rat; price : rat; role : role }
              | Funding of { time : int64; hour : int64; coin : int; oracle : rat; rate : rat }
              | Absorb
   type t
   type position = { units : rat; cost : rat; entry : rat option }
   type snapshot = { cash : rat; positions : position list; realized : rat;
     fees : rat; funding : rat; absorbed : rat; bankrupt : bool }
   type receipt = { state : t; fee : rat; closed_pnl : rat;
     tier : string option; rate : rat option }
   val initial : rat -> int -> t
   val view : t -> snapshot
   val equity : t -> rat list -> rat
   val unrealized : t -> rat list -> rat
   val step : tier list -> t -> event -> (receipt, string) result
   val replay : cash:rat -> coins:int -> tier list -> event list -> (receipt list, string) result
   All numeric entry points call the running Lean ledger through the C stub.
   replay returns one receipt per supplied event, including funding/absorption;
   it validates the ENTIRE schedule, even unused future tiers or an empty replay.
   Invalid rates return E_FEE_SCHEDULE. Flat entry is None; realized excludes fees.
   Absorb is the post-liquidation floor on a flat, nonpositive-cash account.

   Brief 3, step 2 tests (verbatim):
   1. One lot at 100 and two at 101, closed at 102, change cash by exactly 4 and never round; `entry` is `302/3`; a partial close leaves `entry` as it was; two opposite positions' funding sums to zero.
   2. Conservation (law A1) at every event of random sequences of fills, funding and one bankruptcy, as an equality of rationals with `absorbed` in it (GPT's finding 13).
   3. Every fee is its notional times its role's rate in the tier in force at its time, across a change of tier. A schedule that holds a rate below 0 or above 1 is refused, here by the replay and from step 3 by `start`; rates of 0 and of 1 are admitted (GPT, rounds 5 and 6).
   4. Layer 1: see layer1.ml, a local executable, deliberately NOT @runtest;
      venue_test.ml runs the made-up whole-number arithmetic cases in @runtest.
   5. The replay is admitted like a run: a fill dated in an unreleased protected window rejects it, and its result is written through the same two ledger rows (from step 9; until then the test is marked as waiting on it).
   The existing kernel2/tests/flake-lock.sh checks the unchanged flake.lock.
*)

module L = Mm2_lean.Ledger
module O = Ledger_oracle
module Q = O.Q

let check name condition = if not condition then failwith ("FAIL: " ^ name)

let expect_q name actual expected =
  if actual <> Q.wire expected
  then
    failwith
      (Printf.sprintf
         "FAIL: %s: got %s/%s, expected %s"
         name
         (fst actual)
         (snd actual)
         (Q.text expected))
;;

let ok = function
  | Ok value -> value
  | Error code -> failwith ("ledger rejected: " ^ code)
;;

let q = Q.integer

let base : L.tier =
  { from_ms = 0L; name = "base"; maker = "3", "20000"; taker = "9", "20000" }
;;

let free : L.tier = { base with name = "free"; maker = "0", "1"; taker = "0", "1" }

let fill ?(role = L.Maker) time coin units price =
  L.Fill { time; coin; units = Q.wire units; price = Q.wire price; role }
;;

let funding time coin oracle rate =
  L.Funding { time; hour = 0L; coin; oracle = Q.wire oracle; rate = Q.wire rate }
;;

let replay schedule events = ok (L.replay ~cash:("1000", "1") ~coins:2 schedule events)
let at receipt coin = List.nth (L.view receipt.L.state).positions coin

let test_1 () =
  let first = fill 1L 0 (q 1) (q 100) in
  let second = fill 2L 0 (q 2) (q 101) in
  let rows = replay [ free ] [ first; second; fill 3L 0 (q (-3)) (q 102) ] in
  let opened = List.nth rows 1
  and closed = List.nth rows 2 in
  check "entry is 302/3" ((at opened 0).entry = Some ("302", "3"));
  expect_q "signed open cost" (at opened 0).cost (q 302);
  expect_q "cash changes by exactly four" (L.view closed.state).cash (q 1004);
  expect_q "realized four" closed.closed_pnl (q 4);
  check "flat entry undefined" ((at closed 0).entry = None);
  expect_q "flat cost zero" (at closed 0).cost Q.zero;
  let partial =
    replay
      [ free ]
      [ first; second; fill 3L 0 (q (-1)) (q 102); fill 4L 0 (q (-2)) (q 102) ]
  in
  let reduced = List.nth partial 2 in
  check "partial close preserves entry" ((at reduced 0).entry = Some ("302", "3"));
  expect_q "partial close never rounds cost" (at reduced 0).cost (Q.make "604" "3");
  expect_q "partial close never rounds pnl" reduced.closed_pnl (Q.make "4" "3");
  expect_q
    "partial then final equals one close"
    (L.view (List.nth partial 3).state).realized
    (q 4);
  let rows =
    replay
      [ free ]
      [ fill 1L 0 (q 3) (q 100)
      ; fill 1L 1 (q (-3)) (q 100)
      ; funding 2L 0 (q 101) (Q.make "7" "10000")
      ; funding 2L 1 (q 101) (Q.make "7" "10000")
      ]
  in
  let paid = L.view (List.nth rows 2).state in
  let neutral = L.view (List.nth rows 3).state in
  expect_q "long pays exact oracle funding" paid.funding (Q.make "2121" "10000");
  expect_q "opposite funding sums to zero" neutral.funding Q.zero;
  expect_q "opposite funding cash is unchanged" neutral.cash (q 1000)
;;

let active schedule time =
  List.fold_left
    (fun found (tier : L.tier) -> if tier.from_ms <= time then tier else found)
    (List.hd schedule)
    schedule
;;

let test_2 () =
  let random = Random.State.make [| 0xa1; 0x01; 0x2026 |] in
  let later : L.tier =
    { from_ms = 60L; name = "later"; maker = "1", "10000"; taker = "1", "2500" }
  in
  let schedule = [ base; later ] in
  for sequence = 1 to 128 do
    let starting = q 1000 in
    let state = ref (L.initial (Q.wire starting) 3) in
    let positions = Array.make 3 O.flat in
    let cash = ref starting
    and buys = ref Q.zero
    and sells = ref Q.zero in
    let fees = ref Q.zero
    and paid = ref Q.zero
    and realized = ref Q.zero in
    let absorbed = ref Q.zero
    and events = ref []
    and receipts = ref [] in
    let apply event =
      let receipt = ok (L.step schedule !state event) in
      let expected_fee = ref Q.zero
      and expected_pnl = ref Q.zero in
      let expected_tier = ref None
      and expected_rate = ref None in
      (match event with
       | L.Fill f ->
         let units = Q.of_wire f.units
         and price = Q.of_wire f.price in
         let tier = active schedule f.time in
         let rate = if f.role = L.Maker then tier.maker else tier.taker in
         let notional = Q.mul (Q.abs units) price in
         let fee = Q.mul notional (Q.of_wire rate) in
         let position, pnl = O.fill positions.(f.coin) units price in
         positions.(f.coin) <- position;
         cash := Q.sub (Q.sub !cash (Q.mul units price)) fee;
         if Q.lt Q.zero units
         then buys := Q.add !buys notional
         else sells := Q.add !sells notional;
         fees := Q.add !fees fee;
         realized := Q.add !realized pnl;
         expected_fee := fee;
         expected_pnl := pnl;
         expected_tier := Some tier.name;
         expected_rate := Some rate
       | L.Funding f ->
         let payment =
           Q.mul positions.(f.coin).units (Q.mul (Q.of_wire f.oracle) (Q.of_wire f.rate))
         in
         cash := Q.sub !cash payment;
         paid := Q.add !paid payment
       | L.Absorb ->
         absorbed := Q.neg !cash;
         cash := Q.zero);
      let view = L.view receipt.state in
      let context =
        Printf.sprintf "sequence %d event %d" sequence (List.length !events)
      in
      expect_q (context ^ " cash") view.cash !cash;
      expect_q
        (context ^ " A1 conservation including absorbed")
        view.cash
        (Q.add
           (Q.sub (Q.sub (Q.add (Q.sub starting !buys) !sells) !fees) !paid)
           !absorbed);
      expect_q (context ^ " fees total") view.fees !fees;
      expect_q (context ^ " funding total") view.funding !paid;
      expect_q (context ^ " absorption total") view.absorbed !absorbed;
      expect_q (context ^ " realized total") view.realized !realized;
      expect_q (context ^ " fill fee") receipt.fee !expected_fee;
      expect_q (context ^ " closed pnl") receipt.closed_pnl !expected_pnl;
      check (context ^ " tier") (receipt.tier = !expected_tier);
      check (context ^ " rate") (receipt.rate = !expected_rate);
      check
        (context ^ " bankruptcy exactly at absorption")
        (view.bankrupt = (event = L.Absorb));
      check (context ^ " position count") (List.length view.positions = 3);
      List.iteri
        (fun coin (actual : L.position) ->
           let expected = positions.(coin) in
           expect_q (context ^ " units") actual.units expected.units;
           expect_q (context ^ " cost") actual.cost expected.cost;
           check (context ^ " entry") (actual.entry = Option.map Q.wire (O.entry expected)))
        view.positions;
      let marks = [ q 97; Q.make "203" "2"; Q.make "1" "10" ] in
      let value =
        Q.sum (List.mapi (fun coin mark -> Q.mul positions.(coin).units mark) marks)
      in
      let cost =
        Q.sum (Array.to_list (Array.map (fun (p : O.position) -> p.cost) positions))
      in
      expect_q
        (context ^ " equity")
        (L.equity receipt.state (List.map Q.wire marks))
        (Q.add !cash value);
      expect_q
        (context ^ " unrealized")
        (L.unrealized receipt.state (List.map Q.wire marks))
        (Q.sub value cost);
      state := receipt.state;
      events := event :: !events;
      receipts := view :: !receipts
    in
    for index = 1 to 120 do
      let coin = Random.State.int random 3 in
      let time = Int64.of_int index in
      if index mod 4 = 0
      then
        apply
          (funding
             time
             coin
             (Q.make (string_of_int (950 + Random.State.int random 101)) "10")
             (Q.make (string_of_int (Random.State.int random 21 - 10)) "10000"))
      else (
        let size = Random.State.int random 7 + 1 in
        let signed = if Random.State.bool random then size else -size in
        let price = Q.make (string_of_int (900 + Random.State.int random 201)) "10" in
        let role = if Random.State.bool random then L.Maker else L.Taker in
        apply (fill ~role time coin (q signed) price))
    done;
    for coin = 0 to 2 do
      if not (Q.equal positions.(coin).units Q.zero)
      then apply (fill ~role:L.Taker 121L coin (Q.neg positions.(coin).units) (q 100))
    done;
    apply (fill 122L 0 (q 1) (q 100));
    let charge = Q.add (Q.abs !cash) (q 10000) in
    apply (funding 123L 0 Q.one charge);
    apply (fill ~role:L.Taker 124L 0 (q (-1)) (q 1));
    check "bankruptcy has a strictly positive shortfall" (Q.lt !cash Q.zero);
    apply L.Absorb;
    check "one actual absorption, not a vacuous random branch" (Q.lt Q.zero !absorbed);
    let replayed =
      ok (L.replay ~cash:(Q.wire starting) ~coins:3 schedule (List.rev !events))
    in
    check
      "replay is the same ledger transition fold"
      (List.map (fun (r : L.receipt) -> L.view r.state) replayed = List.rev !receipts)
  done
;;

let test_3 () =
  let next : L.tier =
    { from_ms = 10L; name = "discount"; maker = "1", "10000"; taker = "7", "20000" }
  in
  let events =
    [ fill 9L 0 (Q.make "3" "10") (Q.make "100001" "1000")
    ; fill ~role:L.Taker 9L 1 (q (-2)) (q 101)
    ; fill 10L 0 (q (-1)) (Q.make "1" "3")
    ; fill ~role:L.Taker 11L 1 (q 1) (q 99)
    ]
  in
  let rows = replay [ base; next ] events in
  List.iter2
    (fun event (receipt : L.receipt) ->
       match event with
       | L.Fill f ->
         let tier = if f.time < 10L then base else next in
         let rate = if f.role = L.Maker then tier.maker else tier.taker in
         expect_q
           "fee = exact notional times active role rate"
           receipt.fee
           (Q.mul
              (Q.mul (Q.abs (Q.of_wire f.units)) (Q.of_wire f.price))
              (Q.of_wire rate));
         check "dated tier in receipt" (receipt.tier = Some tier.name);
         check "role rate in receipt" (receipt.rate = Some rate)
       | L.Funding _ | L.Absorb -> assert false)
    events
    rows;
  List.iter
    (fun bad_rate ->
       List.iter
         (fun maker ->
            let bad =
              if maker
              then { next with maker = bad_rate }
              else { next with taker = bad_rate }
            in
            List.iter
              (fun input ->
                 check
                   "replay refuses an invalid rate, even an unused tier"
                   (L.replay ~cash:("1000", "1") ~coins:2 [ base; bad ] input
                    = Error "E_FEE_SCHEDULE"))
              [ []; [ List.hd events ]; events ])
         [ true; false ])
    [ "-1", "1000000000000"; "1000000000001", "1000000000000"; "-1", "1"; "2", "1" ];
  List.iter
    (fun rate ->
       let endpoint = { base with maker = rate; taker = rate } in
       let rows =
         replay
           [ endpoint ]
           [ fill 1L 0 (q 1) (q 10); fill ~role:L.Taker 2L 0 (q (-1)) (q 10) ]
       in
       List.iter
         (fun (r : L.receipt) ->
            expect_q "endpoint fee admitted" r.fee (Q.mul (q 10) (Q.of_wire rate)))
         rows)
    [ "0", "1"; "1", "1" ]
;;

let test_5 () =
  Printf.printf
    "SKIP: step 2 test 5 waits on step 9: replay protected-date admission and the shared \
     attempt/result SQLite rows are not built yet.\n\
     %!"
;;

let () =
  List.iter
    (fun (number, test) ->
       test ();
       Printf.printf "ledger: step 2 test %d passed\n%!" number)
    [ 1, test_1; 2, test_2; 3, test_3 ];
  test_5 ()
;;
