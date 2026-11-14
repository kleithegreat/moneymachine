(* Item 15: a connection's failure stays in its connection. For each way the fake can misbehave on its first
   connection (closing or resetting during the websocket handshake, answering the upgrade with a status other than 101, resetting
   mid-frame), that connection gives an [error] event naming what happened and reopens, while the process keeps
   running and keeps recording on the other connection. *)

open Core
open Async
module H = Rec_support.Harness
module F = Rec_support.Fake_hl

let lower_contains reason words =
  let lower = String.lowercase reason in
  List.exists words ~f:(fun word -> String.is_substring lower ~substring:word)
;;

let support file = Filename_unix.realpath (Filename.concat "../support" file)

let scenario ~name ~fault ~names_it ~tls () =
  let config =
    { F.default_config with
      tls = (if tls then Some { F.crt_file = support "tls_server.crt"; key_file = support "tls_server.key" } else None)
    ; rest = F.rest_of_universe (fun () -> [ "C0"; "C1"; "C2"; "C3" ])
    ; stream = Some (fun ~conn ~seq -> F.trades_frame ~coin:(sprintf "K%d" conn) ~seq)
    ; stream_interval_ms = 10
    ; fault = (fun ~conn -> if conn = 1 then Some fault else None)
    }
  in
  let%bind fake = F.start config in
  let root = H.tmp_dir () in
  let env = if tls then [ "SSL_CERT_FILE", support "tls_server.crt" ] else [] in
  let%bind process = H.spawn_run ~root ~env ~extra:[ "--connections"; "2" ] fake in
  let exited () = Deferred.is_determined (Process.wait process) in
  let error_events () =
    List.filter (H.events ~root) ~f:(fun (_, _, event, _) -> String.equal event "error")
  in
  let%bind () =
    H.wait_until ~timeout_s:60. ~what:(name ^ ": an error event, a reconnect, and the other connection streaming") (fun () ->
      H.check (not (exited ())) (name ^ ": the process exited");
      List.length (F.accepts fake) >= 3 && F.streamed fake ~conn:2 >= 100 && not (List.is_empty (error_events ())))
  in
  H.check (not (exited ())) (name ^ ": the process exited");
  let streamed_before = F.streamed fake ~conn:2 in
  let%bind () = after (Time_float.Span.of_sec 2.) in
  H.check (not (exited ())) (name ^ ": the process exited after the failure");
  H.check (F.streamed fake ~conn:2 > streamed_before) (name ^ ": the fake stopped streaming on the healthy connection");
  let%bind status, _ = H.sigterm_and_wait process in
  H.check (Result.is_ok status) (name ^ ": exit status");
  let errors = error_events () in
  let recv, conn, _, msg = List.hd_exn errors in
  let conn = Option.value_exn conn in
  let reason =
    match Yojson.Safe.Util.member "reason" msg with
    | `String reason -> reason
    | _ -> ""
  in
  H.check (not (String.is_empty reason)) (name ^ ": the error event has no reason");
  H.check (names_it reason) (sprintf "%s: the reason does not name what happened: %s" name reason);
  let reopened =
    List.exists (H.events ~root) ~f:(fun (r, c, event, _) ->
      Option.equal Int.equal c (Some conn) && r > recv && String.equal event "open")
  in
  H.check reopened (sprintf "%s: connection %d did not reopen after its error" name conn);
  let trades_conns =
    List.filter_map (H.channel_lines ~root ~channel:"trades") ~f:(fun (_, c, _) -> c) |> List.dedup_and_sort ~compare:Int.compare
  in
  H.check (List.exists trades_conns ~f:(fun c -> c <> conn)) (name ^ ": nothing recorded on the other connection");
  F.stop fake
;;

let () =
  H.main "item 15: failures stay in their connection" (fun () ->
    let handshake_close reason = lower_contains reason [ "handshake"; "eof"; "closed"; "close" ] in
    let status code reason = lower_contains reason [ Int.to_string code ] in
    let mid_frame reason = lower_contains reason [ "reset"; "eof"; "closed"; "frame"; "connection" ] in
    H.run_all
      [ ( "close in the handshake"
        , scenario ~name:"close in the handshake" ~fault:F.Close_in_handshake ~names_it:handshake_close ~tls:false )
      ; ( "close in the middle of the 101 response"
        , scenario ~name:"close in the middle of the 101 response" ~fault:F.Partial_response ~names_it:handshake_close ~tls:false )
      ; ( "reset in the handshake"
        , scenario ~name:"reset in the handshake" ~fault:F.Reset_in_handshake ~names_it:mid_frame ~tls:false )
      ; ( "403 to the upgrade"
        , scenario ~name:"403 to the upgrade" ~fault:(F.Answer_with 403) ~names_it:(status 403) ~tls:false )
      ; ( "200 to the upgrade"
        , scenario ~name:"200 to the upgrade" ~fault:(F.Answer_with 200) ~names_it:(status 200) ~tls:false )
      ; "reset mid-frame", scenario ~name:"reset mid-frame" ~fault:F.Reset_mid_frame ~names_it:mid_frame ~tls:false
      ; ( "close in the handshake over TLS"
        , scenario ~name:"close in the handshake over TLS" ~fault:F.Close_in_handshake ~names_it:handshake_close ~tls:true )
      ; ( "403 to the upgrade over TLS"
        , scenario ~name:"403 to the upgrade over TLS" ~fault:(F.Answer_with 403) ~names_it:(status 403) ~tls:true )
      ])
;;
