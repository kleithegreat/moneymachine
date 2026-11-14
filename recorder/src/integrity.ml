open Core

type entry =
  { channel : string
  ; hour : string
  ; bytes : int
  ; frames : int
  ; lines : int
  ; truncated : bool
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

let suffix = ".jsonl.zst"

let list_dir path =
  match Sys_unix.is_directory path with
  | `Yes -> Sys_unix.ls_dir path |> List.sort ~compare:String.compare
  | _ -> []
;;

let files_in_range ~root ~from_ ~to_ =
  List.concat_map (list_dir root) ~f:(fun channel ->
    List.concat_map (list_dir (Filename.concat root channel)) ~f:(fun date ->
      let dir = String.concat ~sep:"/" [ root; channel; date ] in
      List.filter_map (list_dir dir) ~f:(fun name ->
        match String.chop_suffix name ~suffix with
        | None -> None
        | Some hh ->
          let hour = date ^ hh in
          if String.compare hour from_ >= 0 && String.compare hour to_ <= 0
          then Some (channel, hour, Filename.concat dir name)
          else None)))
;;

let read_file path = In_channel.read_all path

let entry_of (channel, hour, path) =
  let raw = read_file path in
  let decoded = Frames.decode raw in
  let lines = String.count decoded.data ~f:(Char.equal '\n') in
  { channel; hour; bytes = String.length raw; frames = decoded.frames; lines; truncated = decoded.truncated }
;;

type fact =
  { recv_ms : int
  ; conn : int
  ; event : string
  }

let facts_of_line line =
  let open Yojson.Safe.Util in
  let json = Yojson.Safe.from_string line in
  match member "conn" json, member "recv" json, member "event" (member "msg" json) with
  | `Int conn, `Int recv_ms, `String event -> Some { recv_ms; conn; event }
  | _ -> None
;;

let facts path =
  (Frames.decode (read_file path)).data
  |> String.split_lines
  |> List.filter_map ~f:facts_of_line

let gaps_of_facts facts =
  let sorted = List.stable_sort facts ~compare:(fun a b -> Int.compare a.recv_ms b.recv_ms) in
  let closed = Hashtbl.create (module Int) in
  let finished =
    List.filter_map sorted ~f:(fun fact ->
      match fact.event with
      | "close" | "error" ->
        ignore (Hashtbl.add closed ~key:fact.conn ~data:fact.recv_ms : [ `Ok | `Duplicate ]);
        None
      | "open" ->
        Option.map (Hashtbl.find_and_remove closed fact.conn) ~f:(fun closed_ms ->
          { conn = fact.conn; closed_ms; reopened_ms = Some fact.recv_ms })
      | _ -> None)
  in
  let unfinished =
    Hashtbl.fold closed ~init:[] ~f:(fun ~key:conn ~data:closed_ms acc ->
      { conn; closed_ms; reopened_ms = None } :: acc)
  in
  List.sort (finished @ unfinished) ~compare:(fun a b -> Int.compare a.closed_ms b.closed_ms)
;;

let check ~root ~from_ ~to_ =
  let files = files_in_range ~root ~from_ ~to_ in
  let event_files =
    List.filter_map files ~f:(fun (channel, _, path) ->
      if String.equal channel (Route.dir Route.Events) then Some path else None)
  in
  { entries = List.map files ~f:entry_of
  ; gaps = gaps_of_facts (List.concat_map event_files ~f:facts)
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
      ; Int.to_string e.frames
      ; Int.to_string e.lines
      ; (if e.truncated then "yes" else "no")
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
  String.concat (List.map (List.map entries ~f:entry_line @ List.map report.gaps ~f:gap_line) ~f:(fun l -> l ^ "\n"))
;;
