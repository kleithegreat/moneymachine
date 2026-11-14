(** Spreading subscriptions over connections (RECORDER.md, Behaviour: "Planning"; Limits it keeps). *)

type t

(** [create ~connections ~max_subscriptions] holds the one [allDexsAssetCtxs] subscription from the start. *)
val create : connections:int -> max_subscriptions:int -> t

type outcome =
  | Added
  | Refused

(** Adds [Trades coin] and [L2_book coin] together, on one connection, the one carrying the fewest [l2Book]
    subscriptions. [Refused], adding nothing, if the two would exceed the maximum. A coin already held is [Added]
    and unchanged. *)
val add : t -> coin:string -> outcome

(** Drops the coin's subscriptions, returning each with its connection (empty if the coin is unknown). *)
val remove : t -> coin:string -> (int * Sub.t) list

(** The subscriptions held by one connection. *)
val subs : t -> conn:int -> Sub.t list

(** The connection holding a subscription. *)
val conn_of : t -> Sub.t -> int option

(** The number of subscriptions held in all. *)
val total : t -> int
