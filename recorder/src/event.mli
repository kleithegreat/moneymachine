(** The recorder's own facts, recorded in the [events] channel (RECORDER.md, Storage: "Events"). *)

type t

(** [make name fields] is the event [{"event": name, ...fields}]. Names in use: start, stop, open, close, error,
    subscribed, unacked, refused, listing. *)
val make : string -> (string * Yojson.Safe.t) list -> t

(** The event's name. *)
val name : t -> string

(** The value of one extra field. *)
val field : t -> string -> Yojson.Safe.t option

(** The recorded line, ["\n"]-terminated, with the event as [msg] (Storage: "A line"). [conn] is the connection
    the fact concerns; [None] for recorder-wide events (start, stop, listing, refused), written as ["conn": null]. *)
val to_line : recv_ms:int -> conn:int option -> t -> string
