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

let connect_tls ~host reader writer =
  let net_to_ssl = Reader.pipe reader in
  let ssl_to_net_r, ssl_to_net = Pipe.create () in
  let app_to_ssl_r, app_to_ssl_w = Pipe.create () in
  let ssl_to_app_r, ssl_to_app_w = Pipe.create () in
  don't_wait_for (Writer.transfer writer ssl_to_net_r (Writer.write writer));
  let%bind session =
    Async_ssl.Ssl.client
      ~hostname:host
      ~ca_file
      ~app_to_ssl:app_to_ssl_r
      ~ssl_to_app:ssl_to_app_w
      ~net_to_ssl
      ~ssl_to_net
      ()
  in
  let session = Or_error.ok_exn session in
  Or_error.ok_exn (Async_ssl.Ssl.Connection.check_peer_certificate_host session host);
  let%bind app_reader = Reader.of_pipe (Info.of_string "tls") ssl_to_app_r in
  let%map app_writer, `Closed_and_flushed_downstream _ =
    Writer.of_pipe (Info.of_string "tls") app_to_ssl_w
  in
  let close () =
    Async_ssl.Ssl.Connection.close session;
    let%bind () = Writer.close app_writer ~force_close:(Clock_ns.after (Time_ns.Span.of_sec 2.)) in
    let%bind () = Reader.close app_reader in
    close_tcp reader writer ()
  in
  { reader = app_reader; writer = app_writer; close }
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
  | `Eof | `Ok "" -> return (List.rev acc)
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

let websocket url =
  let url = parse_url url in
  let%bind net = connect url in
  let handshake () =
    Writer.write
      net.writer
      (sprintf
         "GET %s HTTP/1.1\r\nHost: %s\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\n\r\n"
         url.path
         url.host);
    match%bind Reader.read_line net.reader with
    | `Eof -> failwith "websocket handshake: eof"
    | `Ok status ->
      if status_code status <> 101 then failwithf "websocket handshake: %s" status ();
      let%map (_ : string list) = read_headers net.reader [] in
      Websocket.create ~role:Client net.reader net.writer
  in
  match%bind try_with handshake with
  | Ok ws -> return (ws, net)
  | Error exn ->
    let%bind () = net.close () in
    raise exn
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

let post url ~body =
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
      let%map response =
        match header headers "transfer-encoding" with
        | Some "chunked" -> read_chunks net.reader []
        | _ -> Reader.contents net.reader
      in
      if status_code status <> 200 then failwithf "rest: %s" status ();
      response
  in
  Monitor.protect request ~finally:net.close
;;
