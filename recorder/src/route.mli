(** Which file a frame belongs to (RECORDER.md, Storage: "Routing"). *)

type t =
  | Trades
  | L2_book
  | All_dexs_asset_ctxs
  | Events
  | Listings
[@@deriving sexp_of, compare, equal]

(** The channel of a received frame, from its top-level [channel] field: trades, l2Book and allDexsAssetCtxs
    to their own files; subscriptionResponse, pong, error, unknown channels and unparseable text to [Events].
    Never [Listings]. *)
val of_frame : string -> t

(** The directory name under the root: trades, l2Book, allDexsAssetCtxs, events, listings. *)
val dir : t -> string
