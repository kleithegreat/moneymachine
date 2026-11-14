open Core

type compressor
type decompressor

external compressor : unit -> compressor = "mmrec_zstd_cctx_create"
external compress_step : compressor -> string -> int -> bool -> int * string * int = "mmrec_zstd_compress_step"
external decompressor : unit -> decompressor = "mmrec_zstd_dctx_create"
external decompress_step : decompressor -> string -> int -> int * string * int = "mmrec_zstd_decompress_step"

let compress cctx input ~ending =
  let out = Buffer.create (String.length input / 4 + 64) in
  let rec go pos =
    let pos, chunk, remaining = compress_step cctx input pos ending in
    Buffer.add_string out chunk;
    if pos < String.length input || remaining > 0 then go pos
  in
  go 0;
  Buffer.contents out
;;

type reading =
  { dctx : decompressor
  ; mutable at_frame_end : bool
  }

let reader () = { dctx = decompressor (); at_frame_end = true }

let feed t input ~f =
  let cap = 131072 in
  let rec go pos =
    let pos, chunk, hint = decompress_step t.dctx input pos in
    if not (String.is_empty chunk) then f chunk;
    t.at_frame_end <- hint = 0;
    if pos < String.length input || String.length chunk = cap then go pos
  in
  if not (String.is_empty input) then go 0
;;

let at_frame_end t = t.at_frame_end
