(* Brief 3, step 2 test 4 (verbatim):
   For all 5,806 fills, the fee and closedPnl equal the venue's printed values
   under one rounding of the exact value to the printed decimals, the mode
   found for each field on the first hundred fills and fixed in the test;
   startPosition chains exactly, and every price is on its coin's grid (A18,
   at figures of 5 and decimals of 6 - szDecimals) and every size a whole
   number of lots. Print every difference; exit nonzero on any.

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
   Run from the repository or a descendant so the read-only rules file is found.
   No raw fills are fixtures or Nix inputs; this executable is NOT @runtest.
   A8's base tier is for the simulated account, not a specified vault tier.
   Accordingly rates, too, are found on the first 100 unique fills and frozen
   before inspecting any later fee/PnL. Select the simplest decimal rate (at
   most A2's 12 places) per role consistent with that sample. Among fee modes,
   minimize the total rate precision, breaking ties by Q.modes' fixed order.
   Indistinguishable modes use that same fixed order, never later observations.
   The chosen rates/modes and all sample-compatible PnL modes are printed.
   This discovers a witness, not a claim that a rounded sample identifies a
   unique rate or a tie rule; any later discrepancy is a failure, not a refit.
*)

module L = Mm2_lean.Ledger
module F = Mm2_lean.Fills
module E = Mm2_lean.Exact
module O = Ledger_oracle
module Q = O.Q
module Z = O.Z

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
  |> List.sort (fun (a, _) (b, _) -> Int.compare a b)
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
            if not (List.mem name names) then difference "SHA256SUMS" ("unexpected file " ^ name)
            else if Hashtbl.mem sums name then difference name "repeated checksum"
            else Hashtbl.add sums name hash
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
              | None -> Hashtbl.add unique row.tid row
              | Some previous ->
                incr duplicates;
                if row <> previous then difference context "same tid, conflicting fill objects"
              end)
          rows)))
    names;
  let rows = Hashtbl.fold (fun _ row acc -> row :: acc) unique [] in
  let rows = List.sort (fun (a : F.fill) (b : F.fill) ->
    let time = Int64.compare a.time b.time in
    if time = 0 then Int64.compare a.tid b.tid else time) rows in
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
    if List.map (fun (r : F.fill) -> r.tid) actual <> List.map (fun (r : F.fill) -> r.tid) expected then
      difference "OCaml fills reader" "order/count differs from deduplicated (time, tid) order"

let rec rules_path directory =
  let path = Filename.concat directory "venue/hyperliquid/rules.json" in
  if Sys.file_exists path then path
  else
    let parent = Filename.dirname directory in
    if parent = directory then failwith "cannot find read-only venue/hyperliquid/rules.json"
    else rules_path parent

let significant_digits text =
  let digits = String.concat "" (String.split_on_char '.' text) |> Z.of_string |> Z.abs in
  let rec strip n = if n > 0 && digits.[n - 1] = '0' then strip (n - 1) else n in
  strip (String.length digits)

type analyzed = {
  row : F.fill; coin : int; units : Q.t; price : Q.t; notional : Q.t;
  after : O.position; pnl : Q.t;
}

let analyze rules coins rows =
  let positions = Array.make (List.length coins) O.flat in
  let analyzed = ref [] in
  List.iter
    (fun (row : F.fill) ->
      let context = Printf.sprintf "tid=%Ld %s time=%Ld" row.tid row.coin row.time in
      match protect context (fun () ->
        let coin = List.assoc row.coin (List.mapi (fun i name -> name, i) coins) in
        let sz_decimals = field "coins" rules |> field row.coin |> field "szDecimals" |> Yojson.Safe.Util.to_int in
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
        positions.(coin) <- after;
        {row; coin; units; price; notional = Q.mul size price; after; pnl}) with
      | None -> ()
      | Some value -> analyzed := value :: !analyzed)
    rows;
  List.rev !analyzed

let matches mode exact printed =
  Q.equal (Q.round mode (Q.places printed) exact) (Q.decimal printed)

let find_rate mode sample =
  match sample with
  | [] -> None
  | _ ->
    let low, high = List.fold_left
      (fun (low, high) a ->
        let printed = Q.decimal a.row.fee in
        let unit = Q.make "1" (Z.pow10 (Q.places a.row.fee)) in
        Q.max low (Q.div (Q.sub printed unit) a.notional),
        Q.min high (Q.div (Q.add printed unit) a.notional))
      (Q.zero, Q.one) sample in
    let rec precision places =
      if places > 12 || Q.lt high low then None
      else
        let scale = Z.pow10 places in
        let multiplier = Q.make scale "1" in
        let lower = Q.round_integer Q.Ceil (Q.mul low multiplier) in
        let upper = Q.round_integer Q.Floor (Q.mul high multiplier) in
        let rec candidate numerator =
          if Z.compare numerator upper > 0 then precision (places + 1)
          else
            let rate = Q.make numerator scale in
            if List.for_all (fun a -> matches mode (Q.mul a.notional rate) a.row.fee) sample then
              Some (places, rate)
            else candidate (Z.add numerator "1")
        in
        candidate lower
    in
    precision 0

let first_hundred rows =
  let rec take left acc = function
    | [] -> List.rev acc
    | _ when left = 0 -> List.rev acc
    | row :: rest -> take (left - 1) (row :: acc) rest
  in
  take 100 [] rows

let calibrate sample =
  if List.length sample <> 100 then difference "calibration" "fewer than 100 usable unique fills";
  let pnl_modes = List.filter
    (fun mode -> List.for_all (fun a -> matches mode a.pnl a.row.closed_pnl) sample) Q.modes in
  let pnl_mode = match pnl_modes with
    | mode :: _ -> mode
    | [] -> failwith "STOP for architect: no single closedPnl rounding mode fits the first 100 unique fills" in
  let maker = List.filter (fun a -> not a.row.crossed) sample in
  let taker = List.filter (fun a -> a.row.crossed) sample in
  let choices = List.filter_map
    (fun mode -> match find_rate mode maker, find_rate mode taker with
      | Some (mp, mr), Some (tp, tr) -> Some (mp + tp, mode, mr, tr)
      | _ -> None)
    Q.modes in
  let choices = List.stable_sort (fun (a, _, _, _) (b, _, _, _) -> Int.compare a b) choices in
  let fee_mode, maker_rate, taker_rate = match choices with
    | (_, mode, mr, tr) :: _ -> mode, mr, tr
    | [] -> failwith "STOP for architect: no per-role decimal rates and single fee rounding fit the first 100 unique fills (both roles required)" in
  Printf.printf
    "FIXED from first 100 unique fills (vault tier unspecified): maker=%s taker=%s fee=%s closedPnl=%s; compatible closedPnl modes=[%s]. No later refit.\n%!"
    (Q.text maker_rate) (Q.text taker_rate) (Q.mode_name fee_mode) (Q.mode_name pnl_mode)
    (String.concat "," (List.map Q.mode_name pnl_modes));
  fee_mode, pnl_mode, maker_rate, taker_rate

let check_ledger coins rows fee_mode pnl_mode maker_rate taker_rate =
  let tier : L.tier =
    { from_ms = 0L; name = "vault-first-100"; maker = Q.wire maker_rate; taker = Q.wire taker_rate } in
  let cash = Q.integer 1000000000 in
  let state = ref (L.initial (Q.wire cash) (List.length coins)) in
  let expected_cash = ref cash in
  let events = ref [] and snapshots = ref [] in
  List.iter
    (fun a ->
      let context = Printf.sprintf "tid=%Ld %s time=%Ld" a.row.tid a.row.coin a.row.time in
      let rate = if a.row.crossed then taker_rate else maker_rate in
      let exact_fee = Q.mul a.notional rate in
      compare_q (context ^ " printed fee")
        (Q.round fee_mode (Q.places a.row.fee) exact_fee) (Q.decimal a.row.fee);
      compare_q (context ^ " printed closedPnl")
        (Q.round pnl_mode (Q.places a.row.closed_pnl) a.pnl) (Q.decimal a.row.closed_pnl);
      let current = List.nth (L.view !state).positions a.coin in
      compare_q (context ^ " ledger startPosition") (Q.of_wire current.units) (Q.decimal a.row.start_position);
      let event = L.Fill { time = a.row.time; coin = a.coin; units = Q.wire a.units;
        price = Q.wire a.price; role = if a.row.crossed then L.Taker else L.Maker } in
      expected_cash := Q.sub (Q.sub !expected_cash (Q.mul a.units a.price)) exact_fee;
      events := event :: !events;
      begin match L.step [tier] !state event with
      | Error code -> difference context ("ledger step rejected: " ^ code)
      | Ok receipt ->
        compare_q (context ^ " exact fee") (Q.of_wire receipt.fee) exact_fee;
        compare_q (context ^ " exact closedPnl") (Q.of_wire receipt.closed_pnl) a.pnl;
        compare_q (context ^ " engine rounded fee vs API")
          (Q.round fee_mode (Q.places a.row.fee) (Q.of_wire receipt.fee)) (Q.decimal a.row.fee);
        compare_q (context ^ " engine rounded closedPnl vs API")
          (Q.round pnl_mode (Q.places a.row.closed_pnl) (Q.of_wire receipt.closed_pnl)) (Q.decimal a.row.closed_pnl);
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
      end)
    rows;
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
  let rules = Yojson.Safe.from_file (rules_path (Sys.getcwd ())) in
  let coins = List.map (fun (row : F.fill) -> row.coin) rows |> List.sort_uniq String.compare in
  let analyzed = analyze rules coins rows in
  let fee_mode, pnl_mode, maker_rate, taker_rate = calibrate (first_hundred analyzed) in
  check_ledger coins analyzed fee_mode pnl_mode maker_rate taker_rate;
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
