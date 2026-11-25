open Core

let ms_per_hour = 3_600_000
let ms_per_day = 24 * ms_per_hour
let suffix = ".jsonl.zst"

let hour_key ~recv_ms =
  let date = Date.add_days Date.unix_epoch (recv_ms / ms_per_day) in
  let hour = recv_ms / ms_per_hour % 24 in
  sprintf
    "%04d%02d%02d%02d"
    (Date.year date)
    (Month.to_int (Date.month date))
    (Date.day date)
    hour
;;

let of_recv ~root route ~run ~recv_ms =
  let key = hour_key ~recv_ms in
  sprintf
    "%s/%s/%s/%s.%d%s"
    root
    (Route.dir route)
    (String.prefix key 8)
    (String.suffix key 2)
    run
    suffix
;;

let hour_and_run_of_name name =
  let open Option.Let_syntax in
  let%bind stem = String.chop_suffix name ~suffix in
  let hh = String.prefix stem 2 in
  let rest = String.drop_prefix stem 2 in
  let%bind () =
    Option.some_if (String.length hh = 2 && String.for_all hh ~f:Char.is_digit) ()
  in
  let%map run =
    match String.chop_prefix rest ~prefix:"." with
    | _ when String.is_empty rest -> Some (-1)
    | Some digits
      when (not (String.is_empty digits)) && String.for_all digits ~f:Char.is_digit ->
      Int.of_string_opt digits
    | _ -> None
  in
  hh, run
;;
