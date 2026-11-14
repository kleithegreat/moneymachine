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
    let%bind process = H.spawn_run ~root ~extra:[ "--connections"; "2" ] fake in
    let sent conn = F.subscribed_on fake ~conn in
    let sorted subs = List.sort subs ~compare:[%compare: string * string] in
    let%bind () =
      H.wait_until ~timeout_s:70. ~what:"a second generation of connections with its subscriptions" (fun () ->
        List.length (F.accepts fake) >= 4
        && List.length (sent 3) + List.length (sent 4) >= List.length (sent 1) + List.length (sent 2))
    in
    let%bind status, _ = H.sigterm_and_wait process in
    H.check (Result.is_ok status) "exit status";
    let opened conn = List.Assoc.find_exn (F.accepts fake) ~equal:Int.equal conn in
    let first_opened = Int.min (opened 1) (opened 2) in
    let second_opened = Int.min (opened 3) (opened 4) in
    let first_generation = sorted (sent 1 @ sent 2) in
    H.check
      (List.length first_generation = 7)
      (sprintf "%d subscriptions in the first generation, expected 7" (List.length first_generation));
    let unacked =
      List.filter (H.events ~root) ~f:(fun (recv, _, name, _) ->
        String.equal name "unacked" && recv < second_opened)
    in
    H.check
      (List.length unacked = 7)
      (sprintf "%d unacked events before the reconnect, expected one per subscription (7)" (List.length unacked));
    List.iter unacked ~f:(fun (recv, _, _, _) ->
      let after_open = recv - first_opened in
      H.check (after_open >= 29_000 && after_open <= 36_000) (sprintf "unacked %d ms after the connection opened" after_open));
    H.check
      (List.equal [%equal: string * string] first_generation (sorted (sent 3 @ sent 4)))
      "the unacknowledged subscriptions were not re-sent";
    F.stop fake)
;;
