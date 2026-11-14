(* Item 4, third case: kill -9 during writing leaves a file whose complete frames all decompress. *)

open Core
open Async
module H = Rec_support.Harness
module F = Rec_support.Fake_hl

let () =
  H.main "item 4: kill -9 during writing" (fun () ->
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
      H.wait_until ~timeout_s:30. ~what:"2.5 s of streaming" (fun () ->
        List.exists (F.accepts fake) ~f:(fun (conn, _) -> F.streamed fake ~conn >= 500))
    in
    H.send_signal process Signal.kill;
    let%bind status = Process.wait process in
    H.check
      (match status with
       | Error (`Signal s) -> Signal.equal s Signal.kill
       | _ -> false)
      "the process was not killed";
    let sent = List.map (F.accepts fake) ~f:(fun (conn, _) -> sprintf "K%d" conn, F.streamed fake ~conn) in
    let files = H.recordings root in
    H.check (not (List.is_empty files)) "no recordings";
    List.iter files ~f:(fun path ->
      let raw = H.read_file path in
      let decoded = Mmrec.Frames.decode raw in
      H.check (decoded.complete_bytes <= String.length raw) "complete_bytes";
      H.check (Bool.equal decoded.truncated (decoded.complete_bytes < String.length raw)) "truncated flag";
      let whole = Filename.concat (H.tmp_dir ()) "whole.jsonl.zst" in
      Out_channel.write_all whole ~data:(String.prefix raw decoded.complete_bytes);
      H.check (String.equal decoded.data (H.zstd_binary_decode whole)) "complete frames decompress");
    let lines_ok =
      List.for_all files ~f:(fun path ->
        let decoded = Mmrec.Frames.decode (H.read_file path) in
        String.is_empty decoded.data
        || (String.is_suffix decoded.data ~suffix:"\n"
            && List.for_all (String.split_lines decoded.data) ~f:(fun line ->
              match Yojson.Safe.from_string line with
              | `Assoc _ -> true
              | _ -> false
              | exception _ -> false)))
    in
    H.check lines_ok "a complete frame holds a line that is not whole JSON";
    let recorded = H.contiguous_prefixes (H.trade_ids ~root) in
    H.check (not (List.is_empty recorded)) "no trades recorded";
    List.iter recorded ~f:(fun (coin, m) ->
      let total = Option.value (List.Assoc.find sent ~equal:String.equal coin) ~default:0 in
      H.check (m >= 100) (sprintf "%s: only %d recorded" coin m);
      H.check (total - m <= 300) (sprintf "%s: lost %d of %d, more than the unflushed second" coin (total - m) total));
    F.stop fake)
;;
