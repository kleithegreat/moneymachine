(* Brief 3, step 3 test 5: synthetic coin-day manifest checks only. *)

open Events_support
module R = Mm2_archive.Reader

let sql_string text = "'" ^ String.concat "''" (String.split_on_char '\'' text) ^ "'"

let contains text part =
  let rec search i =
    i + String.length part <= String.length text
    && (String.sub text i (String.length part) = part || search (i + 1))
  in
  search 0
;;

let with_archive_directory body =
  with_file ".dir" (fun sentinel ->
    let root = sentinel ^ "-files" in
    Unix.mkdir root 0o700;
    let rec remove_owned path =
      match (Unix.lstat path).st_kind with
      | Unix.S_DIR ->
        Array.iter
          (fun name -> remove_owned (Filename.concat path name))
          (Sys.readdir path);
        Unix.rmdir path
      | _ -> Unix.unlink path
    in
    Fun.protect ~finally:(fun () -> remove_owned root) (fun () -> body root))
;;

let with_manifest raw_hours source_hours body =
  with_archive_directory (fun root ->
    let path name = Filename.concat root name in
    List.iter
      (fun name -> Unix.mkdir (path name) 0o700)
      [ "raw"; "raw/20260403"; "snapshots"; "snapshots/A" ];
    List.iter
      (fun hour ->
         let directory = path (Printf.sprintf "raw/20260403/%d" hour) in
         Unix.mkdir directory 0o700;
         write (Filename.concat directory "A.lz4") "")
      raw_hours;
    let table = path "snapshots/A/20260403.parquet" in
    let metadata =
      match source_hours with
      | None -> ""
      | Some text -> ", KV_METADATA {source_hours: " ^ sql_string text ^ "}"
    in
    Mm2_archive.Duckdb.exec
      (Printf.sprintf
         "COPY (SELECT %Ld::BIGINT AS time, [99.0::DOUBLE] AS bid_px, [2.0::DOUBLE] AS \
          bid_sz, [101.0::DOUBLE] AS ask_px, [3.0::DOUBLE] AS ask_sz) TO %s (FORMAT \
          PARQUET%s)"
         base
         (sql_string table)
         metadata);
    body table (R.manifest root "A" "20260403"))
;;

let invalid_source_hours =
  [ "missing", None
  ; "invalid JSON", Some "not-json"
  ; "JSON non-list", Some "{}"
  ; "non-integer element", Some "[0,\"1\"]"
  ; "non-integer number", Some "[0,1.0]"
  ]
;;

let require_source_hours_error raw_hours =
  List.iter
    (fun (name, metadata) ->
       with_manifest raw_hours metadata (fun _ result ->
         match result with
         | Ok _ -> failwith (name ^ " source_hours: unverified table admitted")
         | Error message ->
           check
             (name ^ " metadata error must name source_hours, got: " ^ message)
             (contains message "source_hours")))
    invalid_source_hours
;;

let raw_present_requires_source_hours () = require_source_hours_error [ 0; 1 ]
let raw_absent_requires_source_hours () = require_source_hours_error []

let readable_source_hours_preserves_comparison () =
  let cases =
    [ [ 0; 1 ], "[0,1]", None
    ; [], "[]", None
    ; [ 0; 1 ], "[0]", Some "short of"
    ; [ 0; 1 ], "[]", Some "short of"
    ; [ 0; 1 ], "[0,2]", Some "differs from"
    ; [ 0; 1 ], "[0,1,2]", Some "differs from"
    ; [], "[0]", Some "differs from"
    ]
  in
  List.iter
    (fun (raw_hours, metadata, expected_error) ->
       with_manifest raw_hours (Some metadata) (fun table result ->
         match expected_error, result with
         | None, Ok (Some found) ->
           check "equal readable hours return the snapshot table" (found = table)
         | Some expected, Error message ->
           check
             ("readable " ^ metadata ^ " must report " ^ expected ^ ", got: " ^ message)
             (contains message expected)
         | None, Error message -> failwith ("equal readable hours rejected: " ^ message)
         | _ -> failwith ("unexpected manifest result for readable " ^ metadata)))
    cases
;;

let () =
  let tests =
    [ "raw_present_requires_source_hours", raw_present_requires_source_hours
    ; "raw_absent_requires_source_hours", raw_absent_requires_source_hours
    ; ( "readable_source_hours_preserves_comparison"
      , readable_source_hours_preserves_comparison )
    ]
  in
  let failures = ref [] in
  List.iter
    (fun (name, test) ->
       try
         test ();
         Printf.printf "%s: passed\n%!" name
       with
       | Failure message -> failures := (name ^ ": " ^ message) :: !failures)
    tests;
  match List.rev !failures with
  | [] -> ()
  | messages -> failwith (String.concat "\n" messages)
;;
