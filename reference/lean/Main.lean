import Ref

/-!
refmm: the Lean reference kernel's executable, on binary64.
  refmm check PROGRAM                 the verdict: `ok` or the rejection code
  refmm run PROGRAMS MARKET OUT_DIR   on a market exported by reference/mmdump, each program listed in PROGRAMS
                                      (one path per line): the i-th's output to OUT_DIR/i.json, its node streams to
                                      OUT_DIR/i.bin
  refmm bench PROGRAM MARKET REPS     evaluator-only milliseconds of REPS runs (`null` if not completed)
                                      written in mmdump's format (every float as its bits)
  refmm admit CASES                   per admission case (reference/admission_differential.py), `admit`'s refusal
                                      code and position, or `ok` and the required set when it passes event times
  refmm resolve CASES                 per resolver case (kernel/RULES.md §7), one line: its result and, if it
                                      resolves, `resolveAll`'s observations in §7's format
-/

open Ref Json

def int! : Value → Int
  | .int i => i
  | _ => panic! "expected an integer"

def bits! (v : Value) : Float := Float.ofBits (int! v).toNat.toUInt64

def arr! : Value → Array Value
  | .arr xs => xs
  | _ => panic! "expected an array"

def get! (v : Value) (k : String) : Value := (v.get? k).get!

/-- The stage 6 market's world as sources: funding (the settlement provider; source 0), bars (the bars provider; 1)
and the two event sources (2, 3), each bound to a dataset whose certificate grants everything. -/
def decl (n : Nat) (fields : Array (String × String × Dim)) (cadence : Cadence)
    (roles : List (Role × List (String × String))) : Decl :=
  { hash := s!"decl{n}", fields, times := ["event", "fetchedAt"], eventColumn := "event",
    slotColumn := if cadence == .event then some "slot" else none, entityColumns := ["coin"], revisionColumns := [],
    rule := .max [.field "event", .field "fetchedAt"], cadence, deps := [], roles }

def evField (name : String) : Array (String × String × Dim) := #[(name, "count", ⟨[0, 0, 0, 0, 0, 1]⟩)]

def registry : Registry :=
  { decls := #[
      decl 0 #[("funding", "rate", ⟨[0, 0, -1, 0, 0, 0]⟩), ("premium", "premium", Dim.one)] .held
        [(.settlement, [("rate", "rate")])],
      decl 1 #[("open", "open", ⟨[1, -1, 0, 0, 0, 0]⟩), ("high", "high", ⟨[1, -1, 0, 0, 0, 0]⟩),
               ("low", "low", ⟨[1, -1, 0, 0, 0, 0]⟩), ("close", "close", ⟨[1, -1, 0, 0, 0, 0]⟩),
               ("volume", "volume", ⟨[0, 1, 0, 0, 0, 0]⟩)] .held
        [(.bars, [("open", "open"), ("high", "high"), ("low", "low"), ("close", "close"), ("trades", "trades")])],
      decl 2 (evField "forum_posts") .event [],
      decl 3 (evField "gov_proposals") .event [] ] }

def roles : Roles := ⟨1, 0⟩

def far : Int := 2 ^ 62 - 1

def admissionMeta (present : List Nat) (intervals : Array (Int × Int)) : Meta :=
  let bound := [0, 1] ++ present.map (· + 2)
  let cert (s : Nat) : Cert :=
    let d := registry.decls[s]!
    { id := s!"cert{s}", decl := d.hash, manifest := s!"data{s}", policy := "P", verifier := "V", upstream := [],
      grants := (List.range intervals.size).flatMap fun c =>
        d.values.map fun col => ⟨c, col, (-far, far), (-far, far)⟩
      controls := d.controls, venueState := true }
  { bindings := fun s => if bound.contains s then some ⟨s!"data{s}", s!"cert{s}"⟩ else none
    certs := bound.map cert, supersessions := [], position := 0, policy := "P", verifier := "V", holdout := [],
    holdoutStart := far, intervals, version := 0 }

def obs (source coin : Nat) (key known : Int) (slot : Option Int) (vals : Array Float) (role : Option (RolePayload Float)) :
    Obs Float :=
  { source, coin, key, slot, known, vals := vals.map some, role, final := true, retraction := false, recorded := known }

/-- The refmm input: a market exported by reference/mmdump (the stage 6 format) as resolved observations, with the
venue and policy. -/
def market (v : Value) : Array (Obs Float) × Meta × Venue Float × Policy × Int :=
  let f := (arr! (get! v "funding")).map fun r => let r := arr! r
    obs 0 (int! r[0]!).toNat (int! r[1]!) (int! r[2]!) none #[bits! r[3]!, bits! r[4]!] (some (.rate (bits! r[3]!)))
  let b := (arr! (get! v "bars")).map fun r => let r := arr! r
    obs 1 (int! r[0]!).toNat (int! r[2]!) (int! r[3]!) none #[bits! r[4]!, bits! r[5]!, bits! r[6]!, bits! r[7]!, bits! r[8]!]
      (some (.bar (bits! r[4]!) (bits! r[5]!) (bits! r[6]!) (bits! r[7]!) (int! r[9]!)))
  let e := (arr! (get! v "events")).map fun r => let r := arr! r
    obs ((int! r[0]!).toNat + 2) (int! r[1]!).toNat (int! r[2]!) (int! r[3]!) (some (int! r[2]!)) #[bits! r[4]!] none
  let iv := (arr! (get! v "intervals")).map fun r => let r := arr! r; (int! r[0]!, int! r[1]!)
  let ven := get! v "venue"
  let venue : Venue Float :=
    { takerFee := bits! (get! ven "taker_fee"), minNotional := bits! (get! ven "min_notional")
      szDecimals := (arr! (get! ven "sz_decimals")).map fun x => (int! x).toNat
      minTierLeverage := (arr! (get! ven "min_tier_leverage")).map bits!
      costBps := (arr! (get! ven "cost_bps")).map fun c => (arr! c).map fun s => (arr! s).map bits! }
  let pol := get! v "policy"
  (f ++ b ++ e, admissionMeta ((arr! (get! v "present")).toList.map fun x => (int! x).toNat) iv, venue,
   { delta := int! (get! pol "delta"), wStart := int! (get! pol "w_start") }, int! (get! pol "end"))

def loader (os : Array (Obs Float)) : Loader Float := { rows := fun _ => [], resolve := fun _ => some os }

def str! : Value → String
  | .str s => s
  | _ => panic! "expected a string"

def strs! (v : Value) : List String := (arr! v).toList.map str!

/-- A declaration as admission reads it: the case's own decoding of its file; no fields, which `stage1` does not read,
and the rule the generator writes (a time column, `fetchedAt`, every dependency), for `Registry.valid`. -/
def caseDecl (v : Value) : Decl :=
  let cadence := match str! (get! v "cadence") with | "event" => Cadence.event | "evidence" => .evidence | _ => .held
  let deps : List Dep := (arr! (get! v "deps")).toList.map fun d => let d := arr! d
    ⟨(arr! d[0]!).toList.map fun u => (int! u).toNat, str! d[1]!, int! d[2]!⟩
  let times := strs! (get! v "times")
  { hash := str! (get! v "hash"), fields := #[], times, eventColumn := str! (get! v "event"),
    slotColumn := match get! v "slot" with | .str s => some s | _ => none, entityColumns := strs! (get! v "entity"),
    revisionColumns := strs! (get! v "revision"), cadence, deps
    rule := .max (.field times.head! :: .field "fetchedAt" :: deps.map (.dep ·.name))
    roles := (arr! (get! v "roles")).toList.map fun r => let r := arr! r
      (if str! r[0]! == "bars" then .bars else .settlement,
       (arr! r[1]!).toList.map fun c => let c := arr! c; (str! c[0]!, str! c[1]!)) }

/-- One admission case's outcome: `Registry.valid` (`mm` refuses such a declaration when parsing), then `admit` with a
loader whose resolution fails, so passing positions 1 to 5 is refusal 6; then `stage1`'s required set. -/
def admitCase (v : Value) : String :=
  let reg : Registry := { decls := (arr! (get! v "decls")).map caseDecl }
  let rs := arr! (get! v "roles")
  let roles : Roles := ⟨(int! rs[0]!).toNat, (int! rs[1]!).toNat⟩
  let p : Program := { nodes := (arr! (get! v "sources")).map fun s => .input ⟨(int! s).toNat, 0, false, Dim.one⟩
                       types := #[], params := #[], convTo := #[], weight := 0, prediction := none }
  let bs := (arr! (get! v "bindings")).toList.map fun b => let b := arr! b; ((int! b[0]!).toNat, (⟨str! b[1]!, str! b[2]!⟩ : Binding))
  let certs := (arr! (get! v "certs")).toList.map fun k =>
    ({ id := str! (get! k "id"), decl := str! (get! k "decl"), manifest := str! (get! k "manifest")
       policy := str! (get! k "policy"), verifier := str! (get! k "verifier"), upstream := strs! (get! k "upstream")
       grants := [], controls := strs! (get! k "controls"), venueState := match get! k "venueState" with | .bool b => b | _ => false } : Cert)
  let adm : Meta :=
    { bindings := fun s => (bs.find? (·.1 == s)).map (·.2), certs
      supersessions := (arr! (get! v "supersessions")).toList.map fun x => let x := arr! x; (str! x[0]!, (int! x[1]!).toNat)
      position := (int! (get! v "position")).toNat, policy := str! (get! v "policy"), verifier := str! (get! v "verifier")
      holdout := strs! (get! v "holdout"), holdoutStart := int! (get! v "holdoutStart"), intervals := #[], version := 0 }
  let mode := if str! (get! v "mode") == "search" then Mode.search else .holdout
  let rows := (arr! (get! v "rows")).toList.map fun r => let r := arr! r; ((int! r[0]!).toNat, int! r[1]!)
  let ld : Loader Float := { rows := fun req => req.flatMap fun s => rows.filter (·.1 == s), resolve := fun _ => none }
  let venue : Venue Float := { takerFee := 0, minNotional := 0, szDecimals := #[], minTierLeverage := #[], costBps := #[] }
  if !reg.valid then "invalid 0" else
  match admit reg roles p adm ld venue ⟨1, 0⟩ 0 mode, stage1 reg roles p adm mode with
  | .error (6, .binding), .ok req => "ok " ++ ",".intercalate (req.map toString)
  | .error (k, a), _ => s!"{a.code} {k}"
  | .ok _, _ => "unreachable"

def fb (x : Float) : String := toString x.toBits.toNat

def eventJson : Ref.Event Float → String
  | .decision t c w q => s!"[\"decision\",{t},{c},{fb w},{fb q}]"
  | .hold t c why => s!"[\"hold\",{t},{c},\"{why}\"]"
  | .fill f =>
    let why := match f.why with | .fill => "fill" | .liquidation => "liquidation" | .delisting => "delisting"
    s!"[\"fill\",\"{why}\",{f.coin},{fb f.qty},{f.inputsKnown},{fb f.decisionPrice},{f.decided},{f.submitted},{f.filled},{f.sourceOpen},{fb f.reference},{fb f.price},{fb f.fee}]"
  | .unfilled t c q => s!"[\"unfilled\",{t},{c},{fb q}]"
  | .funding t c r p paid => s!"[\"funding\",{t},{c},{fb r},{fb p},{fb paid}]"
  | .equity t e r => s!"[\"equity\",{t},{fb e},{fb r}]"

def list (xs : Array String) : String := "[" ++ ",".intercalate xs.toList ++ "]"

def tyJson : Ty → String
  | .bool => "\"bool\""
  | .num u => "\"num:" ++ ",".intercalate (u.e.map toString) ++ "\""

/-- A value as bytes: 0 if undefined, else 1 and its eight bytes, low byte first. -/
def pushVal (b : ByteArray) : Option Float → ByteArray
  | none => b.push 0
  | some x => Id.run do
    let mut b := b.push 1
    for i in [0:8] do
      b := b.push (x.toBits >>> (8 * i).toUInt64).toUInt8
    return b

/-- One tick's node values (nodes in order, each coin in order) as bytes, and how many are defined. -/
def tickBytes (ms : MState Float) : ByteArray × Nat :=
  ms.vals.foldl (fun acc row => row.foldl (fun (b, n) x => (pushVal b x, if x.isSome then n + 1 else n)) acc) (ByteArray.empty, 0)

/-- Every node's value for every coin at every tick of the machine's schedule (wStart, then each hour of every
step: `Ctx.machineAfter`'s schedule over the run's steps), written to `h`; returns how many were defined. -/
def writeStreams (h : IO.FS.Handle) (c : Ctx Float) : IO (Except Abort Nat) := do
  let pol := c.pol
  let p := c.p
  let mut s ← match c.start floatOps with
    | .error a => return .error a
    | .ok s => pure s
  let (b0, n0) := tickBytes s.machine
  h.write b0
  let mut n := n0
  for k in [1:4 * c.bounds.length + 1] do
    let hr := pol.wStart + (k : Int) * HOUR
    match c.deliver s (hr + pol.delta) with
    | .error a => return .error a
    | .ok s' => s := { s' with machine := s'.machine.tick floatOps p (c.mask hr) hr }
    let (b, d) := tickBytes s.machine
    h.write b
    n := n + d
  return .ok n

/-! `refmm resolve`: the resolver's cases (kernel/RULES.md §7, revision of 2026-11-04 B3). This decoding layer is new
code, not frozen Lean: it reads every text of a case by RULES.md §1 itself, reusing `Ref.Json`'s string reader and
binary64 rounding so an integer token of any size stays an integer, maps it to cells by §7, and runs the frozen
`timeline` and `resolveAll`. -/

/-- A RULES.md §1 value: integers exact, a non-integer as its binary64 bits (none if it rounds to infinity). -/
inductive J where
  | null
  | bool (b : Bool)
  | int (i : Int)
  | real (bits : Option UInt64)
  | str (s : String)
  | arr (xs : Array J)
  | obj (kvs : Array (String × J))
  deriving Inhabited

/-- The binary64 bits nearest (-1)^neg · m · 10^e, bounding the exponent before `decimalBits` computes 10^e. -/
def realBits (neg : Bool) (m : Nat) (e : Int) : Option UInt64 :=
  let n : Int := (toString m).length
  if m == 0 || n + e < -400 then some (if neg then 0x8000000000000000 else 0)
  else if n + e > 400 then none
  else decimalBits neg m e

def rnumber : Parser J := do
  let neg := (← peek) == some '-'
  if neg then discard next
  let int ← digits
  if int.isEmpty || (int.length > 1 && int.head? == some '0') then throw "bad number"
  let mut frac := []
  let mut real := false
  if (← peek) == some '.' then
    discard next
    frac ← digits
    if frac.isEmpty then throw "bad fraction"
    real := true
  let mut expo : Int := 0
  if (← peek) == some 'e' || (← peek) == some 'E' then
    discard next
    real := true
    let mut sgn : Int := 1
    if (← peek) == some '-' then
      discard next
      sgn := -1
    else if (← peek) == some '+' then
      discard next
    let d ← digits
    if d.isEmpty then throw "bad exponent"
    expo := sgn * natOf d
  if !real then return .int (if neg then -(natOf int : Int) else natOf int)
  return .real (realBits neg (natOf (int ++ frac)) (expo - frac.length))

/-- A value at `depth` (the outermost is 1; RULES.md §1 refuses a container deeper than 64). -/
partial def rvalue (depth : Nat) : Parser J := do
  ws
  match ← peek with
  | some '{' =>
    if depth > 64 then throw "too deep"
    discard next; ws
    if (← peek) == some '}' then discard next; return .obj #[]
    let mut kvs := #[]
    repeat
      ws; expect '"'
      let k ← strBody ""
      if kvs.any (·.1 == k) then throw "duplicate key"
      ws; expect ':'
      kvs := kvs.push (k, ← rvalue (depth + 1))
      ws
      match ← next with
      | ',' => pure ()
      | '}' => break
      | _ => throw "expected , or }"
    return .obj kvs
  | some '[' =>
    if depth > 64 then throw "too deep"
    discard next; ws
    if (← peek) == some ']' then discard next; return .arr #[]
    let mut xs := #[]
    repeat
      xs := xs.push (← rvalue (depth + 1))
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
  | some _ => rnumber
  | none => throw "unexpected end"

/-- A text's value, or none if it is malformed. -/
def rparse (text : String) : Option J :=
  match ((do let v ← rvalue 1; ws; return v) : Parser J).run text.toList with
  | .ok (v, []) => some v
  | _ => none

def J.cell : J → Option Cell
  | .null => some .null
  | .bool b => some (.bool b)
  | .int i => some (.int i)
  | .real (some b) => some (.num b)
  | .str s => some (.str s)
  | _ => none

def J.get? : J → String → Option J
  | .obj kvs, k => (kvs.find? (·.1 == k)).map (·.2)
  | _, _ => none

partial def ruleExpr : J → Option RuleExpr
  | .obj kvs => match kvs.toList with
    | [("field", .str n)] => if n.isEmpty then none else some (.field n)
    | [("dep", .str n)] => if n.isEmpty then none else some (.dep n)
    | [("ms", .int n)] => some (.ms n)
    | [("add", .arr xs)] => match xs.toList with
      | [t, d] => do pure (.add (← ruleExpr t) (← ruleExpr d))
      | _ => none
    | [("floor", .arr xs)] => match xs.toList with
      | [t, p] => do pure (.floor (← ruleExpr t) (← ruleExpr p))
      | _ => none
    | [("max", .arr xs)] => do pure (.max (← xs.toList.mapM ruleExpr))
    | _ => none
  | _ => none

/-- A rule document of version 1 (RULES.md §3), or none; checking is the frozen `Decl.ruleOk`. -/
def ruleDoc (text : String) : Option RuleExpr :=
  if text.utf8ByteSize > 65536 then none else
  match rparse text with
  | some (.obj kvs) => if kvs.size != 2 then none else
    match (J.obj kvs).get? "rule", (J.obj kvs).get? "expr" with
    | some (.int 1), some e => ruleExpr e
    | _, _ => none
  | _ => none

def hexPad (n : Nat) : String := let h := String.mk (Nat.toDigits 16 n); "".pushn '0' (4 - h.length) ++ h

def quote (s : String) : String :=
  "\"" ++ s.foldl (fun acc c => acc ++ (if c == '"' then "\\\"" else if c == '\\' then "\\\\"
    else if c.toNat < 0x20 then "\\u" ++ hexPad c.toNat else c.toString)) "" ++ "\""

/-- A binary64 number's exact decimal, with a fraction (`1.0`, `-0.0`), which every correctly rounding reader reads
back to the same bits. -/
def realText (b : UInt64) : String :=
  let sign := if b >>> 63 == 1 then "-" else ""
  let e := ((b >>> 52) &&& 0x7FF).toNat
  let f := (b &&& 0xFFFFFFFFFFFFF).toNat
  let (m, ex) : Nat × Int := if e == 0 then (f, -1074) else (f + 2 ^ 52, (e : Int) - 1075)
  if ex ≥ 0 then s!"{sign}{m * 2 ^ ex.toNat}.0" else
  let k := (-ex).toNat
  let ds := toString (m * 5 ^ k)
  let ds := "".pushn '0' (k + 1 - ds.length) ++ ds
  let whole := String.mk (ds.toList.take (ds.length - k))
  let frac := (ds.toList.drop (ds.length - k)).reverse.dropWhile (· == '0') |>.reverse
  s!"{sign}{whole}.{if frac.isEmpty then "0" else String.mk frac}"

def cellJson : Cell → String
  | .int i => toString i
  | .num b => realText b
  | .str s => quote s
  | .bool b => toString b
  | .null => "null"

def opt {α : Type} (f : α → String) : Option α → String
  | some x => f x
  | none => "null"

/-- Cells ordered as §7 sorts keys: null, booleans, integers, non-integers, strings; numbers by value. -/
def cellCmp (a b : Cell) : Ordering :=
  let rank : Cell → Nat := fun | .null => 0 | .bool _ => 1 | .int _ => 2 | .num _ => 3 | .str _ => 4
  match a, b with
  | .int x, .int y => compare x y
  | .num x, .num y => let (x, y) := (Float.ofBits x, Float.ofBits y); if x < y then .lt else if y < x then .gt else .eq
  | .str x, .str y => compare x y
  | .bool x, .bool y => compare x.toNat y.toNat
  | _, _ => compare (rank a) (rank b)

def cellsCmp : List Cell → List Cell → Ordering
  | [], [] => .eq
  | [], _ => .lt
  | _, [] => .gt
  | a :: as, b :: bs => (cellCmp a b).then (cellsCmp as bs)

/-- A stored entity as `Revision.entity`: its cells' text, the two zeros as one. -/
def entityKey (cs : List Cell) : String :=
  ",".intercalate (cs.map fun | .num b => cellJson (.num (if b &&& 0x7FFFFFFFFFFFFFFF == 0 then 0 else b)) | c => cellJson c)

def bool! : Value → Bool
  | .bool b => b
  | _ => panic! "expected a boolean"

/-- A case's source: its name, declared columns (sorted) and role columns, and its declaration. -/
structure CaseSrc where
  name : String
  declared : List String
  roleCols : List String
  decl : Decl
  ruleOk : Bool
  deriving Inhabited

def caseSrc (names : Array String) (v : Value) : CaseSrc :=
  let idx (n : String) : Nat := (names.findIdx? (· == n)).getD names.size
  let name := str! (get! v "name")
  let times := strs! (get! v "times")
  let values := strs! (get! v "values")
  let entity := strs! (get! v "entity")
  let slot := match get! v "slot" with | .str c => some c | _ => none
  let roles : List (Role × List (String × String)) := match get! v "roles" with
    | .obj kvs => match kvs.toList with
      | [("bars", cols)] => [(.bars, ["open", "high", "low", "close", "trades"].zip (strs! cols))]
      | [("settlement", cols)] => [(.settlement, ["rate"].zip (strs! cols))]
      | _ => []
    | _ => []
  let roleCols := roles.flatMap (·.2.map (·.2))
  let rule := ruleDoc (str! (get! v "rule"))
  let decl : Decl :=
    { hash := "", fields := values.toArray.map fun c => (s!"{name}.{c}", c, Dim.one), times := "fetchedAt" :: times
      eventColumn := str! (get! v "event"), slotColumn := slot, entityColumns := entity, revisionColumns := []
      rule := rule.getD (.ms 0), roles
      cadence := if bool! (get! v "evidence") then .evidence else if slot.isSome then .event else .held
      deps := (arr! (get! v "deps")).toList.map fun d =>
        ⟨(strs! (get! d "sources")).map idx, str! (get! d "name"), int! (get! d "lag")⟩ }
  { name, roleCols, decl, ruleOk := rule.isSome && decl.ruleOk
    declared := (values ++ times ++ [decl.eventColumn] ++ slot.toList ++ entity ++ roleCols).eraseDups.mergeSort
      (· ≤ ·) }

/-- One eligible stored row as a `Revision` of source `s` by §7's JSON mapping, its entity's cells beside it; an
error if it does not decode (RULES.md §6, revision of 2026-11-04). -/
def caseRow (srcs : Array CaseSrc) (univ : List String) (s : Nat) (v : Value) : Except Unit (Revision × List Cell) := do
  let c := srcs[s]!
  let d := c.decl
  let some (.obj kvs) := rparse (str! (get! v "cells")) | throw ()
  let cells ← c.declared.filterMapM fun col => match (J.obj kvs).get? col with
    | none => pure none
    | some j => match j.cell with
      | some x => pure (some (col, x))
      | none => throw ()
  let event ← match cellAt cells d.eventColumn with
    | .int e => if inRange e then pure e else throw ()
    | _ => throw ()
  let ent := d.entityColumns.map (cellAt cells)
  let coin := if d.cadence == .evidence then none else match cellAt cells "coin" with
    | .str x => univ.idxOf? x
    | _ => none
  let upstream ← if d.deps.isEmpty then pure [] else
    match rparse (str! (get! v "upstream")) with
    | some (.obj ms) => ms.toList.mapM fun (dep, keys) => match keys with
      | J.arr ks => do
        let ks ← ks.toList.mapM fun k => match k with
          | J.arr #[J.str src, J.arr cs, J.int e] => do
            let some u := srcs.findIdx? (·.name == src) | throw ()
            if cs.size != srcs[u]!.decl.entityColumns.length || !inRange e then throw ()
            let some cs := cs.toList.mapM J.cell | throw ()
            pure (u, entityKey cs, e)
          | _ => throw ()
        pure (dep, ks)
      | _ => throw ()
    | _ => throw ()
  pure ({ entity := entityKey ent, coin, event, fetchedAt := int! (get! v "fetchedAt"), tombstone := bool! (get! v "tombstone")
          cells, upstream }, ent)

/-- A cell read as a number: an integer or a non-integer, as its binary64 value. -/
def numBits : Cell → Option UInt64
  | .int i => realBits (i < 0) i.natAbs 0
  | .num b => some b
  | _ => none

/-- A case's §7 result and, if it resolves, its observations by `resolveAll`, sorted by source name, coin, event time
and fetchedAt. -/
def resolveCase (v : Value) : String := Id.run do
  let univ := strs! (get! v "universe")
  let sv := arr! (get! v "sources")
  let names := sv.map fun s => str! (get! s "name")
  let srcs := sv.map (caseSrc names)
  let line (result obs : String) := s!"\{\"result\":{result},\"observations\":{obs}}"
  if !srcs.all (·.ruleOk) then return line "\"E_RULE\"" "null"
  let V := int! (get! v "version")
  let rows := (arr! (get! v "rows")).toList.filter fun r => decide (int! (get! r "fetchedAt") ≤ V)
  let decoded := rows.mapM fun r =>
    let s := (names.findIdx? (· == str! (get! r "source"))).get!
    (caseRow srcs univ s r).map ((s, ·))
  let .ok decoded := decoded | return line "\"INVALID\"" "null"
  let reg : Registry := { decls := srcs.map (·.decl) }
  let st : Stored := { rows := fun s => decoded.filterMap fun (u, r, _) => if u == s then some r else none
                       identity := fun _ => "" }
  let all := List.range srcs.size
  if !all.all (st.validAt · V) then return line "\"INVALID\"" "null"
  let queries := (arr! (get! v "queries")).toList.map int!
  let keys := (decoded.map fun (s, r, ent) => (s, ent, r.event)).eraseDups.mergeSort fun (s, a, e) (t, b, f) =>
    (compare srcs[s]!.name srcs[t]!.name |>.then (cellsCmp a b) |>.then (compare e f)) != .gt
  let keyJson := keys.map fun (s, ent, event) =>
    let c := srcs[s]!
    let d := c.decl
    let es := timeline reg st V (decodes numBits reg) srcs.size s (entityKey ent) event
    let coin := (decoded.find? fun (u, r, _) => u == s && r.entity == entityKey ent && r.event == event).bind (·.2.1.coin)
    let (_, entries) := es.foldl (fun (slot, out) e =>
      let slot := if e.retraction then slot else slotOf d e.rev
      let cells := if e.retraction then "null" else
        "{" ++ ",".intercalate (c.declared.map fun col => quote col ++ ":" ++ cellJson (cellAt e.rev.cells col)) ++ "}"
      let role := if e.retraction || c.roleCols.isEmpty then "null" else
        "[" ++ ",".intercalate (c.roleCols.map fun col => cellJson (cellAt e.rev.cells col)) ++ "]"
      (slot, out ++ [s!"[{e.rev.fetchedAt},{e.known},{e.retraction},{opt toString slot},{cells},{role}]"]))
      ((none : Option Int), ([] : List String))
    let visible := queries.map fun q => match (es.filter fun e => decide (e.known ≤ q)).getLast? with
      | some e => if e.retraction then "null" else toString e.rev.fetchedAt
      | none => "null"
    s!"\{\"source\":{quote c.name},\"entity\":[{",".intercalate (ent.map cellJson)}],\"event\":{event}," ++
      s!"\"coin\":{opt toString coin},\"timeline\":[{",".intercalate entries}],\"visible\":[{",".intercalate visible}]}"
  let obs := ((resolveAll numBits reg st V all).getD #[]).toList.mergeSort fun a b =>
    (compare srcs[a.source]!.name srcs[b.source]!.name |>.then (compare a.coin b.coin) |>.then (compare a.key b.key)
      |>.then (compare a.recorded b.recorded)) != .gt
  let obsJson := obs.map fun o =>
    let role := match o.role with
      | some (.bar op hi lo cl t) => s!"[{op},{hi},{lo},{cl},{t}]"
      | some (.rate r) => s!"[{r}]"
      | none => "null"
    s!"[{quote srcs[o.source]!.name},{o.coin},{o.key},{o.recorded},{o.known},{o.retraction},{opt toString o.slot}," ++
      s!"[{",".intercalate (o.vals.toList.map (opt toString))}],{role},{o.final}]"
  line s!"\{\"keys\":[{",".intercalate keyJson}]}" s!"[{",".intercalate obsJson}]"

def main (args : List String) : IO UInt32 := do
  match args with
  | ["check", path] =>
    match Ref.check registry.inputs (← IO.FS.readFile path) with
    | .ok _ => IO.println "ok"; return 0
    | .error c => IO.println c.name; return 1
  | ["run", programs, mkt, outDir] =>
    let some v := (Json.parse (← IO.FS.readFile mkt)).toOption.filter (·.uniqueKeys) | IO.eprintln "bad market"; return 3
    let (os, adm, venue, pol, stop) := market v
    let paths := (← IO.FS.readFile programs).splitOn "\n" |>.filter (· ≠ "")
    let mut i := 0
    for prog in paths do
      let streams : System.FilePath := outDir ++ s!"/{i}.bin"
      let result ← match Ref.check registry.inputs (← IO.FS.readFile prog) with
        | .error c => pure s!"\{\"reject\":\"{c.name}\"}"
        | .ok p => match admit registry roles p adm (loader os) venue pol stop .search with
          | .error (_, a) => pure s!"\{\"abort\":\"{a.code}\"}"
          | .ok c => match c.evaluate floatOps with
          | .error a => pure s!"\{\"abort\":\"{a.code}\"}"
          | .ok r => do
            let defined ← IO.FS.withFile streams .write fun h => writeStreams h c
            let nodes := match defined with
              | .ok n => s!"\{\"defined\":{n}}"
              | .error a => s!"\"{a.code}\""
            pure s!"\{\"trace\":{list (r.trace.map eventJson)},\"returns\":{list (r.returns.map fb)},\"gross_returns\":{list (r.grossReturns.map fb)},\"types\":{list (p.types.map tyJson)},\"nodes\":{nodes}}"
      IO.FS.writeFile (outDir ++ s!"/{i}.json") result
      i := i + 1
    return 0
  | ["bench", prog, mkt, reps] =>
    let some v := (Json.parse (← IO.FS.readFile mkt)).toOption.filter (·.uniqueKeys) | IO.eprintln "bad market"; return 3
    let (os, adm, venue, pol, stop) := market v
    let .ok p := Ref.check registry.inputs (← IO.FS.readFile prog) | IO.println "null"; return 0
    let .ok c := admit registry roles p adm (loader os) venue pol stop .search | IO.println "null"; return 0
    let mut ms := #[]
    for _ in [0:reps.toNat!] do
      let t0 ← IO.monoNanosNow
      let .ok r := c.evaluate floatOps | IO.println "null"; return 0
      if r.returns.isEmpty then IO.println "null"; return 0
      ms := ms.push (toString (((← IO.monoNanosNow) - t0).toFloat / 1e6))
    IO.println (list ms)
    return 0
  | ["admit", cases] =>
    let some v := (Json.parse (← IO.FS.readFile cases)).toOption.filter (·.uniqueKeys) | IO.eprintln "bad cases"; return 3
    for c in arr! v do
      IO.println (admitCase c)
    return 0
  | ["resolve", cases] =>
    let some v := (Json.parse (← IO.FS.readFile cases)).toOption | IO.eprintln "bad cases"; return 3
    for c in arr! v do
      IO.println (resolveCase c)
    return 0
  | _ => IO.eprintln "usage: refmm check PROGRAM | refmm run PROGRAMS MARKET OUT_DIR | refmm bench PROGRAM MARKET REPS | refmm admit CASES | refmm resolve CASES"; return 2
