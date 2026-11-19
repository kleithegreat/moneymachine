(* Item 17: connects that fail TLS's host check leave the recorder process's open file count where it was. The
   fake presents a certificate for 127.0.0.1 that the CA file trusts, and the recorder is given the URL
   wss://localhost:<port>/..., a name the certificate does not carry.

   The count of /proc/<pid>/fd is what a process that has made few failed connects holds, read of a run with 2
   connections; a run with 20 connections makes twenty or more failed connects (at most 30 a minute), and its count
   must be no more than that, within a little slack. Each reading is the least of several samples, so a connect in
   flight at that moment does not count. *)

open Core
open Async
module H = Rec_support.Harness
module F = Rec_support.Fake_hl

let support file = Filename_unix.realpath (Filename.concat "../support" file)
let open_fds ~pid = Array.length (Stdlib.Sys.readdir (sprintf "/proc/%d/fd" (Pid.to_int pid)))

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

(* Runs the recorder with this many connections against the fake, all failing the host check; returns the settled
   open file count after [seconds], and how many error events it recorded. *)
let failing_run ~connections ~seconds =
  let config =
    { F.default_config with
      rest = F.rest_of_universe (fun () -> [ "C0"; "C1"; "C2" ])
    ; tls = Some { F.crt_file = support "tls_server.crt"; key_file = support "tls_server.key" }
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
        ; String.substr_replace_first (F.ws_url fake) ~pattern:"127.0.0.1" ~with_:"localhost"
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
  let%bind () = after (Time_float.Span.of_sec seconds) in
  let%bind fds = settled_fds ~pid:(Process.pid process) in
  let%bind status, _ = H.sigterm_and_wait process in
  H.check (Result.is_ok status) "exit status";
  H.check (List.is_empty (F.accepts fake)) "a websocket was accepted despite the host check";
  let errors = List.count (H.events ~root) ~f:(fun (_, _, name, _) -> String.equal name "error") in
  let%map () = F.stop fake in
  fds, errors
;;

let () =
  H.main "item 17: failed TLS host checks leak no sockets" (fun () ->
    let%bind few_fds, few_errors = failing_run ~connections:2 ~seconds:5. in
    let%bind many_fds, many_errors = failing_run ~connections:20 ~seconds:5. in
    H.check (few_errors >= 2) (sprintf "the run with 2 connections had %d error events" few_errors);
    H.check (many_errors >= 20) (sprintf "the run with 20 connections had %d error events, expected 20" many_errors);
    H.check
      (many_fds <= few_fds + 3)
      (sprintf
         "open file count %d after %d failed connects (20 connections), against %d after %d (2 connections)"
         many_fds
         many_errors
         few_fds
         few_errors);
    return ())
;;
