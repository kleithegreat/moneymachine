(* Item 20: errors after connecting stay reported. A websocket connection whose TLS session fails after its
   handshake (the fake sends a TLS fatal alert) gives an [error] event naming the TLS failure and reopens,
   within 5 s, while the process keeps running and recording on the other connection. *)

open Core
open Async
module H = Rec_support.Harness
module F = Rec_support.Fake_hl

let support file = Filename_unix.realpath (Filename.concat "../support" file)

let names_tls_failure reason =
  let lower = String.lowercase reason in
  List.exists [ "ssl"; "tls"; "alert"; "record" ] ~f:(fun word ->
    String.is_substring lower ~substring:word)
  && not
       (List.exists
          [ "timeout"; "timed out"; "no close"; "nothing received" ]
          ~f:(fun word -> String.is_substring lower ~substring:word))
;;

let reason_of msg =
  match Yojson.Safe.Util.member "reason" msg with
  | `String s -> s
  | _ -> ""
;;

let () =
  H.main "item 20: TLS errors after handshake stay reported" (fun () ->
    let config =
      { F.default_config with
        tls =
          Some
            { F.crt_file = support "tls_server.crt"; key_file = support "tls_server.key" }
      ; rest = F.rest_of_universe (fun () -> [ "C0"; "C1" ])
      ; stream = Some (fun ~conn ~seq -> F.trades_frame ~coin:(sprintf "K%d" conn) ~seq)
      ; stream_interval_ms = 20
      ; fault = (fun ~conn -> if conn = 1 then Some F.Tls_fatal_alert else None)
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
    let exited () = Deferred.is_determined (Process.wait process) in
    let ws_errors () =
      List.filter_map (H.events ~root) ~f:(fun (recv, conn, event, msg) ->
        if String.equal event "error"
        then Option.map conn ~f:(fun c -> recv, c, reason_of msg)
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
          ~timeout_s:15.
          ~what:"TLS fatal alert error event, reopen, and streaming"
          (fun () ->
             H.check (not (exited ())) "the process exited";
             Option.is_some (F.fault_at fake ~conn:1)
             && (not (List.is_empty (ws_errors ())))
             && List.length (F.accepts fake) >= 3
             && F.streamed fake ~conn:2 >= 50
             && F.streamed fake ~conn:3 >= 20)
      in
      let streamed_conn2 = F.streamed fake ~conn:2 in
      let%bind () = after (Time_float.Span.of_sec 1.) in
      H.check (not (exited ())) "the process exited after the TLS failure";
      H.check
        (F.streamed fake ~conn:2 > streamed_conn2)
        "the healthy connection stopped streaming";
      let%bind status, _ = H.sigterm_and_wait process in
      H.check (Result.is_ok status) "exit status";
      let alert_at = Option.value_exn (F.fault_at fake ~conn:1) in
      let err_recv, conn, reason = List.hd_exn (ws_errors ()) in
      H.check
        (err_recv >= alert_at)
        (sprintf "error event %d ms before alert" (alert_at - err_recv));
      H.check
        (err_recv - alert_at <= 5_000)
        (sprintf
           "error event arrived %d ms after alert, expected <= 5000 ms"
           (err_recv - alert_at));
      H.check
        (names_tls_failure reason)
        (sprintf "error reason does not name the TLS failure: %s" reason);
      let reopened_at =
        List.find_map (H.events ~root) ~f:(fun (r, c, event, _) ->
          if
            Option.equal Int.equal c (Some conn)
            && r > err_recv
            && String.equal event "open"
          then Some r
          else None)
      in
      let reopen_recv =
        Option.value_exn
          reopened_at
          ~message:(sprintf "connection %d did not reopen after its TLS error" conn)
      in
      H.check
        (reopen_recv - alert_at <= 5_000)
        (sprintf
           "connection %d reopened %d ms after alert, expected <= 5000 ms"
           conn
           (reopen_recv - alert_at));
      let trades_conns =
        List.filter_map (H.channel_lines ~root ~channel:"trades") ~f:(fun (_, c, _) -> c)
        |> List.dedup_and_sort ~compare:Int.compare
      in
      H.check
        (List.exists trades_conns ~f:(fun c -> c <> conn))
        "nothing recorded on the other connection";
      H.check
        (List.exists trades_conns ~f:(fun c -> c = conn))
        "nothing recorded on the reopened connection";
      return ()))
;;
