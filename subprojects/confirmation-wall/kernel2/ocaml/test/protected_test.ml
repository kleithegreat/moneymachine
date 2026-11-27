(* Assumed interface: Engine.Machine/Mm2_lean.Machine start/feed/finish and
   A18 arrays/A19 rows as events_support.ml; mm2 start PROGRAM HEADER STATE,
   feed STATE CHUNK_JSON, finish STATE OUTDIR, inspect HEADER CHUNK_JSON.
   inspect's only keys are size,sha256,records,stale; it never prints values.
    Reader is mm2_archive.Reader (double-preserving archive reader);
    protected-windows.json is compiled strict data at
   kernel2/protected-windows.json: [{start:integer-ms,end:integer-ms,released:bool}].
   Mm2_identity build/identity/embedded_* and compile_windows are specified in
   events_support.ml. Test 2 checks the actual CLI and compiled policy, not an
   injected policy; the companion script also checks real isolated builds.
   Synthetic protected-date fixtures are NOT protected recordings. *)

open Events_support
module I = Mm2_identity

let refused_start market =
  match M.start program market with
  | Error code -> check "start protected code" (code = "R_PROTECTED")
  | Ok _ -> failwith "protected horizon admitted"
;;

let check_source_manifest sources =
  let suffix = "/kernel2/lean/.lake/build/lib/libengine_Engine.a" in
  let library = Sys.getenv "MM2_ENGINE_LIB" in
  check "real engine library path" (String.ends_with ~suffix library);
  let root = String.sub library 0 (String.length library - String.length suffix) in
  let rec walk relative =
    let path = Filename.concat root relative in
    if Sys.is_directory path
    then
      Sys.readdir path
      |> Array.to_list
      |> List.filter (fun name -> name <> ".lake" && name <> "_build")
      |> List.concat_map (fun name -> walk (relative ^ "/" ^ name))
    else [ relative ]
  in
  let required =
    List.concat_map walk [ "kernel2/lean"; "kernel2/ocaml/src"; "kernel2/ocaml/bin" ]
    @ [ "kernel2/ocaml/dune-project" ]
  in
  List.iter
    (fun path ->
       check ("source omitted from build: " ^ path) (List.mem_assoc path sources);
       check
         ("manifest contains real source bytes: " ^ path)
         (List.assoc path sources = read (Filename.concat root path)))
    required
;;

let policy_and_identity () =
  List.iter
    (fun (first, last) -> refused_start (header ~first ~last ()))
    [ Int64.sub protected_start 1L, Int64.add protected_start 1L
    ; protected_start, Int64.add protected_start 1L
    ; Int64.sub protected_end 1L, protected_end
    ; base, Int64.add protected_end 1L
    ];
  List.iter
    (fun (first, last) -> ignore (get (M.start program (header ~first ~last ())) : M.t))
    [ Int64.sub protected_start 1000L, protected_start
    ; protected_end, Int64.add protected_end 1000L
    ];
  List.iter
    (fun market ->
       List.iter
         (fun time -> rejection ~market "R_PROTECTED" [ [ quote time ]; [ quote base ] ])
         [ protected_start; Int64.sub protected_end 1L ])
    [ header (); header ~first:protected_end ~last:(Int64.add protected_end 1000L) () ];
  List.iter
    (fun extra ->
       let original = json (header ()) in
       let changed =
         match original with
         | `Assoc fields -> `Assoc (extra :: fields)
         | _ -> assert false
       in
       check
         "header cannot alter policy"
         (match M.start program (Yojson.Basic.to_string changed) with
          | Error _ -> true
          | Ok _ -> false))
    [ "released", `Bool true
    ; "protected_windows", `List []
    ; "allow_protected", `Bool true
    ; "build", `String "anything"
    ];
  let valid =
    Printf.sprintf
      {|[{"start":%Ld,"end":%Ld,"released":false}]|}
      protected_start
      protected_end
  in
  ignore (get (I.compile_windows valid) : string);
  List.iter
    (fun invalid ->
       check "strict build-time window data" (Result.is_error (I.compile_windows invalid)))
    [ "import os"
    ; "null"
    ; "{}"
    ; "[true]"
    ; {|[{"start":0,"end":1,"released":false,"code":"release everything"}]|}
    ; {|[{"start":0,"end":1}]|}
    ; {|[{"start":"0","end":1,"released":false}]|}
    ; {|[{"start":0,"end":1,"released":0}]|}
    ; {|[{"start":0,"end":1,"released":false,"released":true}]|}
    ; {|[{"start":1,"end":1,"released":false}]|}
    ; {|[{"start":2,"end":1,"released":false}]|}
    ];
  let sources = I.embedded_sources () in
  let toolchain = I.embedded_toolchain () in
  let windows = I.embedded_windows () in
  check "real source manifest not empty" (List.length sources >= 5);
  check "real compiler AND library paths hashed" (List.length toolchain >= 4);
  List.iter
    (fun path ->
       check
         "store path not compiler version text"
         (String.starts_with ~prefix:"/nix/store/" path))
    toolchain;
  let build = I.build ~sources ~toolchain in
  check "embedded build derived from actual inputs" (build = I.embedded_build ());
  let source_paths = List.map fst sources in
  check "Lean source included" (List.mem "kernel2/lean/Engine/Exact.lean" source_paths);
  check "C boundary included" (List.mem "kernel2/ocaml/src/stubs.c" source_paths);
  check_source_manifest sources;
  List.iter
    (fun (path, _) ->
       let changed =
         List.map (fun (p, b) -> p, if p = path then b ^ " " else b) sources
       in
       if path = "kernel2/protected-windows.json"
       then
         check
           "policy excluded only from build"
           (I.build ~sources:changed ~toolchain = build)
       else
         check
           ("one byte changes build: " ^ path)
           (I.build ~sources:changed ~toolchain <> build))
    sources;
  List.iteri
    (fun i path ->
       let changed = List.mapi (fun j p -> if i = j then path ^ "x" else p) toolchain in
       check
         "every compiler/library path changes build"
         (I.build ~sources ~toolchain:changed <> build))
    toolchain;
  let released =
    match json windows with
    | `List entries ->
      `List
        (List.map
           (function
             | `Assoc fields ->
               `Assoc
                 (List.map
                    (fun (key, value) ->
                       key, if key = "released" then `Bool true else value)
                    fields)
             | _ -> failwith "bad embedded policy")
           entries)
      |> Yojson.Basic.to_string
    | _ -> failwith "bad embedded policy"
  in
  let identity =
    I.identity ~build ~windows ~inputs:[ "program", program; "header", header () ]
  in
  check
    "a release changes identity"
    (I.identity
       ~build
       ~windows:released
       ~inputs:[ "program", program; "header", header () ]
     <> identity);
  check
    "no change is deterministic"
    (I.identity ~build ~windows ~inputs:[ "program", program; "header", header () ]
     = identity);
  let extra = sources @ [ "kernel2/test/protected-windows.json", valid ] in
  check "no basename-only exclusion" (I.build ~sources:extra ~toolchain <> build)
;;

let with_directory body =
  with_file ".dir" (fun sentinel ->
    let directory = sentinel ^ "-files" in
    Unix.mkdir directory 0o700;
    let rec remove_owned path =
      match (Unix.lstat path).st_kind with
      | Unix.S_DIR ->
        Array.iter
          (fun name -> remove_owned (Filename.concat path name))
          (Sys.readdir path);
        Unix.rmdir path
      | _ -> Unix.unlink path
    in
    Fun.protect ~finally:(fun () -> remove_owned directory) (fun () -> body directory))
;;

let captured executable arguments =
  with_file ".stdout" (fun stdout_path ->
    with_file ".stderr" (fun stderr_path ->
      let stdout = Unix.openfile stdout_path [ Unix.O_WRONLY; Unix.O_TRUNC ] 0o600 in
      let stderr = Unix.openfile stderr_path [ Unix.O_WRONLY; Unix.O_TRUNC ] 0o600 in
      let pid =
        Unix.create_process
          executable
          (Array.of_list (executable :: arguments))
          Unix.stdin
          stdout
          stderr
      in
      Unix.close stdout;
      Unix.close stderr;
      let _, status = Unix.waitpid [] pid in
      status, read stdout_path, read stderr_path))
;;

let cli executable build_script =
  with_directory (fun dir ->
    let path name = Filename.concat dir name in
    write (path "program") program;
    write (path "header") (header ());
    write (path "chunk") (chunk_json (chunk [ quote base; quote protected_start ]));
    let status, text =
      command executable [ "start"; path "program"; path "header"; path "state" ]
    in
    check
      "CLI start succeeds on safe horizon"
      (status = Unix.WEXITED 0 && field "ok" (json text) = `Bool true);
    let _, feed_status = command executable [ "feed"; path "state"; path "chunk" ] in
    let status_fields =
      match json feed_status with
      | `Assoc fields -> List.map fst fields
      | _ -> []
    in
    check
      "feed never publishes spool rows"
      (status_fields <> []
       && List.for_all
            (fun key -> List.mem key [ "ok"; "error"; "time"; "detail" ])
            status_fields);
    let status, text = command executable [ "finish"; path "state"; dir ] in
    check
      "CLI finish reports sticky rejection"
      (status = Unix.WEXITED 1 && text_field "error" (json text) = "R_PROTECTED");
    check "no published report after reject" (not (Sys.file_exists (path "report.tsv")));
    check "no published trace after reject" (not (Sys.file_exists (path "trace.tsv")));
    let first = protected_start in
    let last = Int64.add first 120_000L in
    write (path "protected-header") (header ~first ~last ());
    let time = Int64.add first 1000L in
    write
      (path "protected-chunk")
      (chunk_json
         (chunk
            [ trade ~price:"123.45" time 987654321
            ; quote ~bid:"123.4" ~ask:"123.5" time
            ; trade ~price:"123.45" (Int64.add first 61_000L) 987654322
            ]));
    let status, text, stderr =
      captured executable [ "inspect"; path "protected-header"; path "protected-chunk" ]
    in
    check "inspect admits integrity inspection" (status = Unix.WEXITED 0);
    check "inspect cannot leak values through stderr" (stderr = "");
    let result = json text in
    let keys =
      match result with
      | `Assoc fields -> List.sort String.compare (List.map fst fields)
      | _ -> []
    in
    check
      "inspect metadata allowlist, no rows or prices"
      (keys = [ "records"; "sha256"; "size"; "stale" ]);
    check
      "inspect true file size"
      (int_field "size" result = String.length (read (path "protected-chunk")));
    check "inspect counts every record" (int_field "records" result = 3);
    let status, hash = command "sha256sum" [ path "protected-chunk" ] in
    check "hash oracle available" (status = Unix.WEXITED 0);
    check
      "inspect true SHA256"
      (text_field "sha256" result = List.hd (String.split_on_char ' ' hash));
    let spans = field "stale" result |> Yojson.Basic.Util.to_list in
    List.iter
      (fun span ->
         match span with
         | `Assoc fields ->
           check
             "no values hidden inside stale metadata"
             (List.sort String.compare (List.map fst fields) = [ "coin"; "end"; "start" ])
         | _ -> failwith "stale metadata is not a span")
      spans;
    let interval coin start stop =
      List.exists
        (fun span ->
           text_field "coin" span = coin
           && field "start" span = `Int (Int64.to_int start)
           && field "end" span = `Int (Int64.to_int stop))
        spans
    in
    check "inspect stale before first quote" (interval "A" first time);
    check
      "inspect stale from last quote plus G"
      (interval "A" (Int64.add first 61_000L) last);
    check "inspect stale throughout unquoted coin" (interval "B" first last);
    List.iter
      (fun (subcommand, args) ->
         List.iter
           (fun option ->
              let status, text =
                command executable ((subcommand :: args) @ [ option; "true" ])
              in
              check "no override option accepted" (status = Unix.WEXITED 2);
              check "bad options reveal no values" (String.trim text = ""))
           [ "--release"; "--allow-protected"; "--protected-windows"; "--unsafe" ])
      [ "start", [ path "program"; path "protected-header"; path "other-state" ]
      ; "feed", [ path "state"; path "protected-chunk" ]
      ; "finish", [ path "state"; dir ]
      ; "inspect", [ path "protected-header"; path "protected-chunk" ]
      ];
    let status, output =
      command
        "sh"
        [ build_script
        ; executable
        ; path "program"
        ; path "header"
        ; path "protected-header"
        ]
    in
    check ("build mutation tests: " ^ output) (status = Unix.WEXITED 0))
;;

let () =
  check "usage: protected_test MM2 BUILD_SCRIPT" (Array.length Sys.argv = 3);
  policy_and_identity ();
  cli Sys.argv.(1) Sys.argv.(2);
  print_endline "step3 protected: test 2 passed"
;;
