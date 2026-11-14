(** A subscription (RECORDER.md, What it records). *)

type t =
  | All_dexs_asset_ctxs
  | Trades of string
  | L2_book of string
[@@deriving sexp_of, compare, equal]

(** The JSON request that subscribes: [{"method":"subscribe","subscription":{"type":...,"coin":...}}], with no
    optional fields for [l2Book]. *)
val subscribe_message : t -> string

(** The JSON request that unsubscribes. *)
val unsubscribe_message : t -> string

(** The subscription a [subscriptionResponse] frame acknowledges (Behaviour: "Subscribing"); [None] for any
    other frame. *)
val of_ack : string -> t option
