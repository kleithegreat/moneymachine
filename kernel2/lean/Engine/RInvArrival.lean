import Engine.RInvClauses

/-!
# What an arrival logs (brief 3 step 5; R1)
-/

namespace Engine.Machine

open Engine.Orders (Wish Book Order Placement arrive cancelSlot admission)

theorem tag_cancelled_not_placed : ("cancelled:replaced" == "placed") = false := by decide

theorem tag_cancelled_not_refused : "cancelled:replaced".startsWith "refused:" = false := by decide +kernel

theorem admit_ok_order {a : Engine.Orders.Admission} {o : Order} (h : Engine.Orders.admit a = .ok o) : o = a.order := by
  unfold Engine.Orders.admit at h
  by_cases h1 : a.marginOk
  · by_cases h2 : a.minimumOk
    · by_cases h3 : a.capOk
      · simp only [h1, h2, h3, not_true_eq_false, ↓reduceIte] at h
        exact (Except.ok.inj h).symm
      · simp [h1, h2, h3] at h
    · simp [h1, h2] at h
  · simp [h1] at h

/-- The cases of an arrival: it changes nothing, it cancels the live order only, it is refused, or it places. -/
theorem arrive_cases (b : Book) (w : Wish) :
    ((arrive b w).2 = [] ∨ (arrive b w).2 = ["cancelled:replaced"]) ∨
    (∃ (tags : List String) (o : Order) (r : String), (tags = [] ∨ tags = ["cancelled:replaced"]) ∧
      (arrive b w).2 = tags ++ ["refused:" ++ r] ∧ Engine.Orders.prepare (cancelSlot b w.coin w.slot) w = some o ∧
      Engine.Orders.admit (admission (cancelSlot b w.coin w.slot) o) = .error r) ∨
    (∃ (tags : List String) (o : Order), (tags = [] ∨ tags = ["cancelled:replaced"]) ∧
      (arrive b w).2 = tags ++ ["placed"] ∧ Engine.Orders.prepare (cancelSlot b w.coin w.slot) w = some o ∧
      Engine.Orders.admit (admission (cancelSlot b w.coin w.slot) o) = .ok o) := by
  unfold arrive
  by_cases hg : w.coin ∈ b.ended ∨ w.cycle ≠ b.cycle w.coin ∨ Engine.Orders.sameOrder b w = true
  · left; left; simp [hg]
  · simp only [hg, ↓reduceIte]
    cases hp : Engine.Orders.prepare (cancelSlot b w.coin w.slot) w with
    | none =>
      left
      by_cases hl : b.orders.any (fun o => o.coin == w.coin && o.slot == w.slot) = true
      · right; simp [hl]
      · left; simp [hl]
    | some o =>
      cases ha : Engine.Orders.admit (admission (cancelSlot b w.coin w.slot) o) with
      | error r =>
        right; left
        by_cases hl : b.orders.any (fun o => o.coin == w.coin && o.slot == w.slot) = true
        · exact ⟨["cancelled:replaced"], o, r, Or.inr rfl, by simp [hl, ha], rfl, ha⟩
        · exact ⟨[], o, r, Or.inl rfl, by simp [hl, ha], rfl, ha⟩
      | ok adm =>
        right; right
        have hadm : adm = o := admit_ok_order ha
        subst hadm
        by_cases hl : b.orders.any (fun o => o.coin == w.coin && o.slot == w.slot) = true
        · exact ⟨["cancelled:replaced"], adm, Or.inr rfl, by simp [hl, ha], rfl, ha⟩
        · exact ⟨[], adm, Or.inl rfl, by simp [hl, ha], rfl, ha⟩

theorem refused_ne_placed (r : String) : ("refused:" ++ r == "placed") = false := by
  apply beq_false_of_ne
  intro h
  have := congrArg String.length h
  simp [String.length_append] at this
  have h1 : "refused:".length = 8 := by decide +kernel
  have h2 : "placed".length = 6 := by decide +kernel
  omega

theorem placed_ne_refused (r : String) : "placed" ≠ "refused:" ++ r := fun h => by
  have := beq_iff_eq.2 h.symm
  rw [refused_ne_placed] at this
  exact Bool.false_ne_true this

theorem prepare_fields {b : Book} {w : Wish} {o : Order} (h : Engine.Orders.prepare b w = some o) :
    o.placed = w.arrives ∧ o.reduceOnly = w.reduceOnly ∧ o.coin = w.coin ∧ o.slot = w.slot ∧ ∃ v, w.value = some v := by
  unfold Engine.Orders.prepare at h
  split at h
  · simp at h
  · split at h
    · simp at h
    · rename_i v hv
      dsimp only at h
      have h' := ite_none_some h
      subst h'
      exact ⟨rfl, rfl, rfl, rfl, v, hv⟩

/-- What an arrival logs: nothing, a refused candidate, or a placed one. -/
theorem arrival_logged {α : Type} (s : StateOf α) (w : Wish) :
    (arrivalPlaced s w = [] ∧ arrivalAdmissions s w = []) ∨
    (∃ (o : Order) (r : String), arrivalPlaced s w = [] ∧
      arrivalAdmissions s w = [(cancelSlot (worldBook s w.arrives) w.coin w.slot, o)] ∧
      Engine.Orders.admit (admission (cancelSlot (worldBook s w.arrives) w.coin w.slot) o) = .error r ∧
      Engine.Orders.prepare (cancelSlot (worldBook s w.arrives) w.coin w.slot) w = some o) ∨
    (∃ (o : Order) (v : Engine.Orders.Value), arrivalPlaced s w = [⟨o, v, (worldBook s w.arrives).rules w.coin, stepCount s⟩] ∧
      arrivalAdmissions s w = [(cancelSlot (worldBook s w.arrives) w.coin w.slot, o)] ∧
      Engine.Orders.admit (admission (cancelSlot (worldBook s w.arrives) w.coin w.slot) o) = .ok o ∧
      Engine.Orders.prepare (cancelSlot (worldBook s w.arrives) w.coin w.slot) w = some o ∧ w.value = some v) := by
  unfold arrivalPlaced arrivalAdmissions
  generalize worldBook s w.arrives = book
  rcases arrive_cases book w with (h | h) | ⟨tags, o, r, ht, h, hp, ha⟩ | ⟨tags, o, ht, h, hp, ha⟩
  · left; simp [h]
  · left; simp [h, tag_cancelled_not_refused]
  · right; left
    refine ⟨o, r, ?_, ?_, ha, hp⟩
    · rcases ht with rfl | rfl <;> simp [h, placed_ne_refused]
    · rcases ht with rfl | rfl <;> simp [h, hp]
  · right; right
    obtain ⟨_, _, _, _, v, hv⟩ := prepare_fields hp
    refine ⟨o, v, ?_, ?_, ha, hp, hv⟩
    · rcases ht with rfl | rfl <;> simp [h, hp, hv]
    · rcases ht with rfl | rfl <;> simp [h, hp]

end Engine.Machine
