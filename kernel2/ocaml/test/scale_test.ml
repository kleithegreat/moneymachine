(* Step 3 test 6, sandbox rate guard: the shape of 2026-04-03, NOT its data.
   Exactly 2,487,176 quotes, sixteen coins, twenty levels each side (80
   binary64 exact fields per quote), over one day, no program/clock. Every
   record goes through the normal public feed. Fields vary by event and coin;
   decimal sizes cover scales 0..5. The real day/window are scale_local's job.
   Fixture construction, start, feed and finish all count toward 150 seconds.
   Never accumulate a day's tape or output. No local files are Nix inputs. *)
open Events_support
module S = Scale_support

let quotes = 2_487_176
let last = Int64.add base 86_400_000L

let worker () =
  S.check_one_core ();
  let started = Unix.gettimeofday () in
  let rules = List.mapi (fun i name -> name, i mod 6, 5, 6 - i mod 6) S.coins in
  let state = ref (get (M.start "" (S.market ~last rules))) in
  let streamed = ref 0L in
  let consume (rows : M.rows) =
    streamed := Int64.add !streamed
      (Int64.of_int (String.length rows.report + String.length rows.trace)) in
  let batch_size = 4096 in
  let batches = (quotes + batch_size - 1) / batch_size in
  for batch = 0 to batches - 1 do
    let first = batch * batch_size in
    let length = min batch_size (quotes - first) in
    let records = Bytes.make (24 * length) '\000' in
    let doubles = Array.make (80 * length) 0. in
    for local = 0 to length - 1 do
      let index = first + local in
      let coin = index mod 16 in
      let time = Int64.add base (Int64.of_int ((index / 16) * 86_400_000 / ((quotes + 15) / 16))) in
      let offset = 24 * local in
      Bytes.set_uint8 records offset 3;
      Bytes.set_uint8 records (offset + 1) 20;
      Bytes.set_uint8 records (offset + 2) 20;
      Bytes.set_uint16_le records (offset + 4) coin;
      Bytes.set_int64_le records (offset + 8) time;
      Bytes.set_int64_le records (offset + 16) time;
      let center = 1000 + coin * 1000 + (index / 16 mod 100) in
      let divisor = 10. ** float_of_int (coin mod 6) in
      for level = 0 to 39 do
        let ticks = if level < 20 then center - level - 1 else center + level - 19 in
        doubles.(80 * local + 2 * level) <- float_of_int ticks /. 10.;
        doubles.(80 * local + 2 * level + 1) <-
          float_of_int (1 + (index * 41 + level * 17) mod 99991) /. divisor
      done
    done;
    let next, rows = M.feed !state { records; integers = [||]; doubles } in
    state := next;
    consume rows;
    check "suite day native state below 2GB" (M.retained_bytes next < 2_000_000_000L)
  done;
  let rows, summary = M.finish !state in
  consume rows;
  success (json summary);
  let elapsed = Unix.gettimeofday () -. started and rss = S.peak_rss () in
  Printf.printf "step3 suite day: quotes=%Ld seconds=%.3f peak_rss=%Ld streamed_bytes=%Ld\n%!"
    (M.count !state) elapsed rss !streamed;
  check "entire day fed, no sampling/drops/empty-engine pass" (M.count !state = Int64.of_int quotes);
  check "suite admission day strictly under 150 seconds" (elapsed < 150.);
  check "suite whole process below 2GB" (rss < 2_000_000_000L)

let () = match Array.to_list Sys.argv with
  | [_; "--worker"] -> worker ()
  | [_] -> S.launch 150 []
  | _ -> failwith "usage: scale_test"
