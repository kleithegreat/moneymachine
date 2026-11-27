open Core

let with_temp_repo f =
  let base =
    Filename.concat
      Filename.temp_dir_name
      (sprintf
         "mmwiki-test-%d-%f"
         (Core_unix.getpid () |> Pid.to_int)
         (Core_unix.gettimeofday ()))
  in
  Core_unix.mkdir_p (Filename.concat base "wiki/adrs");
  Core_unix.mkdir_p (Filename.concat base "data");
  Out_channel.write_all
    (Filename.concat base "wiki/index.md")
    ~data:"# Knowledge Hub\n\nWelcome to the causal data fabric.\n";
  Out_channel.write_all
    (Filename.concat base "wiki/adrs/0001-pivot.md")
    ~data:"# ADR-0001\n\nRetractions never resurrect earlier revisions.\n";
  Out_channel.write_all (Filename.concat base ".keys.env") ~data:"SECRET=1\n";
  Out_channel.write_all (Filename.concat base "data/secret.md") ~data:"# Hidden\n";
  Exn.protect
    ~f:(fun () -> f base)
    ~finally:(fun () ->
      ignore
        (Core_unix.system (sprintf "rm -rf %s" (Filename.quote base))
         : Core_unix.Exit_or_signal.t))
;;

let body_string (resp : Tiny_httpd.Response.t) =
  match resp.body with
  | `String s -> s
  | `Stream _ | `Writer _ | `Void -> "<non-string>"
;;

let%expect_test "sanitize_rel_path blocks traversal, dotfiles, tokens, data, and _build" =
  let cases =
    [ "wiki/index.md"
    ; "../etc/passwd"
    ; "/etc/passwd"
    ; ".git/config"
    ; ".keys.env"
    ; ".CLAUDE_CODE_OAUTH_TOKEN_TAMU"
    ; "data/secret.md"
    ; "wiki/server/_build/default"
    ; "subprojects/confirmation-wall/kernel2/target/foo"
    ]
  in
  List.iter cases ~f:(fun p ->
    printf "%s => %b\n" p (Result.is_ok (Mmwiki.Catalog.sanitize_rel_path p)));
  [%expect
    {|
    wiki/index.md => true
    ../etc/passwd => false
    /etc/passwd => false
    .git/config => false
    .keys.env => false
    .CLAUDE_CODE_OAUTH_TOKEN_TAMU => false
    data/secret.md => false
    wiki/server/_build/default => false
    subprojects/confirmation-wall/kernel2/target/foo => false
    |}]
;;

let%expect_test "discover_docs, search, and server dispatch endpoints" =
  with_temp_repo (fun root ->
    let docs = Mmwiki.Catalog.discover_docs ~root in
    printf
      "docs=%d paths=%s\n"
      (List.length docs)
      (List.map docs ~f:(fun d -> d.path) |> String.concat ~sep:",");
    let hits = Mmwiki.Catalog.search ~root ~query:"retractions" in
    printf
      "hits=%d first=%s\n"
      (List.length hits)
      (match hits with
       | h :: _ -> h.path
       | [] -> "none");
    let r_root = Mmwiki.Server.dispatch ~root ~meth:`GET ~path_components:[] ~query:[] in
    let r_health =
      Mmwiki.Server.dispatch ~root ~meth:`GET ~path_components:[ "healthz" ] ~query:[]
    in
    let r_view =
      Mmwiki.Server.dispatch
        ~root
        ~meth:`GET
        ~path_components:[ "view"; "wiki"; "index.md" ]
        ~query:[]
    in
    let r_api_search =
      Mmwiki.Server.dispatch
        ~root
        ~meth:`GET
        ~path_components:[ "api"; "search" ]
        ~query:[ "q", "causal" ]
    in
    let r_blocked_dot =
      Mmwiki.Server.dispatch
        ~root
        ~meth:`GET
        ~path_components:[ "raw"; ".keys.env" ]
        ~query:[]
    in
    let r_blocked_data =
      Mmwiki.Server.dispatch
        ~root
        ~meth:`GET
        ~path_components:[ "view"; "data"; "secret.md" ]
        ~query:[]
    in
    let search_json = Yojson.Safe.from_string (body_string r_api_search) in
    let search_count = Yojson.Safe.Util.(member "count" search_json |> to_int) in
    printf
      "codes=(%d,%d,%d,%d,%d,%d) has_heading=%b search_count=%d\n"
      r_root.code
      r_health.code
      r_view.code
      r_api_search.code
      r_blocked_dot.code
      r_blocked_data.code
      (String.is_substring (body_string r_view) ~substring:"Knowledge Hub")
      search_count);
  [%expect
    {|
    docs=2 paths=wiki/index.md,wiki/adrs/0001-pivot.md
    hits=1 first=wiki/adrs/0001-pivot.md
    codes=(302,200,200,200,403,403) has_heading=true search_count=1
    |}]
;;
