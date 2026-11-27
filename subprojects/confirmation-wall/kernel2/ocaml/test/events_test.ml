(* Assumed interface: Engine.Machine start/feed/finish, A18 Chunk and A19 Rows;
   Mm2_lean.Machine start/feed/finish/snapshot/count/retained_bytes as documented
   in events_support.ml. CLI: mm2 start PROGRAM HEADER STATE; feed STATE CHUNK;
   finish STATE OUTDIR; inspect HEADER CHUNK (integrity metadata only).
   Reader: mm2_archive Reader.snapshot_file/trade_file/archive_day/archive/merge,
    raw doubles unchanged; see support.
   Policy: kernel2/protected-windows.json, strict JSON list of exactly
   {start:integer-ms,end:integer-ms,released:bool}, compiled in, never overridable.
   Tests 1, 3 and 4 of brief 3, step 3; all inputs are synthetic. *)

open Events_support

let rec replace path value document =
  match path, document with
  | [], _ -> value
  | name :: rest, `Assoc fields ->
    `Assoc
      (List.map
         (fun (key, original) ->
            key, if key = name then replace rest value original else original)
         fields)
  | _ -> failwith "bad test JSON path"
;;

let test_1 () =
  let q = quote base in
  let bad_cases =
    [ "time order", [ quote (at 2); trade (at 1) 1 ]
    ; "class order", [ quote (at 1); funding ~hour:base (at 1) ]
    ; "coin order", [ quote ~coin:1 (at 1); quote ~coin:0 (at 1) ]
    ; "kind order", [ quote (at 1); trade (at 1) 2 ]
    ; "source order", [ observation ~source:1 (at 1) 1.; observation (at 1) 2. ]
    ; "crossed", [ quote ~bid:"102" ~ask:"101" (at 1) ]
    ; "same timestamp id", [ trade (at 1) 17; trade (at 1) 17 ]
    ; "nonadjacent duplicate", [ trade (at 1) 17; trade (at 1) 18; trade (at 1) 17 ]
    ; "trade off grid", [ trade ~price:"100.001" (at 1) 1 ]
    ; "quote off grid", [ quote ~ask:"100.001" (at 1) ]
    ; "zero trade", [ trade ~price:"0" (at 1) 1 ]
    ; "zero bid", [ quote ~bid:"0" (at 1) ]
    ; "zero ask", [ quote ~bid:"0" ~ask:"0" (at 1) ]
    ; "negative settlement", [ ending ~price:"-1" (at 1) ]
    ; "after end", [ ending (at 1); quote (at 2) ]
    ; "funding at end", [ ending (at 1); funding ~hour:base (at 1) ]
    ; "trade at end", [ ending (at 1); trade (at 1) 1 ]
    ; "quote at end", [ ending (at 1); quote (at 1) ]
    ; "observation at end", [ ending (at 1); observation (at 1) 1. ]
    ]
  in
  List.iter
    (fun (name, expected, events) ->
       try
         rejection expected [ [ q ]; events; [ quote ~coin:1 (at 100_000) ] ];
         rejection expected (List.map (fun e -> [ e ]) (q :: events));
         let bad, prefix =
           match List.rev events with
           | bad :: rest -> bad, List.rev rest
           | [] -> failwith "empty rejection case"
         in
         let state, _ =
           M.feed (get (M.start program (header ()))) (chunk (q :: prefix))
         in
         let rejected, rows = M.feed state (chunk [ bad ]) in
         check "rejecting feed emits neither kind of row" (rows = empty_rows);
         let _, rows = M.feed rejected (chunk [ quote ~coin:1 (at 100_000) ]) in
         check "feed after rejection emits neither kind of row" (rows = empty_rows)
       with
       | Failure message -> failwith (name ^ ": " ^ message))
    (List.map (fun (name, events) -> name, "R_MARKET", events) bad_cases
     @ [ "lot excess decimals", "E_DECIMAL", [ trade ~size:"0.001" (at 1) 1 ] ]);
  List.iter
    (fun events -> rejection "E_DECIMAL" [ [ q ]; events ])
    [ [ trade ~price:"10000000" (at 1) 1 ]
    ; [ trade ~price:"100.000000001" (at 1) 1 ]
    ; [ trade ~size:"10000000000000" (at 1) 1 ]
    ];
  let new_rules = record ~a:0 ~b:3 ~c:5 0 (at 1) [ 3L; 1L; 0L; 0L; 10L ] [] in
  rejection
    "R_MARKET"
    [ [ quote ~bid:"1" ~ask:"1.0001" base ]
    ; [ new_rules; trade ~price:"1.0001" ~size:"1" (at 1) 8 ]
    ];
  List.iter
    (fun value ->
       let bad = record ~a:1 ~b:1 3 (at 1) [] [ 99.; 2.; value; 3. ] in
       rejection ~market:(header ~encoding:"double" ()) "E_DECIMAL" [ [ bad ] ])
    [ nan; infinity; 0.1 +. 0.2; 10_000_000. ];
  let _, rows, summary = run [ [ q; trade (at 1) 1; trade (at 2) 1; ending (at 3) ] ] in
  success summary;
  check
    "a zero settlement is legal"
    (List.mem (Printf.sprintf "end\t%Ld\tA\t0" (at 3)) (lines rows.trace));
  let _, _, summary = run [ [ q; ending (at 1); quote ~coin:1 (at 1) ] ] in
  success summary
;;

let encoding_and_lateness () =
  let malformed =
    [ record 6 base [] []
    ; record ~coin:2 3 base [] []
    ; record ~a:2 2 base ((1L :: placed "100") @ placed "1") []
    ; quote ~known:(at 1) base
    ; record ~a:0 ~b:1 3 base (placed "101" @ placed "1") []
    ; record
        ~a:2
        ~b:1
        3
        base
        (placed "98" @ placed "1" @ placed "99" @ placed "1" @ placed "101" @ placed "1")
        []
    ; record ~a:1 ~b:1 3 base (placed "99" @ placed "0" @ placed "101" @ placed "1") []
    ; funding ~hour:(Int64.add base 1L) base
    ; funding ~hour:base (at 1001)
    ; funding ~hour:(Int64.add base 3_600_000L) base
    ; record ~a:0 ~b:2 ~c:0 0 base [ 4L; 1L; 0L; 0L; 10L ] []
    ; record ~a:0 ~b:2 ~c:5 0 base [ 9L; 1L; 0L; 0L; 10L ] []
    ; record ~a:0 ~b:13 ~c:5 0 base [ 4L; 1L; 0L; 0L; 10L ] []
    ; record ~a:0 ~b:2 ~c:5 0 base [ 4L; 0L ] []
    ; record ~a:0 ~b:2 ~c:5 0 base [ 4L; 2L; 0L; 0L; 10L; 0L; 0L; 5L ] []
    ; observation ~known:(Int64.sub base 1L) base 1.
    ; quote (Int64.sub base 1L)
    ; quote (at 125_000)
    ]
  in
  List.iter (fun e -> rejection "R_MARKET" [ [ e ] ]) malformed;
  rejection "R_MARKET" [ [ funding ~hour:base base; funding ~hour:base (at 1) ] ];
  List.iter
    (fun bad ->
       let state, _ = M.feed (get (M.start program (header ()))) bad in
       let rows, summary = M.finish state in
       check "bad arrays reject" (text_field "error" (json summary) = "R_MARKET");
       check "bad arrays have no finish rows" (rows = empty_rows))
    [ { (chunk [ quote base ]) with records = Bytes.make 23 '\000' }
    ; { (chunk [ quote base ]) with integers = [||] }
    ; { (chunk [ quote base ]) with doubles = [| 1. |] }
    ; { (chunk []) with integers = [| 1L |] }
    ];
  List.iter
    (fun offset ->
       let _, _, summary = run [ [ funding ~hour:base (at offset); quote (at 2000) ] ] in
       success summary)
    [ 0; 999; 1000 ];
  let _, _, summary = run [ [ observation base nan; observation (at 1) infinity ] ] in
  success summary;
  List.iter
    (fun role ->
       List.iter
         (fun rate ->
            let fees =
              `List
                [ `Assoc
                    [ "from", `Int (Int64.to_int base)
                    ; "tier", `String "base"
                    ; "maker", `String (if role = "maker" then rate else "0.00015")
                    ; "taker", `String (if role = "taker" then rate else "0.00045")
                    ]
                ]
            in
            let market =
              replace [ "fees" ] fees (json (header ())) |> Yojson.Basic.to_string
            in
            match M.start program market with
            | Error code ->
              check "fee rate outside [0,1] refused at start" (code = "E_HEADER")
            | Ok _ -> failwith "bad fee schedule admitted")
         [ "-0.000000000001"; "1.000000000001" ])
    [ "maker"; "taker" ];
  List.iter
    (fun rate ->
       let fees =
         `List
           [ `Assoc
               [ "from", `Int (Int64.to_int base)
               ; "tier", `String "base"
               ; "maker", `String rate
               ; "taker", `String rate
               ]
           ]
       in
       ignore
         (get
            (M.start
               program
               (replace [ "fees" ] fees (json (header ())) |> Yojson.Basic.to_string))
          : M.t))
    [ "0"; "1" ];
  let too_late =
    replace [ "sources"; "funding"; "late" ] (`Int 3_600_000) (json (header ()))
    |> Yojson.Basic.to_string
  in
  check "funding lateness below one hour" (Result.is_error (M.start program too_late));
  let lagged =
    replace [ "sources"; "funding"; "lag" ] (`Int 10) (json (header ()))
    |> Yojson.Basic.to_string
  in
  rejection ~market:lagged "R_MARKET" [ [ funding ~known:(at 9) ~hour:base base ] ];
  let _, _, summary = run ~market:lagged [ [ funding ~known:(at 10) ~hour:base base ] ] in
  success summary
;;

let rec cuts = function
  | [] -> [ [] ]
  | first :: rest ->
    List.concat_map
      (function
        | [] -> [ [ [ first ] ] ]
        | head :: tail as groups -> [ [ first ] :: groups; (first :: head) :: tail ])
      (cuts rest)
;;

let same_run market expected groups =
  let reference_state, (reference_rows : M.rows), reference_summary = expected in
  let state, rows, summary = run ~market groups in
  check "C1 complete native state" (M.snapshot state = M.snapshot reference_state);
  check "C1 report bytes and order" (rows.report = reference_rows.report);
  check "C1 trace bytes and order" (rows.trace = reference_rows.trace);
  check "C1 summary" (summary = reference_summary)
;;

let test_3 () =
  let events =
    [ quote base
    ; funding ~hour:base (at 1000)
    ; trade (at 1000) 1
    ; trade (at 1000) 2
    ; quote (at 1000)
    ; observation (at 1000) 3.
    ; quote ~coin:1 (at 1000)
    ; trade (at 2001) 1
    ]
  in
  let market = header () in
  let expected = run ~market [ events ] in
  let state, rows, summary = expected in
  success summary;
  check
    "nonconstant admission counts all events"
    (M.count state = Int64.of_int (List.length events));
  check
    "nonconstant trace contains prints"
    (List.length (List.filter (String.starts_with ~prefix:"print\t") (lines rows.trace))
     = 3);
  List.iter (same_run market expected) (cuts events);
  same_run
    market
    expected
    ([ [] ] @ List.concat_map (fun e -> [ []; [ e ]; [] ]) events @ [ [] ]);
  let pending, emitted =
    M.feed (get (M.start program market)) (chunk [ quote base; trade (at 1000) 1 ])
  in
  check
    "chunk end never fires its tick"
    (not
       (List.exists
          (String.starts_with ~prefix:(Printf.sprintf "tick\t%Ld\t" (at 1000)))
          (lines emitted.trace)));
  let _, emitted = M.feed pending (chunk [ quote (at 1000); quote (at 1001) ]) in
  check
    "later time fires pending tick once"
    (List.length
       (List.filter
          (String.starts_with ~prefix:(Printf.sprintf "tick\t%Ld\tA\t" (at 1000)))
          (lines emitted.trace))
     = 1);
  let rng = Random.State.make [| 3; 2026 |] in
  for trial = 1 to 80 do
    let events =
      List.init (20 + trial) (fun i ->
        let time = at (i * 1000) in
        [ trade time i; quote ~bid:(string_of_int (90 + Random.State.int rng 10)) time ])
      |> List.concat
    in
    let expected = run [ events ] in
    let groups = List.map (fun e -> if Random.State.bool rng then [ e ] else []) events in
    let rec partition remaining sizes =
      match remaining, sizes with
      | [], _ -> []
      | _, [] -> [ remaining ]
      | _, size :: rest ->
        let n = if size = [] then 0 else 1 + Random.State.int rng 7 in
        let rec take n xs =
          match n, xs with
          | 0, _ | _, [] -> [], xs
          | n, x :: tail ->
            let a, b = take (n - 1) tail in
            x :: a, b
        in
        let head, tail = take n remaining in
        head :: partition tail rest
    in
    same_run (header ()) expected (partition events groups)
  done;
  let market = header ~last:(at 500_000) () in
  let state = ref (get (M.start program market)) in
  let small = ref 0L in
  for batch = 0 to 199 do
    let events = List.init 1000 (fun i -> trade (at ((batch * 1000) + i)) 7) in
    let next, _ = M.feed !state (chunk events) in
    state := next;
    if batch = 9 then small := M.retained_bytes !state
  done;
  check "all 200000 trades admitted" (M.count !state = 200_000L);
  check "no trade history retained" (M.retained_bytes !state <= Int64.add !small 65_536L);
  let _, summary = M.finish !state in
  success (json summary)
;;

let print_marks rows =
  List.filter_map
    (fun line ->
       match String.split_on_char '\t' line with
       | [ "print"; time; "A"; _; _; _; _; stale ] -> Some (Int64.of_string time, stale)
       | _ -> None)
    (lines rows.M.trace)
;;

let test_4 () =
  let prefix =
    [ trade base 0
    ; quote base
    ; trade (at 59_999) 1
    ; trade (at 60_000) 2
    ; trade (at 60_010) 3
    ]
  in
  let _, first, summary = run [ prefix @ [ quote (at 60_010); trade (at 60_020) 4 ] ] in
  success summary;
  check
    "causal exact gap endpoints"
    (print_marks first
     = [ base, "1"; at 59_999, "0"; at 60_000, "1"; at 60_010, "1"; at 60_020, "0" ]);
  let _, late, summary = run [ prefix @ [ quote (at 90_000); trade (at 90_001) 4 ] ] in
  success summary;
  let through_t marks = List.filter (fun (time, _) -> time <= at 60_010) marks in
  check
    "future quote cannot rewrite prior stale marks"
    (through_t (print_marks first) = through_t (print_marks late));
  let _, no_future, summary = run [ prefix ] in
  success summary;
  check
    "finish cannot use future gap knowledge"
    (print_marks no_future = through_t (print_marks first));
  check
    "stale again G after last quote"
    (List.mem (Printf.sprintf "tick\t%Ld\tA\t100\t1\t1" (at 120_010)) (lines first.trace)
     || List.mem
          (Printf.sprintf "tick\t%Ld\tA\t100\t1\t1" (at 121_000))
          (lines first.trace))
;;

let () =
  test_1 ();
  encoding_and_lateness ();
  test_3 ();
  test_4 ();
  print_endline "step3 events: tests 1,3,4 passed"
;;
