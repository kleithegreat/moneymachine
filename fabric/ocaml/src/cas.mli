(** Content-addressable Zstd blob store matching [fabric/cas.py] on disk. *)

open! Core

type record =
  { sha256 : string
  ; uri : string
  ; byte_size : int
  ; compressed_size : int
  ; existed : bool
  }
[@@deriving sexp_of, equal]

val sha256_hex : string -> string
val path_for : root:string -> digest:string -> (string, string) Result.t
val uri_for : ?uri_prefix:string -> root:string -> string -> (string, string) Result.t
val exists : root:string -> digest:string -> bool

val put
  :  ?uri_prefix:string
  -> ?level:int
  -> root:string
  -> string
  -> (record, string) Result.t

val get : root:string -> string -> (string, string) Result.t
val verify : root:string -> string -> bool
val to_yojson : record -> Yojson.Safe.t
