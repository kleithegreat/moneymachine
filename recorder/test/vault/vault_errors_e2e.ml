(* VAULT.md test 7: errors. Interface assumed: see vault_harness.ml. A retry's wait (backoff, up to 5 retries) is
   the collector's own; these runs may take minutes. *)

open Core
open Async
module H = Rec_support.Harness
module V = Vault_harness

let now = V.nov 5 10 0

let fresh () =
  let%map fake = V.start () in
  for i = 0 to 9 do
    V.add_fill fake ~tid:(i + 1) ~time:(V.nov 5 9 (10 + i)) ~visible:true
  done;
  fake
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
  V.stop fake
;;

let five_429s () =
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
    (attempts >= 5 && attempts <= 6)
    (sprintf "a 429 is retried at most 5 times, not %d attempts" attempts);
  H.check
    (List.length (V.named (V.last_run_events ~root) "error") >= 1)
    "an error event must be recorded";
  H.check (V.watermark root = V.nov 1 0 0) "the watermark must not move";
  V.stop fake
;;

let () =
  H.main "vault errors" (fun () ->
    H.run_all
      [ "7 a 429 retried", retried_once
      ; "7 five 429s", five_429s
      ; ( "7 a 500"
        , fun () -> always ~status:500 ~body:"internal error" ~what:"500 every time" )
      ; ( "7 an unreadable body"
        , fun () -> always ~status:200 ~body:"<html>not json" ~what:"unreadable body" )
      ])
;;
