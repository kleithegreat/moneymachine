(* VAULT.md test 7: errors, and Limits: a run stops at its first failed pull, sending no request after it, and a pull
   completed before it keeps what it did. Interface assumed: see vault_harness.ml. A retry's wait (backoff, up to 5
   retries) is the collector's own; these runs may take minutes. *)

open Core
open Async
module H = Rec_support.Harness
module F = Rec_support.Fake_hl
module V = Vault_harness

let now = V.nov 5 10 0

let with_fills n =
  let%map fake = V.start () in
  for i = 1 to n do
    V.add_fill fake ~tid:i ~time:(V.nov 5 9 0 + i) ~visible:true
  done;
  fake
;;

let fresh () = with_fills 10
let kinds fake = List.map fake.V.log ~f:(fun r -> r.V.kind)

let names_request errors ~kind =
  List.exists errors ~f:(fun e ->
    String.is_substring (Yojson.Safe.to_string e.V.json) ~substring:kind)
;;

let retried_once () =
  let root = H.tmp_dir () in
  let%bind fake = fresh () in
  V.set_behaviour fake (fun ~kind ~nth _ ->
    if String.equal kind "userFillsByTime" && nth = 0
    then V.Reply (429, "rate limited")
    else V.Normal);
  let%bind outcome = V.run ~root ~fake ~now_ms:now in
  V.check_exit outcome ~expected:0 "a 429 then an answer";
  let answered =
    List.count (V.requests fake ~kind:"userFillsByTime") ~f:(fun r -> r.V.status = 200)
  in
  let stored = List.length (V.kind_lines ~root "fills") in
  H.check
    (stored = answered)
    "every answered fills request must be stored once, and the 429 not at all";
  H.check (List.length (V.stored_tids ~root) = 10) "the fills must be stored";
  H.check (V.watermark root = now) "the watermark must move";
  V.stop fake
;;

let always ~status ~body ~what =
  let root = H.tmp_dir () in
  let%bind fake = fresh () in
  V.set_behaviour fake (fun ~kind ~nth:_ _ ->
    if String.equal kind "userFillsByTime" then V.Reply (status, body) else V.Normal);
  let%bind outcome = V.run ~root ~fake ~now_ms:now in
  V.check_exit outcome ~expected:1 what;
  let events = V.last_run_events ~root in
  H.check
    (List.length (V.named events "error") >= 1)
    (sprintf "%s: an error event must be recorded" what);
  H.check
    (V.watermark root = V.nov 1 0 0)
    (sprintf "%s: the watermark must not move" what);
  H.check
    (String.is_empty (V.raw_text ~root "fills"))
    (sprintf "%s: something of it was stored" what);
  V.stop fake
;;

let six_429s () =
  let root = H.tmp_dir () in
  let%bind fake = fresh () in
  V.set_behaviour fake (fun ~kind ~nth:_ _ ->
    if String.equal kind "userFillsByTime"
    then V.Reply (429, "rate limited")
    else V.Normal);
  let%bind outcome = V.run ~root ~fake ~now_ms:now in
  V.check_exit outcome ~expected:1 "429 every time";
  let attempts = List.length (V.requests fake ~kind:"userFillsByTime") in
  H.check
    (attempts = 6)
    (sprintf "a 429 is asked again 5 times, six requests in all, not %d" attempts);
  H.check
    (List.length (V.named (V.last_run_events ~root) "error") >= 1)
    "an error event must be recorded";
  H.check (V.watermark root = V.nov 1 0 0) "the watermark must not move";
  V.stop fake
;;

(* A fill of the third page, which only the failed second page's stand-in holds. *)
let late = { V.tid = 4321; time = V.nov 5 9 0 + 4321; visible = true }

(* 4,500 fills come in pages of 2,000, 2,000 and 502; the second page fails as [second] says. The run stops there,
   storing nothing of it; the next run, answered whole, stores all 4,500. *)
let later_page ~second what () =
  let root = H.tmp_dir () in
  let%bind fake = with_fills 4500 in
  V.set_behaviour fake (fun ~kind ~nth _ ->
    if String.equal kind "userFillsByTime" && nth = 1 then second else V.Normal);
  let%bind outcome = V.run ~root ~fake ~now_ms:now in
  V.check_exit outcome ~expected:1 what;
  let errors = V.named (V.last_run_events ~root) "error" in
  H.check
    (names_request errors ~kind:"userFillsByTime")
    (sprintf "%s: no error names the fills request" what);
  H.check
    (List.equal String.equal (kinds fake) [ "userFillsByTime"; "userFillsByTime" ])
    (sprintf
       "%s: requests after the failed page: %s"
       what
       (String.concat ~sep:" " (kinds fake)));
  H.check (V.watermark root = V.nov 1 0 0) (sprintf "%s: the watermark moved" what);
  H.check
    (not (List.mem (V.stored_tids ~root) late.tid ~equal:Int.equal))
    (sprintf "%s: the failed page was stored" what);
  V.set_behaviour fake (fun ~kind:_ ~nth:_ _ -> V.Normal);
  V.forget_requests fake;
  let%bind outcome = V.run ~root ~fake ~now_ms:now in
  V.check_exit outcome ~expected:0 (what ^ ", then answered whole");
  H.check
    (List.equal Int.equal (V.stored_tids ~root) (List.init 4500 ~f:(fun i -> i + 1)))
    (sprintf "%s: the next run did not store all 4,500 fills" what);
  H.check
    (V.watermark root = now)
    (sprintf "%s: the next run did not move the watermark" what);
  V.stop fake
;;

let cut_page =
  let page = V.array_json [ V.fill_json late ] in
  V.Serve (F.send (F.with_length ~announced:(String.length page + 64) page))
;;

(* The fees request fails as [fees] says: the run stops with no orders request, and the fills pull before it stays
   stored with its watermark moved. *)
let fees_fail ~fees what () =
  let root = H.tmp_dir () in
  let%bind fake = fresh () in
  V.set_behaviour fake (fun ~kind ~nth:_ _ ->
    if String.equal kind "userFees" then fees else V.Normal);
  let%bind outcome = V.run ~root ~fake ~now_ms:now in
  V.check_exit outcome ~expected:1 what;
  let errors = V.named (V.last_run_events ~root) "error" in
  H.check
    (names_request errors ~kind:"userFees")
    (sprintf "%s: no error names the fees request" what);
  H.check
    (List.is_empty (V.requests fake ~kind:"historicalOrders"))
    (sprintf "%s: orders were asked for after fees failed" what);
  H.check
    (List.equal Int.equal (V.stored_tids ~root) (List.init 10 ~f:(fun i -> i + 1)))
    (sprintf "%s: the fills pull before it is not stored" what);
  H.check
    (V.watermark root = now)
    (sprintf "%s: the fills pull's watermark did not stay moved" what);
  V.stop fake
;;

let () =
  H.main "vault errors" (fun () ->
    H.run_all
      [ "7 a 429 retried", retried_once
      ; "7 six 429s", six_429s
      ; ( "7 a 500"
        , fun () -> always ~status:500 ~body:"internal error" ~what:"500 every time" )
      ; ( "7 an unreadable body"
        , fun () -> always ~status:200 ~body:"<html>not json" ~what:"unreadable body" )
      ; ( "7 a second fills page cut short"
        , later_page ~second:cut_page "a second page cut short" )
      ; ( "7 a second fills page answered 500"
        , later_page ~second:(V.Reply (500, "internal error")) "a second page 500" )
      ; ( "7 fees answered 500"
        , fees_fail ~fees:(V.Reply (500, "internal error")) "fees 500" )
      ; ( "7 fees with a comment after its object"
        , fees_fail
            ~fees:(V.Serve (F.send (F.with_length (V.fees_json ^ " /* fees */"))))
            "fees with a comment" )
      ])
;;
