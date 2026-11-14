(* Item 14: a TLS failure (the fake presents a certificate the CA file does not trust) is an [error] event whose
   reason names the TLS failure, on every connection that meets it, within 5 s of the start. The control run
   trusts the fake's certificate and must connect, so that a broken fake cannot pass the first run. The recorder
   reads its CA file from SSL_CERT_FILE. *)

open Core
open Async
module H = Rec_support.Harness
module F = Rec_support.Fake_hl

let support file = Filename_unix.realpath (Filename.concat "../support" file)

let tls_fake () =
  let config =
    { F.default_config with
      rest = F.rest_of_universe (fun () -> [ "C0"; "C1"; "C2" ])
    ; tls = Some { F.crt_file = support "tls_server.crt"; key_file = support "tls_server.key" }
    }
  in
  F.start config
;;

let error_reasons ~root =
  List.filter_map (H.events ~root) ~f:(fun (recv, conn, name, msg) ->
    if String.equal name "error"
    then (
      match Yojson.Safe.Util.member "reason" msg with
      | `String reason -> Some (recv, conn, reason)
      | _ -> Some (recv, conn, ""))
    else None)
;;

let names_tls_failure reason =
  let lower = String.lowercase reason in
  List.exists [ "ssl"; "tls"; "certificate"; "verif" ] ~f:(fun word -> String.is_substring lower ~substring:word)
  && not (List.exists [ "timeout"; "timed out" ] ~f:(fun word -> String.is_substring lower ~substring:word))
;;

let () =
  H.main "item 14: a TLS failure is an error event naming it" (fun () ->
    let connections = 8 in
    let%bind fake = tls_fake () in
    let root = H.tmp_dir () in
    let started = H.now_ms () in
    let%bind process =
      H.spawn_run
        ~root
        ~env:[ "SSL_CERT_FILE", support "tls_unrelated_ca.pem" ]
        ~extra:[ "--connections"; Int.to_string connections ]
        fake
    in
    let%bind () = after (Time_float.Span.of_sec 6.) in
    let%bind status, _ = H.sigterm_and_wait process in
    H.check (Result.is_ok status) "exit status";
    let errors = error_reasons ~root in
    let first_per_conn =
      List.filter_map errors ~f:(fun (recv, conn, reason) -> Option.map conn ~f:(fun c -> c, recv, reason))
      |> List.sort ~compare:(fun (_, a, _) (_, b, _) -> Int.compare a b)
      |> List.fold ~init:(Map.empty (module Int)) ~f:(fun acc (conn, recv, reason) ->
        Map.add_multi acc ~key:conn ~data:(recv, reason))
    in
    H.check
      (Map.length first_per_conn = connections)
      (sprintf "error events on %d connections, expected %d" (Map.length first_per_conn) connections);
    Map.iteri first_per_conn ~f:(fun ~key:conn ~data ->
      let first_recv, _ = List.last_exn data in
      H.check (first_recv - started <= 5_000) (sprintf "conn %d: first error %d ms after the start" conn (first_recv - started));
      H.check
        (List.exists data ~f:(fun (_, reason) -> names_tls_failure reason))
        (sprintf "conn %d: no error reason names the TLS failure: %s" conn (String.concat ~sep:" | " (List.map data ~f:snd))));
    H.check (List.is_empty (F.accepts fake)) "a websocket was accepted despite the untrusted certificate";
    let%bind () = F.stop fake in
    let%bind fake = tls_fake () in
    let root = H.tmp_dir () in
    let%bind process =
      H.spawn_run
        ~root
        ~env:[ "SSL_CERT_FILE", support "tls_server.crt" ]
        ~extra:[ "--connections"; "2" ]
        fake
    in
    let%bind () =
      H.wait_until ~timeout_s:10. ~what:"control connections over TLS" (fun () ->
        List.length (F.accepts fake) >= 2)
    in
    let%bind status, _ = H.sigterm_and_wait process in
    H.check (Result.is_ok status) "control exit status";
    H.check (List.is_empty (error_reasons ~root)) "control run has error events";
    F.stop fake)
;;
