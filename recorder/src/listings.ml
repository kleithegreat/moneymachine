open Core

type perp =
  { coin : string
  ; delisted : bool
  }
[@@deriving sexp_of, equal]

let invalid request why = failwithf "%s: %s" request why ()

let parse request response =
  match Yojson.Safe.from_string response with
  | json -> json
  | exception Yojson.Json_error _ -> invalid request "not JSON"
;;

let field name = function
  | `Assoc fields -> List.Assoc.find fields ~equal:String.equal name
  | _ -> None
;;

let name_of request entry =
  match field "name" entry with
  | Some (`String name) -> name
  | Some _ | None -> invalid request "an entry has no string name"
;;

let dex_names response =
  match parse "perpDexs" response with
  | `List (`Null :: dexes) -> "" :: List.map dexes ~f:(name_of "perpDexs")
  | _ -> invalid "perpDexs" "not an array whose first element is null"
;;

let perps response =
  match field "universe" (parse "meta" response) with
  | Some (`List assets) ->
    List.map assets ~f:(fun asset ->
      { coin = name_of "meta" asset
      ; delisted = Poly.equal (field "isDelisted" asset) (Some (`Bool true))
      })
  | Some _ | None -> invalid "meta" "universe is not an array"
;;

let owns ~dex coin =
  match String.lsplit2 coin ~on:':' with
  | None -> String.is_empty dex && not (String.is_empty coin)
  | Some (prefix, rest) ->
    (not (String.is_empty dex)) && String.equal prefix dex && not (String.is_empty rest)
;;

let dex_perps ~dex response =
  let perps = perps response in
  List.iter perps ~f:(fun perp ->
    if not (owns ~dex perp.coin)
    then invalid "meta" (sprintf "a coin does not belong to dex %S" dex));
  perps
;;

let check_spot_meta response =
  let json = parse "spotMeta" response in
  List.iter [ "universe"; "tokens" ] ~f:(fun key ->
    match field key json with
    | Some (`List _) -> ()
    | Some _ | None -> invalid "spotMeta" (key ^ " is not an array"))
;;

let active perps =
  List.filter_map perps ~f:(fun perp -> if perp.delisted then None else Some perp.coin)
;;

let held ~before perps =
  let flagged =
    List.filter_map perps ~f:(fun perp -> Option.some_if perp.delisted perp.coin)
  in
  let kept =
    List.filter before ~f:(fun coin -> not (List.mem flagged coin ~equal:String.equal))
  in
  let fresh =
    List.filter (active perps) ~f:(fun coin ->
      not (List.mem before coin ~equal:String.equal))
  in
  kept @ fresh
;;
