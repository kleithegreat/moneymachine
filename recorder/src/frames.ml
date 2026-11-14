open Core

type decoded =
  { data : string
  ; frames : int
  ; complete_bytes : int
  ; truncated : bool
  }
[@@deriving sexp_of]

let decode file =
  let total = String.length file in
  let out = Buffer.create total in
  let rec go ~pos ~frames =
    match Zstd.frame_size file ~pos with
    | None -> pos, frames
    | Some size ->
      let content = Zstd.decompress (String.sub file ~pos ~len:size) in
      Buffer.add_string out content;
      go ~pos:(pos + size) ~frames:(frames + 1)
  in
  let complete_bytes, frames = go ~pos:0 ~frames:0 in
  { data = Buffer.contents out; frames; complete_bytes; truncated = complete_bytes < total }
;;
