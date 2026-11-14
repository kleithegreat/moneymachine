(* Items 3 and 13 against the running recorder, with its clock set (libfaketime) to a few seconds before 11:00 UTC
   on 2026-11-14 (1794654000000 ms since the epoch):
   - item 3: a line received before 11:00:00.000 is in a file of hour 10 and one received at or after it in a file of
     hour 11; each run writes its own files, named <HH>.<run>.jsonl.zst with <run> the run's start in ms; a restart
     within the hour writes new files and the earlier files' bytes do not change;
   - item 13: once a channel has a file of the new hour, its hour-10 files are closed (their stream ended, so
     [zstd -t] passes) and their bytes never change again, even across a restart later in the new hour. *)

open Core
open Async
module H = Rec_support.Harness
module F = Rec_support.Fake_hl

let boundary = 1794654000000

let config =
  { F.default_config with
    rest = F.rest_of_universe (fun () -> [ "C0"; "C1" ])
  ; stream = Some (fun ~conn ~seq -> F.trades_frame ~coin:(sprintf "K%d" conn) ~seq)
  ; stream_interval_ms = 10
  }
;;

let file_hour_and_run path =
  let name = Filename.basename path in
  match String.split name ~on:'.' with
  | [ hour; run; "jsonl"; "zst" ] -> hour, Int.of_string run
  | _ -> failwithf "%s is not named <HH>.<run>.jsonl.zst" path ()
;;

let channel_of path = Filename.basename (Filename.dirname (Filename.dirname path))

let files_of_hour root hour =
  List.filter (H.recordings root) ~f:(fun path -> String.equal (fst (file_hour_and_run path)) hour)
;;

let zstd_ok path =
  match Core_unix.system (sprintf "zstd -t -q %s 2>/dev/null" (Filename.quote path)) with
  | Ok () -> true
  | Error _ -> false
;;

let snapshot root = List.map (H.recordings root) ~f:(fun path -> path, H.read_file path)

let () =
  H.main "items 3 and 13: hours, one file per run, hour end" (fun () ->
    let%bind fake = F.start config in
    let root = H.tmp_dir () in
    let started = H.now_ms () in
    let first_start = boundary - 3_000 in
    let%bind process1 =
      H.spawn_run ~root ~env:(H.faketime_env ~at_ms:first_start) ~extra:[ "--connections"; "2" ] fake
    in
    let%bind () =
      H.wait_until ~timeout_s:90. ~what:"a trades file of hour 11" (fun () ->
        List.exists (files_of_hour root "11") ~f:(fun path -> String.equal (channel_of path) "trades"))
    in
    let channels_with_hour_11 =
      List.map (files_of_hour root "11") ~f:channel_of |> List.dedup_and_sort ~compare:String.compare
    in
    List.iter (files_of_hour root "10") ~f:(fun path ->
      if List.mem channels_with_hour_11 (channel_of path) ~equal:String.equal
      then H.check (zstd_ok path) (sprintf "%s is not closed although its channel is in the next hour" path));
    let hour_10_at_rollover =
      List.filter_map (files_of_hour root "10") ~f:(fun path ->
        if List.mem channels_with_hour_11 (channel_of path) ~equal:String.equal
        then Some (path, H.read_file path)
        else None)
    in
    H.check (not (List.is_empty hour_10_at_rollover)) "no hour-10 file to watch";
    let%bind () = after (Time_float.Span.of_sec 2.) in
    let%bind status1, _ = H.sigterm_and_wait process1 in
    H.check (Result.is_ok status1) "first run's exit status";
    let after_first_run = snapshot root in
    List.iter hour_10_at_rollover ~f:(fun (path, bytes) ->
      H.check (String.equal (H.read_file path) bytes) (sprintf "%s changed after the next hour began" path));
    let runs_of_first =
      List.map after_first_run ~f:(fun (path, _) -> snd (file_hour_and_run path)) |> List.dedup_and_sort ~compare:Int.compare
    in
    (match runs_of_first with
     | [ run ] ->
       H.check
         (run >= first_start - 1_000 && run <= first_start + (H.now_ms () - started) + 1_000)
         (sprintf "run id %d is not the run's start in ms (clock set to %d)" run first_start)
     | runs -> failwithf "one run wrote files of %d run ids" (List.length runs) ());
    let lines = H.all_lines ~root in
    H.check (not (List.is_empty lines)) "no lines";
    List.iter (H.recordings root) ~f:(fun path ->
      let hour, _ = file_hour_and_run path in
      let channel = channel_of path in
      let in_file = List.map (H.lines_in_file path) ~f:(fun (recv, _, _) -> recv) in
      List.iter in_file ~f:(fun recv ->
        H.check
          (String.equal (String.sub (H.hour_of_ms recv) ~pos:8 ~len:2) hour)
          (sprintf "%s (%s): a line received at %d is in the wrong hour's file" path channel recv);
        H.check
          (Bool.equal (recv < boundary) (String.equal hour "10"))
          (sprintf "%s: line at %d on the wrong side of 11:00:00.000" path recv)));
    let trades_recvs =
      List.filter_map lines ~f:(fun (channel, recv, _, _) -> if String.equal channel "trades" then Some recv else None)
    in
    H.check (List.exists trades_recvs ~f:(fun r -> r < boundary)) "no trades line before 11:00";
    H.check (List.exists trades_recvs ~f:(fun r -> r >= boundary)) "no trades line from 11:00";
    let second_start = boundary + 30_000 in
    let%bind process2 =
      H.spawn_run ~root ~env:(H.faketime_env ~at_ms:second_start) ~extra:[ "--connections"; "2" ] fake
    in
    let%bind () =
      H.wait_until ~timeout_s:60. ~what:"a second run's file of hour 11" (fun () ->
        List.length
          (List.dedup_and_sort ~compare:Int.compare
             (List.map (files_of_hour root "11") ~f:(fun path -> snd (file_hour_and_run path))))
        >= 2)
    in
    let%bind () = after (Time_float.Span.of_sec 2.) in
    let%bind status2, _ = H.sigterm_and_wait process2 in
    H.check (Result.is_ok status2) "second run's exit status";
    List.iter after_first_run ~f:(fun (path, bytes) ->
      H.check (String.equal (H.read_file path) bytes) (sprintf "%s changed when a later run started and stopped" path));
    List.iter (H.recordings root) ~f:(fun path ->
      H.check (zstd_ok path) (sprintf "%s is not a whole stream after both runs stopped" path));
    let runs_of_hour_11 =
      List.map (files_of_hour root "11") ~f:(fun path -> snd (file_hour_and_run path))
      |> List.dedup_and_sort ~compare:Int.compare
    in
    H.check (List.length runs_of_hour_11 = 2) "hour 11 does not hold the files of exactly two runs";
    H.check (List.exists runs_of_hour_11 ~f:(fun r -> r >= second_start - 1_000)) "second run's id is not its start";
    F.stop fake)
;;
