(* Assumed interface: Engine.Machine and Mm2_lean.Machine start/feed/finish,
   A18 flat chunks and A19 rows as events_support.ml. CLI start PROGRAM HEADER
   STATE, feed STATE CHUNK_JSON, finish STATE OUTDIR, inspect HEADER CHUNK_JSON.
   mm2_archive.Reader snapshot_file/trade_file/merge/coin_rules/archive_day/archive
   and Duckdb.exec are the real OCaml/C readers described in events_support.ml;
   emit callbacks receive A18 chunks, never normalized decimal doubles.
   Policy kernel2/protected-windows.json is compiled strict JSON data:
   [{start:integer-ms,end:integer-ms,released:bool}], with no runtime override.
   Synthetic disk fixtures for step 3 tests 3/5; no local archive in @runtest. *)

open Events_support
module R = Mm2_archive.Reader

let collect read =
  let chunks = ref [] in
  let result = read (fun value -> chunks := value :: !chunks) in
  result, List.rev !chunks

let flatten chunks : M.chunk =
  { records = Bytes.concat Bytes.empty (List.map (fun (c : M.chunk) -> c.records) chunks);
    integers = Array.concat (List.map (fun (c : M.chunk) -> c.integers) chunks);
    doubles = Array.concat (List.map (fun (c : M.chunk) -> c.doubles) chunks) }

let same_chunk left right =
  check "reader record bytes" (left.M.records = right.M.records);
  check "reader integer bytes" (left.M.integers = right.M.integers);
  check "reader double bits, not approximate decimals"
    (Array.map Int64.bits_of_float left.M.doubles = Array.map Int64.bits_of_float right.M.doubles)

let sql_string text = "'" ^ String.concat "''" (String.split_on_char '\'' text) ^ "'"

let synthetic_snapshots () =
  with_file ".parquet" (fun path ->
    Sys.remove path;
    Mm2_archive.Duckdb.exec
      (Printf.sprintf
        "COPY (SELECT * FROM (VALUES (%Ld::BIGINT, [99.0::DOUBLE,98.0], [2.0::DOUBLE,4.0], [101.0::DOUBLE,102.0], [3.0::DOUBLE,5.0]), (%Ld::BIGINT, []::DOUBLE[], []::DOUBLE[], [101.0::DOUBLE], [3.0::DOUBLE]), (%Ld::BIGINT,[102.0::DOUBLE],[1.0::DOUBLE],[101.0::DOUBLE],[1.0::DOUBLE]), (%Ld::BIGINT,[100.0::DOUBLE],[0.29::DOUBLE],[102.0::DOUBLE],[1.93::DOUBLE])) t(time,bid_px,bid_sz,ask_px,ask_sz)) TO %s (FORMAT PARQUET)"
        base (at 1) (at 2) (at 3) (sql_string path));
    let result, chunks = collect (fun emit -> R.snapshot_file ~path ~coin:1 ~delta:7 ~emit) in
    let counts = get result in
    check "reader counts crossed and empty quotes" (counts.dropped = 2);
    check "no fabricated deduplication" (counts.deduplicated = 0);
    let expected = chunk
      [ record ~a:2 ~b:2 ~coin:1 ~known:(at 7) 3 base [] [ 99.;2.;98.;4.;101.;3.;102.;5. ];
        record ~a:1 ~b:1 ~coin:1 ~known:(at 10) 3 (at 3) [] [ 100.;0.29;102.;1.93 ] ]
    in
    same_chunk (flatten chunks) expected;
    let state, rows = feed_chunks (get (M.start program (header ~delta:7 ~encoding:"double" ()))) chunks in
    let last, summary = M.finish state in
    success (json summary);
    check "real reader's bytes reach Lean" (M.count state = 2L && String.length (append rows last).trace > 0))

let trade_line ?(coin = "A") ?(price = "100") time id =
  Printf.sprintf {|{"coin":"%s","time":%Ld,"tid":%d,"px":"%s","sz":"1.93","side":"A"}|}
    coin time id price ^ "\n"

let disk_ids () =
  with_file ".jsonl" (fun path ->
    let first = trade_line base 7 in
    write path (first ^ trade_line (at 1) 8);
    let result, chunks = collect (fun emit -> R.trade_file ~path ~coin:0 ~delta:5 ~emit) in
    let counts = get result in
    check "unique canonical coin-day has no deduplication" (counts.deduplicated = 0);
    same_chunk (flatten chunks)
      (chunk [ trade ~known:(at 5) ~size:"1.93" base 7;
               trade ~known:(at 6) ~size:"1.93" (at 1) 8 ]);
    List.iter
      (fun contents ->
        write path contents;
        let result, emitted = collect (fun emit -> R.trade_file ~path ~coin:0 ~delta:0 ~emit) in
        check "reader refuses id reuse anywhere on disk" (Result.is_error result);
        check "disk id validation precedes emission" (emitted = []))
      [ first ^ first;
        first ^ trade_line (at 1) 8 ^ trade_line (at 2) 7;
        first ^ trade_line ~price:"101" base 7 ];
    write path (trade_line base 7);
    ignore (get (R.trade_file ~path ~coin:0 ~delta:0 ~emit:ignore));
    write path (trade_line (Int64.add base 86_400_000L) 7);
    ignore (get (R.trade_file ~path ~coin:0 ~delta:0 ~emit:ignore)))

let merge_order () =
  let a = [ funding ~hour:base base; trade base 1; trade base 2; quote base;
            observation base 1.; observation ~source:1 base 2. ] in
  let b = [ ending ~coin:1 base ] in
  let expected = [ ending ~coin:1 base; funding ~hour:base base; trade base 1;
                   trade base 2; quote base; observation base 1.; observation ~source:1 base 2. ] in
  List.iter
    (fun streams -> same_chunk (flatten (get (R.merge streams))) (chunk expected))
    [ [ List.map (fun e -> chunk [e]) a; [ chunk b ] ];
      [ [chunk b]; [chunk a] ]; [ [chunk []]; [chunk b]; [chunk a]; [] ] ];
  let _, _, summary = run [ expected ] in
  success summary

let grid_from_meta () =
  with_file ".json" (fun path ->
    write path {|{"universe":[{"name":"BTC","szDecimals":5},{"name":"ETH","szDecimals":4},{"name":"SOL","szDecimals":2},{"name":"ZERO","szDecimals":0},{"name":"SIX","szDecimals":6}]}|};
    check "grid derives only from szDecimals"
      (R.coin_rules path = Ok [ "BTC",5,5,1; "ETH",4,5,2; "SOL",2,5,4; "ZERO",0,5,6; "SIX",6,5,0 ]);
    write path {|{"universe":[{"name":"TOO_FINE","szDecimals":7}]}|};
    check "reader stops for szDecimals above six" (Result.is_error (R.coin_rules path)))

let () =
  synthetic_snapshots (); disk_ids (); merge_order (); grid_from_meta ();
  print_endline "step3 synthetic readers: passed"
