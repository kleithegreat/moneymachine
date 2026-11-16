(* VAULT.md test 6: idempotence, and SIGKILL at random moments. Interface assumed: see vault_harness.ml.

   "Two runs at one now add nothing but events" is judged by identity: a page of duplicates is still stored and
   fees and orders are stored at every run (VAULT.md), so what must not change is the set of stored fill and
   funding identities, the watermark, and what each pull counts as new. *)

open Core
open Async
module H = Rec_support.Harness
module V = Vault_harness

let now = V.nov 5 12 0

let populated () =
  let%map fake = V.start () in
  for i = 0 to 2999 do
    V.add_fill fake ~tid:(i + 1) ~time:(V.nov 4 0 0 + (i * 1000)) ~visible:true
  done;
  for i = 0 to 299 do
    V.add_funding fake ~coin:"ETH" ~time:(V.nov 1 0 0 + (i * 30 * V.minute)) ~visible:true;
    V.add_funding fake ~coin:"BTC" ~time:(V.nov 1 0 0 + (i * 30 * V.minute)) ~visible:true
  done;
  fake
;;

let idempotent () =
  let root = H.tmp_dir () in
  let%bind fake = populated () in
  let%bind first = V.run ~root ~fake ~now_ms:now in
  V.check_exit first ~expected:0 "first run";
  let tids = V.stored_tids ~root in
  let funding = V.stored_funding ~root in
  H.check (List.length tids = 3000 && List.length funding = 600) "the first run must store everything";
  let%bind second = V.run ~root ~fake ~now_ms:now in
  V.check_exit second ~expected:0 "second run at the same now";
  H.check (List.equal Int.equal tids (V.stored_tids ~root)) "the second run changed the stored fills";
  H.check
    (List.equal [%equal: string * int] funding (V.stored_funding ~root))
    "the second run changed the stored funding rows";
  H.check (V.watermark root = now) "the watermark must stay at now";
  let events = V.last_run_events ~root in
  H.check
    (V.new_total events ~kind:"fills" = 0 && V.new_total events ~kind:"funding" = 0)
    "the second run must count nothing new";
  H.check (List.length (V.named events "stop") = 1) "the second run must end with a stop event";
  V.stop fake
;;

let kills () =
  let root = H.tmp_dir () in
  let%bind fake = populated () in
  let seed = Time_ns.to_int_ns_since_epoch (Time_ns.now ()) in
  Random.init seed;
  let%bind () =
    Deferred.List.iter (List.init 8 ~f:Fn.id) ~how:`Sequential ~f:(fun i ->
      let%bind process = V.spawn ~root ~fake ~now_ms:now in
      let wait_ms = Random.float_range 0. 11_000. in
      let%bind () = after (Time_float.Span.of_ms wait_ms) in
      let%bind () = V.kill process in
      V.check_integrity ~root (sprintf "after kill %d (seed %d, waited %.0f ms)" i seed wait_ms);
      return ())
  in
  let stored_before = List.length (V.stored_tids ~root) in
  let funding_before = List.length (V.stored_funding ~root) in
  let%bind final = V.run ~root ~fake ~now_ms:now in
  V.check_exit final ~expected:0 (sprintf "the run after the kills (seed %d)" seed);
  V.check_integrity ~root "after the final run";
  H.check
    (List.length (V.stored_tids ~root) = 3000)
    (sprintf "a fill was lost (seed %d)" seed);
  H.check
    (List.length (V.stored_funding ~root) = 600)
    (sprintf "a funding row was lost (seed %d)" seed);
  let events = V.last_run_events ~root in
  H.check
    (V.new_total events ~kind:"fills" = 3000 - stored_before)
    (sprintf "the final run must count as new exactly the fills not stored before (seed %d)" seed);
  H.check
    (V.new_total events ~kind:"funding" = 600 - funding_before)
    (sprintf "the final run must count as new exactly the funding rows not stored before (seed %d)" seed);
  H.check (V.watermark root = now) "the watermark must end at now";
  let%bind again = V.run ~root ~fake ~now_ms:now in
  V.check_exit again ~expected:0 "run after the final run";
  H.check
    (V.new_total (V.last_run_events ~root) ~kind:"fills" = 0)
    "a run after a completed run must count nothing new";
  V.stop fake
;;

let () = H.main "vault kills" (fun () -> H.run_all [ "6 idempotence", idempotent; "6 kills", kills ])
