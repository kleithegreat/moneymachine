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

let count_l2 planner ~conn =
  List.count (P.subs planner ~conn) ~f:(function Sub.L2_book _ -> true | _ -> false)
;;

let check_invariants planner ~connections ~max ~coins =
  let subs = all_subs planner ~connections in
  assert (List.length subs = P.total planner);
  assert (P.total planner <= max);
  let contexts = List.count subs ~f:(fun (_, s) -> Sub.equal s Sub.All_dexs_asset_ctxs) in
  assert (contexts = 1);
  List.iter coins ~f:(fun coin ->
    let trades = P.conn_of planner (Sub.Trades coin) in
    let l2 = P.conn_of planner (Sub.L2_book coin) in
    assert (Bool.equal (Option.is_some trades) (Option.is_some l2));
    assert (Option.equal Int.equal trades l2));
  let distinct = List.contains_dup subs ~compare:[%compare: int * Sub.t] in
  assert (not distinct)
;;

let add_all planner coins =
  List.rev (List.fold coins ~init:[] ~f:(fun acc coin -> (coin, P.add planner ~coin) :: acc))

let%expect_test "item 5: every non-delisted perp gets trades and l2Book and there is one allDexsAssetCtxs" =
  List.iter [ 1, 1; 3, 7; 5, 70; 8, 44 ] ~f:(fun (dexes, per_dex) ->
    let coins = coin_names ~dexes ~per_dex in
    let planner = P.create ~connections:8 ~max_subscriptions:950 in
    let results = add_all planner coins in
    assert (List.for_all results ~f:(fun (_, r) -> Poly.equal r P.Added));
    check_invariants planner ~connections:8 ~max:950 ~coins;
    List.iter coins ~f:(fun coin ->
      assert (Option.is_some (P.conn_of planner (Sub.Trades coin)));
      assert (Option.is_some (P.conn_of planner (Sub.L2_book coin))));
    assert (Option.is_some (P.conn_of planner Sub.All_dexs_asset_ctxs));
    printf "dexes=%d perps=%d total=%d\n" dexes (List.length coins) (P.total planner));
  [%expect {|
    dexes=1 perps=1 total=3
    dexes=3 perps=21 total=43
    dexes=5 perps=350 total=701
    dexes=8 perps=352 total=705 |}]
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
  assert (Option.is_none (P.conn_of planner (Sub.L2_book "xyz:GONE")));
  assert (P.total planner = 5);
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

let%test_unit "item 5: l2Book subscriptions are spread evenly over the connections" =
  List.iter [ 8, 8; 8, 13; 8, 350; 5, 77; 1, 10 ] ~f:(fun (connections, n) ->
    let coins = coin_names ~dexes:1 ~per_dex:n in
    let planner = P.create ~connections ~max_subscriptions:950 in
    ignore (add_all planner coins : _ list);
    let counts = List.init connections ~f:(fun conn -> count_l2 planner ~conn) in
    let lo = List.fold counts ~init:Int.max_value ~f:Int.min in
    let hi = List.fold counts ~init:0 ~f:Int.max in
    if hi - lo > 1
    then failwithf "connections=%d n=%d: l2Book counts %s" connections n
           (Sexp.to_string [%sexp (counts : int list)]) ())
;;

let%test_unit "item 5: subscriptions never exceed the maximum, past it new listings are refused and nothing is dropped" =
  let max = 950 in
  let coins = coin_names ~dexes:1 ~per_dex:474 in
  let planner = P.create ~connections:8 ~max_subscriptions:max in
  ignore (add_all planner coins : _ list);
  assert (P.total planner = 949);
  let snapshot = all_subs planner ~connections:8 in
  let outcome = P.add planner ~coin:"NEW" in
  assert (Poly.equal outcome P.Refused);
  assert (P.total planner = 949);
  assert (Option.is_none (P.conn_of planner (Sub.Trades "NEW")));
  assert (Option.is_none (P.conn_of planner (Sub.L2_book "NEW")));
  assert (
    List.equal
      [%equal: int * Sub.t]
      (List.sort snapshot ~compare:[%compare: int * Sub.t])
      (List.sort (all_subs planner ~connections:8) ~compare:[%compare: int * Sub.t]));
  let removed = P.remove planner ~coin:"C0" in
  assert (List.length removed = 2);
  assert (Poly.equal (P.add planner ~coin:"NEW") P.Added);
  check_invariants planner ~connections:8 ~max ~coins:("NEW" :: coins)
;;

let%test_unit "item 5: a coin's two subscriptions are both added or both refused (quickcheck)" =
  Base_quickcheck.Test.run_exn
    ~config:{ Base_quickcheck.Test.default_config with test_count = 300 }
    (module struct
      type t = int * int * int [@@deriving sexp_of]

      let quickcheck_generator =
        let open Base_quickcheck.Generator in
        both (int_uniform_inclusive 1 8) (both (int_uniform_inclusive 1 40) (int_uniform_inclusive 0 40))
        |> map ~f:(fun (c, (m, n)) -> c, m, n)
      ;;

      let quickcheck_shrinker = Base_quickcheck.Shrinker.atomic
    end)
    ~f:(fun (connections, max, n) ->
      let planner = P.create ~connections ~max_subscriptions:max in
      let coins = coin_names ~dexes:1 ~per_dex:n in
      List.iter coins ~f:(fun coin ->
        let snapshot = all_subs planner ~connections in
        let outcome = P.add planner ~coin in
        let now = all_subs planner ~connections in
        (match outcome with
         | P.Added ->
           assert (List.length now = List.length snapshot + 2);
           assert (List.for_all snapshot ~f:(List.mem now ~equal:[%equal: int * Sub.t]))
         | P.Refused ->
           assert (List.length now = List.length snapshot);
           assert (List.length snapshot + 2 > max));
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
  [%expect {|
    {"method":"subscribe","subscription":{"type":"allDexsAssetCtxs"}}
    {"method":"subscribe","subscription":{"coin":"BTC","type":"trades"}}
    {"method":"subscribe","subscription":{"coin":"xyz:TSLA","type":"l2Book"}} |}];
  let unsub = Yojson.Safe.from_string (Sub.unsubscribe_message (Sub.Trades "BTC")) in
  print_endline (Yojson.Safe.to_string (Yojson.Safe.Util.member "method" unsub));
  [%expect {| "unsubscribe" |}]
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
  show (Sub.of_ack (ack {|{"type":"allDexsAssetCtxs"}|}));
  show (Sub.of_ack {|{"channel":"pong"}|});
  show (Sub.of_ack {|{"channel":"trades","data":[]}|});
  [%expect {|
    (Trades BTC)
    (L2_book xyz:TSLA)
    All_dexs_asset_ctxs
    none
    none |}]
;;
