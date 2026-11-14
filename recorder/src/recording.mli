(** Reading a recording file as a stream, in memory independent of its size (RECORDER.md, Storage: "Compression";
    Interface: "Both read as a stream"). *)

(** [fold_lines path ~init ~f] folds [f] over the whole lines of the file, newline removed, and reports whether
    the file is truncated: its last stream was never ended, or its bytes are not zstd. A partial line at the cut is
    dropped. *)
val fold_lines : string -> init:'a -> f:('a -> string -> 'a) -> 'a * bool
