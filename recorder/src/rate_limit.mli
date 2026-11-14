(** A sliding-window limit on events (RECORDER.md, Limits it keeps), over an injected clock. *)

type t

(** At most [limit] events in any half-open window [[s, s + window_ms)]. *)
val create : limit:int -> window_ms:int -> t

(** [reserve t ~now_ms ~n] books [n] events at the earliest time [at >= now_ms] that keeps the limit and
    returns [at]; the caller waits until then. A reservation is never earlier than any before it. *)
val reserve : t -> now_ms:int -> n:int -> int
