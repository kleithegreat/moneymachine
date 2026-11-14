(** A subscription (RECORDER.md, What it records). *)

type t =
  | All_dexs_asset_ctxs
  | Trades of string
  | L2_book_fast of string
  | L2_book of string
[@@deriving sexp_of, compare, equal]

(** The JSON request that subscribes: [{"method":"subscribe","subscription":{"type":...,"coin":...}}].
    [L2_book_fast] is [l2Book] with ["fast": true] (5 levels, about every 0.55 s); [L2_book] has no optional
    fields (20 levels, about every 10 s). *)
val subscribe_message : t -> string

(** The JSON request that unsubscribes. *)
val unsubscribe_message : t -> string

(** The subscription a [subscriptionResponse] frame acknowledges (Behaviour: "Subscribing"); [None] for any
    other frame. An [l2Book] acknowledgement carrying ["fast": true] is [L2_book_fast], one without is
    [L2_book]. *)
val of_ack : string -> t option
