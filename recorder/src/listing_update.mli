(** Comparing two hourly listings (RECORDER.md, Behaviour: "Listings change"). *)

type action =
  | Subscribe of
      { conn : int
      ; sub : Sub.t
      }
  | Unsubscribe of
      { conn : int
      ; sub : Sub.t
      }
  | Record of Event.t

(** [apply planner ~before ~after] compares the active coins of the last read with those of this one. Each new
    coin is added to the planner: [Subscribe] for its two subscriptions and a [listing] event naming it in a
    [coin] field, or, if refused, only a [refused] event naming it in a [coin] field. Each coin gone is removed:
    [Unsubscribe] for its subscriptions and a [listing] event naming it. Nothing else is dropped. *)
val apply : Planner.t -> before:string list -> after:string list -> action list
