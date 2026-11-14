(** The integrity tool behind [mmrec check] (RECORDER.md, The forward window and Interface). It reads sizes,
    counts, the recorder's own [recv] and [conn], and the [channel] and [event] fields, and nothing else of any
    frame. Memory does not grow with a file's size. *)

type entry =
  { channel : string
  ; hour : string  (** [YYYYMMDDHH] *)
  ; bytes : int  (** the compressed size of the hour's files *)
  ; files : int
  ; lines : int  (** the whole lines of the files *)
  ; truncated : bool  (** whether any file is *)
  }
[@@deriving sexp_of, equal]

(** A connection's gap, from its [close] or [error] (the earlier, if both), or from its last line when a [start]
    finds it open, to its next [open]; [reopened_ms] is [None] if it is not opened again within the range (the gap
    runs to the end of the range). *)
type gap =
  { conn : int
  ; closed_ms : int
  ; reopened_ms : int option
  }
[@@deriving sexp_of, equal]

type report =
  { entries : entry list  (** in no specified order *)
  ; gaps : gap list  (** by [closed_ms] *)
  }
[@@deriving sexp_of, equal]

(** The report for the hours [from_] to [to_] inclusive, each [YYYYMMDDHH], for every channel under [root]. *)
val check : root:string -> from_:string -> to_:string -> report

(** The text [mmrec check] prints, tab-separated: per entry [hour channel bytes files lines truncated] with
    truncated [yes] or [no], then per gap [gap conn from_ms to_ms] with [to_ms] empty if never reopened. *)
val render : report -> string
