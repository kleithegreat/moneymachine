(* LOCAL ONLY, step 3 test 6. Run scale_local ARCHIVE_ROOT REPO_ROOT.
   Engine.Machine/Mm2_lean.Machine start/feed/finish, count and retained_bytes
   (transitively owned native Lean state) are events_support.ml's interface.
   mm2 start PROGRAM HEADER STATE; feed STATE CHUNK_JSON; finish STATE OUTDIR;
   inspect HEADER CHUNK_JSON prints metadata only. Reader.archive streams the
   raw/-manifest-checked snapshots/ archive, in A18 order, through ~emit; it
   refuses a short table, never repairs it. Duckdb.scalar_int64 : string -> int64
   independently counts timestamp-column rows within the horizon, without
   opening price columns outside it. Metadata is universe[].name and
   szDecimals from venue/hyperliquid/meta-2026-11-16.json, never rules.json.
   kernel2/protected-windows.json is compiled strict [{start:integer-ms,
   end:integer-ms,released:bool}] data with no override. No forward files open.
   One OS core for the WHOLE worker, including DuckDB and foreign runtime;
   1200s hard timeout, <2,000,000,000 bytes native state AND whole-process peak
   RSS. Rows discarded after counting (streamed), never accumulated in state.
   A known short BTC table is an honest preflight failure, not a benchmark skip.
*)

open Events_support
module R = Mm2_archive.Reader

let coins = [ "ADA";"AVAX";"BCH";"BNB";"BTC";"DOGE";"ETH";"HBAR";
              "HYPE";"LINK";"NEAR";"SOL";"SUI";"TRX";"XLM";"XRP" ]
let last = protected_start

let day index =
  let seconds = Int64.to_float (Int64.div (Int64.add base (Int64.mul (Int64.of_int index) 86_400_000L)) 1000L) in
  let date = Unix.gmtime seconds in
  Printf.sprintf "%04d%02d%02d" (date.tm_year + 1900) (date.tm_mon + 1) date.tm_mday

let scalar key path =
  lines (read path) |> List.find_map (fun line ->
    match String.split_on_char ':' line with
    | [ name; value ] when name = key ->
      let number = String.trim value |> String.split_on_char ' ' |> List.hd in
      Some (Int64.of_string number)
    | _ -> None) |> Option.get

let sql_string text = "'" ^ String.concat "''" (String.split_on_char '\'' text) ^ "'"

let worker root repo =
  check "exactly 212 pre-forward days" (Int64.sub last base = Int64.mul 212L 86_400_000L);
  let meta = Filename.concat repo "venue/hyperliquid/meta-2026-11-16.json" in
  let rules = get (R.coin_rules meta) in
  let coin_headers = List.map (fun coin ->
    let _, sz, figures, decimals = List.find (fun (name, _, _, _) -> name = coin) rules in
    Printf.sprintf {|{"name":"%s","sz_decimals":%d,"figures":%d,"decimals":%d,"tiers":[{"from":"0","max_leverage":1}]}|}
      coin sz figures decimals |> json) coins
  in
  let market = match json (header ~last ~encoding:"double" ()) with
    | `Assoc fields -> `Assoc (List.map (fun (key, value) -> key, if key = "coins" then `List coin_headers else value) fields)
    | _ -> assert false
  in
  let paths = List.concat_map (fun coin -> List.filter_map (fun i ->
    let date = day i in
    check "no protected paths" (date < "20261101");
    let path = Filename.concat root ("snapshots/" ^ coin ^ "/" ^ date ^ ".parquet") in
    if Sys.file_exists path then Some path else None) (List.init 212 Fun.id)) coins
  in
  check "sixteen full coin histories, not a toy benchmark" (List.length paths >= 16 * 200);
  Mm2_archive.Duckdb.exec "SET threads=1; SET memory_limit='256MB'";
  let expected = Mm2_archive.Duckdb.scalar_int64
      (Printf.sprintf "SELECT count(*)::BIGINT FROM read_parquet([%s]) WHERE time >= %Ld AND time < %Ld"
        (String.concat "," (List.map sql_string paths)) base last) in
  check "benchmark has the recorded scale" (expected >= 200_000_000L);
  let started = Unix.gettimeofday () in
  let state = ref (get (M.start "" (Yojson.Basic.to_string market))) in
  let maximum = ref 0L and streamed_bytes = ref 0L in
  let emit value =
    let next, rows = M.feed !state value in
    state := next;
    maximum := Int64.max !maximum (M.retained_bytes next);
    streamed_bytes := Int64.add !streamed_bytes (Int64.of_int (String.length rows.report + String.length rows.trace));
    check "native state below 2GB throughout" (!maximum < 2_000_000_000L)
  in
  let counts = get (R.archive ~root ~meta ~coins ~first:"20260403" ~last:"20261101" ~delta:0 ~emit) in
  let rows, summary = M.finish !state in
  success (json summary);
  streamed_bytes := Int64.add !streamed_bytes (Int64.of_int (String.length rows.report + String.length rows.trace));
  let elapsed = Unix.gettimeofday () -. started in
  let rss = Int64.mul 1024L (scalar "VmHWM" "/proc/self/status") in
  Printf.printf "coins=16 days=212 quotes=%Ld seconds=%.3f native_state=%Ld peak_rss=%Ld streamed_bytes=%Ld\n%!"
    (M.count !state) elapsed !maximum rss !streamed_bytes;
  check "every snapshot fed or explicitly dropped, none sampled"
    (Int64.add (M.count !state) (Int64.of_int (counts.dropped + counts.deduplicated)) = expected);
  check "benchmark did not replace the tape with drops" (M.count !state >= 200_000_000L);
  check "strictly under twenty minutes" (elapsed < 1200.);
  check "whole-process RSS below 2GB (includes untracked native allocations)" (rss < 2_000_000_000L)

let () =
  match Array.to_list Sys.argv with
  | [ _; "--worker"; root; repo ] -> worker root repo
  | [ _; root; repo ] ->
    let line = lines (read "/proc/self/status") |> List.find (String.starts_with ~prefix:"Cpus_allowed_list:") in
    let allowed = String.sub line 18 (String.length line - 18) |> String.trim in
    let core = List.hd (String.split_on_char ',' allowed) |> String.split_on_char '-' |> List.hd in
    let executable = if Filename.is_relative Sys.executable_name then Filename.concat (Sys.getcwd ()) Sys.executable_name else Sys.executable_name in
    let args = [| "timeout"; "--signal=KILL"; "1200"; "taskset"; "-c"; core; executable; "--worker"; root; repo |] in
    let pid = Unix.create_process "timeout" args Unix.stdin Unix.stdout Unix.stderr in
    check "one-core benchmark completed within its hard deadline" (snd (Unix.waitpid [] pid) = Unix.WEXITED 0)
  | _ -> failwith "usage: scale_local ARCHIVE_ROOT REPO_ROOT"
