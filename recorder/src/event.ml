open Core

type t =
  { name : string
  ; fields : (string * Yojson.Safe.t) list
  }

let make name fields = { name; fields }
let name t = t.name
let field t key = List.Assoc.find t.fields ~equal:String.equal key

let to_line ~recv_ms ~conn t =
  let conn = Option.value_map conn ~default:"null" ~f:Int.to_string in
  let msg = Yojson.Safe.to_string (`Assoc (("event", `String t.name) :: t.fields)) in
  sprintf {|{"recv":%d,"conn":%s,"msg":%s}|} recv_ms conn msg ^ "\n"
;;
