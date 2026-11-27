open Core

type doc_entry =
  { path : string
  ; title : string
  ; category : string
  ; size_bytes : int
  }
[@@deriving sexp_of, equal]

type search_hit =
  { path : string
  ; title : string
  ; category : string
  ; line_no : int
  ; snippet : string
  ; score : int
  }
[@@deriving sexp_of, equal]

let skipped_any_depth = [ "_build"; "__pycache__"; "node_modules"; "result" ]

let viewable_exts =
  [ ".md"
  ; ".pdf"
  ; ".txt"
  ; ".yaml"
  ; ".yml"
  ; ".json"
  ; ".toml"
  ; ".lean"
  ; ".ml"
  ; ".mli"
  ; ".py"
  ; ".sh"
  ; ".tex"
  ; ".case"
  ]
;;

let is_skipped_segment ~is_top seg =
  String.is_empty seg
  || String.equal seg "."
  || String.equal seg ".."
  || String.is_prefix seg ~prefix:"."
  || List.mem skipped_any_depth seg ~equal:String.equal
  || String.is_prefix seg ~prefix:"target"
  || (is_top && String.equal seg "data")
;;

let sanitize_rel_path raw =
  if String.is_empty raw
  then Error "empty path"
  else if Char.equal raw.[0] '/' || String.mem raw '\000' || String.mem raw '\\'
  then Error (sprintf "invalid path syntax: %S" raw)
  else (
    let parts = String.split raw ~on:'/' in
    let bad =
      List.existsi parts ~f:(fun i seg -> is_skipped_segment ~is_top:(i = 0) seg)
    in
    if bad
    then Error (sprintf "blocked path segment: %S" raw)
    else Ok (String.concat ~sep:"/" parts))
;;

let is_viewable_ext path =
  let lower = String.lowercase path in
  List.exists viewable_exts ~f:(fun ext -> String.is_suffix lower ~suffix:ext)
;;

let category_of_path rel =
  if String.is_prefix rel ~prefix:"wiki/adrs/"
  then "ADRs"
  else if
    String.equal rel "wiki/quirks.md"
    || String.equal rel "wiki/operations.md"
    || String.equal rel "CLUSTER.md"
  then "Quirks & Ops"
  else if
    String.is_prefix rel ~prefix:"wiki/research/"
    || String.is_prefix rel ~prefix:"docs/"
    || String.is_prefix rel ~prefix:"pods/"
  then "Research"
  else if String.is_prefix rel ~prefix:"wiki/"
  then "Wiki"
  else if
    String.equal rel "AGENTS.md"
    || String.equal rel "CLAUDE.md"
    || String.equal rel "PROGRESS.md"
  then "Governance"
  else if String.is_prefix rel ~prefix:"subprojects/"
  then "Subprojects"
  else if
    String.is_prefix rel ~prefix:"recorder/"
    || String.is_prefix rel ~prefix:"ingest/"
    || String.is_prefix rel ~prefix:"fabric/"
  then "Systems & Fabric"
  else if String.is_prefix rel ~prefix:"audit/"
  then "Audit"
  else "Repo"
;;

let category_rank = function
  | "Wiki" -> 0
  | "Quirks & Ops" -> 1
  | "ADRs" -> 2
  | "Governance" -> 3
  | "Research" -> 4
  | "Systems & Fabric" -> 5
  | "Subprojects" -> 6
  | "Audit" -> 7
  | _ -> 8
;;

let extract_title path lines =
  let h1 =
    List.find_map lines ~f:(fun line ->
      let trimmed = String.strip line in
      Option.map (String.chop_prefix trimmed ~prefix:"# ") ~f:(fun s -> String.strip s))
  in
  match h1 with
  | Some t when not (String.is_empty t) -> t
  | Some _ | None ->
    (match
       List.find_map lines ~f:(fun line ->
         let trimmed = String.strip line in
         Option.map (String.chop_prefix trimmed ~prefix:"## ") ~f:(fun s ->
           String.strip s))
     with
     | Some t when not (String.is_empty t) -> t
     | Some _ | None -> Filename.basename path)
;;

let list_dir_sorted dir =
  try Sys_unix.ls_dir dir |> List.sort ~compare:String.compare with
  | Sys_error _ | Core_unix.Unix_error _ -> []
;;

let read_lines_safe path =
  try Some (In_channel.read_lines path) with
  | Sys_error _ | Core_unix.Unix_error _ -> None
;;

let file_size_safe path =
  try Int64.to_int_exn (Core_unix.stat path).st_size with
  | Sys_error _ | Core_unix.Unix_error _ -> 0
;;

let discover_docs ~root =
  let acc = ref [] in
  let rec walk rel_dir ~depth =
    let abs_dir =
      if String.is_empty rel_dir then root else Filename.concat root rel_dir
    in
    List.iter (list_dir_sorted abs_dir) ~f:(fun name ->
      if not (is_skipped_segment ~is_top:(depth = 0) name)
      then (
        let rel = if String.is_empty rel_dir then name else rel_dir ^ "/" ^ name in
        let abs = Filename.concat root rel in
        match Sys_unix.is_directory ~follow_symlinks:false abs with
        | `Yes -> walk rel ~depth:(depth + 1)
        | `No ->
          if String.is_suffix (String.lowercase name) ~suffix:".md"
          then (
            let lines = Option.value (read_lines_safe abs) ~default:[] in
            let title = extract_title rel lines in
            let category = category_of_path rel in
            let size_bytes = file_size_safe abs in
            acc := { path = rel; title; category; size_bytes } :: !acc)
        | `Unknown -> ()))
  in
  walk "" ~depth:0;
  List.sort !acc ~compare:(fun a b ->
    match Int.compare (category_rank a.category) (category_rank b.category) with
    | 0 -> String.compare a.path b.path
    | c -> c)
;;

let truncate_snippet s =
  let trimmed = String.strip s in
  if String.length trimmed <= 180 then trimmed else String.prefix trimmed 177 ^ "..."
;;

let search ~root ~query =
  let tokens =
    String.lowercase query
    |> String.split_on_chars ~on:[ ' '; '\t'; '\n'; '\r' ]
    |> List.filter ~f:(fun s -> not (String.is_empty s))
  in
  if List.is_empty tokens
  then []
  else (
    let docs = discover_docs ~root in
    let hits =
      List.filter_map docs ~f:(fun doc ->
        let abs = Filename.concat root doc.path in
        let path_low = String.lowercase doc.path in
        let title_low = String.lowercase doc.title in
        let header_score =
          List.sum
            (module Int)
            tokens
            ~f:(fun tok ->
              (if String.is_substring title_low ~substring:tok then 10 else 0)
              + if String.is_substring path_low ~substring:tok then 5 else 0)
        in
        let lines = Option.value (read_lines_safe abs) ~default:[] in
        let best_line =
          List.foldi lines ~init:None ~f:(fun idx best line ->
            let low = String.lowercase line in
            let hits_count =
              List.count tokens ~f:(fun tok -> String.is_substring low ~substring:tok)
            in
            let needed = if header_score > 0 then 1 else List.length tokens in
            if hits_count >= needed && hits_count > 0
            then (
              let score = (hits_count * 4) + header_score in
              match best with
              | None -> Some (score, idx + 1, truncate_snippet line)
              | Some (prev_score, _, _) when score > prev_score ->
                Some (score, idx + 1, truncate_snippet line)
              | Some _ -> best)
            else best)
        in
        match best_line with
        | Some (score, line_no, snippet) ->
          Some
            { path = doc.path
            ; title = doc.title
            ; category = doc.category
            ; line_no
            ; snippet
            ; score
            }
        | None
          when header_score > 0
               && List.for_all tokens ~f:(fun tok ->
                 String.is_substring title_low ~substring:tok
                 || String.is_substring path_low ~substring:tok) ->
          Some
            { path = doc.path
            ; title = doc.title
            ; category = doc.category
            ; line_no = 1
            ; snippet = doc.title
            ; score = header_score
            }
        | None -> None)
    in
    List.sort hits ~compare:(fun a b ->
      match Int.compare b.score a.score with
      | 0 -> String.compare a.path b.path
      | c -> c)
    |> Fn.flip List.take 50)
;;

let doc_to_yojson (d : doc_entry) =
  `Assoc
    [ "path", `String d.path
    ; "title", `String d.title
    ; "category", `String d.category
    ; "size_bytes", `Int d.size_bytes
    ]
;;

let index_to_yojson docs =
  `Assoc
    [ "count", `Int (List.length docs); "docs", `List (List.map docs ~f:doc_to_yojson) ]
;;

let hit_to_yojson (h : search_hit) =
  `Assoc
    [ "path", `String h.path
    ; "title", `String h.title
    ; "category", `String h.category
    ; "line_no", `Int h.line_no
    ; "snippet", `String h.snippet
    ; "score", `Int h.score
    ]
;;

let search_to_yojson ~query hits =
  `Assoc
    [ "query", `String query
    ; "count", `Int (List.length hits)
    ; "hits", `List (List.map hits ~f:hit_to_yojson)
    ]
;;
