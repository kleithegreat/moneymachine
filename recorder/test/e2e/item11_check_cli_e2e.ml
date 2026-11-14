(* Item 11 through the executable, on synthetic roots written with the independent [zstd] tool:
   - [mmrec check] gives the right byte, file and line counts and gaps, for an hour of two runs' files and a file in
     the earlier <HH>.jsonl.zst form, a truncated file, and gaps that a killed run leaves (a [start] that finds a
     connection open reports it from its last received line);
   - its output is identical, apart from byte counts, for roots that differ only in other fields' values;
   - [mmrec cat] decompresses new, old and cut recordings. *)

open Core
open Async
module H = Rec_support.Harness

let t0 = 1794650400000

let line ~recv ~conn msg =
  sprintf "{\"recv\":%d,\"conn\":%s,\"msg\":%s}\n" recv (Option.value_map conn ~default:"null" ~f:Int.to_string) msg
;;

let event ~recv ~conn name = line ~recv:(t0 + recv) ~conn (sprintf {|{"event":"%s","reason":"r"}|} name)

let trade ~recv ~conn px =
  line ~recv:(t0 + recv) ~conn:(Some conn) (sprintf {|{"channel":"trades","data":[{"coin":"BTC","px":"%s"}]}|} px)
;;

let path root channel hour run =
  match run with
  | Some run -> sprintf "%s/%s/20261114/%s.%d.jsonl.zst" root channel hour run
  | None -> sprintf "%s/%s/20261114/%s.jsonl.zst" root channel hour
;;

let file_size p = (Core_unix.stat p).st_size |> Int64.to_int_exn
let check_hours root ~from_ ~to_ = H.run_cli [ "check"; root; from_; to_ ]

let rows_sorted out =
  List.map (H.parse_check out) ~f:(String.concat ~sep:"\t") |> List.sort ~compare:String.compare
;;

let counts_and_gaps () =
  let root = H.tmp_dir () in
  let run_a = t0 - 1_000_000 in
  let run_b = t0 + 1_800_000 in
  let trades_a = path root "trades" "10" (Some run_a) in
  let trades_b = path root "trades" "10" (Some run_b) in
  let trades_old = path root "trades" "10" None in
  let trades_11 = path root "trades" "11" (Some (t0 + 3_600_000)) in
  let events_a = path root "events" "10" (Some run_a) in
  H.write_stream ~path:trades_a [ trade ~recv:1 ~conn:1 "A"; trade ~recv:2 ~conn:1 "B"; trade ~recv:3 ~conn:1 "C" ];
  H.write_stream ~path:trades_b [ trade ~recv:1_800_001 ~conn:1 "D"; trade ~recv:1_800_002 ~conn:1 "E" ];
  H.write_stream ~path:trades_old (List.init 4 ~f:(fun i -> trade ~recv:(100 + i) ~conn:1 "F"));
  H.write_stream ~path:trades_11 (List.init 5 ~f:(fun i -> trade ~recv:(3_600_000 + i) ~conn:1 "G"));
  let whole_11 = H.read_file trades_11 in
  H.cut_copy ~src:trades_11 ~dst:trades_11 ~bytes:(String.length whole_11 - 4);
  H.write_stream
    ~path:events_a
    [ event ~recv:100 ~conn:None "start"
    ; event ~recv:1_000 ~conn:(Some 1) "open"
    ; event ~recv:1_000 ~conn:(Some 2) "open"
    ; event ~recv:1_000 ~conn:(Some 3) "open"
    ; event ~recv:4_000 ~conn:(Some 2) "error"
    ; event ~recv:4_500 ~conn:(Some 2) "close"
    ; event ~recv:5_000 ~conn:(Some 1) "close"
    ; event ~recv:7_000 ~conn:(Some 2) "open"
    ; event ~recv:9_000 ~conn:(Some 1) "open"
    ; event ~recv:20_000 ~conn:(Some 3) "close"
    ];
  let%bind _, out = check_hours root ~from_:"2026111410" ~to_:"2026111411" in
  let expected =
    [ sprintf "2026111410\ttrades\t%d\t3\t9\tno" (file_size trades_a + file_size trades_b + file_size trades_old)
    ; sprintf "2026111410\tevents\t%d\t1\t10\tno" (file_size events_a)
    ; sprintf "2026111411\ttrades\t%d\t1\t5\tyes" (file_size trades_11)
    ; sprintf "gap\t1\t%d\t%d" (t0 + 5_000) (t0 + 9_000)
    ; sprintf "gap\t2\t%d\t%d" (t0 + 4_000) (t0 + 7_000)
    ; sprintf "gap\t3\t%d\t" (t0 + 20_000)
    ]
    |> List.sort ~compare:String.compare
  in
  H.check
    (List.equal String.equal (rows_sorted out) expected)
    (sprintf "check output:\n%s\nexpected:\n%s" (String.concat ~sep:"\n" (rows_sorted out)) (String.concat ~sep:"\n" expected));
  let%bind _, only_10 = check_hours root ~from_:"2026111410" ~to_:"2026111410" in
  H.check
    (not (List.exists (H.parse_check only_10) ~f:(function h :: _ -> String.equal h "2026111411" | [] -> false)))
    "a row of an hour outside the range";
  return ()
;;

let gaps_after_a_kill () =
  let root = H.tmp_dir () in
  let run_1 = t0 - 5_000 in
  let run_2 = t0 + 60_000 in
  H.write_stream
    ~path:(path root "events" "10" (Some run_1))
    [ event ~recv:100 ~conn:None "start"
    ; event ~recv:1_000 ~conn:(Some 1) "open"
    ; event ~recv:1_000 ~conn:(Some 2) "open"
    ; event ~recv:1_000 ~conn:(Some 3) "open"
    ; event ~recv:2_000 ~conn:(Some 3) "close"
    ];
  H.write_stream
    ~path:(path root "trades" "10" (Some run_1))
    [ trade ~recv:1_500 ~conn:3 "x"; trade ~recv:8_000 ~conn:1 "y" ];
  H.write_stream
    ~path:(path root "l2Book-fast" "10" (Some run_1))
    [ line ~recv:(t0 + 8_500) ~conn:(Some 2) {|{"channel":"l2Book","data":{"coin":"BTC"}}|} ];
  H.write_stream
    ~path:(path root "events" "10" (Some run_2))
    [ event ~recv:60_000 ~conn:None "start"
    ; event ~recv:61_000 ~conn:(Some 1) "open"
    ; event ~recv:62_000 ~conn:(Some 2) "open"
    ; event ~recv:63_000 ~conn:(Some 3) "open"
    ];
  let%bind _, out = check_hours root ~from_:"2026111410" ~to_:"2026111410" in
  let gaps =
    List.filter (H.parse_check out) ~f:(function "gap" :: _ -> true | _ -> false)
    |> List.map ~f:(String.concat ~sep:"\t")
    |> List.sort ~compare:String.compare
  in
  let expected =
    [ sprintf "gap\t1\t%d\t%d" (t0 + 8_000) (t0 + 61_000)
    ; sprintf "gap\t2\t%d\t%d" (t0 + 8_500) (t0 + 62_000)
    ; sprintf "gap\t3\t%d\t%d" (t0 + 2_000) (t0 + 63_000)
    ]
  in
  H.check
    (List.equal String.equal gaps expected)
    (sprintf "gaps:\n%s\nexpected:\n%s" (String.concat ~sep:"\n" gaps) (String.concat ~sep:"\n" expected));
  return ()
;;

let build root ~flip ~extra =
  let px = if flip then String.rev "KQZWXP" else "KQZWXP" in
  H.write_stream
    ~path:(path root "trades" "10" (Some (t0 - 1)))
    ([ trade ~recv:1 ~conn:1 px ^ trade ~recv:2 ~conn:1 px; trade ~recv:3 ~conn:1 px ] @ if extra then [ trade ~recv:4 ~conn:1 px ] else []);
  H.write_stream
    ~path:(path root "events" "10" (Some (t0 - 1)))
    [ event ~recv:5 ~conn:(Some 1) "open" ^ event ~recv:6_000 ~conn:(Some 1) "close" ^ event ~recv:9_000 ~conn:(Some 1) "open" ]
;;

let without_bytes out =
  List.map (H.parse_check out) ~f:(function
    | "gap" :: _ as gap -> String.concat ~sep:"\t" gap
    | hour :: channel :: _bytes :: rest -> String.concat ~sep:"\t" (hour :: channel :: rest)
    | other -> String.concat ~sep:"\t" other)
  |> List.sort ~compare:String.compare
;;

let other_fields () =
  let a = H.tmp_dir () in
  let b = H.tmp_dir () in
  let c = H.tmp_dir () in
  build a ~flip:false ~extra:false;
  build b ~flip:true ~extra:false;
  build c ~flip:false ~extra:true;
  let%bind status_a, out_a = check_hours a ~from_:"2026111410" ~to_:"2026111411" in
  let%bind status_b, out_b = check_hours b ~from_:"2026111410" ~to_:"2026111411" in
  let%bind _, out_c = check_hours c ~from_:"2026111410" ~to_:"2026111411" in
  H.check (Result.is_ok status_a && Result.is_ok status_b) "check failed";
  H.check (not (String.is_empty out_a)) "check printed nothing";
  H.check
    (List.equal String.equal (without_bytes out_a) (without_bytes out_b))
    "check differs, apart from byte counts, between roots that differ only in other fields' values";
  H.check
    (not (List.equal String.equal (without_bytes out_a) (without_bytes out_c)))
    "check does not see an extra line";
  return ()
;;

let cat_reads_every_form () =
  let root = H.tmp_dir () in
  let lines = List.init 3000 ~f:(fun i -> trade ~recv:i ~conn:1 (Int.to_string (i * 7919))) in
  let text = String.concat lines in
  let new_form = path root "trades" "10" (Some t0) in
  let old_form = path root "trades" "11" None in
  H.write_stream ~path:new_form [ text ];
  H.write_stream ~path:old_form [ text ];
  let%bind () =
    Deferred.List.iter [ new_form; old_form ] ~how:`Sequential ~f:(fun file ->
      let%map status, out = H.run_cli [ "cat"; file ] in
      H.check (Result.is_ok status) (sprintf "cat failed on %s" file);
      H.check (String.equal out text) (sprintf "cat differs from the lines written, on %s" file);
      H.check (String.equal out (H.zstd_binary_decode file)) (sprintf "cat differs from zstd -dc on %s" file))
  in
  let cut = path root "trades" "12" (Some t0) in
  H.cut_copy ~src:new_form ~dst:cut ~bytes:(file_size new_form - 50);
  let%map _, out = H.run_cli [ "cat"; cut ] in
  H.check (String.is_prefix text ~prefix:out) "cat of a cut file is not a prefix of the lines written";
  H.check (String.is_empty out || String.is_suffix out ~suffix:"\n") "cat of a cut file ends in a partial line"
;;

let () =
  H.main "item 11: mmrec check and cat" (fun () ->
    H.run_all
      [ "counts and gaps", counts_and_gaps
      ; "gaps after a kill", gaps_after_a_kill
      ; "other fields' values", other_fields
      ; "cat reads every form", cat_reads_every_form
      ])
;;
