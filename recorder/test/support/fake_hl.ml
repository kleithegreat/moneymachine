open Core
open Async

type config =
  { rest : request:string -> string
  ; ack_subscriptions : bool
  ; close_after_ms : conn:int -> int option
  ; stream : (conn:int -> seq:int -> string) option
  ; stream_interval_ms : int
  ; tls : tls option
  ; rest_tls : tls option
  ; fault : conn:int -> fault option
  ; rest_stall : request:string -> bool
  ; rest_fault : unit -> rest_stall_mode option
  ; rest_serve : request:string -> (Writer.t -> unit Deferred.t) option
  }

and fault =
  | Close_in_handshake
  | Partial_response
  | Reset_in_handshake
  | Answer_with of int
  | Missing_accept
  | Bad_accept
  | Reset_mid_frame
  | Tls_fatal_alert

and rest_stall_mode =
  | Stall_tls_handshake
  | Stall_before_status_line
  | Stall_in_chunked_body

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
  ; rest_tls = None
  ; fault = (fun ~conn:_ -> None)
  ; rest_stall = (fun ~request:_ -> false)
  ; rest_fault = (fun () -> None)
  ; rest_serve = (fun ~request:_ -> None)
  }
;;

type t =
  { servers : (Socket.Address.Inet.t, int) Tcp.Server.t list
  ; ws_port : int
  ; rest_port : int
  ; ws_scheme : string
  ; rest_scheme : string
  ; stopped : unit Ivar.t
  ; accepts : (int * int) list ref
  ; received : (int * int * string) list ref
  ; rest_requests : string list ref
  ; streamed : (int, int) Hashtbl.t
  ; faults_at : (int, int) Hashtbl.t
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

let json_of_text text =
  match Yojson.Safe.from_string text with
  | json -> Some json
  | exception Yojson.Json_error _ -> None
;;

let ack_frame subscription =
  Yojson.Safe.to_string
    (`Assoc
        [ "channel", `String "subscriptionResponse"
        ; "data", `Assoc [ "method", `String "subscribe"; "subscription", subscription ]
        ])
;;

let wait_eof_or_stop t reader =
  let buf = Bytes.create 4096 in
  let rec drain () =
    match%bind Reader.read reader buf with
    | `Eof -> return ()
    | `Ok _ -> drain ()
  in
  Deferred.any [ drain (); Ivar.read t.stopped ]
;;

let head ?(status = 200) fields =
  let reason = if status = 200 then "OK" else "Status" in
  String.concat
    ((sprintf "HTTP/1.1 %d %s" status reason :: "Content-Type: application/json" :: fields)
     @ [ "Connection: close"; ""; "" ])
    ~sep:"\r\n"
;;

let with_length ?announced body =
  let announced = Option.value announced ~default:(String.length body) in
  head [ sprintf "Content-Length: %d" announced ] ^ body
;;

let chunked ?(trailers = []) ?(ending = `Whole) chunks =
  let body =
    List.map chunks ~f:(fun chunk -> sprintf "%x\r\n%s\r\n" (String.length chunk) chunk)
  in
  let last =
    match ending with
    | `Whole ->
      "0\r\n"
      ^ String.concat (List.map trailers ~f:(fun field -> field ^ "\r\n"))
      ^ "\r\n"
    | `No_last_chunk -> ""
    | `No_final_crlf -> "0\r\n"
  in
  head [ "Transfer-Encoding: chunked" ] ^ String.concat body ^ last
;;

let to_close body = head [] ^ body

let send wire writer =
  Writer.write writer wire;
  Writer.flushed writer
;;

let send_in_pieces ~bytes wire writer =
  let rec from pos =
    if pos >= String.length wire
    then return ()
    else (
      let len = Int.min bytes (String.length wire - pos) in
      let%bind () = send (String.sub wire ~pos ~len) writer in
      from (pos + len))
  in
  from 0
;;

let send_and_keep_open wire writer =
  let%bind () = send wire writer in
  Deferred.never ()
;;

let serve_rest t config ~fault reader writer headers =
  let length =
    Option.value_map (header headers "content-length") ~default:0 ~f:Int.of_string
  in
  let buffer = Bytes.create length in
  let%bind (_ : [ `Ok | `Eof of int ]) = Reader.really_read reader buffer in
  let request = Bytes.to_string buffer in
  t.rest_requests := request :: !(t.rest_requests);
  match fault with
  | Some Stall_before_status_line | Some Stall_tls_handshake -> wait_eof_or_stop t reader
  | Some Stall_in_chunked_body ->
    Writer.write
      writer
      "HTTP/1.1 200 OK\r\n\
       Content-Type: application/json\r\n\
       Transfer-Encoding: chunked\r\n\
       \r\n\
       1\r\n\
       [\r\n";
    let%bind () = Writer.flushed writer in
    wait_eof_or_stop t reader
  | None ->
    if config.rest_stall ~request
    then (
      (* The answer starts and never ends: the headers promise more body than is ever sent. *)
      Writer.write
        writer
        "HTTP/1.1 200 OK\r\n\
         Content-Type: application/json\r\n\
         Content-Length: 100000\r\n\
         \r\n\
         [";
      Deferred.never ())
    else (
      let serve =
        match config.rest_serve ~request with
        | Some serve -> serve
        | None -> send (with_length (config.rest ~request))
      in
      let%bind () = Deferred.any [ serve writer; Ivar.read t.stopped ] in
      Writer.close ~force_close:(Clock.after (Time_float.Span.of_sec 5.)) writer)
;;

let reset writer =
  let%bind () = Writer.flushed writer in
  Fd.with_file_descr_exn (Writer.fd writer) (fun fd ->
    Core_unix.setsockopt_optint fd Core_unix.SO_LINGER (Some 0));
  Writer.close writer
;;

let reset_mid_frame writer =
  Writer.write writer "\x81\x7e\x10\x00partial";
  reset writer
;;

let serve_ws t config ~outer_wr reader writer headers conn =
  let key = Option.value_exn (header headers "sec-websocket-key") in
  let accept = Websocket.sec_websocket_accept_header_value ~sec_websocket_key:key in
  Writer.write
    writer
    (sprintf
       "HTTP/1.1 101 Switching Protocols\r\n\
        Upgrade: websocket\r\n\
        Connection: Upgrade\r\n\
        Sec-WebSocket-Accept: %s\r\n\
        \r\n"
       accept);
  let ws = Websocket.create ~role:Server reader writer in
  let rd, wr = Websocket.pipes ws in
  let finished = Ivar.create () in
  let stop_stream = Ivar.create () in
  let subscribed = ref false in
  let resetting = ref false in
  let alert_scheduled = ref false in
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
      ~stop:(Deferred.any [ Ivar.read finished; Ivar.read stop_stream ])
      (Time_ns.Span.of_int_ms config.stream_interval_ms)
      (fun () ->
         if !subscribed
         then (
           incr seq;
           Hashtbl.set t.streamed ~key:conn ~data:!seq;
           send (stream ~conn ~seq:!seq))));
  let trigger_tls_alert () =
    if not !alert_scheduled
    then (
      alert_scheduled := true;
      don't_wait_for
        (let%bind () = after (Time_float.Span.of_ms 400.) in
         Ivar.fill_if_empty stop_stream ();
         let%bind () = Writer.flushed writer in
         let%bind () = after (Time_float.Span.of_ms 50.) in
         match outer_wr with
         | None -> failwith "Tls_fatal_alert requires tls = Some ..."
         | Some raw_wr ->
           let%bind () = Writer.flushed raw_wr in
           Hashtbl.set t.faults_at ~key:conn ~data:(now_ms ());
           Writer.write raw_wr "\x15\x03\x03\x00\x02\x02\x50";
           Writer.flushed raw_wr))
  in
  let handle text =
    t.received := (conn, now_ms (), text) :: !(t.received);
    if Poly.equal (config.fault ~conn) (Some Reset_mid_frame)
    then (
      if not !resetting
      then (
        resetting := true;
        don't_wait_for (reset_mid_frame writer)))
    else (
      match json_of_text text with
      | Some (`Assoc fields) ->
        (match List.Assoc.find fields ~equal:String.equal "method" with
         | Some (`String "subscribe") ->
           subscribed := true;
           let subscription =
             Option.value
               (List.Assoc.find fields ~equal:String.equal "subscription")
               ~default:`Null
           in
           if config.ack_subscriptions then send (ack_frame subscription);
           if Poly.equal (config.fault ~conn) (Some Tls_fatal_alert)
           then trigger_tls_alert ()
         | Some (`String "ping") ->
           if config.ack_subscriptions then send {|{"channel":"pong"}|}
         | _ -> ())
      | _ -> ())
  in
  let%bind () =
    Deferred.any [ Pipe.iter_without_pushback rd ~f:handle; Ivar.read t.stopped ]
  in
  close ();
  Writer.close writer
;;

let start config =
  let t_ref = ref None in
  let counter = ref 0 in
  let ws_or_rest_handler ~outer_wr reader writer =
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
      match config.fault ~conn with
      | Some Close_in_handshake -> Writer.close writer
      | Some Partial_response ->
        Writer.write writer "HTTP/1.1 101 Switching Protocols\r\nUpgrade: web";
        let%bind () = Writer.flushed writer in
        Writer.close writer
      | Some Reset_in_handshake -> reset writer
      | Some (Answer_with code) ->
        Writer.write
          writer
          (sprintf
             "HTTP/1.1 %d Refused\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
             code);
        Writer.close writer
      | Some Missing_accept ->
        Writer.write
          writer
          "HTTP/1.1 101 Switching Protocols\r\n\
           Upgrade: websocket\r\n\
           Connection: Upgrade\r\n\
           \r\n";
        let%bind () = Writer.flushed writer in
        Writer.close writer
      | Some Bad_accept ->
        Writer.write
          writer
          "HTTP/1.1 101 Switching Protocols\r\n\
           Upgrade: websocket\r\n\
           Connection: Upgrade\r\n\
           Sec-WebSocket-Accept: invalid-accept-value\r\n\
           \r\n";
        let%bind () = Writer.flushed writer in
        Writer.close writer
      | Some (Reset_mid_frame | Tls_fatal_alert) | None ->
        serve_ws t config ~outer_wr reader writer headers conn)
    else (
      let fault = config.rest_fault () in
      serve_rest t config ~fault reader writer headers)
  in
  let rest_tls_config =
    Option.map config.rest_tls ~f:(fun { crt_file; key_file } ->
      Async_ssl.Config.Server.create ~crt_file ~key_file ~ca_file:None ~ca_path:None ())
  in
  let rest_handler outer_rd outer_wr =
    let t = Option.value_exn !t_ref in
    let fault = config.rest_fault () in
    match fault with
    | Some Stall_tls_handshake -> wait_eof_or_stop t outer_rd
    | _ ->
      let run reader writer =
        let%bind headers = read_headers reader [] in
        serve_rest t config ~fault reader writer headers
      in
      (match rest_tls_config with
       | None -> run outer_rd outer_wr
       | Some tls_config ->
         Async_ssl.Tls.wrap_server_connection
           tls_config
           outer_rd
           outer_wr
           ~f:(fun _ r w -> run r w))
  in
  let where = Tcp.Where_to_listen.bind_to Localhost On_port_chosen_by_os in
  let%map servers, ws_port, ws_scheme, rest_port, rest_scheme =
    match config.tls, config.rest_tls with
    | None, None ->
      let%map plain =
        Tcp.Server.create ~on_handler_error:`Ignore where (fun _ r w ->
          ws_or_rest_handler ~outer_wr:None r w)
      in
      let port = Tcp.Server.listening_on plain in
      [ plain ], port, "ws", port, "http"
    | ws_tls, rest_tls ->
      let%bind ws_server, ws_scheme =
        match ws_tls with
        | None ->
          let%map plain =
            Tcp.Server.create ~on_handler_error:`Ignore where (fun _ r w ->
              ws_or_rest_handler ~outer_wr:None r w)
          in
          plain, "ws"
        | Some { crt_file; key_file } ->
          let tls_config =
            Async_ssl.Config.Server.create
              ~crt_file
              ~key_file
              ~ca_file:None
              ~ca_path:None
              ()
          in
          let%map secure =
            Tcp.Server.create ~on_handler_error:`Ignore where (fun _ outer_rd outer_wr ->
              Async_ssl.Tls.wrap_server_connection
                tls_config
                outer_rd
                outer_wr
                ~f:(fun _ r w -> ws_or_rest_handler ~outer_wr:(Some outer_wr) r w))
          in
          secure, "wss"
      in
      let%map rest_server =
        Tcp.Server.create ~on_handler_error:`Ignore where (fun _ r w -> rest_handler r w)
      in
      let rest_scheme = if Option.is_some rest_tls then "https" else "http" in
      ( [ ws_server; rest_server ]
      , Tcp.Server.listening_on ws_server
      , ws_scheme
      , Tcp.Server.listening_on rest_server
      , rest_scheme )
  in
  let t =
    { servers
    ; ws_port
    ; rest_port
    ; ws_scheme
    ; rest_scheme
    ; stopped = Ivar.create ()
    ; accepts = ref []
    ; received = ref []
    ; rest_requests = ref []
    ; streamed = Hashtbl.create (module Int)
    ; faults_at = Hashtbl.create (module Int)
    }
  in
  t_ref := Some t;
  t
;;

let stop t =
  Ivar.fill_if_empty t.stopped ();
  Deferred.List.iter ~how:`Sequential t.servers ~f:(fun server -> Tcp.Server.close server)
;;

let ws_url t = sprintf "%s://127.0.0.1:%d/ws" t.ws_scheme t.ws_port
let rest_url t = sprintf "%s://127.0.0.1:%d/info" t.rest_scheme t.rest_port
let accepts t = List.rev !(t.accepts)
let received t = List.rev !(t.received)
let streamed t ~conn = Option.value (Hashtbl.find t.streamed conn) ~default:0
let fault_at t ~conn = Hashtbl.find t.faults_at conn
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
         Poly.equal
           (List.Assoc.find sub ~equal:String.equal "type")
           (Some (`String "l2Book"))
         && Poly.equal
              (List.Assoc.find sub ~equal:String.equal "fast")
              (Some (`Bool true))
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
          , `List
              (List.map live ~f:(fun c -> asset c)
               @ List.map delisted ~f:(asset ~flag:true)) )
        ; "marginTables", `List []
        ])
;;

let perp_dexs_json names =
  Yojson.Safe.to_string
    (`List
        (`Null
         :: List.map names ~f:(fun n ->
           `Assoc [ "name", `String n; "fullName", `String n ])))
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
