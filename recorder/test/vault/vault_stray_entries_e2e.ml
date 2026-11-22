(* VAULT.md test 12: stray entries. A subdirectory and a file not named [*.jsonl.zst] under a stored day
   change nothing: the run succeeds and its events are identical to a run without them. *)

open Core
open Async
module H = Rec_support.Harness
module V = Vault_harness

let normalize_event (e : V.event) =
  match e.json with
  | `Assoc fields ->
    `Assoc (List.filter fields ~f:(fun (k, _) -> not (String.equal k "recv")))
  | other -> other
;;

let plant_strays day_dir =
  let sub = Filename.concat day_dir "stray_subdir" in
  Core_unix.mkdir_p sub;
  Out_channel.write_all (Filename.concat sub "ignored.jsonl.zst") ~data:"not valid zstd\n";
  Out_channel.write_all
    (Filename.concat day_dir "notes.txt")
    ~data:"stray non-recording file\n";
  Out_channel.write_all
    (Filename.concat day_dir "00.jsonl.zst.tmp")
    ~data:"partial temp file\n"
;;

let () =
  H.main "vault 12: stray entries under a stored day change nothing" (fun () ->
    let root_clean = H.tmp_dir () in
    let root_stray = H.tmp_dir () in
    let%bind fake = V.start () in
    for tid = 1 to 3 do
      V.add_fill fake ~tid ~time:(V.nov 5 9 0 + (tid * 1000)) ~visible:true
    done;
    V.add_funding fake ~coin:"ETH" ~time:(V.nov 5 8 0) ~visible:true;
    V.add_funding fake ~coin:"BTC" ~time:(V.nov 5 8 0) ~visible:true;
    let t1 = V.nov 5 10 0 in
    let%bind clean1 = V.run ~root:root_clean ~fake ~now_ms:t1 in
    V.check_exit clean1 ~expected:0 "clean first run";
    let%bind stray1 = V.run ~root:root_stray ~fake ~now_ms:t1 in
    V.check_exit stray1 ~expected:0 "stray root first run";
    let fills_files = V.files ~root:root_stray "fills" in
    let funding_files = V.files ~root:root_stray "funding" in
    H.check (not (List.is_empty fills_files)) "first run stored no fills file";
    H.check (not (List.is_empty funding_files)) "first run stored no funding file";
    plant_strays (Filename.dirname (List.hd_exn fills_files));
    plant_strays (Filename.dirname (List.hd_exn funding_files));
    V.add_fill fake ~tid:4 ~time:(V.nov 6 9 0) ~visible:true;
    V.add_funding fake ~coin:"SOL" ~time:(V.nov 6 8 0) ~visible:true;
    let t2 = V.nov 6 10 0 in
    let%bind clean2 = V.run ~root:root_clean ~fake ~now_ms:t2 in
    V.check_exit clean2 ~expected:0 "clean second run";
    let%bind stray2 = V.run ~root:root_stray ~fake ~now_ms:t2 in
    V.check_exit stray2 ~expected:0 "second run with stray entries";
    H.check
      (List.equal
         Int.equal
         (V.stored_tids ~root:root_stray)
         (V.stored_tids ~root:root_clean))
      "stored fill identities differ when stray entries are present";
    H.check
      (List.equal
         [%equal: string * int]
         (V.stored_funding ~root:root_stray)
         (V.stored_funding ~root:root_clean))
      "stored funding identities differ when stray entries are present";
    H.check
      (V.watermark root_stray = V.watermark root_clean)
      "watermark differs when stray entries are present";
    let clean_events = List.map (V.last_run_events ~root:root_clean) ~f:normalize_event in
    let stray_events = List.map (V.last_run_events ~root:root_stray) ~f:normalize_event in
    H.check
      (List.equal Yojson.Safe.equal stray_events clean_events)
      (sprintf
         "events with stray entries differ from clean run:\nstray: %s\nclean: %s"
         (String.concat
            ~sep:"; "
            (List.map stray_events ~f:(fun event -> Yojson.Safe.to_string event)))
         (String.concat
            ~sep:"; "
            (List.map clean_events ~f:(fun event -> Yojson.Safe.to_string event))));
    V.stop fake)
;;
