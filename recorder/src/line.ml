open Core

let sanitize s = String.map s ~f:(function '\r' | '\n' -> ' ' | c -> c)

let of_frame ~recv_ms ~conn frame =
  sprintf {|{"recv":%d,"conn":%d,"msg":%s}|} recv_ms conn (sanitize frame) ^ "\n"
;;
