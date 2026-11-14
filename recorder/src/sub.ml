open Core

type t =
  | All_dexs_asset_ctxs
  | Trades of string
  | L2_book_fast of string
  | L2_book of string
[@@deriving sexp_of, compare, equal]

let subscription = function
  | All_dexs_asset_ctxs -> `Assoc [ "type", `String "allDexsAssetCtxs" ]
  | Trades coin -> `Assoc [ "type", `String "trades"; "coin", `String coin ]
  | L2_book_fast coin ->
    `Assoc [ "type", `String "l2Book"; "coin", `String coin; "fast", `Bool true ]
  | L2_book coin -> `Assoc [ "type", `String "l2Book"; "coin", `String coin ]
;;

let request meth t =
  Yojson.Safe.to_string (`Assoc [ "method", `String meth; "subscription", subscription t ])
;;

let subscribe_message = request "subscribe"
let unsubscribe_message = request "unsubscribe"

let of_ack frame =
  let open Yojson.Safe.Util in
  match Yojson.Safe.from_string frame with
  | exception _ -> None
  | json ->
    (match member "channel" json, member "data" json with
     | `String "subscriptionResponse", data ->
       let subscription = member "subscription" data in
       (match member "method" data, member "type" subscription, member "coin" subscription with
        | `String "subscribe", `String "allDexsAssetCtxs", _ -> Some All_dexs_asset_ctxs
        | `String "subscribe", `String "trades", `String coin -> Some (Trades coin)
        | `String "subscribe", `String "l2Book", `String coin ->
          (match member "fast" subscription with
           | `Bool true -> Some (L2_book_fast coin)
           | _ -> Some (L2_book coin))
        | _ -> None)
     | _ -> None
     | exception _ -> None)
;;
