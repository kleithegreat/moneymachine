import Engine.Ledger

namespace Engine.LedgerWire
open Engine.Ledger

/-- A reader over the space-separated tokens of a call's arguments. -/
abbrev Reader := StateT (List String) Option

def token : Reader String := fun
  | [] => none
  | t :: ts => some (t, ts)

def nat : Reader Nat := do
  let t ← token
  let some n := t.toNat? | failure
  pure n

def int : Reader Int := do
  let t ← token
  let some n := t.toInt? | failure
  pure n

def rat : Reader Rat := do
  let t ← token
  match t.splitOn "/" with
  | [n, d] =>
    let some num := n.toInt? | failure
    let some den := d.toNat? | failure
    if den = 0 then failure else pure (mkRat num den)
  | _ => failure

def times {α : Type} (p : Reader α) : Nat → Reader (List α)
  | 0 => pure []
  | n + 1 => do
    let x ← p
    let xs ← times p n
    pure (x :: xs)

def tier : Reader Tier := do
  let start ← int
  let name ← token
  let maker ← rat
  let taker ← rat
  pure { start, name, maker, taker }

def tiers : Reader (List Tier) := do
  let n ← nat
  times tier n

def state : Reader State := do
  let n ← nat
  let cash ← rat
  let positions ← times (do
    let units ← rat
    let cost ← rat
    pure ({ units, cost } : Position)) n
  let realized ← rat
  let fees ← rat
  let funding ← rat
  let absorbed ← rat
  let flag ← token
  let bankrupt ← match flag with
    | "true" => pure true
    | "false" => pure false
    | _ => failure
  pure { cash, positions, realized, fees, funding, absorbed, bankrupt }

def event : Reader Event := do
  match ← token with
  | "F" =>
    let time ← int
    let coin ← nat
    let units ← rat
    let price ← rat
    let role ← match ← token with
      | "M" => pure Role.maker
      | "T" => pure Role.taker
      | _ => failure
    pure (.fill time coin units price role)
  | "U" =>
    let time ← int
    let hour ← int
    let coin ← nat
    let oracle ← rat
    let rate ← rat
    pure (.funding time hour coin oracle rate)
  | "A" => pure .absorb
  | _ => failure

def showRat (r : Rat) : String := s!"{r.num}/{r.den}"

def showState (s : State) : List String :=
  [toString s.positions.length, showRat s.cash] ++
    s.positions.flatMap (fun p => [showRat p.units, showRat p.cost]) ++
    [showRat s.realized, showRat s.fees, showRat s.funding, showRat s.absorbed,
      toString s.bankrupt]

def showView (s : State) : List String :=
  [toString s.positions.length, showRat s.cash] ++
    (List.range s.positions.length).flatMap (fun i =>
      let p := position s i
      [showRat p.units, showRat p.cost, (entry s i).elim "none" showRat]) ++
    [showRat s.realized, showRat s.fees, showRat s.funding, showRat s.absorbed,
      toString s.bankrupt]

def showOption {α : Type} (render : α → String) : Option α → List String
  | none => ["none"]
  | some x => ["some", render x]

def showReceipt (r : Receipt) : List String :=
  [showRat r.fee, showRat r.closedPnl] ++ showOption id r.tier ++ showOption showRat r.rate ++
    showState r.state

def finish {α : Type} (render : α → List String) : Except String α → String
  | .error code => s!"error {code}"
  | .ok x => " ".intercalate ("ok" :: render x)

def parse {α : Type} (p : Reader α) (args : String) : Option α :=
  match (p.run (args.splitOn " ")) with
  | some (x, []) => some x
  | _ => none

/-- The `ledger_*` operations of the C stub: the arguments and the reply are space-separated
tokens, a rational `n/d`, a state as `showState` writes it. -/
def call (op : String) (args : String) : Option String :=
  match op with
  | "ledger_initial" => do
    let (cash, coins) ← parse (do pure ((← rat), (← nat))) args
    some (" ".intercalate ("ok" :: showState (initial cash coins)))
  | "ledger_view" => do
    let s ← parse state args
    some (" ".intercalate (showView s))
  | "ledger_equity" => do
    let (marks, s) ← parse (do
      let n ← nat
      let marks ← times rat n
      pure (marks, ← state)) args
    some (showRat (equity s marks))
  | "ledger_unrealized" => do
    let (marks, s) ← parse (do
      let n ← nat
      let marks ← times rat n
      pure (marks, ← state)) args
    some (showRat (unrealized s marks))
  | "ledger_step" => do
    let (fees, s, e) ← parse (do pure ((← tiers), (← state), (← event))) args
    some (finish showReceipt (step fees s e))
  | "ledger_replay" => do
    let (cash, coins, fees, events) ← parse (do
      let cash ← rat
      let coins ← nat
      let fees ← tiers
      let n ← nat
      pure (cash, coins, fees, ← times event n)) args
    some (finish (fun rs => toString rs.length :: rs.flatMap showReceipt)
      (replay cash coins fees events))
  | _ => none

end Engine.LedgerWire
