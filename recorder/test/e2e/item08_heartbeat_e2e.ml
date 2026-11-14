(* Item 8: after 30 s with nothing received a ping is sent, after 45 s the connection is reopened. The fake server
   stays silent: no acks, no pongs. Two connections (one deep, one fast), each
   checked. About 50 s. *)

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
    let%bind process = H.spawn_run ~root ~extra:[ "--connections"; "2" ] fake in
    let%bind () =
      H.wait_until ~timeout_s:70. ~what:"both connections reopened" (fun () -> List.length (F.accepts fake) >= 4)
    in
    let%bind status, _ = H.sigterm_and_wait process in
    H.check (Result.is_ok status) "exit status";
    let opened conn = List.Assoc.find_exn (F.accepts fake) ~equal:Int.equal conn in
    List.iter [ 1; 2 ] ~f:(fun conn ->
      let pings =
        List.filter_map (F.received fake) ~f:(fun (c, at, text) ->
          if c = conn && is_ping text then Some (at - opened conn) else None)
      in
      H.check (List.length pings = 1) (sprintf "%d pings on connection %d, expected 1" (List.length pings) conn);
      let ping = List.hd_exn pings in
      H.check (ping >= 29_000 && ping <= 33_000) (sprintf "connection %d: ping after %d ms, expected about 30000" conn ping));
    let first_opened = Int.min (opened 1) (opened 2) in
    List.iter [ 3; 4 ] ~f:(fun conn ->
      let reopened = opened conn - first_opened in
      H.check
        (reopened >= 44_000 && reopened <= 55_000)
        (sprintf "connection %d reopened after %d ms, expected about 45000 plus the backoff" conn reopened));
    F.stop fake)
;;
