import Engine.SAcct

/-!
# What an arrival does to the account (brief 3 step 5; S1)
-/

namespace Engine.Machine

open Engine.World
open Engine.Orders (Wish Order Book arrive cancelSlot admission)

theorem prepare_cycle {b : Book} {w : Wish} {o : Order} (h : Engine.Orders.prepare b w = some o) : o.cycle = w.cycle := by
  unfold Engine.Orders.prepare at h
  split at h
  · simp at h
  · split at h
    · simp at h
    · dsimp only at h
      have h' := ite_none_some h
      subst h'
      rfl

theorem arrive_guard (b : Book) (w : Wish) (h : (arrive b w).2 ≠ []) :
    ¬ (w.coin ∈ b.ended ∨ w.cycle ≠ b.cycle w.coin ∨ Engine.Orders.sameOrder b w = true) := by
  intro hg
  apply h
  unfold arrive
  simp [hg]

theorem arrivalEffects_ok (s : State) (w : Wish) :
    ∀ e ∈ arrivalEffects (worldBook s w.arrives) w, (∀ coin cycle, e ≠ .cycleEnd coin cycle) ∧
      ∀ o, e = .placed o → o.cycle = s.acct.cycles.getD o.coin 0 := by
  intro e he
  unfold arrivalEffects at he
  simp only [List.mem_filterMap] at he
  obtain ⟨tag, htag, hx⟩ := he
  have hne : (arrive (worldBook s w.arrives) w).2 ≠ [] := by
    intro h0; rw [h0] at htag; simp at htag
  have hg := arrive_guard _ _ hne
  by_cases h1 : (tag == "cancelled:replaced") = true
  · simp only [h1, ↓reduceIte] at hx
    cases hf : (worldBook s w.arrives).orders.find? (fun o => o.coin == w.coin && o.slot == w.slot) with
    | none => rw [hf] at hx; simp at hx
    | some o =>
      rw [hf] at hx
      simp only [Option.map_some, Option.some.injEq] at hx
      subst hx
      exact ⟨fun _ _ => by simp, fun o' h' => by simp at h'⟩
  · simp only [h1, Bool.false_eq_true, ↓reduceIte] at hx
    by_cases h2 : (tag == "placed") = true
    · simp only [h2, ↓reduceIte] at hx
      cases hc : Engine.Orders.prepare (cancelSlot (worldBook s w.arrives) w.coin w.slot) w with
      | none => rw [hc] at hx; simp at hx
      | some o =>
        rw [hc] at hx
        simp only [Option.map_some, Option.some.injEq] at hx
        subst hx
        refine ⟨fun _ _ => by simp, fun o' h' => ?_⟩
        simp only [Effect.placed.injEq] at h'
        subst h'
        have hcyc := prepare_cycle hc
        obtain ⟨_, _, hco, _⟩ := prepare_fields hc
        have : w.cycle = (worldBook s w.arrives).cycle w.coin := by
          by_cases hh : w.cycle = (worldBook s w.arrives).cycle w.coin
          · exact hh
          · exact absurd (Or.inr (Or.inl hh)) hg
        rw [hcyc, hco, this]
        rfl
    · simp only [h2, Bool.false_eq_true, ↓reduceIte] at hx
      by_cases h3 : tag.startsWith "refused:" = true
      · simp only [h3, ↓reduceIte] at hx
        cases hc : Engine.Orders.prepare (cancelSlot (worldBook s w.arrives) w.coin w.slot) w with
        | none => rw [hc] at hx; simp at hx
        | some o =>
          rw [hc] at hx
          simp only [Option.map_some, Option.some.injEq] at hx
          subst hx
          exact ⟨fun _ _ => by simp, fun o' h' => by simp at h'⟩
      · simp only [h3, Bool.false_eq_true, ↓reduceIte] at hx
        simp at hx

end Engine.Machine
