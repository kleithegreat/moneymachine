(* Step 1 assumed implementation interface, library mm2_lean:

   module Mm2_lean.Exact:
     type rat = string * string
     val mul : rat -> rat -> rat
     val nearest_bits : rat -> int64
     val read_bits : int -> int64 -> string option
     val put_placed : int -> (string * int) -> (string, string) result
     val round_down : rat -> rat -> rat
     val round_up : rat -> rat -> rat
     val round_size : rat -> rat -> rat
     val grid_step : int -> int -> rat -> rat
     val on_grid : int -> int -> rat -> bool
     val round_price_buy : int -> int -> rat -> rat
     val round_price_sell : int -> int -> rat -> rat
   module Mm2_lean.Decimal:
     val place : string -> ((string * int), string) result

   rat is a reduced numerator and positive denominator, both decimal integers.
   Exact calls Lean through the C stub, with no OCaml/C arithmetic substitute:
     Engine.Exact.nearestBits : Rat -> UInt64
     Engine.Exact.readBits : Nat -> UInt64 -> Option Int
     Engine.Exact.putPlaced : Nat -> Int -> Nat -> Except String Int
     Engine.Exact.roundDown, roundUp, roundSize : Rat -> Rat -> Rat
     Engine.Exact.gridStep : Nat -> Int -> Rat -> Rat
     Engine.Exact.onGrid : Nat -> Int -> Rat -> Bool
     Engine.Exact.roundPriceBuy, roundPriceSell : Nat -> Int -> Rat -> Rat
   mul is Lean Rat multiplication. Rounders take value then positive step.
   Grid functions take figures, decimal places, then price. Negative decimal
   places cover arithmetic.py.txt's fixtures, not an extra admitted market rule.
   Bits cross unchanged, including NaNs and negative zero. Scaled integers
   return as canonical decimal strings; put_placed errors are E_DECIMAL.
   Decimal.place places signed digits, removes fractional trailing zeros, and
   receives no scale. The independent oracle below never calls that reader.
   The existing kernel2/tests/flake-lock.sh remains the lock-identity test.

   The tests must show (brief 3, step 1, verbatim):
   1. `10 × 0.9775` is `9.775` and rounds to itself as a buy on a grid of 0.001; `10 × 1.0056` to `10.056` as a sell; `1.93` coins are 193 lots and `0.29` are 29.
   2. For every scale from 0 to 12 and sampled `n` with `|n| < 10¹⁵`, the nearest double of `n · 10⁻ᵈ` reads back as `n`, and agrees with OCaml's `Float.of_string` on the written decimal.
   3. Rejected: `0.1 + 0.2` at every scale from 0 to 12; a NaN; an infinity; `10⁷` at scale 8 (its `n` is `10¹⁵`). Negative zero reads as zero.
   4. A string with more decimals than its scale is rejected by the engine, as is `"100.000000000000001"` at scale 8, which `Float.of_string` would have rounded to 100 (corrected by the advisor, 2026-11-16: the earlier `"100.00000000000001"` rounds to 100 + 2⁻⁴⁶, found by GPT) (Argon's finding 4). `"5.0"` at scale 0 is 5; `"5.01"` at scale 1 is rejected. The reader is given no scale.
   5. A value off the grid by any amount rounds in its direction and by less than one grid step.
   6. **The grid is the certificate's** (`venue/sources.toml`, "Price grid"; `KERNEL.md` A18), and this test is written from its quoted words and counts digits, where A18's step and its law count multiples. At five figures and one decimal: `123456` is on the grid and `12345.6` is not, a buy there rounding to 12,345 and a sell to 12,346; 99,999, 100,000 and 100,001 are on it and 100,000.5 is not, rounding to 100,000 and 100,001; a sell at 99,999.5 rounds to 100,000. For every price of `arithmetic.py.txt`'s `price_grid`, membership by the sentence equals membership by the step, a buy rounds to the greatest grid price at or below it, to zero when there is none, and a sell to the least at or above.
*)

module E = Mm2_lean.Exact
module D = Mm2_lean.Decimal

let check name condition =
  if not condition then failwith ("FAIL: " ^ name)

let expect name actual expected =
  if actual <> expected then failwith ("FAIL: " ^ name)

module Q = struct
  type t = { n : int; d : int }

  let rec gcd a b = if b = 0 then a else gcd b (a mod b)

  let make n d =
    if d = 0 then invalid_arg "zero oracle denominator";
    let n, d = if d < 0 then -n, -d else n, d in
    let g = gcd (abs n) d in
    { n = n / g; d = d / g }

  let integer n = make n 1
  let wire q = string_of_int q.n, string_of_int q.d

  let of_wire (n, d) =
    let q = make (int_of_string n) (int_of_string d) in
    expect "canonical Lean rational" (wire q) (n, d);
    q

  let compare a b = Int.compare (a.n * b.d) (b.n * a.d)
  let le a b = compare a b <= 0
  let lt a b = compare a b < 0
  let add a b = make (a.n * b.d + b.n * a.d) (a.d * b.d)
  let sub a b = make (a.n * b.d - b.n * a.d) (a.d * b.d)
  let mul a b = make (a.n * b.n) (a.d * b.d)
  let div a b = make (a.n * b.d) (a.d * b.n)
  let neg a = { a with n = -a.n }
  let zero = integer 0
  let one = integer 1
end

let expect_q name actual expected = expect name actual (Q.wire expected)

let placed text =
  match D.place text with
  | Ok value -> value
  | Error code -> failwith ("placing " ^ text ^ ": " ^ code)

let decimal scale text =
  match E.put_placed scale (placed text) with
  | Ok value -> value
  | Error code -> failwith ("scaling " ^ text ^ ": " ^ code)

let test_1 () =
  let first = E.mul ("10", "1") ("391", "400") in
  expect_q "10 × 0.9775 = 9.775" first (Q.make 9775 1000);
  expect "buy 9.775 on 0.001 is unchanged"
    (E.round_down first ("1", "1000")) first;
  expect "price-grid buy 9.775 is unchanged"
    (E.round_price_buy 5 3 first) first;
  let exit = E.mul ("10", "1") ("1257", "1250") in
  expect_q "10 × 1.0056 = 10.056" exit (Q.make 10056 1000);
  expect "sell 10.056 on 0.001 is unchanged"
    (E.round_up exit ("1", "1000")) exit;
  expect "price-grid sell 10.056 is unchanged"
    (E.round_price_sell 5 3 exit) exit;
  List.iter
    (fun (text, units) ->
      expect (text ^ " coins as whole lots") (decimal 2 text) units;
      let value = Q.make (int_of_string units) 100 in
      expect_q (text ^ " rounds to itself as a size")
        (E.round_size (Q.wire value) ("1", "100")) value)
    [ "1.93", "193"; "0.29", "29" ]

let pow10 n =
  let rec loop value left = if left = 0 then value else loop (value * 10) (left - 1) in
  loop 1 n

let written_decimal n scale =
  let negative = Int64.compare n 0L < 0 in
  let digits = Int64.to_string (Int64.abs n) in
  let padding = max 0 (scale + 1 - String.length digits) in
  let digits = String.make padding '0' ^ digits in
  let text =
    if scale = 0 then digits
    else
      let split = String.length digits - scale in
      String.sub digits 0 split ^ "." ^ String.sub digits split scale
  in
  if negative then "-" ^ text else text

let sample_integer scale n =
  let text = written_decimal n scale in
  let bits = E.nearest_bits (Int64.to_string n, string_of_int (pow10 scale)) in
  expect ("nearest bits: " ^ text) bits (Int64.bits_of_float (Float.of_string text));
  expect ("decimal readback: " ^ text) (E.read_bits scale bits) (Some (Int64.to_string n))

let test_2 () =
  let random = Random.State.make [| 0x5842; 0xdec; 0x2026 |] in
  for scale = 0 to 12 do
    List.iter (sample_integer scale)
      [ 0L; 1L; -1L; 999999999999999L; -999999999999999L;
        999999999999998L; -999999999999998L ];
    for exponent = 0 to 14 do
      let centre = Int64.of_int (pow10 exponent) in
      List.iter
        (fun offset ->
          let n = Int64.add centre offset in
          sample_integer scale n;
          sample_integer scale (Int64.neg n))
        [ -1L; 0L; 1L ]
    done;
    for _sample = 1 to 1024 do
      let n = Random.State.int64 random 1000000000000000L in
      let n = if Random.State.bool random then n else Int64.neg n in
      sample_integer scale n
    done
  done;
  List.iter
    (fun (value, bits) -> expect "binary64 nearest, ties to even" (E.nearest_bits value) bits)
    [ (("9007199254740993", "9007199254740992"), 0x3ff0000000000000L);
      (("9007199254740995", "9007199254740992"), 0x3ff0000000000002L);
      (("-9007199254740993", "9007199254740992"), 0xbff0000000000000L);
      (("-9007199254740995", "9007199254740992"), 0xbff0000000000002L) ]

let test_3 () =
  let sum = Sys.opaque_identity 0.1 +. Sys.opaque_identity 0.2 in
  let rejected =
    [ Int64.bits_of_float sum; 0x7ff8000000000000L; 0x7ff0000000000001L;
      0xfff8000000000042L; 0x7ff0000000000000L; 0xfff0000000000000L ]
  in
  for scale = 0 to 12 do
    List.iter
      (fun bits -> expect "non-decimal/non-finite input rejected" (E.read_bits scale bits) None)
      rejected;
    expect "negative zero reads as zero"
      (E.read_bits scale Int64.min_int) (Some "0");
    expect "positive zero reads as zero" (E.read_bits scale 0L) (Some "0");
    List.iter
      (fun n ->
        let bits = E.nearest_bits (n, string_of_int (pow10 scale)) in
        expect "exclusive scaled-integer range" (E.read_bits scale bits) None)
      [ "1000000000000000"; "-1000000000000000" ]
  done;
  expect "10^7 at scale 8 rejected"
    (E.read_bits 8 (Int64.bits_of_float 10000000.)) None

let test_4 () =
  List.iter
    (fun (text, expected) -> expect ("placed digits: " ^ text) (placed text) expected)
    [ "5.0", ("5", 0); "5.01", ("501", 2);
       "100.000000000000001", ("100000000000000001", 15);
      "0.0000000000001", ("1", 13); "1.2300", ("123", 2);
      "-0.2900", ("-29", 2); "-0.000", ("0", 0) ];
  expect "5.0 at scale zero" (decimal 0 "5.0") "5";
  expect "trailing zeros do not consume scale" (decimal 2 "1.2300") "123";
  expect "negative placed decimal" (decimal 2 "-0.2900") "-29";
  List.iter
    (fun (scale, text) ->
      expect ("engine rejects excess places: " ^ text)
        (E.put_placed scale (placed text)) (Error "E_DECIMAL"))
     [ 1, "5.01"; 8, "100.000000000000001"; 12, "0.0000000000001" ];
  for scale = 0 to 12 do
    let text = "0." ^ String.make scale '0' ^ "1" in
    expect "engine, not reader, rejects one excess decimal"
      (E.put_placed scale (placed text)) (Error "E_DECIMAL");
    let edge = written_decimal 1000000000000000L scale in
    expect "placed decimal range is exclusive"
      (E.put_placed scale (placed edge)) (Error "E_DECIMAL");
    let negative_edge = "-" ^ edge in
    expect "negative placed decimal range is exclusive"
      (E.put_placed scale (placed negative_edge)) (Error "E_DECIMAL");
    let last = written_decimal 999999999999999L scale in
    expect "last in-range placed decimal" (decimal scale last) "999999999999999"
  done;
   expect "Float.of_string erases excess decimal digits"
     (Float.of_string "100.000000000000001") 100.0;
  expect "a double cannot distinguish the erased digits"
    (E.read_bits 8 (Int64.bits_of_float 100.)) (Some "10000000000")

let uniform_rounding p step =
  let down = Q.of_wire (E.round_down (Q.wire p) (Q.wire step)) in
  let up = Q.of_wire (E.round_up (Q.wire p) (Q.wire step)) in
  let size = Q.of_wire (E.round_size (Q.wire p) (Q.wire step)) in
  List.iter
    (fun rounded -> check "rounded value is a whole step" ((Q.div rounded step).d = 1))
    [ down; up; size ];
  check "buy/down direction" (Q.le down p);
  check "sell/up direction" (Q.le p up);
  check "buy/down strict error bound" (Q.lt (Q.sub p down) step);
  check "sell/up strict error bound" (Q.lt (Q.sub up p) step);
  if p.n >= 0 then begin
    check "positive size does not increase" (Q.le Q.zero size && Q.le size p);
    check "positive size strict error bound" (Q.lt (Q.sub p size) step)
  end else begin
    check "negative size tends to zero" (Q.le p size && Q.le size Q.zero);
    check "negative size strict error bound" (Q.lt (Q.sub size p) step)
  end;
  if (Q.div p step).d = 1 then
    List.iter (fun rounded -> expect "on-step value unchanged" rounded p) [ down; up; size ]
  else begin
    check "off-step buy moves strictly down" (Q.lt down p);
    check "off-step sell moves strictly up" (Q.lt p up)
  end

let test_5 () =
  let steps = [ Q.integer 10; Q.one; Q.make 1 100; Q.make 1 1000 ] in
  List.iter
    (fun step ->
      for k = -20 to 20 do
        let base = Q.mul (Q.integer k) step in
        List.iter
          (fun offset -> uniform_rounding (Q.add base (Q.mul step offset)) step)
          [ Q.zero; Q.make 1 2; Q.make 1 1000000; Q.make 999999 1000000;
            Q.make (-1) 1000000; Q.make (-999999) 1000000 ]
      done)
    steps;
  let denominator = "10000000000000000000000000000000000000000" in
  List.iter
    (fun (p, down, up, size) ->
      expect "infinitesimal buy still moves" (E.round_down p ("1", "1")) down;
      expect "infinitesimal sell still moves" (E.round_up p ("1", "1")) up;
      expect "infinitesimal size still truncates" (E.round_size p ("1", "1")) size)
    [ (("10000000000000000000000000000000000000001", denominator),
        ("1", "1"), ("2", "1"), ("1", "1"));
      (("9999999999999999999999999999999999999999", denominator),
        ("0", "1"), ("1", "1"), ("0", "1"));
      (("-10000000000000000000000000000000000000001", denominator),
        ("-2", "1"), ("-1", "1"), ("-1", "1"));
      (("-9999999999999999999999999999999999999999", denominator),
        ("-1", "1"), ("0", "1"), ("0", "1")) ]

let significant_digits n =
  let digits = string_of_int n in
  let rec strip length =
    if length > 0 && digits.[length - 1] = '0' then strip (length - 1) else length
  in
  strip (String.length digits)

let sentence_member figures decimals hundredths =
  let within_places =
    if decimals >= 0 then (hundredths * pow10 decimals) mod 100 = 0
    else hundredths mod (100 * pow10 (-decimals)) = 0
  in
  hundredths > 0 && within_places
  && (significant_digits hundredths <= figures || hundredths mod 100 = 0)

let grid_range figures decimals top =
  let members =
    Array.init top (fun i -> i + 1)
    |> Array.to_list
    |> List.filter (sentence_member figures decimals)
    |> Array.of_list
  in
  let next = ref 0 in
  for hundredths = 1 to top do
    while !next < Array.length members && members.(!next) < hundredths do
      incr next
    done;
    let member = sentence_member figures decimals hundredths in
    let p = Q.make hundredths 100 in
    let step = Q.of_wire (E.grid_step figures decimals (Q.wire p)) in
    let context = Printf.sprintf "figures=%d decimals=%d price=%d/100" figures decimals hundredths in
    check ("step is positive: " ^ context) (Q.lt Q.zero step);
    expect ("sentence = step membership: " ^ context) ((Q.div p step).d = 1) member;
    expect ("engine membership = counted digits: " ^ context)
      (E.on_grid figures decimals (Q.wire p)) member;
    let below =
      if member then hundredths else if !next = 0 then 0 else members.(!next - 1)
    in
    check ("fixture contains the ceiling: " ^ context) (!next < Array.length members);
    let above = members.(!next) in
    let buy = Q.of_wire (E.round_price_buy figures decimals (Q.wire p)) in
    let sell = Q.of_wire (E.round_price_sell figures decimals (Q.wire p)) in
    expect ("greatest grid price below, or zero: " ^ context) buy (Q.make below 100);
    expect ("least grid price above: " ^ context) sell (Q.make above 100);
    check ("price buy strict error: " ^ context) (Q.lt (Q.sub p buy) step);
    check ("price sell strict error: " ^ context) (Q.lt (Q.sub sell p) step)
  done;
  top

let test_6 () =
  List.iter
    (fun (p, member) -> expect "certificate's five-figure examples" (E.on_grid 5 1 (Q.wire p)) member)
    [ Q.integer 123456, true; Q.make 123456 10, false;
      Q.integer 99999, true; Q.integer 100000, true; Q.integer 100001, true;
      Q.make 1000005 10, false; Q.make 99999 10, true; Q.make 1 2, true ];
  List.iter
    (fun (p, buy, sell) ->
      expect_q "certificate buy neighbour" (E.round_price_buy 5 1 (Q.wire p)) (Q.integer buy);
      expect_q "certificate sell neighbour" (E.round_price_sell 5 1 (Q.wire p)) (Q.integer sell))
    [ Q.make 123456 10, 12345, 12346;
      Q.make 1000005 10, 100000, 100001;
      Q.make 999995 10, 99999, 100000 ];
  List.iter
    (fun n ->
      expect_q "whole-number exception keeps step at one"
        (E.grid_step 5 1 (Q.wire (Q.integer n))) Q.one;
      expect_q "whole-number buy unchanged"
        (E.round_price_buy 5 1 (Q.wire (Q.integer n))) (Q.integer n);
      expect_q "whole-number sell unchanged"
        (E.round_price_sell 5 1 (Q.wire (Q.integer n))) (Q.integer n))
    [ 99999; 100000; 100001; 123456 ];
  let checked = ref 0 in
  List.iter
    (fun (figures, decimals_tried, top) ->
      List.iter
        (fun decimals -> checked := !checked + grid_range figures decimals top)
        decimals_tried)
    [ 1, [ -1; 0; 1; 2 ], 12000;
      2, [ -1; 0; 1; 2 ], 12000;
      3, [ 0; 1 ], 120000 ];
  expect "every arithmetic.py.txt price_grid price tested" !checked 336000;
  List.iter
    (fun p ->
      expect "zero/nonpositive is not a grid price" (E.on_grid 5 1 (Q.wire p)) false;
      expect_q "nonpositive buy has no positive predecessor"
        (E.round_price_buy 5 1 (Q.wire p)) Q.zero;
      expect_q "nonpositive sell is least grid price"
        (E.round_price_sell 5 1 (Q.wire p)) (Q.make 1 10))
    [ Q.zero; Q.integer (-1) ];
  Printf.printf "price grid: %d certificate-oracle cases\n%!" !checked

let () =
  List.iter
    (fun (number, test) ->
      test ();
      Printf.printf "exact: step 1 test %d passed\n%!" number)
    [ 1, test_1; 2, test_2; 3, test_3; 4, test_4; 5, test_5; 6, test_6 ]
