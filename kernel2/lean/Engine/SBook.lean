import Engine.SInv

/-!
# The world's book and an offer's plan (brief 3 step 5; S1)
-/

namespace Engine.Machine

open Engine.World
open Engine.Orders (Wish Order Book)

variable {α : Type}

theorem worldBook_cycle (s : StateOf α) (t : Int) (k : Nat) : (worldBook s t).cycle k = s.acct.cycles.getD k 0 := rfl

theorem worldBook_coins (s : StateOf α) (t : Int) : (worldBook s t).coins = List.range s.cfg.names.length := rfl

theorem worldBook_position (s : StateOf α) (t : Int) (k : Nat) (hk : k < s.cfg.names.length) :
    (worldBook s t).position k = s.acct.position k := by
  show (((List.range s.cfg.names.length).map s.acct.position).getD k 0) = _
  rw [getD_map_range _ _ _ _ hk]

theorem worldBook_filled (s : StateOf α) (t : Int) (k slot : Nat) : (worldBook s t).filled k slot = s.acct.filledAt k slot := rfl

theorem worldBook_orders_coin (s : StateOf α) (t : Int) : ∀ o ∈ (worldBook s t).orders, ∃ o' ∈ s.acct.orders, o.coin = o'.coin := by
  intro o ho
  obtain ⟨o', ho', rfl⟩ := List.mem_map.1 ho
  exact ⟨o', ho', rfl⟩

theorem ledger_fill_ok {fees : List Engine.Ledger.Tier} {L : Engine.Ledger.State} {time : Int} {coin : Nat} {units price : Rat}
    {role : Engine.Ledger.Role} {r : Engine.Ledger.Receipt} (h : Engine.Ledger.step fees L (.fill time coin units price role) = .ok r) :
    coin < L.positions.length ∧
      r.state.positions = L.positions.set coin (Engine.Ledger.fillPosition (Engine.Ledger.position L coin) units price).1 := by
  unfold Engine.Ledger.step at h
  split at h
  · simp at h
  · simp only [] at h
    split at h
    · rename_i hcond
      split at h
      · simp at h
      · simp only [Except.ok.injEq] at h
        subst h
        exact ⟨hcond.1, rfl⟩
    · simp at h

theorem fillAccepted_ok {fees : List Engine.Ledger.Tier} {L : Engine.Ledger.State} {time : Int} {coin : Nat}
    {units price : Rat} (h : fillAccepted fees L time coin units price = true) (role : Engine.Ledger.Role) :
    ∃ r, Engine.Ledger.step fees L (.fill time coin units price role) = .ok r := by
  unfold fillAccepted at h
  simp only [Bool.and_eq_true, Bool.not_eq_true', decide_eq_true_eq] at h
  obtain ⟨⟨hb, hc⟩, ha⟩ := h
  obtain ⟨tier, htier⟩ := Option.isSome_iff_exists.1 ha
  unfold Engine.Ledger.step
  obtain ⟨hc1, hc2, hc3⟩ := hc
  simp [hb, hc1, hc2, hc3, htier]

end Engine.Machine
