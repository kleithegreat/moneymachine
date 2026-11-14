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
    let where = Tcp.Where_to_connect.of_host_and_port { host = "127.0.0.1"; port = port_of (F.ws_url fake) } in
    let%bind _socket, reader, writer = Tcp.connect where in
    Writer.write
      writer
      "GET /ws HTTP/1.1\r\nHost: x\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\n\r\n";
    let%bind status = Reader.read_line reader in
    H.check (match status with `Ok l -> String.is_substring l ~substring:"101" | `Eof -> false) "no 101";
    let%bind () = skip_headers reader in
    let ws = Websocket.create ~role:Client reader writer in
    let rd, wr = Websocket.pipes ws in
    let%bind () = Pipe.write wr {|{"method":"subscribe","subscription":{"type":"trades","coin":"A"}}|} in
    let%bind first = Pipe.read rd in
    let%bind second = Pipe.read rd in
    (match first, second with
     | `Ok ack, `Ok frame ->
       H.check (String.is_substring ack ~substring:"subscriptionResponse") "no ack";
       H.check (String.is_substring frame ~substring:{|"channel":"trades"|}) "no stream frame"
     | _ -> failwith "pipe ended early");
    let%bind () = Pipe.write wr {|{"method":"ping"}|} in
    let%bind () = after (Time_float.Span.of_sec 1.5) in
    H.check (List.length (F.accepts fake) = 1) "accepts";
    H.check
      (List.mem (F.subscribed_on fake ~conn:1) ("trades", "A") ~equal:[%equal: string * string])
      "subscribed_on";
    H.check (F.streamed fake ~conn:1 > 5) "streamed";
    let%bind _socket, reader, writer = Tcp.connect where in
    let body = {|{"type":"meta","dex":""}|} in
    Writer.write
      writer
      (sprintf "POST /info HTTP/1.1\r\nHost: x\r\nContent-Length: %d\r\n\r\n%s" (String.length body) body);
    let%bind response = Reader.contents reader in
    H.check (String.is_substring response ~substring:{|"universe"|}) "rest response";
    H.check (List.length (F.rest_requests fake) = 1) "rest_requests";
    F.stop fake)
;;
