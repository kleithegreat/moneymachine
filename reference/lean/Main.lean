import Ref

/-!
refmm: the Lean reference kernel's executable, on binary64.
  refmm check PROGRAM                 the verdict: `ok` or the rejection code
  refmm run PROGRAMS MARKET OUT_DIR   on a market exported by reference/mmdump, each program listed in PROGRAMS
                                      (one path per line): the i-th's output to OUT_DIR/i.json, its node streams to
                                      OUT_DIR/i.bin
  refmm bench PROGRAM MARKET REPS     evaluator-only milliseconds of REPS runs (`null` if not completed)
                                      written in mmdump's format (every float as its bits)
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
    slotColumn := if cadence == .event then some "slot" else none, entityColumn := "coin", revisionColumns := [],
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
  | _ => IO.eprintln "usage: refmm check PROGRAM | refmm run PROGRAMS MARKET OUT_DIR | refmm bench PROGRAM MARKET REPS"; return 2
