type action =
  | Send_ping
  | Reopen

let ping_after_ms = 30_000
let reopen_after_ms = 45_000

type t =
  { mutable last_received_ms : int
  ; mutable pinged : bool
  }

let create ~now_ms = { last_received_ms = now_ms; pinged = false }

let received t ~now_ms =
  t.last_received_ms <- now_ms;
  t.pinged <- false
;;

let poll t ~now_ms =
  let idle = now_ms - t.last_received_ms in
  if idle >= reopen_after_ms
  then [ Reopen ]
  else if idle >= ping_after_ms && not t.pinged
  then (
    t.pinged <- true;
    [ Send_ping ])
  else []
;;
