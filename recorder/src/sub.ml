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
  Yojson.Safe.to_string
    (`Assoc [ "method", `String meth; "subscription", subscription t ])
;;

let subscribe_message = request "subscribe"
let unsubscribe_message = request "unsubscribe"

let field name = function
  | `Assoc fields -> List.Assoc.find fields ~equal:String.equal name
  | _ -> None
;;

let of_ack frame =
  match Yojson.Safe.from_string frame with
  | exception Yojson.Json_error _ -> None
  | json ->
    (match field "channel" json, field "data" json with
     | Some (`String "subscriptionResponse"), Some data ->
       (match field "method" data, field "subscription" data with
        | Some (`String "subscribe"), Some subscription ->
          (match field "type" subscription, field "coin" subscription with
           | Some (`String "allDexsAssetCtxs"), _ -> Some All_dexs_asset_ctxs
           | Some (`String "trades"), Some (`String coin) -> Some (Trades coin)
           | Some (`String "l2Book"), Some (`String coin) ->
             (match field "fast" subscription with
              | Some (`Bool true) -> Some (L2_book_fast coin)
              | _ -> Some (L2_book coin))
           | _ -> None)
        | _ -> None)
     | _ -> None)
;;
