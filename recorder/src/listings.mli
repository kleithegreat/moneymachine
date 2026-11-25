(** Reading the hourly REST listings (RECORDER.md, What it records, item 1). *)

type perp =
  { coin : string
  ; delisted : bool
  }
[@@deriving sexp_of, equal]

(** The dex names in a [perpDexs] response, the main dex first as [""]. Raises [Failure] naming the request unless the
    response is an array whose first element is [null] and whose others are objects with a string [name]. *)
val dex_names : string -> string list

(** The perps in a [meta] response's [universe], coin names as the API gives them; [delisted] is its
    [isDelisted] flag. Raises [Failure] naming the request unless the response is an object whose [universe] is an array
    of objects with a string [name]. *)
val perps : string -> perp list

(** [perps] of the response to dex [dex]'s [meta], whose every coin must be that dex's: no [:] on the main dex [""],
    and beginning [<dex>:] on any other. Raises [Failure] otherwise: another dex's universe would be read as this
    one's. *)
val dex_perps : dex:string -> string -> perp list

(** Raises [Failure] naming the request unless a [spotMeta] response is an object with arrays [universe] and
    [tokens]. *)
val check_spot_meta : string -> unit

(** The coins that are listed and not delisted, in the order given. *)
val active : perp list -> string list

(** [held ~before perps] is the coins held after a whole read of [perps] (all dexes) when [before] were held: [before]
    but for the coins the read flags delisted, then the read's coins that are listed and not held. A coin the read
    omits stays held: only the flag delists (RECORDER.md, What it records, item 1). *)
val held : before:string list -> perp list -> string list
