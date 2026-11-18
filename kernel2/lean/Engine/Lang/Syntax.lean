import Engine.Json
import Engine.Orders.Value

/-!
# The program: units, types, the checked DAG and its verdict (KERNEL.md A17)

`parseAt` reads a program's text and returns the checked program or the first fault's code and where it is.
The nodes are hash-consed into a DAG whose arguments precede their users. An operator named for both sorts is
resolved when its first argument is typed: on exact arguments it is the exact operator (`eadd`, ..., `ele`).
-/

namespace Engine.Lang

open Engine.Json

/-- Exponents over (usd, coin, h, d, y, ev, tick); each stays within `i8`. -/
structure Dim where
  e : List Int
  deriving DecidableEq, Repr, Inhabited

namespace Dim

def bases : List String := ["usd", "coin", "h", "d", "y", "ev", "tick"]
def one : Dim := ⟨[0, 0, 0, 0, 0, 0, 0]⟩
def base (name : String) : Option Dim :=
  (bases.idxOf? name).map fun i => ⟨(List.range 7).map fun j => if j == i then 1 else 0⟩
def inI8 (x : Int) : Bool := -128 ≤ x && x ≤ 127

def zip (f : Int → Int → Int) (a b : Dim) : Option Dim :=
  let e := List.zipWith f a.e b.e
  if a.e.length == b.e.length && e.all inI8 then some ⟨e⟩ else none
def mul := zip (· + ·)
def div := zip (· - ·)
def sqrt (u : Dim) : Option Dim := if u.e.all (· % 2 == 0) then some ⟨u.e.map (· / 2)⟩ else none

def splitOn (sep : Char) (cs : List Char) : List (List Char) :=
  cs.foldr
    (fun c acc =>
      if c == sep then [] :: acc
      else match acc with
        | a :: rest => (c :: a) :: rest
        | [] => [[c]])
    [[]]

def exponentOf (cs : List Char) : Option Int :=
  if cs.isEmpty || !cs.all isDigit then none
  else
    let n : Int := cs.foldl (fun n c => n * 10 + ((c.toNat - '0'.toNat : Nat) : Int)) 0
    if 1 ≤ n && n ≤ 127 then some n else none

def factor (cs : List Char) : Option Dim :=
  match splitOn '^' cs with
  | [name] => base (String.ofList name)
  | [name, k] => do
    let b ← base (String.ofList name)
    let k ← exponentOf k
    some ⟨b.e.map (· * k)⟩
  | _ => none

def product (cs : List Char) : Option Dim :=
  if cs == ['1'] then some one
  else (splitOn '*' cs).foldlM (init := one) fun u f => do
    let d ← factor f
    mul u d

/-- A unit as A17 writes it: `1`, or factors joined by `*`, and optionally `/` and more factors. -/
def parse (s : String) : Option Dim :=
  match splitOn '/' (chars s) with
  | [n] => product n
  | [n, d] => do
    let d ← product d
    let n ← product n
    div n d
  | _ => none

/-- The canonical text of a unit: its exponents. Two units are equal when their texts are. -/
def canon (u : Dim) : String := ",".intercalate (u.e.map toString)

def powiGo (r a : Float) (n : Nat) : Float :=
  let r := if n % 2 == 1 then r * a else r
  if h : n / 2 = 0 then r else powiGo r (a * a) (n / 2)
termination_by n
decreasing_by omega

/-- compiler-rt's `__powidf2`, which Rust's `powi` lowers to. -/
def powi (a : Float) (b : Int) : Float :=
  let r := powiGo 1 a b.natAbs
  if b < 0 then 1 / r else r

/-- The conversion factor's bits, if the units differ only in time units with the same total time exponent. -/
def conversion (fr to : Dim) : Option UInt64 :=
  let time := [2, 3, 4]
  let nonTime := [0, 1, 5, 6].all fun i => fr.e[i]! == to.e[i]!
  let total (u : Dim) := time.foldl (fun s i => s + u.e[i]!) 0
  if !nonTime || total fr != total to then none else
  let hours (u : Dim) := (time.zip [1.0, 24.0, 8760.0]).foldl (fun p (i, h) => p * powi h (u.e[i]!)) 1.0
  some (hours fr / hours to).toBits

end Dim

inductive Window where
  | lag | mean | sum | std | minOver | maxOver | ema
  deriving DecidableEq, Repr, Inhabited

inductive Op where
  | add | sub | mul | div | min | max | neg | abs | sign | log | exp | sqrt | clip
  | gt | ge | lt | le | and | or | not | ite
  | eadd | esub | emul | ediv | emin | emax | eneg | egt | ege | elt | ele
  | toExact | toFloat
  | convert (factor : UInt64) (to : Dim)
  | window (w : Window) (ticks : Nat)
  | xsMean | xsDemean | xsRank | ticksSince
  deriving DecidableEq, Repr, Inhabited

/-- A type: a bool, a float with its unit, or an exact number with its unit. -/
inductive Ty where
  | bool
  | num (u : Dim)
  | exact (u : Dim)
  deriving DecidableEq, Repr, Inhabited

inductive Node where
  | builtin (name : String)
  | slotIn (name : String) (slot : Nat)
  | source (name : String) (u : Dim)
  | const (bits : UInt64) (u : Dim)
  | exactConst (q : Rat) (u : Dim)
  | op (o : Op) (args : List Nat)
  deriving DecidableEq, Repr, Inhabited

inductive Leverage where
  | all (n : Nat)
  | byCoin (entries : List (String × Nat))
  deriving DecidableEq, Repr, Inhabited

/-- A slot's size: `close`, or a target at a node of unit `coin` (a size) or `usd` (a notional). -/
inductive SlotSize where
  | close
  | target (node : Nat)
  deriving DecidableEq, Repr, Inhabited

/-- A slot of A17; `when`, `price` and a target are nodes. -/
structure Slot where
  name : String
  side : Engine.Orders.Side
  when : Nat
  price : Nat
  size : SlotSize
  tif : Engine.Orders.Tif
  reduceOnly : Bool
  deriving DecidableEq, Repr, Inhabited

/-- A checked program: nodes in an order where arguments precede users, each with its type. -/
structure Program where
  tick : Nat
  decideEvery : Nat
  leverage : Leverage
  sources : List (String × Dim)
  nodes : Array Node
  types : Array Ty
  probeNodes : Array Nat
  slots : Array Slot := #[]
  deriving DecidableEq, Repr, Inhabited

def priceUnit : Dim := ⟨[1, -1, 0, 0, 0, 0, 0]⟩
def sizeUnit : Dim := ⟨[0, 1, 0, 0, 0, 0, 0]⟩
def moneyUnit : Dim := ⟨[1, 0, 0, 0, 0, 0, 0]⟩
def rateUnit : Dim := ⟨[0, 0, -1, 0, 0, 0, 0]⟩
def tickUnit : Dim := ⟨[0, 0, 0, 0, 0, 0, 1]⟩

/-- A17's built-in inputs and their units; every one is exact. -/
def builtinUnits : List (String × Dim) :=
  [("bid", priceUnit), ("ask", priceUnit), ("mid", priceUnit), ("high", priceUnit), ("low", priceUnit),
   ("oracle", priceUnit), ("entry", priceUnit), ("first_price", priceUnit), ("resting_price", priceUnit),
   ("bid_size", sizeUnit), ("ask_size", sizeUnit), ("traded", sizeUnit), ("pos", sizeUnit),
   ("first_size", sizeUnit), ("filled", sizeUnit), ("resting", sizeUnit),
   ("funding", rateUnit), ("age", tickUnit), ("equity", moneyUnit), ("free_margin", moneyUnit)]

def inputNames : List String := builtinUnits.map (·.1)

def builtinTy (name : String) : Option Ty := ((builtinUnits.find? (·.1 == name)).map (·.2)).map Ty.exact

/-- The inputs of one slot, which only a slot's name selects. -/
def slotInputs : List String := ["filled", "resting", "resting_price"]

def validName (s : String) : Bool :=
  match chars s with
  | c :: rest =>
    'a' ≤ c && c ≤ 'z' && rest.length ≤ 31 && rest.all fun d => ('a' ≤ d && d ≤ 'z') || isDigit d || d == '_'
  | [] => false

def ops : List (String × Op × Nat) :=
  [("add", .add, 2), ("sub", .sub, 2), ("mul", .mul, 2), ("div", .div, 2), ("min", .min, 2), ("max", .max, 2),
   ("neg", .neg, 1), ("abs", .abs, 1), ("sign", .sign, 1), ("log", .log, 1), ("exp", .exp, 1), ("sqrt", .sqrt, 1),
   ("clip", .clip, 3), ("gt", .gt, 2), ("ge", .ge, 2), ("lt", .lt, 2), ("le", .le, 2), ("and", .and, 2),
   ("or", .or, 2), ("not", .not, 1), ("if", .ite, 3), ("convert", .convert 0 Dim.one, 1),
   ("lag", .window .lag 0, 1), ("mean", .window .mean 0, 1), ("sum", .window .sum 0, 1), ("std", .window .std 0, 1),
   ("min_over", .window .minOver 0, 1), ("max_over", .window .maxOver 0, 1), ("ema", .window .ema 0, 1),
   ("xs_mean", .xsMean, 1), ("xs_demean", .xsDemean, 1), ("xs_rank", .xsRank, 1), ("ticks_since", .ticksSince, 1),
   ("exact", .toExact, 1), ("float", .toFloat, 1)]

/-- The exact operator an operator named for both sorts is on exact arguments. -/
def Op.exactTwin : Op → Option Op
  | .add => some .eadd
  | .sub => some .esub
  | .mul => some .emul
  | .div => some .ediv
  | .min => some .emin
  | .max => some .emax
  | .neg => some .eneg
  | .gt => some .egt
  | .ge => some .ege
  | .lt => some .elt
  | .le => some .ele
  | _ => none

def maxNodes := 4096
def maxDepth := 64
def maxWindowTicks := 1048576

/-! ### The typing rule of one operator -/

def sameDim (a b : Dim) : Except String Dim := if a == b then .ok a else .error "E_UNIT"

def numOf (x : Except String Dim) : Except String Ty := x.map Ty.num

def exactOf (x : Except String Dim) : Except String Ty := x.map Ty.exact

def boolOf (x : Except String Unit) : Except String Ty := x.map fun _ => Ty.bool

/-- The type of `if`'s two branches: two bools, or two floats of one unit. -/
def iteTy (a b : Option Ty) : Except String Ty :=
  match a, b with
  | some Ty.bool, some Ty.bool => .ok Ty.bool
  | some (Ty.num x), some (Ty.num y) => numOf (sameDim x y)
  | _, _ => .error "E_TYPE"

/-- The type of an operator over its arguments' types, or the code of the fault (KERNEL.md, "The verdict"). -/
def opTyE (o : Op) (ts : List Ty) : Except String Ty :=
  let num (k : Nat) : Except String Dim := match ts[k]? with
    | some (.num u) => .ok u
    | _ => .error "E_TYPE"
  let exact (k : Nat) : Except String Dim := match ts[k]? with
    | some (.exact u) => .ok u
    | _ => .error "E_TYPE"
  let boolean (k : Nat) : Except String Unit := match ts[k]? with
    | some .bool => .ok ()
    | _ => .error "E_TYPE"
  let same := sameDim
  let one (u : Dim) : Except String Dim := if u == Dim.one then .ok u else .error "E_UNIT"
  let opt (x : Option Dim) : Except String Dim := match x with | some u => .ok u | none => .error "E_UNIT"
  match o with
  | .add | .sub | .min | .max => numOf (do let a ← num 0; let b ← num 1; same a b)
  | .mul => numOf (do let a ← num 0; let b ← num 1; opt (Dim.mul a b))
  | .div => numOf (do let a ← num 0; let b ← num 1; opt (Dim.div a b))
  | .neg | .abs => numOf (num 0)
  | .sign => numOf (do let _ ← num 0; pure Dim.one)
  | .log | .exp => numOf (do one (← num 0))
  | .sqrt => numOf (do opt (Dim.sqrt (← num 0)))
  | .clip => numOf (do let a ← num 0; let b ← num 1; let c ← num 2; same (← same a b) c)
  | .gt | .ge | .lt | .le => boolOf (do let a ← num 0; let b ← num 1; let _ ← same a b; pure ())
  | .and | .or => boolOf (do boolean 0; boolean 1)
  | .not => boolOf (boolean 0)
  | .ite => do
    boolean 0
    iteTy ts[1]? ts[2]?
  | .convert f to => numOf (do
    let a ← num 0
    if Dim.conversion a to == some f then pure to else .error "E_UNIT")
  | .window _ n => numOf (do
    let u ← num 0
    if 1 ≤ n && n ≤ maxWindowTicks then pure u else .error "E_WINDOW")
  | .xsMean | .xsDemean => numOf (num 0)
  | .xsRank => numOf (do one (← num 0))
  | .ticksSince => numOf (do boolean 0; pure tickUnit)
  | .eadd | .esub | .emin | .emax => exactOf (do let a ← exact 0; let b ← exact 1; same a b)
  | .emul => exactOf (do let a ← exact 0; let b ← exact 1; opt (Dim.mul a b))
  | .ediv => exactOf (do let a ← exact 0; let b ← exact 1; opt (Dim.div a b))
  | .eneg => exactOf (exact 0)
  | .egt | .ege | .elt | .ele => boolOf (do let a ← exact 0; let b ← exact 1; let _ ← same a b; pure ())
  | .toExact => exactOf (num 0)
  | .toFloat => numOf (exact 0)

def opTy (o : Op) (ts : List Ty) : Option Ty := (opTyE o ts).toOption

/-! ### Well-formedness -/

/-- Node `i` is typed by its rule and reads only nodes before it. -/
def Program.nodeOkb (p : Program) (i : Nat) : Bool :=
  match p.nodes[i]! with
  | .builtin n => (builtinTy n).isSome && p.types[i]! == (builtinTy n).getD .bool
  | .slotIn n s =>
    slotInputs.contains n && (builtinTy n).isSome && p.types[i]! == (builtinTy n).getD .bool && s < p.slots.size
  | .source _ u => p.types[i]! == .num u
  | .const _ u => p.types[i]! == .num u
  | .exactConst _ u => p.types[i]! == .exact u
  | .op o args => args.all (· < i) && opTy o (args.map (p.types[·]!)) == some p.types[i]!

/-- A slot's `when` is a bool, its price an exact price, its size `close` or an exact size or notional. -/
def Program.slotOkb (p : Program) (s : Slot) : Bool :=
  s.when < p.nodes.size && p.types[s.when]! == .bool &&
    s.price < p.nodes.size && p.types[s.price]! == .exact priceUnit &&
    match s.size with
    | .close => true
    | .target n => n < p.nodes.size && (p.types[n]! == .exact sizeUnit || p.types[n]! == .exact moneyUnit)

def maxSlots := 16

/-- Each node typed by its rule, arguments before their users, probes naming nodes, at most 16 slots, each typed. -/
def Program.wfb (p : Program) : Bool :=
  p.types.size == p.nodes.size && p.probeNodes.all (· < p.nodes.size) &&
    (List.range p.nodes.size).all p.nodeOkb && p.slots.size ≤ maxSlots && p.slots.all p.slotOkb

def Program.WF (p : Program) : Prop := p.wfb = true

def Program.sourceNames (p : Program) : List String :=
  p.nodes.toList.filterMap fun n => match n with | .source name _ => some name | _ => none

def Program.declared (p : Program) : List (String × String) := p.sources.map fun d => (d.1, Dim.canon d.2)

def Program.readsTraded (p : Program) : Bool := p.nodes.any fun n => n == .builtin "traded"

def Node.rename (ρ : String → String) : Node → Node
  | .source name u => .source (ρ name) u
  | n => n

def Program.rename (ρ : String → String) (p : Program) : Program :=
  { p with sources := p.sources.map fun d => (ρ d.1, d.2), nodes := p.nodes.map (Node.rename ρ) }

/-! ### Reading a program -/

/-- A parameter's value: a float with its bits, or an exact decimal. -/
inductive PVal where
  | float (bits : UInt64)
  | exact (q : Rat)

structure CState where
  sources : List (String × Dim) := []
  nodes : Array Node := #[]
  types : Array Ty := #[]
  params : List (String × PVal × Dim) := []
  lets : List (String × Nat) := []
  slotNames : List (Option String) := []
  parsed : Nat := 0
  where_ : String := "document"

abbrev Check := StateT CState (Except (String × String))

def fail {α : Type} (code : String) : Check α := do
  let st ← get
  throw (code, st.where_)

def fields (v : J) (req opt : List String) : Check (List (String × J)) := do
  match v with
  | .obj kvs =>
    if v.keysAre req opt then return kvs else fail "E_PARSE"
  | _ => fail "E_PARSE"

def field (kvs : List (String × J)) (k : String) : J := ((kvs.find? (·.1 == k)).map (·.2)).getD .null

def asString : J → Check String
  | .str s => pure s
  | _ => fail "E_PARSE"

def asFloat : J → Option UInt64
  | .int i => some (Float.ofInt i).toBits
  | .float b => some b
  | _ => none

def finiteBits (b : UInt64) : Bool := (Float.ofBits b).isFinite

def number (v : J) : Check UInt64 := do
  let some b := asFloat v | fail "E_PARSE"
  if !finiteBits b then fail "E_PARSE"
  return b

def unitOf (v : J) : Check Dim := do
  let s ← asString v
  let some u := Dim.parse s | fail "E_UNIT"
  return u

def intern (n : Node) (t : Ty) : Check Nat := do
  let st ← get
  match st.nodes.toList.findIdx? (· == n) with
  | some i => return i
  | none =>
    set { st with nodes := st.nodes.push n, types := st.types.push t }
    return st.nodes.size

def normalizeZero (b : UInt64) : UInt64 := (Float.ofBits b + 0.0).toBits

def windowTicks (kvs : List (String × J)) : Check Nat := do
  match field kvs "ticks" with
  | .int i => if 1 ≤ i && i ≤ maxWindowTicks then return i.toNat else fail "E_WINDOW"
  | _ => fail "E_WINDOW"

/-- The rational of an exact decimal: an optional `-`, digits, and optionally a point and digits. -/
def decimalRat (s : String) : Option Rat :=
  let (negative, cs) := match chars s with | '-' :: rest => (true, rest) | rest => (false, rest)
  let (whole, rest) := cs.span isDigit
  let fraction : Option (List Char) := match rest with
    | [] => some []
    | '.' :: digits => if !digits.isEmpty && digits.all isDigit then some digits else none
    | _ => none
  if whole.isEmpty then none else
  fraction.map fun digits =>
    let n := (whole ++ digits).foldl (fun n c => n * 10 + (c.toNat - '0'.toNat)) 0
    let q : Rat := (n : Rat) / (10 : Rat) ^ digits.length
    if negative then -q else q

/-- One expression, its arguments first, at `depth`; `fuel` only bounds the recursion. -/
def expr : Nat → J → Nat → Check Nat
  | 0, _, _ => fail "E_SIZE"
  | fuel + 1, v, depth => do
    modify fun st => { st with parsed := st.parsed + 1 }
    if depth > maxDepth then fail "E_SIZE"
    if (← get).parsed > maxNodes then fail "E_SIZE"
    let .obj kvs := v | fail "E_PARSE"
    let has (k : String) := kvs.any (·.1 == k)
    if has "input" then
      let kvs ← fields v ["input"] ["slot"]
      let name ← asString (field kvs "input")
      let slotted := has "slot"
      if slotInputs.contains name then
        if !slotted then fail "E_PARSE"
        let slot ← asString (field kvs "slot")
        let some i := (← get).slotNames.findIdx? (· == some slot) | fail "E_REF"
        let some t := builtinTy name | fail "E_UNKNOWN_INPUT"
        intern (.slotIn name i) t
      else if slotted then fail "E_PARSE"
      else match builtinTy name with
        | some t => intern (.builtin name) t
        | none =>
          match (← get).sources.find? (·.1 == name) with
          | some (_, u) => intern (.source name u) (.num u)
          | none => fail "E_UNKNOWN_INPUT"
    else if has "const" then
      let kvs ← fields v ["const", "unit"] []
      let b ← number (field kvs "const")
      let u ← unitOf (field kvs "unit")
      intern (.const (normalizeZero b) u) (.num u)
    else if has "exact" then
      let kvs ← fields v ["exact", "unit"] []
      let some q := decimalRat (← asString (field kvs "exact")) | fail "E_PARSE"
      let u ← unitOf (field kvs "unit")
      intern (.exactConst q u) (.exact u)
    else if has "param" then
      let kvs ← fields v ["param"] []
      let name ← asString (field kvs "param")
      match (← get).params.find? (·.1 == name) with
      | some (_, .float bits, u) => intern (.const bits u) (.num u)
      | some (_, .exact q, u) => intern (.exactConst q u) (.exact u)
      | none => fail "E_REF"
    else if has "ref" then
      let kvs ← fields v ["ref"] []
      let name ← asString (field kvs "ref")
      match (← get).lets.find? (·.1 == name) with
      | some (_, i) => return i
      | none => fail "E_REF"
    else if has "op" then
      let name ← asString (field kvs "op")
      let some (_, op, arity) := ops.find? (·.1 == name) | fail "E_UNKNOWN_OP"
      let extra := match op with | .window .. => ["ticks"] | .convert .. => ["to"] | _ => []
      let kvs ← fields v ["op", "args"] extra
      let .arr args := field kvs "args" | fail "E_PARSE"
      if args.length != arity then fail "E_ARITY"
      let mut ix : List Nat := []
      for a in args do
        ix := ix ++ [← expr fuel a (depth + 1)]
      let types := (← get).types
      let ts := ix.map fun i => types[i]!
      let op := match ts[0]?, op.exactTwin with
        | some (.exact _), some twin => twin
        | _, _ => op
      let op ← match op with
        | .window w _ => do
          let n ← match field kvs "ticks" with
            | .int i => if 1 ≤ i then pure i.toNat else fail "E_WINDOW"
            | _ => fail "E_WINDOW"
          pure (Op.window w n)
        | .convert _ _ => do
          let to ← unitOf (field kvs "to")
          let first : Option Ty := ts[0]?
          let some f := (match first with
            | some (Ty.num fr) => Dim.conversion fr to
            | _ => none) | fail (match first with | some (Ty.num _) => "E_UNIT" | _ => "E_TYPE")
          pure (Op.convert f to)
        | o => pure o
      match opTyE op ts with
      | .ok ty => intern (.op op ix) ty
      | .error code => fail code
    else fail "E_PARSE"

def nameList (v : J) : Check (List (String × J)) := do
  match v with
  | .arr items =>
    let mut out : List (String × J) := []
    for item in items do
      let kvs ← fields item ["name", "is"] []
      let name ← asString (field kvs "name")
      if !validName name || out.any (·.1 == name) then fail "E_PARSE"
      out := out ++ [(name, field kvs "is")]
    return out
  | _ => fail "E_PARSE"

def atSection (s : String) : Check Unit := modify fun st => { st with where_ := s }

def positiveInt (v : J) : Check Nat := do
  match v with
  | .int n => if 1 ≤ n then return n.toNat else fail "E_PARSE"
  | _ => fail "E_PARSE"

def leverageOf (v : J) : Check Leverage := do
  match v with
  | .int n => if 1 ≤ n then return .all n.toNat else fail "E_PARSE"
  | .obj kvs =>
    let mut out : List (String × Nat) := []
    for (k, x) in kvs do
      out := out ++ [(k, ← positiveInt x)]
    return .byCoin out
  | _ => fail "E_PARSE"

/-- The names of the document's slots by position, so that an input reads a slot named further on. -/
def slotNamesOf : J → List (Option String)
  | .arr items => items.map fun item => match item with
    | .obj kvs => match field kvs "name" with | .str name => some name | _ => none
    | _ => none
  | _ => []

def nodeAt (v : J) : Check Nat := do expr (maxDepth + 4) v 1

def oneOf {β : Type} (table : List (String × β)) (v : J) : Check β := do
  let name ← asString v
  let some (_, x) := table.find? (·.1 == name) | fail "E_PARSE"
  return x

/-- The slots of A17, each checked in the order of its table. -/
def slotList (v : J) : Check (List Slot) := do
  let .arr items := v | fail "E_PARSE"
  if items.length > maxSlots then fail "E_PARSE"
  let mut out : List Slot := []
  for item in items do
    let kvs ← fields item ["name", "side", "when", "price", "size", "tif", "reduce_only"] []
    let name ← asString (field kvs "name")
    if !validName name || out.any (·.name == name) then fail "E_PARSE"
    atSection ("slots." ++ name)
    let side ← oneOf [("buy", Engine.Orders.Side.buy), ("sell", .sell)] (field kvs "side")
    let when_ ← nodeAt (field kvs "when")
    if (← get).types[when_]! != .bool then fail "E_TYPE"
    let price ← nodeAt (field kvs "price")
    match (← get).types[price]! with
    | .exact u => if u != priceUnit then fail "E_UNIT"
    | _ => fail "E_TYPE"
    let size ← match field kvs "size" with
      | .str "close" => pure SlotSize.close
      | e => do
        let n ← nodeAt e
        match (← get).types[n]! with
        | .exact u => if u != sizeUnit && u != moneyUnit then fail "E_UNIT"
        | _ => fail "E_TYPE"
        pure (SlotSize.target n)
    let tif ← oneOf [("gtc", Engine.Orders.Tif.gtc), ("alo", .alo), ("ioc", .ioc)] (field kvs "tif")
    let reduceOnly ← match field kvs "reduce_only" with
      | .bool b => pure b
      | _ => fail "E_PARSE"
    out := out ++ [{ name := name, side := side, when := when_, price := price, size := size, tif := tif,
                     reduceOnly := reduceOnly }]
  return out

def program (v : J) : Check Program := do
  let kvs ← fields v ["version", "tick", "decide_every", "leverage", "sources", "params", "let", "slots", "probes"] []
  match field kvs "version" with
  | .int 2 => pure ()
  | _ => fail "E_PARSE"
  let tick ← positiveInt (field kvs "tick")
  let every ← positiveInt (field kvs "decide_every")
  let leverage ← leverageOf (field kvs "leverage")
  atSection "sources"
  match field kvs "sources" with
  | .arr items =>
    for item in items do
      let sk ← fields item ["name", "unit"] []
      let name ← asString (field sk "name")
      if !validName name || (← get).sources.any (·.1 == name) then fail "E_PARSE"
      let u ← unitOf (field sk "unit")
      modify fun st => { st with sources := st.sources ++ [(name, u)] }
  | _ => fail "E_PARSE"
  atSection "params"
  match field kvs "params" with
  | .arr items =>
    for item in items do
      let pk ← fields item ["name", "value", "unit"] []
      let name ← asString (field pk "name")
      if !validName name || (← get).params.any (·.1 == name) then fail "E_PARSE"
      let value : PVal ← match field pk "value" with
        | .str s => match decimalRat s with
          | some q => pure (PVal.exact q)
          | none => fail "E_PARSE"
        | j => do pure (PVal.float (← number j))
      let u ← unitOf (field pk "unit")
      modify fun st => { st with params := st.params ++ [(name, value, u)] }
  | _ => fail "E_PARSE"
  modify fun st => { st with slotNames := slotNamesOf (field kvs "slots") }
  atSection "let"
  let lets ← nameList (field kvs "let")
  for (name, e) in lets do
    atSection ("let." ++ name)
    let i ← expr (maxDepth + 4) e 1
    modify fun st => { st with lets := st.lets ++ [(name, i)] }
  atSection "slots"
  let slots ← slotList (field kvs "slots")
  atSection "probes"
  let probes ← nameList (field kvs "probes")
  let mut probeNodes : List Nat := []
  for (name, e) in probes do
    atSection ("probes." ++ name)
    probeNodes := probeNodes ++ [← expr (maxDepth + 4) e 1]
  atSection "windows"
  let st ← get
  let total := st.nodes.toList.foldl (fun s n => match n with | .op (.window _ k) _ => s + k | _ => s) 0
  if total > maxWindowTicks then fail "E_WINDOW"
  return { tick := tick, decideEvery := every, leverage := leverage, sources := st.sources, nodes := st.nodes,
           types := st.types, probeNodes := probeNodes.toArray, slots := slots.toArray }

/-- The checked program of a text, or the first fault's code and where it is. -/
def parseAt (text : String) : Except (String × String) Program :=
  if text.utf8ByteSize > 1048576 || depth text > 130 then .error ("E_SIZE", "document")
  else
    match Json.parse text with
    | .error _ => .error ("E_PARSE", "document")
    | .ok j =>
      match (program j).run {} with
      | .error e => .error e
      | .ok (p, _) => if p.wfb then .ok p else .error ("E_PARSE", "document")

def parse (text : String) : Except String Program := (parseAt text).mapError (·.1)

end Engine.Lang
