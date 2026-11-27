import Engine.STimeMoves

/-!
# The view's lag under an offer (brief 3 step 5; S1)
-/

namespace Engine.Machine

open Engine.World
open Engine.Orders (Wish Order Book Placement CycleStep OrderFill Trigger)

theorem offerFinal_veffects (s : State) (coin : Nat) (p : Taken) (role : Engine.Ledger.Role) :
    ∃ L, (offerFinal s coin p role).veffects = s.veffects ++ L ∧
      ∀ x ∈ L, x.known = p.time + s.cfg.delta ∧ ∀ k C, x.effect = .cycleEnd k C → k = coin ∧ C = s.acct.cycle coin ∧ p.ends = true := by
  unfold offerFinal
  dsimp only
  rw [emit_veffects, emit_veffects]
  have hc := (emit_frame s p.time [Effect.fill p.order p.units p.price role]).cfg
  refine ⟨[logged s.cfg p.time (.fill p.order p.units p.price role)] ++
    ((if p.ends = true then ((emit s p.time [Effect.fill p.order p.units p.price role]).1.acct.orders.filter (·.coin == coin)).map
        (fun o => Effect.cancelled o "cycle_end") else []) ++
      (if p.ends = true then [Effect.cycleEnd coin (s.acct.cycle coin)] else [])).map (logged s.cfg p.time), ?_, ?_⟩
  · rw [hc]; simp
  · intro x hx
    rw [hc] at *
    simp only [List.mem_append, List.mem_singleton, List.mem_map] at hx
    rcases hx with rfl | ⟨e, he, rfl⟩
    · exact ⟨by simp [logged], fun k C h => by simp [logged] at h⟩
    · refine ⟨by simp [logged], fun k C h => ?_⟩
      simp only [logged] at h
      rcases he with he | he
      · by_cases hp : p.ends = true
        · simp only [hp, ite_true, List.mem_map] at he
          obtain ⟨o, _, rfl⟩ := he
          simp at h
        · simp [hp] at he
      · by_cases hp : p.ends = true
        · simp only [hp, ite_true, List.mem_singleton] at he
          subst he
          simp only [Effect.cycleEnd.injEq] at h
          exact ⟨h.1.symm, h.2.symm, hp⟩
        · simp [hp] at he

theorem offerFinal_cycles_length (s : State) (coin : Nat) (p : Taken) (role : Engine.Ledger.Role) :
    (offerFinal s coin p role).acct.cycles.length = s.acct.cycles.length := by
  cases he : p.ends
  · rw [offerFinal_acct_noend s coin p role he, fillAcct_cycles]
  · rw [offerFinal_acct_end s coin p role he, apply_cycleEnd_cycles, replaceAt_length,
      (foldl_cancels _ _ _ _ _).2.1, fillAcct_cycles]

theorem getD_oob {α : Type} (l : List α) (k : Nat) (d : α) (h : l.length ≤ k) : l.getD k d = d := by
  simp [List.getD_eq_getElem?_getD, List.getElem?_eq_none h]

theorem offer_cycle_mono {s : State} {coin slot : Nat} {parts : List (Nat × Rat)} {p : Taken} (role : Engine.Ledger.Role)
    (h : offerPlan s coin slot parts = some p) (hB : BInv s.core) :
    ∀ k, s.acct.cycle k ≤ (offerFinal s coin p role).acct.cycle k := by
  intro k
  have hlen := offerFinal_cycles_length s coin p role
  by_cases hk : k < s.acct.cycles.length
  · unfold Acct.cycle
    rw [getD_irrel s.acct.cycles k hk 1 0, getD_irrel (offerFinal s coin p role).acct.cycles k (by omega) 1 0]
    exact (offer_cycles (role := role) h hB).1 k
  · unfold Acct.cycle
    rw [getD_oob _ _ _ (by omega), getD_oob _ _ _ (by omega)]
    exact Nat.le_refl _

theorem offer_hlog (s : State) (coin slot : Nat) (parts : List (Nat × Rat)) (role : Engine.Ledger.Role) (p : Taken)
    (hp : offerPlan s coin slot parts = some p) :
    ∀ l', (offer s coin slot parts role).1.core.log = some l' →
      ∃ l : Log, s.core.log = some l.core ∧ l'.steps = l.steps ++ [offerStep s coin p role] ∧
        l'.fills = l.fills ++ [offerFill s p] ∧ l'.placed = l.placed ∧ s.log = some l ∧ l'.ticks = l.ticks := by
  intro l' hl'
  rcases offer_decomp s coin slot parts role l' hl' with ⟨l, _, hp', _⟩ | ⟨l, p', hs, hp', rfl⟩
  · rw [hp] at hp'; exact absurd hp' (by simp)
  · rw [hp] at hp'
    obtain rfl := Option.some.inj hp'
    exact ⟨l, by simp [StateOf.core, hs], rfl, rfl, rfl, hs, rfl⟩

theorem timeInv_offer (s : State) (coin slot : Nat) (parts : List (Nat × Rat)) (role : Engine.Ledger.Role)
    (hB : BInv s.core) (hS : SInv s.core) (h : TimeInv s.core) : TimeInv (offer s coin slot parts role).1.core := by
  cases hp : offerPlan s coin slot parts with
  | none =>
    have : (offer s coin slot parts role).1 = s := by
      unfold offer
      rw [hp]
    rw [this]
    exact h
  | some p =>
    obtain ⟨hn1, hn2, hn3, hprev⟩ := offer_fields s coin slot parts role
    have hvacct : (offer s coin slot parts role).1.vacct = s.vacct := by
      unfold offer; rw [hp]; exact applyOffer_vacct s coin p role
    have hacct : (offer s coin slot parts role).1.acct = (offerFinal s coin p role).acct := by
      unfold offer; rw [hp]; exact applyOffer_acct s coin p role
    have hveff : (offer s coin slot parts role).1.veffects = (offerFinal s coin p role).veffects := by
      unfold offer; rw [hp]; rfl
    have hmono := offer_cycle_mono role hp hB
    have hlog := offer_hlog s coin slot parts role p hp
    have hsh : Shape s.cfg.names.length s.acct := hB.shapeW
    have hnn := offer_coin_lt hp
    have hlt : coin < s.cfg.names.length := by
      have := hsh.1
      omega
    have hcl : coin < s.acct.cycles.length := by
      have := hsh.1
      have := hsh.2.1
      omega
    have hbefore : (offerStep s coin p role).before.cycle coin = s.acct.cycle coin := by
      show (worldBook s p.time).cycle coin = _
      rw [worldBook_cycle]
      unfold Acct.cycle
      exact getD_irrel s.acct.cycles coin hcl 0 1
    refine ⟨?_, ?_, ?_, ?_, ?_⟩
    · intro l' hl' k
      obtain ⟨l, hc, _⟩ := hlog l' hl'
      show (offer s coin slot parts role).1.vacct.cycle k ≤ (offer s coin slot parts role).1.acct.cycle k
      rw [hvacct, hacct]
      exact Nat.le_trans (h.va l.core hc k) (hmono k)
    · intro l' hl'
      obtain ⟨l, hc, e1, _⟩ := hlog l' hl'
      have hv := h.ve l.core hc
      show VE l'.steps (offer s coin slot parts role).1.cfg.delta (offer s coin slot parts role).1.veffects
      rw [hn1, hveff, e1]
      obtain ⟨L, hL, hLx⟩ := offerFinal_veffects s coin p role
      rw [hL]
      intro x hx k C hxe
      rcases List.mem_append.1 hx with hx | hx
      · obtain ⟨st, hst, r⟩ := hv x hx k C hxe
        exact ⟨st, List.mem_append_left _ hst, r⟩
      · obtain ⟨hk1, hk2⟩ := hLx x hx
        obtain ⟨hkc, hCc, hend⟩ := hk2 k C hxe
        subst hkc
        refine ⟨offerStep s k p role, List.mem_append_right _ (List.mem_singleton_self _), ?_, ?_, ?_⟩
        · simp [offerStep, hend]
        · rw [hbefore, hCc]
        · rw [hk1]; rfl
    · intro l' hl' st hst k hk hlt'
      obtain ⟨l, hc, e1, _, _, _, e7⟩ := hlog l' hl'
      rw [e1] at hst
      have hlt'' : st.before.cycle k < s.vacct.cycle k := by rw [← hvacct]; exact hlt'
      rcases List.mem_append.1 hst with hst | hst
      · obtain ⟨tk, htk, hle⟩ := h.vt l.core hc st hst k hk hlt''
        refine ⟨tk, by rw [e7]; exact htk, ?_⟩
        show st.time + (offer s coin slot parts role).1.cfg.delta ≤ tk.1
        rw [hn1]; exact hle
      · simp only [List.mem_singleton] at hst
        subst hst
        have hk' : k ∈ (if p.ends = true then [coin] else []) := hk
        cases he : p.ends
        · simp [he] at hk'
        · simp [he] at hk'
          subst hk'
          exfalso
          have h1 : s.vacct.cycle k ≤ s.acct.cycle k := h.va l.core hc k
          rw [hbefore] at hlt''
          omega
    · intro l' hl' w hw
      obtain ⟨l, hc, e1, _⟩ := hlog l' hl'
      have hw' : w ∈ s.wishes := by rw [← hn3]; exact hw
      obtain ⟨h1, h2⟩ := h.wq l.core hc w hw'
      refine ⟨?_, ?_⟩
      · show w.cycle ≤ (offer s coin slot parts role).1.acct.cycle w.coin
        rw [hacct]
        exact Nat.le_trans h1 (hmono _)
      · intro st hst k hk hk' hlt'
        rw [e1] at hst
        show st.time + (offer s coin slot parts role).1.cfg.delta + (offer s coin slot parts role).1.cfg.lambda ≤ w.arrives
        rw [hn1]
        rcases List.mem_append.1 hst with hst | hst
        · exact h2 st hst k hk hk' hlt'
        · simp only [List.mem_singleton] at hst
          subst hst
          have hkk : k ∈ (if p.ends = true then [coin] else []) := hk
          cases he : p.ends
          · simp [he] at hkk
          · simp [he] at hkk
            subst hkk
            exfalso
            rw [hbefore] at hlt'
            have h1' : w.cycle ≤ s.acct.cycle k := by rw [← hk']; exact h1
            omega
    · intro l' hl' q hq i st hi hiq k hk hck hlt'
      obtain ⟨l, hc, e1, _, e3, _⟩ := hlog l' hl'
      rw [e3] at hq
      rw [e1] at hi
      obtain ⟨st', hst', _⟩ := hS.placedOwn l.core hc q hq
      have hlen : q.step < l.steps.length := (List.getElem?_eq_some_iff.1 hst').1
      rw [getElem?_append_lt _ _ _ (by omega)] at hi
      have := h.pl l.core hc q hq i st hi hiq k hk hck hlt'
      show st.time + (offer s coin slot parts role).1.cfg.delta + (offer s coin slot parts role).1.cfg.lambda ≤ q.order.placed
      rw [hn1]; exact this

end Engine.Machine
