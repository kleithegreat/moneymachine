open Core

type t =
  { limit : int
  ; window_ms : int
  ; recent : int Queue.t
  }

let create ~limit ~window_ms = { limit; window_ms; recent = Queue.create () }

let reserve t ~now_ms ~n =
  let last = Option.value (Queue.last t.recent) ~default:now_ms in
  let earliest = Int.max now_ms last in
  let keep = Int.max 0 (t.limit - n) in
  let overflow = Queue.length t.recent - keep in
  let at =
    if overflow > 0
    then Int.max earliest (Queue.get t.recent (overflow - 1) + t.window_ms)
    else earliest
  in
  for _ = 1 to n do
    Queue.enqueue t.recent at
  done;
  while Queue.length t.recent > t.limit do
    ignore (Queue.dequeue_exn t.recent : int)
  done;
  at
;;
