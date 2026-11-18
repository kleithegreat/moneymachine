import Engine.SOfferMove

/-!
# When a wish of a cycle after one's end can be sent (brief 3 step 5; S1)

The view learns of a cycle's end `δ` after the world's step, so a wish whose cycle follows an end was sent no sooner.
-/

namespace Engine.Machine

open Engine.World
open Engine.Orders (Wish Order Book Placement CycleStep OrderFill Trigger)

/-- The effects held for the view that end a cycle each name the step that ended it, known `δ` after it. -/
def VE (steps : List CycleStep) (delta : Int) (xs : List Logged) : Prop :=
  ∀ x ∈ xs, ∀ k C, x.effect = .cycleEnd k C → ∃ st ∈ steps, k ∈ st.ended ∧ st.before.cycle k = C ∧ x.known = st.time + delta

/-- A cycle the view's account has passed was ended by a step the view had learnt of by some tick. -/
def VT (steps : List CycleStep) (delta bound : Int) (a : Acct) : Prop :=
  ∀ st ∈ steps, ∀ k ∈ st.ended, st.before.cycle k < a.cycle k → st.time + delta ≤ bound

structure TimeInv (c : Core) : Prop where
  va : ∀ l, c.log = some l → ∀ k, c.vacct.cycle k ≤ c.acct.cycle k
  ve : ∀ l, c.log = some l → VE l.steps c.cfg.delta c.veffects
  vt : ∀ l, c.log = some l → ∀ st ∈ l.steps, ∀ k ∈ st.ended, st.before.cycle k < c.vacct.cycle k →
    ∃ tk ∈ l.ticks, st.time + c.cfg.delta ≤ tk.1
  wq : ∀ l, c.log = some l → ∀ w ∈ c.wishes, w.cycle ≤ c.acct.cycle w.coin ∧
    ∀ st ∈ l.steps, ∀ k ∈ st.ended, w.coin = k → st.before.cycle k < w.cycle →
      st.time + c.cfg.delta + c.cfg.lambda ≤ w.arrives
  pl : ∀ l, c.log = some l → ∀ p ∈ l.placed, ∀ (i : Nat) st, l.steps[i]? = some st → i < p.step →
    ∀ k ∈ st.ended, p.order.coin = k → st.before.cycle k < p.order.cycle →
      st.time + c.cfg.delta + c.cfg.lambda ≤ p.order.placed

theorem pairwise_cases {α : Type} {R : α → α → Prop} : ∀ {l : List α}, l.Pairwise R → ∀ {a b}, a ∈ l → b ∈ l →
    a = b ∨ R a b ∨ R b a := by
  intro l
  induction l with
  | nil => intro _ a b ha; simp at ha
  | cons x l ih =>
    intro h a b ha hb
    rw [List.pairwise_cons] at h
    rcases List.mem_cons.1 ha with rfl | ha'
    · rcases List.mem_cons.1 hb with rfl | hb'
      · exact Or.inl rfl
      · exact Or.inr (Or.inl (h.1 b hb'))
    · rcases List.mem_cons.1 hb with rfl | hb'
      · exact Or.inr (Or.inr (h.1 a ha'))
      · exact ih h.2 ha' hb'

/-- Two steps that end one coin are in the order of the cycles they end, and so of their times. -/
theorem steps_order {c : Core} (h : SInv c) {l : LogCore} (hl : c.log = some l) {st st' : CycleStep} (hst : st ∈ l.steps)
    (hst' : st' ∈ l.steps) {k : Nat} (hk : k ∈ st.ended) (hk' : k ∈ st'.ended)
    (hle : st.before.cycle k ≤ st'.before.cycle k) : st.time ≤ st'.time := by
  have hp := (h.chain l hl).and (h.times l hl)
  rcases pairwise_cases hp hst hst' with rfl | ⟨h1, h2⟩ | ⟨h1, h2⟩
  · exact Int.le_refl _
  · exact h2 (List.ne_nil_of_mem hk) (List.ne_nil_of_mem hk')
  · have := h1 k hk'
    omega

theorem getD_irrel {α : Type} (l : List α) (k : Nat) (h : k < l.length) (d d' : α) : l.getD k d = l.getD k d' := by
  simp [List.getD_eq_getElem?_getD, List.getElem?_eq_getElem h]

theorem release_fold {c : Core} (h : SInv c) {l : LogCore} (hl : c.log = some l) (fees : List Engine.Ledger.Tier) (T delta : Int)
    (acct : Acct) (hcl : acct.cycles.length = c.cfg.names.length)
    (hmono : ∀ st ∈ l.steps, ∀ k, st.after.cycle k ≤ acct.cycles.getD k 0) :
    ∀ (R : List Logged), (∀ x ∈ R, x.known ≤ T) → VE l.steps delta R →
    ∀ a : Acct, a.cycles.length = c.cfg.names.length → (∀ k, a.cycle k ≤ acct.cycle k) → VT l.steps delta T a →
      (R.foldl (fun a x => a.apply fees x.time x.effect) a).cycles.length = c.cfg.names.length ∧
      (∀ k, (R.foldl (fun a x => a.apply fees x.time x.effect) a).cycle k ≤ acct.cycle k) ∧
      VT l.steps delta T (R.foldl (fun a x => a.apply fees x.time x.effect) a) := by
  intro R
  induction R with
  | nil => intro _ _ a hlen hva hvt; exact ⟨hlen, hva, hvt⟩
  | cons x R ih =>
    intro hR hve a hlen hva hvt
    simp only [List.foldl_cons]
    have hR' : ∀ y ∈ R, y.known ≤ T := fun y hy => hR y (List.mem_cons_of_mem _ hy)
    have hve' : VE l.steps delta R := fun y hy => hve y (List.mem_cons_of_mem _ hy)
    by_cases hx : ∃ k C, x.effect = .cycleEnd k C
    · obtain ⟨k, C, hxe⟩ := hx
      obtain ⟨st', hst', hk', hbef, hknown⟩ := hve x (List.mem_cons_self ..) k C hxe
      have hkn : k < c.cfg.names.length := h.endedLt l hl st' hst' k hk'
      have hxk : x.known ≤ T := hR x (List.mem_cons_self ..)
      have hcy : (a.apply fees x.time x.effect).cycles = replaceAt a.cycles k (fun _ => C + 1) := by
        rw [hxe]; exact apply_cycleEnd_cycles _ _ _ _ _
      have hcyc : ∀ j, (a.apply fees x.time x.effect).cycle j = if j = k then C + 1 else a.cycle j := by
        intro j
        unfold Acct.cycle
        rw [hcy]
        by_cases hj : j = k
        · subst hj
          simp only [ite_true]
          rw [replaceAt_getD_self _ _ _ _ (by omega)]
        · simp only [hj, ite_false]
          exact replaceAt_getD_ne _ _ _ _ _ (Ne.symm hj)
      have hstC : st'.after.cycle k = C + 1 := by
        have := ((h.steps l hl st' hst').2.2 k hk').2.1
        omega
      have hacc : acct.cycle k = acct.cycles.getD k 0 := getD_irrel acct.cycles k (by omega) 1 0
      have hle : C + 1 ≤ acct.cycle k := by
        have := hmono st' hst' k
        omega
      have hlen1 : (a.apply fees x.time x.effect).cycles.length = c.cfg.names.length := by
        rw [hcy, replaceAt_length]; exact hlen
      have hva1 : ∀ j, (a.apply fees x.time x.effect).cycle j ≤ acct.cycle j := by
        intro j
        rw [hcyc j]
        by_cases hj : j = k
        · subst hj; simpa using hle
        · simpa [hj] using hva j
      have hvt1 : VT l.steps delta T (a.apply fees x.time x.effect) := by
        intro st hst j hj hlt
        rw [hcyc j] at hlt
        by_cases hjk : j = k
        · subst hjk
          simp only [ite_true] at hlt
          have h1 : st.before.cycle j ≤ st'.before.cycle j := by omega
          have h2 := steps_order h hl hst hst' hj hk' h1
          omega
        · simp only [hjk, ite_false] at hlt
          exact hvt st hst j hj hlt
      exact ih hR' hve' _ hlen1 hva1 hvt1
    · have hcy : (a.apply fees x.time x.effect).cycles = a.cycles :=
        apply_cycles_of_not_end _ _ _ _ (fun coin cyc hh => hx ⟨coin, cyc, hh⟩)
      have hcyc : ∀ j, (a.apply fees x.time x.effect).cycle j = a.cycle j := by
        intro j; unfold Acct.cycle; rw [hcy]
      exact ih hR' hve' _ (by rw [hcy]; exact hlen) (fun j => by rw [hcyc]; exact hva j)
        (fun st hst k hk hlt => hvt st hst k hk (by rw [← hcyc k]; exact hlt))

end Engine.Machine
