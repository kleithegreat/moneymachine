open Core
open Async

let now_ms () = Time_ns.to_int_ns_since_epoch (Time_ns.now ()) / 1_000_000

let tmp_dir () =
  let base = Option.value (Sys.getenv "TMPDIR") ~default:"/tmp" in
  Core_unix.mkdtemp (Filename.concat base "mmrec-test-")
;;

let mmrec_exe = "../../bin/mmrec.exe"

let drain_all process =
  don't_wait_for (Reader.drain (Process.stdout process));
  don't_wait_for (Reader.drain (Process.stderr process))
;;

let spawn_run ~root ?(env = []) ?(listings_interval_s = 3600) ?(extra = []) fake =
  let args =
    [ "run"
    ; root
    ; "--ws-url"
    ; Fake_hl.ws_url fake
    ; "--rest-url"
    ; Fake_hl.rest_url fake
    ; "--listings-interval-s"
    ; Int.to_string listings_interval_s
    ]
    @ extra
  in
  let%map process = Process.create_exn ~prog:mmrec_exe ~args ~env:(`Extend env) () in
  drain_all process;
  process
;;

let run_cli args =
  let%bind process = Process.create_exn ~prog:mmrec_exe ~args () in
  let stdout = Reader.contents (Process.stdout process) in
  don't_wait_for (Reader.drain (Process.stderr process));
  let%bind out = stdout in
  let%map status = Process.wait process in
  status, out
;;

let send_signal process signal = Signal_unix.send_exn signal (`Pid (Process.pid process))

let wait_until ~timeout_s ~what condition =
  let deadline = Time_ns.add (Time_ns.now ()) (Time_ns.Span.of_sec timeout_s) in
  let rec loop () =
    if condition ()
    then return ()
    else if Time_ns.( > ) (Time_ns.now ()) deadline
    then failwithf "timed out waiting for: %s" what ()
    else (
      let%bind () = after (Time_float.Span.of_ms 50.) in
      loop ())
  in
  loop ()
;;

let rec recordings dir =
  match Sys_unix.file_exists dir with
  | `Yes ->
    Sys_unix.ls_dir dir
    |> List.sort ~compare:String.compare
    |> List.concat_map ~f:(fun name ->
      let path = Filename.concat dir name in
      match Sys_unix.is_directory path with
      | `Yes -> recordings path
      | _ -> if String.is_suffix name ~suffix:".jsonl.zst" then [ path ] else [])
  | _ -> []
;;

let read_file path = In_channel.read_all path

let zstd_binary_decode path =
  let command = sprintf "zstd -dc %s" (Filename.quote path) in
  let channel = Core_unix.open_process_in command in
  let out = In_channel.input_all channel in
  match Core_unix.close_process_in channel with
  | Ok () -> out
  | Error _ -> failwithf "zstd -dc failed on %s" path ()
;;

let lines_of_text text = List.filter (String.split_lines text) ~f:(fun l -> not (String.is_empty l))

let whole_lines text =
  match String.rindex text '\n' with
  | None -> ""
  | Some i -> String.prefix text (i + 1)
;;

let zstd_lenient_decode path =
  let command = sprintf "zstd -dc %s 2>/dev/null" (Filename.quote path) in
  let channel = Core_unix.open_process_in command in
  let out = In_channel.input_all channel in
  ignore (Core_unix.close_process_in channel : Core_unix.Exit_or_signal.t);
  whole_lines out
;;

let parse_line line =
  match Yojson.Safe.from_string line with
  | `Assoc fields ->
    let recv =
      match List.Assoc.find_exn fields ~equal:String.equal "recv" with
      | `Int n -> n
      | _ -> failwith "recv"
    in
    let conn =
      match List.Assoc.find_exn fields ~equal:String.equal "conn" with
      | `Int n -> Some n
      | `Null -> None
      | _ -> failwith "conn"
    in
    recv, conn, List.Assoc.find_exn fields ~equal:String.equal "msg"
  | _ -> failwith "line is not an object"
;;

let lines_in_file path = List.map (lines_of_text (zstd_lenient_decode path)) ~f:parse_line

let channel_lines ~root ~channel =
  List.concat_map (recordings (Filename.concat root channel)) ~f:lines_in_file
;;

let events ~root =
  channel_lines ~root ~channel:"events"
  |> List.filter_map ~f:(fun (recv, conn, msg) ->
    match msg with
    | `Assoc fields ->
      (match List.Assoc.find fields ~equal:String.equal "event" with
       | Some (`String name) -> Some (recv, conn, name, msg)
       | _ -> None)
    | _ -> None)
  |> List.stable_sort ~compare:(fun (a, _, _, _) (b, _, _, _) -> Int.compare a b)
;;

let raw_channel_data ~root ~channel =
  recordings (Filename.concat root channel)
  |> List.map ~f:zstd_lenient_decode
  |> String.concat
;;

let trade_ids ~root =
  channel_lines ~root ~channel:"trades"
  |> List.map ~f:(fun (_, _, msg) ->
    let open Yojson.Safe.Util in
    let first = msg |> member "data" |> to_list |> List.hd_exn in
    first |> member "coin" |> to_string, first |> member "tid" |> to_int)
;;

let sigterm_and_wait process =
  let started = Time_ns.now () in
  send_signal process Signal.term;
  let%map status = Process.wait process in
  status, Time_ns.Span.to_sec (Time_ns.diff (Time_ns.now ()) started)
;;

let max_in_window times ~window_ms =
  let arr = Array.of_list (List.sort times ~compare:Int.compare) in
  let best = ref 0 in
  Array.iteri arr ~f:(fun i start ->
    let j = ref i in
    while !j < Array.length arr && arr.(!j) < start + window_ms do
      incr j
    done;
    best := Int.max !best (!j - i));
  !best
;;

let contiguous_prefixes ids =
  let by_coin = Map.of_alist_multi (module String) ids in
  Map.to_alist by_coin
  |> List.map ~f:(fun (coin, tids) ->
    let sorted = List.sort tids ~compare:Int.compare in
    let m = List.length sorted in
    if not (List.equal Int.equal sorted (List.init m ~f:(fun i -> i + 1)))
    then failwithf "ids of %s are not 1..%d" coin m ();
    coin, m)
;;

let write_stream ~path chunks =
  Core_unix.mkdir_p (Filename.dirname path);
  let command = sprintf "zstd -9 -q --check -f -o %s" (Filename.quote path) in
  let channel = Core_unix.open_process_out command in
  List.iter chunks ~f:(Out_channel.output_string channel);
  match Core_unix.close_process_out channel with
  | Ok () -> ()
  | Error _ -> failwithf "zstd failed writing %s" path ()
;;

let cut_copy ~src ~dst ~bytes =
  Core_unix.mkdir_p (Filename.dirname dst);
  Out_channel.write_all dst ~data:(String.prefix (read_file src) bytes)
;;

let hour_of_ms ms =
  let time = Time_ns.of_int_ns_since_epoch (ms * 1_000_000) in
  let date, ofday = Time_ns.to_date_ofday time ~zone:Time_float.Zone.utc in
  let hour = Time_ns.Ofday.to_span_since_start_of_day ofday |> Time_ns.Span.to_hr |> Float.to_int in
  sprintf "%04d%02d%02d%02d" (Date.year date) (Month.to_int (Date.month date)) (Date.day date) hour
;;

let faketime_library () =
  let path = Option.value (Sys.getenv "PATH") ~default:"" in
  let bin =
    String.split path ~on:':'
    |> List.find_map ~f:(fun dir ->
      let candidate = Filename.concat dir "faketime" in
      if Sys_unix.file_exists_exn candidate then Some candidate else None)
  in
  match bin with
  | None -> failwith "faketime is not on PATH"
  | Some bin ->
    let real = Filename_unix.realpath bin in
    Filename.concat (Filename.dirname (Filename.dirname real)) "lib/libfaketime.so.1"
;;

let faketime_env ~at_ms =
  let offset_s = ((at_ms - now_ms ()) / 1000) in
  [ "LD_PRELOAD", faketime_library ()
  ; "FAKETIME", sprintf "%+d" offset_s
  ; "FAKETIME_NO_CACHE", "1"
  ]
;;

let in_order n ~f =
  let acc = ref [] in
  for i = 0 to n - 1 do
    acc := f i :: !acc
  done;
  List.rev !acc
;;

let check condition message = if not condition then failwith message

let run_all scenarios =
  let%bind failures =
    Deferred.List.filter_map scenarios ~how:`Sequential ~f:(fun (name, scenario) ->
      match%map Monitor.try_with scenario with
      | Ok () -> None
      | Error exn -> Some (sprintf "[%s] %s" name (Exn.to_string exn)))
  in
  if List.is_empty failures then return () else failwith (String.concat ~sep:"\n" failures)
;;

let main name scenario =
  upon
    (Monitor.try_with scenario)
    (function
      | Ok () ->
        printf "PASS %s\n" name;
        shutdown 0
      | Error exn ->
        eprintf "FAIL %s: %s\n" name (Exn.to_string exn);
        shutdown 1);
  never_returns (Scheduler.go ())
;;

let channel_dirs root =
  match Sys_unix.file_exists root with
  | `Yes -> Sys_unix.ls_dir root |> List.sort ~compare:String.compare
  | _ -> []
;;

let all_lines ~root =
  List.concat_map (channel_dirs root) ~f:(fun channel ->
    List.map (channel_lines ~root ~channel) ~f:(fun (recv, conn, msg) -> channel, recv, conn, msg))
;;

let parse_check text =
  String.split_lines text
  |> List.map ~f:(fun line ->
    let fields = String.split line ~on:'\t' in
    match fields with
    | "gap" :: _ -> fields @ List.init (Int.max 0 (4 - List.length fields)) ~f:(fun _ -> "")
    | _ -> fields)
;;

let shell_output command =
  let channel = Core_unix.open_process_in command in
  let out = In_channel.input_all channel in
  ignore (Core_unix.close_process_in channel : Core_unix.Exit_or_signal.t);
  out
;;
