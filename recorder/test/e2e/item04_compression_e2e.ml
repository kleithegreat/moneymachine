(* Item 4 (compression), judged with the independent [zstd] tool and through [mmrec check] and [mmrec cat]:
   - a closed file is one zstd stream with its checksum, decompressing to exactly the lines written;
   - a file cut at any byte yields whole lines only, a prefix of those written, and is reported truncated; cut where
     a flush ended it yields the lines flushed before the cut;
   - after kill -9, every line received more than 2 s before the kill is read back. *)

open Core
open Async
module H = Rec_support.Harness
module F = Rec_support.Fake_hl

let sanitize s = String.map s ~f:(function '\r' | '\n' -> ' ' | c -> c)

let stream_config =
  { F.default_config with
    rest = F.rest_of_universe (fun () -> [ "C0"; "C1"; "C2"; "C3" ])
  ; stream = Some (fun ~conn ~seq -> F.trades_frame ~coin:(sprintf "K%d" conn) ~seq)
  ; stream_interval_ms = 5
  }
;;

let trades_line_is_exact line =
  let _, _, msg = H.parse_line line in
  let open Yojson.Safe.Util in
  let first = msg |> member "data" |> to_list |> List.hd_exn in
  let coin = first |> member "coin" |> to_string in
  let seq = first |> member "tid" |> to_int in
  let expected_tail = sprintf ",\"msg\":%s}" (sanitize (F.trades_frame ~coin ~seq)) in
  String.is_suffix line ~suffix:expected_tail && String.is_prefix line ~prefix:"{\"recv\":"
;;

let closed_file () =
  let%bind fake = F.start stream_config in
  let root = H.tmp_dir () in
  let%bind process = H.spawn_run ~root ~extra:[ "--connections"; "2" ] fake in
  let%bind () =
    H.wait_until ~timeout_s:30. ~what:"streaming" (fun () ->
      List.exists (F.accepts fake) ~f:(fun (conn, _) -> F.streamed fake ~conn >= 300))
  in
  let%bind status, _ = H.sigterm_and_wait process in
  H.check (Result.is_ok status) "exit status";
  let files = H.recordings root in
  H.check (not (List.is_empty files)) "no recordings";
  let%bind () =
    Deferred.List.iter files ~how:`Sequential ~f:(fun path ->
      let listing = H.shell_output (sprintf "zstd -lv %s 2>&1" (Filename.quote path)) in
      H.check (String.is_substring listing ~substring:"# Zstandard Frames: 1") (sprintf "%s is not one stream:\n%s" path listing);
      H.check (String.is_substring listing ~substring:"Check: XXH64") (sprintf "%s has no checksum:\n%s" path listing);
      let text = H.zstd_binary_decode path in
      H.check (String.is_suffix text ~suffix:"\n") (sprintf "%s does not end in a whole line" path);
      let%map status_cat, cat = H.run_cli [ "cat"; path ] in
      H.check (Result.is_ok status_cat) "cat failed on a closed file";
      H.check (String.equal cat text) (sprintf "cat differs from zstd -dc on %s" path);
      if String.equal (Filename.basename (Filename.dirname (Filename.dirname path))) "trades"
      then
        List.iter (String.split_lines text) ~f:(fun line ->
          H.check (trades_line_is_exact line) (sprintf "%s: a line is not the frame written: %s" path line)))
  in
  let recorded = H.contiguous_prefixes (H.trade_ids ~root) in
  H.check (not (List.is_empty recorded)) "no trades recorded";
  F.stop fake
;;

let random_hex rng n = String.init n ~f:(fun _ -> "0123456789abcdef".[Random.State.int rng 16])

let numbered_lines n =
  let rng = Random.State.make [| 4 |] in
  List.init n ~f:(fun i ->
    sprintf "{\"recv\":%d,\"conn\":1,\"msg\":{\"channel\":\"trades\",\"i\":%d,\"h\":\"%s\"}}\n" (1794653000000 + i) i (random_hex rng 60))
;;

let check_row root =
  let%map _, out = H.run_cli [ "check"; root; "2026111410"; "2026111410" ] in
  List.find (H.parse_check out) ~f:(function
    | _ :: channel :: _ -> String.equal channel "trades"
    | _ -> false)
;;

let cut_files () =
  let lines = numbered_lines 20_000 in
  let text = String.concat lines in
  let full = H.tmp_dir () in
  let path_in root = Filename.concat root "trades/20261114/10.jsonl.zst" in
  H.write_stream ~path:(path_in full) [ text ];
  let size = String.length (H.read_file (path_in full)) in
  let rng = Random.State.make [| 9 |] in
  let cuts =
    [ 1; 4; 9; 13; size / 7; size / 3; size / 2; size - 100; size - 9; size - 5; size - 1 ]
    @ List.init 12 ~f:(fun _ -> 1 + Random.State.int rng (size - 1))
  in
  let%bind full_row = check_row full in
  (match full_row with
   | Some [ _; _; _; "1"; "20000"; "no" ] -> ()
   | _ -> failwith "an uncut file is not reported as one file of 20000 lines, not truncated");
  Deferred.List.iter cuts ~how:`Sequential ~f:(fun bytes ->
    let root = H.tmp_dir () in
    H.cut_copy ~src:(path_in full) ~dst:(path_in root) ~bytes;
    let%bind _, cat = H.run_cli [ "cat"; path_in root ] in
    H.check (String.is_empty cat || String.is_suffix cat ~suffix:"\n") (sprintf "cut at %d: cat does not end on a whole line" bytes);
    H.check (String.is_prefix text ~prefix:cat) (sprintf "cut at %d: cat is not a prefix of the lines written" bytes);
    let%map row = check_row root in
    match row with
    | Some [ _; _; size_field; "1"; lines_field; "yes" ] ->
      H.check (Int.of_string size_field = bytes) (sprintf "cut at %d: bytes %s" bytes size_field);
      H.check
        (Int.of_string lines_field = List.length (String.split_lines cat))
        (sprintf "cut at %d: check counts %s lines, cat yields %d" bytes lines_field (List.length (String.split_lines cat)))
    | _ -> failwithf "cut at %d: check does not report the cut file as truncated" bytes ())
;;

let flush_end_cut () =
  let%bind fake = F.start stream_config in
  let root = H.tmp_dir () in
  let%bind process = H.spawn_run ~root ~extra:[ "--connections"; "2" ] fake in
  let%bind () =
    H.wait_until ~timeout_s:30. ~what:"streaming" (fun () ->
      List.exists (F.accepts fake) ~f:(fun (conn, _) -> F.streamed fake ~conn >= 600))
  in
  let live_trades () =
    List.find (H.recordings root) ~f:(fun path -> String.equal (Filename.basename (Filename.dirname (Filename.dirname path))) "trades")
  in
  let size path = (Core_unix.stat path).st_size |> Int64.to_int_exn in
  let rec find_stable_size () =
    match live_trades () with
    | None ->
      let%bind () = after (Time_float.Span.of_ms 50.) in
      find_stable_size ()
    | Some path ->
      let before = size path in
      let%bind () = after (Time_float.Span.of_ms 150.) in
      let observed_at = H.now_ms () in
      if before > 0 && before = size path then return (path, before, observed_at) else find_stable_size ()
  in
  let%bind path, flushed_bytes, observed_at = find_stable_size () in
  let cut_root = H.tmp_dir () in
  let cut_path = Filename.concat cut_root "trades/20261114/10.jsonl.zst" in
  H.cut_copy ~src:path ~dst:cut_path ~bytes:flushed_bytes;
  H.send_signal process Signal.kill;
  let%bind _ = Process.wait process in
  let%bind _, cat = H.run_cli [ "cat"; cut_path ] in
  H.check (not (String.is_empty cat)) "nothing read from the file cut at a flush";
  H.check (String.is_suffix cat ~suffix:"\n") "a file cut at a flush ends in a partial line";
  H.check
    (String.equal cat (H.zstd_lenient_decode cut_path))
    "cat of a file cut where a flush ended differs from what the lossless decoder reads of it";
  let killed_lines = H.zstd_lenient_decode path in
  H.check (String.is_prefix killed_lines ~prefix:cat) "the flushed lines are not a prefix of the killed file's lines";
  let old_enough =
    List.filter (String.split_lines killed_lines) ~f:(fun line ->
      let recv, _, _ = H.parse_line line in
      recv < observed_at - 3_000)
  in
  H.check (not (List.is_empty old_enough)) "no line older than 3 s to check";
  let in_cut = String.Set.of_list (String.split_lines cat) in
  List.iter old_enough ~f:(fun line ->
    H.check (Set.mem in_cut line) "a line received long before the flush is missing from the file cut there");
  let%bind row = check_row cut_root in
  (match row with
   | Some [ _; _; _; "1"; lines_field; "yes" ] ->
     H.check (Int.of_string lines_field = List.length (String.split_lines cat)) "check's line count differs from cat's"
   | _ -> failwith "check does not report the flush-cut file as truncated");
  F.stop fake
;;

let kill9 () =
  let%bind fake = F.start stream_config in
  let root = H.tmp_dir () in
  let%bind process = H.spawn_run ~root ~extra:[ "--connections"; "2" ] fake in
  let%bind () =
    H.wait_until ~timeout_s:30. ~what:"streaming" (fun () ->
      List.exists (F.accepts fake) ~f:(fun (conn, _) -> F.streamed fake ~conn >= 300))
  in
  let sent_3_s_before_kill =
    List.map (F.accepts fake) ~f:(fun (conn, _) -> sprintf "K%d" conn, F.streamed fake ~conn)
  in
  let%bind () = after (Time_float.Span.of_sec 3.) in
  H.send_signal process Signal.kill;
  let%bind status = Process.wait process in
  H.check
    (match status with
     | Error (`Signal s) -> Signal.equal s Signal.kill
     | _ -> false)
    "the process was not killed";
  let recorded = H.contiguous_prefixes (H.trade_ids ~root) in
  H.check (not (List.is_empty recorded)) "no trades recorded";
  List.iter sent_3_s_before_kill ~f:(fun (coin, sent) ->
    let m = Option.value (List.Assoc.find recorded ~equal:String.equal coin) ~default:0 in
    H.check (m >= sent) (sprintf "%s: %d recorded, but %d were received 3 s before the kill" coin m sent));
  let now = H.now_ms () in
  let from_ = H.hour_of_ms (now - 3_600_000) in
  let to_ = H.hour_of_ms (now + 3_600_000) in
  let%bind _, out = H.run_cli [ "check"; root; from_; to_ ] in
  let rows = H.parse_check out in
  H.check
    (List.exists rows ~f:(function
       | _ :: channel :: _ :: _ :: _ :: truncated :: _ -> String.equal channel "trades" && String.equal truncated "yes"
       | _ -> false))
    "check does not report the killed run's trades file as truncated";
  F.stop fake
;;

let () =
  H.main "item 4: compression" (fun () ->
    H.run_all
      [ "closed file", closed_file
      ; "cut at any byte", cut_files
      ; "cut where a flush ended", flush_end_cut
      ; "kill -9", kill9
      ])
;;
