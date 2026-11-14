(** One connection's liveness (RECORDER.md, Behaviour: "Heartbeat" and "Reconnecting"). Times are in ms. *)

type t

type action =
  | Send_ping
  | Reopen

(** A connection that came up at [now_ms]. *)
val create : now_ms:int -> t

(** A message was received at [now_ms]. *)
val received : t -> now_ms:int -> unit

(** What to do at [now_ms]: [Send_ping] once per idle spell, when nothing has been received for 30 s; [Reopen]
    when nothing has been received for 45 s. Receiving anything starts a new idle spell. *)
val poll : t -> now_ms:int -> action list
