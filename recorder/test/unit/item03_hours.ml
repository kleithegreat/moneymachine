(* Item 3: Hours. 2026-11-14 10:59:59.999 UTC is 1794653999999 ms since the epoch. *)

open Core

let at_10_59 = 1794653999999
let at_11_00 = 1794654000000
let at_23_59 = 1794700799999
let at_00_00 = 1794700800000

let%expect_test "item 3: 10:59:59.999 is hour 10 and 11:00:00.000 is hour 11" =
  let path ms = Mmrec.Hour_path.of_recv ~root:"/r" Mmrec.Route.Trades ~recv_ms:ms in
  print_endline (path at_10_59);
  print_endline (path at_11_00);
  print_endline (path at_23_59);
  print_endline (path at_00_00);
  [%expect {|
    /r/trades/20261114/10.jsonl.zst
    /r/trades/20261114/11.jsonl.zst
    /r/trades/20261114/23.jsonl.zst
    /r/trades/20261115/00.jsonl.zst |}]
;;

let%expect_test "item 3: every channel has its directory, listings included" =
  List.iter
    Mmrec.Route.[ Trades; L2_book; L2_book_fast; All_dexs_asset_ctxs; Events; Listings ]
    ~f:(fun route ->
      print_endline (Mmrec.Hour_path.of_recv ~root:"data/ws" route ~recv_ms:at_10_59));
  [%expect {|
    data/ws/trades/20261114/10.jsonl.zst
    data/ws/l2Book/20261114/10.jsonl.zst
    data/ws/l2Book-fast/20261114/10.jsonl.zst
    data/ws/allDexsAssetCtxs/20261114/10.jsonl.zst
    data/ws/events/20261114/10.jsonl.zst
    data/ws/listings/20261114/10.jsonl.zst |}]
;;

let%expect_test "item 3: hour keys" =
  print_endline (Mmrec.Hour_path.hour_key ~recv_ms:at_10_59);
  print_endline (Mmrec.Hour_path.hour_key ~recv_ms:at_11_00);
  print_endline (Mmrec.Hour_path.hour_key ~recv_ms:at_00_00);
  [%expect {|
    2026111410
    2026111411
    2026111500 |}]
;;

let independent_hour_key ms =
  let time = Time_ns.of_int_ns_since_epoch (ms * 1_000_000) in
  let date, ofday = Time_ns.to_date_ofday time ~zone:Time_float.Zone.utc in
  let hour = Time_ns.Ofday.to_span_since_start_of_day ofday |> Time_ns.Span.to_hr |> Float.to_int in
  sprintf "%04d%02d%02d%02d" (Date.year date) (Month.to_int (Date.month date)) (Date.day date) hour
;;

let%test_unit "item 3: the hour is the UTC hour of the receive time (quickcheck)" =
  Base_quickcheck.Test.run_exn
    ~config:{ Base_quickcheck.Test.default_config with test_count = 2000 }
    (module struct
      type t = int [@@deriving sexp_of]

      let quickcheck_generator =
        Base_quickcheck.Generator.int_uniform_inclusive 0 4_102_444_800_000
      ;;

      let quickcheck_shrinker = Base_quickcheck.Shrinker.int
    end)
    ~f:(fun ms ->
      let key = Mmrec.Hour_path.hour_key ~recv_ms:ms in
      assert (String.equal key (independent_hour_key ms));
      let path = Mmrec.Hour_path.of_recv ~root:"/r" Mmrec.Route.Events ~recv_ms:ms in
      let date = String.sub key ~pos:0 ~len:8 in
      let hour = String.sub key ~pos:8 ~len:2 in
      assert (String.equal path (sprintf "/r/events/%s/%s.jsonl.zst" date hour)))
;;

let with_root f =
  let root = Rec_support.Harness.tmp_dir () in
  f root
;;

let decode path = Mmrec.Frames.decode (Rec_support.Harness.read_file path)

let%test_unit "item 3: lines either side of the hour boundary go to different files" =
  with_root (fun root ->
    let clock = ref 0 in
    let writer = Mmrec.Writer.create ~root ~now_ms:(fun () -> !clock) in
    Mmrec.Writer.add writer Trades ~recv_ms:at_10_59 "{\"a\":1}\n";
    Mmrec.Writer.add writer Trades ~recv_ms:at_11_00 "{\"a\":2}\n";
    Mmrec.Writer.close writer;
    let ten = decode (Mmrec.Hour_path.of_recv ~root Trades ~recv_ms:at_10_59) in
    let eleven = decode (Mmrec.Hour_path.of_recv ~root Trades ~recv_ms:at_11_00) in
    assert (String.equal ten.data "{\"a\":1}\n");
    assert (String.equal eleven.data "{\"a\":2}\n"))
;;

let%test_unit "item 3: a restart within an hour appends to its file" =
  with_root (fun root ->
    let clock = ref 0 in
    let first = Mmrec.Writer.create ~root ~now_ms:(fun () -> !clock) in
    Mmrec.Writer.add first Events ~recv_ms:at_10_59 "{\"n\":1}\n";
    Mmrec.Writer.close first;
    let path = Mmrec.Hour_path.of_recv ~root Events ~recv_ms:at_10_59 in
    let before = Rec_support.Harness.read_file path in
    let second = Mmrec.Writer.create ~root ~now_ms:(fun () -> !clock) in
    Mmrec.Writer.add second Events ~recv_ms:(at_10_59 - 5000) "{\"n\":2}\n";
    Mmrec.Writer.close second;
    let after = Rec_support.Harness.read_file path in
    assert (String.is_prefix after ~prefix:before);
    let decoded = Mmrec.Frames.decode after in
    assert (String.equal decoded.data "{\"n\":1}\n{\"n\":2}\n");
    assert (decoded.frames = 2);
    assert (not decoded.truncated);
    assert (
      String.equal
        (Rec_support.Harness.zstd_binary_decode path)
        "{\"n\":1}\n{\"n\":2}\n"))
;;
