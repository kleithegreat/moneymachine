(** Line framing (RECORDER.md, Storage: "A line"). *)

(** [sanitize s] is [s] with every CR and LF byte replaced by a space and nothing else changed. *)
val sanitize : string -> string

(** [of_frame ~recv_ms ~conn frame] is the recorded line for a received frame, terminated by ["\n"]: a JSON
    object with fields [recv], [conn] and [msg], where [msg] is [sanitize frame] spliced in byte for byte, as
    the last field. *)
val of_frame : recv_ms:int -> conn:int -> string -> string

(** [envelope line] is the [recv] and [conn] of a recorded line ([conn] is [None] for [null]), read from its
    first two fields without parsing the frame. *)
val envelope : string -> (int * int option) option
