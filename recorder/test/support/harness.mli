(** Helpers for the end-to-end tests: temporary roots, running and killing the built [mmrec], reading recordings.

    ASSUMPTION (a question for the spec): [mmrec run] accepts the test flags [--ws-url URL], [--rest-url URL] and
    [--listings-interval-s N] (defaults: Hyperliquid's own endpoints and 3600). RECORDER.md's Interface lists
    none of them. *)

open Async

val now_ms : unit -> int

(** A fresh empty directory. *)
val tmp_dir : unit -> string

(** The built executable, relative to the test's working directory. *)
val mmrec_exe : string

(** Runs [mmrec run <root> ...] against the fake, [extra] flags appended. Its output is drained and discarded. *)
val spawn_run
  :  root:string
  -> ?listings_interval_s:int
  -> ?extra:string list
  -> Fake_hl.t
  -> Process.t Deferred.t

(** Runs [mmrec] with arguments to completion, returning its exit status and stdout. *)
val run_cli : string list -> (Core_unix.Exit_or_signal.t * string) Deferred.t

val send_signal : Process.t -> Signal.t -> unit

(** Polls every 50 ms until the condition holds or the timeout passes (raises). *)
val wait_until : timeout_s:float -> what:string -> (unit -> bool) -> unit Deferred.t

(** Every [*.jsonl.zst] under a directory, sorted. *)
val recordings : string -> string list

val read_file : string -> string

(** The content of a recording by the independent [zstd -dc] binary; raises if zstd reports an error. *)
val zstd_binary_decode : string -> string

(** The lines of every recording of a channel under [root], in path order, each parsed far enough to give
    [(recv, conn, msg-as-JSON)], via Yojson. *)
val channel_lines : root:string -> channel:string -> (int * int option * Yojson.Safe.t) list

(** The names of the [events] under [root] with their JSON, in order of [recv]. *)
val events : root:string -> (int * int option * string * Yojson.Safe.t) list

(** The decompressed content of every recording of a channel under [root], in path order, whole frames only. *)
val raw_channel_data : root:string -> channel:string -> string

(** [(coin, tid)] of the first trade of every line of the [trades] channel, in order. *)
val trade_ids : root:string -> (string * int) list

(** Sends SIGTERM and waits for exit: the status and the seconds it took. *)
val sigterm_and_wait : Process.t -> (Core_unix.Exit_or_signal.t * float) Deferred.t

(** The most items of the list (times in ms) inside one window [[t, t + window_ms)] starting at one of them. *)
val max_in_window : int list -> window_ms:int -> int

(** [(coin, tid)] ids per coin are exactly [1 .. m] for some [m]: no hole, no repeat. Returns [(coin, m)]. *)
val contiguous_prefixes : (string * int) list -> (string * int) list

(** [write_frames ~path chunks] creates [path] (and its directories) holding one zstd frame per chunk, made with
    [Mmrec.Zstd.compress]. *)
val write_frames : path:string -> string list -> unit

(** [in_order n ~f] is [[f 0; ...; f (n-1)]] with [f] called in that order (for stateful [f]). *)
val in_order : int -> f:(int -> 'a) -> 'a list

(** Raises with the message unless the condition holds. *)
val check : bool -> string -> unit

(** Runs a scenario under the Async scheduler and exits 0 if it returns, 1 if it raises. *)
val main : string -> (unit -> unit Deferred.t) -> unit
