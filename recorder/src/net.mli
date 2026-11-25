(** WebSocket client transport with TLS verification and RFC 6455 handshake validation (RECORDER.md). *)

open Async

type t =
  { reader : Reader.t
  ; writer : Writer.t
  ; close : unit -> unit Deferred.t
  }

(** Connects and performs the RFC 6455 WebSocket upgrade within 30 s, verifying TLS peer/hostname and the
    server's [Sec-WebSocket-Accept] header. [connected] receives each transport layer as soon as it exists so
    the caller can close it on failure. *)
val websocket : string -> connected:(t -> unit) -> Websocket.t Deferred.t
