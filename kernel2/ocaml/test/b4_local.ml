(* Step 4, test 1 (B4): version 2's float evaluator against the Lean reference's stored streams. LOCAL: it reads data
   the Nix sandbox cannot see, so it is an executable and not part of @runtest.

     b4_local.exe REF_DIR [AUDIT_DIR [LIMIT [SHARD COUNT]]]

   REF_DIR is `data/stage6/c64-reference` (out/<N1|N2|N3>/<name>.json.zst and .bin.zst, each market's mk-*.json,
   SHA256SUMS, raw-sha256.json, manifest.json). AUDIT_DIR holds c64-corpus.jsonl and c64-manifest.json (default
   audit/stage6). LIMIT bounds the items taken from each market before sharding (default all). Exit 0 and one summary line when every
   stream is bit-identical; exit 1 and the first divergence otherwise.

   Checked first: SHA256SUMS over REF_DIR, the corpus's hash against its manifest, and the presence of manifest.json
   and raw-sha256.json.

   Assumed interface, supplied by the builder (as eval_test.ml's header says): Mm2_lean.Machine.start takes the A17
   program and A18's header; the trace's tick rows carry one probe each, in the program's order.

   The conversion of a stage 6 program (DSL version 1, reference/SEMANTICS.md) into a version 2 program is the test's:
   - nodes are the reference's, in its order: the program's lets in order, then the weight, then the prediction's
     condition, each expression's arguments before it, equal nodes interned as the reference's checker interns them
     (a constant by the bits of its value plus +0 and its unit, a convert by its target unit);
   - node i is the let `n<i>`, whose arguments are `ref`s to earlier lets, and the probe `p<i>` is `{"ref":"n<i>"}`;
   - an input is the declared source `s_<name>` (so that `high` and `low` do not take the built-in inputs' names),
     in the unit the reference gives it, a `state` source but the two event counts, which are `flow`;
   - `hours` is `ticks`, the program's tick is 3600 seconds, and `hours_since(c)` is
     `mul(ticks_since(c), const 1 [h/tick])`;
   - parameters keep their JSON numbers.
   The market is the reference's export (mk-*.json) as observations of coin `c<i>`: a funding row's rate and premium,
   a bar's open, high, low, close and volume, and an event count, each at its event time and at its reference
   `known` less the reference's delta, since the reference's tick at H reads what is known by H + delta and version
   2's reads what is known by H. The horizon is [0, the last tick + 1 ms). Events of a slot the market does not bind
   are not given, so a program that reads one meets `start`'s E_UNKNOWN_INPUT where the reference met
   R_INPUT_UNAVAILABLE. *)

open Events_support
module J = Yojson.Safe

let hour = 3_600_000L
let fail fmt = Printf.ksprintf failwith fmt
let shell_quote path = Filename.quote path

let sha256_of path =
  let status, out = command "sha256sum" [ path ] in
  if status <> Unix.WEXITED 0 then fail "sha256sum failed on %s" path;
  List.hd (String.split_on_char ' ' out)
;;

let u64 = function
  | `Int i -> Int64.of_int i
  | `Intlit text -> Int64.of_string ("0u" ^ text)
  | _ -> failwith "expected an integer"
;;

let int_of = function
  | `Int i -> i
  | _ -> failwith "expected a small integer"
;;

let bits_float value = Int64.float_of_bits (u64 value)

let items = function
  | `List values -> values
  | _ -> failwith "expected an array"
;;

let member = J.Util.member

let number = function
  | `Float f -> f
  | `Int i -> float_of_int i
  | `Intlit text -> float_of_string text
  | _ -> failwith "expected a number"
;;

let units_of_name =
  [ "funding", "1/h"
  ; "premium", "1"
  ; "open", "usd/coin"
  ; "high", "usd/coin"
  ; "low", "usd/coin"
  ; "close", "usd/coin"
  ; "volume", "coin"
  ; "forum_posts", "ev"
  ; "gov_proposals", "ev"
  ]
;;

let bases = [ "usd"; "coin"; "h"; "d"; "y"; "ev" ]

let index_of value list =
  let rec go i = function
    | [] -> failwith "no such base unit"
    | x :: rest -> if x = value then i else go (i + 1) rest
  in
  go 0 list
;;

let canonical_unit text =
  let text = String.concat "" (String.split_on_char ' ' text) in
  let product factors =
    let exponents = Array.make 6 0 in
    if factors <> "1"
    then
      List.iter
        (fun factor ->
           let name, power =
             match String.split_on_char '^' factor with
             | [ name ] -> name, 1
             | [ name; power ] -> name, int_of_string power
             | _ -> failwith "unit"
           in
           let i = index_of name bases in
           exponents.(i) <- exponents.(i) + power)
        (String.split_on_char '*' factors);
    exponents
  in
  let exponents =
    match String.split_on_char '/' text with
    | [ numerator ] -> product numerator
    | [ numerator; denominator ] ->
      Array.map2 ( - ) (product numerator) (product denominator)
    | _ -> failwith "unit"
  in
  String.concat "," (Array.to_list (Array.map string_of_int exponents))
;;

type compiled =
  { text : string
  ; nodes : int
  ; unbound_slot : bool
  }

let compile ~present program_text =
  let program = J.from_string program_text in
  let table : (string, int) Hashtbl.t = Hashtbl.create 64 in
  let nodes : string list ref = ref [] in
  let count = ref 0 in
  let lets : (string * int) list ref = ref [] in
  let used : string list ref = ref [] in
  let intern key expression =
    match Hashtbl.find_opt table key with
    | Some i -> i
    | None ->
      let i = !count in
      incr count;
      Hashtbl.add table key i;
      nodes := expression :: !nodes;
      i
  in
  let reference i = Printf.sprintf {|{"ref":"n%d"}|} i in
  let rec walk = function
    | `Assoc fields ->
      let field name = List.assoc name fields in
      if List.mem_assoc "input" fields
      then (
        let name = J.Util.to_string (field "input") in
        if not (List.mem name !used) then used := !used @ [ name ];
        intern ("i:" ^ name) (Printf.sprintf {|{"input":"s_%s"}|} name))
      else if List.mem_assoc "const" fields
      then (
        let value = field "const" in
        let unit = J.Util.to_string (field "unit") in
        let bits = Int64.bits_of_float (number value +. 0.0) in
        intern
          (Printf.sprintf "c:%Ld:%s" bits (canonical_unit unit))
          (Printf.sprintf {|{"const":%s,"unit":"%s"}|} (J.to_string value) unit))
      else if List.mem_assoc "param" fields
      then (
        let name = J.Util.to_string (field "param") in
        intern ("p:" ^ name) (Printf.sprintf {|{"param":"%s"}|} name))
      else if List.mem_assoc "ref" fields
      then List.assoc (J.Util.to_string (field "ref")) !lets
      else (
        let op = J.Util.to_string (field "op") in
        let args = List.map walk (items (field "args")) in
        let arguments = String.concat "," (List.map reference args) in
        let numbers = String.concat "," (List.map string_of_int args) in
        match op with
        | "hours_since" ->
          intern
            (Printf.sprintf "o:%s:%s" op numbers)
            (Printf.sprintf
               {|{"op":"mul","args":[{"op":"ticks_since","args":[%s]},{"const":1.0,"unit":"h/tick"}]}|}
               arguments)
        | _ when List.mem_assoc "hours" fields ->
          let hours = int_of (field "hours") in
          intern
            (Printf.sprintf "o:%s:h%d:%s" op hours numbers)
            (Printf.sprintf {|{"op":"%s","args":[%s],"ticks":%d}|} op arguments hours)
        | _ when List.mem_assoc "to" fields ->
          let target = J.Util.to_string (field "to") in
          intern
            (Printf.sprintf "o:%s:to%s:%s" op (canonical_unit target) numbers)
            (Printf.sprintf {|{"op":"%s","args":[%s],"to":"%s"}|} op arguments target)
        | _ ->
          intern
            (Printf.sprintf "o:%s:%s" op numbers)
            (Printf.sprintf {|{"op":"%s","args":[%s]}|} op arguments))
    | _ -> failwith "expected an expression"
  in
  let params =
    match member "params" program with
    | `Assoc entries ->
      List.map
        (fun (name, spec) ->
           Printf.sprintf
             {|{"name":"%s","value":%s,"unit":"%s"}|}
             name
             (J.to_string (member "value" spec))
             (J.Util.to_string (member "unit" spec)))
        entries
    | _ -> []
  in
  (match member "let" program with
   | `Assoc entries ->
     List.iter
       (fun (name, expression) -> lets := (name, walk expression) :: !lets)
       entries
   | _ -> ());
  ignore (walk (member "weight" program));
  (match member "prediction" program with
   | `Assoc _ as prediction -> ignore (walk (member "condition" prediction))
   | _ -> ());
  let nodes = List.rev !nodes in
  let slot_of name =
    match name with
    | "forum_posts" -> Some 0
    | "gov_proposals" -> Some 1
    | _ -> None
  in
  let unbound_slot =
    List.exists
      (fun name ->
         match slot_of name with
         | Some slot -> not (List.mem slot present)
         | None -> false)
      !used
  in
  let sources =
    List.map
      (fun name ->
         Printf.sprintf
           {|{"name":"s_%s","unit":"%s"}|}
           name
           (List.assoc name units_of_name))
      !used
  in
  let lets_json =
    List.mapi
      (fun i expression -> Printf.sprintf {|{"name":"n%d","is":%s}|} i expression)
      nodes
  in
  let probes =
    List.mapi (fun i _ -> Printf.sprintf {|{"name":"p%d","is":%s}|} i (reference i)) nodes
  in
  let text =
    Printf.sprintf
      {|{"version":2,"tick":3600,"decide_every":1,"leverage":1,"sources":[%s],"params":[%s],"let":[%s],"slots":[],"probes":[%s]}|}
      (String.concat "," sources)
      (String.concat "," params)
      (String.concat "," lets_json)
      (String.concat "," probes)
  in
  { text; nodes = List.length nodes; unbound_slot }
;;

type market =
  { coins : int
  ; ticks : int
  ; header : string
  ; chunks : M.chunk list
  }

let load_market path =
  let mk = J.from_file path in
  let policy = member "policy" mk in
  let delta = Int64.of_int (int_of (member "delta" policy)) in
  let stop = Int64.of_int (int_of (member "end" policy)) in
  let start = int_of (member "w_start" policy) in
  let bar = int_of (member "bar" policy) in
  if start <> 0 then fail "%s: the horizon must start at 0" path;
  List.iter
    (fun interval ->
       match items interval with
       | [ first; last ] ->
         if int_of first <> 0 || Int64.of_int (int_of last) <> stop
         then fail "%s: a coin lists late or ends" path
       | _ -> failwith "interval")
    (items (member "intervals" mk));
  let coins = List.length (items (member "intervals" mk)) in
  let steps =
    if Int64.to_int stop >= 2 * bar
    then ((Int64.to_int stop - (2 * bar)) / bar) + 1
    else 0
  in
  let ticks = 1 + (steps * (bar / Int64.to_int hour)) in
  let horizon_end = Int64.add (Int64.mul (Int64.of_int (ticks - 1)) hour) 1L in
  let present = List.map int_of (items (member "present" mk)) in
  let source_names =
    [ "funding"; "premium"; "open"; "high"; "low"; "close"; "volume" ]
    @ List.map (fun slot -> if slot = 0 then "forum_posts" else "gov_proposals") present
  in
  let observation_specs =
    List.mapi
      (fun i name ->
         Printf.sprintf
           {|{"name":"s_%s","unit":"%s","kind":"%s","lag":0}|}
           name
           (List.assoc name units_of_name)
           (if i >= 7 then "flow" else "state"))
      source_names
  in
  let coin_specs =
    List.mapi
      (fun i sz ->
         Printf.sprintf
           {|{"name":"c%d","sz_decimals":%d,"figures":5,"decimals":%d,"tiers":[{"from":"0","max_leverage":10}]}|}
           i
           (int_of sz)
           (6 - int_of sz))
      (items (member "sz_decimals" (member "venue" mk)))
  in
  let header =
    Printf.sprintf
      {|{"horizon":{"start":0,"end":%Ld},"venue":{"fill":"optimistic","lambda":0,"delta":0,"stale":60000,"cap":"10000","minimum":"10"},"cash":"10000","coins":[%s],"fees":[{"from":0,"tier":"base","maker":"0.00015","taker":"0.00045"}],"sources":{"listings":{"lag":0},"funding":{"encoding":"string","lag":0,"late":1000},"quotes":{"encoding":"double"},"trades":{"encoding":"string"},"observations":[%s]},"aliases":{"coins":{},"sources":{}}}|}
      horizon_end
      (String.concat "," coin_specs)
      (String.concat "," observation_specs)
  in
  let observations = ref [] in
  let add ~coin ~source ~time ~known value =
    let known = Int64.sub known delta in
    if known < time
    then fail "%s: a row known before it happened, after the delta is taken off" path;
    if time < horizon_end
    then observations := (time, coin, source, known, value) :: !observations
  in
  List.iter
    (fun row ->
       match items row with
       | [ coin; event; known; rate; premium ] ->
         let coin = int_of coin
         and time = u64 event
         and known = u64 known in
         add ~coin ~source:0 ~time ~known (bits_float rate);
         add ~coin ~source:1 ~time ~known (bits_float premium)
       | _ -> failwith "funding row")
    (items (member "funding" mk));
  List.iter
    (fun row ->
       match items row with
       | [ coin; _open_time; event; known; o; h; l; c; v; _trades ] ->
         let coin = int_of coin
         and time = u64 event
         and known = u64 known in
         List.iteri
           (fun i value -> add ~coin ~source:(2 + i) ~time ~known (bits_float value))
           [ o; h; l; c; v ]
       | _ -> failwith "bar row")
    (items (member "bars" mk));
  List.iter
    (fun row ->
       match items row with
       | [ slot; coin; event; known; count ] ->
         let rec place i = function
           | [] -> None
           | s :: rest -> if s = int_of slot then Some i else place (i + 1) rest
         in
         (match place 0 present with
          | Some position ->
            add
              ~coin:(int_of coin)
              ~source:(7 + position)
              ~time:(u64 event)
              ~known:(u64 known)
              (bits_float count)
          | None -> ())
       | _ -> failwith "event row")
    (items (member "events" mk));
  let ordered =
    List.stable_sort
      (fun (t1, c1, s1, _, _) (t2, c2, s2, _, _) -> compare (t1, c1, s1) (t2, c2, s2))
      (List.rev !observations)
  in
  let events =
    List.map
      (fun (time, coin, source, known, value) ->
         observation ~coin ~source ~known time value)
      ordered
  in
  let rec cut acc current n = function
    | [] -> List.rev (if current = [] then acc else List.rev current :: acc)
    | e :: rest ->
      if n = 20_000
      then cut (List.rev current :: acc) [ e ] 1 rest
      else cut acc (e :: current) (n + 1) rest
  in
  { coins; ticks; header; chunks = List.map chunk (cut [] [] 0 events) }, present
;;

let read_head path wanted =
  let ic = Unix.open_process_args_in "zstd" [| "zstd"; "-dc"; path |] in
  let buffer = Bytes.create wanted in
  let rec fill got =
    if got = wanted
    then got
    else (
      let n = input ic buffer got (wanted - got) in
      if n = 0 then got else fill (got + n))
  in
  let got = fill 0 in
  ignore (Unix.close_process_in ic);
  Bytes.sub_string buffer 0 got
;;

let read_entry ic =
  match input_char ic with
  | '\000' -> None
  | _ -> Some (String.get_int64_le (really_input_string ic 8) 0)
;;

let decode = function
  | "-" -> None
  | "1" -> Some 0x3FF0000000000000L
  | "0" -> Some 0L
  | text when String.length text = 16 -> Some (Int64.of_string ("0x" ^ text))
  | text -> fail "an unreadable probe field %S" text
;;

let show = function
  | None -> "undefined"
  | Some bits -> Printf.sprintf "%016Lx" bits
;;

type walk =
  { mutable current : int64
  ; mutable pending : (string * string array) list
  ; mutable index : int
  }

let compare_item ~market ~name ~nodes ~stream state =
  let ic = Unix.open_process_args_in "zstd" [| "zstd"; "-dc"; stream |] in
  let walker = { current = -1L; pending = []; index = 0 } in
  let flush () =
    if walker.pending <> []
    then (
      if walker.index < market.ticks
      then (
        if walker.current <> Int64.mul (Int64.of_int walker.index) hour
        then fail "%s: tick %d is at %Ld" name walker.index walker.current;
        for node = 0 to nodes - 1 do
          for coin = 0 to market.coins - 1 do
            let expected = read_entry ic in
            let got =
              match List.assoc_opt (Printf.sprintf "c%d" coin) walker.pending with
              | None -> None
              | Some probes ->
                if Array.length probes <> nodes
                then fail "%s: %d probes, %d nodes" name (Array.length probes) nodes;
                decode probes.(node)
            in
            if expected <> got
            then
              fail
                "%s: first divergence at tick %d, node %d, coin %d: the reference has \
                 %s, version 2 has %s"
                name
                walker.index
                node
                coin
                (show expected)
                (show got)
          done
        done);
      walker.index <- walker.index + 1;
      walker.pending <- [])
  in
  let take (rows : M.rows) =
    List.iter
      (fun line ->
         match String.split_on_char '\t' line with
         | "tick" :: time :: coin :: _price :: _world :: _view :: probes ->
           let time = Int64.of_string time in
           if time <> walker.current
           then (
             flush ();
             walker.current <- time);
           walker.pending <- (coin, Array.of_list probes) :: walker.pending
         | _ -> ())
      (lines rows.trace)
  in
  let state =
    List.fold_left
      (fun state next ->
         let state, rows = M.feed state next in
         take rows;
         state)
      state
      market.chunks
  in
  let last, summary = M.finish state in
  take last;
  flush ();
  success (json summary);
  if walker.index <> market.ticks
  then fail "%s: %d ticks read, %d expected" name walker.index market.ticks;
  (match input_char ic with
   | exception End_of_file -> ()
   | _ -> fail "%s: the reference's stream is longer than version 2's" name);
  ignore (Unix.close_process_in ic)
;;

let () =
  let usage () =
    prerr_endline "usage: b4_local.exe REF_DIR [AUDIT_DIR [LIMIT [SHARD COUNT]]]";
    exit 2
  in
  let dir, audit, limit, shard, count =
    match Array.to_list Sys.argv with
    | [ _; dir ] -> dir, "audit/stage6", max_int, 0, 1
    | [ _; dir; audit ] -> dir, audit, max_int, 0, 1
    | [ _; dir; audit; limit ] -> dir, audit, int_of_string limit, 0, 1
    | [ _; dir; audit; limit; shard; count ] ->
      dir, audit, int_of_string limit, int_of_string shard, int_of_string count
    | _ -> usage ()
  in
  if count <= 0 || shard < 0 || shard >= count then usage ();
  List.iter
    (fun file ->
       if not (Sys.file_exists (Filename.concat dir file))
       then fail "%s is missing: the reference's run is not finished" file)
    [ "SHA256SUMS"; "manifest.json"; "raw-sha256.json" ];
  let status =
    Sys.command
      (Printf.sprintf "cd %s && sha256sum -c --quiet SHA256SUMS" (shell_quote dir))
  in
  if status <> 0 then fail "SHA256SUMS does not hold over %s" dir;
  let corpus_path = Filename.concat audit "c64-corpus.jsonl" in
  let manifest = J.from_file (Filename.concat audit "c64-manifest.json") in
  if sha256_of corpus_path <> J.Util.to_string (member "corpus_sha256" manifest)
  then fail "the corpus differs from its manifest";
  let corpus = List.map (fun line -> J.from_string line) (lines (read corpus_path)) in
  let compared = ref 0
  and aborted = ref 0
  and ticks_total = ref 0 in
  List.iter
    (fun name ->
       let out = Filename.concat (Filename.concat dir "out") name in
       let mk =
         match
           List.filter
             (fun f -> String.length f > 3 && String.sub f 0 3 = "mk-")
             (Array.to_list (Sys.readdir out))
         with
         | [ one ] -> Filename.concat out one
         | _ -> fail "%s must hold exactly one mk-*.json" out
       in
       let market, present = load_market mk in
       let taken = ref 0 in
       List.iter
         (fun item ->
            let markets = List.map J.Util.to_string (items (member "markets" item)) in
            if List.mem name markets && !taken < limit
            then (
              let position = !taken in
              incr taken;
              if position mod count = shard
              then (
                let item_name = J.Util.to_string (member "name" item) in
                let compiled =
                  compile ~present (J.Util.to_string (member "program" item))
                in
                let stream = Filename.concat out (item_name ^ ".bin.zst") in
                let json_path = Filename.concat out (item_name ^ ".json.zst") in
                let head = read_head json_path 9 in
                let label = name ^ "/" ^ item_name in
                match M.start compiled.text market.header with
                | Error code ->
                  if head = {|{"trace":|}
                  then
                    fail
                      "%s: the reference ran it and version 2's start refused it: %s"
                      label
                      code
                  else if not (compiled.unbound_slot && code = "E_UNKNOWN_INPUT")
                  then
                    fail
                      "%s: the reference did not run it (%s) and start gave %s"
                      label
                      (read_head json_path 80)
                      code
                  else incr aborted
                | Ok state ->
                  if head <> {|{"trace":|}
                  then fail "%s: the reference did not run it and version 2 started" label;
                  compare_item ~market ~name:label ~nodes:compiled.nodes ~stream state;
                  incr compared;
                  ticks_total := !ticks_total + market.ticks)))
         corpus;
       Printf.printf "%s: %d items taken\n%!" name !taken)
    [ "N1"; "N2"; "N3" ];
  Printf.printf
    "b4: shard %d of %d: %d streams bit-identical over %d ticks, %d refused alike by \
     start and the reference\n"
    shard
    count
    !compared
    !ticks_total
    !aborted
;;
