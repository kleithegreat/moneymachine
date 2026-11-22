(* VAULT.md tests 1 to 5 and 8: paging, overlap, late fills, a stuck page, funding, the alarm. Interface assumed:
   see vault_harness.ml (the executable [mmvault run ROOT --user ADDRESS --rest-url URL --now-ms MS], the fake's
   API, state.json's ["watermark_ms"], the events' fields).

   Test 1 asserts the first two pages hold the cap and the third is shorter, not that it holds exactly 500: the
   spec's inclusive restart repeats the last item of a page, so 4,500 fills come as 2,000, 2,000 and 502. *)

open Core
open Async
module H = Rec_support.Harness
module V = Vault_harness

let fills_requests fake = V.requests fake ~kind:"userFillsByTime"
let funding_requests fake = V.requests fake ~kind:"userFunding"

let add_fills fake ~first_tid ~count ~time =
  for i = 0 to count - 1 do
    V.add_fill fake ~tid:(first_tid + i) ~time:(time i) ~visible:true
  done
;;

let paging () =
  let now = V.nov 3 12 0 in
  let root = H.tmp_dir () in
  let watermarks_seen = ref [] in
  let%bind fake =
    V.start
      ~on_request:(fun ~request_start:_ ~kind ->
        if String.equal kind "userFillsByTime"
        then watermarks_seen := V.watermark root :: !watermarks_seen)
      ()
  in
  let time i = V.nov 2 0 0 + (i * 1000) in
  add_fills fake ~first_tid:1 ~count:4500 ~time;
  let%bind outcome = V.run ~root ~fake ~now_ms:now in
  V.check_exit outcome ~expected:0 "paging run";
  let first_three = List.take (fills_requests fake) 3 in
  H.check (List.length first_three = 3) "fewer than three fills requests";
  let starts = List.map first_three ~f:(fun r -> Option.value_exn r.V.start_ms) in
  H.check
    (List.equal Int.equal starts [ V.nov 1 0 0; time 1999; time 3998 ])
    "pages must start at the watermark, then at the last time of the page before, \
     inclusive";
  H.check
    (List.for_all first_three ~f:(fun r -> Option.equal Int.equal r.V.end_ms (Some now)))
    "every hourly page must end at now";
  let sizes = List.map first_three ~f:(fun r -> r.V.returned) in
  H.check
    (match sizes with
     | [ a; b; c ] -> a = V.fills_cap && b = V.fills_cap && c < V.fills_cap
     | _ -> false)
    "the pages must be two at the cap, then a shorter one";
  let request_shape = (List.hd_exn first_three).V.body in
  H.check
    (String.equal
       (Yojson.Safe.Util.to_string (Yojson.Safe.Util.member "user" request_shape))
       V.user
     && Yojson.Safe.equal
          (Yojson.Safe.Util.member "aggregateByTime" request_shape)
          (`Bool false))
    "the request must name the user and aggregateByTime false";
  let before_last_page = List.take (List.rev !watermarks_seen) 3 in
  H.check
    (List.for_all before_last_page ~f:(fun w -> w < now))
    "the watermark must not move before the last page has been requested";
  H.check (V.watermark root = now) "the watermark must be now after the pull completed";
  H.check (List.length (V.stored_tids ~root) = 4500) "every fill must be stored";
  let events = V.last_run_events ~root in
  let hourly = List.hd_exn (V.pulls events ~kind:"fills") in
  H.check (V.field_int hourly "pages" = 3) "the hourly fills pull must be three pages";
  H.check (V.field_int hourly "new" = 4500) "the hourly pull must count 4500 new fills";
  H.check
    (V.new_total events ~kind:"fills" = 4500)
    "every fill must be counted new exactly once in the run";
  V.stop fake
;;

let overlap () =
  let root = H.tmp_dir () in
  let%bind fake = V.start () in
  V.add_fill fake ~tid:1 ~time:(V.nov 5 9 30) ~visible:false;
  let%bind first = V.run ~root ~fake ~now_ms:(V.nov 5 10 0) in
  V.check_exit first ~expected:0 "first run";
  H.check
    (List.is_empty (V.stored_tids ~root))
    "the fill was not indexed at the first run";
  V.reveal fake;
  V.forget_requests fake;
  let%bind second = V.run ~root ~fake ~now_ms:(V.nov 5 10 5) in
  V.check_exit second ~expected:0 "second run";
  let first_request = List.hd_exn (fills_requests fake) in
  H.check
    (Option.equal Int.equal first_request.V.start_ms (Some (V.nov 5 9 0)))
    "the hourly pull must start one hour before the watermark";
  H.check
    (List.equal Int.equal (V.stored_tids ~root) [ 1 ])
    "the fill 30 minutes before the watermark must be stored";
  H.check (V.new_total (V.last_run_events ~root) ~kind:"fills" = 1) "and counted new";
  V.stop fake
;;

(* A fill dated 2026-11-02 00:30, first indexed [days_late] days later. A run lies between: the daily re-read of
   the day before the fill appears, so the watermark is near now whichever way "30 days before the watermark" is
   read. *)
let late_fill ~days_late ~before_reveal ~reveal_run ~expect_stored =
  let root = H.tmp_dir () in
  let%bind fake = V.start () in
  V.add_fill fake ~tid:7 ~time:(V.nov 2 0 30) ~visible:false;
  let%bind a = V.run ~root ~fake ~now_ms:(V.nov 2 6 0) in
  V.check_exit a ~expected:0 "first run";
  let%bind b = V.run ~root ~fake ~now_ms:before_reveal in
  V.check_exit b ~expected:0 "run before the fill is indexed";
  H.check (List.is_empty (V.stored_tids ~root)) "the fill is not indexed yet";
  V.reveal fake;
  let%bind c = V.run ~root ~fake ~now_ms:reveal_run in
  V.check_exit c ~expected:0 (sprintf "run %d days after the fill" days_late);
  let stored = List.mem (V.stored_tids ~root) 7 ~equal:Int.equal in
  H.check
    (Bool.equal stored expect_stored)
    (sprintf "a fill %d days late: stored must be %b" days_late expect_stored);
  H.check
    (V.new_total (V.last_run_events ~root) ~kind:"fills" = if expect_stored then 1 else 0)
    (sprintf
       "a fill %d days late: its pull events must count %d new"
       days_late
       (if expect_stored then 1 else 0));
  V.stop fake
;;

let late_29 () =
  late_fill
    ~days_late:29
    ~before_reveal:(V.nov 30 12 0)
    ~reveal_run:(V.nov 31 0 30)
    ~expect_stored:true
;;

let late_31 () =
  late_fill
    ~days_late:31
    ~before_reveal:(V.nov 32 12 0)
    ~reveal_run:(V.nov 33 0 30)
    ~expect_stored:false
;;

let stuck () =
  let root = H.tmp_dir () in
  let%bind fake = V.start () in
  add_fills fake ~first_tid:1 ~count:2001 ~time:(fun _ -> V.nov 5 9 30);
  let%bind outcome = V.run ~root ~fake ~now_ms:(V.nov 5 10 0) in
  V.check_exit outcome ~expected:1 "stuck run";
  let events = V.last_run_events ~root in
  H.check (List.length (V.named events "stuck") >= 1) "a stuck event must be recorded";
  H.check (V.watermark root = V.nov 1 0 0) "the watermark must not move";
  let fills_pulls = V.pulls events ~kind:"fills" in
  H.check
    (List.exists fills_pulls ~f:(fun e ->
       not (Yojson.Safe.Util.to_bool (Yojson.Safe.Util.member "complete" e.V.json))))
    "the fills pull must be recorded as not complete";
  V.stop fake
;;

let funding () =
  let root = H.tmp_dir () in
  let%bind fake = V.start () in
  let time i = V.nov 1 0 0 + (i * 10 * V.minute) in
  for i = 0 to 599 do
    V.add_funding fake ~coin:"ETH" ~time:(time i) ~visible:true;
    V.add_funding fake ~coin:"BTC" ~time:(time i) ~visible:true
  done;
  let%bind first = V.run ~root ~fake ~now_ms:(V.nov 10 12 0) in
  V.check_exit first ~expected:0 "first run";
  let first_start = (List.hd_exn (funding_requests fake)).V.start_ms in
  H.check
    (Option.equal Int.equal first_start (Some (V.nov 1 0 0)))
    "the first funding pull must start at 2026-11-01";
  H.check
    (List.length (funding_requests fake) >= 3)
    "1200 rows must take at least three pages of 500";
  H.check (List.length (V.stored_funding ~root) = 1200) "every funding row must be stored";
  H.check
    (V.new_total (V.last_run_events ~root) ~kind:"funding" = 1200)
    "each (coin, time) counted new once";
  V.add_funding fake ~coin:"SOL" ~time:(V.nov 10 3 0) ~visible:true;
  let%bind second = V.run ~root ~fake ~now_ms:(V.nov 11 12 0) in
  V.check_exit second ~expected:0 "second run";
  H.check (List.length (V.stored_funding ~root) = 1201) "the late row must be stored";
  H.check
    (V.new_total (V.last_run_events ~root) ~kind:"funding" = 1)
    "rows present in two re-reads must be counted new once";
  V.stop fake
;;

let alarm () =
  let root = H.tmp_dir () in
  let%bind fake = V.start () in
  let time i = V.nov 2 0 0 + (i * 1000) in
  add_fills fake ~first_tid:1 ~count:5000 ~time;
  let%bind first = V.run ~root ~fake ~now_ms:(V.nov 2 12 0) in
  V.check_exit first ~expected:0 "first run";
  H.check
    (List.is_empty (V.named (V.last_run_events ~root) "alarm"))
    "a daily re-read of exactly 5000 fills must raise no alarm";
  V.add_fill fake ~tid:5001 ~time:(time 5000) ~visible:true;
  let%bind second = V.run ~root ~fake ~now_ms:(V.nov 3 12 0) in
  V.check_exit second ~expected:0 "second run";
  H.check
    (List.length (V.named (V.last_run_events ~root) "alarm") >= 1)
    "a daily re-read of 5001 fills must raise alarm";
  V.stop fake
;;

let () =
  H.main "vault pulls" (fun () ->
    H.run_all
      [ "1 paging", paging
      ; "2 overlap", overlap
      ; "3 late fill 29 days", late_29
      ; "3 late fill 31 days", late_31
      ; "4 stuck page", stuck
      ; "5 funding", funding
      ; "8 alarm", alarm
      ])
;;
