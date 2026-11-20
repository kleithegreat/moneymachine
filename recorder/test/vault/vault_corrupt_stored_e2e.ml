(* VAULT.md test 10: a stored fills file with a corrupt frame or unparseable line before its end gives exactly one
   [error] event naming the file, preserves prior identities, and the run still pulls and stores; a kill's
   truncated last line spanning >1 zstd block (>128 KiB) gives no event. Interface assumed: see vault_harness.ml. *)

open Core
open Async
module H = Rec_support.Harness
module V = Vault_harness

let now = V.nov 5 12 0
let planted_name = "00.1793491200000.jsonl.zst"
let planted_path ~root = Filename.concat (Filename.concat (Filename.concat (V.vault_dir root) "fills") "20261101") planted_name

(* One fills response line holding these fills. *)
let line ~tids =
  let fills = List.map tids ~f:(fun tid -> { V.tid; time = V.nov 4 0 0 + (tid * 1000); visible = true }) in
  sprintf
    {|{"recv":%d,"request":{"type":"userFillsByTime"},"msg":%s}|}
    (V.nov 1 0 0)
    (V.array_json (List.map fills ~f:V.fill_json))
  ^ "\n"
;;

let stream_bytes lines =
  let path = Filename.concat (H.tmp_dir ()) "frame.jsonl.zst" in
  H.write_stream ~path lines;
  H.read_file path
;;

let frame_bytes ~tids = stream_bytes [ line ~tids ]

let write_file ~path contents =
  Core_unix.mkdir_p (Filename.dirname path);
  Out_channel.write_all path ~data:contents
;;

let populated () =
  let%map fake = V.start () in
  for tid = 1 to 6 do
    V.add_fill fake ~tid ~time:(V.nov 4 0 0 + (tid * 1000)) ~visible:true
  done;
  fake
;;

let error_events events = V.named events "error"

let run_stored_tids ~root =
  V.files ~root "fills"
  |> List.filter ~f:(fun path -> not (String.is_suffix path ~suffix:planted_name))
  |> List.concat_map ~f:V.lines_of_file
  |> List.map ~f:(Yojson.Safe.Util.member "msg")
  |> List.concat_map ~f:(fun msg ->
    List.map (Yojson.Safe.Util.to_list msg) ~f:(fun item ->
      Yojson.Safe.Util.to_int (Yojson.Safe.Util.member "tid" item)))
  |> List.dedup_and_sort ~compare:Int.compare
;;

let pulled_and_stored ~root ~expected_new events outcome what =
  V.check_exit outcome ~expected:0 what;
  let pulls = V.pulls events ~kind:"fills" in
  H.check (not (List.is_empty pulls)) (sprintf "%s: no fills pull event" what);
  H.check
    (List.for_all pulls ~f:(fun e -> Poly.equal (Yojson.Safe.Util.member "complete" e.V.json) (`Bool true)))
    (sprintf "%s: a fills pull did not complete" what);
  H.check
    (V.new_total events ~kind:"fills" = expected_new)
    (sprintf "%s: fills pull counted %d new, expected %d" what (V.new_total events ~kind:"fills") expected_new);
  H.check
    (List.equal Int.equal (run_stored_tids ~root) [ 1; 2; 3; 4; 5; 6 ])
    (sprintf "%s: the run did not store the pulled fills" what);
  H.check
    (List.exists (V.files ~root "fills") ~f:(fun path -> not (String.is_suffix path ~suffix:planted_name)))
    (sprintf "%s: the run stored no file of its own" what)
;;

let corrupt_before_end () =
  let root = H.tmp_dir () in
  let%bind fake = populated () in
  let contents =
    frame_bytes ~tids:[ 1; 2; 3 ] ^ String.make 64 '\xff' ^ frame_bytes ~tids:[ 4; 5; 6 ]
  in
  write_file ~path:(planted_path ~root) contents;
  let%bind outcome = V.run ~root ~fake ~now_ms:now in
  let events = V.last_run_events ~root in
  let errors = error_events events in
  H.check
    (List.length errors = 1)
    (sprintf "corrupt frame before the end: %d error events, expected 1" (List.length errors));
  H.check
    (List.for_all errors ~f:(fun e ->
       String.is_substring (Yojson.Safe.to_string e.V.json) ~substring:planted_name))
    "corrupt frame before the end: the error event does not name the file";
  pulled_and_stored ~root ~expected_new:3 events outcome "corrupt frame before the end";
  V.stop fake
;;

let bad_line_before_end ~bad_line ~what () =
  let root = H.tmp_dir () in
  let%bind fake = populated () in
  let contents = stream_bytes [ line ~tids:[ 1; 2; 3 ]; bad_line; line ~tids:[ 4; 5; 6 ] ] in
  write_file ~path:(planted_path ~root) contents;
  let%bind outcome = V.run ~root ~fake ~now_ms:now in
  let events = V.last_run_events ~root in
  let errors = error_events events in
  H.check
    (List.length errors = 1)
    (sprintf "%s: %d error events, expected 1" what (List.length errors));
  H.check
    (List.for_all errors ~f:(fun e ->
       String.is_substring (Yojson.Safe.to_string e.V.json) ~substring:planted_name))
    (sprintf "%s: the error event does not name the file" what);
  pulled_and_stored ~root ~expected_new:3 events outcome what;
  V.stop fake
;;

let find_mid_line_multi_block_cut ~prefix_line whole =
  let min_decoded = String.length prefix_line + (128 * 1024) in
  let rec search lo hi best =
    if lo > hi
    then best
    else (
      let mid = (lo + hi) / 2 in
      let decoded = H.decode_lossless (String.prefix whole mid) in
      if String.length decoded > min_decoded
      then search lo (mid - 1) (Some (mid, decoded))
      else search (mid + 1) hi best)
  in
  let cut, decoded =
    Option.value_exn
      (search 1 (String.length whole - 1) None)
      ~message:"failed to find a >128 KiB cut in the compressed stream"
  in
  H.check (String.is_prefix decoded ~prefix:prefix_line) "cut lost the prefix line";
  H.check
    (String.length decoded > min_decoded)
    (sprintf "cut decoded only %d bytes, expected > %d" (String.length decoded) min_decoded);
  H.check
    (not (String.is_suffix decoded ~suffix:"\n"))
    "cut ended on a newline rather than mid-line";
  String.prefix whole cut
;;

let truncated_last_line () =
  let root = H.tmp_dir () in
  let%bind fake = populated () in
  let prefix_line = line ~tids:[ 1; 2; 3 ] in
  let large_tids = List.init 1500 ~f:(fun i -> 100 + i) in
  let large_line = line ~tids:large_tids in
  H.check
    (String.length large_line > 256 * 1024)
    (sprintf "large_line is %d bytes, expected > 256 KiB" (String.length large_line));
  let whole = stream_bytes [ prefix_line; large_line ] in
  let cut = find_mid_line_multi_block_cut ~prefix_line whole in
  write_file ~path:(planted_path ~root) cut;
  let%bind outcome = V.run ~root ~fake ~now_ms:now in
  let events = V.last_run_events ~root in
  let errors = error_events events in
  H.check
    (List.is_empty errors)
    (sprintf "truncated last line: %d error events, expected none" (List.length errors));
  pulled_and_stored ~root ~expected_new:3 events outcome "truncated last line";
  V.stop fake
;;

let () =
  H.main "vault 10: a corrupt stored file is one error event, a truncated one none" (fun () ->
    H.run_all
      [ "corrupt frame before the end", corrupt_before_end
      ; ( "corrupt json line before the end"
        , bad_line_before_end ~bad_line:"{not json\n" ~what:"corrupt json line before the end" )
      ; ( "unexpected shape before the end"
        , bad_line_before_end ~bad_line:"{\"unexpected\":true}\n" ~what:"unexpected shape before the end" )
      ; "truncated last line (>128 KiB)", truncated_last_line
      ])
;;
