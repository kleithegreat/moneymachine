import Engine.R1Streams

/-!
# The account under the effects it takes (brief 3 step 5; S1)

What `Acct.apply` leaves alone, effect by effect: the lengths of its lists, its cycles, its ledger.
-/

namespace Engine.World

open Engine.Orders

theorem replaceAt_length {α : Type} (l : List α) (i : Nat) (f : α → α) : (replaceAt l i f).length = l.length := by
  induction l generalizing i with
  | nil => rfl
  | cons x rest ih => cases i <;> simp [replaceAt, ih]

theorem replaceAt_getD_self {α : Type} (l : List α) (i : Nat) (f : α → α) (d : α) (h : i < l.length) :
    (replaceAt l i f).getD i d = f (l.getD i d) := by
  induction l generalizing i with
  | nil => simp at h
  | cons x rest ih =>
    cases i with
    | zero => simp [replaceAt]
    | succ i => simp [replaceAt]; exact ih i (by simpa using h)

theorem replaceAt_getD_ne {α : Type} (l : List α) (i j : Nat) (f : α → α) (d : α) (h : i ≠ j) :
    (replaceAt l i f).getD j d = l.getD j d := by
  induction l generalizing i j with
  | nil => simp [replaceAt]
  | cons x rest ih =>
    cases i with
    | zero =>
      cases j with
      | zero => exact absurd rfl h
      | succ j => simp [replaceAt]
    | succ i =>
      cases j with
      | zero => simp [replaceAt]
      | succ j => simp [replaceAt]; exact ih i j (fun e => h (by omega))

theorem ledger_step_length (fees : List Engine.Ledger.Tier) (s : Engine.Ledger.State) (ev : Engine.Ledger.Event)
    (r : Engine.Ledger.Receipt) (h : Engine.Ledger.step fees s ev = .ok r) : r.state.positions.length = s.positions.length := by
  unfold Engine.Ledger.step at h
  split at h
  · simp at h
  · cases ev with
    | fill time coin units price role =>
      simp only [] at h
      split at h
      · split at h
        · simp at h
        · simp only [Except.ok.injEq] at h
          subst h
          simp
      · simp at h
    | funding time hour coin oracle rate =>
      simp only [] at h
      split at h
      · simp only [Except.ok.injEq] at h
        subst h
        rfl
      · simp at h
    | absorb =>
      simp only [] at h
      split at h
      · simp only [Except.ok.injEq] at h
        subst h
        rfl
      · simp at h


variable (fees : List Engine.Ledger.Tier) (time : Int) (a : Acct)

theorem apply_ledger_length (e : Effect) :
    (a.apply fees time e).ledger.positions.length = a.ledger.positions.length := by
  cases e with
  | placed o => rfl
  | refused o r => rfl
  | cancelled o c => rfl
  | fill o units price role =>
    simp only [Acct.apply]
    cases hs : Engine.Ledger.step fees a.ledger (.fill time o.coin units price role) with
    | error r => simp
    | ok r => simp [ledger_step_length fees _ _ r hs]
  | cycleEnd coin cycle => rfl

theorem apply_cycles_length (e : Effect) : (a.apply fees time e).cycles.length = a.cycles.length := by
  cases e with
  | placed o => rfl
  | refused o r => rfl
  | cancelled o c => rfl
  | fill o units price role => simp only [Acct.apply]
  | cycleEnd coin cycle => simp [Acct.apply, replaceAt_length]

theorem apply_filled_length (e : Effect) : (a.apply fees time e).filled.length = a.filled.length := by
  cases e with
  | placed o => rfl
  | refused o r => rfl
  | cancelled o c => rfl
  | fill o units price role => simp [Acct.apply, replaceAt_length]
  | cycleEnd coin cycle => simp [Acct.apply, replaceAt_length]

theorem apply_cycles_of_not_end (e : Effect) (h : ∀ coin cycle, e ≠ .cycleEnd coin cycle) :
    (a.apply fees time e).cycles = a.cycles := by
  cases e with
  | placed o => rfl
  | refused o r => rfl
  | cancelled o c => rfl
  | fill o units price role => simp [Acct.apply]
  | cycleEnd coin cycle => exact absurd rfl (h coin cycle)

end Engine.World
