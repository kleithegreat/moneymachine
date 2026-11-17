(* Brief 3 step 5 test 13: generate, hash and store the NEW B4 reference.
   Test-side executable, no engine interface or implementation change required.
   Usage: x4_reference_local.exe FROZEN_SOURCE SOURCE_HASH OLD_DIR NEW_DIR [AUDIT_DIR].
   FROZEN_SOURCE/SOURCE_SHA256SUMS is supplied and certified by the advisor;
   SOURCE_HASH is its externally pinned SHA256, not a hash this test invents.
   scripts/x4-reference.sh builds the frozen refmm with ONLY exp/log linked to
   test 12's MPFR stub. OLD_DIR is read-only stage-6 evidence (never rerun).
   NEW_DIR must not exist. Programs are the frozen corpus's original DSL v1,
   markets are OLD_DIR's unmodified exports. Outputs use b4_local's layout.
   No new Python/Rust, no changed lock or source evaluator, no exempted items.
   b4_local.exe NEW_DIR OLD_DIR then judges every item and prints the two reports. *)

open Events_support
module J = Yojson.Safe

let member = J.Util.member
let string value = J.Util.to_string value
let items value = J.Util.to_list value
let path = Filename.concat
let shell command = check ("command failed: " ^ command) (Sys.command command = 0)
let quote = Filename.quote

let sha file =
  let status, out = command "sha256sum" [ file ] in
  check "sha256sum" (status = Unix.WEXITED 0);
  List.hd (String.split_on_char ' ' out)
;;

let copy source destination = write destination (read source)

let () =
  let source, source_hash, old_dir, new_dir, audit =
    match Array.to_list Sys.argv with
    | [ _; source; hash; old_dir; new_dir ] ->
      source, hash, old_dir, new_dir, "audit/stage6"
    | [ _; source; hash; old_dir; new_dir; audit ] ->
      source, hash, old_dir, new_dir, audit
    | _ ->
      failwith
        "usage: x4_reference_local.exe SOURCE SOURCE_HASH OLD_DIR NEW_DIR [AUDIT_DIR]"
  in
  check "new reference directory must be fresh" (not (Sys.file_exists new_dir));
  check
    "externally pinned frozen source"
    (sha (path source "SOURCE_SHA256SUMS") = source_hash);
  shell ("cd " ^ quote old_dir ^ " && sha256sum -c --quiet SHA256SUMS");
  shell ("mkdir -p " ^ quote new_dir);
  let build = path new_dir "build" in
  let status, out =
    command
      "sh"
      [ "kernel2/ocaml/test/scripts/x4-reference.sh"; source; source_hash; build ]
  in
  check "build the frozen MPFR reference" (status = Unix.WEXITED 0);
  let executable = String.trim out in
  let corpus_path = path audit "c64-corpus.jsonl" in
  let corpus_manifest = J.from_file (path audit "c64-manifest.json") in
  check
    "frozen corpus hash"
    (sha corpus_path = string (member "corpus_sha256" corpus_manifest));
  let corpus = List.map J.from_string (lines (read corpus_path)) in
  List.iter
    (fun market ->
       let old_out = path (path old_dir "out") market in
       let new_out = path (path new_dir "out") market in
       shell ("mkdir -p " ^ quote new_out);
       let mk =
         match
           List.filter
             (fun name ->
                Filename.check_suffix name ".json"
                && String.starts_with ~prefix:"mk-" name)
             (Array.to_list (Sys.readdir old_out))
         with
         | [ name ] -> name
         | _ -> failwith "one frozen market export required"
       in
       copy (path old_out mk) (path new_out mk);
       List.iter
         (fun item ->
            if List.mem market (List.map string (items (member "markets" item)))
            then (
              let name = string (member "name" item) in
              check
                "safe corpus item name"
                (Filename.basename name = name && name <> "." && name <> "..");
              let program = path new_dir "program.json" in
              let programs = path new_dir "programs.txt" in
              write program (string (member "program" item));
              write programs (program ^ "\n");
              let status, _ =
                command executable [ "run"; programs; path old_out mk; new_out ]
              in
              check "run frozen reference with MPFR" (status = Unix.WEXITED 0);
              List.iter
                (fun extension ->
                   let generated = path new_out ("0." ^ extension) in
                   if Sys.file_exists generated
                   then (
                     let target = path new_out (name ^ "." ^ extension ^ ".zst") in
                     shell ("zstd -q -c " ^ quote generated ^ " > " ^ quote target);
                     Sys.remove generated))
                [ "json"; "bin" ]))
         corpus)
    [ "N1"; "N2"; "N3" ];
  copy (path old_dir "raw-sha256.json") (path new_dir "raw-sha256.json");
  let manifest =
    `Assoc
      [ "numeric_policy", `String "mpfr-binary64"
      ; "reference_source_sha256", `String source_hash
      ; "oracle_stub_sha256", `String (sha "kernel2/ocaml/test/x4_mpfr_stubs.c")
      ; "old_reference_sha256", `String (sha (path old_dir "SHA256SUMS"))
      ; "corpus_sha256", member "corpus_sha256" corpus_manifest
      ]
  in
  write (path new_dir "manifest.json") (J.pretty_to_string manifest ^ "\n");
  shell
    ("cd "
     ^ quote new_dir
     ^ " && find out -type f -print | LC_ALL=C sort | xargs sha256sum > SHA256SUMS"
     ^ " && sha256sum manifest.json raw-sha256.json >> SHA256SUMS");
  Printf.printf "MPFR B4 reference SHA256SUMS: %s\n%!" (sha (path new_dir "SHA256SUMS"))
;;
