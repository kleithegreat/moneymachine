(* Item 17: connects that fail TLS's host check leave the recorder process's open file count where it was. The
   fake presents a certificate for 127.0.0.1 that the CA file trusts, and the recorder is given the URL
   wss://localhost:<port>/..., a name the certificate does not carry.

   Each counted error must name the host-check failure, and the test waits until at least [connections]
   host-check error events are recorded and the open file descriptor count settles rather than sleeping for a
   fixed duration. A control run using 127.0.0.1 verifies the certificate is accepted when the host matches. *)

open Core
open Async
module H = Rec_support.Harness
module F = Rec_support.Fake_hl

let support file = Filename_unix.realpath (Filename.concat "../support" file)

let open_fds ~pid =
  Array.length (Stdlib.Sys.readdir (sprintf "/proc/%d/fd" (Pid.to_int pid)))
;;

let reason_of msg =
  match Yojson.Safe.Util.member "reason" msg with
  | `String s -> s
  | _ -> ""
;;

let names_host_check reason =
  let lower = String.lowercase reason in
  List.exists [ "host"; "hostname"; "mismatch"; "did not match" ] ~f:(fun word ->
    String.is_substring lower ~substring:word)
  && not
       (List.exists [ "timeout"; "timed out"; "refused" ] ~f:(fun word ->
          String.is_substring lower ~substring:word))
;;

let host_check_errors ~root =
  List.filter_map (H.events ~root) ~f:(fun (_, conn, name, msg) ->
    if String.equal name "error"
    then (
      let reason = reason_of msg in
      if Option.is_some conn && names_host_check reason then Some reason else None)
    else None)
;;

let all_errors ~root =
  List.filter_map (H.events ~root) ~f:(fun (_, _, name, msg) ->
    if String.equal name "error" then Some (reason_of msg) else None)
;;

let sample_min ~pid =
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

let settled_fds ~pid =
  let deadline = Time_ns.add (Time_ns.now ()) (Time_ns.Span.of_sec 30.) in
  let rec loop prev =
    let%bind cur = sample_min ~pid in
    if Option.equal Int.equal prev (Some cur)
    then return cur
    else if Time_ns.( > ) (Time_ns.now ()) deadline
    then failwithf "open file count did not settle (last sample %d)" cur ()
    else loop (Some cur)
  in
  loop None
;;

let failing_run ~connections =
  let config =
    { F.default_config with
      rest = F.rest_of_universe (fun () -> [ "C0"; "C1"; "C2" ])
    ; tls =
        Some
          { F.crt_file = support "tls_server.crt"; key_file = support "tls_server.key" }
    }
  in
  let%bind fake = F.start config in
  let root = H.tmp_dir () in
  let%bind process =
    Process.create_exn
      ~prog:H.mmrec_exe
      ~args:
        [ "run"
        ; root
        ; "--ws-url"
        ; String.substr_replace_first
            (F.ws_url fake)
            ~pattern:"127.0.0.1"
            ~with_:"localhost"
        ; "--rest-url"
        ; F.rest_url fake
        ; "--connections"
        ; Int.to_string connections
        ]
      ~env:(`Extend [ "SSL_CERT_FILE", support "tls_server.crt" ])
      ()
  in
  don't_wait_for (Reader.drain (Process.stdout process));
  don't_wait_for (Reader.drain (Process.stderr process));
  let exited () = Deferred.is_determined (Process.wait process) in
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
        ~timeout_s:60.
        ~what:
          (sprintf "%d host-check error events (%d connections)" connections connections)
        (fun () ->
           H.check (not (exited ())) "the process exited";
           List.length (host_check_errors ~root) >= connections)
    in
    let%bind fds = settled_fds ~pid:(Process.pid process) in
    let%bind status, _ = H.sigterm_and_wait process in
    H.check (Result.is_ok status) "exit status";
    H.check
      (List.is_empty (F.accepts fake))
      "a websocket was accepted despite the host check";
    List.iter (all_errors ~root) ~f:(fun reason ->
      H.check
        (names_host_check reason)
        (sprintf "error event does not name host-check failure: %s" reason));
    return (fds, List.length (host_check_errors ~root)))
;;

let matching_host_control () =
  let config =
    { F.default_config with
      rest = F.rest_of_universe (fun () -> [ "C0"; "C1"; "C2" ])
    ; tls =
        Some
          { F.crt_file = support "tls_server.crt"; key_file = support "tls_server.key" }
    }
  in
  let%bind fake = F.start config in
  let root = H.tmp_dir () in
  let%bind process =
    H.spawn_run
      ~root
      ~env:[ "SSL_CERT_FILE", support "tls_server.crt" ]
      ~extra:[ "--connections"; "2" ]
      fake
  in
  let%bind () =
    H.wait_until
      ~timeout_s:10.
      ~what:"control run connects over TLS when host matches"
      (fun () -> List.length (F.accepts fake) >= 2)
  in
  let%bind status, _ = H.sigterm_and_wait process in
  H.check (Result.is_ok status) "control exit status";
  H.check (List.is_empty (all_errors ~root)) "control run has error events";
  F.stop fake
;;

let () =
  H.main "item 17: failed TLS host checks leak no sockets" (fun () ->
    let%bind () = matching_host_control () in
    let%bind few_fds, few_errors = failing_run ~connections:2 in
    let%bind many_fds, many_errors = failing_run ~connections:20 in
    H.check
      (few_errors >= 2)
      (sprintf "the run with 2 connections had %d host-check error events" few_errors);
    H.check
      (many_errors >= 20)
      (sprintf
         "the run with 20 connections had %d host-check error events, expected >= 20"
         many_errors);
    H.check
      (many_fds <= few_fds + 3)
      (sprintf
         "open file count %d after %d host-check failures (20 connections), against %d \
          after %d (2 connections)"
         many_fds
         many_errors
         few_fds
         few_errors);
    return ())
;;
