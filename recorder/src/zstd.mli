(** zstd through one C stub file (RECORDER.md, Implementation: "zstd"). *)

(** One zstd frame holding the input, level 3 (Storage: "Compression"). *)
val compress : string -> string

(** [frame_size s ~pos] is the byte length of the complete frame starting at [pos], or [None] if the bytes there
    are not a whole frame (Storage: a truncated last frame is detectable). *)
val frame_size : string -> pos:int -> int option

(** The content of a complete frame; raises on anything else. Needed by [mmrec cat] and [mmrec check]. *)
val decompress : string -> string
