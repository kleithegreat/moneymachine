open Core
open Async

let run =
  Command.async
    ~summary:"record Hyperliquid's websocket market data under ROOT"
    (let%map_open.Command root = anon ("ROOT" %: string)
     and connections = flag "--connections" (optional_with_default 8 int) ~doc:"N websocket connections"
     and max_subscriptions =
       flag "--max-subscriptions" (optional_with_default 950 int) ~doc:"N subscriptions in all"
     and ws_url =
       flag
         "--ws-url"
         (optional_with_default "wss://api.hyperliquid.xyz/ws" string)
         ~doc:"URL websocket endpoint"
     and rest_url =
       flag
         "--rest-url"
         (optional_with_default "https://api.hyperliquid.xyz/info" string)
         ~doc:"URL REST info endpoint"
     and listings_interval_s =
       flag "--listings-interval-s" (optional_with_default 3600 int) ~doc:"N seconds between listing reads"
     in
     fun () ->
       Mmrec.Run.run
         { root; connections; max_subscriptions; ws_url; rest_url; listings_interval_s })
;;

let print text =
  Out_channel.output_string stdout text;
  Out_channel.flush stdout
;;

let check =
  Command.basic
    ~summary:"report the integrity of the recordings between two hours"
    (let%map_open.Command root = anon ("ROOT" %: string)
     and from_ = anon ("FROM" %: string)
     and to_ = anon ("TO" %: string) in
     fun () -> print (Mmrec.Integrity.render (Mmrec.Integrity.check ~root ~from_ ~to_)))
;;

let cat =
  Command.basic
    ~summary:"decompress a recording to stdout"
    (let%map_open.Command file = anon ("FILE" %: string) in
     fun () ->
       let decoded = Mmrec.Frames.decode (In_channel.read_all file) in
       print decoded.data;
       if decoded.truncated then eprintf "mmrec cat: %s ends in a cut frame\n" file)
;;

let () =
  Command_unix.run
    (Command.group ~summary:"the Hyperliquid websocket recorder" [ "run", run; "check", check; "cat", cat ])
;;
