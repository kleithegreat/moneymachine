(* VAULT.md test 11: stalled handshake. A request whose server accepts the connection and never completes the
   TLS handshake gives one [error] event with [timeout] within 35 s, and the run exits 1 with watermark
   unmoved. A control run over HTTPS with the trusted certificate succeeds. *)

open Core
open Async
module H = Rec_support.Harness
module F = Rec_support.Fake_hl
module V = Vault_harness

let support file = Filename_unix.realpath (Filename.concat "../support" file)
let now = V.nov 5 10 0

let healthy_https_control () =
  let root = H.tmp_dir () in
  let tls =
    { F.crt_file = support "tls_server.crt"; key_file = support "tls_server.key" }
  in
  let%bind fake = V.start ~tls () in
  V.add_fill fake ~tid:1 ~time:(V.nov 5 9 30) ~visible:true;
  let%bind outcome =
    V.run_with
      ~env:[ "SSL_CERT_FILE", support "tls_server.crt" ]
      ~timeout_s:30.
      ~root
      ~fake
      ~now_ms:now
      ()
  in
  V.check_exit outcome ~expected:0 "healthy HTTPS control run";
  H.check
    (List.equal Int.equal (V.stored_tids ~root) [ 1 ])
    "control HTTPS run must store the fill";
  H.check (V.watermark root = now) "control HTTPS run must advance the watermark";
  V.stop fake
;;

let stalled_tls_handshake () =
  let root = H.tmp_dir () in
  let%bind fake = V.start ~stall_tls_handshake:true () in
  let started = Time_ns.now () in
  let%bind outcome =
    Monitor.protect
      ~finally:(fun () -> V.stop fake)
      (fun () ->
         V.run_with
           ~env:[ "SSL_CERT_FILE", support "tls_server.crt" ]
           ~timeout_s:40.
           ~root
           ~fake
           ~now_ms:now
           ())
  in
  let elapsed = Time_ns.Span.to_sec (Time_ns.diff (Time_ns.now ()) started) in
  V.check_exit outcome ~expected:1 "stalled TLS handshake";
  H.check
    (Float.( <= ) elapsed 35.)
    (sprintf "stalled TLS handshake took %.2f s, expected <= 35 s" elapsed);
  H.check (fake.accepts >= 1) "fake never saw a TCP connection";
  H.check (fake.client_hellos >= 1) "fake never received a TLS ClientHello";
  let errors = V.named (V.last_run_events ~root) "error" in
  H.check
    (List.length errors = 1)
    (sprintf "expected 1 error event, got %d" (List.length errors));
  let err = List.hd_exn errors in
  let err_text = String.lowercase (Yojson.Safe.to_string err.V.json) in
  H.check
    (String.is_substring err_text ~substring:"timeout")
    (sprintf
       "error event does not mention timeout: %s"
       (Yojson.Safe.to_string err.V.json));
  H.check
    (V.watermark root = V.nov 1 0 0)
    "watermark must not move after stalled handshake";
  return ()
;;

let () =
  H.main "vault 11: stalled TLS handshake" (fun () ->
    H.run_all
      [ "healthy HTTPS control", healthy_https_control
      ; "11 stalled TLS handshake", stalled_tls_handshake
      ])
;;
