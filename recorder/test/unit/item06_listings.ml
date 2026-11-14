(* Item 6: Listings (the live end-to-end case is test/e2e/item06_listings_e2e.ml). *)

open Core
module P = Mmrec.Planner
module Sub = Mmrec.Sub
module U = Mmrec.Listing_update

let planner_with coins =
  let planner = P.create ~connections:4 ~max_subscriptions:950 in
  List.iter coins ~f:(fun coin -> ignore (P.add planner ~coin : P.outcome));
  planner
;;

let subscribes actions =
  List.filter_map actions ~f:(function
    | U.Subscribe { conn; sub } -> Some (conn, sub)
    | _ -> None)
;;

let unsubscribes actions =
  List.filter_map actions ~f:(function
    | U.Unsubscribe { conn; sub } -> Some (conn, sub)
    | _ -> None)
;;

let events actions =
  List.filter_map actions ~f:(function
    | U.Record event -> Some event
    | _ -> None)
;;

let coin_of event =
  match Mmrec.Event.field event "coin" with
  | Some (`String coin) -> Some coin
  | _ -> None
;;

let%test_unit "item 6: a coin added between two hourly reads is subscribed, and it is an event" =
  let planner = planner_with [ "A"; "B" ] in
  let actions = U.apply planner ~before:[ "A"; "B" ] ~after:[ "A"; "B"; "C" ] in
  let subs = subscribes actions in
  assert (List.length subs = 3);
  let trades = List.find_exn subs ~f:(fun (_, s) -> Sub.equal s (Sub.Trades "C")) in
  let fast_book = List.find_exn subs ~f:(fun (_, s) -> Sub.equal s (Sub.L2_book_fast "C")) in
  let deep_book = List.find_exn subs ~f:(fun (_, s) -> Sub.equal s (Sub.L2_book "C")) in
  assert (fst trades = fst fast_book);
  assert (P.equal_kind (P.kind planner ~conn:(fst trades)) P.Fast);
  assert (P.equal_kind (P.kind planner ~conn:(fst deep_book)) P.Deep);
  assert (List.is_empty (unsubscribes actions));
  let evs = events actions in
  assert (List.length evs = 1);
  let event = List.hd_exn evs in
  assert (String.equal (Mmrec.Event.name event) "listing");
  assert (Option.equal String.equal (coin_of event) (Some "C"));
  assert (Option.equal Int.equal (P.conn_of planner (Sub.Trades "C")) (Some (fst trades)))
;;

let%test_unit "item 6: a coin delisted between two hourly reads is unsubscribed, and it is an event" =
  let planner = planner_with [ "A"; "B" ] in
  let held_on = P.conn_of planner (Sub.Trades "B") |> Option.value_exn in
  let actions = U.apply planner ~before:[ "A"; "B" ] ~after:[ "A" ] in
  let unsubs = unsubscribes actions in
  assert (List.length unsubs = 3);
  assert (List.count unsubs ~f:(fun (conn, _) -> conn = held_on) = 2);
  assert (List.exists unsubs ~f:(fun (_, s) -> Sub.equal s (Sub.Trades "B")));
  assert (List.exists unsubs ~f:(fun (_, s) -> Sub.equal s (Sub.L2_book_fast "B")));
  assert (List.exists unsubs ~f:(fun (_, s) -> Sub.equal s (Sub.L2_book "B")));
  assert (List.is_empty (subscribes actions));
  let evs = events actions in
  assert (List.length evs = 1);
  assert (String.equal (Mmrec.Event.name (List.hd_exn evs)) "listing");
  assert (Option.equal String.equal (coin_of (List.hd_exn evs)) (Some "B"));
  assert (Option.is_none (P.conn_of planner (Sub.Trades "B")));
  assert (Option.is_some (P.conn_of planner (Sub.Trades "A")))
;;

let%test_unit "item 6: a coin flagged delisted in meta is a removal" =
  let before_meta = Rec_support.Fake_hl.meta_json ~live:[ "A"; "B" ] ~delisted:[] in
  let after_meta = Rec_support.Fake_hl.meta_json ~live:[ "A" ] ~delisted:[ "B" ] in
  let active meta = Mmrec.Listings.active (Mmrec.Listings.perps meta) in
  let planner = planner_with (active before_meta) in
  let actions = U.apply planner ~before:(active before_meta) ~after:(active after_meta) in
  assert (List.length (unsubscribes actions) = 3)
;;

let%test_unit "item 6: an add and a delist in the same read give both" =
  let planner = planner_with [ "A"; "B" ] in
  let actions = U.apply planner ~before:[ "A"; "B" ] ~after:[ "A"; "C" ] in
  assert (List.length (subscribes actions) = 3);
  assert (List.length (unsubscribes actions) = 3);
  let coins = List.filter_map (events actions) ~f:coin_of |> List.sort ~compare:String.compare in
  assert (List.equal String.equal coins [ "B"; "C" ])
;;

let%test_unit "item 6: no change gives no action" =
  let planner = planner_with [ "A"; "B" ] in
  assert (List.is_empty (U.apply planner ~before:[ "A"; "B" ] ~after:[ "B"; "A" ]))
;;

let%test_unit "item 6: past the maximum a new listing is refused and nothing existing is dropped" =
  let planner = P.create ~connections:2 ~max_subscriptions:7 in
  List.iter [ "A"; "B" ] ~f:(fun coin -> ignore (P.add planner ~coin : P.outcome));
  assert (P.total planner = 7);
  let actions = U.apply planner ~before:[ "A"; "B" ] ~after:[ "A"; "B"; "C" ] in
  assert (List.is_empty (subscribes actions));
  assert (List.is_empty (unsubscribes actions));
  let evs = events actions in
  assert (List.length evs = 1);
  let event = List.hd_exn evs in
  assert (String.equal (Mmrec.Event.name event) "refused");
  assert (Option.equal String.equal (coin_of event) (Some "C"));
  assert (P.total planner = 7);
  List.iter [ "A"; "B" ] ~f:(fun coin ->
    assert (Option.is_some (P.conn_of planner (Sub.Trades coin)));
    assert (Option.is_some (P.conn_of planner (Sub.L2_book_fast coin)));
    assert (Option.is_some (P.conn_of planner (Sub.L2_book coin))))
;;

let str_field event key =
  match Mmrec.Event.field event key with
  | Some (`String v) -> Some v
  | _ -> None
;;

let%test_unit "item 6: an added coin's event has coin, dex and change" =
  let planner = planner_with [ "A" ] in
  let actions = U.apply planner ~before:[ "A" ] ~after:[ "A"; "xyz:TSLA" ] in
  let event = List.hd_exn (events actions) in
  assert (Option.equal String.equal (str_field event "coin") (Some "xyz:TSLA"));
  assert (Option.equal String.equal (str_field event "dex") (Some "xyz"));
  assert (Option.equal String.equal (str_field event "change") (Some "added"));
  let actions = U.apply planner ~before:[ "A"; "xyz:TSLA" ] ~after:[ "xyz:TSLA" ] in
  let event = List.hd_exn (events actions) in
  assert (Option.equal String.equal (str_field event "coin") (Some "A"));
  assert (Option.equal String.equal (str_field event "dex") (Some ""));
  assert (Option.equal String.equal (str_field event "change") (Some "delisted"))
;;

let%test_unit "item 6: the first read subscribes everything and is one listing event, not one per coin" =
  let planner = P.create ~connections:3 ~max_subscriptions:950 in
  let actions = U.first_read planner [ "A"; "B"; "xyz:C"; "xyz:D"; "xyz:E" ] in
  assert (List.length (subscribes actions) = 12);
  let evs = events actions in
  assert (List.length evs = 1);
  let event = List.hd_exn evs in
  assert (String.equal (Mmrec.Event.name event) "listing");
  assert (Option.is_none (coin_of event));
  assert (P.total planner = 13)
;;

let%test_unit "item 6: a coin added on a builder dex gets trades and the fast book only" =
  let planner = planner_with [ "A" ] in
  let actions = U.apply planner ~before:[ "A" ] ~after:[ "A"; "xyz:TSLA" ] in
  let subs = List.map (subscribes actions) ~f:snd in
  assert (List.length subs = 2);
  assert (List.mem subs (Sub.Trades "xyz:TSLA") ~equal:Sub.equal);
  assert (List.mem subs (Sub.L2_book_fast "xyz:TSLA") ~equal:Sub.equal);
  assert (Option.is_none (P.conn_of planner (Sub.L2_book "xyz:TSLA")))
;;
