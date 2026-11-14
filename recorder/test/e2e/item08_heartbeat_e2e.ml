(* Item 8: after 30 s with nothing received a ping is sent, after 45 s the connection is reopened. The fake server
   stays silent: no acks, no pongs. About 50 s. *)

open Core
open Async
module H = Rec_support.Harness
module F = Rec_support.Fake_hl

let is_ping text =
  match Yojson.Safe.from_string text with
  | `Assoc fields -> Poly.equal (List.Assoc.find fields ~equal:String.equal "method") (Some (`String "ping"))
  | _ -> false
  | exception _ -> false
;;

let () =
  H.main "item 8: ping at 30 s, reopen at 45 s" (fun () ->
    let config =
      { F.default_config with
        rest = F.rest_of_universe (fun () -> [ "C0"; "C1" ])
      ; ack_subscriptions = false
      }
    in
    let%bind fake = F.start config in
    let root = H.tmp_dir () in
    let%bind process = H.spawn_run ~root ~extra:[ "--connections"; "1" ] fake in
    let%bind () =
      H.wait_until ~timeout_s:70. ~what:"a second connection" (fun () -> List.length (F.accepts fake) >= 2)
    in
    let%bind status, _ = H.sigterm_and_wait process in
    H.check (Result.is_ok status) "exit status";
    let opened_1 = List.Assoc.find_exn (F.accepts fake) ~equal:Int.equal 1 in
    let opened_2 = List.Assoc.find_exn (F.accepts fake) ~equal:Int.equal 2 in
    let pings =
      List.filter_map (F.received fake) ~f:(fun (conn, at, text) ->
        if conn = 1 && is_ping text then Some (at - opened_1) else None)
    in
    H.check (List.length pings = 1) (sprintf "%d pings on the first connection, expected 1" (List.length pings));
    let ping = List.hd_exn pings in
    H.check (ping >= 29_000 && ping <= 33_000) (sprintf "ping after %d ms, expected about 30000" ping);
    let reopened = opened_2 - opened_1 in
    H.check
      (reopened >= 44_000 && reopened <= 55_000)
      (sprintf "reopened after %d ms, expected about 45000 plus the backoff" reopened);
    F.stop fake)
;;
