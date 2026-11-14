(* Item 9: Sent-message limits (the end-to-end case is test/e2e/item07_item09_churn_e2e.ml). *)

open Core
module R = Mmrec.Rate_limit

let max_in_window times ~window_ms =
  let arr = Array.of_list (List.sort times ~compare:Int.compare) in
  let best = ref 0 in
  Array.iteri arr ~f:(fun i start ->
    let count = ref 0 in
    let j = ref i in
    while !j < Array.length arr && arr.(!j) < start + window_ms do
      incr count;
      incr j
    done;
    best := Int.max !best !count);
  !best
;;

let%test_unit "item 9: messages sent across connections stay at or below 2000 a minute under reconnect storms" =
  let limiter = R.create ~limit:2000 ~window_ms:60_000 in
  let sent = ref [] in
  let now = ref 0 in
  for storm = 1 to 400 do
    now := !now + 100 + (storm * 37 % 900);
    let at = R.reserve limiter ~now_ms:!now ~n:88 in
    sent := List.init 88 ~f:(fun _ -> at) @ !sent
  done;
  assert (max_in_window !sent ~window_ms:60_000 <= 2000);
  assert (List.length !sent = 400 * 88)
;;

let%test_unit "item 9: the bound holds at any rate of listing changes and reconnects (quickcheck)" =
  Base_quickcheck.Test.run_exn
    ~config:{ Base_quickcheck.Test.default_config with test_count = 300 }
    (module struct
      type t = (int * int) list [@@deriving sexp_of]

      let quickcheck_generator =
        let open Base_quickcheck.Generator in
        list (both (int_uniform_inclusive 0 5_000) (int_uniform_inclusive 1 400))
      ;;

      let quickcheck_shrinker = Base_quickcheck.Shrinker.atomic
    end)
    ~f:(fun requests ->
      let limiter = R.create ~limit:2000 ~window_ms:60_000 in
      let now = ref 0 in
      let sent = ref [] in
      List.iter requests ~f:(fun (gap, n) ->
        now := !now + gap;
        let at = R.reserve limiter ~now_ms:!now ~n in
        assert (at >= !now);
        sent := List.init n ~f:(fun _ -> at) @ !sent);
      assert (max_in_window !sent ~window_ms:60_000 <= 2000))
;;

let%expect_test "item 9: a connection subscribes at most 10 a second" =
  let limiter = R.create ~limit:10 ~window_ms:1000 in
  let times = Rec_support.Harness.in_order 25 ~f:(fun _ -> R.reserve limiter ~now_ms:0 ~n:1) in
  let counts = List.map [ 0; 1000; 2000 ] ~f:(fun t -> List.count times ~f:(Int.equal t)) in
  print_s [%sexp (counts : int list)];
  [%expect {| (10 10 5) |}]
;;
