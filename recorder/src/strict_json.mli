(** Strict RFC 8259 UTF-8 JSON validation bounded to nesting depth 64 (RECORDER.md, What it records, item 1). *)

(** [check text] is [Ok ()] when [text] is one RFC 8259 JSON value in valid UTF-8 with nesting depth at most 64
    (no BOM, no comments, no [NaN]/[Infinity], no lone surrogates, no trailing tokens), and a fixed error message
    quoting no input bytes otherwise. *)
val check : string -> (unit, string) result
