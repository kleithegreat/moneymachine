import Engine.Rules
import Engine.Orders.Value
import Engine.Exact

/-!
# The book, wishes, admission and arrival (kernel-v2.md A6)

The order and account part of the machine's state, and the pure functions that turn a wish into a placed order.
Every list of the book is indexed by coin number, and a missing entry reads as its neutral value, so the book has
decidable equality.
-/

namespace Engine.Orders

open Engine.Machine

instance : Inhabited Rules := ⟨⟨0, 0, 0, []⟩⟩

/-- A wish: a slot's exact value at a deciding tick, `none` for the inactive wish, sent at `sent`, arriving at `arrives`. -/
structure Wish where
  coin : Nat
  slot : Nat
  cycle : Nat
  side : Side
  value : Option Value
  sent : Int
  arrives : Int
  reduceOnly : Bool
  tif : String
  deriving DecidableEq, Repr

/-- A live order: rounded price and target, and the remainder the world still lets it fill. -/
structure Order where
  coin : Nat
  slot : Nat
  cycle : Nat
  side : Side
  price : Rat
  target : Option Rat
  remainder : Rat
  placed : Int
  reduceOnly : Bool
  tif : String
  deriving DecidableEq, Repr

/-- The account's orders and the numbers admission reads; each list is indexed by coin number (`fills` by coin, then slot). -/
structure Book where
  orders : List Order
  coins : List Nat
  ended : List Nat
  cycles : List Nat
  positions : List Rat
  fills : List (List Rat)
  ruleList : List Rules
  marks : List Rat
  leverages : List Nat
  takerRates : List Rat
  cash : Rat
  minimum : Rat
  cap : Rat
  deriving DecidableEq, Repr

/-- A book with no orders, no positions and every number neutral. -/
def Book.empty (coins : List Nat) : Book :=
  ⟨[], coins, [], [], [], [], [], [], [], [], 0, 0, 0⟩

/-- A coin's cycle, 0 when unknown. -/
def Book.cycle (b : Book) (c : Nat) : Nat := b.cycles.getD c 0

/-- A coin's signed position, 0 when unknown. -/
def Book.position (b : Book) (c : Nat) : Rat := b.positions.getD c 0

/-- What a slot has filled of a coin in its cycle, 0 when unknown. -/
def Book.filled (b : Book) (c slot : Nat) : Rat := (b.fills.getD c []).getD slot 0

/-- A coin's rules in force. -/
def Book.rules (b : Book) (c : Nat) : Rules := b.ruleList.getD c default

/-- A coin's mark, its adverse price (A10), 0 when unknown. -/
def Book.mark (b : Book) (c : Nat) : Rat := b.marks.getD c 0

/-- A coin's leverage, 1 when unknown. -/
def Book.leverage (b : Book) (c : Nat) : Nat := b.leverages.getD c 1

/-- A coin's taker rate, 0 when unknown. -/
def Book.takerRate (b : Book) (c : Nat) : Rat := b.takerRates.getD c 0

def absQ (x : Rat) : Rat := if x < 0 then -x else x

/-- The initial margin of the positions at the marks. -/
def Book.positionMargin (b : Book) : Rat :=
  b.coins.foldl (fun total c => total + absQ (b.position c) * b.mark c / (b.leverage c : Rat)) 0

/-- Cash and the positions at the marks. -/
def Book.equity (b : Book) : Rat :=
  b.cash + b.coins.foldl (fun total c => total + b.position c * b.mark c) 0

/-- One admission check: the book without the candidate, the candidate, and the world's numbers at this check. -/
structure Admission where
  book : Book
  order : Order
  positionMargin : Rat
  equity : Rat
  minimum : Rat
  cap : Rat
  leverage : Nat → Rat
  takerRate : Nat → Rat

def admission (b : Book) (o : Order) : Admission :=
  ⟨b, o, b.positionMargin, b.equity, b.minimum, b.cap, fun c => (b.leverage c : Rat), b.takerRate⟩

/-- A wish's price on its coin's grid. -/
def roundedPrice (rules : Rules) (side : Side) (price : Rat) : Rat :=
  match side with
  | .buy => Engine.Exact.roundPriceBuy rules.figures rules.decimals price
  | .sell => Engine.Exact.roundPriceSell rules.figures rules.decimals price

/-- A wish's target in lots. -/
def roundedTarget (rules : Rules) (value : Value) : Option Rat :=
  value.target.map (fun x => Engine.Exact.roundSize x (1 / (10 : Rat) ^ rules.szDecimals))

/-- The rounded order of a wish with its world remainder; `none` if the coin has ended, the wish is inactive or the remainder is zero. -/
def prepare (b : Book) (w : Wish) : Option Order :=
  if w.coin ∈ b.ended then none else
  match w.value with
  | none => none
  | some value =>
    let rules := b.rules w.coin
    let price := roundedPrice rules w.side value.price
    let target := roundedTarget rules value
    let reducible := match w.side with
      | .sell => max 0 (b.position w.coin)
      | .buy => max 0 (-b.position w.coin)
    let remainder := match target with
      | some x =>
        let remaining := max 0 (x - b.filled w.coin w.slot)
        if w.reduceOnly then min remaining reducible else remaining
      | none => reducible
    if remainder = 0 then none else
      some {coin := w.coin, slot := w.slot, cycle := w.cycle, side := w.side,
            price := price, target := target, remainder := remainder,
            placed := w.arrives, reduceOnly := w.reduceOnly, tif := w.tif}

/-- Removes the live order of a slot on a coin. -/
def cancelSlot (b : Book) (coin slot : Nat) : Book :=
  {b with orders := b.orders.filter (fun o => !(o.coin == coin && o.slot == slot))}

/-- Puts an order in the book, after the others. -/
def install (b : Book) (o : Order) : Book := {b with orders := b.orders ++ [o]}

def Order.signed (o : Order) : Rat := if o.side = .buy then o.remainder else -o.remainder

/-- What filling an order's remainder would add to the position's absolute size. -/
def Admission.opens (a : Admission) (o : Order) : Rat :=
  if o.reduceOnly then 0 else if a.book.position o.coin * o.signed < 0
  then max 0 (o.remainder - absQ (a.book.position o.coin)) else o.remainder

/-- The margin of the positions, of what every live order and the candidate open at their limits, and their taker fees. -/
def Admission.requirement (a : Admission) : Rat :=
  a.positionMargin + (a.book.orders ++ [a.order]).foldl (fun total o =>
    total + a.opens o * o.price * (1 / a.leverage o.coin + a.takerRate o.coin)) (0 : Rat)

def Admission.marginOk (a : Admission) : Prop := a.requirement ≤ a.equity

/-- The venue's minimum notional, waived for an order that only reduces and closes the position exactly. -/
def Admission.minimumOk (a : Admission) : Prop :=
  a.minimum ≤ a.order.remainder * a.order.price ∨
    ((a.order.reduceOnly = true ∨ a.order.target = none) ∧
      a.book.position a.order.coin + a.order.signed = 0)

def Admission.capOk (a : Admission) : Prop := a.order.remainder * a.order.price ≤ a.cap

instance (a : Admission) : Decidable a.marginOk := inferInstanceAs (Decidable (_ ≤ _))
instance (a : Admission) : Decidable a.minimumOk := inferInstanceAs (Decidable (_ ∨ _))
instance (a : Admission) : Decidable a.capOk := inferInstanceAs (Decidable (_ ≤ _))

/-- The candidate if it is admitted, else the first failing condition: margin, minimum, cap. -/
def admit (a : Admission) : Except String Order :=
  if ¬ a.marginOk then .error "margin"
  else if ¬ a.minimumOk then .error "minimum"
  else if ¬ a.capOk then .error "cap"
  else .ok a.order

/-- Whether a slot's live order already has the wish's rounded price and target. -/
def sameOrder (b : Book) (w : Wish) : Bool :=
  match w.value with
  | none => false
  | some value =>
    let rules := b.rules w.coin
    b.orders.any (fun o => o.coin == w.coin && o.slot == w.slot &&
      o.price == roundedPrice rules w.side value.price && o.target == roundedTarget rules value)

/-- A wish arriving at the book and its effects, one tag each in order. A wish of an ended coin or another cycle, or equal to the live order, changes nothing. -/
def arrive (b : Book) (w : Wish) : Book × List String :=
  if w.coin ∈ b.ended ∨ w.cycle ≠ b.cycle w.coin ∨ sameOrder b w = true then (b, []) else
  let cancelled := cancelSlot b w.coin w.slot
  let live := b.orders.any (fun o => o.coin == w.coin && o.slot == w.slot)
  let tags := if live then ["cancelled:replaced"] else []
  match prepare cancelled w with
  | none => (cancelled, tags)
  | some o =>
    match admit (admission cancelled o) with
    | .error reason => (cancelled, tags ++ ["refused:" ++ reason])
    | .ok admitted => (install cancelled admitted, tags ++ ["placed"])

structure Placement where
  order : Order
  value : Value
  rules : Rules
  step : Nat

structure Arrival where
  before : Book
  after : Book
  wish : Wish
  time : Int

inductive Trigger where
  | fill (coin : Nat) (units : Rat)
  | liquidation
  | other

structure CycleStep where
  before : Book
  after : Book
  trigger : Trigger
  time : Int
  ended : List Nat

structure OrderFill where
  order : Order
  before : Book
  units : Rat
  time : Int
  step : Nat

structure Run where
  placed : List Placement
  wishes : List Wish
  arrivals : List Arrival
  admissions : List Admission
  steps : List CycleStep
  fills : List OrderFill
  whenValues : List (Int × Nat × Nat × Option Bool)
  exactValues : List (Int × Nat × Nat × Option Rat)
  rows : Rows
  tickWorlds : List (Int × Nat × List (Option Rat))

theorem prepare_spec : ∀ (b : Book) (w : Wish),
      prepare b w = (if w.coin ∈ b.ended then none else match w.value with
        | none => none
        | some value =>
          let rules := b.rules w.coin
          let price := match w.side with
            | .buy => Engine.Exact.roundPriceBuy rules.figures rules.decimals value.price
            | .sell => Engine.Exact.roundPriceSell rules.figures rules.decimals value.price
          let target := value.target.map (fun x =>
            Engine.Exact.roundSize x (1 / (10 : Rat) ^ rules.szDecimals))
          let reducible := match w.side with
            | .sell => max 0 (b.position w.coin)
            | .buy => max 0 (-b.position w.coin)
          let remainder : Rat := match target with
            | some x =>
              let remaining := max 0 (x - b.filled w.coin w.slot)
              if w.reduceOnly then min remaining reducible else remaining
            | none => reducible
          if remainder = 0 then none else
            some {coin := w.coin, slot := w.slot, cycle := w.cycle, side := w.side,
                  price := price, target := target, remainder := remainder,
                  placed := w.arrives, reduceOnly := w.reduceOnly, tif := w.tif}) :=
  fun _ _ => rfl

theorem admission_spec :
    ∀ (b : Book) (o : Order), (admission b o).book = b ∧ (admission b o).order = o :=
  fun _ _ => ⟨rfl, rfl⟩

theorem sameOrder_iff (b : Book) (w : Wish) :
    sameOrder b w = true ↔ (match w.value with
        | none => False
        | some value =>
          let rules := b.rules w.coin
          let price := match w.side with
            | .buy => Engine.Exact.roundPriceBuy rules.figures rules.decimals value.price
            | .sell => Engine.Exact.roundPriceSell rules.figures rules.decimals value.price
          let target := value.target.map (fun x =>
            Engine.Exact.roundSize x (1 / (10 : Rat) ^ rules.szDecimals))
          ∃ o ∈ b.orders, o.coin = w.coin ∧ o.slot = w.slot ∧
            o.price = price ∧ o.target = target) := by
  unfold sameOrder
  cases w.value with
  | none => simp
  | some value =>
    simp only [List.any_eq_true, Bool.and_eq_true, beq_iff_eq, roundedPrice, roundedTarget]
    constructor
    · rintro ⟨o, ho, ⟨⟨h1, h2⟩, h3⟩, h4⟩
      exact ⟨o, ho, h1, h2, h3, h4⟩
    · rintro ⟨o, ho, h1, h2, h3, h4⟩
      exact ⟨o, ho, ⟨⟨h1, h2⟩, h3⟩, h4⟩

theorem arrive_ended : ∀ (b : Book) (w : Wish), w.cycle ≤ b.cycle w.coin →
    (w.coin ∈ b.ended → arrive b w = (b, [])) := by
  intro b w _ h
  simp [arrive, h]

theorem arrive_stale_cycle : ∀ (b : Book) (w : Wish), w.cycle ≤ b.cycle w.coin →
    (w.cycle ≠ b.cycle w.coin → arrive b w = (b, [])) := by
  intro b w _ h
  simp [arrive, h]

theorem arrive_same : ∀ (b : Book) (w : Wish), w.cycle ≤ b.cycle w.coin →
    (w.cycle = b.cycle w.coin →
      (match w.value with
        | none => False
        | some value =>
          let rules := b.rules w.coin
          let price := match w.side with
            | .buy => Engine.Exact.roundPriceBuy rules.figures rules.decimals value.price
            | .sell => Engine.Exact.roundPriceSell rules.figures rules.decimals value.price
          let target := value.target.map (fun x =>
            Engine.Exact.roundSize x (1 / (10 : Rat) ^ rules.szDecimals))
          ∃ o ∈ b.orders, o.coin = w.coin ∧ o.slot = w.slot ∧
            o.price = price ∧ o.target = target) → arrive b w = (b, [])) := by
  intro b w _ _ h
  rw [← sameOrder_iff] at h
  simp [arrive, h]

theorem arrive_replace : ∀ (b : Book) (w : Wish), w.cycle ≤ b.cycle w.coin →
    (w.coin ∉ b.ended → w.cycle = b.cycle w.coin →
      ¬ (match w.value with
        | none => False
        | some value =>
          let rules := b.rules w.coin
          let price := match w.side with
            | .buy => Engine.Exact.roundPriceBuy rules.figures rules.decimals value.price
            | .sell => Engine.Exact.roundPriceSell rules.figures rules.decimals value.price
          let target := value.target.map (fun x =>
            Engine.Exact.roundSize x (1 / (10 : Rat) ^ rules.szDecimals))
          ∃ o ∈ b.orders, o.coin = w.coin ∧ o.slot = w.slot ∧
            o.price = price ∧ o.target = target) →
      let cancelled := cancelSlot b w.coin w.slot
      (arrive b w).1 = (match prepare cancelled w with
        | none => cancelled
        | some o => match admit (admission cancelled o) with
          | .error _ => cancelled
          | .ok admitted => install cancelled admitted)) := by
  intro b w _ hend hcyc hsame
  rw [← sameOrder_iff] at hsame
  intro cancelled
  dsimp only [cancelled]
  have hc : ¬ (w.coin ∈ b.ended ∨ w.cycle ≠ b.cycle w.coin ∨ sameOrder b w = true) := by
    simp [hend, hcyc, hsame]
  simp only [arrive, hc, ↓reduceIte]
  cases hp : prepare (cancelSlot b w.coin w.slot) w with
  | none => simp
  | some o =>
    cases ha : admit (admission (cancelSlot b w.coin w.slot) o) <;> simp [ha]

theorem arrive_stale_before : ∀ (b : Book) (w : Wish), w.cycle < b.cycle w.coin →
    arrive b w = (b, []) := by
  intro b w h
  exact arrive_stale_cycle b w (Nat.le_of_lt h) (Nat.ne_of_lt h)

theorem admit_spec : ∀ a : Admission,
      let absQ := fun x : Rat => if x < 0 then -x else x
      let signed := fun o : Order => if o.side = .buy then o.remainder else -o.remainder
      let opens := fun o : Order =>
        if o.reduceOnly then 0 else if a.book.position o.coin * signed o < 0
        then max 0 (o.remainder - absQ (a.book.position o.coin)) else o.remainder
      let all := a.book.orders ++ [a.order]
      let requirement := a.positionMargin + all.foldl (fun total o =>
        total + opens o * o.price * (1 / a.leverage o.coin + a.takerRate o.coin)) (0 : Rat)
      let margin := requirement ≤ a.equity
      let minimum := a.minimum ≤ a.order.remainder * a.order.price ∨
        ((a.order.reduceOnly = true ∨ a.order.target = none) ∧
          a.book.position a.order.coin + signed a.order = 0)
      let cap := a.order.remainder * a.order.price ≤ a.cap
      0 < a.order.remainder → 0 < a.leverage a.order.coin →
        (admit a = .ok a.order ↔ margin ∧ minimum ∧ cap) ∧
        ((∃ reason : String, admit a = .error reason) ↔ ¬ (margin ∧ minimum ∧ cap)) ∧
        (admit a = .error "margin" → ¬ margin) ∧
        (admit a = .error "minimum" → ¬ minimum) ∧
        (admit a = .error "cap" → ¬ cap) ∧
        (∀ reason : String, admit a = .error reason → reason ∈ ["margin", "minimum", "cap"]) := by
  intro a _ _ _ _ _ margin minimum cap _ _
  show (admit a = .ok a.order ↔ a.marginOk ∧ a.minimumOk ∧ a.capOk) ∧
    ((∃ reason : String, admit a = .error reason) ↔ ¬ (a.marginOk ∧ a.minimumOk ∧ a.capOk)) ∧
    (admit a = .error "margin" → ¬ a.marginOk) ∧
    (admit a = .error "minimum" → ¬ a.minimumOk) ∧
    (admit a = .error "cap" → ¬ a.capOk) ∧
    (∀ reason : String, admit a = .error reason → reason ∈ ["margin", "minimum", "cap"])
  unfold admit
  by_cases h1 : a.marginOk <;> by_cases h2 : a.minimumOk <;> by_cases h3 : a.capOk <;>
    simp [h1, h2, h3]

end Engine.Orders
