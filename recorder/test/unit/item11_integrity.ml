(* Item 11: Integrity tool (the command-line case is test/e2e/item11_check_cli_e2e.ml). *)

open Core
module H = Rec_support.Harness
module I = Mmrec.Integrity

let t0 = 1794653999999 - 3_599_999

(* Another value with the same bytes in another order, so that every byte value keeps its count and the
   compressed files have the same size; the test checks that precondition. *)
let shift_digits ~shift s = if shift = 0 then s else String.rev s
let shift_letters ~shift s = if shift = 0 then s else String.rev s

let line ~recv ~conn msg = sprintf "{\"recv\":%d,\"conn\":%d,\"msg\":%s}\n" recv conn msg

let trades_line ~shift i =
  line
    ~recv:(t0 + i)
    ~conn:1
    (sprintf
       {|{"channel":"trades","data":[{"coin":"%s","px":"%s","sz":"%s","time":"%s"}]}|}
       (shift_letters ~shift "QRSTUV")
       (shift_digits ~shift "KQZWXP")
       (shift_digits ~shift "MNBVCD")
       (shift_digits ~shift "TRESAQWDF"))
;;

let l2_line ~shift i =
  line
    ~recv:(t0 + i)
    ~conn:2
    (sprintf
       {|{"channel":"l2Book","data":{"coin":"%s","levels":[[{"px":"%s","sz":"%s","n":3}],[]]}}|}
       (shift_letters ~shift "WXYZAB")
       (shift_digits ~shift "GHJLZX")
       (shift_digits ~shift "YUIOP"))
;;

let event_line ~recv ~conn ~shift name =
  line ~recv ~conn (sprintf {|{"event":"%s","reason":"%s"}|} name (shift_letters ~shift "HJKMNP"))
;;

let cut_last_bytes frame n = String.prefix frame (String.length frame - n)

(* Returns the expected entries and gaps. *)
let build root ~shift ~extra_trade_line =
  let write route date hour chunks =
    H.write_frames
      ~path:(sprintf "%s/%s/%s/%s.jsonl.zst" root route date hour)
      chunks
  in
  write
    "trades"
    "20261114"
    "10"
    [ String.concat [ trades_line ~shift 1; trades_line ~shift 2; trades_line ~shift 3 ]
    ; String.concat
        (trades_line ~shift 4 :: (if extra_trade_line then [ trades_line ~shift 5 ] else []))
    ];
  write "l2Book" "20261114" "10" [ String.concat [ l2_line ~shift 1; l2_line ~shift 2 ] ];
  write
    "events"
    "20261114"
    "10"
    [ String.concat
        [ event_line ~recv:(t0 + 10) ~conn:1 ~shift "open"
        ; event_line ~recv:(t0 + 20) ~conn:2 ~shift "open"
        ; event_line ~recv:(t0 + 5_000) ~conn:1 ~shift "close"
        ; line ~recv:(t0 + 5_001) ~conn:1 {|{"channel":"pong"}|}
        ]
    ; String.concat
        [ event_line ~recv:(t0 + 8_000) ~conn:1 ~shift "open"
        ; event_line ~recv:(t0 + 9_000) ~conn:2 ~shift "close"
        ]
    ];
  write "listings" "20261114" "10" [ line ~recv:(t0 + 30) ~conn:0 {|{"universe":[]}|} ];
  let tail = Mmrec.Zstd.compress (trades_line ~shift 9 ^ trades_line ~shift 10) in
  let path = sprintf "%s/trades/20261114/11.jsonl.zst" root in
  H.write_frames ~path [ String.concat [ trades_line ~shift 6; trades_line ~shift 7 ] ];
  Out_channel.with_file path ~append:true ~f:(fun oc ->
    Out_channel.output_string oc (cut_last_bytes tail 3));
  write "trades" "20261114" "12" [ trades_line ~shift 8 ]
;;

let size path = String.length (H.read_file path)

let%test_unit "item 11: check gives the right byte, frame and line counts and gaps on a synthetic root" =
  let root = H.tmp_dir () in
  build root ~shift:0 ~extra_trade_line:true;
  let report = I.check ~root ~from_:"2026111410" ~to_:"2026111411" in
  let entry channel hour = List.find_exn report.entries ~f:(fun e -> String.equal e.channel channel && String.equal e.hour hour) in
  let bytes route date hour = size (sprintf "%s/%s/%s/%s.jsonl.zst" root route date hour) in
  let channels_and_hours = List.map report.entries ~f:(fun e -> e.channel, e.hour) in
  assert (
    List.equal
      [%equal: string * string]
      channels_and_hours
      [ "events", "2026111410"
      ; "l2Book", "2026111410"
      ; "listings", "2026111410"
      ; "trades", "2026111410"
      ; "trades", "2026111411"
      ]);
  let trades10 = entry "trades" "2026111410" in
  assert (trades10.frames = 2);
  assert (trades10.lines = 5);
  assert (trades10.bytes = bytes "trades" "20261114" "10");
  assert (not trades10.truncated);
  let trades11 = entry "trades" "2026111411" in
  assert (trades11.frames = 1);
  assert (trades11.lines = 2);
  assert (trades11.bytes = bytes "trades" "20261114" "11");
  assert trades11.truncated;
  let l2 = entry "l2Book" "2026111410" in
  assert (l2.frames = 1 && l2.lines = 2 && not l2.truncated);
  let events = entry "events" "2026111410" in
  assert (events.frames = 2 && events.lines = 6 && not events.truncated);
  let listings = entry "listings" "2026111410" in
  assert (listings.frames = 1 && listings.lines = 1);
  assert (
    List.equal
      [%equal: I.gap]
      report.gaps
      [ { conn = 1; closed_ms = t0 + 5_000; reopened_ms = Some (t0 + 8_000) }
      ; { conn = 2; closed_ms = t0 + 9_000; reopened_ms = None }
      ])
;;

let%test_unit "item 11: the range is inclusive of both hours and excludes the rest" =
  let root = H.tmp_dir () in
  build root ~shift:0 ~extra_trade_line:true;
  let hours report = List.map report.I.entries ~f:(fun e -> e.hour) |> List.dedup_and_sort ~compare:String.compare in
  let one = I.check ~root ~from_:"2026111411" ~to_:"2026111411" in
  assert (List.equal String.equal (hours one) [ "2026111411" ]);
  let all = I.check ~root ~from_:"2026111323" ~to_:"2026111500" in
  assert (List.equal String.equal (hours all) [ "2026111410"; "2026111411"; "2026111412" ]);
  let none = I.check ~root ~from_:"2026111500" ~to_:"2026111503" in
  assert (List.is_empty none.entries);
  assert (List.is_empty none.gaps)
;;

let%test_unit "item 11: the output is identical for roots that differ only in values of other fields" =
  let a = H.tmp_dir () in
  let b = H.tmp_dir () in
  build a ~shift:0 ~extra_trade_line:true;
  build b ~shift:3 ~extra_trade_line:true;
  List.iter (H.recordings a) ~f:(fun path ->
    let twin = String.chop_prefix_exn path ~prefix:a in
    let other = b ^ twin in
    if size path <> size other
    then failwithf "test design: %s compresses to different sizes" twin ());
  assert (not (String.equal (H.read_file (List.hd_exn (H.recordings a))) (H.read_file (List.hd_exn (H.recordings b)))));
  let report_a = I.check ~root:a ~from_:"2026111410" ~to_:"2026111412" in
  let report_b = I.check ~root:b ~from_:"2026111410" ~to_:"2026111412" in
  assert ([%equal: I.report] report_a report_b);
  assert (String.equal (I.render report_a) (I.render report_b))
;;

let%test_unit "item 11: the output does change when counts change" =
  let a = H.tmp_dir () in
  let b = H.tmp_dir () in
  build a ~shift:0 ~extra_trade_line:true;
  build b ~shift:0 ~extra_trade_line:false;
  let render root = I.render (I.check ~root ~from_:"2026111410" ~to_:"2026111412") in
  assert (not (String.equal (render a) (render b)))
;;
