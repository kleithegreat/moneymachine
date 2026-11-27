import Engine.Orders
import Engine.Ledger

/-!
# The account and its orders as one fold of effects (kernel-v2.md A1, A6; brief 3 step 5, wall 1 and 5)

An effect is any change the world makes to the account or its orders. The world applies each at its time and the
view applies the same function at the effect's time plus `δ`, so the view's copy is the world's, `δ` late.
-/

namespace Engine.World

open Engine.Orders

/-- The fills of a cycle's opening order: its slot and placement time identify it, and its summed size and notional. -/
structure Opening where
  slot : Nat
  placed : Int
  size : Rat
  notional : Rat
  deriving DecidableEq, Repr

/-- The ledger, the live orders, each coin's cycle and each slot's fills in it, and each coin's opening order. -/
structure Acct where
  ledger : Engine.Ledger.State
  orders : List Order
  cycles : List Nat
  filled : List (List Rat)
  openings : List (Option Opening)
  deriving DecidableEq, Repr

def Acct.initial (cash : Rat) (coins : Nat) : Acct :=
  ⟨Engine.Ledger.initial cash coins, [], List.replicate coins 1, List.replicate coins [],
    List.replicate coins none⟩

def Acct.position (a : Acct) (coin : Nat) : Rat := (Engine.Ledger.position a.ledger coin).units

def Acct.cycle (a : Acct) (coin : Nat) : Nat := a.cycles.getD coin 1

def Acct.filledAt (a : Acct) (coin slot : Nat) : Rat := (a.filled.getD coin []).getD slot 0

/-- What of the position a side's order would reduce. -/
def Acct.reducible (a : Acct) (side : Side) (coin : Nat) : Rat :=
  match side with
  | .sell => max 0 (a.position coin)
  | .buy => max 0 (-a.position coin)

/-- What an order may still fill (A6): its target less its slot's fills this cycle, never below zero, and for `close`
what it would reduce; a `reduce_only` order's is at most that. -/
def Acct.remainder (a : Acct) (o : Order) : Rat :=
  match o.target with
  | some target =>
    let remaining := max 0 (target - a.filledAt o.coin o.slot)
    if o.reduceOnly then min remaining (a.reducible o.side o.coin) else remaining
  | none => a.reducible o.side o.coin

/-- The live order of a slot on a coin. -/
def Acct.live (a : Acct) (coin slot : Nat) : Option Order :=
  a.orders.find? fun o => o.coin == coin && o.slot == slot

def replaceAt {α : Type} (l : List α) (i : Nat) (f : α → α) : List α :=
  match l, i with
  | [], _ => []
  | x :: rest, 0 => f x :: rest
  | x :: rest, i + 1 => x :: replaceAt rest i f

def setRow (row : List Rat) (slot : Nat) (v : Rat) : List Rat :=
  (row ++ List.replicate (slot + 1 - row.length) 0).set slot v

inductive Effect where
  | placed (o : Order)
  | refused (o : Order) (reason : String)
  | cancelled (o : Order) (cause : String)
  | fill (o : Order) (units price : Rat) (role : Engine.Ledger.Role)
  | cycleEnd (coin cycle : Nat)
  deriving DecidableEq, Repr

/-- One fill's figures for its order's opening record: the first fill that finds the position at zero starts it, and
the same order's later fills add to it. -/
def Acct.opened (a : Acct) (o : Order) (units price : Rat) : Option Opening :=
  match a.openings.getD o.coin none with
  | some op =>
    if op.slot = o.slot && op.placed == o.placed then
      some { op with size := op.size + absQ units, notional := op.notional + absQ units * price }
    else some op
  | none =>
    if a.position o.coin = 0 then some ⟨o.slot, o.placed, absQ units, absQ units * price⟩ else none

/-- The account after an effect at `time`, under the fee schedule. -/
def Acct.apply (fees : List Engine.Ledger.Tier) (time : Int) (a : Acct) : Effect → Acct
  | .placed o => { a with orders := a.orders ++ [o] }
  | .refused _ _ => a
  | .cancelled o _ => { a with orders := a.orders.filter fun x => !(x.coin == o.coin && x.slot == o.slot) }
  | .fill o units price role =>
    let ledger := match Engine.Ledger.step fees a.ledger (.fill time o.coin units price role) with
      | .ok receipt => receipt.state
      | .error _ => a.ledger
    let opening := a.opened o units price
    let a' : Acct :=
      { a with ledger := ledger,
               filled := replaceAt a.filled o.coin fun row => setRow row o.slot (a.filledAt o.coin o.slot + absQ units),
               openings := replaceAt a.openings o.coin fun _ => opening }
    { a' with orders := a'.orders.filter fun x => !(x.coin == o.coin && x.slot == o.slot && a'.remainder x = 0) }
  | .cycleEnd coin cycle =>
    { a with cycles := replaceAt a.cycles coin (fun _ => cycle + 1), filled := replaceAt a.filled coin fun _ => [],
             orders := a.orders.filter fun x => x.coin != coin, openings := replaceAt a.openings coin fun _ => none }

end Engine.World
