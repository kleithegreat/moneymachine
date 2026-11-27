open Core

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

let in_opt_list xs_opt x =
  match xs_opt with
  | None -> true
  | Some xs -> List.mem xs x ~equal:String.equal
;;

let polarity_matches filter p =
  match filter with
  | None -> true
  | Some target -> equal_polarity p target
;;

let admits view o =
  in_opt_list view.allowed_sources o.key.source
  && in_opt_list view.allowed_licenses o.license
  && view.min_quality <= o.quality
  && polarity_matches view.polarity_filter o.polarity
;;

let ranks_higher cand cur =
  if cur.known_at < cand.known_at
  then true
  else if cand.known_at < cur.known_at
  then false
  else if cur.revision_id < cand.revision_id
  then true
  else if cand.revision_id < cur.revision_id
  then false
  else cur.obs_id < cand.obs_id
;;

let pick_better cand = function
  | None -> Some cand
  | Some cur -> if ranks_higher cand cur then Some cand else Some cur
;;

let rec latest_revision rows view ~as_of key =
  match rows with
  | [] -> None
  | o :: rest ->
    let tail = latest_revision rest view ~as_of key in
    if equal_obs_key o.key key && o.known_at <= as_of && admits view o
    then pick_better o tail
    else tail
;;

let pit_latest rows view ~as_of key =
  match latest_revision rows view ~as_of key with
  | None -> None
  | Some o ->
    (match o.state with
     | Retracted -> None
     | Original | Restated -> Some o)
;;

let asof_candidate_valid all_rows view ~as_of ~left_event_time r =
  r.key.event_time <= left_event_time
  &&
  match pit_latest all_rows view ~as_of r.key with
  | None -> false
  | Some winner -> equal_obs winner r
;;

let pick_asof cand = function
  | None -> Some cand
  | Some cur -> if cur.key.event_time < cand.key.event_time then Some cand else Some cur
;;

let asof_match right_rows view ~as_of ~left_event_time =
  let rec loop = function
    | [] -> None
    | r :: rest ->
      let tail = loop rest in
      if asof_candidate_valid right_rows view ~as_of ~left_event_time r
      then pick_asof r tail
      else tail
  in
  loop right_rows
;;
