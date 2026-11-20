open Core
open Async

type t =
  { reader : Reader.t
  ; writer : Writer.t
  ; close : unit -> unit Deferred.t
  }

type url =
  { tls : bool
  ; host : string
  ; port : int
  ; path : string
  }

let parse_url s =
  let scheme, rest = String.lsplit2_exn s ~on:':' in
  let rest = String.chop_prefix_exn rest ~prefix:"//" in
  let authority, path =
    match String.lsplit2 rest ~on:'/' with
    | Some (authority, path) -> authority, "/" ^ path
    | None -> rest, "/"
  in
  let tls = List.mem [ "wss"; "https" ] scheme ~equal:String.equal in
  let host, port =
    match String.lsplit2 authority ~on:':' with
    | Some (host, port) -> host, Int.of_string port
    | None -> authority, if tls then 443 else 80
  in
  { tls; host; port; path }
;;

let ca_file =
  Option.value (Sys.getenv "SSL_CERT_FILE") ~default:"/etc/ssl/certs/ca-certificates.crt"
;;

let close_tcp reader writer () =
  let%bind () = Writer.close writer ~force_close:(Clock_ns.after (Time_ns.Span.of_sec 2.)) in
  Reader.close reader
;;

(** Async_ssl builds one SSL context per argument set and caches it; when loading the CA file fails, only the first
    caller sees the error and every later caller waits forever. So the first TLS connect probes, and the others wait for
    its outcome and share its error (RECORDER.md, Behaviour; item 14). *)
let tls_context : (unit, Error.t) Result.t Ivar.t = Ivar.create ()
let tls_context_probed = ref false

let connect_tls ~host reader writer =
  let close_and_raise error =
    let%bind () = close_tcp reader writer () in
    Error.raise error
  in
  let probing = not !tls_context_probed in
  tls_context_probed := true;
  let%bind () =
    if probing
    then return ()
    else (
      match%bind Ivar.read tls_context with
      | Ok () -> return ()
      | Error error -> close_and_raise error)
  in
  let net_to_ssl = Reader.pipe reader in
  let ssl_to_net_r, ssl_to_net = Pipe.create () in
  let app_to_ssl_r, app_to_ssl_w = Pipe.create () in
  let ssl_to_app_r, ssl_to_app_w = Pipe.create () in
  let to_net data =
    Ivar.fill_if_empty tls_context (Ok ());
    Writer.write writer data
  in
  don't_wait_for (Writer.transfer writer ssl_to_net_r to_net);
  match%bind
    Async_ssl.Ssl.client
      ~hostname:host
      ~ca_file
      ~app_to_ssl:app_to_ssl_r
      ~ssl_to_app:ssl_to_app_w
      ~net_to_ssl
      ~ssl_to_net
      ()
  with
  | Error error ->
    Ivar.fill_if_empty tls_context (Error error);
    close_and_raise error
  | Ok session ->
    (match Async_ssl.Ssl.Connection.check_peer_certificate_host session host with
     | Error error ->
       Async_ssl.Ssl.Connection.close session;
       close_and_raise error
     | Ok () ->
       let opened = ref false in
       let app_reader_ref = ref None in
       upon (Monitor.get_next_error (Monitor.current ())) (fun _ ->
         if not !opened
         then (
           Async_ssl.Ssl.Connection.close session;
           don't_wait_for
             (let%bind () =
                Option.value_map !app_reader_ref ~default:(return ()) ~f:Reader.close
              in
              close_tcp reader writer ())));
       let%bind app_reader = Reader.of_pipe (Info.of_string "tls") ssl_to_app_r in
       app_reader_ref := Some app_reader;
       let%map app_writer, `Closed_and_flushed_downstream _ =
         Writer.of_pipe (Info.of_string "tls") app_to_ssl_w
       in
       opened := true;
       let close () =
         Async_ssl.Ssl.Connection.close session;
         let%bind () =
           Writer.close app_writer ~force_close:(Clock_ns.after (Time_ns.Span.of_sec 2.))
         in
         let%bind () = Reader.close app_reader in
         close_tcp reader writer ()
       in
       { reader = app_reader; writer = app_writer; close })
;;

let connect url =
  let where = Tcp.Where_to_connect.of_host_and_port { host = url.host; port = url.port } in
  let%bind _socket, reader, writer = Tcp.connect where in
  if url.tls
  then connect_tls ~host:url.host reader writer
  else return { reader; writer; close = close_tcp reader writer }
;;

let rec read_headers reader acc =
  match%bind Reader.read_line reader with
  | `Eof -> return None
  | `Ok "" -> return (Some (List.rev acc))
  | `Ok line -> read_headers reader (line :: acc)
;;

let header headers name =
  List.find_map headers ~f:(fun line ->
    match String.lsplit2 line ~on:':' with
    | Some (key, value) when String.equal (String.lowercase key) name -> Some (String.strip value)
    | _ -> None)
;;

let status_code line =
  match String.split line ~on:' ' with
  | _ :: code :: _ -> Int.of_string code
  | _ -> failwithf "bad status line: %s" line ()
;;

let handshake_key () =
  let nonce = String.init 16 ~f:(fun _ -> Char.of_int_exn (Random.int 256)) in
  Cryptokit.transform_string (Cryptokit.Base64.encode_compact ()) nonce
;;

let handshake_failure what = failwithf "websocket handshake: %s" what ()

let upgrade url (net : t) =
  Writer.write
    net.writer
    (sprintf
       "GET %s HTTP/1.1\r\nHost: %s\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: %s\r\nSec-WebSocket-Version: 13\r\n\r\n"
       url.path
       url.host
       (handshake_key ()));
  match%bind Reader.read_line net.reader with
  | `Eof -> handshake_failure "eof"
  | `Ok status ->
    if status_code status <> 101 then handshake_failure status;
    (match%map read_headers net.reader [] with
     | None -> handshake_failure "eof"
     | Some _ -> Websocket.create ~role:Client net.reader net.writer)
;;

(** Connects and upgrades within 30 s. [connected] receives the transport as soon as it exists (a late one is the
    caller's to close), so that whatever fails afterwards, the caller can close it. Failures are raised to the caller's
    monitor, which the transport's reader and writer report to as well. *)
let websocket url ~connected =
  let url = parse_url url in
  let establish () =
    let%bind net = connect url in
    connected net;
    let%map ws = upgrade url net in
    ws
  in
  match%bind Clock_ns.with_timeout (Time_ns.Span.of_sec 30.) (establish ()) with
  | `Result ws -> return ws
  | `Timeout -> handshake_failure "timed out"
;;

let rec read_chunks reader acc =
  match%bind Reader.read_line reader with
  | `Eof -> failwith "chunked body: eof"
  | `Ok size_line ->
    let size = Int.of_string ("0x" ^ String.strip (List.hd_exn (String.split size_line ~on:';'))) in
    if size = 0
    then return (String.concat (List.rev acc))
    else (
      let chunk = Bytes.create size in
      let%bind () =
        match%map Reader.really_read reader chunk with
        | `Ok -> ()
        | `Eof _ -> failwith "chunked body: eof"
      in
      let%bind (_ : [ `Ok of string | `Eof ]) = Reader.read_line reader in
      read_chunks reader (Bytes.to_string chunk :: acc))
;;

(** The status and body of a POST, [`Timeout] if not answered in full within 30 s. The connection is closed either
    way. *)
let post_status url ~body =
  let url = parse_url url in
  let%bind net = connect url in
  let request () =
    Writer.write
      net.writer
      (sprintf
         "POST %s HTTP/1.1\r\nHost: %s\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s"
         url.path
         url.host
         (String.length body)
         body);
    match%bind Reader.read_line net.reader with
    | `Eof -> failwith "rest: eof"
    | `Ok status ->
      let%bind headers = read_headers net.reader [] in
      let headers = Option.value_or_thunk headers ~default:(fun () -> failwith "rest: eof") in
      let%map response =
        match header headers "transfer-encoding" with
        | Some "chunked" -> read_chunks net.reader []
        | _ -> Reader.contents net.reader
      in
      status_code status, response
  in
  Monitor.protect
    (fun () -> Clock_ns.with_timeout (Time_ns.Span.of_sec 30.) (request ()))
    ~finally:net.close
;;

let post url ~body =
  match%map post_status url ~body with
  | `Timeout -> failwith "rest: timed out"
  | `Result (status, response) ->
    if status <> 200 then failwithf "rest: HTTP status %d" status ();
    response
;;
