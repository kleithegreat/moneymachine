module M = Mm2_lean.Machine
module I = Mm2_identity

let read_file path = In_channel.with_open_bin path In_channel.input_all

let write_file path text =
  Out_channel.with_open_bin path (fun c -> Out_channel.output_string c text)
;;

let usage () =
  prerr_endline
    "usage: mm2 check FILE | start PROGRAM HEADER STATE | feed STATE CHUNK | finish \
     STATE OUTDIR | inspect HEADER CHUNK";
  2
;;

let check path =
  match read_file path with
  | exception Sys_error message ->
    prerr_endline message;
    2
  | text ->
    let verdict = Mm2_lean.Check.program text in
    print_endline verdict;
    if String.starts_with ~prefix:"{\"ok\":true" verdict then 0 else 1
;;

let error_line code detail =
  print_endline
    (Yojson.Basic.to_string (`Assoc [ "error", `String code; "detail", `String detail ]));
  1
;;

let state_file program header =
  Printf.sprintf
    "%d\n%s\n%d\n%s\n"
    (String.length program)
    program
    (String.length header)
    header
;;

let start program_path header_path state_path =
  let program = read_file program_path
  and header = read_file header_path in
  match M.start program header with
  | Error code -> error_line code "start"
  | Ok _ ->
    write_file state_path (state_file program header);
    let build = I.embedded_build () in
    let identity =
      I.identity
        ~build
        ~windows:(I.embedded_windows ())
        ~inputs:[ "program", program; "header", header ]
    in
    print_endline
      (Yojson.Basic.to_string
         (`Assoc
             [ "ok", `Bool true; "build", `String build; "identity", `String identity ]));
    0
;;

let feed state_path chunk_path =
  let text = read_file chunk_path in
  match Yojson.Basic.from_string text with
  | exception Yojson.Json_error message -> error_line "R_MARKET" message
  | _ ->
    Out_channel.with_open_gen [ Open_append; Open_binary ] 0o600 state_path (fun c ->
      Out_channel.output_string c (Printf.sprintf "%d\n%s\n" (String.length text) text));
    print_endline "{\"ok\":true}";
    0
;;

let unhex text =
  Bytes.init
    (String.length text / 2)
    (fun i -> Char.chr (int_of_string ("0x" ^ String.sub text (2 * i) 2)))
;;

let chunk_of_json text : M.chunk =
  let open Yojson.Basic.Util in
  let j = Yojson.Basic.from_string text in
  { records = unhex (j |> member "records" |> to_string)
  ; integers =
      j
      |> member "integers"
      |> to_list
      |> List.map (fun v -> Int64.of_string (to_string v))
      |> Array.of_list
  ; doubles =
      j
      |> member "doubles"
      |> to_list
      |> List.map (fun v -> Int64.float_of_bits (Int64.of_string ("0x" ^ to_string v)))
      |> Array.of_list
  }
;;

let load state_path =
  let text = read_file state_path in
  let pos = ref 0 in
  let section () =
    let eol = String.index_from text !pos '\n' in
    let len = int_of_string (String.sub text !pos (eol - !pos)) in
    let body = String.sub text (eol + 1) len in
    pos := eol + 1 + len + 1;
    body
  in
  let program = section () in
  let header = section () in
  let chunks = ref [] in
  while !pos < String.length text do
    chunks := section () :: !chunks
  done;
  program, header, List.rev !chunks
;;

let finish state_path out_dir =
  let program, header, chunks = load state_path in
  match M.start program header with
  | Error code -> error_line code "start"
  | Ok state ->
    let report = Buffer.create 4096
    and trace = Buffer.create 4096 in
    let state =
      List.fold_left
        (fun state text ->
           let next, rows = M.feed state (chunk_of_json text) in
           Buffer.add_string report rows.report;
           Buffer.add_string trace rows.trace;
           next)
        state
        chunks
    in
    let last, summary = M.finish state in
    Buffer.add_string report last.report;
    Buffer.add_string trace last.trace;
    print_endline summary;
    if Yojson.Basic.Util.member "ok" (Yojson.Basic.from_string summary) = `Bool true
    then (
      write_file (Filename.concat out_dir "report.tsv") (Buffer.contents report);
      write_file (Filename.concat out_dir "trace.tsv") (Buffer.contents trace);
      0)
    else 1
;;

let inspect header_path chunk_path =
  let text = read_file chunk_path in
  match M.inspect (read_file header_path) (chunk_of_json text) with
  | Error code -> error_line code "inspect"
  | Ok found ->
    let fields =
      match Yojson.Basic.from_string found with
      | `Assoc f -> f
      | _ -> []
    in
    let sha = Digestif.SHA256.to_hex (Digestif.SHA256.digest_string text) in
    print_endline
      (Yojson.Basic.to_string
         (`Assoc ([ "size", `Int (String.length text); "sha256", `String sha ] @ fields)));
    0
;;

let () =
  let code =
    match Array.to_list Sys.argv with
    | [ _; "check"; path ] -> check path
    | [ _; "start"; program; header; state ] -> start program header state
    | [ _; "feed"; state; chunk ] -> feed state chunk
    | [ _; "finish"; state; out ] -> finish state out
    | [ _; "inspect"; header; chunk ] -> inspect header chunk
    | _ -> usage ()
  in
  exit code
;;
