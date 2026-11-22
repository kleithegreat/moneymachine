(* Item 16: the hourly listings read is answered once, then the fake accepts the next listings request, starts its
   answer and never finishes it. The recorder gives an [error] event within 35 s of that request, keeps recording
   on its connections meanwhile, and retries: a further listings request arrives, which the fake answers. Uses the
   assumed flag --listings-interval-s to make the "hourly" read fast. *)

open Core
open Async
module H = Rec_support.Harness
module F = Rec_support.Fake_hl

let is_perp_dexs request =
  match Yojson.Safe.from_string request with
  | `Assoc fields ->
    Poly.equal
      (List.Assoc.find fields ~equal:String.equal "type")
      (Some (`String "perpDexs"))
  | _ -> false
  | exception Yojson.Json_error _ -> false
;;

let () =
  H.main "item 16: a stalled listings request is an error event and is retried" (fun () ->
    let perp_dexs_seen = ref 0 in
    let stalled_at = ref None in
    let rest = F.rest_of_universe (fun () -> [ "C0"; "C1" ]) in
    let rest_stall ~request =
      if is_perp_dexs request
      then (
        incr perp_dexs_seen;
        if !perp_dexs_seen = 2
        then (
          stalled_at := Some (H.now_ms ());
          true)
        else false)
      else false
    in
    let config =
      { F.default_config with
        rest
      ; rest_stall
      ; stream = Some (fun ~conn ~seq -> F.trades_frame ~coin:(sprintf "K%d" conn) ~seq)
      ; stream_interval_ms = 10
      }
    in
    let%bind fake = F.start config in
    let root = H.tmp_dir () in
    let%bind process =
      H.spawn_run ~root ~listings_interval_s:5 ~extra:[ "--connections"; "2" ] fake
    in
    let exited () = Deferred.is_determined (Process.wait process) in
    let error_events () =
      List.filter (H.events ~root) ~f:(fun (_, _, event, _) -> String.equal event "error")
    in
    let%bind () =
      H.wait_until ~timeout_s:30. ~what:"the listings request that stalls" (fun () ->
        Option.is_some !stalled_at)
    in
    let stalled_at = Option.value_exn !stalled_at in
    let%bind () =
      H.wait_until
        ~timeout_s:40.
        ~what:"an error event for the stalled listings request"
        (fun () ->
           H.check (not (exited ())) "the process exited";
           not (List.is_empty (error_events ())))
    in
    let first_recv, _, _, _ = List.hd_exn (error_events ()) in
    H.check
      (first_recv >= stalled_at)
      (sprintf
         "an error event %d ms before the stalled request"
         (stalled_at - first_recv));
    H.check
      (first_recv - stalled_at <= 35_000)
      (sprintf
         "the first error event came %d ms after the stalled request, more than 35 s"
         (first_recv - stalled_at));
    let streamed_at_error = F.streamed fake ~conn:2 in
    let%bind () =
      H.wait_until ~timeout_s:90. ~what:"a retried listings request" (fun () ->
        H.check (not (exited ())) "the process exited";
        List.count (F.rest_requests fake) ~f:is_perp_dexs >= 3)
    in
    let%bind () = after (Time_float.Span.of_sec 1.) in
    H.check (not (exited ())) "the process exited after the stall";
    H.check
      (F.streamed fake ~conn:2 > streamed_at_error)
      "the fake stopped streaming after the stalled request";
    let%bind status, _ = H.sigterm_and_wait process in
    H.check (Result.is_ok status) "exit status";
    H.check
      (not (List.is_empty (H.channel_lines ~root ~channel:"trades")))
      "nothing was recorded in trades";
    F.stop fake)
;;
