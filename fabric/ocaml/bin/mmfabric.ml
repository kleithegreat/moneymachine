open Core

let root_flag =
  Command.Param.flag
    "--root"
    (Command.Param.optional_with_default "data/fabric" Command.Param.string)
    ~doc:"DIR fabric storage root"
;;

let cas_put =
  Command.basic
    ~summary:"write stdin bytes into Zstd content-addressable storage"
    (let%map_open.Command root = root_flag
     and level =
       flag "--level" (optional_with_default 9 int) ~doc:"N zstd compression level"
     and uri_prefix =
       flag "--uri-prefix" (optional string) ~doc:"URI optional URI prefix"
     in
     fun () ->
       let raw = In_channel.input_all In_channel.stdin in
       match Mmfabric.Cas.put ?uri_prefix ~level ~root raw with
       | Ok rec_ ->
         print_endline (Yojson.Safe.pretty_to_string (Mmfabric.Cas.to_yojson rec_))
       | Error msg ->
         eprintf "error: %s\n" msg;
         exit 1)
;;

let cas_get =
  Command.basic
    ~summary:"read and verify bytes for a SHA-256 CAS object to stdout"
    (let%map_open.Command root = root_flag
     and digest = anon ("SHA256" %: string) in
     fun () ->
       match Mmfabric.Cas.get ~root digest with
       | Ok raw -> Out_channel.output_string Out_channel.stdout raw
       | Error msg ->
         eprintf "error: %s\n" msg;
         exit 1)
;;

let cas_verify =
  Command.basic
    ~summary:"verify an existing SHA-256 CAS object on disk"
    (let%map_open.Command root = root_flag
     and digest = anon ("SHA256" %: string) in
     fun () ->
       if Mmfabric.Cas.verify ~root digest
       then printf "ok %s\n" (String.lowercase digest)
       else (
         eprintf "invalid or missing CAS object: %s\n" digest;
         exit 1))
;;

let () =
  Command_unix.run
    ~version:"0.1.0"
    (Command.group
       ~summary:"moneymachine data fabric CLI"
       [ "cas-put", cas_put; "cas-get", cas_get; "cas-verify", cas_verify ])
;;
