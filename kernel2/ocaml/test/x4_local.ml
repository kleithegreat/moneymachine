(* Brief 3 step 5 test 12. LOCAL; invocation: x4_local.exe INPUT_DIR OUTPUT.
   Builder supplies ONLY the existing Mm2_lean.Machine.start/feed/finish and
   A18 chunks (events_support.ml), and Mm2_lean.Exact.nearest_bits :
   (string * string) -> int64. exp/log are tested as declared-source probes,
   not through new engine exports. Non-finite probe results must be undefined.
   MPFR/GMP are test-only inputs from pinned nixpkgs (x4_mpfr_stubs.c).

   INPUT_DIR/SHA256SUMS pins manifest.json and all six argument files:
     exp-draws.txt, log-draws.txt: exactly 1,000,000 finite binary64 hex lines
     each, drawn by arithmetic.py.txt:last_pass_r3, not a replacement sampler;
     exp-glibc.txt, log-glibc.txt: EVERY mis-rounded argument from those draws;
   hardest.txt: lines `exp HEX` or `log HEX`, the advisor-certified tables.
   boundaries.txt: the six words returned by the test stub's boundaries (),
   in its order; verified here and read by the least-N report.
   manifest.json: {"recipe":"arithmetic.py.txt:last_pass_r3",
     "recipe_sha256":"...", "certification":"nonempty citation/ranges",
     "exp_glibc_count":N, "log_glibc_count":M}, counts from that pinned draw.
   The advisor supplies these missing artifacts. Missing/empty certification,
   incomplete million-argument files, or missing mis-roundings FAIL, not skip.

   OUTPUT is the complete ordered result transcript, used by tests/x4-hosts.sh
   for two actual hosts and the -FMA launch. Least deciding N counts are printed
   separately by fixtures/x4-counts.lean, from X4's fixed formulas, no stats API.
   No order/value-order test, precision ladder, or lower-bound fallback remains. *)

open Events_support
module O = X4_oracle

external offset_q
  :  string * string
  -> int
  -> int
  -> int
  -> string * string
  = "mm2_test_mpfr_offset"

let program =
  {|{"version":2,"tick":1,"decide_every":1,"leverage":1,"sources":[{"name":"vol","unit":"1"}],"params":[],"let":[],"slots":[],"probes":[{"name":"exp","is":{"op":"exp","args":[{"input":"vol"}]}},{"name":"log","is":{"op":"log","args":[{"input":"vol"}]}}]}|}
;;

let bits text = Int64.of_string ("0x" ^ text)
let finite b = Int64.logand b 0x7FF0000000000000L <> 0x7FF0000000000000L
let show b = Printf.sprintf "%016Lx" b

let read_bits path =
  List.map
    (fun text ->
       check "argument must be a binary64 hex word" (String.length text = 16);
       bits text)
    (lines (read path))
;;

let nearest () =
  let state = Random.State.make [| 5; 6; 17 |] in
  let checked = ref 0 in
  let compare ((n, d) as q) =
    let expected = O.round q in
    let got = Mm2_lean.Exact.nearest_bits q in
    if got <> expected
    then
      failwith
        (Printf.sprintf "nearestBits %s/%s: %s <> %s" n d (show got) (show expected));
    incr checked
  in
  let both ((n, d) as q) =
    compare q;
    compare ("-" ^ n, d)
  in
  let epsilons = [ 1, 1, -1200; -1, 1, -1200; 1, 3, -1100; -1, 3, -1100 ] in
  let both_with_eps q =
    both q;
    List.iter (fun (num, den, exp2) -> both (offset_q q num den exp2)) epsilons
  in
  compare ("0", "1");
  for e = -1100 to 1024 do
    for _sample = 1 to 8 do
      both (O.rational 0 e (Random.State.int64 state Int64.max_int))
    done;
    for _sample = 1 to 2 do
      both (O.rational 5 e (Random.State.int64 state Int64.max_int))
    done
  done;
  for e = -1022 to 1023 do
    let r = Random.State.int64 state Int64.max_int in
    let even_r = Int64.logand r (Int64.lognot 1L) in
    let odd_r = Int64.logor r 1L in
    both_with_eps (O.rational 1 e even_r);
    both_with_eps (O.rational 1 e odd_r)
  done;
  List.iter
    (fun e ->
       let q = O.rational 1 e (Random.State.int64 state Int64.max_int) in
       List.iter (fun s -> both (offset_q q s 3 (e - 80))) [ -1; 1 ])
    [ -1022; -500; -53; 0; 1; 53; 500; 1023 ];
  let subnormal_edges =
    [ 0L; 1L; 2L; 3L; 4L; 5L; 0x000FFFFFFFFFFFFDL; 0x000FFFFFFFFFFFFEL ]
  in
  let subnormal_randoms =
    List.init 28 (fun _ ->
      let r = Int64.logand (Random.State.int64 state Int64.max_int) 0x000FFFFFFFFFFFFFL in
      [ Int64.logand r (Int64.lognot 1L); Int64.logor r 1L ])
    |> List.concat
  in
  List.iter
    (fun n -> both_with_eps (O.rational 2 0 n))
    (subnormal_edges @ subnormal_randoms);
  both_with_eps (O.rational 3 0 0L);
  let zero_min_subnormal = offset_q ("0", "1") 1 1 (-1075) in
  let neg_zero_min_subnormal = "-" ^ fst zero_min_subnormal, snd zero_min_subnormal in
  both_with_eps zero_min_subnormal;
  check
    "zero/min-subnormal +2^-1075 rounds to +0"
    (Mm2_lean.Exact.nearest_bits zero_min_subnormal = 0L);
  check
    "zero/min-subnormal -2^-1075 rounds to -0"
    (Mm2_lean.Exact.nearest_bits neg_zero_min_subnormal = Int64.min_int);
  List.iter
    (fun (num, den, exp2) ->
       check
         "-(2^-1075 - eps) rounds to -0"
         (Mm2_lean.Exact.nearest_bits (offset_q neg_zero_min_subnormal num den exp2)
          = Int64.min_int);
       check
         "-(2^-1075 + eps) rounds to -2^-1074"
         (Mm2_lean.Exact.nearest_bits (offset_q neg_zero_min_subnormal (-num) den exp2)
          = 0x8000000000000001L))
    [ 1, 1, -1200; 1, 3, -1100 ];
  List.iter (fun side -> both (O.rational 4 side 0L)) [ -1; 0; 1 ];
  let overflow_mid = O.rational 4 0 0L in
  let neg_overflow_mid = "-" ^ fst overflow_mid, snd overflow_mid in
  both_with_eps overflow_mid;
  check
    "+(2 - 2^-53)*2^1023 rounds to +inf"
    (Mm2_lean.Exact.nearest_bits overflow_mid = 0x7FF0000000000000L);
  check
    "-(2 - 2^-53)*2^1023 rounds to -inf"
    (Mm2_lean.Exact.nearest_bits neg_overflow_mid = 0xFFF0000000000000L);
  List.iter
    (fun (num, den, exp2) ->
       check
         "+overflow_mid + eps -> +inf"
         (Mm2_lean.Exact.nearest_bits (offset_q overflow_mid num den exp2)
          = 0x7FF0000000000000L);
       check
         "+overflow_mid - eps -> +DBL_MAX"
         (Mm2_lean.Exact.nearest_bits (offset_q overflow_mid (-num) den exp2)
          = 0x7FEFFFFFFFFFFFFFL);
       check
         "-overflow_mid - eps -> -inf"
         (Mm2_lean.Exact.nearest_bits (offset_q neg_overflow_mid (-num) den exp2)
          = 0xFFF0000000000000L);
       check
         "-overflow_mid + eps -> -DBL_MAX"
         (Mm2_lean.Exact.nearest_bits (offset_q neg_overflow_mid num den exp2)
          = 0xFFEFFFFFFFFFFFFFL))
    [ 1, 1, -1200; 1, 3, -1100 ];
  let n, d = O.rational 0 (-1100) 0L in
  check
    "negative nonzero underflow is -0, not +0"
    (Mm2_lean.Exact.nearest_bits ("-" ^ n, d) = Int64.min_int);
  let wn, wd = O.rational 5 (-1100) (Random.State.int64 state Int64.max_int) in
  check
    "negative wide-denominator underflow is -0, not +0"
    (Mm2_lean.Exact.nearest_bits ("-" ^ wn, wd) = Int64.min_int);
  Printf.printf
    "nearestBits: %d MPFR comparisons (both signs, binades, wide denoms, ties+/-eps, \
     overflow)\n\
     %!"
    !checked
;;

let observed text = if text = "-" then None else Some (bits text)

let expected op argument =
  let b = O.eval op argument in
  if finite b then Some b else None
;;

let run_batch output arguments =
  let count = List.length arguments in
  let market = header ~last:(at ((1000 * (count - 1)) + 1)) () in
  let state = get (M.start program market) in
  let events =
    List.mapi (fun i b -> observation (at (1000 * i)) (Int64.float_of_bits b)) arguments
  in
  let state, early = M.feed state (chunk events) in
  let last, summary = M.finish state in
  success (json summary);
  let ticks =
    List.filter_map
      (fun line ->
         match String.split_on_char '\t' line with
         | [ "tick"; time; "A"; _; _; _; exp; log ] ->
           Some (Int64.of_string time, observed exp, observed log)
         | _ -> None)
      (lines (early.trace ^ last.trace))
  in
  check "exactly one tick per argument" (List.length ticks = count);
  List.iteri
    (fun i (argument, (time, exp, log)) ->
       check "scheduled argument tick" (time = at (1000 * i));
       List.iter
         (fun (op, got) ->
            let wanted = expected op argument in
            check "no finite-domain result is X4's cap NaN" (got = wanted);
            Printf.fprintf
              output
              "%d\t%s\t%s\n"
              op
              (show argument)
              (match got with
               | None -> "-"
               | Some b -> show b))
         [ 0, exp; 1, log ])
    (List.combine arguments ticks)
;;

let batches output arguments =
  let rec loop pending n rest =
    match rest with
    | [] -> if pending <> [] then run_batch output (List.rev pending)
    | x :: xs ->
      if n = 256
      then (
        run_batch output (List.rev pending);
        loop [ x ] 1 xs)
      else loop (x :: pending) (n + 1) xs
  in
  loop [] 0 arguments
;;

let () =
  let dir, output =
    match Array.to_list Sys.argv with
    | [ _; dir; output ] -> dir, output
    | _ -> failwith "usage: x4_local.exe INPUT_DIR OUTPUT"
  in
  let status =
    Sys.command ("cd " ^ Filename.quote dir ^ " && sha256sum -c --quiet SHA256SUMS")
  in
  check "test-12 input hashes" (status = 0);
  let checksums = lines (read (Filename.concat dir "SHA256SUMS")) in
  List.iter
    (fun file ->
       check
         ("input is not hash-covered: " ^ file)
         (List.exists (fun line -> Filename.check_suffix line ("  " ^ file)) checksums))
    [ "manifest.json"
    ; "exp-draws.txt"
    ; "log-draws.txt"
    ; "exp-glibc.txt"
    ; "log-glibc.txt"
    ; "hardest.txt"
    ; "boundaries.txt"
    ];
  let manifest = json (read (Filename.concat dir "manifest.json")) in
  check
    "the prescribed draw recipe"
    (text_field "recipe" manifest = "arithmetic.py.txt:last_pass_r3");
  check "recipe is pinned" (String.length (text_field "recipe_sha256" manifest) = 64);
  check
    "hardest arguments need advisor certification"
    (text_field "certification" manifest <> "");
  O.selfcheck ();
  nearest ();
  let draws op =
    let name = if op = 0 then "exp" else "log" in
    let values = read_bits (Filename.concat dir (name ^ "-draws.txt")) in
    check
      "a million finite arguments of each function"
      (List.length values = 1_000_000 && List.for_all finite values);
    let listed = read_bits (Filename.concat dir (name ^ "-glibc.txt")) in
    check
      "complete pinned glibc mismatch list"
      (List.length listed = int_field (name ^ "_glibc_count") manifest);
    let actual =
      List.length
        (List.filter
           (fun b ->
              let x = Int64.float_of_bits b in
              let glibc = Int64.bits_of_float (if op = 0 then exp x else log x) in
              let mpfr = O.eval op b in
              finite glibc && finite mpfr && glibc <> mpfr)
           values)
    in
    Printf.eprintf "%s: this host's glibc differs from MPFR at %d draws\n%!" name actual;
    values @ listed
  in
  let hardest =
    List.map
      (fun line ->
         match String.split_on_char ' ' line with
         | [ ("exp" | "log"); word ] -> bits word
         | _ -> failwith "hardest.txt: expected exp/log and binary64 hex")
      (lines (read (Filename.concat dir "hardest.txt")))
  in
  check "certified hardest arguments are not empty" (hardest <> []);
  let specials =
    [ 0L
    ; Int64.min_int
    ; 0x3FF0000000000000L
    ; 0x4000000000000000L
    ; 0x7FF0000000000000L
    ; 0xFFF0000000000000L
    ; 0x7FF8000000000000L
    ; 0x7FF0000000000001L
    ; 0xFFF8000000000001L
    ; 0xBFF0000000000000L
    ; Int64.bits_of_float 710.
    ; Int64.bits_of_float (-746.)
    ; Int64.bits_of_float (-744.)
    ]
  in
  check "MPFR exp zero exactly one" (O.eval 0 0L = 0x3FF0000000000000L);
  check "MPFR log one exactly zero" (O.eval 1 0x3FF0000000000000L = 0L);
  let boundaries = read_bits (Filename.concat dir "boundaries.txt") in
  check
    "the six boundary neighbours are MPFR's"
    (boundaries = Array.to_list (O.boundaries ()));
  let arguments = draws 0 @ draws 1 @ hardest @ boundaries @ specials in
  let channel = open_out_bin output in
  Fun.protect ~finally:(fun () -> close_out channel) (fun () -> batches channel arguments);
  Printf.printf
    "X4: %d arguments, both declared-source probes equal MPFR\n%!"
    (List.length arguments)
;;
