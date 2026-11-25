(* Checks the fake server itself with a plain websocket client, so that a failure elsewhere is the recorder's. *)

open Core
open Async
module H = Rec_support.Harness
module F = Rec_support.Fake_hl

let port_of url =
  let after_colon = String.rsplit2_exn url ~on:':' |> snd in
  Int.of_string (String.take_while after_colon ~f:Char.is_digit)
;;

let rec skip_headers reader =
  match%bind Reader.read_line reader with
  | `Eof | `Ok "" -> return ()
  | `Ok _ -> skip_headers reader
;;

let upgrade_request =
  "GET /ws HTTP/1.1\r\n\
   Host: x\r\n\
   Upgrade: websocket\r\n\
   Connection: Upgrade\r\n\
   Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n\
   Sec-WebSocket-Version: 13\r\n\
   \r\n"
;;

let faults () =
  let with_fault fault =
    let%map fake =
      F.start { F.default_config with fault = (fun ~conn:_ -> Some fault) }
    in
    ( fake
    , Tcp.Where_to_connect.of_host_and_port
        { host = "127.0.0.1"; port = port_of (F.ws_url fake) } )
  in
  let%bind fake, where = with_fault F.Close_in_handshake in
  let%bind _socket, reader, writer = Tcp.connect where in
  Writer.set_raise_when_consumer_leaves writer false;
  Writer.write writer upgrade_request;
  let%bind answer = Reader.read_line reader in
  H.check
    (match answer with
     | `Eof -> true
     | `Ok _ -> false)
    "close in the handshake: the server answered";
  let%bind () = F.stop fake in
  let%bind fake, where = with_fault (F.Answer_with 403) in
  let%bind _socket, reader, writer = Tcp.connect where in
  Writer.set_raise_when_consumer_leaves writer false;
  Writer.write writer upgrade_request;
  let%bind status = Reader.read_line reader in
  H.check
    (match status with
     | `Ok l -> String.is_substring l ~substring:"403"
     | `Eof -> false)
    "answer with 403: no 403 status line";
  let%bind () = F.stop fake in
  let%bind fake, where = with_fault F.Reset_mid_frame in
  let%bind _socket, reader, writer = Tcp.connect where in
  Writer.set_raise_when_consumer_leaves writer false;
  Writer.write writer upgrade_request;
  let%bind status = Reader.read_line reader in
  H.check
    (match status with
     | `Ok l -> String.is_substring l ~substring:"101"
     | `Eof -> false)
    "reset mid-frame: no 101";
  let%bind () = skip_headers reader in
  let ws = Websocket.create ~role:Client reader writer in
  let rd, wr = Websocket.pipes ws in
  let%bind () =
    Pipe.write wr {|{"method":"subscribe","subscription":{"type":"trades","coin":"A"}}|}
  in
  let%bind next = Pipe.read rd in
  H.check
    (match next with
     | `Eof -> true
     | `Ok _ -> false)
    "reset mid-frame: a whole message arrived";
  F.stop fake
;;

let post_info fake body =
  let where =
    Tcp.Where_to_connect.of_host_and_port
      { host = "127.0.0.1"; port = port_of (F.rest_url fake) }
  in
  let%bind _socket, reader, writer = Tcp.connect where in
  Writer.write
    writer
    (sprintf
       "POST /info HTTP/1.1\r\nHost: x\r\nContent-Length: %d\r\n\r\n%s"
       (String.length body)
       body);
  Reader.contents reader
;;

let wires () =
  let expected =
    [ F.with_length ~announced:99 "[1]"
    ; F.chunked ~ending:`No_last_chunk [ "[1"; "]" ]
    ; F.chunked ~ending:`No_final_crlf [ "[1"; "]" ]
    ; F.chunked ~trailers:[ "X-T: 1" ] [ "[1"; "]" ]
    ; F.to_close "[1]"
    ]
  in
  H.check
    (String.is_suffix (List.nth_exn expected 2) ~suffix:"]\r\n0\r\n")
    "a chunked body without its final CRLF ends otherwise";
  H.check
    (String.is_suffix (List.nth_exn expected 3) ~suffix:"]\r\n0\r\nX-T: 1\r\n\r\n")
    "a chunked body with trailers ends otherwise";
  Deferred.List.iter ~how:`Sequential expected ~f:(fun wire ->
    let%bind fake =
      F.start
        { F.default_config with rest_serve = (fun ~request:_ -> Some (F.send wire)) }
    in
    let%bind received = post_info fake {|{"type":"meta"}|} in
    H.check
      (String.equal received wire)
      (sprintf "rest_serve: %S arrived as %S" wire received);
    F.stop fake)
;;

let () =
  H.main "fake_hl selftest" (fun () ->
    let config =
      { F.default_config with
        rest = F.rest_of_universe (fun () -> [ "A"; "B" ])
      ; stream = Some (fun ~conn:_ ~seq -> F.trades_frame ~coin:"A" ~seq)
      ; stream_interval_ms = 20
      ; close_after_ms = (fun ~conn:_ -> Some 1000)
      }
    in
    let%bind fake = F.start config in
    let where =
      Tcp.Where_to_connect.of_host_and_port
        { host = "127.0.0.1"; port = port_of (F.ws_url fake) }
    in
    let%bind _socket, reader, writer = Tcp.connect where in
    Writer.write
      writer
      "GET /ws HTTP/1.1\r\n\
       Host: x\r\n\
       Upgrade: websocket\r\n\
       Connection: Upgrade\r\n\
       Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n\
       Sec-WebSocket-Version: 13\r\n\
       \r\n";
    let%bind status = Reader.read_line reader in
    H.check
      (match status with
       | `Ok l -> String.is_substring l ~substring:"101"
       | `Eof -> false)
      "no 101";
    let%bind () = skip_headers reader in
    let ws = Websocket.create ~role:Client reader writer in
    let rd, wr = Websocket.pipes ws in
    let%bind () =
      Pipe.write wr {|{"method":"subscribe","subscription":{"type":"trades","coin":"A"}}|}
    in
    let%bind first = Pipe.read rd in
    let%bind second = Pipe.read rd in
    (match first, second with
     | `Ok ack, `Ok frame ->
       H.check (String.is_substring ack ~substring:"subscriptionResponse") "no ack";
       H.check
         (String.is_substring frame ~substring:{|"channel":"trades"|})
         "no stream frame"
     | _ -> failwith "pipe ended early");
    let%bind () = Pipe.write wr {|{"method":"ping"}|} in
    let%bind () = after (Time_float.Span.of_sec 1.5) in
    H.check (List.length (F.accepts fake) = 1) "accepts";
    H.check
      (List.mem
         (F.subscribed_on fake ~conn:1)
         ("trades", "A")
         ~equal:[%equal: string * string])
      "subscribed_on";
    H.check (F.streamed fake ~conn:1 > 5) "streamed";
    let%bind _socket, reader, writer = Tcp.connect where in
    let body = {|{"type":"meta","dex":""}|} in
    Writer.write
      writer
      (sprintf
         "POST /info HTTP/1.1\r\nHost: x\r\nContent-Length: %d\r\n\r\n%s"
         (String.length body)
         body);
    let%bind response = Reader.contents reader in
    H.check (String.is_substring response ~substring:{|"universe"|}) "rest response";
    H.check (List.length (F.rest_requests fake) = 1) "rest_requests";
    let%bind () = F.stop fake in
    let%bind () = faults () in
    wires ())
;;
