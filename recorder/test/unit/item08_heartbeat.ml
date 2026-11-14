(* Item 8: Heartbeat (the end-to-end case is test/e2e/item08_heartbeat_e2e.ml). *)

open Core
module H = Mmrec.Conn_health

let actions_to_string actions =
  List.map actions ~f:(function H.Send_ping -> "ping" | H.Reopen -> "reopen")
  |> String.concat ~sep:","
;;

let%expect_test "item 8: after 30 s with nothing received a ping is sent, after 45 s the connection is reopened" =
  let h = H.create ~now_ms:1_000 in
  let at t = print_endline (sprintf "%d: [%s]" t (actions_to_string (H.poll h ~now_ms:(1_000 + t)))) in
  at 0;
  at 29_999;
  at 30_000;
  at 31_000;
  at 44_999;
  at 45_000;
  [%expect {|
    0: []
    29999: []
    30000: [ping]
    31000: []
    44999: []
    45000: [reopen] |}]
;;

let%expect_test "item 8: anything received starts a new idle spell" =
  let h = H.create ~now_ms:0 in
  assert (List.equal Poly.equal (H.poll h ~now_ms:30_000) [ H.Send_ping ]);
  H.received h ~now_ms:40_000;
  let at t = print_endline (sprintf "%d: [%s]" t (actions_to_string (H.poll h ~now_ms:t))) in
  at 69_999;
  at 70_000;
  at 84_999;
  at 85_000;
  [%expect {|
    69999: []
    70000: [ping]
    84999: []
    85000: [reopen] |}]
;;

let%test_unit "item 8: a long gap between polls still reopens" =
  let h = H.create ~now_ms:0 in
  let actions = H.poll h ~now_ms:50_000 in
  assert (List.mem actions H.Reopen ~equal:Poly.equal)
;;

let%test_unit "item 8: a busy connection is neither pinged nor reopened (quickcheck)" =
  Base_quickcheck.Test.run_exn
    ~config:{ Base_quickcheck.Test.default_config with test_count = 200 }
    (module struct
      type t = int list [@@deriving sexp_of]

      let quickcheck_generator =
        Base_quickcheck.Generator.(list (int_uniform_inclusive 1 29_000))
      ;;

      let quickcheck_shrinker = Base_quickcheck.Shrinker.atomic
    end)
    ~f:(fun gaps ->
      let h = H.create ~now_ms:0 in
      let now = ref 0 in
      List.iter gaps ~f:(fun gap ->
        now := !now + gap;
        assert (List.is_empty (H.poll h ~now_ms:!now));
        H.received h ~now_ms:!now))
;;

let%test_unit "item 8: reopening is reported once the idle time reaches 45 s and never before (quickcheck)" =
  Base_quickcheck.Test.run_exn
    ~config:{ Base_quickcheck.Test.default_config with test_count = 200 }
    (module struct
      type t = int list [@@deriving sexp_of]

      let quickcheck_generator =
        Base_quickcheck.Generator.(list (int_uniform_inclusive 1 20_000))
      ;;

      let quickcheck_shrinker = Base_quickcheck.Shrinker.atomic
    end)
    ~f:(fun gaps ->
      let h = H.create ~now_ms:0 in
      let last_received = ref 0 in
      let now = ref 0 in
      let reopened = ref false in
      List.iter gaps ~f:(fun gap ->
        if not !reopened
        then (
          now := !now + gap;
          let actions = H.poll h ~now_ms:!now in
          let idle = !now - !last_received in
          let wants_reopen = List.mem actions H.Reopen ~equal:Poly.equal in
          assert (Bool.equal wants_reopen (idle >= 45_000));
          if List.mem actions H.Send_ping ~equal:Poly.equal then assert (idle >= 30_000);
          if wants_reopen
          then reopened := true
          else if gap mod 2 = 0
          then (
            H.received h ~now_ms:!now;
            last_received := !now))))
;;
