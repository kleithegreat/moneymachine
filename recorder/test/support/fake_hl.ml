open Core
open Async

type config =
  { rest : request:string -> string
  ; ack_subscriptions : bool
  ; close_after_ms : conn:int -> int option
  ; stream : (conn:int -> seq:int -> string) option
  ; stream_interval_ms : int
  ; tls : tls option
  }

and tls =
  { crt_file : string
  ; key_file : string
  }

let default_config =
  { rest = (fun ~request:_ -> "{}")
  ; ack_subscriptions = true
  ; close_after_ms = (fun ~conn:_ -> None)
  ; stream = None
  ; stream_interval_ms = 100
  ; tls = None
  }
;;

type t =
  { servers : (Socket.Address.Inet.t, int) Tcp.Server.t list
  ; ws_port : int
  ; rest_port : int
  ; ws_scheme : string
  ; accepts : (int * int) list ref
  ; received : (int * int * string) list ref
  ; rest_requests : string list ref
  ; streamed : (int, int) Hashtbl.t
  }

let now_ms () = Time_ns.to_int_ns_since_epoch (Time_ns.now ()) / 1_000_000

let rec read_headers reader acc =
  match%bind Reader.read_line reader with
  | `Eof | `Ok "" -> return (List.rev acc)
  | `Ok line -> read_headers reader (line :: acc)
;;

let header headers name =
  List.find_map headers ~f:(fun line ->
    match String.lsplit2 line ~on:':' with
    | Some (key, value) when String.equal (String.lowercase key) name ->
      Some (String.strip value)
    | _ -> None)
;;

let json_of_text text = try Some (Yojson.Safe.from_string text) with _ -> None

let ack_frame subscription =
  Yojson.Safe.to_string
    (`Assoc
        [ "channel", `String "subscriptionResponse"
        ; ( "data"
          , `Assoc [ "method", `String "subscribe"; "subscription", subscription ] )
        ])
;;

let serve_rest t config reader writer headers =
  let length = Option.value_map (header headers "content-length") ~default:0 ~f:Int.of_string in
  let buffer = Bytes.create length in
  let%bind _ = Reader.really_read reader buffer in
  let request = Bytes.to_string buffer in
  t.rest_requests := request :: !(t.rest_requests);
  let body = config.rest ~request in
  Writer.write
    writer
    (sprintf
       "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s"
       (String.length body)
       body);
  Writer.close writer
;;

let serve_ws t config reader writer headers conn =
  let key = Option.value_exn (header headers "sec-websocket-key") in
  let accept = Websocket.sec_websocket_accept_header_value ~sec_websocket_key:key in
  Writer.write
    writer
    (sprintf
       "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: %s\r\n\r\n"
       accept);
  let ws = Websocket.create ~role:Server reader writer in
  let rd, wr = Websocket.pipes ws in
  let finished = Ivar.create () in
  let subscribed = ref false in
  let send text = if not (Pipe.is_closed wr) then Pipe.write_without_pushback wr text in
  let close () =
    Pipe.close wr;
    Ivar.fill_if_empty finished ()
  in
  Option.iter (config.close_after_ms ~conn) ~f:(fun ms ->
    upon (after (Time_float.Span.of_int_ms ms)) close);
  Option.iter config.stream ~f:(fun stream ->
    let seq = ref 0 in
    Clock_ns.every
      ~stop:(Ivar.read finished)
      (Time_ns.Span.of_int_ms config.stream_interval_ms)
      (fun () ->
         if !subscribed
         then (
           incr seq;
           Hashtbl.set t.streamed ~key:conn ~data:!seq;
           send (stream ~conn ~seq:!seq))));
  let handle text =
    t.received := (conn, now_ms (), text) :: !(t.received);
    match json_of_text text with
    | Some (`Assoc fields) ->
      (match List.Assoc.find fields ~equal:String.equal "method" with
       | Some (`String "subscribe") ->
         subscribed := true;
         let subscription =
           Option.value (List.Assoc.find fields ~equal:String.equal "subscription") ~default:`Null
         in
         if config.ack_subscriptions then send (ack_frame subscription)
       | Some (`String "ping") -> if config.ack_subscriptions then send {|{"channel":"pong"}|}
       | _ -> ())
    | _ -> ()
  in
  let%bind () = Pipe.iter_without_pushback rd ~f:handle in
  close ();
  Writer.close writer
;;

let start config =
  let t_ref = ref None in
  let counter = ref 0 in
  let handler reader writer =
    let t = Option.value_exn !t_ref in
    let%bind headers = read_headers reader [] in
    let is_upgrade =
      Option.exists (header headers "upgrade") ~f:(fun v ->
        String.equal (String.lowercase v) "websocket")
    in
    if is_upgrade
    then (
      incr counter;
      let conn = !counter in
      t.accepts := (conn, now_ms ()) :: !(t.accepts);
      serve_ws t config reader writer headers conn)
    else serve_rest t config reader writer headers
  in
  let where = Tcp.Where_to_listen.bind_to Localhost On_port_chosen_by_os in
  let%bind plain = Tcp.Server.create ~on_handler_error:`Ignore where (fun _ r w -> handler r w) in
  let%map servers, ws_port, ws_scheme =
    match config.tls with
    | None -> return ([ plain ], Tcp.Server.listening_on plain, "ws")
    | Some { crt_file; key_file } ->
      let tls_config = Async_ssl.Config.Server.create ~crt_file ~key_file ~ca_file:None ~ca_path:None () in
      let%map secure =
        Async_ssl.Tls.listen
          tls_config
          where
          ~on_handler_error:`Ignore
          ~f:(fun _ _ reader writer -> handler reader writer)
      in
      [ plain; secure ], Tcp.Server.listening_on secure, "wss"
  in
  let t =
    { servers
    ; ws_port
    ; rest_port = Tcp.Server.listening_on plain
    ; ws_scheme
    ; accepts = ref []
    ; received = ref []
    ; rest_requests = ref []
    ; streamed = Hashtbl.create (module Int)
    }
  in
  t_ref := Some t;
  t
;;

let stop t = Deferred.List.iter ~how:`Sequential t.servers ~f:Tcp.Server.close
let ws_url t = sprintf "%s://127.0.0.1:%d/ws" t.ws_scheme t.ws_port
let rest_url t = sprintf "http://127.0.0.1:%d/info" t.rest_port
let accepts t = List.rev !(t.accepts)
let received t = List.rev !(t.received)
let streamed t ~conn = Option.value (Hashtbl.find t.streamed conn) ~default:0
let rest_requests t = List.rev !(t.rest_requests)

let subscribed_on t ~conn =
  List.filter_map (received t) ~f:(fun (c, _, text) ->
    if c <> conn
    then None
    else (
      match json_of_text text with
      | Some (`Assoc fields) ->
        (match
           ( List.Assoc.find fields ~equal:String.equal "method"
           , List.Assoc.find fields ~equal:String.equal "subscription" )
         with
         | Some (`String "subscribe"), Some (`Assoc sub) ->
           let str key =
             match List.Assoc.find sub ~equal:String.equal key with
             | Some (`String s) -> s
             | _ -> ""
           in
           Some (str "type", str "coin")
         | _ -> None)
      | _ -> None))
;;

let carries_fast_book t ~conn =
  List.exists (received t) ~f:(fun (c, _, text) ->
    c = conn
    &&
    match json_of_text text with
    | Some (`Assoc fields) ->
      (match
         ( List.Assoc.find fields ~equal:String.equal "method"
         , List.Assoc.find fields ~equal:String.equal "subscription" )
       with
       | Some (`String "subscribe"), Some (`Assoc sub) ->
         Poly.equal (List.Assoc.find sub ~equal:String.equal "type") (Some (`String "l2Book"))
         && Poly.equal (List.Assoc.find sub ~equal:String.equal "fast") (Some (`Bool true))
       | _ -> false)
    | _ -> false)
;;

let meta_json ~live ~delisted =
  let asset ?(flag = false) name =
    `Assoc
      ([ "name", `String name; "szDecimals", `Int 4; "maxLeverage", `Int 10 ]
       @ if flag then [ "isDelisted", `Bool true ] else [])
  in
  Yojson.Safe.to_string
    (`Assoc
        [ ( "universe"
          , `List (List.map live ~f:(fun c -> asset c) @ List.map delisted ~f:(asset ~flag:true))
          )
        ; "marginTables", `List []
        ])
;;

let perp_dexs_json names =
  Yojson.Safe.to_string
    (`List (`Null :: List.map names ~f:(fun n -> `Assoc [ "name", `String n; "fullName", `String n ])))
;;

let rest_of_universe coins ~request =
  match json_of_text request with
  | Some (`Assoc fields) ->
    (match List.Assoc.find fields ~equal:String.equal "type" with
     | Some (`String "perpDexs") -> perp_dexs_json []
     | Some (`String "meta") -> meta_json ~live:(coins ()) ~delisted:[]
     | Some (`String "spotMeta") -> {|{"tokens":[],"universe":[]}|}
     | _ -> "{}")
  | _ -> "{}"
;;

let trades_frame ~coin ~seq =
  let separator = if seq % 2 = 1 then "\r\n" else "" in
  sprintf
    {|{"channel":"trades",%s"data":[{"coin":"%s","side":"B","px":"%d.5","sz":"0.1","time":%d,"hash":"0x00","tid":%d}]}|}
    separator
    coin
    (100 + seq)
    seq
    seq
;;
