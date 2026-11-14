(** Where a recording lives (RECORDER.md, Storage). *)

(** [<root>/<channel>/<YYYYMMDD>/<HH>.<run>.jsonl.zst], the date and hour being those of [recv_ms] in UTC and [run]
    the run's start in ms. *)
val of_recv : root:string -> Route.t -> run:int -> recv_ms:int -> string

(** The UTC hour of [recv_ms] as [YYYYMMDDHH]. *)
val hour_key : recv_ms:int -> string
