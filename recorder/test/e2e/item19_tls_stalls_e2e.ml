(* Item 19: over HTTPS, a listings request whose server stalls in the TLS handshake, before the status line, or
   in a chunked body gives an [error] event within 35 s and leaves the open file count where it was. Baseline
   descriptor counts are taken as in item 18, once the hourly files exist on disk and before the first stall. *)

open Core
open Async
module H = Rec_support.Harness
module F = Rec_support.Fake_hl

let stalls = 3
let support file = Filename_unix.realpath (Filename.concat "../support" file)

let is_perp_dexs request =
  match Yojson.Safe.from_string request with
  | `Assoc fields ->
    Poly.equal
      (List.Assoc.find fields ~equal:String.equal "type")
      (Some (`String "perpDexs"))
  | _ -> false
  | exception Yojson.Json_error _ -> false
;;

let open_fds ~pid =
  Array.length (Stdlib.Sys.readdir (sprintf "/proc/%d/fd" (Pid.to_int pid)))
;;

let settled_fds ~pid =
  let rec go samples least =
    if samples = 0
    then return least
    else (
      let least = Int.min least (open_fds ~pid) in
      let%bind () = after (Time_float.Span.of_ms 50.) in
      go (samples - 1) least)
  in
  go 10 Int.max_value
;;

let reason_of msg =
  match Yojson.Safe.Util.member "reason" msg with
  | `String s -> s
  | _ -> ""
;;

let run_scenario ~name ~mode =
  let stall_enabled = ref false in
  let stalled_times = ref [] in
  let rest_fault () =
    if !stall_enabled && List.length !stalled_times < stalls
    then (
      stalled_times := H.now_ms () :: !stalled_times;
      Some mode)
    else None
  in
  let config =
    { F.default_config with
      rest = F.rest_of_universe (fun () -> [ "C0"; "C1" ])
    ; rest_tls =
        Some
          { F.crt_file = support "tls_server.crt"; key_file = support "tls_server.key" }
    ; rest_fault
    ; stream = Some (fun ~conn ~seq -> F.trades_frame ~coin:(sprintf "K%d" conn) ~seq)
    ; stream_interval_ms = 10
    }
  in
  let%bind fake = F.start config in
  let root = H.tmp_dir () in
  let%bind process =
    H.spawn_run
      ~root
      ~env:[ "SSL_CERT_FILE", support "tls_server.crt" ]
      ~listings_interval_s:6
      ~extra:[ "--connections"; "2" ]
      fake
  in
  let pid = Process.pid process in
  let exited () = Deferred.is_determined (Process.wait process) in
  let has_recording channel =
    not (List.is_empty (H.recordings (Filename.concat root channel)))
  in
  let listings_errors () =
    List.filter_map (H.events ~root) ~f:(fun (recv, conn, event, msg) ->
      if String.equal event "error" && Option.is_none conn
      then Some (recv, reason_of msg)
      else None)
  in
  let cleanup () =
    let%bind () =
      if exited ()
      then return ()
      else (
        let%map _status, _seconds = H.sigterm_and_wait process in
        ())
    in
    F.stop fake
  in
  Monitor.protect ~finally:cleanup (fun () ->
    let%bind () =
      H.wait_until
        ~timeout_s:30.
        ~what:(name ^ ": first listings read, streams, and hourly files")
        (fun () ->
           H.check (not (exited ())) (name ^ ": the process exited");
           List.count (F.rest_requests fake) ~f:is_perp_dexs >= 1
           && List.length (F.rest_requests fake) >= 3
           && F.streamed fake ~conn:1 > 0
           && F.streamed fake ~conn:2 > 0
           && List.for_all [ "events"; "listings"; "trades" ] ~f:has_recording)
    in
    let%bind before = settled_fds ~pid in
    H.check
      (List.count (F.rest_requests fake) ~f:is_perp_dexs = 1
       && List.is_empty !stalled_times)
      (name ^ ": baseline was read after the second listings cycle started");
    stall_enabled := true;
    let%bind () =
      H.wait_until
        ~timeout_s:30.
        ~what:(name ^ ": first stalled listings request")
        (fun () ->
           H.check (not (exited ())) (name ^ ": the process exited");
           not (List.is_empty !stalled_times))
    in
    let first_stalled_at = List.last_exn !stalled_times in
    let%bind () =
      H.wait_until
        ~timeout_s:45.
        ~what:(name ^ ": first error event within 35 s")
        (fun () ->
           H.check (not (exited ())) (name ^ ": the process exited");
           not (List.is_empty (listings_errors ())))
    in
    let first_recv, first_reason = List.hd_exn (listings_errors ()) in
    H.check
      (first_recv >= first_stalled_at)
      (sprintf
         "%s: error event %d ms before the first stall"
         name
         (first_stalled_at - first_recv));
    H.check
      (first_recv - first_stalled_at <= 35_000)
      (sprintf
         "%s: first error event took %d ms, expected <= 35000 ms"
         name
         (first_recv - first_stalled_at));
    H.check (not (String.is_empty first_reason)) (name ^ ": error event has empty reason");
    let%bind () =
      H.wait_until
        ~timeout_s:300.
        ~what:(name ^ ": all stalled requests failed")
        (fun () ->
           H.check (not (exited ())) (name ^ ": the process exited");
           List.length !stalled_times >= stalls
           && List.length (listings_errors ()) >= stalls)
    in
    let%bind after_stalls = settled_fds ~pid in
    H.check
      (after_stalls <= before + 1)
      (sprintf
         "%s: open file count %d after %d stalled HTTPS requests, against %d before the \
          first"
         name
         after_stalls
         stalls
         before);
    let%bind status, _ = H.sigterm_and_wait process in
    H.check (Result.is_ok status) (name ^ ": exit status");
    return ())
;;

let () =
  H.main "item 19: TLS stalls on HTTPS listings requests" (fun () ->
    let scenarios =
      [ "TLS handshake stall", F.Stall_tls_handshake
      ; "before status line stall", F.Stall_before_status_line
      ; "chunked body stall", F.Stall_in_chunked_body
      ]
    in
    let%map failures =
      Deferred.List.filter_map scenarios ~how:`Parallel ~f:(fun (name, mode) ->
        match%map Monitor.try_with (fun () -> run_scenario ~name ~mode) with
        | Ok () -> None
        | Error exn -> Some (sprintf "[%s] %s" name (Exn.to_string exn)))
    in
    if not (List.is_empty failures) then failwith (String.concat ~sep:"\n" failures))
;;
