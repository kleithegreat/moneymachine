external compress : string -> string = "mmrec_zstd_compress"
external frame_size_raw : string -> int -> int = "mmrec_zstd_frame_size"
external decompress : string -> string = "mmrec_zstd_decompress"

let frame_size s ~pos =
  let size = frame_size_raw s pos in
  if size < 0 then None else Some size
;;
