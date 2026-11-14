(* Item 11, second case: after a kill -9 and a restart, [mmrec check] gives a gap for every connection that was open
   at the kill, from that connection's last received line (the last line on disk) to its first [open] of the next
   run. *)

open Core
open Async
module H = Rec_support.Harness
module F = Rec_support.Fake_hl

let config =
  { F.default_config with
    rest = F.rest_of_universe (fun () -> [ "C0"; "C1"; "C2"; "C3" ])
  ; stream = Some (fun ~conn ~seq -> F.trades_frame ~coin:(sprintf "K%d" conn) ~seq)
  ; stream_interval_ms = 5
  }
;;

let () =
  H.main "item 11: gaps after a kill" (fun () ->
    let%bind fake = F.start config in
    let root = H.tmp_dir () in
    let started = H.now_ms () in
    let%bind run1 = H.spawn_run ~root ~extra:[ "--connections"; "2" ] fake in
    let%bind () =
      H.wait_until ~timeout_s:30. ~what:"both connections streaming" (fun () ->
        List.length (F.accepts fake) >= 2
        && List.for_all (F.accepts fake) ~f:(fun (conn, _) -> F.streamed fake ~conn >= 300))
    in
    let%bind () = after (Time_float.Span.of_sec 3.) in
    H.send_signal run1 Signal.kill;
    let%bind _ = Process.wait run1 in
    let first_run_lines = H.all_lines ~root in
    let conns =
      List.filter_map first_run_lines ~f:(fun (_, _, conn, _) -> conn) |> List.dedup_and_sort ~compare:Int.compare
    in
    H.check (List.length conns = 2) (sprintf "lines of %d connections in the first run, expected 2" (List.length conns));
    let last_line conn =
      List.filter_map first_run_lines ~f:(fun (_, recv, c, _) ->
        if Option.equal Int.equal c (Some conn) then Some recv else None)
      |> List.max_elt ~compare:Int.compare
      |> Option.value_exn
    in
    let%bind () = after (Time_float.Span.of_sec 1.2) in
    let%bind run2 = H.spawn_run ~root ~extra:[ "--connections"; "2" ] fake in
    let kill_time = H.now_ms () in
    let reopened conn =
      List.find_map (H.events ~root) ~f:(fun (recv, c, name, _) ->
        if Option.equal Int.equal c (Some conn) && String.equal name "open" && recv > last_line conn
        then Some recv
        else None)
    in
    let%bind () =
      H.wait_until ~timeout_s:30. ~what:"every connection opened again by the second run" (fun () ->
        List.for_all conns ~f:(fun conn -> Option.is_some (reopened conn)))
    in
    let%bind status, _ = H.sigterm_and_wait run2 in
    H.check (Result.is_ok status) "second run's exit status";
    let from_ = H.hour_of_ms (started - 3_600_000) in
    let to_ = H.hour_of_ms (H.now_ms () + 3_600_000) in
    let%bind _, out = H.run_cli [ "check"; root; from_; to_ ] in
    let gaps =
      List.filter_map (H.parse_check out) ~f:(function
        | [ "gap"; conn; from_ms; to_ms ] -> Some (Int.of_string conn, Int.of_string from_ms, to_ms)
        | _ -> None)
    in
    List.iter conns ~f:(fun conn ->
      let from_ms = last_line conn in
      let matching = List.filter gaps ~f:(fun (c, f, _) -> c = conn && f = from_ms) in
      match matching with
      | [ (_, _, to_ms) ] ->
        let expected = Option.value_exn (reopened conn) in
        H.check
          (String.equal to_ms (Int.to_string expected))
          (sprintf "conn %d: gap runs to %s, its next open is at %d" conn to_ms expected)
      | _ ->
        failwithf
          "conn %d: no single gap from its last line at %d (killed about %d); check printed:\n%s"
          conn
          from_ms
          kill_time
          out
          ());
    F.stop fake)
;;
