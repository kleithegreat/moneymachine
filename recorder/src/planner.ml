open Core

type t =
  { max_subscriptions : int
  ; held : Sub.t list array
  ; mutable total : int
  }

type outcome =
  | Added
  | Refused

let create ~connections ~max_subscriptions =
  let held = Array.create ~len:connections [] in
  held.(0) <- [ Sub.All_dexs_asset_ctxs ];
  { max_subscriptions; held; total = 1 }
;;

let subs t ~conn = List.rev t.held.(conn)

let conn_of t sub =
  Array.findi t.held ~f:(fun _ held -> List.mem held sub ~equal:Sub.equal)
  |> Option.map ~f:fst
;;

let total t = t.total

let l2_count held =
  List.count held ~f:(function
    | Sub.L2_book _ -> true
    | _ -> false)
;;

let fewest_l2 t =
  let best = ref 0 in
  Array.iteri t.held ~f:(fun conn held ->
    if l2_count held < l2_count t.held.(!best) then best := conn);
  !best
;;

let add t ~coin =
  if Option.is_some (conn_of t (Sub.Trades coin))
  then Added
  else if t.total + 2 > t.max_subscriptions
  then Refused
  else (
    let conn = fewest_l2 t in
    t.held.(conn) <- Sub.L2_book coin :: Sub.Trades coin :: t.held.(conn);
    t.total <- t.total + 2;
    Added)
;;

let remove t ~coin =
  match conn_of t (Sub.Trades coin) with
  | None -> []
  | Some conn ->
    let dropped = [ Sub.Trades coin; Sub.L2_book coin ] in
    t.held.(conn)
    <- List.filter t.held.(conn) ~f:(fun sub -> not (List.mem dropped sub ~equal:Sub.equal));
    t.total <- t.total - 2;
    List.map dropped ~f:(fun sub -> conn, sub)
;;
