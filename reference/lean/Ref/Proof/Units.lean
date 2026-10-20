import Ref.Proof.Eval

/-! The unit-instrumented machine against the executable one (L2): tagged values carry their static types,
evaluation never raises a unit error on a well-formed program, and erasing the tags gives the executable
machine's values. -/

namespace Ref
variable {α : Type} [Inhabited α]

omit [Inhabited α] in
theorem head!_none (l : List (Val α)) (h : ∀ x ∈ l, x = none) : l.head! = none := by
  cases l with
  | nil => rfl
  | cons a l => exact h a (by simp)

/-- A window that has only ever been pushed undefined values. -/
def Win.Blank : Win α → Prop
  | .lag _ buf => ∀ x ∈ buf, x = none
  | .sums _ n buf _ _ nones _ => 1 ≤ n ∧ (∀ x ∈ buf, x = none) ∧ nones = buf.length
  | .extreme _ _ _ _ dq => dq = []
  | .ema _ _ _ seen => seen = 0

omit [Inhabited α] in
theorem push_blank (N : NumOps α) (w : Win α) (hb : w.Blank) : (w.push N none).1.Blank ∧ (w.push N none).2 = none := by
  cases w with
  | lag k buf =>
    simp only [Win.Blank] at hb
    have hall : ∀ x ∈ buf ++ [none], x = none := by
      intro x hx; simp at hx; rcases hx with h | h; exact hb x h; exact h
    simp only [Win.push]
    by_cases hlen : (buf ++ [none]).length > k + 1
    · simp only [hlen, ite_true]
      have hd : ∀ x ∈ (buf ++ [none]).drop 1, x = none := fun x hx => hall x (List.mem_of_mem_drop hx)
      have ht : ∀ x ∈ (buf ++ [none]).tail, x = none := fun x hx => hall x (List.mem_of_mem_tail hx)
      exact ⟨hd, by split <;> simp [head!_none _ ht]⟩
    · simp only [hlen, ite_false]
      exact ⟨hall, by split <;> simp [head!_none _ hall]⟩
  | sums kind n buf sum sumsq nones since =>
    simp only [Win.Blank] at hb
    obtain ⟨hn, hbuf, hnones⟩ := hb
    have hall : ∀ x ∈ buf ++ [none], x = none := by
      intro x hx; simp at hx; rcases hx with h | h; exact hbuf x h; exact h
    simp only [Win.push]
    by_cases hlen : (buf ++ [none]).length > n
    · have hh : (buf ++ [none]).head! = none := head!_none _ hall
      simp only [hlen, ite_true, hh]
      have hd : ∀ x ∈ (buf ++ [none]).drop 1, x = none := fun x hx => hall x (List.mem_of_mem_drop hx)
      refine ⟨⟨hn, hd, ?_⟩, ?_⟩
      · simp [hnones]
      · split <;> simp_all <;> omega
    · simp only [hlen, ite_false]
      refine ⟨⟨hn, hall, by simp [hnones]⟩, ?_⟩
      split <;> simp_all <;> omega
  | extreme isMax n seq lastNone dq =>
    simp only [Win.Blank] at hb; subst hb
    simp [Win.push, Win.Blank]
  | ema n alpha s seen =>
    simp only [Win.Blank] at hb
    simp [Win.push, Win.Blank, hb]

/-- The instrumented state against the executable machine: erased values, every other field, static tags,
canonical booleans, window tags, and blank untagged windows. -/
structure URel (N : NumOps α) (p : Program) (u : UState α) (m : MState α) : Prop where
  vals : eraseTV u.tv = m.vals
  wins : u.m.wins = m.wins
  since : u.m.since = m.since
  funding : u.m.funding = m.funding
  bar : u.m.bar = m.bar
  events : u.m.events = m.events
  hour : u.m.hour = m.hour
  maxKnown : u.m.maxKnown = m.maxKnown
  tagged : Tagged N p u.tv
  tags : ∀ (i c : Nat) (t : Ty), u.wtag[i]![c]! = some t → t = p.types[i]!
  blank : ∀ (i c : Nat) (w : Win α), u.wtag[i]![c]! = none → u.m.wins[i]![c]! = some w → w.Blank
  winNode : ∀ (i c : Nat) (w : Win α), u.m.wins[i]![c]! = some w → ∃ k h args, p.nodes[i]! = .op (.window k h) args
  shape : u.wtag.size = u.m.wins.size ∧ ∀ i : Nat, u.wtag[i]!.size = u.m.wins[i]!.size

omit [Inhabited α] in
/-- Two loops, one failing and one total, that step in lockstep under a relation. -/
theorem forIn_rel {ε β σ τ : Type} (l : List β) (F : β → σ → Except ε (ForInStep σ)) (G : β → τ → Id (ForInStep τ))
    (R : σ → τ → Prop)
    (hF : ∀ a ∈ l, ∀ u m, R u m → ∃ u' m', F a u = .ok (.yield u') ∧ G a m = .yield m' ∧ R u' m') :
    ∀ u m, R u m → ∃ u', forIn l u F = .ok u' ∧ R u' (forIn (m := Id) l m G) := by
  induction l with
  | nil => intro u m h; exact ⟨u, rfl, h⟩
  | cons a l ih =>
    intro u m h
    obtain ⟨u', m', hu, hm, h'⟩ := hF a (by simp) u m h
    obtain ⟨u'', hu'', h''⟩ := ih (fun a' ha' => hF a' (by simp [ha'])) u' m' h'
    refine ⟨u'', ?_, ?_⟩
    · simp only [List.forIn_cons, hu, bind, Except.bind]; exact hu''
    · simp only [List.forIn_cons, hm]; exact h''

omit [Inhabited α] in
theorem eval_congr (N : NumOps α) (p : Program) {m₁ m₂ : MState α} (hv : m₁.vals = m₂.vals)
    (hf : m₁.funding = m₂.funding) (hb : m₁.bar = m₂.bar) (he : m₁.events = m₂.events) (hh : m₁.hour = m₂.hour)
    (i c : Nat) : MState.eval N p m₁ i c = MState.eval N p m₂ i c := by
  have hin : ∀ inp c, m₁.input inp c = m₂.input inp c := by
    intro inp c; cases inp <;> simp [MState.input, hf, hb, he, hh]
  simp only [MState.eval, hv, hin]

omit [Inhabited α] in
theorem eraseTV_modify (tv : Array (Array (TVal α))) (i c : Nat) (v : TVal α) :
    eraseTV (tv.modify i fun row => row.set! c v) = (eraseTV tv).modify i fun row => row.set! c (v.map (·.1)) := by
  unfold eraseTV
  apply Array.ext
  · simp
  · intro j h₁ h₂
    simp only [Array.getElem_map, Array.getElem_modify]
    split
    · apply Array.ext
      · simp
      · intro k h₃ h₄
        simp only [Array.set!_eq_setIfInBounds, Array.size_map, Array.size_setIfInBounds] at h₃ h₄
        simp only [Array.getElem_map, Array.set!_eq_setIfInBounds]
        rw [Array.getElem_setIfInBounds h₃, Array.getElem_setIfInBounds (by simpa using h₃)]
        split <;> simp
    · simp

omit [Inhabited α] in
/-- Reading after a row update gives the written value exactly where it was written, in bounds. -/
theorem get_modify_set {β : Type} [Inhabited β] (xs : Array (Array β)) (i c j k : Nat) (v : β) :
    (xs.modify i fun row => row.set! c v)[j]![k]! =
      if j = i ∧ i < xs.size ∧ c < xs[i]!.size ∧ k = c then v else xs[j]![k]! := by
  by_cases hj : j < xs.size
  · rw [getElem!_pos _ j (by simpa using hj), getElem!_pos xs j hj, Array.getElem_modify]
    split
    · rename_i hij; subst hij
      simp only [Array.set!_eq_setIfInBounds, getElem!_pos xs i hj, true_and, hj]
      by_cases hk : k < xs[i].size
      · rw [getElem!_pos _ k (by simpa using hk), getElem!_pos _ k hk]
        by_cases hck : c = k
        · subst hck; simp [hk]
        · simp [Array.getElem_setIfInBounds_ne hk hck, Ne.symm hck]
      · rw [getElem!_neg _ k (by simpa using hk), getElem!_neg _ k hk]
        split <;> simp_all
    · rename_i hij; simp [Ne.symm hij]
  · rw [getElem!_neg _ j (by simpa using hj), getElem!_neg xs j hj]
    split <;> simp_all

omit [Inhabited α] in
theorem size_modify_set {β : Type} [Inhabited β] (xs : Array (Array β)) (i c j : Nat) (v : β) :
    (xs.modify i fun row => row.set! c v)[j]!.size = xs[j]!.size := by
  by_cases hj : j < xs.size
  · rw [getElem!_pos _ j (by simpa using hj), getElem!_pos xs j hj, Array.getElem_modify]
    split <;> simp
  · rw [getElem!_neg _ j (by simpa using hj), getElem!_neg xs j hj]

omit [Inhabited α] in
theorem modify_set_self {β : Type} [Inhabited β] (xs : Array (Array β)) (i c : Nat) :
    (xs.modify i fun row => row.set! c xs[i]![c]!) = xs := by
  apply Array.ext
  · simp
  · intro j h₁ h₂
    simp only [Array.getElem_modify]
    split
    · rename_i hij; subst hij
      apply Array.ext
      · simp
      · intro k h₃ h₄
        simp only [Array.set!_eq_setIfInBounds, Array.size_setIfInBounds] at h₃ ⊢
        rw [Array.getElem_setIfInBounds h₃]
        split
        · rename_i hck; subst hck; rw [getElem!_pos xs i (by simpa using h₂), getElem!_pos _ c h₃]
        · rfl
    · rfl

omit [Inhabited α] in
theorem keepT_erase (N : NumOps α) (v : TVal α) : (keepT N v).map (·.1) = (v.map (·.1)).bind N.keep := by
  cases v with
  | none => rfl
  | some xt => simp only [keepT, NumOps.keep, Option.bind_some, Option.map_some]; split <;> simp

omit [Inhabited α] in
theorem keepT_some {N : NumOps α} {v : TVal α} {x : α} {t : Ty} (h : keepT N v = some (x, t)) : v = some (x, t) := by
  cases v with
  | none => cases h
  | some xt => cases xt; simp only [keepT, NumOps.keep, Option.bind_some] at h; split at h <;> simp_all

/-- One coin of one node written on both sides keeps the relation, if the written value is tagged by the
node's type, the window's tag is too, and an untagged window stays blank. -/
theorem URel_update (N : NumOps α) (p : Program) {u : UState α} {m : MState α} (hR : URel N p u m) (i c : Nat)
    (v : TVal α) (hv : ∀ x t, v = some (x, t) → t = p.types[i]! ∧ (t = .bool → ∃ b, x = N.truth b))
    (w : Option (Win α)) (tag : Option Ty) (htag : ∀ t, tag = some t → t = p.types[i]!)
    (hblank : ∀ w', tag = none → w = some w' → w'.Blank)
    (hwin : ∀ w', w = some w' → ∃ k h args, p.nodes[i]! = .op (.window k h) args) :
    URel N p (UState.mk { u.m with wins := u.m.wins.modify i (fun row => row.set! c w) }
               (u.tv.modify i (fun row => row.set! c (keepT N v)))
               (u.wtag.modify i (fun row => row.set! c tag)))
      ({ m with
          vals := m.vals.modify i (fun row => row.set! c ((v.map Prod.fst).bind N.keep))
          wins := m.wins.modify i (fun row => row.set! c w) } : MState α) := by
  refine ⟨?_, ?_, hR.since, hR.funding, hR.bar, hR.events, hR.hour, hR.maxKnown, ?_, ?_, ?_, ?_, ?_⟩
  · simp only [eraseTV_modify, keepT_erase, hR.vals]
  · simp only [hR.wins]
  · intro j k x t hx
    rw [get_modify_set] at hx
    split at hx
    · rename_i hc; obtain ⟨rfl, -, -, rfl⟩ := hc; exact hv x t (keepT_some hx)
    · exact hR.tagged j k x t hx
  · intro j k t ht
    rw [get_modify_set] at ht
    split at ht
    · rename_i hc; obtain ⟨rfl, -, -, rfl⟩ := hc; exact htag t ht
    · exact hR.tags j k t ht
  · intro j k w' ht hw
    simp only at hw
    rw [get_modify_set] at ht hw
    have hs : (j = i ∧ i < u.wtag.size ∧ c < u.wtag[i]!.size ∧ k = c) ↔
        (j = i ∧ i < u.m.wins.size ∧ c < u.m.wins[i]!.size ∧ k = c) := by rw [hR.shape.1, hR.shape.2 i]
    split at hw
    · rw [if_pos (hs.2 ‹_›)] at ht; exact hblank w' ht hw
    · rw [if_neg (fun h => ‹¬_› (hs.1 h))] at ht; exact hR.blank j k w' ht hw
  · intro j k w' hw
    simp only at hw
    rw [get_modify_set] at hw
    split at hw
    · rename_i hc; obtain ⟨rfl, -, -, rfl⟩ := hc; exact hwin w' hw
    · exact hR.winNode j k w' hw
  · simp only [Array.size_modify, size_modify_set]
    exact hR.shape

omit [Inhabited α] in
theorem step_of_loop {ε β σ τ : Type} {l : List β} {F : β → σ → Except ε (ForInStep σ)} {G : β → τ → Id (ForInStep τ)}
    {R : σ → τ → Prop} {u : σ} {m : τ} (h : ∃ u', forIn l u F = .ok u' ∧ R u' (forIn (m := Id) l m G)) :
    ∃ u' m', (forIn l u F >>= fun s => pure (ForInStep.yield s)) = .ok (.yield u') ∧
      (forIn (m := Id) l m G >>= fun s => pure (ForInStep.yield s)) = ForInStep.yield m' ∧ R u' m' := by
  obtain ⟨u', hu, hR⟩ := h
  exact ⟨u', _, by rw [hu]; rfl, rfl, hR⟩

theorem tick_rel (N : NumOps α) (p : Program) (hW : p.WF) (listed : Array Bool) (hour : Int) (u : UState α)
    (m : MState α) (h : URel N p u m) :
    ∃ u', u.tick N p listed hour = .ok u' ∧ URel N p u' (m.tick N p listed hour) := by
  unfold UState.tick MState.tick
  simp only [Std.Legacy.Range.forIn_eq_forIn_range', bind_pure, Id.run]
  refine forIn_rel _ _ _ (URel N p) ?_ _ _ ?_
  · intro i hi u m hR
    have hi' : i < p.nodes.size := by simp at hi; omega
    cases hn : p.nodes[i]! with
    | input inp =>
      refine step_of_loop (forIn_rel _ _ _ (URel N p) ?_ u m hR)
      intro c hc u m hR
      obtain ⟨r, hr, he, ht⟩ := evalU_leaf N p u.m u.tv i c hW hi' (by simp [hn])
      have hev : MState.eval N p m i c = r.map (·.1) := by
        rw [he]; exact eval_congr N p (m₂ := { u.m with vals := eraseTV u.tv }) hR.vals.symm hR.funding.symm
          hR.bar.symm hR.events.symm hR.hour.symm i c
      have hwm : m.wins[i]![c]! = u.m.wins[i]![c]! := by rw [hR.wins]
      by_cases hl : listed[c]! = true
      · simp only [hl, ite_true, hr, hev, bind, Except.bind, hwm]
        cases hw : u.m.wins[i]![c]! with
        | none =>
          refine ⟨_, _, rfl, rfl, ?_⟩
          have key := URel_update N p hR i c r ht (u.m.wins[i]![c]!) (u.wtag[i]![c]!) (hR.tags i c) (by simp [hw])
            (by simp [hw])
          rw [modify_set_self, modify_set_self] at key
          simpa [hw] using key
        | some w =>
          obtain ⟨_, _, _, hn'⟩ := hR.winNode i c w hw
          rw [hn] at hn'; cases hn'
      · simp only [hl, Bool.false_eq_true, ite_false, hwm, pure, Except.pure, bind, Except.bind]
        have key := URel_update N p hR i c none (by simp) (u.m.wins[i]![c]!) (u.wtag[i]![c]!) (hR.tags i c)
          (fun w' ht hw' => hR.blank i c w' ht hw') (fun w' hw' => hR.winNode i c w' hw')
        rw [modify_set_self, modify_set_self] at key
        cases hw : u.m.wins[i]![c]! <;> simp only [Bool.not_false, ite_true] <;> refine ⟨_, _, rfl, rfl, ?_⟩ <;>
          simpa [hw] using key
    | _ => sorry
  · exact { h with hour := rfl }

end Ref
