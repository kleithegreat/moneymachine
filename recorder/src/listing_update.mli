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

(** [first_read planner coins] is the read after a start: every coin is added to the planner ([Subscribe] for each of its
    subscriptions (two, or three on the main dex), or a [refused] event with a [coin] field if refused) and ONE [listing] event records each
    dex's count of perps (RECORDER.md, Storage: "Events"). The dex of a coin is the part of its name before [:],
    [""] for the main dex. *)
val first_read : Planner.t -> string list -> action list

(** [apply planner ~before ~after] compares the active coins of the last read with those of this one. Each new
    coin is added to the planner: [Subscribe] for each of its subscriptions (two, or three on the main dex) and a [listing] event with fields [coin],
    [dex] and [change] (["added"]), or, if refused, only a [refused] event with a [coin] field. Each coin gone is
    removed: [Unsubscribe] for each of its subscriptions and a [listing] event with [change] ["delisted"]. *)
val apply : Planner.t -> before:string list -> after:string list -> action list
