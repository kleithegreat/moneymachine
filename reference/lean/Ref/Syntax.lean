import Ref.Json

/-!
Units, the program DAG and the type checker (reference/SEMANTICS.md §2), mirroring the engine's
parser check for check so that verdicts and rejection codes agree.
-/

namespace Ref

/-- Exponents over (usd, coin, h, d, y, ev); each must stay within the engine's i8. -/
structure Dim where
  e : List Int
  deriving DecidableEq, Repr, Inhabited

namespace Dim
def bases : List String := ["usd", "coin", "h", "d", "y", "ev"]
def one : Dim := ⟨[0, 0, 0, 0, 0, 0]⟩
def base (name : String) : Option Dim :=
  (bases.idxOf? name).map fun i => ⟨(List.range 6).map fun j => if j == i then 1 else 0⟩
def inI8 (x : Int) : Bool := -128 ≤ x && x ≤ 127
def zip (f : Int → Int → Int) (a b : Dim) : Option Dim :=
  let e := List.zipWith f a.e b.e
  if e.all inI8 then some ⟨e⟩ else none
def mul := zip (· + ·)
def div := zip (· - ·)
def sqrt (u : Dim) : Option Dim := if u.e.all (· % 2 == 0) then some ⟨u.e.map (· / 2)⟩ else none

def product (s : String) : Option Dim :=
  if s == "1" then some one else
  (s.splitOn "*").foldlM (init := one) fun u factor =>
    match factor.splitOn "^" with
    | [name] => base name >>= mul u
    | [name, k] => do
        let k ← k.toInt?
        if !inI8 k then none
        let b ← base name
        (List.range k.natAbs).foldlM (init := u) fun u _ => if k > 0 then mul u b else div u b
    | _ => none

def parse (s : String) : Option Dim :=
  let s := String.mk (s.toList.filter (!·.isWhitespace))
  match s.splitOn "/" with
  | [n] => product n
  | n :: rest => do let d ← product (String.intercalate "/" rest); let n ← product n; div n d
  | [] => none

/-- compiler-rt's __powidf2, which Rust's `powi` lowers to. -/
def powi (a : Float) (b : Int) : Float := Id.run do
  let mut (r, a, n) := ((1 : Float), a, b.natAbs)
  repeat
    if n % 2 == 1 then r := r * a
    n := n / 2
    if n == 0 then break
    a := a * a
  return if b < 0 then 1 / r else r

/-- The conversion factor's bits, as the engine computes it, if the units differ only in time units
with the same total time exponent. -/
def conversion (fr to : Dim) : Option UInt64 :=
  let time := [2, 3, 4]
  let nonTime := [0, 1, 5].all fun i => fr.e[i]! == to.e[i]!
  let total (u : Dim) := time.foldl (fun s i => s + u.e[i]!) 0
  if !nonTime || total fr != total to then none else
  let hours (u : Dim) := (time.zip [1.0, 24.0, 8760.0]).foldl (fun p (i, h) => p * powi h (u.e[i]!)) 1.0
  some (hours fr / hours to).toBits
end Dim

inductive Input where
  | funding | premium | «open» | high | low | close | volume
  /-- A row of the event-input table: 0 forum_posts (events_forum), 1 gov_proposals (events_governance). -/
  | event (slot : Nat)
  deriving DecidableEq, Repr, Inhabited

def eventInputs : List (String × String) := [("forum_posts", "events_forum"), ("gov_proposals", "events_governance")]

def Input.parse (name : String) : Option Input :=
  match name with
  | "funding" => some .funding | "premium" => some .premium | "open" => some .open | "high" => some .high
  | "low" => some .low | "close" => some .close | "volume" => some .volume
  | _ => (eventInputs.findIdx? (·.1 == name)).map .event

def Input.unit : Input → Dim
  | .funding => (Dim.parse "1/h").get!
  | .premium => Dim.one
  | .volume => (Dim.base "coin").get!
  | .event _ => (Dim.base "ev").get!
  | _ => (Dim.parse "usd/coin").get!

inductive Window where
  | lag | mean | sum | std | minOver | maxOver | ema
  deriving DecidableEq, Repr, Inhabited

inductive Op where
  | add | sub | mul | div | min | max | neg | abs | sign | log | exp | sqrt | clip
  | gt | ge | lt | le | and | or | not | ite
  | convert (factor : UInt64)
  | window (w : Window) (hours : Nat)
  | xsMean | xsDemean | xsRank | hoursSince
  deriving DecidableEq, Repr, Inhabited

inductive Node where
  | input (i : Input)
  | const (bits : UInt64) (u : Dim)
  | param (k : Nat)
  | op (o : Op) (args : List Nat)
  deriving DecidableEq, Repr, Inhabited

inductive Ty where
  | num (u : Dim)
  | bool
  deriving DecidableEq, Repr, Inhabited

/-- A checked program: nodes topologically ordered (arguments precede users). -/
structure Program where
  nodes : Array Node
  types : Array Ty
  params : Array UInt64
  weight : Nat
  prediction : Option Nat
  deriving Inhabited

inductive Code where
  | parse | unknownInput | unknownOp | arity | unit | dimensionless | bool | window | ref | size
  deriving DecidableEq, Repr

def Code.name : Code → String
  | .parse => "E_PARSE" | .unknownInput => "E_UNKNOWN_INPUT" | .unknownOp => "E_UNKNOWN_OP"
  | .arity => "E_ARITY" | .unit => "E_UNIT" | .dimensionless => "E_DIMENSIONLESS" | .bool => "E_BOOL"
  | .window => "E_WINDOW" | .ref => "E_REF" | .size => "E_SIZE"

def ops : List (String × Op × Nat) :=
  [("add", .add, 2), ("sub", .sub, 2), ("mul", .mul, 2), ("div", .div, 2), ("min", .min, 2), ("max", .max, 2),
   ("neg", .neg, 1), ("abs", .abs, 1), ("sign", .sign, 1), ("log", .log, 1), ("exp", .exp, 1), ("sqrt", .sqrt, 1),
   ("clip", .clip, 3), ("gt", .gt, 2), ("ge", .ge, 2), ("lt", .lt, 2), ("le", .le, 2), ("and", .and, 2),
   ("or", .or, 2), ("not", .not, 1), ("if", .ite, 3), ("convert", .convert 0, 1),
   ("lag", .window .lag 0, 1), ("mean", .window .mean 0, 1), ("sum", .window .sum 0, 1), ("std", .window .std 0, 1),
   ("min_over", .window .minOver 0, 1), ("max_over", .window .maxOver 0, 1), ("ema", .window .ema 0, 1),
   ("xs_mean", .xsMean, 1), ("xs_demean", .xsDemean, 1), ("xs_rank", .xsRank, 1), ("hours_since", .hoursSince, 1)]

def maxNodes := 4096
def maxDepth := 64
def maxHours := 4380

open Json

structure CState where
  nodes : Array Node := #[]
  types : Array Ty := #[]
  params : Array (String × UInt64 × Dim) := #[]
  lets : Array (String × Nat) := #[]
  parsed : Nat := 0

abbrev Check := StateT CState (Except Code)

def fail {α} (c : Code) : Check α := throw c

/-- The engine's `fields`: unknown fields first, then missing ones. -/
def fields (v : Value) (req opt : List String) : Check (Array (String × Value)) := do
  let .obj kvs := v | fail .parse
  for (k, _) in kvs do
    if !req.contains k && !opt.contains k then fail .parse
  for k in req do
    if !(kvs.any (·.1 == k)) then fail .parse
  return kvs

def field (kvs : Array (String × Value)) (k : String) : Value := ((kvs.find? (·.1 == k)).map (·.2)).getD .null

def asString : Value → Check String
  | .str s => pure s
  | _ => fail .parse

def asFloat : Value → Option UInt64
  | .int i => some (Float.ofInt i).toBits
  | .float b => some b
  | _ => none

def finiteBits (b : UInt64) : Bool := (Float.ofBits b).isFinite

def number (v : Value) : Check UInt64 := do
  let some b := asFloat v | fail .parse
  if !finiteBits b then fail .parse
  return b

def unitOf (v : Value) : Check Dim := do
  let s ← asString v
  let some u := Dim.parse s | fail .unit
  return u

def intern (n : Node) (t : Ty) : Check Nat := do
  let st ← get
  match st.nodes.findIdx? (· == n) with
  | some i => return i
  | none =>
    set { st with nodes := st.nodes.push n, types := st.types.push t }
    return st.nodes.size

def normalizeZero (b : UInt64) : UInt64 := (Float.ofBits b + 0.0).toBits

def typeOp (op : Op) (ts : List Ty) (kvs : Array (String × Value)) : Check (Op × Ty) := do
  let num (k : Nat) : Check Dim := match ts[k]! with
    | .num u => pure u
    | .bool => fail .bool
  let boolean (k : Nat) : Check PUnit := match ts[k]! with
    | .bool => pure ⟨⟩
    | .num _ => fail .bool
  let same (a b : Dim) : Check Dim := if a == b then pure a else fail .unit
  let one (u : Dim) : Check Dim := if u == Dim.one then pure u else fail .dimensionless
  let opt (x : Option Dim) : Check Dim := match x with | some u => pure u | none => fail .unit
  match op with
  | .add | .sub | .min | .max => return (op, .num (← same (← num 0) (← num 1)))
  | .mul => return (op, .num (← opt (Dim.mul (← num 0) (← num 1))))
  | .div => return (op, .num (← opt (Dim.div (← num 0) (← num 1))))
  | .neg | .abs => return (op, .num (← num 0))
  | .sign => do discard (num 0); return (op, .num Dim.one)
  | .log | .exp => return (op, .num (← one (← num 0)))
  | .sqrt => return (op, .num (← opt (Dim.sqrt (← num 0))))
  | .clip => return (op, .num (← same (← same (← num 0) (← num 1)) (← num 2)))
  | .gt | .ge | .lt | .le => do discard (same (← num 0) (← num 1)); return (op, .bool)
  | .and | .or => do boolean 0; boolean 1; return (op, .bool)
  | .not => do boolean 0; return (op, .bool)
  | .ite => do
      boolean 0
      match ts[1]!, ts[2]! with
      | .bool, .bool => return (op, .bool)
      | .num a, .num b => return (op, .num (← same a b))
      | _, _ => fail .bool
  | .convert _ => do
      let to ← unitOf (field kvs "to")
      let fr ← num 0
      let some f := Dim.conversion fr to | fail .unit
      return (.convert f, .num to)
  | .window w _ => do
      let u ← num 0
      let some h := (match field kvs "hours" with | .int i => if 1 ≤ i && i ≤ maxHours then some i.toNat else none | _ => none)
        | fail .window
      return (.window w h, .num u)
  | .hoursSince => do boolean 0; return (op, .num (Dim.base "h").get!)
  | .xsMean | .xsDemean => return (op, .num (← num 0))
  | .xsRank => return (op, .num (← one (← num 0)))

def expr (v : Value) (depth : Nat) : Check Nat := do
  modify fun st => { st with parsed := st.parsed + 1 }
  if hd : depth > maxDepth then fail .size else
  if (← get).parsed > maxNodes then fail .size
  let .obj kvs := v | fail .parse
  let has (k : String) := kvs.any (·.1 == k)
  if has "input" then
    let kvs ← fields v ["input"] []
    let name ← asString (field kvs "input")
    let some i := Input.parse name | fail .unknownInput
    return ← intern (.input i) (.num i.unit)
  if has "const" then
    let kvs ← fields v ["const", "unit"] []
    let b ← number (field kvs "const")
    let u ← unitOf (field kvs "unit")
    return ← intern (.const (normalizeZero b) u) (.num u)
  if has "param" then
    let kvs ← fields v ["param"] []
    let name ← asString (field kvs "param")
    let some k := (← get).params.findIdx? (·.1 == name) | fail .ref
    return ← intern (.param k) (.num (← get).params[k]!.2.2)
  if has "ref" then
    let kvs ← fields v ["ref"] []
    let name ← asString (field kvs "ref")
    let some (_, i) := (← get).lets.find? (·.1 == name) | fail .ref
    return i
  if !has "op" then fail .parse
  let name ← asString (field kvs "op")
  let some (_, op, arity) := ops.find? (·.1 == name) | fail .unknownOp
  let extra := match op with | .window .. => ["hours"] | .convert _ => ["to"] | _ => []
  let kvs ← fields v (["op", "args"] ++ extra) []
  let .arr args := field kvs "args" | fail .parse
  if args.size != arity then fail .arity
  let mut ix := #[]
  for a in args do
    ix := ix.push (← expr a (depth + 1))
  let types := (← get).types
  let ts := ix.toList.map fun i => types[i]!
  let (op, ty) ← typeOp op ts kvs
  intern (.op op ix.toList) ty
termination_by maxDepth + 1 - depth
decreasing_by omega

def program (v : Value) : Check Program := do
  let kvs ← fields v ["dsl", "name", "mechanism", "weight"] ["params", "let", "prediction"]
  match field kvs "dsl" with
  | .int 1 => pure ()
  | _ => fail .parse
  discard (asString (field kvs "name"))
  let mech ← fields (field kvs "mechanism") ["counterparty", "predictions", "capacity"] []
  discard (asString (field mech "counterparty"))
  discard (asString (field mech "capacity"))
  match field mech "predictions" with
  | .arr xs => if !(xs.all fun x => match x with | .str _ => true | _ => false) then fail .parse
  | _ => fail .parse
  if let some p := v.get? "params" then
    let .obj ps := p | fail .parse
    for (name, spec) in ps do
      let s ← fields spec ["value", "unit"] []
      let b ← number (field s "value")
      let u ← unitOf (field s "unit")
      modify fun st => { st with params := st.params.push (name, b, u) }
  if let some l := v.get? "let" then
    let .obj ls := l | fail .parse
    for (name, e) in ls do
      let i ← expr e 1
      modify fun st => { st with lets := st.lets.push (name, i) }
  let w ← expr (field kvs "weight") 1
  match (← get).types[w]! with
  | .num u => if u != Dim.one then fail .dimensionless
  | .bool => fail .bool
  let pred ← match v.get? "prediction" with
    | none => pure none
    | some p => do
      let pk ← fields p ["condition"] []
      let c ← expr (field pk "condition") 1
      if (← get).types[c]! != .bool then fail .bool
      pure (some c)
  let st ← get
  return { nodes := st.nodes, types := st.types, params := st.params.map (·.2.1), weight := w, prediction := pred }

/-- Parse and check a program's text: the program, or the engine's rejection code. -/
def check (text : String) : Except Code Program :=
  if text.utf8ByteSize > 1 <<< 20 || Json.depth text > 2 * maxDepth + 8 then .error .size else
  match Json.parse text with
  | .error _ => .error .parse
  | .ok v => match (program v).run {} with
    | .ok (p, _) => .ok p
    | .error c => .error c

end Ref
