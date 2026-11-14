(** Spreading subscriptions over connections (RECORDER.md, Behaviour: "Planning"; Limits it keeps). *)

type t

(** The two kinds of connection: [Deep] ones carry only 20-level books, [Fast] ones everything else. *)
type kind =
  | Deep
  | Fast
[@@deriving sexp_of, compare, equal]

(** [create ~connections ~max_subscriptions], with [connections >= 2]: a quarter of the connections, rounded up,
    are [Deep] and the rest [Fast]. It holds the one [allDexsAssetCtxs] subscription from the start, on the
    lowest-numbered [Fast] connection. *)
val create : connections:int -> max_subscriptions:int -> t

(** The kind of connection [conn] (counting from 0). *)
val kind : t -> conn:int -> kind

type outcome =
  | Added
  | Refused

(** Adds a coin: [Trades coin] and [L2_book_fast coin] together on one [Fast] connection, the one carrying the
    fewest [Trades] subscriptions; and, if the coin is on the main dex (its name has no [:]), also [L2_book coin]
    on the [Deep] connection carrying the fewest [L2_book] subscriptions. All or nothing: [Refused], adding
    nothing, if the coin's subscriptions (two, or three on the main dex) would exceed the maximum. A coin already
    held is [Added] and unchanged. *)
val add : t -> coin:string -> outcome

(** Drops the coin's subscriptions, returning each with its connection (empty if the coin is unknown). *)
val remove : t -> coin:string -> (int * Sub.t) list

(** The subscriptions held by one connection. *)
val subs : t -> conn:int -> Sub.t list

(** The connection holding a subscription. *)
val conn_of : t -> Sub.t -> int option

(** The number of subscriptions held in all. *)
val total : t -> int
