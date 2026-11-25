(** Reading a recording file as a stream, in memory independent of its size (RECORDER.md, Storage: "Compression";
    Interface: "Both read as a stream"). *)

type state =
  | Complete (** clean zstd frame end with valid checksum and trailing ['\n'] *)
  | Cut (** 0-byte file or clean decompression prefix cut mid-frame/mid-line at EOF *)
  | Malformed
  (** clean zstd frame end whose decompressed bytes are empty or lack trailing ['\n'] *)
  | Corrupt (** zstd decompression error, bad checksum, or invalid magic header *)
[@@deriving sexp_of, compare, equal]

val state_to_string : state -> string
val worst_state : state -> state -> state

(** [fold_lines path ~init ~f] inspects the stream in O(1) memory and classifies it into one of four states.
    For [Complete], [Cut], and [Malformed], it folds [f] over every whole line (newline removed), dropping any
    trailing partial line. For [Corrupt], it feeds zero lines and returns [(init, Corrupt)]. *)
val fold_lines : string -> init:'a -> f:('a -> string -> 'a) -> 'a * state
