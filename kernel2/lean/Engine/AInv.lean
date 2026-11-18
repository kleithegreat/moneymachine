import Engine.RInvArrival

/-!
# R1's arrival and admission invariants (brief 3 step 5)

The wishes that arrive, in order, and the admissions they make, from which R1's arrival, admission and placement streams
follow.
-/

namespace Engine.Machine

open Engine.Orders (Wish Order Arrival arrive admission)

structure AInv (c : Core) : Prop where
  own : ∀ l, c.log = some l → ∀ a ∈ l.arrivals, a.time = a.wish.arrives ∧ a.after = (arrive a.before a.wish).1
  sorted : ∀ l, c.log = some l → l.arrivals.Pairwise fun a b => a.time ≤ b.time
  queue : ∀ l, c.log = some l → ∀ a ∈ l.arrivals, ∀ w ∈ c.wishes, a.time ≤ w.arrives
  tick : ∀ l, c.log = some l → ∀ a ∈ l.arrivals, ∀ t, c.nextTick = some t → a.time < t
  stop : ∀ l, c.log = some l → ∀ a ∈ l.arrivals, a.time < c.cfg.stop
  admPairs : ∀ l, c.log = some l → l.admissions.Pairwise fun a b =>
    a.2.placed = b.2.placed → KeyLt (orderKey a.2) (orderKey b.2)
  admQueue : ∀ l, c.log = some l → ∀ x ∈ l.admissions, ∀ w ∈ c.wishes, x.2.placed = w.arrives →
    KeyLt (orderKey x.2) (wishKey w)
  admTick : ∀ l, c.log = some l → ∀ x ∈ l.admissions, ∀ t, c.nextTick = some t → x.2.placed < t
  placedAdm : ∀ l, c.log = some l → l.placed.map (·.order) =
    l.admissions.filterMap fun a => (Engine.Orders.admit (admission a.1 a.2)).toOption

theorem wishLe_arrives {a b : Wish} (h : wishLe a b = true) : a.arrives ≤ b.arrives := by
  unfold wishLe at h
  simp only [Bool.or_eq_true, Bool.and_eq_true, decide_eq_true_eq] at h
  omega

theorem keyLt_of_sorted {a b : Wish} (h : wishLe a b = true ∧ (a.arrives = b.arrives → (a.coin, a.slot) ≠ (b.coin, b.slot)))
    (he : a.arrives = b.arrives) : KeyLt (wishKey a) (wishKey b) := by
  obtain ⟨h1, h2⟩ := h
  have hne := h2 he
  unfold wishLe wishRank at h1
  simp only [Bool.or_eq_true, Bool.and_eq_true, decide_eq_true_eq] at h1
  unfold KeyLt wishKey
  simp only [Prod.mk.injEq, ne_eq, not_and] at hne ⊢
  cases ha : a.reduceOnly <;> cases hb : b.reduceOnly <;> simp [ha, hb] at h1 ⊢ <;> omega

theorem aInv_congr {c c' : Core} (h : AInv c) (hstop : c'.cfg.stop = c.cfg.stop) (hn : c'.nextTick = c.nextTick)
    (hw : c'.wishes = c.wishes)
    (hl : c'.log.map (fun l => (l.arrivals, l.admissions, l.placed)) = c.log.map (fun l => (l.arrivals, l.admissions, l.placed))) :
    AInv c' := by
  have key : ∀ l', c'.log = some l' → ∃ l, c.log = some l ∧ l'.arrivals = l.arrivals ∧ l'.admissions = l.admissions ∧
      l'.placed = l.placed := by
    intro l' hl'
    rw [hl'] at hl
    cases hc : c.log with
    | none => rw [hc] at hl; simp at hl
    | some l =>
      rw [hc] at hl
      simp only [Option.map_some, Option.some.injEq, Prod.mk.injEq] at hl
      exact ⟨l, rfl, hl.1, hl.2.1, hl.2.2⟩
  refine ⟨?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_⟩
  · intro l' hl'; obtain ⟨l, hlc, e1, _⟩ := key l' hl'; rw [e1]; exact h.own l hlc
  · intro l' hl'; obtain ⟨l, hlc, e1, _⟩ := key l' hl'; rw [e1]; exact h.sorted l hlc
  · intro l' hl' a ha w hw'; obtain ⟨l, hlc, e1, _⟩ := key l' hl'; rw [e1] at ha; rw [hw] at hw'
    exact h.queue l hlc a ha w hw'
  · intro l' hl' a ha t ht; obtain ⟨l, hlc, e1, _⟩ := key l' hl'; rw [e1] at ha; rw [hn] at ht
    exact h.tick l hlc a ha t ht
  · intro l' hl' a ha; obtain ⟨l, hlc, e1, _⟩ := key l' hl'; rw [e1] at ha; rw [hstop]
    exact h.stop l hlc a ha
  · intro l' hl'; obtain ⟨l, hlc, _, e2, _⟩ := key l' hl'; rw [e2]; exact h.admPairs l hlc
  · intro l' hl' x hx w hw'; obtain ⟨l, hlc, _, e2, _⟩ := key l' hl'; rw [e2] at hx; rw [hw] at hw'
    exact h.admQueue l hlc x hx w hw'
  · intro l' hl' x hx t ht; obtain ⟨l, hlc, _, e2, _⟩ := key l' hl'; rw [e2] at hx; rw [hn] at ht
    exact h.admTick l hlc x hx t ht
  · intro l' hl'; obtain ⟨l, hlc, _, e2, e3⟩ := key l' hl'; rw [e2, e3]; exact h.placedAdm l hlc

end Engine.Machine
