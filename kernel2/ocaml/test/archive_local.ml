(* LOCAL ONLY, step 3 test 5. Run archive_local ARCHIVE_ROOT REPO_ROOT.
   ARCHIVE_ROOT itself contains raw/YYYYMMDD/H/COIN.lz4 and
   snapshots/COIN/YYYYMMDD.parquet; it is normally REPO_ROOT/data/hl-archive.
   Engine.Machine/Mm2_lean.Machine start/feed/finish use A18 arrays/A19 rows.
   mm2 start PROGRAM HEADER STATE; feed STATE CHUNK_JSON; finish STATE OUTDIR;
   inspect HEADER CHUNK_JSON exposes integrity only (events_support.ml).
   mm2_archive.Reader.archive_day ~root ~meta ~coin ~day ~delta ~emit validates
   the raw manifest BEFORE emit and returns reader counts or a named error;
   coin_rules reads universe[].name,szDecimals, giving name,sz,5,6-sz, sz<=6.
   The header's initial listing is derived from those same rules, not rules.json.
   kernel2/protected-windows.json is compiled strict JSON data, a list of
   exactly {start:integer-ms,end:integer-ms,released:bool}; no runtime override.
   Only the existing ingest.archive.parse is the foreign-language oracle;
   the inline adapter just combines its frames and writes untouched float bits.
   Seven fast, six intermediate and seven slow coin-days are frozen below,
   sampled across coins/dates without opening any forward-window data. *)

open Events_support
module R = Mm2_archive.Reader

let samples =
  [ "BTC","20260403"; "ETH","20260417"; "SOL","20260501";
    "HYPE","20260519"; "XRP","20260601"; "ADA","20260610"; "AVAX","20260614";
    "BTC","20260616"; "ETH","20260616"; "SOL","20260617";
    "HYPE","20260618"; "XRP","20260619"; "ADA","20260620";
    "BTC","20260621"; "ETH","20260701"; "SOL","20260801";
    "HYPE","20260820"; "XRP","20260901"; "ADA","20260920"; "BNB","20261020" ]

let oracle = {|import sys, struct
from pathlib import Path
import polars as pl
from ingest.archive import parse
root, coin, day = Path(sys.argv[1]), sys.argv[2], sys.argv[3]
assert "20260403" <= day < "20261101"
paths = [root / "raw" / day / str(h) / (coin + ".lz4") for h in range(24)]
frames = [parse(p) for p in paths if p.exists()]
assert frames
frame = pl.concat(frames).sort("time").unique("time", keep="first", maintain_order=True)
for row in frame.iter_rows(named=True):
    assert row["time"] < 1793491200000
    if not row["bid_px"] or not row["ask_px"] or row["bid_px"][0] >= row["ask_px"][0]:
        continue
    values = []
    for side in ("bid", "ask"):
        for px, sz in zip(row[side + "_px"], row[side + "_sz"], strict=True):
            values.extend((px, sz))
    fields = [str(row["time"]), str(len(row["bid_px"])), str(len(row["ask_px"]))]
    fields.extend(struct.pack(">d", value).hex() for value in values)
    print("\t".join(fields))
|}

let compare_day root repo meta (coin, day) =
  check "never open protected dated files" (day >= "20260403" && day < "20261101");
  let args = [| "python"; "-c"; "import sys; sys.path.insert(0, sys.argv.pop(1));\n" ^ oracle;
                repo; root; coin; day |] in
  let input = Unix.open_process_args_in "python" args in
  let compared = ref 0 in
  let emit (value : M.chunk) =
    check "archive has no string exact fields" (Array.length value.integers = 0);
    check "archive records are complete" (Bytes.length value.records mod 24 = 0);
    let offset = ref 0 in
    for i = 0 to Bytes.length value.records / 24 - 1 do
      let start = 24 * i in
      check "archive emits quotes, no invented events" (Bytes.get_uint8 value.records start = 3);
      check "archive coin index" (Bytes.get_uint16_le value.records (start + 4) = 0);
      check "archive unused fields zero" (Bytes.get_uint8 value.records (start + 3) = 0
        && Bytes.get_uint16_le value.records (start + 6) = 0);
      let time = Bytes.get_int64_le value.records (start + 8) in
      check "archive known is time plus delta" (Bytes.get_int64_le value.records (start + 16) = Int64.add time 17L);
      let bids = Bytes.get_uint8 value.records (start + 1) in
      let asks = Bytes.get_uint8 value.records (start + 2) in
      let expected = input_line input |> String.split_on_char '\t' in
      let actual = ref [ string_of_int asks; string_of_int bids; Int64.to_string time ] in
      for j = 0 to 2 * (bids + asks) - 1 do
        actual := Printf.sprintf "%016Lx" (Int64.bits_of_float value.doubles.(!offset + j)) :: !actual
      done;
      check (Printf.sprintf "%s/%s event %d differs from Python oracle" coin day !compared)
        (List.rev !actual = expected);
      offset := !offset + 2 * (bids + asks);
      incr compared
    done;
    check "all double payload consumed" (!offset = Array.length value.doubles)
  in
  let result = R.archive_day ~root ~meta ~coin ~day ~delta:17 ~emit in
  ignore (get result);
  check "no oracle events omitted" (try ignore (input_line input); false with End_of_file -> true);
  check "oracle succeeded" (Unix.close_process_in input = Unix.WEXITED 0);
  check "sample cannot pass vacuously" (!compared > 0);
  Printf.printf "%s %s: %d event-for-event matches\n%!" coin day !compared

let contains text part =
  let rec search i =
    i + String.length part <= String.length text
    && (String.sub text i (String.length part) = part || search (i + 1))
  in search 0

let () =
  check "usage: archive_local ARCHIVE_ROOT REPO_ROOT" (Array.length Sys.argv = 3);
  let root = Sys.argv.(1) and repo = Sys.argv.(2) in
  let meta = Filename.concat repo "venue/hyperliquid/meta-2026-11-16.json" in
  let rules = get (R.coin_rules meta) in
  let expected_rules = Yojson.Basic.from_file meta |> field "universe" |> Yojson.Basic.Util.to_list
      |> List.map (fun coin ->
        let name = text_field "name" coin and sz = int_field "szDecimals" coin in
        name, sz, 5, 6 - sz) in
  check "reader uses the named metadata's universe, not rules.json" (rules = expected_rules);
  List.iter (fun (_, sz, figures, decimals) -> check "venue grid from metadata alone" (sz <= 6 && figures = 5 && decimals = 6 - sz)) rules;
  check "twenty unique samples" (List.length (List.sort_uniq compare samples) = 20);
  List.iter (compare_day root repo meta) samples;
  let emitted = ref false in
  let result = R.archive_day ~root ~meta ~coin:"BTC" ~day:"20261001" ~delta:0
      ~emit:(fun _ -> emitted := true) in
  (match result with
   | Ok _ -> failwith "expected BTC/20261001 table short of its raw files (brief 3 test 5); if repaired, take this finding to the architect"
   | Error message ->
     check "manifest names the short table, not a generic read failure"
       (contains message "BTC" && contains message "20261001" && contains (String.lowercase_ascii message) "short");
     check "short table refused before any event is emitted" (not !emitted);
     Printf.printf "%s\n%!" message)
