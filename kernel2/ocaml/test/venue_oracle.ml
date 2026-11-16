(* Brief 3, step 2 test 4; facts section 7 and arithmetic.py.txt venue_prints.
   Test-only whole-number books, deliberately distinct from the exact ledger.
   A double product is essential: neither an exact floor nor rational scaling
   reproduces both made-up cases that lose a whole millionth. *)
module Q = Ledger_oracle.Q
module Z = Ledger_oracle.Z

let whole decimals text =
  let scaled = Q.mul (Q.decimal text) (Q.make (Z.pow10 decimals) "1") in
  if scaled.d <> "1" then invalid_arg ("not whole at field scale: " ^ text);
  int_of_string scaled.n

let product a b = int_of_string (Z.mul (string_of_int a) (string_of_int b))

let double n =
  if n < -9007199254740992 || n > 9007199254740992 then
    invalid_arg "whole number is not certified exactly representable as a double";
  Float.of_int n

let ratio numerator denominator = double numerator /. double denominator

let rate (r : Q.t) = ratio (int_of_string r.n) (int_of_string r.d)

let cut n factor = Float.to_int (Float.of_int n *. factor)

let fee notional r = cut notional (rate r)

let close entry lots closed price =
  if lots <= 0 || closed <= 0 || closed > lots || entry < 0 then
    invalid_arg "venue close is not a reduction of a long";
  let printed = product closed (price - entry / lots) in
  let left = lots - closed in
  printed, if left = 0 then 0 else cut entry (ratio left lots)

let floor_scaled entry left lots =
  let quotient, _ = Z.divmod_abs
    (Z.mul (string_of_int entry) (string_of_int left)) (string_of_int lots) in
  int_of_string quotient
