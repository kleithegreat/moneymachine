open Core

type entry =
  { channel : string
  ; hour : string
  ; bytes : int
  ; files : int
  ; lines : int
  ; state : Recording.state
  }
[@@deriving sexp_of, equal]

type gap =
  { conn : int
  ; closed_ms : int
  ; reopened_ms : int option
  }
[@@deriving sexp_of, equal]

type report =
  { entries : entry list
  ; gaps : gap list
  }
[@@deriving sexp_of, equal]

let list_dir path =
  match Sys_unix.is_directory path with
  | `Yes -> Sys_unix.ls_dir path |> List.sort ~compare:String.compare
  | `No | `Unknown -> []
;;

let hour_and_run_of_name = Hour_path.hour_and_run_of_name

let files_in_range ~root ~from_ ~to_ =
  List.concat_map (list_dir root) ~f:(fun channel ->
    List.concat_map
      (list_dir (Filename.concat root channel))
      ~f:(fun date ->
        let dir = String.concat ~sep:"/" [ root; channel; date ] in
        List.filter_map (list_dir dir) ~f:(fun name ->
          let%bind.Option hh, run = hour_and_run_of_name name in
          let hour = date ^ hh in
          if String.compare hour from_ >= 0 && String.compare hour to_ <= 0
          then Some ((hour, run), (channel, hour, Filename.concat dir name))
          else None)))
  |> List.stable_sort ~compare:(fun (a, _) (b, _) -> [%compare: string * int] a b)
  |> List.map ~f:snd
;;

type fact =
  { recv_ms : int
  ; conn : int option
  ; event : string
  }

let field name = function
  | `Assoc fields -> List.Assoc.find fields ~equal:String.equal name
  | _ -> None
;;

let event_fact line =
  match Yojson.Safe.from_string line with
  | exception Yojson.Json_error _ -> None
  | json ->
    (match
       ( field "conn" json
       , field "recv" json
       , Option.bind (field "msg" json) ~f:(field "event") )
     with
     | Some (`Int conn), Some (`Int recv_ms), Some (`String event) ->
       Some { recv_ms; conn = Some conn; event }
     | Some `Null, Some (`Int recv_ms), Some (`String event) ->
       Some { recv_ms; conn = None; event }
     | _ -> None)
;;

type scan =
  { channel : string
  ; hour : string
  ; bytes : int
  ; lines : int
  ; state : Recording.state
  ; last_line : (int * int) list
  ; facts : fact list
  }

let scan (channel, hour, path) =
  let is_events = String.equal channel (Route.dir Route.Events) in
  let last = Hashtbl.create (module Int) in
  let note_line (lines, facts) line =
    Option.iter (Line.envelope line) ~f:(fun (recv_ms, conn) ->
      Option.iter conn ~f:(fun conn ->
        Hashtbl.update
          last
          conn
          ~f:(Option.value_map ~default:recv_ms ~f:(Int.max recv_ms))));
    let facts =
      if is_events
      then Option.fold (event_fact line) ~init:facts ~f:(fun facts fact -> fact :: facts)
      else facts
    in
    lines + 1, facts
  in
  let (lines, facts), state = Recording.fold_lines path ~init:(0, []) ~f:note_line in
  let facts = List.rev facts in
  { channel
  ; hour
  ; bytes = (Core_unix.stat path).st_size |> Int64.to_int_exn
  ; lines
  ; state
  ; last_line = Hashtbl.to_alist last
  ; facts
  }
;;

let gaps_of_facts facts ~last_lines =
  let closed = Hashtbl.create (module Int) in
  let is_open = Hash_set.create (module Int) in
  let close conn at_ms =
    ignore (Hashtbl.add closed ~key:conn ~data:at_ms : [ `Ok | `Duplicate ])
  in
  let last_line_before conn ~ms =
    List.filter_map last_lines ~f:(fun (c, recv_ms) ->
      Option.some_if (c = conn && recv_ms < ms) recv_ms)
    |> List.max_elt ~compare:Int.compare
  in
  let finished =
    List.concat_map facts ~f:(fun fact ->
      match fact.event, fact.conn with
      | ("close" | "error"), Some conn ->
        Hash_set.remove is_open conn;
        close conn fact.recv_ms;
        []
      | "open", Some conn ->
        Hash_set.add is_open conn;
        Option.to_list
          (Option.map (Hashtbl.find_and_remove closed conn) ~f:(fun closed_ms ->
             { conn; closed_ms; reopened_ms = Some fact.recv_ms }))
      | "start", _ ->
        Hash_set.iter is_open ~f:(fun conn ->
          Option.iter (last_line_before conn ~ms:fact.recv_ms) ~f:(close conn));
        Hash_set.clear is_open;
        []
      | _ -> [])
  in
  let unfinished =
    Hashtbl.fold closed ~init:[] ~f:(fun ~key:conn ~data:closed_ms acc ->
      { conn; closed_ms; reopened_ms = None } :: acc)
  in
  List.sort (finished @ unfinished) ~compare:(fun a b ->
    Int.compare a.closed_ms b.closed_ms)
;;

let entries_of scans =
  let by_hour_channel =
    Hashtbl.create
      (module struct
        type t = string * string [@@deriving compare, hash, sexp_of]
      end)
  in
  List.iter scans ~f:(fun s ->
    Hashtbl.update by_hour_channel (s.channel, s.hour) ~f:(function
      | None ->
        { channel = s.channel
        ; hour = s.hour
        ; bytes = s.bytes
        ; files = 1
        ; lines = s.lines
        ; state = s.state
        }
      | Some e ->
        { e with
          bytes = e.bytes + s.bytes
        ; files = e.files + 1
        ; lines = e.lines + s.lines
        ; state = Recording.worst_state e.state s.state
        }));
  Hashtbl.data by_hour_channel
;;

let check ~root ~from_ ~to_ =
  let scans = List.map (files_in_range ~root ~from_ ~to_) ~f:scan in
  { entries = entries_of scans
  ; gaps =
      gaps_of_facts
        (List.concat_map scans ~f:(fun s -> s.facts))
        ~last_lines:(List.concat_map scans ~f:(fun s -> s.last_line))
  }
;;

let render report =
  let entries =
    List.sort report.entries ~compare:(fun a b ->
      [%compare: string * string] (a.hour, a.channel) (b.hour, b.channel))
  in
  let entry_line (e : entry) =
    String.concat
      ~sep:"\t"
      [ e.hour
      ; e.channel
      ; Int.to_string e.bytes
      ; Int.to_string e.files
      ; Int.to_string e.lines
      ; Recording.state_to_string e.state
      ]
  in
  let gap_line (g : gap) =
    String.concat
      ~sep:"\t"
      [ "gap"
      ; Int.to_string g.conn
      ; Int.to_string g.closed_ms
      ; Option.value_map g.reopened_ms ~default:"" ~f:Int.to_string
      ]
  in
  String.concat
    (List.map
       (List.map entries ~f:entry_line @ List.map report.gaps ~f:gap_line)
       ~f:(fun l -> l ^ "\n"))
;;
