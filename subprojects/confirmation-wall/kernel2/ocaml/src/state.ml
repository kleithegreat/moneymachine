type t

external create : unit -> t = "mm2_stub_state_create"
external bump : t -> unit = "mm2_stub_state_bump"
external counter : t -> int = "mm2_stub_state_counter"
external created_total : unit -> int = "mm2_stub_created_total"
external released_total : unit -> int = "mm2_stub_released_total"
