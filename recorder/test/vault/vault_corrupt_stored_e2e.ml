(* VAULT.md test 10: a stored fills file with a corrupt frame before its end gives exactly one [error] event naming
   the file, and the run still pulls and stores; a kill's truncated last frame gives no event. Interface assumed:
   see vault_harness.ml.

   The stored files are planted: zstd frames of fills response lines made by the independent [zstd] binary, then
   either garbage with a valid frame after it (corrupt before its end) or the cut of a frame (as a kill leaves). The
   run's own pull must complete and store whatever the file's state. *)

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

let frame_bytes ~tids =
  let path = Filename.concat (H.tmp_dir ()) "frame.jsonl.zst" in
  H.write_stream ~path [ line ~tids ];
  H.read_file path
;;

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

let pulled_and_stored ~root events what =
  let pulls = V.pulls events ~kind:"fills" in
  H.check (not (List.is_empty pulls)) (sprintf "%s: no fills pull event" what);
  H.check
    (List.for_all pulls ~f:(fun e -> Poly.equal (Yojson.Safe.Util.member "complete" e.V.json) (`Bool true)))
    (sprintf "%s: a fills pull did not complete" what);
  H.check
    (List.equal Int.equal (V.stored_tids ~root) [ 1; 2; 3; 4; 5; 6 ])
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
  let%bind _outcome = V.run ~root ~fake ~now_ms:now in
  let events = V.last_run_events ~root in
  let errors = error_events events in
  H.check
    (List.length errors = 1)
    (sprintf "corrupt frame before the end: %d error events, expected 1" (List.length errors));
  H.check
    (List.for_all errors ~f:(fun e ->
       String.is_substring (Yojson.Safe.to_string e.V.json) ~substring:planted_name))
    "corrupt frame before the end: the error event does not name the file";
  pulled_and_stored ~root events "corrupt frame before the end";
  V.stop fake
;;

let truncated_last_frame () =
  let root = H.tmp_dir () in
  let%bind fake = populated () in
  let whole = frame_bytes ~tids:[ 4; 5; 6 ] in
  let cut = String.prefix whole (String.length whole / 2) in
  write_file ~path:(planted_path ~root) (frame_bytes ~tids:[ 1; 2; 3 ] ^ cut);
  let%bind _outcome = V.run ~root ~fake ~now_ms:now in
  let events = V.last_run_events ~root in
  let errors = error_events events in
  H.check
    (List.is_empty errors)
    (sprintf "truncated last frame: %d error events, expected none" (List.length errors));
  pulled_and_stored ~root events "truncated last frame";
  V.stop fake
;;

let () =
  H.main "vault 10: a corrupt stored file is one error event, a truncated one none" (fun () ->
    H.run_all
      [ "corrupt frame before the end", corrupt_before_end
      ; "truncated last frame", truncated_last_frame
      ])
;;
