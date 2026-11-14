open Core

type t =
  | Trades
  | L2_book
  | All_dexs_asset_ctxs
  | Events
  | Listings
[@@deriving sexp_of, compare, equal]

let of_frame frame =
  match Yojson.Safe.from_string frame with
  | `Assoc fields ->
    (match List.Assoc.find fields ~equal:String.equal "channel" with
     | Some (`String "trades") -> Trades
     | Some (`String "l2Book") -> L2_book
     | Some (`String "allDexsAssetCtxs") -> All_dexs_asset_ctxs
     | _ -> Events)
  | _ -> Events
  | exception _ -> Events
;;

let dir = function
  | Trades -> "trades"
  | L2_book -> "l2Book"
  | All_dexs_asset_ctxs -> "allDexsAssetCtxs"
  | Events -> "events"
  | Listings -> "listings"
;;
