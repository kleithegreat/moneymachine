(* Item 7, third case (no more than 30 connections opened in any minute, even when every connection fails
   repeatedly) and item 9 (messages sent stay at or below 2,000 in any minute), under reconnect storms: 300 perps
   (601 subscriptions over 8 connections), every connection closed by the server 8 s after accept, which is
   about when it finishes subscribing. Runs 80 s.

   Windows are 59.9 s, not 60 s, to absorb millisecond jitter between the recorder's send and the server's
   receive; a limiter that keeps the stated bound by any margin passes. *)

open Core
open Async
module H = Rec_support.Harness
module F = Rec_support.Fake_hl

let window_ms = 59_900

let () =
  H.main "item 7 and 9: connection and message limits under churn" (fun () ->
    let coins = List.init 300 ~f:(sprintf "C%d") in
    let config =
      { F.default_config with
        rest = F.rest_of_universe (fun () -> coins)
      ; close_after_ms = (fun ~conn:_ -> Some 8000)
      }
    in
    let%bind fake = F.start config in
    let root = H.tmp_dir () in
    let%bind process = H.spawn_run ~root fake in
    let%bind () = after (Time_float.Span.of_sec 80.) in
    let%bind status, seconds = H.sigterm_and_wait process in
    H.check (Result.is_ok status) "exit status";
    H.check (Float.( < ) seconds 10.) "slow exit";
    let opens = List.map (F.accepts fake) ~f:snd in
    let sends = List.map (F.received fake) ~f:(fun (_, at, _) -> at) in
    H.check (List.length opens >= 25) (sprintf "only %d connections in 80 s: no churn to judge" (List.length opens));
    H.check (List.length sends >= 1500) (sprintf "only %d messages sent: no storm to judge" (List.length sends));
    let most_opens = H.max_in_window opens ~window_ms in
    H.check (most_opens <= 30) (sprintf "%d connections opened inside one minute" most_opens);
    let most_sends = H.max_in_window sends ~window_ms in
    H.check (most_sends <= 2000) (sprintf "%d messages sent inside one minute" most_sends);
    F.stop fake)
;;
