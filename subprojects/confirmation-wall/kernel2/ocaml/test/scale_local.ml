(* LOCAL ONLY, step 3 test 6: scale_local ARCHIVE_ROOT REPO_ROOT METRICS_JSON.
   Real archive, sixteen coins of 2026-04-03 or the whole 212-day window;
   no program/clock. --day measures the actual suite-sized day locally.
   Reader.archive, coin_rules and Duckdb.scalar_int64 have the signatures in
   events_support.ml. Read only dates before 2026-11-01, never forward data.
   Requires admission's retained readings and Exact.readBitsFast via csimp;
   no new OCaml entry point. One OS core, under twelve hours and 2 GB for
   the window (470 seconds for --day). Time, peak RSS, counts and verdict are
   persisted to METRICS_JSON; rows stream to private .report.spool/.trace.spool
   beside it. These spools are not published reports (step 9 owns publication).
   All three paths must be new. Quote counts are independently checked on
   disk; manifest failures are failures, never a skip or a repair. *)

open Events_support
module R = Mm2_archive.Reader
module S = Scale_support

let day index =
  let seconds =
    Int64.to_float
      (Int64.div (Int64.add base (Int64.mul (Int64.of_int index) 86_400_000L)) 1000L)
  in
  let date = Unix.gmtime seconds in
  Printf.sprintf "%04d%02d%02d" (date.tm_year + 1900) (date.tm_mon + 1) date.tm_mday
;;

let sql_string text = "'" ^ String.concat "''" (String.split_on_char '\'' text) ^ "'"

let worker mode root repo output =
  S.check_one_core ();
  let days, last_day, budget =
    match mode with
    | "day" -> 1, "20260404", 470.
    | "window" -> 212, "20261101", 43200.
    | _ -> failwith "unknown benchmark mode"
  in
  let last = Int64.add base (Int64.mul (Int64.of_int days) 86_400_000L) in
  check "window ends at protected boundary, never beyond it" (last <= protected_start);
  if days = 212 then check "exactly 212 pre-forward days" (last = protected_start);
  let metrics = S.exclusive_output output in
  Fun.protect
    ~finally:(fun () -> close_out metrics)
    (fun () ->
       let meta = Filename.concat repo "venue/hyperliquid/meta-2026-11-16.json" in
       let all_rules = get (R.coin_rules meta) in
       let rules =
         List.map
           (fun coin -> List.find (fun (name, _, _, _) -> name = coin) all_rules)
           S.coins
       in
       let paths =
         List.concat_map
           (fun coin ->
              List.filter_map
                (fun i ->
                   let date = day i in
                   check "no protected paths" (date < "20261101");
                   let path =
                     Filename.concat root ("snapshots/" ^ coin ^ "/" ^ date ^ ".parquet")
                   in
                   if Sys.file_exists path then Some path else None)
                (List.init days Fun.id))
           S.coins
       in
       check
         "sixteen histories, not a toy benchmark"
         (List.length paths >= if days = 1 then 16 else 16 * 200);
       Mm2_archive.Duckdb.exec "SET threads=1; SET memory_limit='256MB'";
       let expected =
         Mm2_archive.Duckdb.scalar_int64
           (Printf.sprintf
              "SELECT count(*)::BIGINT FROM read_parquet([%s]) WHERE time >= %Ld AND \
               time < %Ld"
              (String.concat "," (List.map sql_string paths))
              base
              last)
       in
       check
         "benchmark has recorded scale"
         (if days = 1 then expected = 2_487_176L else expected >= 200_000_000L);
       let report = S.exclusive_output (output ^ ".report.spool") in
       Fun.protect
         ~finally:(fun () -> close_out report)
         (fun () ->
            let trace = S.exclusive_output (output ^ ".trace.spool") in
            Fun.protect
              ~finally:(fun () -> close_out trace)
              (fun () ->
                 let maximum = ref 0L
                 and streamed = ref 0L
                 and fed = ref 0L in
                 let started = Unix.gettimeofday () in
                 let verdict = ref "interrupted" in
                 Fun.protect
                   ~finally:(fun () ->
                     let elapsed = Unix.gettimeofday () -. started
                     and rss = S.peak_rss () in
                     let result =
                       `Assoc
                         [ "mode", `String mode
                         ; "coins", `Int 16
                         ; "days", `Int days
                         ; "core", `String (S.status "Cpus_allowed_list")
                         ; "seconds", `Float elapsed
                         ; "budget_seconds", `Float budget
                         ; "peak_rss", `Int (Int64.to_int rss)
                         ; "native_state", `Int (Int64.to_int !maximum)
                         ; "expected", `Int (Int64.to_int expected)
                         ; "fed", `Int (Int64.to_int !fed)
                         ; "streamed_bytes", `Int (Int64.to_int !streamed)
                         ; "verdict", `String !verdict
                         ]
                     in
                     output_string metrics (Yojson.Basic.to_string result ^ "\n");
                     flush metrics;
                     Unix.fsync (Unix.descr_of_out_channel metrics);
                     Printf.printf "%s\n%!" (Yojson.Basic.to_string result))
                   (fun () ->
                      let state = ref (get (M.start "" (S.market ~last rules))) in
                      let consume (rows : M.rows) =
                        output_string report rows.report;
                        output_string trace rows.trace;
                        streamed
                        := Int64.add
                             !streamed
                             (Int64.of_int
                                (String.length rows.report + String.length rows.trace))
                      in
                      let emit value =
                        let next, rows = M.feed !state value in
                        state := next;
                        fed := M.count next;
                        maximum := Int64.max !maximum (M.retained_bytes next);
                        consume rows;
                        check
                          "native state below 2GB throughout"
                          (!maximum < 2_000_000_000L)
                      in
                      let counts =
                        get
                          (R.archive
                             ~root
                             ~meta
                             ~coins:S.coins
                             ~first:"20260403"
                             ~last:last_day
                             ~delta:0
                             ~emit)
                      in
                      let rows, summary = M.finish !state in
                      consume rows;
                      flush report;
                      flush trace;
                      success (json summary);
                      check
                        "every snapshot fed or explicitly dropped, none sampled"
                        (Int64.add
                           !fed
                           (Int64.of_int (counts.dropped + counts.deduplicated))
                         = expected);
                      check
                        "benchmark did not replace tape with drops"
                        (if days = 1 then !fed = 2_487_176L else !fed >= 200_000_000L);
                      check "strict B5 wall" (Unix.gettimeofday () -. started < budget);
                      check "whole-process RSS below 2GB" (S.peak_rss () < 2_000_000_000L);
                      verdict := "passed"))))
;;

let () =
  match Array.to_list Sys.argv with
  | [ _; "--worker"; mode; root; repo; output ] -> worker mode root repo output
  | [ _; root; repo; output ] -> S.launch 43200 [ "window"; root; repo; output ]
  | [ _; "--day"; root; repo; output ] -> S.launch 470 [ "day"; root; repo; output ]
  | _ -> failwith "usage: scale_local [--day] ARCHIVE_ROOT REPO_ROOT METRICS_JSON"
;;
