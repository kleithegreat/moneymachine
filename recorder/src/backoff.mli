(** Reconnect backoff (RECORDER.md, Behaviour: "Reconnecting"). Times are in seconds. *)

type t

(** [random ()] is uniform on [0, 1); it is injected so that tests are deterministic. *)
val create : random:(unit -> float) -> t

(** The connection came up at [now]. *)
val opened : t -> now:float -> unit

(** The connection was lost at [now]; the delay before reopening. The first failure waits 1 s, each consecutive
    one double the last up to 60 s, each scaled by a jitter of [0.8 + 0.4 * random ()]. A connection that was up
    for 600 s or more since [opened] resets the sequence to 1 s. *)
val failed : t -> now:float -> float
