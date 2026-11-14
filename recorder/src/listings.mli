(** Reading the hourly REST listings (RECORDER.md, What it records, item 1). *)

type perp =
  { coin : string
  ; delisted : bool
  }
[@@deriving sexp_of, equal]

(** The dex names in a [perpDexs] response, the main dex first as [""]. *)
val dex_names : string -> string list

(** The perps in a [meta] response's [universe], coin names as the API gives them; [delisted] is its
    [isDelisted] flag. *)
val perps : string -> perp list

(** The coins that are listed and not delisted, in the order given. *)
val active : perp list -> string list
