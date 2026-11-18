import Engine.MachineCore
import Engine.Lang.Syntax

/-!
# `start` (KERNEL.md A17, A18)

The program and the market's header, read strictly: an unknown field, a missing one, a repeated key or a value
of the wrong type is a fault. A fault of the program is `E_PARSE`, of the header `E_HEADER`, of the venue
`E_VENUE`, and a horizon that meets an unreleased protected window `R_PROTECTED` (A13).
-/

namespace Engine.Machine

open Engine.Json

/-- A decimal string `-?digits(.digits)?` as the integer of its digits and the count of places after the point. -/
def placedOf (text : String) : Option (Int × Nat) :=
  let (negative, chars) := match chars text with
    | '-' :: rest => (true, rest)
    | rest => (false, rest)
  let (whole, rest) := chars.span isDigit
  let fraction? : Option (List Char) := match rest with
    | [] => some []
    | '.' :: fraction => if !fraction.isEmpty && fraction.all isDigit then some fraction else none
    | _ => none
  match fraction? with
  | none => none
  | some fraction =>
    if whole.isEmpty then none
    else
      let digits := (whole ++ fraction).foldl (fun n c => n * 10 + (c.toNat - '0'.toNat)) 0
      some ((if negative then -(digits : Int) else (digits : Int)), fraction.length)

def ratOf (text : String) : Option Rat :=
  (placedOf text).map fun (digits, places) => (digits : Rat) / (10 : Rat) ^ places

def headerError {α : Type} : Except String α := .error "E_HEADER"

def need {α : Type} (value : Option α) (code : String := "E_HEADER") : Except String α :=
  match value with
  | some v => .ok v
  | none => .error code

def intField (j : J) (key : String) : Except String Int :=
  match j.field? key with
  | some (.int n) => .ok n
  | _ => headerError

def strField (j : J) (key : String) : Except String String :=
  match j.field? key with
  | some (.str s) => .ok s
  | _ => headerError

def ratField (j : J) (key : String) : Except String Rat := do
  let text ← strField j key
  need (ratOf text)

def nameOk (name : String) : Bool :=
  let cs := chars name
  !cs.isEmpty && cs.length ≤ 32 && cs.all (fun c => '!' ≤ c && c ≤ '~')

def parseTier (j : J) : Except String (Number × Int) := do
  unless j.keysAre ["from", "max_leverage"] [] do headerError
  let bound ← strField j "from"
  let (digits, places) ← need (placedOf bound)
  let leverage ← intField j "max_leverage"
  return (.placed digits places, leverage)

def parseCoin (j : J) : Except String (String × Rules) := do
  unless j.keysAre ["name", "sz_decimals", "figures", "decimals", "tiers"] [] do headerError
  let name ← strField j "name"
  unless nameOk name do headerError
  let sz ← intField j "sz_decimals"
  let figures ← intField j "figures"
  let decimals ← intField j "decimals"
  let tiers ← match j.field? "tiers" with
    | some (.arr ts) => ts.mapM parseTier
    | _ => headerError
  unless 0 ≤ sz && 0 ≤ figures do headerError
  let rules : Rules := ⟨sz.toNat, figures.toNat, decimals, tiers⟩
  if rules.figures = 0 || 8 < rules.decimals || 12 < rules.szDecimals || tiers.isEmpty ||
      tiersRise tiers none = false then headerError
  return (name, rules)

def parseFee (j : J) : Except String Engine.Ledger.Tier := do
  unless j.keysAre ["from", "tier", "maker", "taker"] [] do headerError
  let since ← intField j "from"
  let tier ← strField j "tier"
  let maker ← ratField j "maker"
  let taker ← ratField j "taker"
  unless 0 ≤ maker && maker ≤ 1 && 0 ≤ taker && taker ≤ 1 do headerError
  return ⟨since, tier, maker, taker⟩

def feesRise : List Engine.Ledger.Tier → Bool
  | a :: b :: rest => decide (a.start < b.start) && feesRise (b :: rest)
  | _ => true

/-- A source's encoding (A2): `string` is true, `double` false. -/
def encodingValue (j : J) : Except String Bool := do
  match ← strField j "encoding" with
  | "string" => .ok true
  | "double" => .ok false
  | _ => headerError

def encodingOf (j : J) : Except String Bool := do
  unless j.keysAre ["encoding"] [] do headerError
  encodingValue j

def parseObservation (j : J) : Except String Observation := do
  unless j.keysAre ["name", "unit", "kind", "lag"] [] do headerError
  let name ← strField j "name"
  let unit ← strField j "unit"
  let lag ← intField j "lag"
  unless 0 ≤ lag && Engine.Lang.validName name && !Engine.Lang.inputNames.contains name &&
      (Engine.Lang.Dim.parse unit).isSome do headerError
  let flow ← match ← strField j "kind" with
    | "state" => .ok false
    | "flow" => .ok true
    | _ => headerError
  return ⟨name, unit, flow, lag⟩

def parseAliases (j : J) : Except String (List (String × String)) := do
  unless j.keysAre ["coins", "sources"] [] do headerError
  let table (key : String) : Except String (List (String × String)) :=
    match j.field? key with
    | some (.obj ms) => ms.mapM fun m => match m.2 with
      | .str s => .ok (m.1, s)
      | _ => headerError
    | _ => headerError
  let coins ← table "coins"
  let _ ← table "sources"
  return coins

/-- The market's header (A18). -/
def parseHeader (text : String) : Except String Config := do
  let j ← match parse text with
    | .ok j => .ok j
    | .error _ => headerError
  unless j.keysAre ["horizon", "venue", "cash", "coins", "fees", "sources", "aliases"] [] do headerError
  let horizon ← need (j.field? "horizon")
  unless horizon.keysAre ["start", "end"] [] do headerError
  let start ← intField horizon "start"
  let stop ← intField horizon "end"
  unless start < stop do headerError
  let venue ← need (j.field? "venue")
  unless venue.keysAre ["fill", "lambda", "delta", "stale", "cap", "minimum"] [] do headerError
  let fill ← strField venue "fill"
  unless fill == "optimistic" || fill == "pessimistic" do headerError
  let lambda ← intField venue "lambda"
  let delta ← intField venue "delta"
  let gap ← intField venue "stale"
  let cap ← ratField venue "cap"
  let minimum ← ratField venue "minimum"
  let cash ← ratField j "cash"
  unless 0 < cash do headerError
  let coins ← match j.field? "coins" with
    | some (.arr cs) => cs.mapM parseCoin
    | _ => headerError
  if coins.isEmpty || coins.length > 65535 then headerError
  let rawNames := coins.map (·.1)
  unless rawNames.eraseDups.length == rawNames.length do headerError
  let fees ← match j.field? "fees" with
    | some (.arr fs) => fs.mapM parseFee
    | _ => headerError
  match fees with
  | [] => headerError
  | first :: _ => unless first.start ≤ start && feesRise fees do headerError
  let sources ← need (j.field? "sources")
  unless sources.keysAre ["listings", "funding"] ["quotes", "trades", "observations"] do headerError
  let listings ← need (sources.field? "listings")
  unless listings.keysAre ["lag"] [] do headerError
  let listingLag ← intField listings "lag"
  let funding ← need (sources.field? "funding")
  unless funding.keysAre ["encoding", "lag", "late"] [] do headerError
  let fundingString ← encodingValue funding
  let fundingLag ← intField funding "lag"
  let fundingLate ← intField funding "late"
  unless 0 ≤ listingLag && 0 ≤ fundingLag && 0 ≤ fundingLate && fundingLate < 3600000 do headerError
  let quotes ← match sources.field? "quotes" with
    | some q => do let e ← encodingOf q; pure (some e)
    | none => pure none
  let trades ← match sources.field? "trades" with
    | some q => do let e ← encodingOf q; pure (some e)
    | none => pure none
  let observations ← match sources.field? "observations" with
    | some (.arr os) => os.mapM parseObservation
    | none => pure []
    | _ => headerError
  unless (observations.map (·.name)).eraseDups.length == observations.length do headerError
  let aliases ← parseAliases (← need (j.field? "aliases"))
  unless (aliases.map (·.2)).eraseDups.length == aliases.length do headerError
  unless aliases.all (fun a => rawNames.contains a.1) do headerError
  unless (rawNames.map fun n => ((aliases.find? (·.1 == n)).map (·.2)).getD n).eraseDups.length ==
      rawNames.length do headerError
  unless 0 ≤ lambda && 0 ≤ delta && 1 ≤ gap && 0 < cap && 0 ≤ minimum do .error "E_VENUE"
  if fill == "pessimistic" && quotes.isSome && trades.isNone then .error "E_VENUE"
  return {
    start := start, stop := stop, pessimistic := fill == "pessimistic", lambda := lambda, delta := delta,
    gap := gap, cap := cap, minimum := minimum, cash := cash,
    names := rawNames.map fun n => ((aliases.find? (·.1 == n)).map (·.2)).getD n,
    initialRules := coins.map (·.2),
    fees := fees, listingLag := listingLag, fundingString := fundingString, fundingLag := fundingLag,
    fundingLate := fundingLate, quotes := quotes, trades := trades, observations := observations,
    tickMs := none }

def meetsProtected (cfg : Config) : Bool :=
  windows.any fun w => !w.released && decide (w.start < cfg.stop) && decide (cfg.start < w.stop)

/-- The header declares a source under a name and a unit, units compared canonically (A17). -/
def Config.declaresSource (cfg : Config) (name unit : String) : Bool :=
  cfg.observations.any fun o =>
    o.name == name && (Engine.Lang.Dim.parse o.unit).map Engine.Lang.Dim.canon == some unit

/-- The header with its declared sources renamed. -/
def Config.rename (ρ : String → String) (cfg : Config) : Config :=
  { cfg with observations := cfg.observations.map fun o => { o with name := ρ o.name } }

/-- `start`'s preflight against the market: a source the program declares that the header does not, or `traded`
on a market with no trade source (A5, A17). -/
def bind (p : Engine.Lang.Program) (cfg : Config) : Except String Unit :=
  if p.declared.any (fun d => !cfg.declaresSource d.1 d.2) || (p.readsTraded && cfg.trades.isNone) then
    .error "E_UNKNOWN_INPUT"
  else .ok ()

def greatestLeverage (rules : Rules) : Int := rules.tiers.foldl (fun m t => max m t.2) 0

/-- A program's leverage against the coins' tiers (A17): at most each coin's greatest, and by coin it names
exactly the market's coins. -/
def leverageOk (p : Engine.Lang.Program) (cfg : Config) : Bool :=
  match p.leverage with
  | .all n => cfg.initialRules.all fun r => decide ((n : Int) ≤ greatestLeverage r)
  | .byCoin entries =>
    entries.length == cfg.names.length && (entries.map (·.1)).eraseDups.length == entries.length &&
      (cfg.names.zip cfg.initialRules).all fun (name, r) =>
        match entries.find? (·.1 == name) with
        | some (_, n) => decide ((n : Int) ≤ greatestLeverage r)
        | none => false

/-- What `start` checks of a program and a header before it binds the two. -/
def prepare (program header : String) : Except String (Engine.Lang.Program × Config) := do
  let p ← Engine.Lang.parse program
  let cfg ← parseHeader header
  if meetsProtected cfg then .error "R_PROTECTED"
  else if !leverageOk p cfg then .error "E_LEVERAGE"
  else return (p, cfg)

def startBeforeBind (program header : String) : Except String Unit := (prepare program header).map fun _ => ()

def initialState (cfg : Config) (prog : Option Engine.Lang.Program) (tick : Option Int) : State :=
  let first := tick.map fun ms => (cfg.start + ms - 1) / ms * ms
  { cfg := { cfg with tickMs := tick }, count := 0, previous := none, ids := [], ended := [],
    rules := cfg.initialRules, coins := cfg.names.map fun _ => CoinState.fresh, nextTick := first,
    traceLines := 0, rejected := none, prog := prog, pending := [],
    view := cfg.names.map fun _ => ViewCoin.fresh cfg.observations.length,
    mach := Engine.Lang.Mach.init Engine.Lang.bitsOps (prog.getD default) cfg.names.length,
    acct := Engine.World.Acct.initial cfg.cash cfg.names.length, vacct := Engine.World.Acct.initial cfg.cash cfg.names.length,
    veffects := [], wishes := [], vage := cfg.names.map fun _ => none, log := none }

/-- A run's first state: every coin listed with its header's rules, no event admitted, the clock at its first tick. -/
def start (program header : String) : Except String State := do
  let (p, cfg) ← prepare program header
  bind p cfg
  return initialState cfg (some p) (some ((p.tick : Int) * 1000))

/-- An admission-only run: no program, no clock, no view. -/
def startAdmission (header : String) : Except String State := do
  let cfg ← parseHeader header
  if meetsProtected cfg then .error "R_PROTECTED" else return initialState cfg none none

end Engine.Machine
