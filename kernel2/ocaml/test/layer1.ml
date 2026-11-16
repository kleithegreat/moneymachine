(* Brief 3, step 2 test 4: whole-number venue arithmetic (V19, V20).
   Layer 1: the vault's 5,806 fills, ordered by time and within a millisecond
   as the API's pages give them, are replayed by the ledger under the base
   tier, with each coin's szDecimals from venue/hyperliquid/meta-2026-11-16.json.
   The venue's printed figures are compared as whole numbers: sizes in lots
   of 10^-szDecimals, prices in units of 10^(szDecimals - 6), money in
   millionths of a USDC. cut(n, x) is Float.to_int (Float.of_int n *. x),
   the double product with its fraction dropped (facts section 7; V19, V20).
   Nothing is found on a sample, and no figure is rounded to be compared.
   - Chain, grid, lots: every startPosition is the ledger's position before
     the fill; every price is on its coin's grid (A18, at figures of 5 and
     decimals of 6 - szDecimals) and every size a whole number of lots.
     This witnesses V1 and V3; an off-grid price means the certificate or
     the coin's rules are wrong.
   - Fee: with N the fill's lots times its price units and r the receipt's
     rate, the printed fee is cut(N, r'), r' the double nearest r. The
     receipt's fee, in millionths, is in [printed fee, printed fee + 1].
     This witnesses V4 and V19.
   - closedPnl: keep the venue's entry notional E per coin, zero when flat.
     A buy adds N. Closing s of p lots at P prints s * (P - E div p), then
     E becomes cut(E, x), x the double nearest the whole-lot ratio (p-s)/p,
     or zero when flat. Before every close, c is the ledger's entry times
     its position in millionths, and m the partial closes since last flat:
     E = c when m = 0, and always c - m <= E <= c. Every position is long,
     so printed closedPnl is at least the receipt's. This witnesses V20.
   - Made-up cases run without fills in venue_test.ml: maker cut(100000,
     0.00015) = 14 versus exact 15; taker cut(100000, 0.00045) = 45;
     one lot at 100 and two at 101 closed at 102 print 4000002 millionths
     versus exact 4 USDC; eleven lots at 1234 units, eight closed at 2000,
     print 6128 and keep 3701 versus exact 3702; the last three print 2301,
     using entry 1233. Exact fee floors and whole-number E scaling fail.
   - Print every difference and the record's counts: 44 of 58 whole exact
     fees print one under; 12 of 489 partial closes leave E under its exact
     floor; 2019 of 2508 closes have m = 0. Done only at no difference.

   Assumed Engine.Ledger signatures:
     initial : Rat -> Nat -> State
     step : List Tier -> State -> Event -> Except String Receipt
     replay : Rat -> Nat -> List Tier -> List Event -> Except String (List Receipt)
     position : State -> Nat -> Position; entry : State -> Nat -> Option Rat
     equity, unrealized : State -> List Rat -> Rat
   checkFunding : Int -> Int -> Int -> List (Nat * Int) -> List Event -> Except String Unit
   Tier {start : Int, name : String, maker taker : Rat}; Role.maker/taker;
   Event.fill(time, coin, signed units, price, role), funding(time,hour,coin,oracle,rate), absorb.
   Receipt {state, fee, closedPnl, tier, rate}; OCaml Mm2_lean.Ledger entry points:
     initial : rat -> int -> t; view : t -> snapshot
     equity, unrealized : t -> rat list -> rat
     step : tier list -> t -> event -> (receipt, string) result
     replay : cash:rat -> coins:int -> tier list -> event list -> (receipt list, string) result
   rat = string * string; the exact records are in ledger_test.ml's header.

   Additional OCaml reader entry point, Mm2_lean.Fills:
     type fill = { coin : string; px : string; sz : string; side : string;
       time : int64; start_position : string; dir : string; closed_pnl : string;
       hash : string; oid : int64; crossed : bool; fee : string; tid : int64;
       fee_token : string }
     val read_directory : string -> (fill list, string) result
   It reads fills-NNN.json API arrays, preserves decimal strings, deduplicates
   by tid (conflicting copies are errors), and orders by (time, tid).
   Mm2_lean.Exact.on_grid : int -> int -> rat -> bool;
   Exact.put_placed : int -> (string * int) -> (string, string) result;
   Mm2_lean.Decimal.place : string -> ((string * int), string) result.

   Local only: dune exec --root kernel2/ocaml test/layer1.exe -- FILLS_DIRECTORY
    Run from the repository or a descendant so the read-only meta file is found.
    Replay keeps first tids in file-name/array order, then stably sorts by time.
    The reader's (time, tid) tie order is not used as execution order.
   No raw fills are fixtures or Nix inputs; this executable is NOT @runtest.
   Base maker 0.015%, taker 0.045%, dated 2026-04-03 (A8; facts section 7).
   The venue arithmetic was found on this whole record, not a sample; these
   fills reproduce it, while fills not yet read will test it (part F).
   Differences go to the architect, never to a tolerance or a refitted rule.
*)

module L = Mm2_lean.Ledger
module F = Mm2_lean.Fills
module E = Mm2_lean.Exact
module O = Ledger_oracle
module Q = O.Q
module Z = O.Z
module V = Venue_oracle

let differences = ref 0
let difference context detail =
  incr differences;
  Printf.printf "DIFFERENCE %s: %s\n%!" context detail

let compare_q context actual expected =
  if not (Q.equal actual expected) then
    difference context (Printf.sprintf "got %s; expected %s" (Q.text actual) (Q.text expected))

let protect context action =
  try Some (action ()) with
  | Failure text | Invalid_argument text | Sys_error text -> difference context text; None
  | Yojson.Json_error text -> difference context text; None
  | Yojson.Safe.Util.Type_error (text, _) -> difference context text; None
  | Unix.Unix_error (error, operation, _) ->
    difference context (operation ^ ": " ^ Unix.error_message error); None

let field name json = Yojson.Safe.Util.member name json
let string name json = Yojson.Safe.Util.to_string (field name json)
let int64 name json =
  match field name json with
  | `Int n -> Int64.of_int n
  | `Intlit text -> Int64.of_string text
  | _ -> failwith ("expected integer " ^ name)

let parse json : F.fill =
  let time = int64 "time" json in
  if time >= 1793491200000L then failwith "fill is not before 2026-11-01; refusing its values";
  { coin = string "coin" json; px = string "px" json; sz = string "sz" json;
    side = string "side" json; time; start_position = string "startPosition" json;
    dir = string "dir" json; closed_pnl = string "closedPnl" json;
    hash = string "hash" json; oid = int64 "oid" json;
    crossed = Yojson.Safe.Util.to_bool (field "crossed" json);
    fee = string "fee" json; tid = int64 "tid" json; fee_token = string "feeToken" json }

let page_number name =
  if String.starts_with ~prefix:"fills-" name && String.ends_with ~suffix:".json" name then
    int_of_string_opt (String.sub name 6 (String.length name - 11))
  else None

let pages directory =
  Sys.readdir directory |> Array.to_list
  |> List.filter_map (fun name -> Option.map (fun number -> number, name) (page_number name))
  |> List.sort (fun (_, a) (_, b) -> String.compare a b)
  |> List.mapi (fun index (number, name) ->
    if number <> index then difference name "missing or misnumbered API page";
    name)

let verify_hashes directory names =
  let sums = Hashtbl.create (List.length names) in
  let manifest = Filename.concat directory "SHA256SUMS" in
  begin match protect "SHA256SUMS" (fun () ->
    let channel = open_in manifest in
    Fun.protect ~finally:(fun () -> close_in channel) (fun () ->
      let rec lines () =
        match input_line channel with
        | line ->
          if String.length line < 67 then difference "SHA256SUMS" "malformed line"
          else begin
            let hash = String.sub line 0 64 in
            let name = String.sub line 66 (String.length line - 66) in
            let name = if String.starts_with ~prefix:"./" name then
                String.sub name 2 (String.length name - 2) else name in
            if List.mem name names then begin
              if Hashtbl.mem sums name then difference name "repeated checksum"
              else Hashtbl.add sums name hash
            end
          end;
          lines ()
        | exception End_of_file -> ()
      in
      lines ())) with
  | Some () | None -> ()
  end;
  List.iter
    (fun name ->
      match Hashtbl.find_opt sums name with
      | None -> difference name "no SHA256SUMS entry"
      | Some expected ->
        ignore (protect name (fun () ->
          let path = Filename.concat directory name in
          let channel = Unix.open_process_args_in "sha256sum" [|"sha256sum"; "--"; path|] in
          let line = try input_line channel with End_of_file -> "" in
          let status = Unix.close_process_in channel in
          if status <> Unix.WEXITED 0 then difference name "sha256sum failed"
          else if String.length line < 64 || String.sub line 0 64 <> expected then
            difference name "SHA256 differs from SHA256SUMS")))
    names

let load directory names =
  let unique = Hashtbl.create 6000 in
  let ordered = ref [] in
  let duplicates = ref 0 in
  List.iter
    (fun name ->
      ignore (protect name (fun () ->
        let rows = Yojson.Safe.from_file (Filename.concat directory name) |> Yojson.Safe.Util.to_list in
        List.iteri
          (fun index json ->
            let context = Printf.sprintf "%s row %d" name index in
            match protect context (fun () -> parse json) with
            | None -> ()
            | Some row ->
              begin match Hashtbl.find_opt unique row.tid with
              | None ->
                Hashtbl.add unique row.tid row;
                ordered := row :: !ordered
              | Some previous ->
                incr duplicates;
                if row <> previous then difference context "same tid, conflicting fill objects"
              end)
          rows)))
    names;
  let rows = List.stable_sort (fun (a : F.fill) (b : F.fill) ->
    Int64.compare a.time b.time) (List.rev !ordered) in
  if List.length rows <> 5806 then
    difference "fill count" (Printf.sprintf "got %d unique tids; expected 5806" (List.length rows));
  if !duplicates = 0 then difference "API pages" "no repeated boundary rows were exercised";
  Printf.printf "layer1: %d unique fills; %d repeated rows removed\n%!" (List.length rows) !duplicates;
  rows

let check_reader directory expected =
  match F.read_directory directory with
  | Error code -> difference "OCaml fills reader" code
  | Ok actual ->
    let by_id = Hashtbl.create 6000 in
    List.iter
      (fun (row : F.fill) ->
        if Hashtbl.mem by_id row.tid then
          difference (Int64.to_string row.tid) "reader did not deduplicate tid";
        Hashtbl.replace by_id row.tid row)
      actual;
    List.iter
      (fun (row : F.fill) ->
        let context = Int64.to_string row.tid in
        match Hashtbl.find_opt by_id row.tid with
        | None -> difference context "reader omitted fill"
        | Some read ->
          if read <> row then difference context "reader changed an API field";
          Hashtbl.remove by_id row.tid)
      expected;
    Hashtbl.iter (fun tid _ -> difference (Int64.to_string tid) "reader invented a fill") by_id;
    (* Reader ties are not execution order; fields and tids were checked above. *)
    if List.map (fun (r : F.fill) -> r.time) actual <> List.map (fun (r : F.fill) -> r.time) expected then
      difference "OCaml fills reader" "time order/count differs from deduplicated API replay"

let rec meta_path directory =
  let path = Filename.concat directory "venue/hyperliquid/meta-2026-11-16.json" in
  if Sys.file_exists path then path
  else
    let parent = Filename.dirname directory in
    if parent = directory then failwith "cannot find read-only venue/hyperliquid/meta-2026-11-16.json"
    else meta_path parent

let significant_digits text =
  let digits = String.concat "" (String.split_on_char '.' text) |> Z.of_string |> Z.abs in
  let rec strip n = if n > 0 && digits.[n - 1] = '0' then strip (n - 1) else n in
  strip (String.length digits)

type analyzed = {
  row : F.fill; coin : int; units : Q.t; price : Q.t; notional : Q.t;
  sz_decimals : int; lots : int; price_units : int;
  after : O.position; pnl : Q.t;
}

let analyze coin_sizes coins rows =
  let positions = Array.make (List.length coins) O.flat in
  let analyzed = ref [] in
  List.iter
    (fun (row : F.fill) ->
      let context = Printf.sprintf "tid=%Ld %s time=%Ld" row.tid row.coin row.time in
      match protect context (fun () ->
        let coin = List.assoc row.coin (List.mapi (fun i name -> name, i) coins) in
        let sz_decimals = List.assoc row.coin coin_sizes in
        if sz_decimals < 0 || sz_decimals > 6 then failwith "szDecimals outside the certificate's 0..6";
        let price = Q.decimal row.px and size = Q.decimal row.sz in
        if not (Q.lt Q.zero price && Q.lt Q.zero size) then failwith "nonpositive fill price/size";
        let units = match row.side with
          | "B" -> size | "A" -> Q.neg size | _ -> failwith "side is neither B nor A" in
        let before = positions.(coin) in
        compare_q (context ^ " startPosition") (Q.decimal row.start_position) before.units;
        if row.fee_token <> "USDC" then difference context ("unexpected feeToken " ^ row.fee_token);
        let decimals = 6 - sz_decimals in
        let quantum = Q.make (Z.pow10 decimals) "1" in
        let sentence = (Q.mul price quantum).d = "1"
          && (price.d = "1" || significant_digits row.px <= 5) in
        if not sentence then difference context
          (Printf.sprintf "px=%s off certified grid (5 figures, %d decimals): STOP for architect (V1/V3)" row.px decimals);
        if E.on_grid 5 decimals (Q.wire price) <> sentence then
          difference context "Engine.Exact grid differs from independent digit-count certificate";
        if (Q.mul size (Q.make (Z.pow10 sz_decimals) "1")).d <> "1" then
          difference context (Printf.sprintf "sz=%s is not whole lots at szDecimals=%d (V3)" row.sz sz_decimals);
        List.iter
          (fun (name, scale, text) ->
            match Mm2_lean.Decimal.place text with
            | Error code -> difference (context ^ " " ^ name) code
            | Ok placed ->
              begin match E.put_placed scale placed with
              | Error code -> difference (context ^ " " ^ name) code
              | Ok integer -> compare_q (context ^ " " ^ name ^ " placed value")
                  (Q.make integer (Z.pow10 scale)) (Q.decimal text)
              end)
          ["px", 8, row.px; "sz", sz_decimals, row.sz];
        let after, pnl = O.fill before units price in
        let lots = V.whole sz_decimals row.sz in
        let price_units = V.whole decimals row.px in
        positions.(coin) <- after;
        {row; coin; units; price; notional = Q.mul size price;
         sz_decimals; lots; price_units; after; pnl}) with
      | None -> ()
      | Some value -> analyzed := value :: !analyzed)
    rows;
  List.rev !analyzed

let check_ledger coins rows =
  let tier : L.tier =
    { from_ms = 1775174400000L; name = "base";
      maker = ("3", "20000"); taker = ("9", "20000") } in
  let cash = Q.integer 1000000000 in
  let million = Q.integer 1000000 in
  let held = Array.make (List.length coins) 0 in
  let entry = Array.make (List.length coins) 0 in
  let partials = Array.make (List.length coins) 0 in
  let whole_fees = ref 0 and one_under = ref 0 in
  let closes = ref 0 and clean_closes = ref 0 in
  let partial_closes = ref 0 and lossy = ref 0 in
  let state = ref (L.initial (Q.wire cash) (List.length coins)) in
  let expected_cash = ref cash in
  let events = ref [] and snapshots = ref [] in
  List.iter
    (fun a ->
       let context = Printf.sprintf "tid=%Ld %s time=%Ld" a.row.tid a.row.coin a.row.time in
       ignore (protect context (fun () ->
       let rate = Q.of_wire (if a.row.crossed then tier.taker else tier.maker) in
       let exact_fee = Q.mul a.notional rate in
       let notional = V.product a.lots a.price_units in
       compare_q (context ^ " whole notional") (Q.integer notional) (Q.mul a.notional million);
       let printed_fee = V.whole 6 a.row.fee in
       let printed_pnl = V.whole 6 a.row.closed_pnl in
       let current = List.nth (L.view !state).positions a.coin in
       compare_q (context ^ " ledger startPosition") (Q.of_wire current.units) (Q.decimal a.row.start_position);
       compare_q (context ^ " venue startPosition (lots)")
         (Q.integer (V.whole a.sz_decimals a.row.start_position)) (Q.integer held.(a.coin));
       compare_q (context ^ " ledger position vs venue lots")
         (Q.mul (Q.of_wire current.units) (Q.make (Z.pow10 a.sz_decimals) "1"))
         (Q.integer held.(a.coin));
       let expected_pnl =
         if a.row.side = "B" then begin
           if a.row.dir <> "Open Long" then difference context "buy is not Open Long (V20)";
           if held.(a.coin) = 0 then begin entry.(a.coin) <- 0; partials.(a.coin) <- 0 end;
           entry.(a.coin) <- entry.(a.coin) + notional;
           held.(a.coin) <- held.(a.coin) + a.lots;
           0
         end else begin
           if a.row.dir <> "Close Long" then difference context "sell is not Close Long (V20)";
           incr closes;
           let cost = match current.entry with
             | None -> difference context "close has no ledger entry"; Q.zero
             | Some price -> Q.mul million (Q.mul (Q.of_wire price) (Q.of_wire current.units)) in
           compare_q (context ^ " entry times position vs ledger cost") cost (Q.mul million (Q.of_wire current.cost));
           let e = Q.integer entry.(a.coin) in
           let m = partials.(a.coin) in
           if m = 0 then begin
             incr clean_closes;
             compare_q (context ^ " E before any partial close (millionths)") e cost
           end;
           if not (Q.le (Q.sub cost (Q.integer m)) e && Q.le e cost) then
             difference context (Printf.sprintf "V20: E=%s outside [cost-m, cost], cost=%s m=%d millionths"
               (Q.text e) (Q.text cost) m);
           let printed, kept = V.close entry.(a.coin) held.(a.coin) a.lots a.price_units in
           let left = held.(a.coin) - a.lots in
           if left > 0 then begin
             incr partial_closes;
             if kept < V.floor_scaled entry.(a.coin) left held.(a.coin) then incr lossy;
             partials.(a.coin) <- m + 1
           end else partials.(a.coin) <- 0;
           entry.(a.coin) <- kept;
           held.(a.coin) <- left;
           printed
         end in
       compare_q (context ^ " printed closedPnl (millionths)")
         (Q.integer expected_pnl) (Q.integer printed_pnl);
       let event = L.Fill { time = a.row.time; coin = a.coin; units = Q.wire a.units;
        price = Q.wire a.price; role = if a.row.crossed then L.Taker else L.Maker } in
      expected_cash := Q.sub (Q.sub !expected_cash (Q.mul a.units a.price)) exact_fee;
      events := event :: !events;
      begin match L.step [tier] !state event with
      | Error code -> difference context ("ledger step rejected: " ^ code)
      | Ok receipt ->
         compare_q (context ^ " exact fee") (Q.of_wire receipt.fee) exact_fee;
         compare_q (context ^ " exact closedPnl") (Q.of_wire receipt.closed_pnl) a.pnl;
         let receipt_rate = match receipt.rate with
           | Some rate -> Q.of_wire rate
           | None -> difference context "fill receipt has no rate"; rate in
         compare_q (context ^ " printed fee (millionths)")
           (Q.integer (V.fee notional receipt_rate)) (Q.integer printed_fee);
         let fee = Q.mul million (Q.of_wire receipt.fee) in
         if fee.d = "1" then incr whole_fees;
         if Q.equal (Q.sub fee (Q.integer printed_fee)) Q.one then incr one_under;
         if not (Q.le (Q.integer printed_fee) fee && Q.le fee (Q.integer (printed_fee + 1))) then
           difference context (Printf.sprintf "V19: ledger fee=%s outside [printed=%d, printed+1] millionths"
             (Q.text fee) printed_fee);
         let pnl = Q.mul million (Q.of_wire receipt.closed_pnl) in
         if not (Q.le pnl (Q.integer printed_pnl)) then
           difference context (Printf.sprintf "V20: printed closedPnl=%d below ledger=%s millionths"
             printed_pnl (Q.text pnl));
        if receipt.tier <> Some tier.name || receipt.rate <> Some (Q.wire rate) then
          difference context "wrong fee tier or role rate";
        let view = L.view receipt.state in
        let position = List.nth view.positions a.coin in
        compare_q (context ^ " position after fill") (Q.of_wire position.units) a.after.units;
        compare_q (context ^ " unrounded cost") (Q.of_wire position.cost) a.after.cost;
        if position.entry <> Option.map Q.wire (O.entry a.after) then difference context "wrong entry";
        compare_q (context ^ " cash") (Q.of_wire view.cash) !expected_cash;
        state := receipt.state;
        snapshots := view :: !snapshots
       end)))
     rows;
  Printf.printf "layer1: %d of %d whole exact fees printed one under; %d of %d partial closes left E under its exact floor; %d of %d closes had m=0\n%!"
    !one_under !whole_fees !lossy !partial_closes !clean_closes !closes;
  List.iter (fun (name, actual, expected) ->
    if actual <> expected then difference name (Printf.sprintf "got %d; expected %d" actual expected))
    ["whole exact fees", !whole_fees, 58; "fees one under", !one_under, 44;
     "partial closes", !partial_closes, 489; "lossy partial closes", !lossy, 12;
     "closes before any partial", !clean_closes, 2019; "closes", !closes, 2508];
  match L.replay ~cash:(Q.wire cash) ~coins:(List.length coins) [tier] (List.rev !events) with
  | Error code -> difference "given-fill replay" code
  | Ok receipts ->
    let rec compare index expected actual = match expected, actual with
      | [], [] -> ()
      | e :: es, (a : L.receipt) :: rest ->
        if L.view a.state <> e then difference (Printf.sprintf "replay row %d" index) "differs from step fold";
        compare (index + 1) es rest
      | _ -> difference "given-fill replay" "receipt count differs from supplied fills"
    in
    compare 0 (List.rev !snapshots) receipts

let main directory =
  let names = pages directory in
  if names = [] then failwith "no fills-NNN.json pages";
  verify_hashes directory names;
  let rows = load directory names in
  check_reader directory rows;
  let meta = Yojson.Safe.from_file (meta_path (Sys.getcwd ())) in
  let coin_sizes = field "universe" meta |> Yojson.Safe.Util.to_list
    |> List.map (fun coin -> string "name" coin,
      field "szDecimals" coin |> Yojson.Safe.Util.to_int) in
  let coins = List.map (fun (row : F.fill) -> row.coin) rows |> List.sort_uniq String.compare in
  let missing = ref false in
  List.iter (fun coin ->
    if not (List.mem_assoc coin coin_sizes) then begin
      difference coin "fill coin absent from meta-2026-11-16.json universe";
      missing := true
    end) coins;
  if !missing then failwith "STOP: fill coin absent from venue meta";
  let analyzed = analyze coin_sizes coins rows in
  check_ledger coins analyzed;
  Printf.printf "layer1: %d differences across %d fills\n%!" !differences (List.length rows);
  if !differences <> 0 then exit 1

let () =
  if Array.length Sys.argv <> 2 then begin
    prerr_endline "usage: layer1 FILLS_DIRECTORY";
    exit 2
  end;
  try main Sys.argv.(1) with
  | exception_value ->
    Printf.eprintf "layer1 failed: %s\n%!" (Printexc.to_string exception_value);
    exit 1
