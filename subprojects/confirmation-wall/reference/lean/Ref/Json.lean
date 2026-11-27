/-!
Strict JSON for the reference kernel's front end (reference/SEMANTICS.md §2): objects keep every
key in order so duplicates can be refused, integers that fit 64 bits stay integers (serde_json's
`Number`), and other numbers are converted to binary64 with correct rounding (serde_json's
`float_roundtrip`). Parsing is outside the laws; it exists for the differential test.
-/

namespace Ref.Json

inductive Value where
  | null
  | bool (b : Bool)
  | int (i : Int)
  | float (bits : UInt64)
  | str (s : String)
  | arr (xs : Array Value)
  | obj (kvs : Array (String × Value))
  deriving Inhabited

/-- The correctly rounded binary64 bits of (-1)^neg · m · 10^e, or none if it overflows. -/
def decimalBits (neg : Bool) (m : Nat) (e : Int) : Option UInt64 :=
  let sgn : UInt64 := if neg then 0x8000000000000000 else 0
  if m == 0 then some sgn else
  -- num / den is the exact value; find q with 2^52 ≤ num·2^s/den < 2^53 (or subnormal), round half even.
  let (num, den) := if e ≥ 0 then (m * 10 ^ e.toNat, 1) else (m, 10 ^ (-e).toNat)
  let lg (x : Nat) : Int := (Nat.log2 x : Int)
  let s0 : Int := 52 - (lg num - lg den)
  let scaled (s : Int) : Nat × Nat :=
    if s ≥ 0 then (num * 2 ^ s.toNat, den) else (num, den * 2 ^ (-s).toNat)
  let s := Id.run do
    let mut s := s0
    for _ in [0:4] do
      let (a, b) := scaled s
      if a / b ≥ 2 ^ 53 then s := s - 1
      else if a / b < 2 ^ 52 then s := s + 1
    return s
  -- exponent of the leading bit: 52 - s; normal if biased exponent in 1..2046
  let exp : Int := 52 - s + 1023
  let s := if exp < 1 then s - (1 - exp) else s
  let (a, b) := scaled s
  let q := a / b
  let r := a % b
  let q := if 2 * r > b || (2 * r == b && q % 2 == 1) then q + 1 else q
  let (q, s) := if q == 2 ^ 53 then (q / 2, s - 1) else (q, s)
  let exp : Int := 52 - s + 1023
  if exp ≥ 2047 then none
  else if q < 2 ^ 52 then some (sgn ||| q.toUInt64)
  else some (sgn ||| (exp.toNat.toUInt64 <<< 52) ||| (q - 2 ^ 52).toUInt64)

abbrev Parser := StateT (List Char) (Except String)

def peek : Parser (Option Char) := do return (← get).head?
def next : Parser Char := do
  match ← get with
  | c :: cs => set cs; return c
  | [] => throw "unexpected end"
def ws : Parser Unit := do
  let rest := (← get).dropWhile (fun c => c == ' ' || c == '\n' || c == '\r' || c == '\t')
  set rest
def expect (c : Char) : Parser Unit := do
  let d ← next
  if d != c then throw s!"expected {c}"

def hexDigit (c : Char) : Option Nat :=
  if '0' ≤ c && c ≤ '9' then some (c.toNat - '0'.toNat)
  else if 'a' ≤ c && c ≤ 'f' then some (c.toNat - 'a'.toNat + 10)
  else if 'A' ≤ c && c ≤ 'F' then some (c.toNat - 'A'.toNat + 10)
  else none

def hex4 : Parser Nat := do
  let mut v := 0
  for _ in [0:4] do
    match hexDigit (← next) with
    | some d => v := 16 * v + d
    | none => throw "bad \\u escape"
  return v

partial def strBody (acc : String) : Parser String := do
  let c ← next
  if c == '"' then return acc
  if c.toNat < 0x20 then throw "control character in string"
  if c != '\\' then return ← strBody (acc.push c)
  match ← next with
  | '"' => strBody (acc.push '"')
  | '\\' => strBody (acc.push '\\')
  | '/' => strBody (acc.push '/')
  | 'b' => strBody (acc.push (Char.ofNat 8))
  | 'f' => strBody (acc.push (Char.ofNat 12))
  | 'n' => strBody (acc.push '\n')
  | 'r' => strBody (acc.push '\r')
  | 't' => strBody (acc.push '\t')
  | 'u' =>
    let hi ← hex4
    if 0xD800 ≤ hi && hi < 0xDC00 then
      expect '\\'; expect 'u'
      let lo ← hex4
      if !(0xDC00 ≤ lo && lo < 0xE000) then throw "bad surrogate pair"
      strBody (acc.push (Char.ofNat (0x10000 + (hi - 0xD800) * 0x400 + (lo - 0xDC00))))
    else if 0xDC00 ≤ hi && hi < 0xE000 then throw "lone surrogate"
    else strBody (acc.push (Char.ofNat hi))
  | _ => throw "bad escape"

def digits : Parser (List Char) := do
  let s ← get
  let ds := s.takeWhile Char.isDigit
  set (s.drop ds.length)
  return ds

def natOf (ds : List Char) : Nat := ds.foldl (fun a c => 10 * a + (c.toNat - '0'.toNat)) 0

def number : Parser Value := do
  let neg := (← peek) == some '-'
  if neg then discard next
  let int ← digits
  if int.isEmpty || (int.length > 1 && int.head? == some '0') then throw "bad number"
  let mut frac := []
  if (← peek) == some '.' then
    discard next
    frac ← digits
    if frac.isEmpty then throw "bad fraction"
  let mut expo : Option Int := none
  if (← peek) == some 'e' || (← peek) == some 'E' then
    discard next
    let mut sgn : Int := 1
    if (← peek) == some '-' then
      discard next
      sgn := -1
    else if (← peek) == some '+' then
      discard next
    let d ← digits
    if d.isEmpty then throw "bad exponent"
    expo := some (sgn * natOf d)
  if frac.isEmpty && expo.isNone then
    let m := natOf int
    let i : Int := if neg then -m else m
    if (neg && m ≤ 2 ^ 63) || (!neg && m < 2 ^ 64) then return .int i
  let m := natOf (int ++ frac)
  match decimalBits neg m ((expo.getD 0) - frac.length) with
  | some b => return .float b
  | none => throw "number out of range"

/-- serde_json's recursion limit: a container opened at nesting depth 128 or more is an error. -/
def maxNesting := 127

partial def value (depth : Nat := 0) : Parser Value := do
  ws
  match ← peek with
  | some '{' =>
    if depth + 1 > maxNesting then throw "recursion limit exceeded"
    discard next; ws
    if (← peek) == some '}' then discard next; return .obj #[]
    let mut kvs := #[]
    repeat
      ws; expect '"'
      let k ← strBody ""
      ws; expect ':'
      let v ← value (depth + 1)
      if kvs.any (·.1 == k) then throw s!"duplicate key {k}"
      kvs := kvs.push (k, v)
      ws
      match ← next with
      | ',' => pure ()
      | '}' => break
      | _ => throw "expected , or }"
    return .obj kvs
  | some '[' =>
    if depth + 1 > maxNesting then throw "recursion limit exceeded"
    discard next; ws
    if (← peek) == some ']' then discard next; return .arr #[]
    let mut xs := #[]
    repeat
      xs := xs.push (← value (depth + 1))
      ws
      match ← next with
      | ',' => pure ()
      | ']' => break
      | _ => throw "expected , or ]"
    return .arr xs
  | some '"' => discard next; return .str (← strBody "")
  | some 't' => for c in "true".toList do expect c
                return .bool true
  | some 'f' => for c in "false".toList do expect c
                return .bool false
  | some 'n' => for c in "null".toList do expect c
                return .null
  | some _ => number
  | none => throw "unexpected end"

def parse (text : String) : Except String Value := do
  let (v, rest) ← (do let v ← value; ws; return v).run text.toList
  if !rest.isEmpty then throw "trailing characters"
  return v

/-- The largest nesting of brackets outside strings (the engine's pre-parse size check). -/
def depth (text : String) : Nat := Id.run do
  let mut (d, mx, inStr, esc) := (0, 0, false, false)
  for c in text.toList do
    if inStr then
      if esc then esc := false
      else if c == '\\' then esc := true
      else if c == '"' then inStr := false
    else if c == '"' then inStr := true
    else if c == '{' || c == '[' then d := d + 1; mx := Nat.max mx d
    else if c == '}' || c == ']' then d := d - 1
  return mx

def Value.get? (v : Value) (k : String) : Option Value :=
  match v with
  | .obj kvs => (kvs.find? (·.1 == k)).map (·.2)
  | _ => none

end Ref.Json
