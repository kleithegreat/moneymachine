import Ref

/-!
refmm: the Lean reference kernel's executable, on binary64.
  refmm check PROGRAM                 the verdict: `ok` or the rejection code
  refmm run PROGRAM MARKET OUT        the run on a market exported by reference/mmdump, its trace
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

def market (v : Value) : Market Float × Venue Float × Policy × Int :=
  let f := (arr! (get! v "funding")).map fun r => let r := arr! r
    ({ coin := (int! r[0]!).toNat, event := int! r[1]!, known := int! r[2]!, rate := bits! r[3]!, premium := bits! r[4]! } : FundingRow Float)
  let b := (arr! (get! v "bars")).map fun r => let r := arr! r
    ({ coin := (int! r[0]!).toNat, openTime := int! r[1]!, event := int! r[2]!, known := int! r[3]!, o := bits! r[4]!,
       h := bits! r[5]!, l := bits! r[6]!, c := bits! r[7]!, v := bits! r[8]!, trades := int! r[9]! } : BarRow Float)
  let e := (arr! (get! v "events")).map fun r => let r := arr! r
    ({ slot := (int! r[0]!).toNat, coin := (int! r[1]!).toNat, event := int! r[2]!, known := int! r[3]!, count := bits! r[4]! } : EventRow Float)
  let iv := (arr! (get! v "intervals")).map fun r => let r := arr! r; (int! r[0]!, int! r[1]!)
  let ven := get! v "venue"
  let venue : Venue Float :=
    { takerFee := bits! (get! ven "taker_fee"), minNotional := bits! (get! ven "min_notional")
      szDecimals := (arr! (get! ven "sz_decimals")).map fun x => (int! x).toNat
      minTierLeverage := (arr! (get! ven "min_tier_leverage")).map bits!
      costBps := (arr! (get! ven "cost_bps")).map fun c => (arr! c).map fun s => (arr! s).map bits! }
  let pol := get! v "policy"
  ({ funding := f, bars := b, events := e, present := (arr! (get! v "present")).toList.map fun x => (int! x).toNat, intervals := iv },
   venue, { delta := int! (get! pol "delta"), wStart := int! (get! pol "w_start") }, int! (get! pol "end"))

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

def main (args : List String) : IO UInt32 := do
  match args with
  | ["check", path] =>
    match Ref.check (← IO.FS.readFile path) with
    | .ok _ => IO.println "ok"; return 0
    | .error c => IO.println c.name; return 1
  | ["run", prog, mkt, out] =>
    let some v := (Json.parse (← IO.FS.readFile mkt)).toOption | IO.eprintln "bad market"; return 3
    let (m, venue, pol, stop) := market v
    let result := match Ref.check (← IO.FS.readFile prog) with
      | .error c => s!"\{\"reject\":\"{c.name}\"}"
      | .ok p => match Ref.run floatOps p m venue pol stop with
        | .error a => s!"\{\"abort\":\"{a.code}\"}"
        | .ok r => s!"\{\"trace\":{list (r.trace.map eventJson)},\"returns\":{list (r.returns.map fb)},\"gross_returns\":{list (r.grossReturns.map fb)}}"
    IO.FS.writeFile out result
    return 0
  | _ => IO.eprintln "usage: refmm check PROGRAM | refmm run PROGRAM MARKET OUT"; return 2
