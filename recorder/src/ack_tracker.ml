open Core

let timeout_ms = 30_000

type t = (Sub.t, int) Hashtbl.Poly.t

let create () = Hashtbl.Poly.create ()
let sent t ~now_ms sub = Hashtbl.set t ~key:sub ~data:now_ms
let acked t sub = Hashtbl.remove t sub

let expired t ~now_ms =
  let due =
    Hashtbl.fold t ~init:[] ~f:(fun ~key ~data acc ->
      if now_ms - data >= timeout_ms then (data, key) :: acc else acc)
  in
  List.iter due ~f:(fun (_, sub) -> Hashtbl.remove t sub);
  List.sort due ~compare:[%compare: int * Sub.t] |> List.map ~f:snd
;;
