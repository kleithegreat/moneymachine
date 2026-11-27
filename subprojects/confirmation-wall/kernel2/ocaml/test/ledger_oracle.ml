(* Step 2 test support; no production implementation is supplied here.
   Assumed Engine.Ledger signatures (and OCaml Mm2_lean.Ledger equivalents):
     Role = maker | taker; Position = { units : Rat, cost : Rat }.
     Tier = { start : Int, name : String, maker : Rat, taker : Rat }.
     Event = fill(time, coin, signed units, price, role)
           | funding(time, hour, coin, oracle, rate) | absorb.
     initial : Rat -> Nat -> State
     position : State -> Nat -> Position
     entry : State -> Nat -> Option Rat
     equity, unrealized : State -> List Rat -> Rat
     step : List Tier -> State -> Event -> Except String Receipt
     replay : Rat -> Nat -> List Tier -> List Event -> Except String (List Receipt)
     checkFunding : Int -> Int -> Int -> List (Nat * Int) -> List Event -> Except String Unit
   OCaml Mm2_lean.Ledger entry points (rat = string * string):
     initial : rat -> int -> t; view : t -> snapshot
     equity, unrealized : t -> rat list -> rat
     step : tier list -> t -> event -> (receipt, string) result
     replay : cash:rat -> coins:int -> tier list -> event list -> (receipt list, string) result
   Receipt has state, fee, closedPnl, tier, rate. See ledger_test.ml for the
   precise OCaml records. This independent, unbounded rational oracle uses
   neither Lean arithmetic nor binary64. Cost is signed (units times entry).
*)

module Z = struct
  type t = string

  let normalize s =
    let rec first i =
      if i < String.length s - 1 && s.[i] = '0' then first (i + 1) else i
    in
    let i = first 0 in
    String.sub s i (String.length s - i)
  ;;

  let negative s = s.[0] = '-'
  let abs s = if negative s then String.sub s 1 (String.length s - 1) else s
  let neg s = if s = "0" then s else if negative s then abs s else "-" ^ s

  let of_string s =
    let minus = negative s in
    let digits = normalize (abs s) in
    String.iter (fun c -> if c < '0' || c > '9' then invalid_arg "integer") digits;
    if minus && digits <> "0" then "-" ^ digits else digits
  ;;

  let compare_abs a b =
    let lengths = Int.compare (String.length a) (String.length b) in
    if lengths = 0 then String.compare a b else lengths
  ;;

  let compare a b =
    match negative a, negative b with
    | true, false -> -1
    | false, true -> 1
    | true, true -> compare_abs (abs b) (abs a)
    | false, false -> compare_abs a b
  ;;

  let add_abs a b =
    let length = max (String.length a) (String.length b) in
    let result = Bytes.make (length + 1) '0' in
    let carry = ref 0 in
    for k = 0 to length - 1 do
      let digit s =
        let i = String.length s - 1 - k in
        if i < 0 then 0 else Char.code s.[i] - 48
      in
      let sum = digit a + digit b + !carry in
      Bytes.set result (length - k) (Char.chr (48 + (sum mod 10)));
      carry := sum / 10
    done;
    Bytes.set result 0 (Char.chr (48 + !carry));
    normalize (Bytes.to_string result)
  ;;

  let sub_abs a b =
    let result = Bytes.of_string a in
    let borrow = ref 0 in
    for k = 0 to String.length a - 1 do
      let i = String.length a - 1 - k in
      let j = String.length b - 1 - k in
      let digit = if j < 0 then 0 else Char.code b.[j] - 48 in
      let value = Char.code a.[i] - 48 - digit - !borrow in
      borrow := if value < 0 then 1 else 0;
      Bytes.set result i (Char.chr (48 + ((value + 10) mod 10)))
    done;
    normalize (Bytes.to_string result)
  ;;

  let add a b =
    if negative a = negative b
    then (
      let sum = add_abs (abs a) (abs b) in
      if negative a && sum <> "0" then "-" ^ sum else sum)
    else (
      let comparison = compare_abs (abs a) (abs b) in
      if comparison = 0
      then "0"
      else if comparison > 0
      then (
        let difference = sub_abs (abs a) (abs b) in
        if negative a then "-" ^ difference else difference)
      else (
        let difference = sub_abs (abs b) (abs a) in
        if negative b then "-" ^ difference else difference))
  ;;

  let sub a b = add a (neg b)

  let mul a b =
    let x = abs a
    and y = abs b in
    let digits = Array.make (String.length x + String.length y) 0 in
    for i = String.length x - 1 downto 0 do
      for j = String.length y - 1 downto 0 do
        let index = i + j + 1 in
        digits.(index)
        <- digits.(index) + ((Char.code x.[i] - 48) * (Char.code y.[j] - 48))
      done
    done;
    for i = Array.length digits - 1 downto 1 do
      digits.(i - 1) <- digits.(i - 1) + (digits.(i) / 10);
      digits.(i) <- digits.(i) mod 10
    done;
    let product =
      normalize (String.init (Array.length digits) (fun i -> Char.chr (48 + digits.(i))))
    in
    if negative a <> negative b && product <> "0" then "-" ^ product else product
  ;;

  let divmod_abs a b =
    if b = "0" then invalid_arg "zero divisor";
    let remainder = ref "0" in
    let quotient = Bytes.make (String.length a) '0' in
    String.iteri
      (fun i c ->
         remainder := normalize (!remainder ^ String.make 1 c);
         let digit = ref 0 in
         while compare_abs !remainder b >= 0 do
           remainder := sub_abs !remainder b;
           incr digit
         done;
         Bytes.set quotient i (Char.chr (48 + !digit)))
      a;
    normalize (Bytes.to_string quotient), !remainder
  ;;

  let rec gcd a b =
    if b = "0"
    then a
    else (
      let _, remainder = divmod_abs a b in
      gcd b remainder)
  ;;

  let quotient a b =
    let q, r = divmod_abs (abs a) (abs b) in
    if r <> "0" then invalid_arg "nonintegral quotient";
    if negative a <> negative b then neg q else q
  ;;

  let pow10 n = "1" ^ String.make n '0'
end

module Q = struct
  type t =
    { n : Z.t
    ; d : Z.t
    }

  let make n d =
    let n = Z.of_string n
    and d = Z.of_string d in
    if d = "0" then invalid_arg "zero denominator";
    let n, d = if Z.negative d then Z.neg n, Z.abs d else n, d in
    let divisor = Z.gcd (Z.abs n) d in
    { n = Z.quotient n divisor; d = Z.quotient d divisor }
  ;;

  let integer n = make (string_of_int n) "1"
  let zero = integer 0
  let one = integer 1
  let wire q = q.n, q.d
  let of_wire (n, d) = make n d
  let text q = if q.d = "1" then q.n else q.n ^ "/" ^ q.d
  let compare a b = Z.compare (Z.mul a.n b.d) (Z.mul b.n a.d)
  let equal a b = compare a b = 0
  let lt a b = compare a b < 0
  let le a b = compare a b <= 0
  let neg a = { a with n = Z.neg a.n }
  let abs a = { a with n = Z.abs a.n }
  let add a b = make (Z.add (Z.mul a.n b.d) (Z.mul b.n a.d)) (Z.mul a.d b.d)
  let sub a b = add a (neg b)
  let mul a b = make (Z.mul a.n b.n) (Z.mul a.d b.d)
  let div a b = make (Z.mul a.n b.d) (Z.mul a.d b.n)
  let min a b = if le a b then a else b
  let max a b = if le a b then b else a
  let sum xs = List.fold_left add zero xs

  let places text =
    match String.index_opt text '.' with
    | None -> 0
    | Some i -> String.length text - i - 1
  ;;

  let decimal text =
    let digits = String.concat "" (String.split_on_char '.' text) in
    make digits (Z.pow10 (places text))
  ;;

  type rounding =
    | Nearest_even
    | Nearest_away
    | Toward_zero
    | Floor
    | Ceil

  let modes = [ Nearest_even; Nearest_away; Toward_zero; Floor; Ceil ]

  let mode_name = function
    | Nearest_even -> "nearest-even"
    | Nearest_away -> "nearest-away"
    | Toward_zero -> "toward-zero"
    | Floor -> "floor"
    | Ceil -> "ceil"
  ;;

  let round_integer mode q =
    let whole, remainder = Z.divmod_abs (Z.abs q.n) q.d in
    let increment =
      match mode with
      | Toward_zero -> false
      | Floor -> Z.negative q.n && remainder <> "0"
      | Ceil -> (not (Z.negative q.n)) && remainder <> "0"
      | Nearest_even | Nearest_away ->
        let comparison = Z.compare (Z.mul "2" remainder) q.d in
        let odd = (Char.code whole.[String.length whole - 1] - 48) mod 2 = 1 in
        comparison > 0 || (comparison = 0 && (mode = Nearest_away || odd))
    in
    let rounded = if increment then Z.add whole "1" else whole in
    if Z.negative q.n then Z.neg rounded else rounded
  ;;

  let round mode places q =
    let scale = Z.pow10 places in
    let scaled = mul q (make scale "1") in
    make (round_integer mode scaled) scale
  ;;
end

type position =
  { units : Q.t
  ; cost : Q.t
  }

let flat = { units = Q.zero; cost = Q.zero }

let entry position =
  if Q.equal position.units Q.zero
  then None
  else Some (Q.div position.cost position.units)
;;

let fill position units price =
  let q = position.units
  and cost = position.cost in
  let next = Q.add q units in
  if Q.equal q Q.zero || Q.lt Q.zero (Q.mul q units)
  then { units = next; cost = Q.add cost (Q.mul units price) }, Q.zero
  else (
    let closed = Q.min (Q.abs q) (Q.abs units) in
    let sign = if Q.lt q Q.zero then Q.integer (-1) else Q.one in
    let pnl = Q.mul (Q.mul closed sign) (Q.sub price (Q.div cost q)) in
    let next_cost =
      if Q.equal next Q.zero
      then Q.zero
      else if Q.lt Q.zero (Q.mul q next)
      then Q.mul cost (Q.div next q)
      else Q.mul next price
    in
    { units = next; cost = next_cost }, pnl)
;;
