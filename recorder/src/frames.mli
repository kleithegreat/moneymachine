(** Reading a recording file: a concatenation of zstd frames (RECORDER.md, Storage: "Compression"). *)

type decoded =
  { data : string  (** the concatenated content of every complete frame *)
  ; frames : int  (** the number of complete frames *)
  ; complete_bytes : int  (** the bytes the complete frames take *)
  ; truncated : bool  (** whether bytes remain after the last complete frame *)
  }
[@@deriving sexp_of]

(** Decodes every complete frame before the first incomplete or invalid byte and reports the cut. The empty
    string decodes to no frames, not truncated. *)
val decode : string -> decoded
