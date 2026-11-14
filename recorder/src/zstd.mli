(** zstd streams through one C stub file (RECORDER.md, Implementation: "zstd"). *)

type compressor

(** A level 9 compressor whose stream carries a content checksum (Storage: "Compression"). *)
val compressor : unit -> compressor

(** [compress c input ~ending] is the bytes that make [input] decodable: after a flush, everything fed so far
    decodes; with [~ending:true] the stream is complete and [c] is not used again. *)
val compress : compressor -> string -> ending:bool -> string

type reading

(** Reads a concatenation of zstd streams, fed in pieces. *)
val reader : unit -> reading

(** Passes [f] the content that [input] completes, in pieces of at most 128 KiB, so that memory does not grow with
    the compression ratio. Raises on bytes that are not zstd. *)
val feed : reading -> string -> f:(string -> unit) -> unit

(** Whether the bytes fed so far end exactly where a stream ends; true before any byte. A file cut anywhere else is
    truncated. *)
val at_frame_end : reading -> bool
