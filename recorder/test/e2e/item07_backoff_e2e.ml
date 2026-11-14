(* Item 7, second case: backoff follows 1, 2, 4 ... within jitter, observed on two connections as the times of
   their accepts, against a server that closes every connection 100 ms after accepting it. The windows of successive
   attempts (cumulative backoffs 1, 2, 4, 8, 16 s, +-20 %, plus 100 ms per close) do not overlap, so the sorted
   accepts group by attempt, two each. A constant 1 s backoff misses the window of attempt 3. About 35 s. *)

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
    let%bind process = H.spawn_run ~root ~extra:[ "--connections"; "2" ] fake in
    let%bind () =
      H.wait_until ~timeout_s:45. ~what:"six attempts on both connections" (fun () ->
        List.length (F.accepts fake) >= 12)
    in
    let%bind status, _ = H.sigterm_and_wait process in
    H.check (Result.is_ok status) "exit status";
    let times = List.map (F.accepts fake) ~f:snd |> List.sort ~compare:Int.compare in
    let start = List.hd_exn times in
    let bases = [ 1000; 2000; 4000; 8000; 16000 ] in
    List.iteri (List.take times 12) ~f:(fun i at ->
      let attempt = i / 2 in
      let before = List.take bases attempt in
      let sum f = List.sum (module Int) before ~f in
      let lo = sum (fun b -> Float.to_int (0.8 *. Float.of_int b) + 100) in
      let hi = sum (fun b -> Float.to_int (1.2 *. Float.of_int b) + 100) + 500 + (100 * attempt) in
      let since = at - start in
      H.check
        (since >= lo && since <= hi)
        (sprintf "accept %d (attempt %d) came %d ms after the first, expected within [%d, %d]" i attempt since lo hi));
    F.stop fake)
;;
