(* Item 5: Planning. *)

open Core
module P = Mmrec.Planner
module Sub = Mmrec.Sub

let coin_names ~dexes ~per_dex =
  List.concat_map (List.range 0 dexes) ~f:(fun d ->
    List.init per_dex ~f:(fun i -> if d = 0 then sprintf "C%d" i else sprintf "dex%d:C%d" d i))
;;

let all_subs planner ~connections =
  List.concat_map (List.range 0 connections) ~f:(fun conn ->
    List.map (P.subs planner ~conn) ~f:(fun sub -> conn, sub))
;;

let is_main coin = not (String.mem coin ':')

let kinds planner ~connections = List.init connections ~f:(fun conn -> conn, P.kind planner ~conn)

let conns_of_kind planner ~connections kind =
  List.filter_map (kinds planner ~connections) ~f:(fun (conn, k) -> if P.equal_kind k kind then Some conn else None)
;;

let count planner ~conn ~f = List.count (P.subs planner ~conn) ~f

let is_trades = function Sub.Trades _ -> true | _ -> false
let is_fast_book = function Sub.L2_book_fast _ -> true | _ -> false
let is_deep_book = function Sub.L2_book _ -> true | _ -> false

let check_invariants planner ~connections ~max ~coins =
  let subs = all_subs planner ~connections in
  assert (List.length subs = P.total planner);
  assert (P.total planner <= max);
  let contexts = List.count subs ~f:(fun (_, s) -> Sub.equal s Sub.All_dexs_asset_ctxs) in
  assert (contexts = 1);
  let fast = conns_of_kind planner ~connections P.Fast in
  assert (Option.equal Int.equal (P.conn_of planner Sub.All_dexs_asset_ctxs) (List.hd fast));
  List.iter subs ~f:(fun (conn, sub) ->
    match P.kind planner ~conn, sub with
    | P.Deep, Sub.L2_book _ -> ()
    | P.Fast, (Sub.Trades _ | Sub.L2_book_fast _ | Sub.All_dexs_asset_ctxs) -> ()
    | _ -> failwithf "conn %d (%s) holds %s" conn (Sexp.to_string [%sexp (P.kind planner ~conn : P.kind)]) (Sexp.to_string [%sexp (sub : Sub.t)]) ());
  List.iter coins ~f:(fun coin ->
    let trades = P.conn_of planner (Sub.Trades coin) in
    let fast_book = P.conn_of planner (Sub.L2_book_fast coin) in
    let deep_book = P.conn_of planner (Sub.L2_book coin) in
    assert (Bool.equal (Option.is_some trades) (Option.is_some fast_book));
    assert (Option.equal Int.equal trades fast_book);
    assert (Bool.equal (Option.is_some trades && is_main coin) (Option.is_some deep_book)));
  let distinct = List.contains_dup subs ~compare:[%compare: int * Sub.t] in
  assert (not distinct)
;;

let add_all planner coins =
  List.rev (List.fold coins ~init:[] ~f:(fun acc coin -> (coin, P.add planner ~coin) :: acc))

let%expect_test "item 5: every non-delisted perp gets trades and fast l2Book, main-dex perps also the 20-level book, and there is one allDexsAssetCtxs" =
  List.iter [ 1, 1; 3, 7; 5, 70; 8, 44 ] ~f:(fun (dexes, per_dex) ->
    let coins = coin_names ~dexes ~per_dex in
    let planner = P.create ~connections:8 ~max_subscriptions:950 in
    let results = add_all planner coins in
    assert (List.for_all results ~f:(fun (_, r) -> Poly.equal r P.Added));
    check_invariants planner ~connections:8 ~max:950 ~coins;
    List.iter coins ~f:(fun coin ->
      assert (Option.is_some (P.conn_of planner (Sub.Trades coin)));
      assert (Option.is_some (P.conn_of planner (Sub.L2_book_fast coin)));
      assert (Bool.equal (is_main coin) (Option.is_some (P.conn_of planner (Sub.L2_book coin)))));
    assert (Option.is_some (P.conn_of planner Sub.All_dexs_asset_ctxs));
    printf "dexes=%d perps=%d total=%d\n" dexes (List.length coins) (P.total planner));
  [%expect {|
    dexes=1 perps=1 total=4
    dexes=3 perps=21 total=50
    dexes=5 perps=350 total=771
    dexes=8 perps=352 total=749 |}]
;;

let%expect_test "item 5: a quarter of the connections, rounded up, are deep" =
  List.iter [ 2; 3; 4; 5; 8; 9; 10 ] ~f:(fun connections ->
    let planner = P.create ~connections ~max_subscriptions:950 in
    let deep = conns_of_kind planner ~connections P.Deep in
    let fast = conns_of_kind planner ~connections P.Fast in
    assert (List.length deep + List.length fast = connections);
    printf "connections=%d deep=%d fast=%d\n" connections (List.length deep) (List.length fast));
  [%expect {|
    connections=2 deep=1 fast=1
    connections=3 deep=1 fast=2
    connections=4 deep=1 fast=3
    connections=5 deep=2 fast=3
    connections=8 deep=2 fast=6
    connections=9 deep=3 fast=6
    connections=10 deep=3 fast=7 |}]
;;

let%test_unit "item 5: allDexsAssetCtxs is on a fast connection from the start, before any coin" =
  List.iter [ 2; 4; 8 ] ~f:(fun connections ->
    let planner = P.create ~connections ~max_subscriptions:950 in
    assert (P.total planner = 1);
    let conn = Option.value_exn (P.conn_of planner Sub.All_dexs_asset_ctxs) in
    assert (P.equal_kind (P.kind planner ~conn) P.Fast);
    assert (Option.equal Int.equal (Some conn) (List.hd (conns_of_kind planner ~connections P.Fast))))
;;

let%expect_test "item 5: delisted perps get nothing, from a meta response" =
  let meta = Rec_support.Fake_hl.meta_json ~live:[ "BTC"; "xyz:TSLA" ] ~delisted:[ "OLD"; "xyz:GONE" ] in
  let perps = Mmrec.Listings.perps meta in
  let active = Mmrec.Listings.active perps in
  print_s [%sexp (List.map perps ~f:(fun (p : Mmrec.Listings.perp) -> p.coin, p.delisted) : (string * bool) list)];
  print_s [%sexp (active : string list)];
  let planner = P.create ~connections:8 ~max_subscriptions:950 in
  ignore (add_all planner active : _ list);
  assert (Option.is_none (P.conn_of planner (Sub.Trades "OLD")));
  assert (Option.is_none (P.conn_of planner (Sub.L2_book_fast "xyz:GONE")));
  assert (Option.is_none (P.conn_of planner (Sub.L2_book "OLD")));
  assert (P.total planner = 6);
  [%expect {|
    ((BTC false) (xyz:TSLA false) (OLD true) (xyz:GONE true))
    (BTC xyz:TSLA) |}]
;;

let%expect_test "item 5: perpDexs names, main dex first" =
  print_s
    [%sexp
      (Mmrec.Listings.dex_names (Rec_support.Fake_hl.perp_dexs_json [ "xyz"; "flx" ]) : string list)];
  [%expect {| ("" xyz flx) |}]
;;

let spread counts =
  let lo = List.fold counts ~init:Int.max_value ~f:Int.min in
  let hi = List.fold counts ~init:0 ~f:Int.max in
  hi - lo
;;

let%test_unit "item 5: coins are spread evenly over the fast connections, and the 20-level books over the deep ones" =
  List.iter [ 8, 8; 8, 13; 8, 350; 5, 77; 2, 10 ] ~f:(fun (connections, n) ->
    let coins = coin_names ~dexes:1 ~per_dex:n in
    let planner = P.create ~connections ~max_subscriptions:950 in
    ignore (add_all planner coins : _ list);
    let per kind ~f = List.map (conns_of_kind planner ~connections kind) ~f:(fun conn -> count planner ~conn ~f) in
    let trades = per P.Fast ~f:is_trades in
    let fast_books = per P.Fast ~f:is_fast_book in
    let deep_books = per P.Deep ~f:is_deep_book in
    if spread trades > 1 || spread deep_books > 1 || not ([%equal: int list] trades fast_books)
    then
      failwithf "connections=%d n=%d: trades %s fast books %s deep books %s" connections n
        (Sexp.to_string [%sexp (trades : int list)])
        (Sexp.to_string [%sexp (fast_books : int list)])
        (Sexp.to_string [%sexp (deep_books : int list)]) ())
;;

let%test_unit "item 5: coins on builder dexes spread over the fast connections and get no 20-level book" =
  let coins = coin_names ~dexes:4 ~per_dex:30 in
  let planner = P.create ~connections:8 ~max_subscriptions:950 in
  ignore (add_all planner coins : _ list);
  let fast = conns_of_kind planner ~connections:8 P.Fast in
  let trades = List.map fast ~f:(fun conn -> count planner ~conn ~f:is_trades) in
  assert (spread trades <= 1);
  let deep_books = List.count (all_subs planner ~connections:8) ~f:(fun (_, s) -> is_deep_book s) in
  assert (deep_books = 30)
;;

let%test_unit "item 5: subscriptions never exceed the maximum, past it new listings are refused and nothing is dropped" =
  let max = 950 in
  let coins = coin_names ~dexes:1 ~per_dex:316 in
  let planner = P.create ~connections:8 ~max_subscriptions:max in
  ignore (add_all planner coins : _ list);
  assert (P.total planner = 949);
  let snapshot = all_subs planner ~connections:8 in
  let outcome = P.add planner ~coin:"NEW" in
  assert (Poly.equal outcome P.Refused);
  assert (P.total planner = 949);
  assert (Option.is_none (P.conn_of planner (Sub.Trades "NEW")));
  assert (Option.is_none (P.conn_of planner (Sub.L2_book_fast "NEW")));
  assert (Option.is_none (P.conn_of planner (Sub.L2_book "NEW")));
  assert (
    List.equal
      [%equal: int * Sub.t]
      (List.sort snapshot ~compare:[%compare: int * Sub.t])
      (List.sort (all_subs planner ~connections:8) ~compare:[%compare: int * Sub.t]));
  let removed = P.remove planner ~coin:"C0" in
  assert (List.length removed = 3);
  assert (Poly.equal (P.add planner ~coin:"NEW") P.Added);
  check_invariants planner ~connections:8 ~max ~coins:("NEW" :: coins)
;;

let%test_unit "item 5: a main-dex coin costs three subscriptions and a builder-dex coin two, each all or nothing" =
  let max = 950 in
  let main_coins = coin_names ~dexes:1 ~per_dex:315 in
  let planner = P.create ~connections:8 ~max_subscriptions:max in
  ignore (add_all planner ("x:A" :: main_coins) : _ list);
  assert (P.total planner = 948);
  assert (Poly.equal (P.add planner ~coin:"NEW") P.Refused);
  assert (P.total planner = 948);
  assert (Option.is_none (P.conn_of planner (Sub.Trades "NEW")));
  assert (Poly.equal (P.add planner ~coin:"x:NEW") P.Added);
  assert (P.total planner = 950);
  assert (Poly.equal (P.add planner ~coin:"x:NEWER") P.Refused);
  check_invariants planner ~connections:8 ~max ~coins:("x:A" :: "x:NEW" :: main_coins)
;;

let%test_unit "item 5: a coin's subscriptions are all added or all refused (quickcheck)" =
  Base_quickcheck.Test.run_exn
    ~config:{ Base_quickcheck.Test.default_config with test_count = 300 }
    (module struct
      type t = int * int * int [@@deriving sexp_of]

      let quickcheck_generator =
        let open Base_quickcheck.Generator in
        both (int_uniform_inclusive 2 8) (both (int_uniform_inclusive 1 40) (int_uniform_inclusive 0 40))
        |> map ~f:(fun (c, (m, n)) -> c, m, n)
      ;;

      let quickcheck_shrinker = Base_quickcheck.Shrinker.atomic
    end)
    ~f:(fun (connections, max, n) ->
      let planner = P.create ~connections ~max_subscriptions:max in
      let coins = List.init n ~f:(fun i -> if i % 3 = 2 then sprintf "x:C%d" i else sprintf "C%d" i) in
      List.iter coins ~f:(fun coin ->
        let cost = if is_main coin then 3 else 2 in
        let snapshot = all_subs planner ~connections in
        let outcome = P.add planner ~coin in
        let now = all_subs planner ~connections in
        (match outcome with
         | P.Added ->
           assert (List.length now = List.length snapshot + cost);
           assert (List.for_all snapshot ~f:(List.mem now ~equal:[%equal: int * Sub.t]))
         | P.Refused ->
           assert (List.length now = List.length snapshot);
           assert (List.length snapshot + cost > max));
        ());
      check_invariants planner ~connections ~max
        ~coins:(List.filter coins ~f:(fun c -> Option.is_some (P.conn_of planner (Sub.Trades c)))))
;;

let%expect_test "item 5: subscription messages" =
  let show sub =
    let json = Yojson.Safe.from_string (Sub.subscribe_message sub) in
    let sorted =
      match json with
      | `Assoc fields ->
        `Assoc
          (List.sort fields ~compare:(fun (a, _) (b, _) -> String.compare a b)
           |> List.map ~f:(function
             | "subscription", `Assoc inner ->
               "subscription", `Assoc (List.sort inner ~compare:(fun (a, _) (b, _) -> String.compare a b))
             | other -> other))
      | other -> other
    in
    print_endline (Yojson.Safe.to_string sorted)
  in
  show Sub.All_dexs_asset_ctxs;
  show (Sub.Trades "BTC");
  show (Sub.L2_book "xyz:TSLA");
  show (Sub.L2_book_fast "BTC");
  [%expect {|
    {"method":"subscribe","subscription":{"type":"allDexsAssetCtxs"}}
    {"method":"subscribe","subscription":{"coin":"BTC","type":"trades"}}
    {"method":"subscribe","subscription":{"coin":"xyz:TSLA","type":"l2Book"}}
    {"method":"subscribe","subscription":{"coin":"BTC","fast":true,"type":"l2Book"}} |}];
  let unsub = Yojson.Safe.from_string (Sub.unsubscribe_message (Sub.Trades "BTC")) in
  print_endline (Yojson.Safe.to_string (Yojson.Safe.Util.member "method" unsub));
  [%expect {| "unsubscribe" |}];
  let subscription message =
    Yojson.Safe.Util.member "subscription" (Yojson.Safe.from_string message)
    |> Yojson.Safe.sort
    |> Yojson.Safe.to_string
  in
  List.iter [ Sub.L2_book_fast "BTC"; Sub.L2_book "BTC"; Sub.Trades "BTC" ] ~f:(fun sub ->
    assert (String.equal (subscription (Sub.subscribe_message sub)) (subscription (Sub.unsubscribe_message sub))))
;;

let%expect_test "item 5: an ack names its subscription" =
  let ack sub =
    sprintf
      {|{"channel":"subscriptionResponse","data":{"method":"subscribe","subscription":%s}}|}
      sub
  in
  let show = function
    | None -> print_endline "none"
    | Some sub -> print_s [%sexp (sub : Sub.t)]
  in
  show (Sub.of_ack (ack {|{"type":"trades","coin":"BTC"}|}));
  show (Sub.of_ack (ack {|{"type":"l2Book","coin":"xyz:TSLA"}|}));
  show (Sub.of_ack (ack {|{"type":"l2Book","coin":"BTC","fast":true}|}));
  show (Sub.of_ack (ack {|{"type":"allDexsAssetCtxs"}|}));
  show (Sub.of_ack {|{"channel":"pong"}|});
  show (Sub.of_ack {|{"channel":"trades","data":[]}|});
  [%expect {|
    (Trades BTC)
    (L2_book xyz:TSLA)
    (L2_book_fast BTC)
    All_dexs_asset_ctxs
    none
    none |}]
;;
