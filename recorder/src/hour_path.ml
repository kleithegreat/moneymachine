open Core

let ms_per_hour = 3_600_000
let ms_per_day = 24 * ms_per_hour

let hour_key ~recv_ms =
  let date = Date.add_days Date.unix_epoch (recv_ms / ms_per_day) in
  let hour = recv_ms / ms_per_hour % 24 in
  sprintf "%04d%02d%02d%02d" (Date.year date) (Month.to_int (Date.month date)) (Date.day date) hour
;;

let of_recv ~root route ~run ~recv_ms =
  let key = hour_key ~recv_ms in
  sprintf
    "%s/%s/%s/%s.%d.jsonl.zst"
    root
    (Route.dir route)
    (String.prefix key 8)
    (String.suffix key 2)
    run
;;
