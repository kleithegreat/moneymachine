(* VAULT.md test 9: nothing printed. The fake serves items whose price, size, fee and rate are distinctive
   sentinels (vault_harness.ml). They must appear in the stored response lines (the control: they were served and
   kept) and nowhere else: not in an event, not in state.json, not in the collector's output. This test itself
   prints no item value: its failure messages name only the place. Interface assumed: see vault_harness.ml. *)

open Core
open Async
module H = Rec_support.Harness
module V = Vault_harness

let contains_sentinel text =
  List.exists V.sentinels ~f:(fun s -> String.is_substring text ~substring:s)
;;

let state_text root =
  if Option.is_some (V.state_json root)
  then In_channel.read_all (V.state_path root)
  else ""
;;

let populate fake =
  for i = 0 to 9 do
    V.add_fill fake ~tid:(i + 1) ~time:(V.nov 5 9 (10 + i)) ~visible:true
  done;
  V.add_funding fake ~coin:"ETH" ~time:(V.nov 5 8 0) ~visible:true
;;

let healthy () =
  let root = H.tmp_dir () in
  let%bind fake = V.start () in
  populate fake;
  let%bind outcome = V.run ~root ~fake ~now_ms:(V.nov 5 10 0) in
  V.check_exit outcome ~expected:0 "healthy run";
  List.iter [ "fills"; "funding"; "fees"; "orders" ] ~f:(fun kind ->
    H.check
      (contains_sentinel (V.raw_text ~root kind))
      (sprintf "the stored %s responses must hold the served items, byte for byte" kind));
  H.check
    (not (contains_sentinel (V.raw_text ~root "events")))
    "an event holds an item's price, size, fee or rate";
  H.check
    (not (contains_sentinel (state_text root)))
    "state.json holds an item's price, size, fee or rate";
  H.check
    (not (contains_sentinel outcome.output))
    "the collector printed an item's price, size, fee or rate";
  V.stop fake
;;

let failing () =
  let root = H.tmp_dir () in
  let%bind fake = V.start () in
  populate fake;
  let echo =
    sprintf "failed on price %s size %s fee %s rate %s" V.px V.sz V.fee V.funding_rate
  in
  V.set_behaviour fake (fun ~kind ~nth:_ _ ->
    if String.equal kind "userFillsByTime" then V.Reply (500, echo) else V.Normal);
  let%bind outcome = V.run ~root ~fake ~now_ms:(V.nov 5 10 0) in
  V.check_exit outcome ~expected:1 "failing run";
  H.check
    (not (contains_sentinel (V.raw_text ~root "events")))
    "an error event echoes the response body of a failed request";
  H.check
    (not (contains_sentinel outcome.output))
    "the collector printed a failed response's body";
  V.stop fake
;;

let () =
  H.main "vault nothing printed" (fun () ->
    H.run_all [ "9 healthy", healthy; "9 failing", failing ])
;;
