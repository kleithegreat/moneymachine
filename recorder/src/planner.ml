open Core

type kind =
  | Deep
  | Fast
[@@deriving sexp_of, compare, equal]

type t =
  { max_subscriptions : int
  ; first_deep : int
  ; held : Sub.t list array
  ; mutable total : int
  }

type outcome =
  | Added
  | Refused

let create ~connections ~max_subscriptions =
  if connections < 2 then invalid_argf "planner: %d connections, need at least 2" connections ();
  let deep = (connections + 3) / 4 in
  let held = Array.create ~len:connections [] in
  held.(0) <- [ Sub.All_dexs_asset_ctxs ];
  { max_subscriptions; first_deep = connections - deep; held; total = 1 }
;;

let kind t ~conn = if conn >= t.first_deep then Deep else Fast
let subs t ~conn = List.rev t.held.(conn)

let conn_of t sub =
  Array.findi t.held ~f:(fun _ held -> List.mem held sub ~equal:Sub.equal)
  |> Option.map ~f:fst
;;

let total t = t.total
let is_main coin = not (String.mem coin ':')

let least_loaded t ~kind:wanted ~f =
  let best = ref None in
  Array.iteri t.held ~f:(fun conn held ->
    if equal_kind (kind t ~conn) wanted
    then (
      match !best with
      | Some (_, load) when load <= List.count held ~f -> ()
      | _ -> best := Some (conn, List.count held ~f)));
  fst (Option.value_exn !best)
;;

let is_trades = function
  | Sub.Trades _ -> true
  | _ -> false
;;

let is_deep_book = function
  | Sub.L2_book _ -> true
  | _ -> false
;;

let place t conn subs =
  t.held.(conn) <- List.rev_append subs t.held.(conn);
  t.total <- t.total + List.length subs
;;

let add t ~coin =
  let cost = if is_main coin then 3 else 2 in
  if Option.is_some (conn_of t (Sub.Trades coin))
  then Added
  else if t.total + cost > t.max_subscriptions
  then Refused
  else (
    let fast = least_loaded t ~kind:Fast ~f:is_trades in
    place t fast [ Sub.Trades coin; Sub.L2_book_fast coin ];
    if is_main coin
    then (
      let deep = least_loaded t ~kind:Deep ~f:is_deep_book in
      place t deep [ Sub.L2_book coin ]);
    Added)
;;

let remove t ~coin =
  let dropped =
    List.filter_map [ Sub.Trades coin; Sub.L2_book_fast coin; Sub.L2_book coin ] ~f:(fun sub ->
      Option.map (conn_of t sub) ~f:(fun conn -> conn, sub))
  in
  List.iter dropped ~f:(fun (conn, sub) ->
    t.held.(conn) <- List.filter t.held.(conn) ~f:(fun held -> not (Sub.equal held sub));
    t.total <- t.total - 1);
  dropped
;;
