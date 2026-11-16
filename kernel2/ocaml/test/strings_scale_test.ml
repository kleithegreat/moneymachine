(* Step 3 test 6, strings. Requires admit's retained readings and onGridAt;
   no new OCaml signature. Writes a synthetic recorder-form JSONL day, then
   feeds its already-packed A18 chunks: 17 coins, five levels per side,
   1,000,000 quotes, all exact sources string. The recorder reader is step 6;
   here the test places its generated strings without knowing a field scale.
   Only feed is timed, on one OS core, strictly under 22 seconds. *)

open Events_support
module S = Scale_support

let quotes = 1_000_000
let batch_size = 4096
let last = Int64.add base 86_400_000L
let names = Array.init 17 (fun i -> Printf.sprintf "S%02d" i)

let written n scale =
  let digits = string_of_int n in
  let digits = String.make (max 0 (scale + 1 - String.length digits)) '0' ^ digits in
  let split = String.length digits - scale in
  if scale = 0 then digits else
    String.sub digits 0 split ^ "." ^ String.sub digits split scale

let template coin phase =
  let sz = coin mod 7 in
  let decimals = 6 - sz in
  let centre = 11000 + coin * 3000 + phase * 20 in
  let side ask = List.init 5 (fun level ->
    let units = centre + (if ask then 2 * level + 1 else -2 * level - 1) in
    check "fixture prices have five significant figures"
      (units >= 10000 && units < 100000 && units mod 10 <> 0);
    let price = written units decimals in
    let size = written (1 + (coin * 41 + phase * 101 + level * 17) mod 99991) sz in
    price, size) in
  let bids = side false and asks = side true in
  let json_side levels = `List (List.map (fun (px, sz) ->
    `Assoc ["px", `String px; "sz", `String sz; "n", `Int 1]) levels) in
  let levels = Yojson.Basic.to_string (`List [json_side bids; json_side asks]) in
  let integers = List.concat_map (fun (px, sz) -> placed px @ placed sz) (bids @ asks)
      |> Array.of_list in
  check "twenty strings, two placed integers each" (Array.length integers = 40);
  levels, integers

let prepack path =
  let templates = Array.init 17 (fun coin -> Array.init 97 (template coin)) in
  let stream = open_out_bin path in
  Fun.protect ~finally:(fun () -> close_out stream) (fun () ->
    let chunks = Array.init ((quotes + batch_size - 1) / batch_size) (fun batch ->
      let first = batch * batch_size in
      let length = min batch_size (quotes - first) in
      let records = Bytes.make (24 * length) '\000' in
      let integers = Array.make (40 * length) 0L in
      for local = 0 to length - 1 do
        let index = first + local in
        let coin = index mod 17 in
        let phase = index / 17 mod 97 in
        let time = Int64.add base
            (Int64.of_int ((index / 17) * 86_400_000 / ((quotes + 16) / 17))) in
        let levels, values = templates.(coin).(phase) in
        Printf.fprintf stream
          {|{"recv":%Ld,"conn":0,"msg":{"channel":"l2Book","data":{"coin":"%s","time":%Ld,"levels":%s}}}|}
          time names.(coin) time levels;
        output_char stream '\n';
        let offset = 24 * local in
        Bytes.set_uint8 records offset 3;
        Bytes.set_uint8 records (offset + 1) 5;
        Bytes.set_uint8 records (offset + 2) 5;
        Bytes.set_uint16_le records (offset + 4) coin;
        Bytes.set_int64_le records (offset + 8) time;
        Bytes.set_int64_le records (offset + 16) time;
        Array.blit values 0 integers (40 * local) 40
      done;
      ({ records; integers; doubles = [||] } : M.chunk)) in
    flush stream;
    check "the generated recorder day was written" ((Unix.stat path).st_size > quotes);
    check "all million quotes are packed before timing"
      (Array.fold_left (fun count (c : M.chunk) -> count + Bytes.length c.records / 24) 0 chunks = quotes);
    chunks)

let worker () =
  S.check_one_core ();
  with_file ".recorder-day.jsonl" (fun path ->
    let chunks = prepack path in
    let rules = Array.to_list (Array.mapi (fun i name -> name, i mod 7, 5, 6 - i mod 7) names) in
    let state = ref (get (M.start "" (S.market ~encoding:"string" ~last rules))) in
    let streamed = ref 0 in
    let elapsed = ref 0. in
    Array.iter (fun value ->
      let started = Unix.gettimeofday () in
      let next, rows = M.feed !state value in
      elapsed := !elapsed +. (Unix.gettimeofday () -. started);
      state := next;
      streamed := !streamed + String.length rows.report + String.length rows.trace) chunks;
    let rows, summary = M.finish !state in
    streamed := !streamed + String.length rows.report + String.length rows.trace;
    success (json summary);
    check "all million string quotes admitted" (M.count !state = Int64.of_int quotes);
    check "one million string quotes: feed strictly under 22 seconds" (!elapsed < 22.);
    check "whole worker below 2GB" (S.peak_rss () < 2_000_000_000L);
    Printf.printf "step3 strings: quotes=%d feed_seconds=%.3f peak_rss=%Ld streamed_bytes=%d\n%!"
      quotes !elapsed (S.peak_rss ()) !streamed)

let () = match Array.to_list Sys.argv with
  | [_; "--worker"] -> worker ()
  | [_] -> S.launch 600 []
  | _ -> failwith "usage: strings_scale_test"
