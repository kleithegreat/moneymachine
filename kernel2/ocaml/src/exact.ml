external call : string -> string -> string = "mm2_stub_exact"

type rat = string * string

let run op arguments =
  let reply = call op (String.concat " " arguments) in
  if reply = "malformed" then failwith ("Exact." ^ op ^ ": malformed arguments") else reply

let rat_arguments (numerator, denominator) = [ numerator; denominator ]

let rat_of_reply reply =
  match String.split_on_char '/' reply with
  | [ numerator; denominator ] -> numerator, denominator
  | _ -> failwith ("Exact: not a rational: " ^ reply)

let unsigned bits = Printf.sprintf "%Lu" bits
let binary operation a b = rat_of_reply (run operation (rat_arguments a @ rat_arguments b))
let mul = binary "mul"
let round_down = binary "round_down"
let round_up = binary "round_up"
let round_size = binary "round_size"

let nearest_bits value =
  Int64.of_string ("0u" ^ run "nearest_bits" (rat_arguments value))

let read_bits scale bits =
  match String.split_on_char ' ' (run "read_bits" [ string_of_int scale; unsigned bits ]) with
  | [ "none" ] -> None
  | [ "some"; scaled ] -> Some scaled
  | _ -> failwith "Exact.read_bits: unexpected reply"

let put_placed scale (digits, places) =
  match
    String.split_on_char ' '
      (run "put_placed" [ string_of_int scale; digits; string_of_int places ])
  with
  | [ "ok"; scaled ] -> Ok scaled
  | [ "error"; code ] -> Error code
  | _ -> failwith "Exact.put_placed: unexpected reply"

let on_grid figures decimals price =
  match run "on_grid" ([ string_of_int figures; string_of_int decimals ] @ rat_arguments price) with
  | "true" -> true
  | "false" -> false
  | _ -> failwith "Exact.on_grid: unexpected reply"

let grid operation figures decimals price =
  rat_of_reply
    (run operation ([ string_of_int figures; string_of_int decimals ] @ rat_arguments price))

let grid_step = grid "grid_step"
let round_price_buy = grid "round_price_buy"
let round_price_sell = grid "round_price_sell"
