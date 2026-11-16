(** The vault collector (VAULT.md): one pass over one account's REST data, appended under
    [<root>/vault/<user>/]. It reads only identity fields and [time] of items and never prints. *)

type config =
  { root : string
  ; user : string
  ; rest_url : string
  ; now_ms : int
  }

(** One run. [true] when every pull completed. *)
val run : config -> bool Async.Deferred.t
