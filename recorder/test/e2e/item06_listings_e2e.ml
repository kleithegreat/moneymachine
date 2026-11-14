(* Item 6 against the running recorder: a coin added between two listing reads is subscribed, one delisted is
   unsubscribed, both are events, and each REST response is stored verbatim in listings. Uses the assumed flag
   --listings-interval-s to make the "hourly" read fast. *)

open Core
open Async
module H = Rec_support.Harness
module F = Rec_support.Fake_hl

let requests_of fake ~meth ~coin =
  List.filter_map (F.received fake) ~f:(fun (_, _, text) ->
    match Yojson.Safe.from_string text with
    | `Assoc fields ->
      (match
         ( List.Assoc.find fields ~equal:String.equal "method"
         , List.Assoc.find fields ~equal:String.equal "subscription" )
       with
       | Some (`String m), Some (`Assoc sub)
         when String.equal m meth
              && List.Assoc.mem sub ~equal:String.equal "coin"
              && Poly.equal (List.Assoc.find_exn sub ~equal:String.equal "coin") (`String coin) ->
         (match List.Assoc.find_exn sub ~equal:String.equal "type" with
          | `String ty -> Some ty
          | _ -> None)
       | _ -> None)
    | _ -> None
    | exception _ -> None)
;;

let () =
  H.main "item 6: listings change, end to end" (fun () ->
    let universe = ref [ "A"; "B"; "C" ] in
    let config = { F.default_config with rest = F.rest_of_universe (fun () -> !universe) } in
    let%bind fake = F.start config in
    let root = H.tmp_dir () in
    let%bind process =
      H.spawn_run ~root ~listings_interval_s:2 ~extra:[ "--connections"; "2" ] fake
    in
    let%bind () =
      H.wait_until ~timeout_s:20. ~what:"initial subscriptions" (fun () ->
        List.length (requests_of fake ~meth:"subscribe" ~coin:"B") = 3)
    in
    universe := [ "A"; "C"; "D" ];
    let%bind () =
      H.wait_until ~timeout_s:30. ~what:"D subscribed and B unsubscribed" (fun () ->
        List.length (requests_of fake ~meth:"subscribe" ~coin:"D") = 3
        && List.length (requests_of fake ~meth:"unsubscribe" ~coin:"B") = 3)
    in
    let types meth coin = List.sort (requests_of fake ~meth ~coin) ~compare:String.compare in
    H.check (List.equal String.equal (types "subscribe" "D") [ "l2Book"; "l2Book"; "trades" ]) "D types";
    H.check (List.equal String.equal (types "unsubscribe" "B") [ "l2Book"; "l2Book"; "trades" ]) "B types";
    H.check (List.is_empty (requests_of fake ~meth:"unsubscribe" ~coin:"A")) "A was unsubscribed";
    let conn_of meth coin ty ~fast =
      List.find_map (F.received fake) ~f:(fun (conn, _, text) ->
        match Yojson.Safe.from_string text with
        | `Assoc f
          when Poly.equal (List.Assoc.find f ~equal:String.equal "method") (Some (`String meth)) ->
          (match List.Assoc.find f ~equal:String.equal "subscription" with
           | Some (`Assoc sub)
             when Poly.equal (List.Assoc.find sub ~equal:String.equal "coin") (Some (`String coin))
                  && Poly.equal (List.Assoc.find sub ~equal:String.equal "type") (Some (`String ty))
                  && Bool.equal
                       fast
                       (Poly.equal (List.Assoc.find sub ~equal:String.equal "fast") (Some (`Bool true))) ->
             Some conn
           | _ -> None)
        | _ -> None
        | exception _ -> None)
    in
    let trades = conn_of "subscribe" "D" "trades" ~fast:false in
    let fast_book = conn_of "subscribe" "D" "l2Book" ~fast:true in
    let deep_book = conn_of "subscribe" "D" "l2Book" ~fast:false in
    H.check (Option.is_some trades && Option.equal Int.equal trades fast_book) "D's trades and fast book are not on one connection";
    H.check (Option.is_some deep_book && not (Option.equal Int.equal deep_book trades)) "D's 20-level book is on the trades connection";
    H.check (not (F.carries_fast_book fake ~conn:(Option.value_exn deep_book))) "D's 20-level book is on a fast connection";
    let%bind status, _ = H.sigterm_and_wait process in
    H.check (Result.is_ok status) "exit status";
    let listing_events =
      List.filter_map (H.events ~root) ~f:(fun (_, _, name, msg) ->
        if String.equal name "listing"
        then (
          match Yojson.Safe.Util.member "coin" msg with
          | `String coin -> Some coin
          | _ -> None)
        else None)
    in
    H.check (List.mem listing_events "D" ~equal:String.equal) "no listing event for D";
    H.check (List.mem listing_events "B" ~equal:String.equal) "no listing event for B";
    let stored = List.map (H.channel_lines ~root ~channel:"listings") ~f:(fun (_, _, msg) -> msg) in
    let has meta = List.mem stored (Yojson.Safe.from_string meta) ~equal:Yojson.Safe.equal in
    H.check (has (F.meta_json ~live:[ "A"; "B"; "C" ] ~delisted:[])) "first meta not stored verbatim";
    H.check (has (F.meta_json ~live:[ "A"; "C"; "D" ] ~delisted:[])) "second meta not stored verbatim";
    H.check (has (F.perp_dexs_json [])) "perpDexs not stored";
    F.stop fake)
;;
