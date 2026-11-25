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

let ca_file () =
  Option.value (Sys.getenv "SSL_CERT_FILE") ~default:"/etc/ssl/certs/ca-certificates.crt"
;;

let close_tcp reader writer () =
  let%bind () =
    Writer.close writer ~force_close:(Clock_ns.after (Time_ns.Span.of_sec 2.))
  in
  Reader.close reader
;;

type tls_probe_state =
  | Unprobed
  | Probing of (unit, Error.t) Result.t Ivar.t
  | Verified

(* Async_ssl caches one SSL context per argument set; if loading ca_file fails, concurrent callers can stall.
   Only cache [Verified] permanently: a failed probe resets to [Unprobed] so later reconnects can recover. *)
let tls_probe : tls_probe_state ref = ref Unprobed

let check_ca_readable path =
  match Core_unix.access path [ `Read ] with
  | Ok () -> Ok ()
  | Error exn ->
    Error (Error.createf "TLS CA file %s unreadable: %s" path (Exn.to_string exn))
;;

let connect_tls ~host reader writer =
  let close_and_raise error =
    let%bind () = close_tcp reader writer () in
    Error.raise error
  in
  let ca = ca_file () in
  let%bind probe_ivar =
    match !tls_probe with
    | Verified -> return None
    | Probing ivar ->
      (match%bind Ivar.read ivar with
       | Ok () -> return None
       | Error error -> close_and_raise error)
    | Unprobed ->
      (match check_ca_readable ca with
       | Error error -> close_and_raise error
       | Ok () ->
         let ivar = Ivar.create () in
         tls_probe := Probing ivar;
         return (Some ivar))
  in
  let mark_verified () =
    match probe_ivar with
    | Some ivar when Ivar.is_empty ivar ->
      tls_probe := Verified;
      Ivar.fill_exn ivar (Ok ())
    | Some _ | None -> ()
  in
  let mark_probe_failed error =
    match probe_ivar with
    | Some ivar when Ivar.is_empty ivar ->
      tls_probe := Unprobed;
      Ivar.fill_exn ivar (Error error)
    | Some _ | None -> ()
  in
  let net_to_ssl = Reader.pipe reader in
  let ssl_to_net_r, ssl_to_net = Pipe.create () in
  let app_to_ssl_r, app_to_ssl_w = Pipe.create () in
  let ssl_to_app_r, ssl_to_app_w = Pipe.create () in
  let to_net data =
    mark_verified ();
    Writer.write writer data
  in
  don't_wait_for (Writer.transfer writer ssl_to_net_r to_net);
  match%bind
    Monitor.protect
      ~finally:(fun () ->
        mark_probe_failed (Error.of_string "TLS probe interrupted");
        return ())
      (fun () ->
         Async_ssl.Ssl.client
           ~hostname:host
           ~ca_file:ca
           ~app_to_ssl:app_to_ssl_r
           ~ssl_to_app:ssl_to_app_w
           ~net_to_ssl
           ~ssl_to_net
           ())
  with
  | Error error ->
    mark_probe_failed error;
    close_and_raise error
  | Ok session ->
    mark_verified ();
    (match Async_ssl.Ssl.Connection.check_peer_certificate_host session host with
     | Error error ->
       Async_ssl.Ssl.Connection.close session;
       close_and_raise error
     | Ok () ->
       let opened = ref false in
       let app_reader_ref = ref None in
       upon
         (Monitor.get_next_error (Monitor.current ()))
         (fun (_ : exn) ->
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

let connect ~connected url =
  let where =
    Tcp.Where_to_connect.of_host_and_port { host = url.host; port = url.port }
  in
  let%bind _socket, reader, writer = Tcp.connect where in
  let tcp = { reader; writer; close = close_tcp reader writer } in
  connected tcp;
  if (not url.tls) || Writer.is_closed writer
  then return tcp
  else (
    let%map net = connect_tls ~host:url.host reader writer in
    connected net;
    net)
;;

let rec read_headers reader acc =
  match%bind Reader.read_line reader with
  | `Eof -> return None
  | `Ok "" -> return (Some (List.rev acc))
  | `Ok line -> read_headers reader (line :: acc)
;;

let status_code line =
  match String.split line ~on:' ' with
  | _ :: code :: _ ->
    (match Int.of_string_opt code with
     | Some n -> n
     | None -> failwithf "bad status line: %s" line ())
  | _ -> failwithf "bad status line: %s" line ()
;;

let handshake_key () =
  let nonce = String.init 16 ~f:(fun _ -> Char.of_int_exn (Random.int 256)) in
  Cryptokit.transform_string (Cryptokit.Base64.encode_compact_pad ()) nonce
;;

let expected_accept key =
  Websocket.sec_websocket_accept_header_value ~sec_websocket_key:key
;;

let handshake_failure what = failwithf "websocket handshake: %s" what ()

let verify_accept_header ~key headers =
  let accepts =
    List.filter_map headers ~f:(fun line ->
      match String.lsplit2 line ~on:':' with
      | Some (name, value)
        when String.Caseless.equal (String.strip name) "sec-websocket-accept" ->
        Some (String.strip value)
      | _ -> None)
  in
  let expected = expected_accept key in
  match accepts with
  | [ got ] when String.equal got expected -> ()
  | [] -> handshake_failure "missing Sec-WebSocket-Accept"
  | _ -> handshake_failure "invalid Sec-WebSocket-Accept"
;;

let upgrade url (net : t) =
  let key = handshake_key () in
  Writer.write
    net.writer
    (sprintf
       "GET %s HTTP/1.1\r\n\
        Host: %s\r\n\
        Upgrade: websocket\r\n\
        Connection: Upgrade\r\n\
        Sec-WebSocket-Key: %s\r\n\
        Sec-WebSocket-Version: 13\r\n\
        \r\n"
       url.path
       url.host
       key);
  match%bind Reader.read_line net.reader with
  | `Eof -> handshake_failure "eof"
  | `Ok status ->
    if status_code status <> 101 then handshake_failure status;
    (match%map read_headers net.reader [] with
     | None -> handshake_failure "eof"
     | Some headers ->
       verify_accept_header ~key headers;
       Websocket.create ~role:Client net.reader net.writer)
;;

let websocket url ~connected =
  let url = parse_url url in
  let establish () =
    let%bind net = connect ~connected url in
    upgrade url net
  in
  match%bind Clock_ns.with_timeout (Time_ns.Span.of_sec 30.) (establish ()) with
  | `Result ws -> return ws
  | `Timeout -> handshake_failure "timed out"
;;
