(** The integrity tool behind [mmrec check] (RECORDER.md, The forward window and Interface). It reads sizes,
    counts, the recorder's own [recv] and [conn], and the [channel] and [event] fields, and nothing else of any
    frame. *)

type entry =
  { channel : string
  ; hour : string  (** [YYYYMMDDHH] *)
  ; bytes : int
  ; frames : int
  ; lines : int
  ; truncated : bool
  }
[@@deriving sexp_of, equal]

(** A connection that closed or errored, and when it was next opened, from the events; [reopened_ms] is [None]
    if it was not within the range. *)
type gap =
  { conn : int
  ; closed_ms : int
  ; reopened_ms : int option
  }
[@@deriving sexp_of, equal]

type report =
  { entries : entry list  (** by channel, then hour *)
  ; gaps : gap list  (** by [closed_ms] *)
  }
[@@deriving sexp_of, equal]

(** The report for the hours [from_] to [to_] inclusive, each [YYYYMMDDHH], for every channel under [root]. *)
val check : root:string -> from_:string -> to_:string -> report

(** The text [mmrec check] prints. *)
val render : report -> string
