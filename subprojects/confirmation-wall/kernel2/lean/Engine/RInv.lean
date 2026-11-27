import Engine.WishOrder

/-!
# R1's invariants (brief 3 step 5; kernel-v2.md A6, A18)

What every state of a run keeps of its wishes, their arrival and the admissions they make, from which R1's streams follow.
-/

namespace Engine.Machine

open Engine.Orders (Wish Book Order Placement Arrival CycleStep OrderFill arrive cancelSlot admission admit)

/-- A18's order of two orders placed in one millisecond: a `reduce_only` first, then by coin and slot. -/
def KeyLt (x y : Bool × Nat × Nat) : Prop :=
  (x.1 = true ∧ y.1 = false) ∨ (x.1 = y.1 ∧ (x.2.1 < y.2.1 ∨ (x.2.1 = y.2.1 ∧ x.2.2 < y.2.2)))

def wishKey (w : Wish) : Bool × Nat × Nat := (w.reduceOnly, w.coin, w.slot)

def orderKey (o : Order) : Bool × Nat × Nat := (o.reduceOnly, o.coin, o.slot)

/-- One slot of one coin. -/
def SameSlot (coin slot : Nat) (w : Wish) : Bool := decide (w.coin = coin ∧ w.slot = slot)

/-- What R1 reads of a run, kept by every state of it: all that a log's lists and the queue say of one another. -/
structure RInv (c : Core) : Prop where
  sentArrives : ∀ l, c.log = some l → ∀ w ∈ l.wishes, w.arrives = w.sent + c.cfg.lambda
  sentBefore : ∀ l, c.log = some l → ∀ w ∈ l.wishes, ∀ t, c.nextTick = some t → w.sent < t
  sentPairs : ∀ l, c.log = some l → l.wishes.Pairwise fun a b =>
    a.coin = b.coin → a.slot = b.slot → a.sent < b.sent ∧ a.arrives < b.arrives
  queueBefore : ∀ w ∈ c.wishes, ∀ t, c.nextTick = some t → w.arrives < t + c.cfg.lambda
  queueSorted : c.wishes.Pairwise fun a b =>
    wishLe a b = true ∧ (a.arrives = b.arrives → (a.coin, a.slot) ≠ (b.coin, b.slot))
  fifo : ∀ l, c.log = some l → ∀ coin slot, l.wishes.filter (SameSlot coin slot) =
    (l.arrivals.map (·.wish)).filter (SameSlot coin slot) ++ c.wishes.filter (SameSlot coin slot)

end Engine.Machine
