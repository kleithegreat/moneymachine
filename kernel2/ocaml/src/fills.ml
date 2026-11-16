type fill = {
  coin : string;
  px : string;
  sz : string;
  side : string;
  time : int64;
  start_position : string;
  dir : string;
  closed_pnl : string;
  hash : string;
  oid : int64;
  crossed : bool;
  fee : string;
  tid : int64;
  fee_token : string;
}

module Json = Yojson.Safe.Util

let int64 name json =
  match Json.member name json with
  | `Int n -> Int64.of_int n
  | `Intlit text -> Int64.of_string text
  | _ -> failwith ("expected an integer " ^ name)

let parse json =
  let string name = Json.to_string (Json.member name json) in
  { coin = string "coin"; px = string "px"; sz = string "sz"; side = string "side";
    time = int64 "time" json; start_position = string "startPosition";
    dir = string "dir"; closed_pnl = string "closedPnl"; hash = string "hash";
    oid = int64 "oid" json; crossed = Json.to_bool (Json.member "crossed" json);
    fee = string "fee"; tid = int64 "tid" json; fee_token = string "feeToken" }

let is_page name =
  String.starts_with ~prefix:"fills-" name && String.ends_with ~suffix:".json" name

let read_directory directory =
  try
    let pages =
      Sys.readdir directory |> Array.to_list |> List.filter is_page |> List.sort String.compare
    in
    let unique = Hashtbl.create 8192 in
    List.iter
      (fun page ->
        let rows = Yojson.Safe.from_file (Filename.concat directory page) |> Json.to_list in
        List.iter
          (fun json ->
            let row = parse json in
            match Hashtbl.find_opt unique row.tid with
            | None -> Hashtbl.add unique row.tid row
            | Some earlier ->
              if earlier <> row then failwith ("conflicting copies of tid " ^ Int64.to_string row.tid))
          rows)
      pages;
    let rows = Hashtbl.fold (fun _ row rows -> row :: rows) unique [] in
    let order a b =
      let by_time = Int64.compare a.time b.time in
      if by_time <> 0 then by_time else Int64.compare a.tid b.tid
    in
    Ok (List.sort order rows)
  with
  | Failure text | Sys_error text -> Error text
  | Yojson.Json_error text -> Error text
  | Json.Type_error (text, _) -> Error text
