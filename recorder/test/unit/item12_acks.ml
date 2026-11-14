(* Item 12: Acknowledgements (the end-to-end case is test/e2e/item12_unacked_e2e.ml). *)

open Core
module T = Mmrec.Ack_tracker
module Sub = Mmrec.Sub

let show subs = print_s [%sexp (subs : Sub.t list)]

let%expect_test "item 12: a subscription not acknowledged is reported once, 30 s after it was sent" =
  let t = T.create () in
  T.sent t ~now_ms:1_000 (Sub.Trades "BTC");
  T.sent t ~now_ms:2_000 (Sub.L2_book "BTC");
  show (T.expired t ~now_ms:30_999);
  show (T.expired t ~now_ms:31_000);
  show (T.expired t ~now_ms:32_000);
  show (T.expired t ~now_ms:100_000);
  [%expect {|
    ()
    ((Trades BTC))
    ((L2_book BTC))
    () |}]
;;

let%expect_test "item 12: an acknowledged subscription is never reported" =
  let t = T.create () in
  T.sent t ~now_ms:0 Sub.All_dexs_asset_ctxs;
  T.sent t ~now_ms:0 (Sub.Trades "BTC");
  T.acked t Sub.All_dexs_asset_ctxs;
  show (T.expired t ~now_ms:60_000);
  [%expect {| ((Trades BTC)) |}]
;;

let%expect_test "item 12: an acknowledgement after the report changes nothing" =
  let t = T.create () in
  T.sent t ~now_ms:0 (Sub.Trades "ETH");
  show (T.expired t ~now_ms:30_000);
  T.acked t (Sub.Trades "ETH");
  show (T.expired t ~now_ms:90_000);
  [%expect {|
    ((Trades ETH))
    () |}]
;;

let%test_unit "item 12: nothing is reported before 30 s, everything unacknowledged after (quickcheck)" =
  Base_quickcheck.Test.run_exn
    ~config:{ Base_quickcheck.Test.default_config with test_count = 200 }
    (module struct
      type t = (int * bool) list [@@deriving sexp_of]

      let quickcheck_generator =
        Base_quickcheck.Generator.(list (both (int_uniform_inclusive 0 100_000) bool))
      ;;

      let quickcheck_shrinker = Base_quickcheck.Shrinker.atomic
    end)
    ~f:(fun sends ->
      let t = T.create () in
      let subs = List.mapi sends ~f:(fun i (at, acked) -> Sub.Trades (Int.to_string i), at, acked) in
      List.iter subs ~f:(fun (sub, at, _) -> T.sent t ~now_ms:at sub);
      List.iter subs ~f:(fun (sub, _, acked) -> if acked then T.acked t sub);
      let early = T.expired t ~now_ms:29_999 in
      assert (List.for_all early ~f:(fun sub -> List.exists subs ~f:(fun (s, at, _) -> Sub.equal s sub && at + 30_000 <= 29_999)));
      let late = T.expired t ~now_ms:200_000 in
      let reported = List.map (early @ late) ~f:Fn.id in
      let expected = List.filter_map subs ~f:(fun (s, _, acked) -> if acked then None else Some s) in
      assert (
        List.equal Sub.equal
          (List.sort reported ~compare:Sub.compare)
          (List.sort expected ~compare:Sub.compare)))
;;
