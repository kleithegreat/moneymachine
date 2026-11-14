(* Item 7, second case: backoff follows 1, 2, 4 ... within jitter, observed as the gaps between accepts of a
   server that closes every connection 100 ms after accepting it. About 35 s. *)

open Core
open Async
module H = Rec_support.Harness
module F = Rec_support.Fake_hl

let () =
  H.main "item 7: backoff 1, 2, 4, 8, 16 s within jitter" (fun () ->
    let config =
      { F.default_config with
        rest = F.rest_of_universe (fun () -> [ "C0" ])
      ; close_after_ms = (fun ~conn:_ -> Some 100)
      }
    in
    let%bind fake = F.start config in
    let root = H.tmp_dir () in
    let%bind process = H.spawn_run ~root ~extra:[ "--connections"; "1" ] fake in
    let%bind () =
      H.wait_until ~timeout_s:45. ~what:"six connections" (fun () -> List.length (F.accepts fake) >= 6)
    in
    let%bind status, _ = H.sigterm_and_wait process in
    H.check (Result.is_ok status) "exit status";
    let times = List.map (F.accepts fake) ~f:snd in
    let gaps = List.map2_exn (List.drop_last_exn times) (List.tl_exn times) ~f:(fun a b -> b - a) in
    let bases = [ 1000; 2000; 4000; 8000; 16000 ] in
    List.iteri (List.zip_exn (List.take gaps 5) bases) ~f:(fun i (gap, base) ->
      let lo = Float.to_int (0.8 *. Float.of_int base) in
      let hi = Float.to_int (1.2 *. Float.of_int base) + 100 + 500 in
      H.check
        (gap >= lo && gap <= hi)
        (sprintf "gap %d was %d ms, expected within [%d, %d]" i gap lo hi));
    F.stop fake)
;;
