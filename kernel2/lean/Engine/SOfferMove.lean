import Engine.SArrive

/-!
# S1's invariants kept by an offer (brief 3 step 5)
-/

namespace Engine.Machine

open Engine.World
open Engine.Orders (Wish Order Book Placement CycleStep OrderFill Trigger)

section Offer

theorem offerFinal_cfg (s : State) (coin : Nat) (p : Taken) (role : Engine.Ledger.Role) : (offerFinal s coin p role).cfg = s.cfg := by
  unfold offerFinal
  dsimp only
  rw [(emit_frame _ _ _).cfg, (emit_frame _ _ _).cfg]

variable {s : State} {coin slot : Nat} {parts : List (Nat × Rat)} {p : Taken} {role : Engine.Ledger.Role}

theorem offer_coin_lt (h : offerPlan s coin slot parts = some p) : coin < s.acct.ledger.positions.length := by
  obtain ⟨last, _, _, _, _, _, _, _, _, _, hacc, _⟩ := offerPlan_spec h
  obtain ⟨r, hr⟩ := fillAccepted_ok hacc Engine.Ledger.Role.taker
  exact (ledger_fill_ok hr).1

/-- The cycles after an offer's fill: never lower, and one higher at the coin exactly when the cycle ends. -/
theorem offer_cycles (h : offerPlan s coin slot parts = some p) (hB : BInv s.core) :
    (∀ k, s.acct.cycles.getD k 0 ≤ (offerFinal s coin p role).acct.cycles.getD k 0) ∧
    (p.ends = false → ∀ k, (offerFinal s coin p role).acct.cycles.getD k 0 = s.acct.cycles.getD k 0) ∧
    (p.ends = true → (offerFinal s coin p role).acct.cycles.getD coin 0 = s.acct.cycles.getD coin 0 + 1 ∧
      ∀ k, k ≠ coin → (offerFinal s coin p role).acct.cycles.getD k 0 = s.acct.cycles.getD k 0) := by
  have hn := offer_coin_lt h
  have hsh : Shape s.cfg.names.length s.acct := hB.shapeW
  have hcl : coin < s.acct.cycles.length := by
    have := hsh.1
    have := hsh.2.1
    omega
  have hf : coin < s.acct.filled.length := by
    have := hsh.1
    have := hsh.2.2
    omega
  have hne : ∀ k, p.ends = false → (offerFinal s coin p role).acct.cycles.getD k 0 = s.acct.cycles.getD k 0 := by
    intro k he
    rw [offerFinal_acct_noend s coin p role he, fillAcct_cycles]
  have hyes : p.ends = true → (offerFinal s coin p role).acct.cycles.getD coin 0 = s.acct.cycles.getD coin 0 + 1 ∧
      ∀ k, k ≠ coin → (offerFinal s coin p role).acct.cycles.getD k 0 = s.acct.cycles.getD k 0 := by
    intro he
    have hc := (offerFinal_ends (role := role) h he hn hf).1
    refine ⟨?_, fun k hk => ?_⟩
    · rw [hc, replaceAt_getD_self _ _ _ _ hcl]
      simp [Acct.cycle, List.getElem?_eq_getElem hcl]
    · rw [hc, replaceAt_getD_ne _ _ _ _ _ (Ne.symm hk)]
  refine ⟨fun k => ?_, fun he k => hne k he, hyes⟩
  cases he : p.ends
  · rw [hne k he]; exact Nat.le_refl _
  · obtain ⟨h1, h2⟩ := hyes he
    by_cases hk : k = coin
    · subst hk; rw [h1]; omega
    · rw [h2 k hk]; exact Nat.le_refl _

/-- The step an offer logs. -/
def offerStep (s : State) (coin : Nat) (p : Taken) (role : Engine.Ledger.Role) : CycleStep :=
  ⟨worldBook s p.time, worldBook (offerFinal s coin p role) p.time, .fill coin p.units, p.time, if p.ends then [coin] else []⟩

/-- The fill an offer logs. -/
def offerFill (s : State) (p : Taken) : OrderFill :=
  ⟨{ p.order with remainder := p.remaining }, worldBook s p.time, p.units, p.time, stepCount s⟩

theorem offerStep_good (h : offerPlan s coin slot parts = some p) (hB : BInv s.core) : StepGood (offerStep s coin p role) := by
  have hsh : Shape s.cfg.names.length s.acct := hB.shapeW
  have hn := offer_coin_lt h
  have hf : coin < s.acct.filled.length := by
    have := hsh.1
    have := hsh.2.2
    omega
  have hlt : coin < s.cfg.names.length := by
    have := hsh.1
    omega
  obtain ⟨hmono, hne, hyes⟩ := offer_cycles (role := role) h hB
  obtain ⟨_, _, _, _, _, _, _, _, _, _, _, hends⟩ := offerPlan_spec h
  refine ⟨?_, ?_, ?_⟩
  · show (if p.ends = true then [coin] else []) = if (worldBook s p.time).position coin ≠ 0 ∧
      (worldBook s p.time).position coin + p.units = 0 then [coin] else []
    rw [worldBook_position s _ coin hlt, hends]
    by_cases hc : s.acct.position coin ≠ 0 ∧ s.acct.position coin + p.units = 0
    · simp [hc.1, hc.2]
    · have : ¬ (s.acct.position coin != 0 && s.acct.position coin + p.units == 0) = true := by
        simp only [Bool.and_eq_true, bne_iff_ne, beq_iff_eq]
        exact hc
      simp [this, hc]
  · intro k _
    show (worldBook (offerFinal s coin p role) p.time).cycle k = (worldBook s p.time).cycle k +
      (if k ∈ (if p.ends = true then [coin] else []) then 1 else 0)
    rw [worldBook_cycle, worldBook_cycle]
    cases he : p.ends
    · rw [hne he k]; simp
    · obtain ⟨h1, h2⟩ := hyes he
      by_cases hk : k = coin
      · subst hk; rw [h1]; simp
      · rw [h2 k hk]; simp [hk]
  · intro k hk
    have he : p.ends = true := by
      by_cases hh : p.ends = true
      · exact hh
      · have : p.ends = false := by simpa using hh
        have hk' : k ∈ (offerStep s coin p role).ended := hk
        simp [offerStep, this] at hk'
    have hk' : k = coin := by
      have hk' : k ∈ (offerStep s coin p role).ended := hk
      simpa [offerStep, he] using hk'
    subst hk'
    obtain ⟨_, hpos, hfill, hord⟩ := offerFinal_ends (role := role) h he hn hf
    obtain ⟨h1, _⟩ := hyes he
    refine ⟨?_, ?_, fun slot => ?_, ?_⟩
    · show (worldBook (offerFinal s k p role) p.time).position k = 0
      rw [worldBook_position _ _ _ (by rw [offerFinal_cfg]; exact hlt)]
      exact hpos
    · show (worldBook (offerFinal s k p role) p.time).cycle k = (worldBook s p.time).cycle k + 1
      rw [worldBook_cycle, worldBook_cycle]
      exact h1
    · exact hfill slot
    · intro o ho
      obtain ⟨o', ho', hc⟩ := worldBook_orders_coin (offerFinal s k p role) p.time o ho
      rw [hc]
      exact hord o' ho'

theorem offerFill_good (h : offerPlan s coin slot parts = some p) (hB : BInv s.core) : FillGood (offerFill s p) := by
  have hsh : Shape s.cfg.names.length s.acct := hB.shapeW
  have hn := offer_coin_lt h
  have hlt : coin < s.cfg.names.length := by
    have := hsh.1
    omega
  obtain ⟨last, m, _, hlive, _, hrem, hrem0, hm, hm0, hunits, _, _⟩ := offerPlan_spec h
  obtain ⟨_, hco, hsl⟩ := live_spec hlive
  have hb := walk_bounds (s.rules.getD coin default).szDecimals parts p.remaining
    (by rw [hrem]; exact remainder_nonneg _ _)
  rw [← hm] at hb
  have hpos := worldBook_position s p.time coin hlt
  have hfil := worldBook_filled s p.time coin slot
  unfold FillGood offerFill
  dsimp only
  rw [hco, hsl, hpos, hfil]
  unfold Acct.remainder Acct.reducible at hrem
  rw [hco, hsl] at hrem
  have hmag : (if p.units < 0 then -p.units else p.units) = m := by
    cases hs : p.order.side <;> rw [hs] at hunits <;> simp only [hunits] <;> grind
  rw [hmag]
  generalize (match p.order.side with | .sell => max 0 (s.acct.position coin) | .buy => max 0 (-s.acct.position coin)) = R at hrem ⊢
  have hmpos : 0 < m := by grind
  cases ht : p.order.target with
  | none =>
    rw [ht] at hrem
    simp only [] at hrem ⊢
    refine ⟨by grind, fun _ => by grind⟩
  | some t =>
    rw [ht] at hrem
    simp only [] at hrem ⊢
    by_cases hro : p.order.reduceOnly = true
    · simp only [hro, ite_true] at hrem
      refine ⟨by grind, fun _ => by grind⟩
    · simp only [hro] at hrem
      refine ⟨by grind, fun h' => absurd h' hro⟩

end Offer

theorem sinv_offer (s : State) (coin slot : Nat) (parts : List (Nat × Rat)) (role : Engine.Ledger.Role)
    (hB : BInv s.core) (h : SInv s.core) : SInv (offer s coin slot parts role).1.core := by
  cases hp : offerPlan s coin slot parts with
  | none =>
    have : (offer s coin slot parts role).1 = s := by
      unfold offer
      rw [hp]
    rw [this]
    exact h
  | some p =>
    obtain ⟨last, m, hprevS, hlive, hpt, hrem, hrem0, hm, hm0, hunits, hacc, hends⟩ := offerPlan_spec hp
    obtain ⟨hmono, hne, hyes⟩ := offer_cycles (role := role) hp hB
    have hacct : (offer s coin slot parts role).1.acct = (offerFinal s coin p role).acct := by
      unfold offer; rw [hp]; exact applyOffer_acct s coin p role
    obtain ⟨_, _, _, hprev⟩ := offer_fields s coin slot parts role
    have hcfg := (offer_fields s coin slot parts role).1
    have hlog : ∀ l', (offer s coin slot parts role).1.core.log = some l' →
        ∃ l : Log, s.core.log = some l.core ∧ l'.steps = l.steps ++ [offerStep s coin p role] ∧
          l'.fills = l.fills ++ [offerFill s p] ∧ l'.placed = l.placed ∧ s.log = some l := by
      intro l' hl'
      rcases offer_decomp s coin slot parts role l' hl' with ⟨l, _, hp', _⟩ | ⟨l, p', hs, hp', rfl⟩
      · rw [hp] at hp'; exact absurd hp' (by simp)
      · rw [hp] at hp'
        obtain rfl := Option.some.inj hp'
        exact ⟨l, by simp [StateOf.core, hs], rfl, rfl, rfl, hs⟩
    have hcyc : ∀ k, (offer s coin slot parts role).1.core.acct.cycles.getD k 0 =
        (offerFinal s coin p role).acct.cycles.getD k 0 := by
      intro k; show (offer s coin slot parts role).1.acct.cycles.getD k 0 = _; rw [hacct]
    have hnames : (offer s coin slot parts role).1.core.cfg.names.length = s.cfg.names.length := by
      show (offer s coin slot parts role).1.cfg.names.length = _; rw [hcfg]
    refine ⟨?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_⟩
    · intro l' hl' st hst
      obtain ⟨l, hc, e1, _⟩ := hlog l' hl'
      rw [e1] at hst
      rcases List.mem_append.1 hst with hst | hst
      · exact h.steps l.core hc st hst
      · simp only [List.mem_singleton] at hst
        subst hst
        exact offerStep_good (role := role) hp hB
    · intro l' hl' st hst k
      obtain ⟨l, hc, e1, _⟩ := hlog l' hl'
      rw [e1] at hst
      rw [hcyc k]
      rcases List.mem_append.1 hst with hst | hst
      · have h1 : st.after.cycle k ≤ s.acct.cycles.getD k 0 := h.mono l.core hc st hst k
        exact Nat.le_trans h1 (hmono k)
      · simp only [List.mem_singleton] at hst
        subst hst
        show (worldBook (offerFinal s coin p role) p.time).cycle k ≤ _
        rw [worldBook_cycle]
        exact Nat.le_refl _
    · intro l' hl'
      obtain ⟨l, hc, e1, _⟩ := hlog l' hl'
      rw [e1, List.pairwise_append]
      refine ⟨h.chain l.core hc, by simp, ?_⟩
      intro a ha b hb
      simp only [List.mem_singleton] at hb
      subst hb
      intro k hk
      have h1 := ((h.steps l.core hc a ha).2.2 k hk).2.1
      have h2 : a.after.cycle k ≤ s.acct.cycles.getD k 0 := h.mono l.core hc a ha k
      show a.before.cycle k < (worldBook s p.time).cycle k
      rw [worldBook_cycle]
      omega
    · intro l' hl'
      obtain ⟨l, hc, e1, _⟩ := hlog l' hl'
      rw [e1, List.pairwise_append]
      refine ⟨h.times l.core hc, by simp, ?_⟩
      intro a ha b hb
      simp only [List.mem_singleton] at hb
      subst hb
      intro hae _
      obtain ⟨e, he, hle⟩ := h.prevTime l.core hc a ha hae
      have : e = last := by
        have := he.symm.trans hprevS
        exact Option.some.inj this
      subst this
      show a.time ≤ p.time
      omega
    · intro l' hl' st hst hnonempty
      obtain ⟨l, hc, e1, _⟩ := hlog l' hl'
      rw [e1] at hst
      rcases List.mem_append.1 hst with hst | hst
      · obtain ⟨e, he, hle⟩ := h.prevTime l.core hc st hst hnonempty
        exact ⟨e, by rw [show (offer s coin slot parts role).1.core.previous = s.previous from hprev]; exact he, hle⟩
      · simp only [List.mem_singleton] at hst
        subst hst
        refine ⟨last, by rw [show (offer s coin slot parts role).1.core.previous = s.previous from hprev]; exact hprevS, ?_⟩
        show p.time ≤ last.time
        omega
    · intro l' hl' k hk K hK1 hK2
      obtain ⟨l, hc, e1, _⟩ := hlog l' hl'
      rw [hnames] at hk
      rw [hcyc k] at hK2
      have old : K < s.acct.cycles.getD k 0 → ∃ st ∈ l'.steps, k ∈ st.ended ∧ st.before.cycle k = K := by
        intro hK
        obtain ⟨st, hst, hend, hbef⟩ := h.exist l.core hc k hk K hK1 hK
        exact ⟨st, by rw [e1]; exact List.mem_append_left _ hst, hend, hbef⟩
      cases he : p.ends
      · rw [hne he k] at hK2
        exact old hK2
      · obtain ⟨h1, h2⟩ := hyes he
        by_cases hkc : k = coin
        · subst hkc
          rw [h1] at hK2
          by_cases hK : K < s.acct.cycles.getD k 0
          · exact old hK
          · have hKe : K = s.acct.cycles.getD k 0 := by omega
            refine ⟨offerStep s k p role, by rw [e1]; exact List.mem_append_right _ (List.mem_singleton_self _), ?_, ?_⟩
            · simp [offerStep, he]
            · show (worldBook s p.time).cycle k = K
              rw [worldBook_cycle]; omega
        · rw [h2 k hkc] at hK2
          exact old hK2
    · intro l' hl' st hst k hk
      obtain ⟨l, hc, e1, _⟩ := hlog l' hl'
      rw [e1] at hst
      rw [hnames]
      rcases List.mem_append.1 hst with hst | hst
      · exact h.endedLt l.core hc st hst k hk
      · simp only [List.mem_singleton] at hst
        subst hst
        have hsh : Shape s.cfg.names.length s.acct := hB.shapeW
        have hn := offer_coin_lt hp
        have hlt : coin < s.cfg.names.length := by
          have := hsh.1
          omega
        have hk' : k ∈ (if p.ends = true then [coin] else []) := hk
        cases he : p.ends
        · simp [he] at hk'
        · simp [he] at hk'
          subst hk'
          exact hlt
    · intro l' hl' q hq j st hj hjq
      obtain ⟨l, hc, e1, _, e3, _⟩ := hlog l' hl'
      rw [e3] at hq
      rw [e1] at hj
      obtain ⟨st', hst', _⟩ := h.placedOwn l.core hc q hq
      have hlen : q.step < l.steps.length := (List.getElem?_eq_some_iff.1 hst').1
      rw [getElem?_append_lt _ _ _ (by omega)] at hj
      exact h.placedIdx l.core hc q hq j st hj hjq
    · intro l' hl' q hq
      obtain ⟨l, hc, e1, _, e3, _⟩ := hlog l' hl'
      rw [e3] at hq
      rw [e1]
      obtain ⟨st', hst', hend⟩ := h.placedOwn l.core hc q hq
      have hlen : q.step < l.steps.length := (List.getElem?_eq_some_iff.1 hst').1
      exact ⟨st', by rw [getElem?_append_lt _ _ _ hlen]; exact hst', hend⟩
    · intro l' hl' f hf j st hj hjf
      obtain ⟨l, hc, e1, e2, _, hs⟩ := hlog l' hl'
      rw [e1] at hj
      rw [e2] at hf
      rcases List.mem_append.1 hf with hf | hf
      · have hlen : f.step < l.steps.length := h.fillsOwn l.core hc f hf
        rw [getElem?_append_lt _ _ _ (by omega)] at hj
        exact h.fillsIdx l.core hc f hf j st hj hjf
      · simp only [List.mem_singleton] at hf
        subst hf
        have hstep : (offerFill s p).step = l.steps.length := stepCount_of_log s l hs
        rw [hstep] at hjf
        rw [getElem?_append_lt _ _ _ hjf] at hj
        have h1 : st.after.cycle p.order.coin ≤ s.acct.cycles.getD p.order.coin 0 :=
          h.mono l.core hc st (List.mem_of_getElem? hj) p.order.coin
        obtain ⟨hmem, _, _⟩ := live_spec hlive
        have h2 : p.order.cycle = s.acct.cycles.getD p.order.coin 0 := hB.live p.order hmem
        show st.after.cycle p.order.coin ≤ p.order.cycle
        rw [h2]
        exact h1
    · intro l' hl' f hf
      obtain ⟨l, hc, e1, e2, _, hs⟩ := hlog l' hl'
      rw [e2] at hf
      rw [e1]
      simp only [List.length_append, List.length_singleton]
      rcases List.mem_append.1 hf with hf | hf
      · have : f.step < l.steps.length := h.fillsOwn l.core hc f hf
        omega
      · simp only [List.mem_singleton] at hf
        subst hf
        have hstep : (offerFill s p).step = l.steps.length := stepCount_of_log s l hs
        omega
    · intro l' hl' f hf
      obtain ⟨l, hc, e1, e2, _⟩ := hlog l' hl'
      rw [e2] at hf
      rcases List.mem_append.1 hf with hf | hf
      · exact h.fillsGood l.core hc f hf
      · simp only [List.mem_singleton] at hf
        subst hf
        exact offerFill_good hp hB

end Engine.Machine
