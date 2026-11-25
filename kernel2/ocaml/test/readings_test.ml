(* Brief 3: step 3 test 8 and ledger B; step 4 tests 6, 7 and ledger A.
   Requires Engine.Machine.admit to return the first fault or the payload's
   readings, keeping each size's admission scale through applyPayload/release.
   No new OCaml signature: Machine.start/feed/finish and Exact.read_bits,
   nearest_bits, put_placed use their existing interfaces. The ordinary
   read_bits must use readBitsFast after the builder's csimp replacement.
   onGridAt's direct property is fixtures/grid-at.lean; admission reaches it
   only through the ordinary feed. All prices and sizes here are invented. *)

open Events_support
module E = Mm2_lean.Exact

let set_rules ~sz ~decimals market =
  match json market with
  | `Assoc fields ->
    let coins = field "coins" (json market) |> Yojson.Basic.Util.to_list in
    let coins =
      List.map
        (function
          | `Assoc fields ->
            `Assoc
              (List.map
                 (fun (key, value) ->
                    ( key
                    , match key with
                      | "sz_decimals" -> `Int sz
                      | "figures" -> `Int 5
                      | "decimals" -> `Int decimals
                      | _ -> value ))
                 fields)
          | _ -> assert false)
        coins
    in
    `Assoc
      (List.map
         (fun (key, value) -> key, if key = "coins" then `List coins else value)
         fields)
    |> Yojson.Basic.to_string
  | _ -> assert false
;;

let sized_quote
      encoding
      ?(bid = "99")
      ?(ask = "101")
      ?(bid_size = "1.23")
      ?(ask_size = "2.34")
      ~known
      time
  =
  match encoding with
  | "string" ->
    record
      ~a:1
      ~b:1
      ~known
      3
      time
      (placed bid @ placed bid_size @ placed ask @ placed ask_size)
      []
  | "double" ->
    record
      ~a:1
      ~b:1
      ~known
      3
      time
      []
      (List.map Float.of_string [ bid; bid_size; ask; ask_size ])
  | _ -> assert false
;;

let sized_trade encoding ~size ~known time id =
  match encoding with
  | "string" -> trade ~known ~size time id
  | "double" ->
    record ~a:1 ~known 2 time [ Int64.of_int id ] [ 100.; Float.of_string size ]
  | _ -> assert false
;;

let listing ~sz ~known time =
  record ~b:sz ~c:5 ~known 0 time [ Int64.of_int (6 - sz); 1L; 0L; 0L; 10L ] []
;;

let execute program market groups =
  let initial = get (M.start program market) in
  let state, emitted = feed_chunks initial (List.map chunk groups) in
  let last, summary = M.finish state in
  state, append emitted last, summary
;;

let test_8_admission_grid () =
  List.iter
    (fun encoding ->
       let market = header ~last:(at 1) ~encoding () |> set_rules ~sz:5 ~decimals:1 in
       List.iter
         (fun (bid, ask, member) ->
            let q =
              sized_quote encoding ~bid ~ask ~bid_size:"1" ~ask_size:"1" ~known:base base
            in
            let state, rows, summary = execute "" market [ [ q ] ] in
            if member
            then (
              success (json summary);
              check "grid witness admitted exactly one quote" (M.count state = 1L))
            else (
              check
                "certificate rejects this bid through feed"
                (text_field "error" (json summary) = "R_MARKET");
              check "grid rejection publishes no rows" (rows = empty_rows)))
         [ "123456", "123457", true
         ; "12345.6", "12347", false
         ; "99999", "100000", true
         ; "100000", "100001", true
         ; "100001", "100002", true
         ; "100000.5", "100002", false
         ; "99999.5", "100001", false
         ])
    [ "string"; "double" ]
;;

let test_first_fault () =
  let expected =
    Printf.sprintf
      {|{"error":"R_MARKET","time":%Ld,"detail":"a price that is not above zero"}|}
      (at 1)
  in
  List.iter
    (fun encoding ->
       let bad =
         match encoding with
         | "string" -> trade ~price:"0" ~size:"0.001" (at 1) 7
         | "double" -> record ~a:1 2 (at 1) [ 7L ] [ 0.; nan ]
         | _ -> assert false
       in
       let market = header ~encoding () in
       let state = get (M.start program market) in
       let rejected, rows = M.feed state (chunk [ bad ]) in
       check "simultaneous faults emit no rows" (rows = empty_rows);
       let last, summary = M.finish rejected in
       check "first fault compared in full, including time and detail" (summary = expected);
       check "first-fault finish has no rows" (last = empty_rows);
       let suffix = sized_quote encoding ~known:(at 2) (at 2) in
       let after, rows = M.feed rejected (chunk [ suffix ]) in
       let last, summary = M.finish after in
       check "first fault survives later input, in full" (summary = expected);
       check "rejection stays silent" (rows = empty_rows && last = empty_rows))
    [ "string"; "double" ]
;;

let view_program =
  {|{"version":2,"tick":1,"decide_every":1,"leverage":1,"sources":[],"params":[],"let":[],"slots":[],"probes":[{"name":"bid","is":{"input":"bid"}},{"name":"ask","is":{"input":"ask"}},{"name":"mid","is":{"input":"mid"}},{"name":"bid_size","is":{"input":"bid_size"}},{"name":"ask_size","is":{"input":"ask_size"}},{"name":"high","is":{"input":"high"}},{"name":"low","is":{"input":"low"}},{"name":"traded","is":{"input":"traded"}}]}|}
;;

let tick_views (rows : M.rows) =
  List.filter_map
    (fun line ->
       match String.split_on_char '\t' line with
       | "tick" :: time :: coin :: _price :: _world :: view :: probes ->
         Some (time :: coin :: view :: probes)
       | _ -> None)
    (lines rows.trace)
;;

let admitted market events =
  let state, rows, summary = execute view_program market [ events ] in
  success (json summary);
  check
    "every event admitted, not a vacuous pair"
    (M.count state = Int64.of_int (List.length events));
  tick_views rows
;;

let through tau =
  List.filter (function
    | time :: _ -> Int64.of_string time <= tau
    | _ -> assert false)
;;

let probes_at tau views =
  List.find_map
    (function
      | time :: "A" :: _view :: probes when Int64.of_string time = tau -> Some probes
      | _ -> None)
    views
  |> Option.get
;;

let same_premises ~delta ~tau left right =
  let known e = Bytes.get_int64_le e.record 16 <= tau in
  let early e = Bytes.get_int64_le e.record 8 <= Int64.sub tau (Int64.of_int delta) in
  check "L1a known-event premise" (List.filter known left = List.filter known right);
  check "L1a time-prefix premise" (List.filter early left = List.filter early right)
;;

let test_6_unknown_listing () =
  List.iter
    (fun encoding ->
       let market = header ~last:(at 6_001) ~delta:1_000 ~encoding () in
       let rules = listing ~sz:3 ~known:(at 20_000) (at 1_000) in
       let q = sized_quote encoding ~bid_size:"1.234" ~known:(at 2_500) (at 1_500) in
       let views = admitted market [ rules; q ] in
       check
         "unknown listing governs admission, not the value"
         (probes_at (at 3_000) views
          = [ "99"; "101"; "100"; "617/500"; "117/50"; "100"; "100"; "0" ]);
       let _, rows, summary = execute view_program market [ [ q ] ] in
       check
         "without that listing this is not an admitted comparison market"
         (text_field "error" (json summary) = "E_DECIMAL");
       check "unreadable quote publishes no rows" (rows = empty_rows);
       let delta = 2_000
       and tau = at 5_000 in
       let market = header ~last:(at 7_001) ~delta ~encoding () in
       let common = sized_quote encoding ~known:(at 3_000) (at 1_000) in
       let left =
         [ common
         ; sized_quote encoding ~bid:"97" ~ask:"99" ~known:(at 5_600) (at 3_600)
         ; sized_trade encoding ~size:"0.23" ~known:(at 5_700) (at 3_700) 1
         ]
       in
       let right =
         [ common
         ; listing ~sz:3 ~known:(at 12_000) (at 3_500)
         ; sized_quote
             encoding
             ~bid:"101"
             ~ask:"103"
             ~bid_size:"1.234"
             ~known:(at 5_600)
             (at 3_600)
         ; sized_trade encoding ~size:"0.234" ~known:(at 5_700) (at 3_700) 2
         ]
       in
       same_premises ~delta ~tau left right;
       let a = admitted market left
       and b = admitted market right in
       check
         "both admitted tails give equal tick views and evaluations through tau"
         (through tau a = through tau b);
       check
         "equal nonempty views contain the earlier quote"
         (List.nth (probes_at tau a) 3 = "123/100");
       let _, rows, summary =
         execute view_program market (List.map (fun e -> [ e ]) right)
       in
       success (json summary);
       check "same unknown-listing test across chunk cuts" (tick_views rows = b))
    [ "string"; "double" ]
;;

let test_pending_quote_scale () =
  List.iter
    (fun encoding ->
       let delta = 1_000
       and tau = at 2_000 in
       let market = header ~last:(at 2_001) ~delta ~encoding () in
       let q = sized_quote encoding ~known:tau (at 1_000) in
       let left = [ q ] in
       let right = [ q; listing ~sz:3 ~known:(at 10_000) (at 1_500) ] in
       same_premises ~delta ~tau left right;
       let a = admitted market left
       and b = admitted market right in
       check
         "later unknown listing cannot rescale a pending quote"
         (through tau a = through tau b);
       List.iter
         (fun views ->
            check
              "size is the exact reading made at admission"
              (probes_at tau views
               = [ "99"; "101"; "100"; "123/100"; "117/50"; "100"; "100"; "0" ]))
         [ a; b ])
    [ "string"; "double" ]
;;

let pow10 scale =
  let rec loop n d = if d = 0 then n else loop (Int64.mul n 10L) (d - 1) in
  loop 1L scale
;;

let written n scale =
  let digits = Int64.to_string (Int64.abs n) in
  let digits = String.make (max 0 (scale + 1 - String.length digits)) '0' ^ digits in
  let split = String.length digits - scale in
  let magnitude =
    if scale = 0
    then digits
    else String.sub digits 0 split ^ "." ^ String.sub digits split scale
  in
  (if n < 0L then "-" else "") ^ magnitude
;;

let test_7_scale_invariance () =
  let rng = Random.State.make [| 7; 0x51ca1e; 2026 |] in
  for d1 = 0 to 12 do
    for d2 = d1 to 12 do
      let factor = pow10 (d2 - d1) in
      let limit = Int64.div 1_000_000_000_000_000L factor in
      let sample n =
        let scaled = Int64.mul n factor in
        check
          "property's exclusive range premise"
          (Int64.abs scaled < 1_000_000_000_000_000L);
        let text = written n d1 in
        let digits = get (Mm2_lean.Decimal.place text) in
        check
          "string reading at the first scale"
          (E.put_placed d1 digits = Ok (Int64.to_string n));
        check
          "same string at the finer scale"
          (E.put_placed d2 digits = Ok (Int64.to_string scaled));
        let finer = get (Mm2_lean.Decimal.place (written scaled d2)) in
        check "writing at the finer scale changes no placed value" (digits = finer);
        let bits = E.nearest_bits (Int64.to_string n, Int64.to_string (pow10 d1)) in
        check
          "equal rational values have identical nearest bits"
          (bits = E.nearest_bits (Int64.to_string scaled, Int64.to_string (pow10 d2)));
        check
          "double reading at the first scale"
          (E.read_bits d1 bits = Some (Int64.to_string n));
        check
          "same double at the finer scale"
          (E.read_bits d2 bits = Some (Int64.to_string scaled))
      in
      List.iter sample [ 0L; 1L; -1L; Int64.pred limit; Int64.neg (Int64.pred limit) ];
      for _sample = 1 to 128 do
        let n = Random.State.int64 rng limit in
        sample (if Random.State.bool rng then n else Int64.neg n)
      done;
      check
        "negative zero has the same value at both scales"
        (E.read_bits d1 Int64.min_int = Some "0"
         && E.read_bits d2 Int64.min_int = Some "0")
    done
  done
;;

let () =
  List.iter
    (fun (name, test) ->
       test ();
       print_endline (name ^ ": passed"))
    [ "step3_8_admission_grid", test_8_admission_grid
    ; "step3_first_fault", test_first_fault
    ; "step4_6_unknown_listing", test_6_unknown_listing
    ; "step4_pending_quote_scale", test_pending_quote_scale
    ; "step4_7_scale_invariance", test_7_scale_invariance
    ]
;;
