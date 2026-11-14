open Core

type perp =
  { coin : string
  ; delisted : bool
  }
[@@deriving sexp_of, equal]

let dex_names response =
  match Yojson.Safe.from_string response with
  | `List entries ->
    List.map entries ~f:(function
      | `Null -> ""
      | entry -> Yojson.Safe.Util.(entry |> member "name" |> to_string))
  | _ -> failwith "perpDexs: not a list"
;;

let perps response =
  let open Yojson.Safe.Util in
  Yojson.Safe.from_string response
  |> member "universe"
  |> to_list
  |> List.map ~f:(fun asset ->
    { coin = asset |> member "name" |> to_string
    ; delisted = Poly.equal (member "isDelisted" asset) (`Bool true)
    })
;;

let active perps =
  List.filter_map perps ~f:(fun perp -> if perp.delisted then None else Some perp.coin)
;;
