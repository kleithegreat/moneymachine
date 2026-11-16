module M = Mm2_lean.Machine

type counts = { dropped : int; deduplicated : int }

let protected_day = "20261101"
let day_ms = 86_400_000
let events_per_chunk = 2048
let max_levels = 20

let quote_sql path =
  Printf.sprintf
    "SELECT time, bid_px, bid_sz, ask_px, ask_sz FROM read_parquet('%s')"
    (String.concat "''" (String.split_on_char '\'' path))

(* The days of the civil calendar, as days since 1970-01-01 (Hinnant's algorithm). *)
let days_from_civil year month day =
  let y = if month <= 2 then year - 1 else year in
  let era = (if y >= 0 then y else y - 399) / 400 in
  let yoe = y - (era * 400) in
  let doy = ((153 * (if month > 2 then month - 3 else month + 9)) + 2) / 5 + day - 1 in
  let doe = (yoe * 365) + (yoe / 4) - (yoe / 100) + doy in
  (era * 146097) + doe - 719468

let civil_of_days z =
  let z = z + 719468 in
  let era = (if z >= 0 then z else z - 146096) / 146097 in
  let doe = z - (era * 146097) in
  let yoe = (doe - (doe / 1460) + (doe / 36524) - (doe / 146096)) / 365 in
  let y = yoe + (era * 400) in
  let doy = doe - ((365 * yoe) + (yoe / 4) - (yoe / 100)) in
  let mp = ((5 * doy) + 2) / 153 in
  let d = doy - (((153 * mp) + 2) / 5) + 1 in
  let m = if mp < 10 then mp + 3 else mp - 9 in
  (if m <= 2 then y + 1 else y), m, d

let parse_day text =
  if String.length text <> 8 || not (String.for_all (fun c -> c >= '0' && c <= '9') text) then None
  else
    Some
      (days_from_civil (int_of_string (String.sub text 0 4)) (int_of_string (String.sub text 4 2))
         (int_of_string (String.sub text 6 2)))

let day_text days =
  let y, m, d = civil_of_days days in
  Printf.sprintf "%04d%02d%02d" y m d

exception Bad of string

let guard f = try f () with Failure message -> Error message | Sys_error message -> Error message

(* A18's quote events, built from rows and cut into chunks. *)
type builder = {
  mutable records : Bytes.t;
  mutable events : int;
  doubles : float array;
  mutable used : int;
  emit : M.chunk -> unit;
}

let builder emit =
  { records = Bytes.create (24 * events_per_chunk); events = 0;
    doubles = Array.make (events_per_chunk * 4 * max_levels) 0.; used = 0; emit }

let flush b =
  if b.events > 0 then begin
    b.emit { M.records = Bytes.sub b.records 0 (24 * b.events); integers = [||];
             doubles = Array.sub b.doubles 0 b.used };
    b.events <- 0;
    b.used <- 0
  end

let add_quote b ~coin ~delta ~time ~bids ~asks (values : float array array) offs =
  if b.events = events_per_chunk then flush b;
  let at = 24 * b.events in
  Bytes.fill b.records at 24 '\000';
  Bytes.set_uint8 b.records at 3;
  Bytes.set_uint8 b.records (at + 1) bids;
  Bytes.set_uint8 b.records (at + 2) asks;
  Bytes.set_uint16_le b.records (at + 4) coin;
  Bytes.set_int64_le b.records (at + 8) (Int64.of_int time);
  Bytes.set_int64_le b.records (at + 16) (Int64.of_int (time + delta));
  let put side_px side_sz levels =
    for k = 0 to levels - 1 do
      b.doubles.(b.used) <- values.(side_px).(offs.(side_px) + k);
      b.doubles.(b.used + 1) <- values.(side_sz).(offs.(side_sz) + k);
      b.used <- b.used + 2
    done
  in
  put 0 1 bids;
  put 2 3 asks;
  b.events <- b.events + 1

(* One coin's rows, across its day files in order. *)
type stream = {
  coin : int;
  mutable paths : string list;
  mutable cursor : Duckdb.cursor option;
  mutable batch : Duckdb.batch;
  mutable row : int;
  offs : int array;
  mutable head : int;
  mutable last : int;
}

let empty_batch = { Duckdb.n = 0; times = Bytes.empty; lens = [||]; values = [||] }
let exhausted = max_int

let stream coin paths =
  { coin; paths; cursor = None; batch = empty_batch; row = 0; offs = Array.make 4 0; head = exhausted;
    last = min_int }

let time_at (s : stream) = Int64.to_int (Bytes.get_int64_le s.batch.times (8 * s.row))

let close s =
  match s.cursor with
  | Some c -> Duckdb.close_cursor c; s.cursor <- None
  | None -> ()

(* Loads rows until one lies in [lo, hi), or the stream ends. *)
let rec load s ~lo ~hi =
  if s.row < s.batch.n then begin
    let t = time_at s in
    if t >= lo && t < hi then s.head <- t else skip s ~lo ~hi
  end
  else
    match s.cursor with
    | Some c -> begin
        match Duckdb.next_quotes c with
        | Some batch ->
          s.batch <- batch; s.row <- 0; Array.fill s.offs 0 4 0; load s ~lo ~hi
        | None -> close s; load s ~lo ~hi
      end
    | None -> begin
        match s.paths with
        | [] -> s.head <- exhausted
        | path :: rest ->
          s.paths <- rest;
          s.cursor <- Some (Duckdb.open_cursor (quote_sql path));
          s.batch <- empty_batch; s.row <- 0;
          load s ~lo ~hi
      end

and skip s ~lo ~hi = step s; load s ~lo ~hi

and step s =
  for c = 0 to 3 do
    s.offs.(c) <- s.offs.(c) + s.batch.lens.((c * s.batch.n) + s.row)
  done;
  s.row <- s.row + 1

let advance s ~lo ~hi = step s; load s ~lo ~hi

let run_streams streams ~lo ~hi ~delta ~emit =
  let b = builder emit in
  let dropped = ref 0 and deduplicated = ref 0 in
  let live = Array.of_list streams in
  Array.iter (fun s -> load s ~lo ~hi) live;
  let rec loop () =
    let best = ref (-1) in
    Array.iteri (fun i s -> if s.head <> exhausted && (!best < 0 || s.head < live.(!best).head) then best := i) live;
    if !best >= 0 then begin
      let s = live.(!best) in
      let n = s.batch.n and r = s.row in
      let len c = s.batch.lens.((c * n) + r) in
      let bids = len 0 and asks = len 2 in
      if len 1 <> bids || len 3 <> asks then raise (Bad "a quote whose prices and sizes differ in count");
      if bids > max_levels || asks > max_levels then raise (Bad "a quote with more than 20 levels");
      let t = s.head in
      if t = s.last then incr deduplicated
      else if t < s.last then incr dropped
      else begin
        s.last <- t;
        let crossed =
          bids = 0 || asks = 0
          || s.batch.values.(2).(s.offs.(2)) <= s.batch.values.(0).(s.offs.(0))
        in
        if crossed then incr dropped
        else add_quote b ~coin:s.coin ~delta ~time:t ~bids ~asks s.batch.values s.offs
      end;
      advance s ~lo ~hi;
      loop ()
    end
  in
  Fun.protect ~finally:(fun () -> Array.iter close live)
    (fun () ->
      try
        loop ();
        flush b;
        Ok { dropped = !dropped; deduplicated = !deduplicated }
      with Bad message -> Error message)

let snapshot_file ~path ~coin ~delta ~emit =
  guard (fun () -> run_streams [ stream coin [ path ] ] ~lo:min_int ~hi:max_int ~delta ~emit)

let contains text part =
  let n = String.length text and m = String.length part in
  let rec at i = i + m <= n && (String.sub text i m = part || at (i + 1)) in
  at 0

let coin_rules path =
  try
    let doc = Yojson.Basic.from_file path in
    let universe = Yojson.Basic.Util.(doc |> member "universe" |> to_list) in
    let rule coin =
      let name = Yojson.Basic.Util.(coin |> member "name" |> to_string) in
      let sz = Yojson.Basic.Util.(coin |> member "szDecimals" |> to_int) in
      if sz > 6 then raise (Bad (Printf.sprintf "%s has szDecimals %d above 6" name sz));
      name, sz, 5, 6 - sz
    in
    Ok (List.map rule universe)
  with
  | Bad message -> Error message
  | Yojson.Json_error message -> Error message
  | Yojson.Basic.Util.Type_error (message, _) -> Error message
  | Sys_error message -> Error message

let raw_hours root coin day =
  List.filter
    (fun h -> Sys.file_exists (Printf.sprintf "%s/raw/%s/%d/%s.lz4" root day h coin))
    (List.init 24 Fun.id)

let ints text = String.concat "," (List.map string_of_int text)

(* A coin-day's table against its raw files: the hours recorded in the table are the hours on disk. *)
let manifest root coin day =
  let table = Printf.sprintf "%s/snapshots/%s/%s.parquet" root coin day in
  let raw = raw_hours root coin day in
  match Sys.file_exists table, raw with
  | false, [] -> Ok None
  | false, _ -> Error (Printf.sprintf "%s %s: no snapshot table for %d raw files" coin day (List.length raw))
  | true, _ ->
    let recorded =
      Duckdb.scalar_string
        (Printf.sprintf
           "SELECT decode(value) FROM parquet_kv_metadata('%s') WHERE decode(key) = 'source_hours'" table)
    in
    let hours =
      try Yojson.Basic.Util.(Yojson.Basic.from_string recorded |> to_list |> List.map to_int)
      with _ -> []
    in
    if hours = raw then Ok (Some table)
    else
      let short = List.length hours < List.length raw in
      Error
        (Printf.sprintf "%s %s: snapshot table %s its raw files (table hours [%s], raw hours [%s])" coin day
           (if short then "short of" else "differs from") (ints hours) (ints raw))

let days_between first last =
  match parse_day first, parse_day last with
  | Some a, Some b when a <= b -> Ok (List.init (b - a) (fun i -> day_text (a + i)))
  | _ -> Error (Printf.sprintf "bad day range %s..%s" first last)

let refuse_protected days =
  match List.find_opt (fun d -> d >= protected_day) days with
  | Some d -> Error (Printf.sprintf "day %s is in the protected window" d)
  | None -> Ok ()

let ( let* ) = Result.bind

let day_start day =
  match parse_day day with Some z -> z * day_ms | None -> 0

let archive ~root ~meta ~coins ~first ~last ~delta ~emit =
  guard (fun () ->
    let* rules = coin_rules meta in
    let* days = days_between first last in
    let* () = refuse_protected days in
    let* () =
      match List.find_opt (fun c -> not (List.exists (fun (n, _, _, _) -> n = c) rules)) coins with
      | Some c -> Error (Printf.sprintf "%s is not in the metadata's universe" c)
      | None -> Ok ()
    in
    let rec tables = function
      | [] -> Ok []
      | coin :: rest ->
        let rec per_day = function
          | [] -> Ok []
          | day :: more ->
            let* found = manifest root coin day in
            let* tail = per_day more in
            Ok (match found with Some path -> path :: tail | None -> tail)
        in
        let* paths = per_day days in
        let* others = tables rest in
        Ok (paths :: others)
    in
    let* paths = tables coins in
    let streams = List.mapi (fun i p -> stream i p) paths in
    let lo = day_start first and hi = day_start last in
    run_streams streams ~lo ~hi ~delta ~emit)

let archive_day ~root ~meta ~coin ~day ~delta ~emit =
  guard (fun () ->
    let* rules = coin_rules meta in
    let* () =
      if List.exists (fun (n, _, _, _) -> n = coin) rules then Ok ()
      else Error (Printf.sprintf "%s is not in the metadata's universe" coin)
    in
    let* () = refuse_protected [ day ] in
    let* found = manifest root coin day in
    match found with
    | None -> Error (Printf.sprintf "%s %s: no table and no raw files" coin day)
    | Some path -> run_streams [ stream 0 [ path ] ] ~lo:min_int ~hi:max_int ~delta ~emit)

(* Trades: a canonical coin-day JSONL, `{coin,time,tid,px,sz,side}`. *)
let trade_file ~path ~coin ~delta ~emit =
  guard (fun () ->
    let lines = In_channel.with_open_bin path In_channel.input_all |> String.split_on_char '\n' in
    let rows = List.filter (fun l -> l <> "") lines in
    let parsed =
      List.map
        (fun line ->
          let j = Yojson.Basic.from_string line in
          let open Yojson.Basic.Util in
          ( j |> member "time" |> to_int, j |> member "tid" |> to_int, j |> member "px" |> to_string,
            j |> member "sz" |> to_string, j |> member "side" |> to_string ))
        rows
    in
    let seen = Hashtbl.create 1024 in
    let* () =
      List.fold_left
        (fun acc (_, id, _, _, _) ->
          let* () = acc in
          if Hashtbl.mem seen id then Error (Printf.sprintf "trade id %d repeats in %s" id path)
          else (Hashtbl.add seen id (); Ok ()))
        (Ok ()) parsed
    in
    let place text =
      match Mm2_lean.Decimal.place text with
      | Ok (digits, places) -> Ok [ Int64.of_string digits; Int64.of_int places ]
      | Error e -> Error e
    in
    let encode (time, id, px, sz, side) =
      let* px = place px in
      let* sz = place sz in
      let* seller = match side with "A" -> Ok 1 | "B" -> Ok 0 | s -> Error ("unknown side " ^ s) in
      let record = Bytes.make 24 '\000' in
      Bytes.set_uint8 record 0 2;
      Bytes.set_uint8 record 1 seller;
      Bytes.set_uint16_le record 4 coin;
      Bytes.set_int64_le record 8 (Int64.of_int time);
      Bytes.set_int64_le record 16 (Int64.of_int (time + delta));
      Ok (record, Int64.of_int id :: (px @ sz))
    in
    let* encoded =
      List.fold_left
        (fun acc row -> let* rest = acc in let* e = encode row in Ok (e :: rest)) (Ok []) parsed
    in
    let encoded = List.rev encoded in
    let rec cut = function
      | [] -> ()
      | rows ->
        let rec take n l = if n = 0 then [], l else match l with [] -> [], [] | x :: t -> let a, b = take (n - 1) t in x :: a, b in
        let now, later = take events_per_chunk rows in
        emit { M.records = Bytes.concat Bytes.empty (List.map fst now);
               integers = Array.of_list (List.concat_map snd now); doubles = [||] };
        cut later
    in
    cut encoded;
    Ok { dropped = 0; deduplicated = 0 })

(* Merging already-encoded streams into A18's order; ties keep the streams' order. *)
type event = { key : int * int * int * int * int; record : bytes; ints : int64 list; floats : float list }

let take_list n l =
  let rec go n acc l = if n = 0 then List.rev acc, l else match l with [] -> raise (Bad "chunk arrays too short") | x :: t -> go (n - 1) (x :: acc) t in
  go n [] l

let events_of_chunk ~double (c : M.chunk) =
  let count = Bytes.length c.records / 24 in
  let ints = ref (Array.to_list c.integers) and floats = ref (Array.to_list c.doubles) in
  List.init count (fun r ->
    let record = Bytes.sub c.records (24 * r) 24 in
    let kind = Bytes.get_uint8 record 0 and a = Bytes.get_uint8 record 1 and b = Bytes.get_uint8 record 2 in
    let coin = Bytes.get_uint16_le record 4 and source = Bytes.get_uint16_le record 6 in
    let time = Int64.to_int (Bytes.get_int64_le record 8) in
    let exact numbers = if double then (0, numbers) else (2 * numbers, 0) in
    let wants_ints, wants_floats =
      match kind with
      | 0 ->
        if a = 1 then (2, 0)
        else begin
          match !ints with
          | _ :: count :: _ -> (2 + (3 * Int64.to_int count), 0)
          | _ -> raise (Bad "a listing without its tier count")
        end
      | 1 -> let i, f = exact (1 + a) in (i + 1, f)
      | 2 -> let i, f = exact 2 in (i + 1, f)
      | 3 -> exact (2 * (a + b))
      | 4 -> (0, 1)
      | 5 -> (0, 5)
      | _ -> raise (Bad "an unknown kind")
    in
    let mine_ints, rest_ints = take_list wants_ints !ints in
    let mine_floats, rest_floats = take_list wants_floats !floats in
    ints := rest_ints;
    floats := rest_floats;
    let cls = match kind with 0 -> 1 | 1 -> 2 | _ -> 3 in
    let rank = match kind with 5 -> 2 | k -> k in
    { key = (time, cls, coin, rank, source); record; ints = mine_ints; floats = mine_floats })

let merge ?(double = false) streams =
  try
    let events = List.concat_map (fun chunks -> List.concat_map (events_of_chunk ~double) chunks) streams in
    let sorted = List.stable_sort (fun x y -> compare x.key y.key) events in
    Ok
      [ { M.records = Bytes.concat Bytes.empty (List.map (fun e -> e.record) sorted);
          integers = Array.of_list (List.concat_map (fun e -> e.ints) sorted);
          doubles = Array.of_list (List.concat_map (fun e -> e.floats) sorted) } ]
  with Bad message -> Error message
