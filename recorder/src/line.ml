open Core

let sanitize s =
  String.map s ~f:(function
    | '\r' | '\n' -> ' '
    | c -> c)
;;

let date_json date =
  Option.value_map date ~default:"null" ~f:(fun d -> Yojson.Safe.to_string (`String d))
;;

let of_frame ~recv_ms ~conn frame =
  sprintf {|{"recv":%d,"conn":%d,"msg":%s}|} recv_ms conn (sanitize frame) ^ "\n"
;;

let of_response ~recv_ms ~request ?date response =
  sprintf
    {|{"recv":%d,"request":%s,"date":%s,"msg":%s}|}
    recv_ms
    request
    (date_json date)
    (sanitize response)
  ^ "\n"
;;

let of_listing ~recv_ms ~request ?date response =
  sprintf
    {|{"recv":%d,"conn":null,"request":%s,"date":%s,"msg":%s}|}
    recv_ms
    request
    (date_json date)
    (sanitize response)
  ^ "\n"
;;

let envelope line =
  let number ~from =
    let stop = ref from in
    while !stop < String.length line && Char.is_digit line.[!stop] do
      incr stop
    done;
    if !stop = from
    then None
    else
      Option.map
        (Int.of_string_opt (String.sub line ~pos:from ~len:(!stop - from)))
        ~f:(fun n -> n, !stop)
  in
  let recv_key = {|{"recv":|} in
  let conn_key = {|,"conn":|} in
  if not (String.is_prefix line ~prefix:recv_key)
  then None
  else (
    match number ~from:(String.length recv_key) with
    | None -> None
    | Some (recv_ms, after_recv) ->
      if not (String.is_substring_at line ~pos:after_recv ~substring:conn_key)
      then None
      else (
        let from = after_recv + String.length conn_key in
        if String.is_substring_at line ~pos:from ~substring:"null"
        then Some (recv_ms, None)
        else Option.map (number ~from) ~f:(fun (conn, _) -> recv_ms, Some conn)))
;;
