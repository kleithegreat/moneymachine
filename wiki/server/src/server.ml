open Core

let text_resp ?(headers = []) ~code body =
  Tiny_httpd.Response.make_raw
    ~headers:(("cache-control", "no-store") :: headers)
    ~code
    body
;;

let html_resp ~code body =
  text_resp ~headers:[ "content-type", "text/html; charset=utf-8" ] ~code body
;;

let json_resp json =
  text_resp
    ~headers:[ "content-type", "application/json; charset=utf-8" ]
    ~code:200
    (Yojson.Safe.pretty_to_string json ^ "\n")
;;

let redirect_resp target =
  Tiny_httpd.Response.make_raw
    ~headers:[ "location", target; "content-type", "text/plain; charset=utf-8" ]
    ~code:302
    ""
;;

let raw_content_type rel =
  let low = String.lowercase rel in
  if String.is_suffix low ~suffix:".md"
  then "text/markdown; charset=utf-8"
  else if String.is_suffix low ~suffix:".pdf"
  then "application/pdf"
  else if String.is_suffix low ~suffix:".json"
  then "application/json; charset=utf-8"
  else "text/plain; charset=utf-8"
;;

let decode_components parts =
  let decoded =
    List.map parts ~f:(fun part ->
      match Tiny_httpd.Util.percent_decode part with
      | Some s -> Ok s
      | None -> Error (sprintf "invalid percent encoding in %S" part))
  in
  Result.all decoded
;;

let strip_body_if_head ~meth (resp : Tiny_httpd.Response.t) =
  match meth with
  | `HEAD -> Tiny_httpd.Response.set_body (`String "") resp
  | `GET | `POST | `PUT | `DELETE | `OPTIONS -> resp
;;

let read_file_safe abs =
  try Ok (In_channel.read_all abs) with
  | Sys_error msg -> Error msg
  | Core_unix.Unix_error (err, fn, arg) ->
    Error (sprintf "%s(%s): %s" fn arg (Core_unix.Error.message err))
;;

let list_dir_viewable ~root rel_dir =
  let abs_dir = if String.is_empty rel_dir then root else Filename.concat root rel_dir in
  try
    Sys_unix.ls_dir abs_dir
    |> List.filter ~f:(fun name ->
      let candidate = if String.is_empty rel_dir then name else rel_dir ^ "/" ^ name in
      Result.is_ok (Catalog.sanitize_rel_path candidate))
    |> List.sort ~compare:String.compare
  with
  | Sys_error _ | Core_unix.Unix_error _ -> []
;;

let title_for_doc ~docs ~rel ~content =
  match List.find docs ~f:(fun (d : Catalog.doc_entry) -> String.equal d.path rel) with
  | Some d -> d.title
  | None ->
    let first_h1 =
      String.split_lines content
      |> List.find_map ~f:(fun line ->
        Option.map
          (String.chop_prefix (String.strip line) ~prefix:"# ")
          ~f:(fun s -> String.strip s))
    in
    Option.value first_h1 ~default:(Filename.basename rel)
;;

let serve_raw ~root parts =
  let docs = Catalog.discover_docs ~root in
  match decode_components parts with
  | Error msg ->
    html_resp ~code:400 (Render.render_error_page ~docs ~code:400 ~message:msg)
  | Ok decoded ->
    let joined = String.concat ~sep:"/" decoded in
    (match Catalog.sanitize_rel_path joined with
     | Error msg ->
       html_resp ~code:403 (Render.render_error_page ~docs ~code:403 ~message:msg)
     | Ok rel ->
       if not (Catalog.is_viewable_ext rel)
       then
         html_resp
           ~code:403
           (Render.render_error_page
              ~docs
              ~code:403
              ~message:"file extension not viewable")
       else (
         let abs = Filename.concat root rel in
         match Sys_unix.is_file ~follow_symlinks:false abs with
         | `No | `Unknown ->
           html_resp
             ~code:404
             (Render.render_error_page ~docs ~code:404 ~message:("not found: " ^ rel))
         | `Yes ->
           (match read_file_safe abs with
            | Error msg ->
              html_resp ~code:500 (Render.render_error_page ~docs ~code:500 ~message:msg)
            | Ok bytes ->
              Tiny_httpd.Response.make_raw
                ~headers:[ "content-type", raw_content_type rel ]
                ~code:200
                bytes)))
;;

let serve_view ~root parts =
  let docs = Catalog.discover_docs ~root in
  match decode_components parts with
  | Error msg ->
    html_resp ~code:400 (Render.render_error_page ~docs ~code:400 ~message:msg)
  | Ok decoded ->
    let non_empty = List.filter decoded ~f:(fun s -> not (String.is_empty s)) in
    if List.is_empty non_empty
    then (
      let entries = list_dir_viewable ~root "" in
      html_resp ~code:200 (Render.render_dir_page ~docs ~rel_dir:"" ~entries))
    else (
      let joined = String.concat ~sep:"/" non_empty in
      match Catalog.sanitize_rel_path joined with
      | Error msg ->
        html_resp ~code:403 (Render.render_error_page ~docs ~code:403 ~message:msg)
      | Ok rel ->
        let abs = Filename.concat root rel in
        (match Sys_unix.is_directory ~follow_symlinks:false abs with
         | `Yes ->
           let idx = Filename.concat abs "index.md" in
           let rdm = Filename.concat abs "README.md" in
           (match Sys_unix.is_file ~follow_symlinks:false idx with
            | `Yes -> redirect_resp ("/view/" ^ Render.url_encode_path (rel ^ "/index.md"))
            | `No | `Unknown ->
              (match Sys_unix.is_file ~follow_symlinks:false rdm with
               | `Yes ->
                 redirect_resp ("/view/" ^ Render.url_encode_path (rel ^ "/README.md"))
               | `No | `Unknown ->
                 let entries = list_dir_viewable ~root rel in
                 html_resp ~code:200 (Render.render_dir_page ~docs ~rel_dir:rel ~entries)))
         | `No | `Unknown ->
           (match Sys_unix.is_file ~follow_symlinks:false abs with
            | `No | `Unknown ->
              html_resp
                ~code:404
                (Render.render_error_page ~docs ~code:404 ~message:("not found: " ^ rel))
            | `Yes ->
              if not (Catalog.is_viewable_ext rel)
              then
                html_resp
                  ~code:403
                  (Render.render_error_page
                     ~docs
                     ~code:403
                     ~message:"file extension not viewable")
              else if String.is_suffix (String.lowercase rel) ~suffix:".pdf"
              then (
                match read_file_safe abs with
                | Error msg ->
                  html_resp
                    ~code:500
                    (Render.render_error_page ~docs ~code:500 ~message:msg)
                | Ok pdf_bytes ->
                  Tiny_httpd.Response.make_raw
                    ~headers:[ "content-type", "application/pdf" ]
                    ~code:200
                    pdf_bytes)
              else (
                match read_file_safe abs with
                | Error msg ->
                  html_resp
                    ~code:500
                    (Render.render_error_page ~docs ~code:500 ~message:msg)
                | Ok content ->
                  if String.is_suffix (String.lowercase rel) ~suffix:".md"
                  then (
                    let title = title_for_doc ~docs ~rel ~content in
                    html_resp
                      ~code:200
                      (Render.render_doc_page
                         ~docs
                         ~rel_path:rel
                         ~title
                         ~markdown:content))
                  else
                    html_resp
                      ~code:200
                      (Render.render_text_page ~docs ~rel_path:rel ~content)))))
;;

let dispatch ~root ~meth ~path_components ~query =
  let resp =
    match meth with
    | `GET | `HEAD ->
      let q_param =
        List.Assoc.find query "q" ~equal:String.equal |> Option.value ~default:""
      in
      (match path_components with
       | [] -> redirect_resp "/view/wiki/index.md"
       | [ "healthz" ] ->
         text_resp
           ~headers:[ "content-type", "text/plain; charset=utf-8" ]
           ~code:200
           "ok\n"
       | [ "api"; "index" ] ->
         json_resp (Catalog.index_to_yojson (Catalog.discover_docs ~root))
       | [ "api"; "search" ] ->
         json_resp
           (Catalog.search_to_yojson ~query:q_param (Catalog.search ~root ~query:q_param))
       | [ "search" ] ->
         let docs = Catalog.discover_docs ~root in
         let hits = Catalog.search ~root ~query:q_param in
         html_resp ~code:200 (Render.render_search_page ~docs ~query:q_param ~hits)
       | "raw" :: rest -> serve_raw ~root rest
       | "view" :: rest -> serve_view ~root rest
       | _ ->
         let docs = Catalog.discover_docs ~root in
         html_resp
           ~code:404
           (Render.render_error_page ~docs ~code:404 ~message:"route not found"))
    | `POST | `PUT | `DELETE | `OPTIONS ->
      text_resp
        ~headers:[ "content-type", "text/plain; charset=utf-8" ]
        ~code:405
        "method not allowed\n"
  in
  strip_body_if_head ~meth resp
;;

let serve ~root ~addr ~port =
  let server = Tiny_httpd.create ~addr ~port () in
  Tiny_httpd.set_top_handler server (fun req ->
    dispatch
      ~root
      ~meth:(Tiny_httpd.Request.meth req)
      ~path_components:(req : Tiny_httpd.byte_stream Tiny_httpd.Request.t).path_components
      ~query:(Tiny_httpd.Request.query req));
  printf
    "mmwiki serving %s at http://%s:%d/view/wiki/index.md\n%!"
    root
    (Tiny_httpd.addr server)
    (Tiny_httpd.port server);
  match Tiny_httpd.run server with
  | Ok () -> ()
  | Error exn -> raise exn
;;
