(** Bitemporal PIT and ASOF causal core mirroring [fabric/lean/Fabric/Causal.lean]. *)

type polarity =
  | Obs
  | Fcst
  | Sched
[@@deriving sexp_of, equal, quickcheck]

type revision_state =
  | Original
  | Restated
  | Retracted
[@@deriving sexp_of, equal, quickcheck]

type obs_key =
  { entity : string
  ; source : string
  ; metric : string
  ; event_time : int
  }
[@@deriving sexp_of, equal, quickcheck]

type obs =
  { key : obs_key
  ; known_at : int
  ; revision_id : int
  ; obs_id : int
  ; state : revision_state
  ; polarity : polarity
  ; quality : int
  ; license : string
  }
[@@deriving sexp_of, equal, quickcheck]

type pod_view =
  { allowed_sources : string list option
  ; allowed_licenses : string list option
  ; min_quality : int
  ; polarity_filter : polarity option
  }
[@@deriving sexp_of, equal, quickcheck]

val admits : pod_view -> obs -> bool
val latest_revision : obs list -> pod_view -> as_of:int -> obs_key -> obs option
val pit_latest : obs list -> pod_view -> as_of:int -> obs_key -> obs option
val asof_match : obs list -> pod_view -> as_of:int -> left_event_time:int -> obs option
