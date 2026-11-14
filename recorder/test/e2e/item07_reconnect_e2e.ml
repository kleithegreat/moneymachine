(* Item 7, first case: the fake server closing a connection gives close, then open after the backoff, and every
   subscription re-sent. *)

open Core
open Async
module H = Rec_support.Harness
module F = Rec_support.Fake_hl

let () =
  H.main "item 7: close, open after backoff, resubscribe" (fun () ->
    let coins = List.init 6 ~f:(sprintf "C%d") in
    let config =
      { F.default_config with
        rest = F.rest_of_universe (fun () -> coins)
      ; close_after_ms = (fun ~conn -> if conn = 1 then Some 3000 else None)
      }
    in
    let%bind fake = F.start config in
    let root = H.tmp_dir () in
    let%bind process = H.spawn_run ~root ~extra:[ "--connections"; "2" ] fake in
    let%bind () =
      H.wait_until ~timeout_s:30. ~what:"a third connection with its subscriptions" (fun () ->
        List.length (F.accepts fake) >= 3
        && List.length (F.subscribed_on fake ~conn:3) >= List.length (F.subscribed_on fake ~conn:1)
        && List.length (F.subscribed_on fake ~conn:1) > 0)
    in
    let sorted conn = List.sort (F.subscribed_on fake ~conn) ~compare:[%compare: string * string] in
    H.check
      (List.equal [%equal: string * string] (sorted 1) (sorted 3))
      "the reopened connection did not re-send every subscription";
    let%bind status, _ = H.sigterm_and_wait process in
    H.check (Result.is_ok status) "exit status";
    let events = H.events ~root in
    let closes = List.filter events ~f:(fun (_, _, name, _) -> String.equal name "close") in
    H.check (not (List.is_empty closes)) "no close event";
    let recv, conn, _, _ = List.hd_exn closes in
    let reopen =
      List.find events ~f:(fun (r, c, name, _) -> Option.equal Int.equal c conn && r > recv && String.equal name "open")
    in
    (match reopen with
     | None -> failwith "no open event after the close"
     | Some (r, _, _, _) ->
       let waited = r - recv in
       H.check (waited >= 800 && waited <= 2500) (sprintf "reopened after %d ms, expected about 1000" waited));
    let reasons =
      List.filter_map closes ~f:(fun (_, _, _, msg) ->
        match Yojson.Safe.Util.member "reason" msg with
        | `Null -> None
        | _ -> Some ())
    in
    H.check (not (List.is_empty reasons)) "close event has no reason";
    F.stop fake)
;;
