import Engine.BInv

/-!
# S1's invariants (brief 3 step 5; kernel-v2.md A6, A7, A19)

What a run's log of steps, fills and placements says of the world's cycles: each step is what its trigger makes of the book,
cycles only rise and each end is a step, every placement and every fill is of a cycle at least as new as every step
logged before it, and a wish of a cycle after one's end was sent no sooner than the end's effect was known.
-/

namespace Engine.Machine

open Engine.World
open Engine.Orders (Wish Order Book Placement CycleStep OrderFill Trigger)

/-- A step is what its trigger makes of the book (S1, first conjunct). -/
def StepGood (st : CycleStep) : Prop :=
  st.ended = (match st.trigger with
    | .fill coin units => if st.before.position coin ≠ 0 ∧ st.before.position coin + units = 0 then [coin] else []
    | .liquidation => st.before.coins
    | .other => []) ∧
  (∀ coin ∈ st.before.coins, st.after.cycle coin = st.before.cycle coin + (if coin ∈ st.ended then 1 else 0)) ∧
  (∀ coin ∈ st.ended, st.after.position coin = 0 ∧ st.after.cycle coin = st.before.cycle coin + 1 ∧
    (∀ slot : Nat, st.after.filled coin slot = 0) ∧ (∀ o ∈ st.after.orders, o.coin ≠ coin))

/-- A fill takes no more than its target or what of the position its side reduces (S1, second conjunct). -/
def FillGood (f : OrderFill) : Prop :=
  let magnitude := if f.units < 0 then -f.units else f.units
  let reducible := match f.order.side with
    | .sell => max 0 (f.before.position f.order.coin)
    | .buy => max 0 (-f.before.position f.order.coin)
  (match f.order.target with
    | some target => f.before.filled f.order.coin f.order.slot + magnitude ≤ target
    | none => magnitude ≤ reducible) ∧
  (f.order.reduceOnly = true → magnitude ≤ reducible)

structure SInv (c : Core) : Prop where
  steps : ∀ l, c.log = some l → ∀ st ∈ l.steps, StepGood st
  mono : ∀ l, c.log = some l → ∀ st ∈ l.steps, ∀ k, st.after.cycle k ≤ c.acct.cycles.getD k 0
  chain : ∀ l, c.log = some l → l.steps.Pairwise fun a b => ∀ k ∈ a.ended, a.before.cycle k < b.before.cycle k
  times : ∀ l, c.log = some l → l.steps.Pairwise fun a b => a.ended ≠ [] → b.ended ≠ [] → a.time ≤ b.time
  prevTime : ∀ l, c.log = some l → ∀ st ∈ l.steps, st.ended ≠ [] → ∃ e, c.previous = some e ∧ st.time ≤ e.time
  exist : ∀ l, c.log = some l → ∀ k < c.cfg.names.length, ∀ K, 1 ≤ K → K < c.acct.cycles.getD k 0 →
    ∃ st ∈ l.steps, k ∈ st.ended ∧ st.before.cycle k = K
  endedLt : ∀ l, c.log = some l → ∀ st ∈ l.steps, ∀ k ∈ st.ended, k < c.cfg.names.length
  placedIdx : ∀ l, c.log = some l → ∀ p ∈ l.placed, ∀ (j : Nat) st, l.steps[j]? = some st → j < p.step →
    st.after.cycle p.order.coin ≤ p.order.cycle
  placedOwn : ∀ l, c.log = some l → ∀ p ∈ l.placed, ∃ st, l.steps[p.step]? = some st ∧ st.ended = []
  fillsIdx : ∀ l, c.log = some l → ∀ f ∈ l.fills, ∀ (j : Nat) st, l.steps[j]? = some st → j < f.step →
    st.after.cycle f.order.coin ≤ f.order.cycle
  fillsOwn : ∀ l, c.log = some l → ∀ f ∈ l.fills, f.step < l.steps.length
  fillsGood : ∀ l, c.log = some l → ∀ f ∈ l.fills, FillGood f

theorem sInv_congr {c c' : Core} (h : SInv c) (hn : c'.cfg.names.length = c.cfg.names.length)
    (hcy : c'.acct.cycles = c.acct.cycles) (hp : c'.previous = c.previous)
    (hl : c'.log.map (fun l => (l.steps, l.placed, l.fills)) = c.log.map (fun l => (l.steps, l.placed, l.fills))) : SInv c' := by
  have key : ∀ l', c'.log = some l' → ∃ l, c.log = some l ∧ l'.steps = l.steps ∧ l'.placed = l.placed ∧ l'.fills = l.fills := by
    intro l' hl'
    rw [hl'] at hl
    cases hc : c.log with
    | none => rw [hc] at hl; simp at hl
    | some l =>
      rw [hc] at hl
      simp only [Option.map_some, Option.some.injEq, Prod.mk.injEq] at hl
      exact ⟨l, rfl, hl.1, hl.2.1, hl.2.2⟩
  refine ⟨?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_⟩
  · intro l' hl'; obtain ⟨l, hlc, e1, _⟩ := key l' hl'; rw [e1]; exact h.steps l hlc
  · intro l' hl'; obtain ⟨l, hlc, e1, _⟩ := key l' hl'; rw [e1, hcy]; exact h.mono l hlc
  · intro l' hl'; obtain ⟨l, hlc, e1, _⟩ := key l' hl'; rw [e1]; exact h.chain l hlc
  · intro l' hl'; obtain ⟨l, hlc, e1, _⟩ := key l' hl'; rw [e1]; exact h.times l hlc
  · intro l' hl'; obtain ⟨l, hlc, e1, _⟩ := key l' hl'; rw [e1, hp]; exact h.prevTime l hlc
  · intro l' hl'; obtain ⟨l, hlc, e1, _⟩ := key l' hl'; rw [e1, hcy, hn]; exact h.exist l hlc
  · intro l' hl'; obtain ⟨l, hlc, e1, _⟩ := key l' hl'; rw [e1, hn]; exact h.endedLt l hlc
  · intro l' hl'; obtain ⟨l, hlc, e1, e2, _⟩ := key l' hl'; rw [e1, e2]; exact h.placedIdx l hlc
  · intro l' hl'; obtain ⟨l, hlc, e1, e2, _⟩ := key l' hl'; rw [e1, e2]; exact h.placedOwn l hlc
  · intro l' hl'; obtain ⟨l, hlc, e1, _, e3⟩ := key l' hl'; rw [e1, e3]; exact h.fillsIdx l hlc
  · intro l' hl'; obtain ⟨l, hlc, e1, _, e3⟩ := key l' hl'; rw [e1, e3]; exact h.fillsOwn l hlc
  · intro l' hl'; obtain ⟨l, hlc, _, _, e3⟩ := key l' hl'; rw [e3]; exact h.fillsGood l hlc

end Engine.Machine
