(** Subscriptions awaiting acknowledgement (RECORDER.md, Behaviour: "Subscribing"). Times are in ms. *)

type t

val create : unit -> t

(** A subscribe request was sent at [now_ms]. *)
val sent : t -> now_ms:int -> Sub.t -> unit

(** Its [subscriptionResponse] arrived. *)
val acked : t -> Sub.t -> unit

(** The subscriptions sent 30 s or more ago and not acknowledged, each reported once ([unacked] events). *)
val expired : t -> now_ms:int -> Sub.t list
