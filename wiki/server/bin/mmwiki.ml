open Core

let root_flag =
  Command.Param.flag
    "--root"
    (Command.Param.optional_with_default "." Command.Param.string)
    ~doc:"DIR repository root"
;;

let serve_cmd =
  Command.basic
    ~summary:"serve the markdown wiki and repo docs over HTTP"
    (let%map_open.Command root = root_flag
     and addr =
       flag "--addr" (optional_with_default "127.0.0.1" string) ~doc:"ADDR bind IP"
     and port = flag "--port" (optional_with_default 8080 int) ~doc:"PORT HTTP port" in
     fun () -> Mmwiki.Server.serve ~root ~addr ~port)
;;

let index_cmd =
  Command.basic
    ~summary:"print JSON catalog of discoverable repository markdown files"
    (let%map_open.Command root = root_flag in
     fun () ->
       let docs = Mmwiki.Catalog.discover_docs ~root in
       print_endline (Yojson.Safe.pretty_to_string (Mmwiki.Catalog.index_to_yojson docs)))
;;

let search_cmd =
  Command.basic
    ~summary:"search markdown docs and print JSON results"
    (let%map_open.Command root = root_flag
     and query = anon ("QUERY" %: string) in
     fun () ->
       let hits = Mmwiki.Catalog.search ~root ~query in
       print_endline
         (Yojson.Safe.pretty_to_string (Mmwiki.Catalog.search_to_yojson ~query hits)))
;;

let () =
  Command_unix.run
    (Command.group
       ~summary:"moneymachine markdown wiki & docs server"
       [ "serve", serve_cmd; "index", index_cmd; "search", search_cmd ])
;;
