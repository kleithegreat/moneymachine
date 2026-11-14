(* Item 12: a subscription the fake never acknowledges gives one [unacked] event 30 s after it was sent, and is
   re-sent on that connection's next reconnect. The fake is silent, so the connection is reopened at 45 s by the
   heartbeat rule (item 8). About 50 s. *)

open Core
open Async
module H = Rec_support.Harness
module F = Rec_support.Fake_hl

let () =
  H.main "item 12: unacked after 30 s, re-sent on reconnect" (fun () ->
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
      H.wait_until ~timeout_s:70. ~what:"a second connection with its subscriptions" (fun () ->
        List.length (F.accepts fake) >= 2
        && List.length (F.subscribed_on fake ~conn:2) >= List.length (F.subscribed_on fake ~conn:1))
    in
    let%bind status, _ = H.sigterm_and_wait process in
    H.check (Result.is_ok status) "exit status";
    let opened_1 = List.Assoc.find_exn (F.accepts fake) ~equal:Int.equal 1 in
    let opened_2 = List.Assoc.find_exn (F.accepts fake) ~equal:Int.equal 2 in
    let sent_1 = F.subscribed_on fake ~conn:1 in
    H.check (List.length sent_1 = 5) (sprintf "%d subscriptions on the first connection, expected 5" (List.length sent_1));
    let unacked = List.filter (H.events ~root) ~f:(fun (recv, _, name, _) -> String.equal name "unacked" && recv < opened_2) in
    H.check
      (List.length unacked = List.length sent_1)
      (sprintf "%d unacked events before the reconnect, expected one per subscription (%d)" (List.length unacked) (List.length sent_1));
    List.iter unacked ~f:(fun (recv, _, _, _) ->
      let after_open = recv - opened_1 in
      H.check (after_open >= 29_000 && after_open <= 36_000) (sprintf "unacked %d ms after the connection opened" after_open));
    let sorted conn = List.sort (F.subscribed_on fake ~conn) ~compare:[%compare: string * string] in
    H.check (List.equal [%equal: string * string] (sorted 1) (sorted 2)) "the unacknowledged subscriptions were not re-sent";
    F.stop fake)
;;
