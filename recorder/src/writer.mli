(** The recording writer (RECORDER.md, Storage: "Compression" and "Files are append-only"). Synchronous; time comes
    from the injected clock. A route and hour is one file, one zstd stream, written by this run only. *)

type t

(** [create ~root ~now_ms] writes under [root]; the clock's reading now names this run's files, and decides when a
    buffer is due. *)
val create : root:string -> now_ms:(unit -> int) -> t

(** A buffer reaching this many bytes is flushed at once: 1 MiB. *)
val max_buffer_bytes : int

(** [add t route ~recv_ms line] buffers a ["\n"]-terminated [line] for the file of [route] and the hour of
    [recv_ms] (or of the latest hour this run has opened for [route], if later). The first line of a later hour
    ends the earlier hour's file for good. *)
val add : t -> Route.t -> recv_ms:int -> string -> unit

(** Flushes every buffer whose oldest line is at least 1000 ms old by the clock. *)
val tick : t -> unit

(** Flushes every buffer, ends every stream and closes every file (RECORDER.md, Behaviour: "Stopping"). *)
val close : t -> unit
