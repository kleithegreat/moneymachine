(** Which file a frame belongs to (RECORDER.md, Storage: "Routing"). *)

type t =
  | Trades
  | L2_book
  | L2_book_fast
  | All_dexs_asset_ctxs
  | Events
  | Listings
[@@deriving sexp_of, compare, equal]

(** The channel of a received frame, from its top-level [channel] field: trades, l2Book and allDexsAssetCtxs
    to their own files; subscriptionResponse, pong, error, unknown channels and unparseable text to [Events].
    [fast] is whether the frame was received on a fast connection (Behaviour: "Planning"): an [l2Book] frame
    then goes to [L2_book_fast], else to [L2_book]; [fast] changes no other frame's file. Never [Listings]. *)
val of_frame : fast:bool -> string -> t

(** The directory name under the root: trades, l2Book, l2Book-fast, allDexsAssetCtxs, events, listings. *)
val dir : t -> string
