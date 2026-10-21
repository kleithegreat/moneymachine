import Ref.Proof.Twin

/-! L3 for `ifNotRev`, first part: inserting a node at i, with later indices shifted, keeps every old node's
rows, one place further on. -/

namespace Ref

variable {α : Type} [Inhabited α]

/-- Where node k lives once a node is inserted at i. -/
def shift (i k : Nat) : Nat := if k ≥ i then k + 1 else k

theorem shift_inj {i a b : Nat} (h : shift i a = shift i b) : a = b := by
  unfold shift at h; split at h <;> split at h <;> omega

theorem shift_ne (i k : Nat) : shift i k ≠ i := by unfold shift; split <;> omega

/-- The machine of the program with a node inserted at i, against the original's: each old row one place on,
and the same inputs. -/
structure Ins (i : Nat) (M M' : MState α) : Prop where
  vals : ∀ k : Nat, M'.vals[shift i k]! = M.vals[k]!
  wins : ∀ k : Nat, M'.wins[shift i k]! = M.wins[k]!
  since : ∀ k : Nat, M'.since[shift i k]! = M.since[k]!
  vsize : M'.vals.size = M.vals.size + 1
  wsize : M'.wins.size = M.wins.size + 1
  ssize : M'.since.size = M.since.size + 1
  funding : M'.funding = M.funding
  bar : M'.bar = M.bar
  events : M'.events = M.events
  hour : M'.hour = M.hour
  maxKnown : M'.maxKnown = M.maxKnown

omit [Inhabited α] in
theorem modify_get {β : Type} [Inhabited β] (xs : Array β) (k j : Nat) (g : β → β) :
    (xs.modify k g)[j]! = if j = k ∧ k < xs.size then g xs[k]! else xs[j]! := by
  rcases Nat.lt_or_ge j xs.size with hj | hj
  · rw [getElem!_pos _ j (by simpa using hj), Array.getElem_modify, getElem!_pos xs j hj]
    by_cases h : k = j
    · subst h; simp [hj, getElem!_pos xs k hj]
    · simp [h, Ne.symm h]
  · rw [getElem!_neg _ j (by simp; omega), getElem!_neg xs j (by omega)]
    split
    · omega
    · rfl

/-- Updating row k in place and row `shift i k` in the inserted machine keeps the correspondence. -/
theorem shifted_modify {β : Type} [Inhabited β] {i k : Nat} {xs ys : Array β} (h : ∀ k, ys[shift i k]! = xs[k]!)
    (hs : ys.size = xs.size + 1) (hi : i ≤ xs.size) (g : β → β) :
    ∀ k', (ys.modify (shift i k) g)[shift i k']! = (xs.modify k g)[k']! := by
  intro k'
  rw [modify_get, modify_get, h, h]
  have hsz : shift i k < ys.size ↔ k < xs.size := by unfold shift; split <;> omega
  by_cases hk : k' = k
  · subst hk; simp [hsz]
  · have : shift i k' ≠ shift i k := fun e => hk (shift_inj e)
    simp [this, hk]

end Ref
