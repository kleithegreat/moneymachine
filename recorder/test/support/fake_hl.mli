(** A local fake of Hyperliquid for the offline tests: one plain-TCP port serving the websocket at any path and
    the REST [info] endpoint at any other, with no TLS. It parses requests with Yojson on its own, not with the
    library under test. Times are real, in ms since the epoch. *)

open Async

type config =
  { rest : request:string -> string  (** the response body for each REST request body *)
  ; ack_subscriptions : bool  (** answer subscribe with a [subscriptionResponse], ping with a [pong] *)
  ; close_after_ms : conn:int -> int option  (** the server closes connection [conn] this long after accepting it *)
  ; stream : (conn:int -> seq:int -> string) option
        (** once a connection has subscribed, send this frame every [stream_interval_ms] *)
  ; stream_interval_ms : int
  }

(** Acks, never closes, streams nothing, REST answers [{}]. *)
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
