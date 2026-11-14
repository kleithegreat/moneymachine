(** A local fake of Hyperliquid for the offline tests: one plain-TCP port serving the websocket at any path and
    the REST [info] endpoint at any other, with no TLS, unless [tls] is set: then the websocket is served over TLS
    on its own port (a [wss://] URL) and REST stays plain on another. It parses requests with Yojson on its own, not with the
    library under test. Times are real, in ms since the epoch. *)

open Async

type config =
  { rest : request:string -> string  (** the response body for each REST request body *)
  ; ack_subscriptions : bool  (** answer subscribe with a [subscriptionResponse], ping with a [pong] *)
  ; close_after_ms : conn:int -> int option  (** the server closes connection [conn] this long after accepting it *)
  ; stream : (conn:int -> seq:int -> string) option
        (** once a connection has subscribed, send this frame every [stream_interval_ms] *)
  ; stream_interval_ms : int
  ; tls : tls option  (** serve the websocket over TLS with this certificate *)
  ; fault : conn:int -> fault option  (** how connection [conn] misbehaves, if it does *)
  }

(** A connection's failure: the server closes the socket on reading the upgrade request, answering nothing; closes it
    after the first bytes of a [101] response; resets it (TCP RST) on reading the upgrade request; answers
    the upgrade with this HTTP status instead of [101]; or, after the handshake and the first message received, sends
    the start of a websocket frame and resets the connection (TCP RST) in the middle of it. *)
and fault =
  | Close_in_handshake
  | Partial_response
  | Reset_in_handshake
  | Answer_with of int
  | Reset_mid_frame

and tls =
  { crt_file : string
  ; key_file : string
  }

(** Acks, never closes, never misbehaves, streams nothing, REST answers [{}]. *)
val default_config : config

type t

val start : config -> t Deferred.t
val stop : t -> unit Deferred.t
val ws_url : t -> string
val rest_url : t -> string

(** Every connection accepted so far, [(conn, at_ms)], [conn] counting from 1 in accept order. *)
val accepts : t -> (int * int) list

(** Every text message received on a websocket, [(conn, at_ms, text)], in order. *)
val received : t -> (int * int * string) list

(** How many stream frames have been sent on [conn]. *)
val streamed : t -> conn:int -> int

(** The REST request bodies received, in order. *)
val rest_requests : t -> string list

(** Whether [conn] has subscribed to a fast [l2Book] ([l2Book] with ["fast": true]): true of a fast
    connection, false of a deep one and of one that subscribed to nothing. *)
val carries_fast_book : t -> conn:int -> bool

(** The coins of the [subscribe] requests received on [conn], per subscription type, e.g. [("trades", "BTC")];
    [("allDexsAssetCtxs", "")] has no coin. *)
val subscribed_on : t -> conn:int -> (string * string) list

(** A [meta] response with these coins in its universe, the second list flagged [isDelisted]. *)
val meta_json : live:string list -> delisted:string list -> string

(** A [perpDexs] response: [null] for the main dex then one object per name. *)
val perp_dexs_json : string list -> string

(** A REST handler serving [perpDexs], [meta] and [spotMeta] with the given universe on dex [""]. *)
val rest_of_universe : (unit -> string list) -> request:string -> string

(** A [trades] frame for a coin. *)
val trades_frame : coin:string -> seq:int -> string
