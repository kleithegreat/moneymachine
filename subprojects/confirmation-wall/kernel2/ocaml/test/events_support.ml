(* Step 3 assumed interface, supplied by the builder, not by these tests.
   Lean Engine.Machine: start : String -> String -> Except String State;
   feed : State -> Chunk -> State × Rows; finish : State -> Rows × String.
   Chunk is A18's three flat arrays; Rows has report/trace strings (A19).
   OCaml Mm2_lean.Machine mirrors these as start/feed/finish below, with
   snapshot : state -> string (canonical complete state, including pending
   timestamp), count : state -> int64, retained_bytes : state -> int64
   (all transitively owned Lean allocations, NOT OCaml's custom-block size).
   type chunk = { records : bytes; integers : int64 array; doubles : float array }
   type rows = { report : string; trace : string }; feed returns state * rows;
   start returns (state,string) result; finish returns rows * summary JSON.
   No feed closes a timestamp merely because its chunk ends.

   mm2 start PROGRAM HEADER STATE writes a private state/spool and prints
   {ok:true,build:SHA256,identity:SHA256}; feed STATE CHUNK_JSON appends a
   chunk, printing status only; finish STATE OUTPUT_DIRECTORY prints A19's
   summary and publishes report.tsv/trace.tsv ONLY on success. CHUNK_JSON is
   {records:lowercase hex,integers:[signed decimal strings],doubles:[16-digit
   binary64 hex]}. Errors exit 1; usage/unknown options exit 2 with no values.
   inspect HEADER CHUNK_JSON prints ONLY {size,sha256,records,stale}, where
   stale is [{coin,start,end}], intervals half-open. Size/hash concern CHUNK_JSON.
   All subcommands accept exactly their positional operands, no policy override.

   OCaml library mm2_archive: Reader.snapshot_file ~path ~coin ~delta ~emit
   emits A18 chunks with double bits untouched; Reader.trade_file ~path ~coin
   ~delta ~emit reads CANONICAL coin-day JSONL {coin,time,tid,px,sz,side}, B/A
    aggressors, strings placed without a scale. A source-specific once-per-side
   normalization (A3), when applicable, precedes this canonical file and counts
    what it deduplicated.
   Reader.merge takes a list of chunk lists and returns a chunk
   list ordered by A18 (including source order). These return (value,string)
   result; reader counts have dropped/deduplicated int fields. Duckdb.exec
   : string -> unit makes synthetic Parquet fixtures through the real C API.
   Reader.coin_rules : string -> ((string * int * int * int) list,string) result reads meta
   universe[].name,szDecimals and returns name,sz,5,6-sz, rejecting sz>6.
   Reader.archive_day ~root ~meta ~coin ~day ~delta ~emit checks raw manifests
   and snapshot counts/hours before emitting; root ITSELF has raw/,snapshots/.
   Reader.archive ~root ~meta ~coins ~first ~last ~delta ~emit streams/merges
   every snapshot in [first,last); known missing hours are gaps, not errors;
   a short existing table is an error, not silently repaired or skipped.
   Duckdb.scalar_int64 : string -> int64 runs a scalar timestamp-count query.
   Machine.start accepts the empty string for an admission-only run, with no
   program/clock, as used by B5 (distinct from the empty-slots timed program).

   Tracked policy: kernel2/protected-windows.json, UTF-8 JSON array, entries
   exactly {start:integer milliseconds,end:integer milliseconds,released:bool}.
   Includes unreleased [1793491200000,1801353600000). Strict build-time data
   compilation; unknown/missing/repeated keys or non-data input fails build.
   No runtime path, environment variable, CLI option or header overrides it.
   Mm2_identity.build ~sources:(path,bytes) list ~toolchain:string list -> hash
   excludes ONLY that exact policy path; identity ~build ~windows ~inputs
   hashes policy as well. embedded_sources/toolchain/windows/build expose the
   ACTUAL build inputs; compile_windows is the SAME strict build-time parser.
   All dates/data in sandbox tests are synthetic. Local tests alone read data.
*)

module M = Mm2_lean.Machine

let check name condition = if not condition then failwith name

let get = function
  | Ok value -> value
  | Error error -> failwith error
;;

let json = Yojson.Basic.from_string
let field name value = Yojson.Basic.Util.member name value
let int_field name value = field name value |> Yojson.Basic.Util.to_int
let text_field name value = field name value |> Yojson.Basic.Util.to_string
let base = 1_775_174_400_000L
let protected_start = 1_793_491_200_000L
let protected_end = 1_801_353_600_000L
let at offset = Int64.add base (Int64.of_int offset)

let program =
  {|{"version":2,"tick":1,"decide_every":1,"leverage":1,"sources":[],"params":[],"let":[],"slots":[],"probes":[]}|}
;;

let header
      ?(first = base)
      ?(last = at 125_000)
      ?(delta = 0)
      ?(stale = 60_000)
      ?(encoding = "string")
      ()
  =
  Printf.sprintf
    {|{"horizon":{"start":%Ld,"end":%Ld},"venue":{"fill":"optimistic","lambda":0,"delta":%d,"stale":%d,"cap":"10000","minimum":"10"},"cash":"10000","coins":[{"name":"A","sz_decimals":2,"figures":5,"decimals":4,"tiers":[{"from":"0","max_leverage":10}]},{"name":"B","sz_decimals":2,"figures":5,"decimals":4,"tiers":[{"from":"0","max_leverage":10}]}],"fees":[{"from":%Ld,"tier":"base","maker":"0.00015","taker":"0.00045"}],"sources":{"listings":{"lag":0},"funding":{"encoding":"string","lag":0,"late":1000},"quotes":{"encoding":"%s"},"trades":{"encoding":"%s"},"observations":[{"name":"vol","unit":"1","kind":"state","lag":0},{"name":"flow","unit":"1","kind":"flow","lag":0}]},"aliases":{"coins":{},"sources":{}}}|}
    first
    last
    delta
    stale
    first
    encoding
    encoding
;;

type event =
  { record : bytes
  ; ints : int64 list
  ; floats : float list
  }

let record
      ?(a = 0)
      ?(b = 0)
      ?(c = 0)
      ?(coin = 0)
      ?(source = 0)
      ?known
      kind
      time
      ints
      floats
  =
  let bytes = Bytes.make 24 '\000' in
  Bytes.set bytes 0 (Char.chr kind);
  Bytes.set bytes 1 (Char.chr a);
  Bytes.set bytes 2 (Char.chr b);
  Bytes.set bytes 3 (Char.chr c);
  Bytes.set_uint16_le bytes 4 coin;
  Bytes.set_uint16_le bytes 6 source;
  Bytes.set_int64_le bytes 8 time;
  Bytes.set_int64_le bytes 16 (Option.value known ~default:time);
  { record = bytes; ints; floats }
;;

let placed text =
  let digits, places = get (Mm2_lean.Decimal.place text) in
  [ Int64.of_string digits; Int64.of_int places ]
;;

let trade ?(coin = 0) ?known ?(price = "100") ?(size = "1") ?(side = 1) time id =
  record ~a:side ~coin ?known 2 time ((Int64.of_int id :: placed price) @ placed size) []
;;

let quote ?(coin = 0) ?known ?(bid = "99") ?(ask = "101") time =
  record
    ~a:1
    ~b:1
    ~coin
    ?known
    3
    time
    (placed bid @ placed "2" @ placed ask @ placed "3")
    []
;;

let ending ?(coin = 0) ?(price = "0") time = record ~a:1 ~coin 0 time (placed price) []

let funding ?(coin = 0) ?known ~hour time =
  record ~coin ?known 1 time (hour :: placed "0.0001") []
;;

let observation ?(coin = 0) ?(source = 0) ?known time value =
  record ~coin ~source ?known 4 time [] [ value ]
;;

let chunk events : M.chunk =
  { records = Bytes.concat Bytes.empty (List.map (fun e -> e.record) events)
  ; integers = Array.of_list (List.concat_map (fun e -> e.ints) events)
  ; doubles = Array.of_list (List.concat_map (fun e -> e.floats) events)
  }
;;

let empty_rows : M.rows = { report = ""; trace = "" }

let append (left : M.rows) (right : M.rows) : M.rows =
  { report = left.report ^ right.report; trace = left.trace ^ right.trace }
;;

let feed_chunks state chunks =
  List.fold_left
    (fun (state, rows) next ->
       let state, emitted = M.feed state next in
       state, append rows emitted)
    (state, empty_rows)
    chunks
;;

let run ?(market = header ()) groups =
  let state, emitted =
    feed_chunks (get (M.start program market)) (List.map chunk groups)
  in
  let last, summary = M.finish state in
  state, append emitted last, json summary
;;

let success summary =
  check "admitted nonempty market must finish" (field "ok" summary = `Bool true)
;;

let lines text = String.split_on_char '\n' text |> List.filter (fun s -> s <> "")

let rejection ?(market = header ()) expected groups =
  let _, _, summary = run ~market groups in
  check ("expected " ^ expected) (text_field "error" summary = expected);
  check "error summary has no report" (field "report" summary = `Null);
  check "error summary has no trace" (field "trace" summary = `Null);
  let state = get (M.start program market) in
  let state, _ = feed_chunks state (List.map chunk groups) in
  let rows, _ = M.finish state in
  check "finish of rejection emits neither kind of row" (rows = empty_rows)
;;

let with_file suffix body =
  let path = Filename.temp_file "mm2-step3-" suffix in
  Fun.protect ~finally:(fun () -> Sys.remove path) (fun () -> body path)
;;

let write path text =
  let channel = open_out_bin path in
  Fun.protect
    ~finally:(fun () -> close_out channel)
    (fun () -> output_string channel text)
;;

let read path =
  let channel = open_in_bin path in
  Fun.protect
    ~finally:(fun () -> close_in channel)
    (fun () -> In_channel.input_all channel)
;;

let hex bytes =
  String.init
    (2 * Bytes.length bytes)
    (fun i ->
       let n = Char.code (Bytes.get bytes (i / 2)) in
       "0123456789abcdef".[if i mod 2 = 0 then n lsr 4 else n land 15])
;;

let chunk_json (value : M.chunk) =
  Yojson.Basic.to_string
    (`Assoc
        [ "records", `String (hex value.records)
        ; ( "integers"
          , `List
              (Array.to_list
                 (Array.map (fun n -> `String (Int64.to_string n)) value.integers)) )
        ; ( "doubles"
          , `List
              (Array.to_list
                 (Array.map
                    (fun f -> `String (Printf.sprintf "%016Lx" (Int64.bits_of_float f)))
                    value.doubles)) )
        ])
;;

let command executable arguments =
  let input =
    Unix.open_process_args_in executable (Array.of_list (executable :: arguments))
  in
  let buffer = Buffer.create 256 in
  (try
     while true do
       Buffer.add_string buffer (input_line input);
       Buffer.add_char buffer '\n'
     done
   with
   | End_of_file -> ());
  let status = Unix.close_process_in input in
  status, Buffer.contents buffer
;;
