(* Step 4's tests 2 to 5 of brief 3 (test 1, B4, is b4_local.ml), and the checker's verdicts (KERNEL.md A17, "The
   verdict"), all on synthetic markets.

   Assumed interface, supplied by the builder:
   - Mm2_lean.Check.program : string -> string is the A17 verdict as JSON: {"ok":true}, or
     {"error":code,"at":where}. `mm2 check FILE` prints it, exit 0 when ok, 1 when not, 2 when the file is unreadable.
   - Mm2_lean.Machine.start takes the A17 program (sources, params, let, probes; no slots) with A18's header and
     returns Error code for E_PARSE, E_HEADER, E_LEVERAGE, E_UNKNOWN_INPUT and the other codes of A17 and A18.
   - A tick row of the trace (A19) is
       tick \t time \t coin \t price \t world \t view \t probe_1 ... probe_n
     for every coin in view at every tick, in coin order; a probe is `-` when undefined, 16 hexadecimal digits of the
     binary64 for a float, `n` or `n/d` for an exact number, `1` or `0` for a bool.
   - Observations of the header's sources enter the view at their `known`; the view takes every event known at or
     before a tick before that tick's expressions are evaluated (A18, "the view's order").
   - A source `vol` is a state, `flow` a flow, both coin by coin (events_support.ml's header). *)

open Events_support

let source name unit = Printf.sprintf {|{"name":"%s","unit":"%s"}|} name unit
let probe name expr = Printf.sprintf {|{"name":"%s","is":%s}|} name expr
let input name = Printf.sprintf {|{"input":"%s"}|} name

let windowed op ticks expr =
  Printf.sprintf {|{"op":"%s","args":[%s],"ticks":%d}|} op expr ticks
;;

let constant value unit = Printf.sprintf {|{"const":%s,"unit":"%s"}|} value unit
let binary op left right = Printf.sprintf {|{"op":"%s","args":[%s,%s]}|} op left right

let prog ?(tick = 1) ?(leverage = 1) ?(lets = []) ~sources probes =
  Printf.sprintf
    {|{"version":2,"tick":%d,"decide_every":1,"leverage":%d,"sources":[%s],"params":[],"let":[%s],"slots":[],"probes":[%s]}|}
    tick
    leverage
    (String.concat "," sources)
    (String.concat "," lets)
    (String.concat "," probes)
;;

let hex value = Printf.sprintf "%016Lx" (Int64.bits_of_float value)
let undefined = "-"

let replace_all ~sub ~by text =
  let n = String.length sub in
  let buffer = Buffer.create (String.length text) in
  let rec go i =
    if i < String.length text
    then
      if i + n <= String.length text && String.sub text i n = sub
      then (
        Buffer.add_string buffer by;
        go (i + n))
      else (
        Buffer.add_char buffer text.[i];
        go (i + 1))
  in
  go 0;
  Buffer.contents buffer
;;

type tick =
  { time : int64
  ; coin : string
  ; world : string
  ; view : string
  ; probes : string list
  }

let ticks (rows : M.rows) =
  List.filter_map
    (fun line ->
       match String.split_on_char '\t' line with
       | "tick" :: time :: coin :: _price :: world :: view :: probes ->
         Some { time = Int64.of_string time; coin; world; view; probes }
       | _ -> None)
    (lines rows.trace)
;;

let run_program program market groups =
  let state = get (M.start program market) in
  let state, emitted = feed_chunks state (List.map chunk groups) in
  let last, summary = M.finish state in
  success (json summary);
  ticks (append emitted last)
;;

let of_coin name all = List.filter (fun t -> t.coin = name) all

let at_second name rows k =
  let t = List.nth rows k in
  check (name ^ ": tick " ^ string_of_int k ^ " is at its second") (t.time = at (k * 1000));
  t
;;

let expect name rows k expected =
  let t = at_second name rows k in
  if t.probes <> expected
  then
    failwith
      (Printf.sprintf
         "%s: tick %d: expected [%s], read [%s]"
         name
         k
         (String.concat "; " expected)
         (String.concat "; " t.probes))
;;

let all_undefined name rows ks width =
  List.iter (fun k -> expect name rows k (List.init width (fun _ -> undefined))) ks
;;

let range first last = List.init (last - first + 1) (fun i -> first + i)

let test_2 () =
  let program =
    prog
      ~sources:[ source "vol" "1"; source "flow" "1" ]
      [ probe "v" (input "vol")
      ; probe "m" (windowed "mean" 4 (input "vol"))
      ; probe "f" (input "flow")
      ]
  in
  let events =
    [ observation (at 0) 1.0
    ; observation ~source:1 (at 2_500) 2.0
    ; observation ~source:1 (at 2_700) 3.0
    ; observation ~source:1 (at 7_000) 4.0
    ; observation (at 10_000) 3.0
    ; observation (at 20_000) 5.0
    ]
  in
  let rows = run_program program (header ()) [ events ] in
  let a = of_coin "A" rows
  and b = of_coin "B" rows in
  check
    "one row a tick, 125 ticks of one second"
    (List.length a = 125 && List.length b = 125);
  let vol k = if k < 10 then 1.0 else if k < 20 then 3.0 else 5.0 in
  let flow k = if k = 3 then Some 5.0 else if k = 7 then Some 4.0 else None in
  List.iter
    (fun k ->
       let mean =
         if k < 3
         then undefined
         else hex ((vol (k - 3) +. vol (k - 2) +. vol (k - 1) +. vol k) /. 4.0)
       in
       let f =
         match flow k with
         | Some x -> hex x
         | None -> undefined
       in
       expect "A" a k [ hex (vol k); mean; f ])
    (range 0 124);
  List.iter (fun k -> expect "B" b k [ undefined; undefined; undefined ]) (range 0 124)
;;

let high_low_program =
  prog
    ~sources:[]
    [ probe "bid" (input "bid")
    ; probe "ask" (input "ask")
    ; probe "mid" (input "mid")
    ; probe "bid_size" (input "bid_size")
    ; probe "ask_size" (input "ask_size")
    ; probe "high" (input "high")
    ; probe "low" (input "low")
    ; probe "traded" (input "traded")
    ]
;;

let test_3 () =
  let events =
    [ quote ~known:(at 2_500) (at 500)
    ; trade ~known:(at 3_000) ~price:"100.5" ~size:"2" (at 1_000) 1
    ; quote ~known:(at 3_200) ~bid:"101" ~ask:"103" (at 1_200)
    ; trade ~known:(at 3_500) ~price:"98.5" ~size:"1" (at 1_500) 2
    ]
  in
  let rows = run_program high_low_program (header ~delta:2_000 ()) [ events ] in
  let a = of_coin "A" rows
  and b = of_coin "B" rows in
  all_undefined "A before anything is known" a [ 0; 1; 2 ] 8;
  expect
    "A at the first tick that knows"
    a
    3
    [ "99"; "101"; "100"; "2"; "3"; "201/2"; "100"; "2" ];
  expect "A at the next" a 4 [ "101"; "103"; "102"; "2"; "3"; "102"; "197/2"; "1" ];
  expect "A with nothing new" a 5 [ "101"; "103"; "102"; "2"; "3"; "102"; "102"; "0" ];
  List.iter
    (fun k ->
       let t = at_second "B" b k in
       check
         "B has no quote: its price inputs are undefined"
         (List.filteri (fun i _ -> i <> 7) t.probes = List.init 7 (fun _ -> undefined)))
    (range 0 5)
;;

let test_3_lag () =
  let program = prog ~sources:[ source "vol" "1" ] [ probe "v" (input "vol") ] in
  let lagged =
    replace_all
      ~sub:{|"name":"vol","unit":"1","kind":"state","lag":0|}
      ~by:{|"name":"vol","unit":"1","kind":"state","lag":4000|}
      (header ())
  in
  let rows =
    run_program program lagged [ [ observation ~known:(at 5_000) (at 1_000) 9.0 ] ]
  in
  let a = of_coin "A" rows in
  all_undefined "a source's value before its known" a [ 0; 1; 2; 3; 4 ] 1;
  List.iter
    (fun k -> expect "a source's value from its known" a k [ hex 9.0 ])
    [ 5; 6; 100 ]
;;

let test_4 () =
  let market = header ~delta:5_000 ~stale:3_000 () in
  let program =
    prog ~sources:[] [ probe "bid" (input "bid"); probe "ask" (input "ask") ]
  in
  let early = quote ~known:(at 28_000) (at 23_000) in
  let later = quote ~known:(at 34_000) ~bid:"97" ~ask:"98" (at 29_000) in
  let without = of_coin "A" (run_program program market [ [ early ] ]) in
  let with_later = of_coin "A" (run_program program market [ [ early; later ] ]) in
  let tick_30 rows = at_second "A" rows 30 in
  check
    "the same inputs at the tick, though the later quote is inside (tau - delta, tau]"
    ((tick_30 without).probes = (tick_30 with_later).probes
     && (tick_30 without).probes = [ "99"; "101" ]);
  check
    "the world is stale in one and not in the other"
    ((tick_30 without).world = "1" && (tick_30 with_later).world = "0");
  check
    "the view is fresh in both"
    ((tick_30 without).view = "0" && (tick_30 with_later).view = "0");
  all_undefined "before the quote is known" without [ 26; 27 ] 2;
  List.iter
    (fun k -> expect "read from its known" without k [ "99"; "101" ])
    [ 28; 29; 30 ];
  all_undefined "a quote is read for G after it became known" without [ 31; 32; 33; 60 ] 2;
  List.iter
    (fun k ->
       check
         "the view's mark is the world's, delta earlier"
         (let t = at_second "A" without k in
          t.view = if k >= 31 then "1" else "0"))
    [ 28; 30; 31; 40 ];
  all_undefined "no quote until the later one is known" with_later [ 31; 32; 33 ] 2;
  expect "the later quote at its known" with_later 34 [ "97"; "98" ]
;;

let without_trades () =
  let market = header () in
  let stripped = replace_all ~sub:{|,"trades":{"encoding":"string"}|} ~by:"" market in
  check "the fixture lost its trade source" (stripped <> market);
  stripped
;;

let test_5 () =
  let reads_traded = prog ~sources:[] [ probe "t" (input "traded") ] in
  let verdict = json (Mm2_lean.Check.program reads_traded) in
  check "check accepts a program that reads traded" (field "ok" verdict = `Bool true);
  (match M.start reads_traded (without_trades ()) with
   | Error code ->
     check
       "start refuses traded on a market with no trade source"
       (code = "E_UNKNOWN_INPUT")
   | Ok _ -> failwith "traded was read from a market with no trades");
  ignore (get (M.start reads_traded (header ())));
  let unknown = prog ~sources:[ source "nope" "1" ] [ probe "p" (input "nope") ] in
  check
    "check accepts a declared source"
    (field "ok" (json (Mm2_lean.Check.program unknown)) = `Bool true);
  (match M.start unknown (header ()) with
   | Error code ->
     check "start refuses a source the market does not declare" (code = "E_UNKNOWN_INPUT")
   | Ok _ -> failwith "an undeclared source was admitted");
  let wrong_unit = prog ~sources:[ source "vol" "usd" ] [ probe "p" (input "vol") ] in
  (match M.start wrong_unit (header ()) with
   | Error code ->
     check "start refuses a source under another unit" (code = "E_UNKNOWN_INPUT")
   | Ok _ -> failwith "a source under the wrong unit was admitted");
  let shadowing = prog ~sources:[ source "bid" "1" ] [ probe "p" (constant "1.0" "1") ] in
  let named_bid = replace_all ~sub:{|"name":"vol"|} ~by:{|"name":"bid"|} (header ()) in
  (match M.start shadowing named_bid with
   | Error code ->
     check "a declared source may not take an input's name" (code = "E_HEADER")
   | Ok _ -> failwith "a source named like an input was admitted");
  match
    M.start (prog ~leverage:11 ~sources:[] [ probe "p" (constant "1.0" "1") ]) (header ())
  with
  | Error code -> check "leverage above the coin's tiers" (code = "E_LEVERAGE")
  | Ok _ -> failwith "leverage above the greatest was admitted"
;;

let verdict_code text =
  let verdict = json (Mm2_lean.Check.program text) in
  match field "ok" verdict with
  | `Bool true -> "ok"
  | _ -> text_field "error" verdict
;;

let test_verdicts () =
  let vol = [ source "vol" "1"; source "px" "usd" ] in
  let one expr = prog ~sources:vol [ probe "p" expr ] in
  let calm =
    prog
      ~sources:vol
      ~lets:
        [ {|{"name":"calm","is":|} ^ binary "lt" (input "vol") (constant "0.02" "1") ^ "}"
        ]
      [ probe "calm" {|{"ref":"calm"}|}; probe "mean" (windowed "mean" 8 (input "vol")) ]
  in
  check "a program with a let, a ref and a window is ok" (verdict_code calm = "ok");
  let cases =
    [ "E_UNKNOWN_INPUT", one (input "nope")
    ; "E_UNKNOWN_OP", one {|{"op":"frobnicate","args":[]}|}
    ; "E_ARITY", one {|{"op":"add","args":[{"input":"vol"}]}|}
    ; "E_UNIT", one (binary "add" (input "vol") (input "px"))
    ; "E_TYPE", one {|{"op":"not","args":[{"input":"vol"}]}|}
    ; "E_REF", one {|{"ref":"ghost"}|}
    ; "E_WINDOW", one (windowed "mean" 0 (input "vol"))
    ; ( "E_WINDOW"
      , prog
          ~sources:vol
          [ probe "a" (windowed "mean" 600_000 (input "vol"))
          ; probe "b" (windowed "sum" 600_000 (input "vol"))
          ] )
    ; ( "E_PARSE"
      , {|{"version":2,"tick":1,"decide_every":1,"leverage":1,"sources":[],"params":[],"let":[],"slots":[],"probes":[],"extra":1}|}
      )
    ; ( "E_PARSE"
      , {|{"version":2,"tick":1,"tick":2,"decide_every":1,"leverage":1,"sources":[],"params":[],"let":[],"slots":[],"probes":[]}|}
      )
    ; ( "E_PARSE"
      , {|{"version":2,"tick":1,"decide_every":1,"leverage":1,"sources":[],"params":[],"let":[],"slots":[]}|}
      )
    ; ( "E_PARSE"
      , {|{"version":2,"tick":1.5,"decide_every":1,"leverage":1,"sources":[],"params":[],"let":[],"slots":[],"probes":[]}|}
      )
    ; "E_PARSE", "not a program"
    ; "E_SIZE", calm ^ String.make 1_048_577 ' '
    ; "E_SIZE", String.make 131 '[' ^ String.make 131 ']'
    ; "E_PARSE", String.make 130 '[' ^ String.make 130 ']'
    ]
  in
  List.iter
    (fun (code, text) -> check ("verdict " ^ code) (verdict_code text = code))
    cases;
  let exactly_the_bound =
    prog
      ~sources:vol
      [ probe "a" (windowed "mean" 524_288 (input "vol"))
      ; probe "b" (windowed "sum" 524_288 (input "vol"))
      ]
  in
  check
    "windows summing to exactly 1,048,576 ticks are ok"
    (verdict_code exactly_the_bound = "ok");
  let verdict = json (Mm2_lean.Check.program (one (input "nope"))) in
  check "an error carries where" (Yojson.Basic.Util.member "at" verdict <> `Null)
;;

let () =
  test_2 ();
  test_3_lag ();
  test_3 ();
  test_4 ();
  test_5 ();
  test_verdicts ();
  print_endline "step4: tests 2 to 5 and the verdicts passed"
;;
