open Core

type entry =
  { channel : string
  ; hour : string
  ; bytes : int
  ; files : int
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

(** [HH.jsonl.zst] (run -1, the earlier form) or [HH.<run>.jsonl.zst]: the hour's digits and the run. *)
let hour_and_run_of_name name =
  let open Option.Let_syntax in
  let%bind stem = String.chop_suffix name ~suffix in
  let hh = String.prefix stem 2 in
  let rest = String.drop_prefix stem 2 in
  let%bind () = Option.some_if (String.length hh = 2 && String.for_all hh ~f:Char.is_digit) () in
  let%map run =
    match String.chop_prefix rest ~prefix:"." with
    | _ when String.is_empty rest -> Some (-1)
    | Some digits when (not (String.is_empty digits)) && String.for_all digits ~f:Char.is_digit ->
      Some (Int.of_string digits)
    | _ -> None
  in
  hh, run
;;

(** The files of the range in recording order: by hour, then run. *)
let files_in_range ~root ~from_ ~to_ =
  List.concat_map (list_dir root) ~f:(fun channel ->
    List.concat_map (list_dir (Filename.concat root channel)) ~f:(fun date ->
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

let event_fact line =
  let open Yojson.Safe.Util in
  match Yojson.Safe.from_string line with
  | exception Yojson.Json_error _ -> None
  | json ->
    (match member "conn" json, member "recv" json, member "event" (member "msg" json) with
     | `Int conn, `Int recv_ms, `String event -> Some { recv_ms; conn = Some conn; event }
     | `Null, `Int recv_ms, `String event -> Some { recv_ms; conn = None; event }
     | _ -> None)
;;

type scan =
  { channel : string
  ; hour : string
  ; bytes : int
  ; lines : int
  ; truncated : bool
  ; last_line : (int * int) list
  ; facts : fact list
  }

let scan (channel, hour, path) =
  let is_events = String.equal channel (Route.dir Route.Events) in
  let last = Hashtbl.create (module Int) in
  let note_line (lines, facts) line =
    Option.iter (Line.envelope line) ~f:(fun (recv_ms, conn) ->
      Option.iter conn ~f:(fun conn ->
        Hashtbl.update last conn ~f:(Option.value_map ~default:recv_ms ~f:(Int.max recv_ms))));
    let facts =
      if is_events then Option.fold (event_fact line) ~init:facts ~f:(fun facts fact -> fact :: facts) else facts
    in
    lines + 1, facts
  in
  let (lines, facts), truncated = Recording.fold_lines path ~init:(0, []) ~f:note_line in
  let facts = List.rev facts in
  { channel
  ; hour
  ; bytes = (Core_unix.stat path).st_size |> Int64.to_int_exn
  ; lines
  ; truncated
  ; last_line = Hashtbl.to_alist last
  ; facts
  }
;;

let gaps_of_facts facts ~last_lines =
  let closed = Hashtbl.create (module Int) in
  let is_open = Hash_set.create (module Int) in
  let close conn at_ms = ignore (Hashtbl.add closed ~key:conn ~data:at_ms : [ `Ok | `Duplicate ]) in
  let last_line_before conn ~ms =
    List.filter_map last_lines ~f:(fun (c, recv_ms) -> Option.some_if (c = conn && recv_ms < ms) recv_ms)
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
  List.sort (finished @ unfinished) ~compare:(fun a b -> Int.compare a.closed_ms b.closed_ms)
;;

let entries_of scans =
  let by_hour_channel = Hashtbl.create (module struct
    type t = string * string [@@deriving compare, hash, sexp_of]
  end) in
  List.iter scans ~f:(fun s ->
    Hashtbl.update by_hour_channel (s.channel, s.hour) ~f:(function
      | None -> { channel = s.channel; hour = s.hour; bytes = s.bytes; files = 1; lines = s.lines; truncated = s.truncated }
      | Some e ->
        { e with
          bytes = e.bytes + s.bytes
        ; files = e.files + 1
        ; lines = e.lines + s.lines
        ; truncated = e.truncated || s.truncated
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
