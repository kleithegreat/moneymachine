(* Item 7: Reconnecting. The end-to-end cases are test/e2e/item07_*. *)

open Core
module B = Mmrec.Backoff
module R = Mmrec.Rate_limit

let constant x () = x
let bases = [ 1.; 2.; 4.; 8.; 16.; 32.; 60.; 60.; 60. ]

let%expect_test "item 7: backoff follows 1, 2, 4 ... 60 s without jitter at the median draw" =
  let b = B.create ~random:(constant 0.5) in
  let delays = Rec_support.Harness.in_order 9 ~f:(fun i -> B.failed b ~now:(Float.of_int i)) in
  print_s [%sexp (delays : float list)];
  [%expect {| (1 2 4 8 16 32 60 60 60) |}]
;;

let%expect_test "item 7: jitter is plus or minus 20 percent" =
  let low = B.create ~random:(constant 0.) in
  let high = B.create ~random:(constant 0.999999) in
  let show b = Rec_support.Harness.in_order 4 ~f:(fun i -> Float.round_decimal (B.failed b ~now:(Float.of_int i)) ~decimal_digits:3) in
  print_s [%sexp (show low : float list)];
  print_s [%sexp (show high : float list)];
  [%expect {|
    (0.8 1.6 3.2 6.4)
    (1.2 2.4 4.8 9.6) |}]
;;

let%test_unit "item 7: every delay is within 20 percent of 1, 2, 4 ... 60 (quickcheck)" =
  Base_quickcheck.Test.run_exn
    ~config:{ Base_quickcheck.Test.default_config with test_count = 200 }
    (module struct
      type t = float list [@@deriving sexp_of]

      let quickcheck_generator =
        Base_quickcheck.Generator.(
          list_with_length ~length:12 (float_uniform_exclusive 0. 1.))
      ;;

      let quickcheck_shrinker = Base_quickcheck.Shrinker.atomic
    end)
    ~f:(fun draws ->
      let remaining = ref draws in
      let random () =
        match !remaining with
        | x :: rest ->
          remaining := rest;
          x
        | [] -> 0.5
      in
      let b = B.create ~random in
      List.iteri draws ~f:(fun i _ ->
        let delay = B.failed b ~now:(Float.of_int i) in
        let base = Float.min 60. (2. ** Float.of_int i) in
        assert (Float.( >= ) delay (0.8 *. base -. 1e-9));
        assert (Float.( <= ) delay (1.2 *. base +. 1e-9))))
;;

let%expect_test "item 7: a connection up for 10 minutes resets the backoff, one up for less does not" =
  let b = B.create ~random:(constant 0.5) in
  let d1 = B.failed b ~now:0. in
  B.opened b ~now:d1;
  let d2 = B.failed b ~now:(d1 +. 1.) in
  B.opened b ~now:(d1 +. 1. +. d2);
  let up = d1 +. 1. +. d2 in
  let d3 = B.failed b ~now:(up +. 599.) in
  B.opened b ~now:(up +. 599. +. d3);
  let start = up +. 599. +. d3 in
  let d4 = B.failed b ~now:(start +. 600.) in
  print_s [%sexp ([ d1; d2; d3; d4 ] : float list)];
  [%expect {| (1 2 4 1) |}]
;;

let%expect_test "item 7: the sequence continues from where it was when the connection was up briefly" =
  let b = B.create ~random:(constant 0.5) in
  let delays =
    Rec_support.Harness.in_order 5 ~f:(fun i ->
      let t = Float.of_int (i * 100) in
      B.opened b ~now:t;
      B.failed b ~now:(t +. 5.))
  in
  print_s [%sexp (delays : float list)];
  [%expect {| (1 2 4 8 16) |}]
;;

(* No more than 30 connections in any minute. *)

let max_in_window times ~window_ms =
  let sorted = List.sort times ~compare:Int.compare in
  let arr = Array.of_list sorted in
  let best = ref 0 in
  Array.iteri arr ~f:(fun i start ->
    let count = ref 0 in
    for j = i to Array.length arr - 1 do
      if arr.(j) < start + window_ms then incr count
    done;
    best := Int.max !best !count);
  !best
;;

let%test_unit "item 7: no more than 30 connections in any minute, however often every connection fails" =
  let limiter = R.create ~limit:30 ~window_ms:60_000 in
  let opens = ref [] in
  let clock = ref 0 in
  let backoffs = Array.init 8 ~f:(fun _ -> B.create ~random:(constant 0.5)) in
  let next_attempt = Array.create ~len:8 0 in
  let last_open = Array.create ~len:8 0 in
  while !clock < 600_000 do
    let conn = ref 0 in
    for c = 1 to 7 do
      if next_attempt.(c) < next_attempt.(!conn) then conn := c
    done;
    let c = !conn in
    clock := Int.max !clock next_attempt.(c);
    let at = R.reserve limiter ~now_ms:!clock ~n:1 in
    clock := at;
    opens := at :: !opens;
    last_open.(c) <- at;
    B.opened backoffs.(c) ~now:(Float.of_int at /. 1000.);
    let delay = B.failed backoffs.(c) ~now:(Float.of_int at /. 1000.) in
    next_attempt.(c) <- at + Float.to_int (delay *. 1000.)
  done;
  assert (List.length !opens > 100);
  assert (max_in_window !opens ~window_ms:60_000 <= 30)
;;

let%test_unit "item 7: a rate limit keeps its bound for any schedule of requests (quickcheck)" =
  Base_quickcheck.Test.run_exn
    ~config:{ Base_quickcheck.Test.default_config with test_count = 300 }
    (module struct
      type t = int * (int * int) list [@@deriving sexp_of]

      let quickcheck_generator =
        let open Base_quickcheck.Generator in
        both
          (int_uniform_inclusive 1 40)
          (list (both (int_uniform_inclusive 0 20_000) (int_uniform_inclusive 1 40)))
      ;;

      let quickcheck_shrinker = Base_quickcheck.Shrinker.atomic
    end)
    ~f:(fun (limit, requests) ->
      let limiter = R.create ~limit ~window_ms:60_000 in
      let now = ref 0 in
      let booked = ref [] in
      let last_at = ref 0 in
      List.iter requests ~f:(fun (gap, n) ->
        let n = Int.min n limit in
        now := !now + gap;
        let at = R.reserve limiter ~now_ms:!now ~n in
        assert (at >= !now);
        assert (at >= !last_at);
        last_at := at;
        booked := List.init n ~f:(fun _ -> at) @ !booked);
      assert (max_in_window !booked ~window_ms:60_000 <= limit))
;;

let%expect_test "item 7: a rate limit books at once when it can and waits for the window when it cannot" =
  let limiter = R.create ~limit:3 ~window_ms:1000 in
  let times =
    Rec_support.Harness.in_order 8 ~f:(fun i -> R.reserve limiter ~now_ms:(if i < 4 then 0 else 100) ~n:1)
  in
  print_s [%sexp (times : int list)];
  [%expect {| (0 0 0 1000 1000 1000 2000 2000) |}]
;;
