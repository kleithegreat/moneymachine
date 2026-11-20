(* Brief 3 step 5 test 12. LOCAL;
   invocation: x4_local.exe INPUT_DIR INPUTS_SHA256 OUTPUT.
   Builder supplies ONLY the existing Mm2_lean.Machine.start/feed/finish and
   A18 chunks (events_support.ml), and Mm2_lean.Exact.nearest_bits :
   (string * string) -> int64. exp/log are tested as declared-source probes,
   not through new engine exports. Non-finite probe results collapse to "-"
   in A19 traces; exact raw 64-bit non-finite results (+inf, -inf, canonical NaN)
   of Engine.Exact.exp/log are verified directly without None collapse by
   fixtures/x4-specials.lean and fixtures/x4-counts.lean.
   MPFR/GMP are test-only inputs from pinned nixpkgs (x4_mpfr_stubs.c).

   INPUT_DIR contract (externally root-pinned by INPUTS_SHA256, never self-attesting):
     INPUTS_SHA256 is the 64-char lowercase hex SHA-256 of INPUT_DIR/SHA256SUMS.
     SHA256SUMS must parse strictly as `<64-hex>  <exact-basename>` (two ASCII
     spaces, LF-terminated, no slashes/duplicates) covering all and only 7 files:
       1. manifest.json: JSON object with required keys:
          - "recipe": "arithmetic.py.txt:emit_x4_draws"
          - "recipe_sha256": "5e6c95e92a71c908e4232346aca294ca259d36c53ce62d09e12c155f3d2d953b"
            (SHA-256 of the pinned emit_x4_draws script)
          - "certification": nonempty citation referencing CORE-MATH, a pinned
            40-char hex commit, exp.wc and log.wc, and honest scope/limits
            (empirical TMD test corpus, not a mechanized exhaustiveness proof)
          - "glibc_version": nonempty string naming the pinned nixpkgs glibc
            version/derivation and containing gnu_get_libc_version ()
          - "glibc_tunables": nonempty GLIBC_TUNABLES string (e.g.
            "glibc.cpu.hwcaps=-FMA,-AVX,-AVX2,-AVX512F") or nonempty JSON array
            of GLIBC_TUNABLES strings with at least one explicit tunable path
          - "exp_hardest_count": integer > 0, exact count of `exp ` lines in hardest.txt
          - "log_hardest_count": integer > 0, exact count of `log ` lines in hardest.txt
          - "exp_glibc_count": integer > 0, exact count of lines in exp-glibc.txt
          - "log_glibc_count": integer >= 0, exact count of lines in log-glibc.txt
       2. exp-draws.txt: 1,000,000 LF-terminated 16-char lowercase hex binary64 words
          from arithmetic.py.txt:emit_x4_draws (random.Random(5)), all finite,
          SHA-256 0efb48018ff7d89206d2704c130a40afe4c6b5e5d73d490bdeee532d7e1ddb30.
       3. log-draws.txt: 1,000,000 LF-terminated 16-char lowercase hex binary64 words
          from arithmetic.py.txt:emit_x4_draws (random.Random(5)), all finite > 0,
          SHA-256 1dc9dc5176e96db25e2b44dac1f870cadb41a9b8fe054a55a1deafb082a4cb66.
       4. exp-glibc.txt: exp_glibc_count (> 0) distinct finite 16-char lowercase hex
          lines from exp-draws.txt covering every glibc-vs-MPFR mis-rounding.
       5. log-glibc.txt: log_glibc_count (>= 0) distinct finite 16-char lowercase hex
          lines from log-draws.txt covering every glibc-vs-MPFR mis-rounding.
       6. hardest.txt: LF-terminated lines matching `^(exp|log) [0-9a-f]{16}$`
          (no comments, blank lines, or C hexfloats), advisor-certified from
          CORE-MATH exp.wc and log.wc, with exp_hardest_count > 0 and log_hardest_count > 0.
       7. boundaries.txt: 6 LF-terminated 16-char lowercase hex lines matching
          mm2_test_mpfr_boundaries () in exact order.
   Missing/unpinned hashes, invalid formats, degenerate draws, or missing
   mis-roundings FAIL, never skip.

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

external runtime_glibc_version : unit -> string = "mm2_test_glibc_version"

let program =
  {|{"version":2,"tick":1,"decide_every":1,"leverage":1,"sources":[{"name":"vol","unit":"1"}],"params":[],"let":[],"slots":[],"probes":[{"name":"exp","is":{"op":"exp","args":[{"input":"vol"}]}},{"name":"log","is":{"op":"log","args":[{"input":"vol"}]}}]}|}
;;

let pinned_recipe_sha256 =
  "5e6c95e92a71c908e4232346aca294ca259d36c53ce62d09e12c155f3d2d953b"
;;

let pinned_exp_draws_sha256 =
  "0efb48018ff7d89206d2704c130a40afe4c6b5e5d73d490bdeee532d7e1ddb30"
;;

let pinned_log_draws_sha256 =
  "1dc9dc5176e96db25e2b44dac1f870cadb41a9b8fe054a55a1deafb082a4cb66"
;;

let is_lower_hex_char c = ('0' <= c && c <= '9') || ('a' <= c && c <= 'f')
let is_hex_n n s = String.length s = n && String.for_all is_lower_hex_char s
let bits text = Int64.of_string ("0x" ^ text)
let finite b = Int64.logand b 0x7FF0000000000000L <> 0x7FF0000000000000L
let show b = Printf.sprintf "%016Lx" b

let strict_lines text =
  check "file must not contain CR" (not (String.contains text '\r'));
  if text = ""
  then []
  else (
    let len = String.length text in
    check "non-empty file must end with LF" (text.[len - 1] = '\n');
    let body = String.split_on_char '\n' (String.sub text 0 (len - 1)) in
    check "file must not contain blank lines" (List.for_all (fun s -> s <> "") body);
    body)
;;

let sha256_of path =
  let status, out = command "sha256sum" [ "--"; path ] in
  check ("sha256sum failed on " ^ path) (status = Unix.WEXITED 0);
  let digest = List.hd (String.split_on_char ' ' (String.trim out)) in
  check ("invalid sha256sum output for " ^ path) (is_hex_n 64 digest);
  digest
;;

let contains_ci haystack needle =
  let h = String.lowercase_ascii haystack in
  let n = String.lowercase_ascii needle in
  let hlen = String.length h in
  let nlen = String.length n in
  if nlen = 0
  then true
  else if nlen > hlen
  then false
  else (
    let rec loop i =
      if i + nlen > hlen
      then false
      else if String.sub h i nlen = n
      then true
      else loop (i + 1)
    in
    loop 0)
;;

let has_hex_token_n n s =
  let len = String.length s in
  let rec scan i run =
    if i = len
    then run = n
    else if is_lower_hex_char s.[i]
    then scan (i + 1) (run + 1)
    else run = n || scan (i + 1) 0
  in
  scan 0 0
;;

let distinct_count xs =
  let tbl = Hashtbl.create (List.length xs) in
  List.iter (fun x -> Hashtbl.replace tbl x ()) xs;
  Hashtbl.length tbl
;;

let verify_checksums dir inputs_sha =
  check "INPUTS_SHA256 must be 64 lowercase hex" (is_hex_n 64 inputs_sha);
  let sums_path = Filename.concat dir "SHA256SUMS" in
  check
    "INPUT_DIR/SHA256SUMS differs from root-pinned INPUTS_SHA256"
    (sha256_of sums_path = inputs_sha);
  let entries =
    List.map
      (fun line ->
         let len = String.length line in
         check "SHA256SUMS line format: <64-hex>  <basename>" (len >= 67);
         let digest = String.sub line 0 64 in
         let sep = String.sub line 64 2 in
         let name = String.sub line 66 (len - 66) in
         check "SHA256SUMS digest must be 64 lowercase hex" (is_hex_n 64 digest);
         check "SHA256SUMS separator must be two ASCII spaces" (sep = "  ");
         check
           ("SHA256SUMS invalid basename: " ^ name)
           (name <> ""
            && name <> "."
            && name <> ".."
            && (not (String.contains name '/'))
            && (not (String.contains name ' '))
            && not (String.contains name '\t'));
         name)
      (strict_lines (read sums_path))
  in
  let required =
    [ "boundaries.txt"
    ; "exp-draws.txt"
    ; "exp-glibc.txt"
    ; "hardest.txt"
    ; "log-draws.txt"
    ; "log-glibc.txt"
    ; "manifest.json"
    ]
  in
  check
    "SHA256SUMS must cover all and only the 7 input files without duplicates"
    (List.sort String.compare entries = required);
  let status =
    Sys.command ("cd " ^ Filename.quote dir ^ " && sha256sum -c --quiet SHA256SUMS")
  in
  check "test-12 input hashes" (status = 0)
;;

let read_bits path =
  List.map
    (fun text ->
       check "argument must be 16 lowercase hex chars" (is_hex_n 16 text);
       bits text)
    (strict_lines (read path))
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
            (match wanted with
             | Some b ->
               check
                 "finite probe result must equal MPFR bit-for-bit (never cap NaN)"
                 (got = Some b)
             | None ->
               check
                 "non-finite probe result must be undefined (raw 64-bit bits checked by \
                  x4-specials/x4-counts)"
                 (got = None));
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

let self_executable () =
  if Sys.file_exists "/proc/self/exe"
  then Unix.realpath "/proc/self/exe"
  else Sys.executable_name
;;

let parse_pinned_tunables manifest =
  let list =
    match field "glibc_tunables" manifest with
    | `String s ->
      check "glibc_tunables string must be non-empty" (s <> "");
      [ s ]
    | `List items ->
      check "glibc_tunables array must be non-empty" (items <> []);
      let strs = List.map Yojson.Basic.Util.to_string items in
      check
        "glibc_tunables array must include at least one non-empty tunable path"
        (List.exists (fun s -> s <> "") strs);
      check
        "glibc_tunables array must not contain duplicates"
        (distinct_count strs = List.length strs);
      strs
    | _ -> failwith "manifest.json: glibc_tunables must be a string or string list"
  in
  list
;;

let host_glibc_scan op values =
  with_file ".glibc.bin" (fun tmp ->
    let ch = open_out_bin tmp in
    let actual = ref 0 in
    let buf = Bytes.create 8 in
    Fun.protect
      ~finally:(fun () -> close_out_noerr ch)
      (fun () ->
         List.iter
           (fun b ->
              let x = Int64.float_of_bits b in
              let glibc = Int64.bits_of_float (if op = 0 then exp x else log x) in
              Bytes.set_int64_le buf 0 glibc;
              output ch buf 0 8;
              let mpfr = O.eval op b in
              if finite glibc && finite mpfr && glibc <> mpfr then incr actual)
           values);
    !actual, sha256_of tmp)
;;

let check_glibc_path_mode op draws_path listed_path =
  let values = read_bits draws_path in
  let listed = read_bits listed_path in
  let tbl = Hashtbl.create (List.length listed + 1) in
  List.iter (fun b -> Hashtbl.replace tbl b ()) listed;
  List.iter
    (fun b ->
       let x = Int64.float_of_bits b in
       let glibc = Int64.bits_of_float (if op = 0 then exp x else log x) in
       let mpfr = O.eval op b in
       if finite glibc && finite mpfr && glibc <> mpfr && not (Hashtbl.mem tbl b)
       then
         failwith
           (Printf.sprintf
              "%s: host-observed glibc mis-rounding %s missing from %s"
              (if op = 0 then "exp" else "log")
              (show b)
              listed_path))
    values
;;

let run_glibc_path_check tunable op draws_path listed_path =
  let base_env =
    Array.to_list (Unix.environment ())
    |> List.filter (fun kv -> not (String.starts_with ~prefix:"GLIBC_TUNABLES=" kv))
  in
  let env =
    if tunable = ""
    then Array.of_list base_env
    else Array.of_list (("GLIBC_TUNABLES=" ^ tunable) :: base_env)
  in
  let exe = self_executable () in
  let argv = [| exe; "--check-glibc-path"; string_of_int op; draws_path; listed_path |] in
  let pid = Unix.create_process_env exe argv env Unix.stdin Unix.stdout Unix.stderr in
  let _, status = Unix.waitpid [] pid in
  check
    (Printf.sprintf
       "glibc mismatch check failed under GLIBC_TUNABLES=%S for %s"
       tunable
       listed_path)
    (status = Unix.WEXITED 0)
;;

let () =
  match Array.to_list Sys.argv with
  | [ _; "--check-glibc-path"; op_s; draws_path; listed_path ] ->
    let op = int_of_string op_s in
    check "op must be 0 or 1" (op = 0 || op = 1);
    check_glibc_path_mode op draws_path listed_path
  | _ ->
    let dir, inputs_sha, output =
      match Array.to_list Sys.argv with
      | [ _; dir; inputs_sha; output ] -> dir, inputs_sha, output
      | _ -> failwith "usage: x4_local.exe INPUT_DIR INPUTS_SHA256 OUTPUT"
    in
    verify_checksums dir inputs_sha;
    let manifest = json (read (Filename.concat dir "manifest.json")) in
    check
      "the prescribed draw recipe"
      (text_field "recipe" manifest = "arithmetic.py.txt:emit_x4_draws");
    check
      "recipe_sha256 must match pinned arithmetic.py.txt:emit_x4_draws"
      (text_field "recipe_sha256" manifest = pinned_recipe_sha256);
    let cert = text_field "certification" manifest in
    check
      "certification must cite CORE-MATH commit, exp.wc/log.wc, and honest scope/limits"
      (String.length cert >= 80
       && contains_ci cert "core-math"
       && contains_ci cert "exp.wc"
       && contains_ci cert "log.wc"
       && has_hex_token_n 40 cert
       && (contains_ci cert "not a "
           || contains_ci cert "empirical"
           || contains_ci cert "uncertified"
           || contains_ci cert "beyond"));
    let glibc_ver = text_field "glibc_version" manifest in
    let runtime_ver = runtime_glibc_version () in
    check
      ("glibc_version must be non-empty and match runtime glibc " ^ runtime_ver)
      (glibc_ver <> "" && contains_ci glibc_ver runtime_ver);
    let pinned_tunables = parse_pinned_tunables manifest in
    O.selfcheck ();
    nearest ();
    let exp_spot_checks =
      [ 0, 0x406581FEF5567DF4L
      ; 1, 0x4070AA02646EDC5AL
      ; 2, 0x40827A0A3AFE0E48L
      ; 17, 0xC05DC85BCFBD4AD0L
      ; 199999, 0x404D215BFD6798F0L
      ; 200000, 0xC079B6512C22AD0FL
      ; 500000, 0xC07DBCC53E55D6FAL
      ; 999999, 0x40833C6185D818AEL
      ]
    in
    let log_spot_checks =
      [ 0, 0x678BDE5C08B791F7L
      ; 1, 0x553D76D4337AD3FCL
      ; 2, 0x3D5076CE2FAE421CL
      ; 17, 0x238EF901B84A9970L
      ; 199999, 0x7832F88153C80339L
      ; 200000, 0x0F3C8BBA4500E873L
      ; 500000, 0x26A85BB362371334L
      ; 999999, 0x13E60820ADE249C0L
      ]
    in
    let draws op =
      let name = if op = 0 then "exp" else "log" in
      let draws_path = Filename.concat dir (name ^ "-draws.txt") in
      let expected_sha =
        if op = 0 then pinned_exp_draws_sha256 else pinned_log_draws_sha256
      in
      check
        (name ^ "-draws.txt sha256 must match pinned emit_x4_draws")
        (sha256_of draws_path = expected_sha);
      let values = read_bits draws_path in
      check
        "a million finite arguments of each function"
        (List.length values = 1_000_000 && List.for_all finite values);
      check (name ^ "-draws.txt must not be degenerate") (distinct_count values > 999_000);
      if op = 0
      then
        check
          "exp draws must include negative and non-negative arguments in [-700, 700)"
          (List.for_all
             (fun b ->
                let x = Int64.float_of_bits b in
                x >= -700.0 && x < 700.0)
             values
           && List.exists (fun b -> Int64.float_of_bits b < 0.0) values
           && List.exists (fun b -> Int64.float_of_bits b >= 0.0) values)
      else
        check
          "log draws must be strictly positive"
          (List.for_all (fun b -> Int64.float_of_bits b > 0.0) values);
      let arr = Array.of_list values in
      let spots = if op = 0 then exp_spot_checks else log_spot_checks in
      List.iter
        (fun (idx, expected) ->
           check
             (Printf.sprintf "%s-draws.txt random.Random(5) spot check at %d" name idx)
             (arr.(idx) = expected))
        spots;
      let listed_path = Filename.concat dir (name ^ "-glibc.txt") in
      let listed = read_bits listed_path in
      let want_count = int_field (name ^ "_glibc_count") manifest in
      check "complete pinned glibc mismatch list" (List.length listed = want_count);
      if op = 0 then check "exp_glibc_count must be positive" (want_count > 0);
      check (name ^ "-glibc.txt entries must be finite") (List.for_all finite listed);
      check
        (name ^ "-glibc.txt entries must be distinct")
        (distinct_count listed = List.length listed);
      let values_tbl = Hashtbl.create 1_000_000 in
      List.iter (fun b -> Hashtbl.replace values_tbl b ()) values;
      check
        (name ^ "-glibc.txt must be a subset of " ^ name ^ "-draws.txt")
        (List.for_all (fun b -> Hashtbl.mem values_tbl b) listed);
      List.iter
        (fun tunable -> run_glibc_path_check tunable op draws_path listed_path)
        pinned_tunables;
      let actual, glibc_sha = host_glibc_scan op values in
      Printf.eprintf
        "%s: this host's glibc differs from MPFR at %d draws (glibc_sha256=%s)\n%!"
        name
        actual
        glibc_sha;
      values @ listed
    in
    let exp_hardest_n = ref 0 in
    let log_hardest_n = ref 0 in
    let exp_hardest_finite = ref false in
    let log_hardest_finite = ref false in
    let hardest =
      List.map
        (fun line ->
           match String.split_on_char ' ' line with
           | [ "exp"; word ] when is_hex_n 16 word ->
             let b = bits word in
             incr exp_hardest_n;
             if finite b then exp_hardest_finite := true;
             b
           | [ "log"; word ] when is_hex_n 16 word ->
             let b = bits word in
             incr log_hardest_n;
             if finite b then log_hardest_finite := true;
             b
           | _ -> failwith "hardest.txt: expected ^(exp|log) [0-9a-f]{16}$")
        (strict_lines (read (Filename.concat dir "hardest.txt")))
    in
    let want_exp_hardest = int_field "exp_hardest_count" manifest in
    let want_log_hardest = int_field "log_hardest_count" manifest in
    check
      "hardest.txt must have positive pinned exp and log counts"
      (want_exp_hardest > 0
       && want_log_hardest > 0
       && !exp_hardest_n = want_exp_hardest
       && !log_hardest_n = want_log_hardest
       && !exp_hardest_finite
       && !log_hardest_finite);
    let specials =
      let subnormal_binades =
        List.init 52 (fun k -> Int64.shift_left 1L k)
        @ [ 0x0000000000000003L
          ; 0x00000000000000FFL
          ; 0x000123456789ABCDL
          ; 0x0008000000000001L
          ; 0x000FFFFFFFFFFFFEL
          ; 0x000FFFFFFFFFFFFFL
          ; 0x8000000000000001L
          ; 0x800FFFFFFFFFFFFFL
          ]
      in
      let high_binades =
        List.init 29 (fun i ->
          let biased = Int64.shift_left (Int64.of_int (1023 + 995 + i)) 52 in
          [ biased; Int64.logor biased 0x000A55A55A55A55AL ])
        |> List.concat
      in
      [ 0L
      ; Int64.min_int
      ; 0x3FF0000000000000L
      ; 0x4000000000000000L
      ; 0x7FF0000000000000L
      ; 0xFFF0000000000000L
      ; 0x7FF8000000000000L
      ; 0x7FF0000000000001L
      ; 0xFFF0000000000001L
      ; 0xFFF8000000000001L
      ; 0xBFF0000000000000L
      ; 0x0010000000000000L
      ; 0x8010000000000000L
      ; 0x7FEFFFFFFFFFFFFFL
      ; 0xFFEFFFFFFFFFFFFFL
      ; 0x3FEFFFFFFFFFFFFEL
      ; 0x3FEFFFFFFFFFFFFFL
      ; 0x3FF0000000000001L
      ; 0x3FE7FFFFFFFFFFFFL
      ; 0x3FE8000000000000L
      ; 0x3FF7FFFFFFFFFFFFL
      ; 0x3FF8000000000000L
      ; 0x3C90000000000000L
      ; 0xBC90000000000000L
      ; 0x3CA0000000000000L
      ; 0xBCA0000000000000L
      ; 0x40862E42FEFA39F1L
      ; 0x40862F0000000000L
      ; 0x40862FC000000000L
      ; 0x40862FFFFFFFFFFFL
      ; 0xC0874FFFFFFFFFFFL
      ; 0xC0874910D52D3053L
      ; 0xC0874910D52D3050L
      ; 0xC086232BDD7ABCD4L
      ; Int64.bits_of_float 710.
      ; Int64.bits_of_float (-746.)
      ; Int64.bits_of_float (-745.13)
      ; Int64.bits_of_float (-745.)
      ; Int64.bits_of_float (-744.5)
      ; Int64.bits_of_float (-744.)
      ; Int64.bits_of_float (-743.)
      ; Int64.bits_of_float (-738.75)
      ; Int64.bits_of_float (-732.25)
      ; Int64.bits_of_float (-725.)
      ; Int64.bits_of_float (-718.5)
      ; Int64.bits_of_float (-712.)
      ; Int64.bits_of_float (-709.)
      ; Int64.bits_of_float (-708.5)
      ; Int64.bits_of_float (-708.4)
      ]
      @ subnormal_binades
      @ high_binades
    in
    check "MPFR exp zero exactly one" (O.eval 0 0L = 0x3FF0000000000000L);
    check "MPFR log one exactly zero" (O.eval 1 0x3FF0000000000000L = 0L);
    let is_nan_bits b =
      Int64.logand b 0x7FF0000000000000L = 0x7FF0000000000000L
      && Int64.logand b 0x000FFFFFFFFFFFFFL <> 0L
    in
    let boundaries = read_bits (Filename.concat dir "boundaries.txt") in
    check
      "the six boundary neighbours are MPFR's"
      (boundaries = Array.to_list (O.boundaries ()));
    check
      "MPFR boundary[1] overflows to +inf"
      (O.eval 0 (List.nth boundaries 1) = 0x7FF0000000000000L);
    check
      "MPFR exp(+inf) = +inf, log(+-0) = -inf, log(-1) = NaN"
      (O.eval 0 0x7FF0000000000000L = 0x7FF0000000000000L
       && O.eval 1 0L = 0xFFF0000000000000L
       && O.eval 1 Int64.min_int = 0xFFF0000000000000L
       && is_nan_bits (O.eval 1 0xBFF0000000000000L));
    let arguments = draws 0 @ draws 1 @ hardest @ boundaries @ specials in
    let channel = open_out_bin output in
    Fun.protect
      ~finally:(fun () -> close_out channel)
      (fun () -> batches channel arguments);
    Printf.printf
      "X4: %d arguments, both declared-source probes equal MPFR\n%!"
      (List.length arguments)
;;
