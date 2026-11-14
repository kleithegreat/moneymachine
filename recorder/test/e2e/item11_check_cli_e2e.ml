(* Item 11 through the executable: [mmrec check] prints the report, identical for roots that differ only in the
   values of fields other than channel and event; [mmrec cat] decompresses a recording. *)

open Core
open Async
module H = Rec_support.Harness
module I = Mmrec.Integrity

let t0 = 1794653999999 - 3_599_999

let line ~recv ~conn msg = sprintf "{\"recv\":%d,\"conn\":%d,\"msg\":%s}\n" recv conn msg

let build root ~flip ~extra =
  let px = if flip then String.rev "KQZWXP" else "KQZWXP" in
  let trade i = line ~recv:(t0 + i) ~conn:1 (sprintf {|{"channel":"trades","data":[{"coin":"BTC","px":"%s","tid":%d}]}|} px i) in
  let write route hour chunks =
    H.write_frames ~path:(sprintf "%s/%s/20261114/%s.jsonl.zst" root route hour) chunks
  in
  write "trades" "10" ([ trade 1 ^ trade 2; trade 3 ] @ if extra then [ trade 4 ] else []);
  write
    "events"
    "10"
    [ line ~recv:(t0 + 5) ~conn:1 {|{"event":"open"}|}
      ^ line ~recv:(t0 + 6000) ~conn:1 {|{"event":"close","reason":"eof"}|}
      ^ line ~recv:(t0 + 9000) ~conn:1 {|{"event":"open"}|}
    ]
;;

let check_cli root = H.run_cli [ "check"; root; "2026111410"; "2026111411" ]

let () =
  H.main "item 11: mmrec check and cat" (fun () ->
    let a = H.tmp_dir () in
    let b = H.tmp_dir () in
    let c = H.tmp_dir () in
    build a ~flip:false ~extra:false;
    build b ~flip:true ~extra:false;
    build c ~flip:false ~extra:true;
    H.check
      (List.for_all (H.recordings a) ~f:(fun path ->
         let twin = b ^ String.chop_prefix_exn path ~prefix:a in
         String.length (H.read_file path) = String.length (H.read_file twin)))
      "test design: the roots compress to different sizes";
    let%bind status_a, out_a = check_cli a in
    let%bind status_b, out_b = check_cli b in
    let%bind _, out_c = check_cli c in
    H.check (Result.is_ok status_a && Result.is_ok status_b) "check failed";
    H.check (not (String.is_empty out_a)) "check printed nothing";
    H.check (String.equal out_a out_b) "check differs between roots that differ only in other fields' values";
    H.check (not (String.equal out_a out_c)) "check does not see an extra frame and line";
    H.check
      (String.equal out_a (I.render (I.check ~root:a ~from_:"2026111410" ~to_:"2026111411")))
      "check prints something other than the Integrity report";
    let file = Filename.concat a "trades/20261114/10.jsonl.zst" in
    let%bind status_cat, out_cat = H.run_cli [ "cat"; file ] in
    H.check (Result.is_ok status_cat) "cat failed";
    H.check (String.equal out_cat (H.zstd_binary_decode file)) "cat differs from zstd -dc";
    return ())
;;
