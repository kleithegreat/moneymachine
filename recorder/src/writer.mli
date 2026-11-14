(** The append-only frame writer (RECORDER.md, Storage: "Compression" and "Files are append-only"). Synchronous;
    time comes from the injected clock. *)

type t

(** [create ~root ~now_ms] writes under [root]; [now_ms] is the clock that decides when a buffer is due. *)
val create : root:string -> now_ms:(unit -> int) -> t

(** One zstd frame is written when a buffer reaches this many bytes: 1 MiB. *)
val max_buffer_bytes : int

(** [add t route ~recv_ms line] buffers a ["\n"]-terminated [line] for the file of [route] and the hour of
    [recv_ms]. When that buffer reaches [max_buffer_bytes] it is written at once as one frame. Lines of different
    hours never share a frame. *)
val add : t -> Route.t -> recv_ms:int -> string -> unit

(** Writes, as one frame appended to its file, every buffer whose oldest line is at least 1000 ms old by the clock. *)
val tick : t -> unit

(** Writes every buffer (RECORDER.md, Behaviour: "Stopping"). *)
val flush_all : t -> unit

(** [flush_all], then closes every file. *)
val close : t -> unit
