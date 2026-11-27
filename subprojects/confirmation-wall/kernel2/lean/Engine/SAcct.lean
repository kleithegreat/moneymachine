import Engine.AcctLemmas

/-!
# S1's account invariants (brief 3 step 5)

The lengths of the account's lists, and that a live order is of its coin's current cycle.
-/

namespace Engine.Machine

open Engine.World
open Engine.Orders (Wish Order Book)

/-- The account keeps one entry for each coin. -/
def Shape (n : Nat) (a : Acct) : Prop :=
  a.ledger.positions.length = n ∧ a.cycles.length = n ∧ a.filled.length = n

/-- A live order is of its coin's current cycle. -/
def Live (a : Acct) : Prop := ∀ o ∈ a.orders, o.cycle = a.cycles.getD o.coin 0

theorem shape_apply {n : Nat} {a : Acct} (h : Shape n a) (fees : List Engine.Ledger.Tier) (time : Int) (e : Effect) :
    Shape n (a.apply fees time e) :=
  ⟨by rw [apply_ledger_length]; exact h.1, by rw [apply_cycles_length]; exact h.2.1, by rw [apply_filled_length]; exact h.2.2⟩

theorem shape_foldl {n : Nat} (fees : List Engine.Ledger.Tier) (time : Int) :
    ∀ (es : List Effect) (a : Acct), Shape n a → Shape n (es.foldl (fun a e => a.apply fees time e) a) := by
  intro es
  induction es with
  | nil => intro a h; exact h
  | cons e es ih => intro a h; exact ih _ (shape_apply h fees time e)

theorem live_apply {a : Acct} (h : Live a) (fees : List Engine.Ledger.Tier) (time : Int) (e : Effect)
    (hp : ∀ o, e = .placed o → o.cycle = a.cycles.getD o.coin 0) :
    Live (a.apply fees time e) := by
  cases e with
  | placed o =>
    intro x hx
    simp only [Acct.apply, List.mem_append, List.mem_singleton] at hx
    rcases hx with hx | rfl
    · exact h x hx
    · exact hp x rfl
  | refused o r => exact h
  | cancelled o c =>
    intro x hx
    simp only [Acct.apply, List.mem_filter] at hx
    exact h x hx.1
  | fill o units price role =>
    intro x hx
    simp only [Acct.apply, List.mem_filter] at hx
    exact h x hx.1
  | cycleEnd coin cycle =>
    intro x hx
    simp only [Acct.apply, List.mem_filter, bne_iff_ne, ne_eq] at hx
    have := h x hx.1
    simp only [Acct.apply]
    rw [replaceAt_getD_ne _ _ _ _ _ (Ne.symm hx.2)]
    exact this

end Engine.Machine
