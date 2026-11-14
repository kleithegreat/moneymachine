(* Item 10: SIGTERM flushes every buffer and exits within 10 s, and every file decompresses whole. *)

open Core
open Async
module H = Rec_support.Harness
module F = Rec_support.Fake_hl

let () =
  H.main "item 10: SIGTERM flushes and exits" (fun () ->
    let config =
      { F.default_config with
        rest = F.rest_of_universe (fun () -> [ "C0"; "C1"; "C2"; "C3" ])
      ; stream = Some (fun ~conn ~seq -> F.trades_frame ~coin:(sprintf "K%d" conn) ~seq)
      ; stream_interval_ms = 5
      }
    in
    let%bind fake = F.start config in
    let root = H.tmp_dir () in
    let%bind process = H.spawn_run ~root ~extra:[ "--connections"; "2" ] fake in
    let%bind () =
      H.wait_until ~timeout_s:30. ~what:"streaming" (fun () ->
        List.exists (F.accepts fake) ~f:(fun (conn, _) -> F.streamed fake ~conn >= 400))
    in
    (* Mid-second: the buffers hold frames that no tick has written. *)
    let%bind () = after (Time_float.Span.of_ms 350.) in
    let sent_before = List.map (F.accepts fake) ~f:(fun (conn, _) -> sprintf "K%d" conn, F.streamed fake ~conn) in
    let%bind status, seconds = H.sigterm_and_wait process in
    H.check (match status with Ok () | Error (`Exit_non_zero _) -> true | Error (`Signal _) -> false) "killed by a signal";
    H.check (Float.( <= ) seconds 10.) (sprintf "took %.1f s to exit" seconds);
    let files = H.recordings root in
    H.check (not (List.is_empty files)) "no recordings";
    List.iter files ~f:(fun path ->
      let decoded = Mmrec.Frames.decode (H.read_file path) in
      H.check (not decoded.truncated) (sprintf "%s ends in a cut frame" path);
      H.check (String.equal decoded.data (H.zstd_binary_decode path)) (sprintf "%s does not decompress whole" path);
      H.check
        (List.for_all (String.split_lines decoded.data) ~f:(fun line ->
           match Yojson.Safe.from_string line with
           | `Assoc _ -> true
           | _ -> false
           | exception _ -> false))
        (sprintf "%s holds a line that is not JSON" path));
    let events = List.map (H.events ~root) ~f:(fun (_, _, name, _) -> name) in
    H.check (List.mem events "stop" ~equal:String.equal) "no stop event";
    let recorded = H.contiguous_prefixes (H.trade_ids ~root) in
    List.iter recorded ~f:(fun (coin, m) ->
      let before = Option.value (List.Assoc.find sent_before ~equal:String.equal coin) ~default:0 in
      H.check (m + 30 >= before) (sprintf "%s: %d recorded, %d were sent before SIGTERM" coin m before));
    F.stop fake)
;;
