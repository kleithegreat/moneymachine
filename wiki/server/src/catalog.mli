(** Repository markdown discovery, safe path sanitization, and full-text search. *)

type doc_entry =
  { path : string
  ; title : string
  ; category : string
  ; size_bytes : int
  }
[@@deriving sexp_of, equal]

type search_hit =
  { path : string
  ; title : string
  ; category : string
  ; line_no : int
  ; snippet : string
  ; score : int
  }
[@@deriving sexp_of, equal]

val sanitize_rel_path : string -> (string, string) Result.t
val is_viewable_ext : string -> bool
val discover_docs : root:string -> doc_entry list
val search : root:string -> query:string -> search_hit list
val index_to_yojson : doc_entry list -> Yojson.Safe.t
val search_to_yojson : query:string -> search_hit list -> Yojson.Safe.t
