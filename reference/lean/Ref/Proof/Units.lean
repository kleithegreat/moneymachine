import Ref.Proof.Eval
import Ref.Proof.Prefix

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

/-- `hours_since` reads a boolean and counts hours. -/
theorem opTy_hoursSince {ts : List Ty} {to : Option Dim} {t : Ty} (hty : opTy .hoursSince ts to = some t) :
    ts[0]? = some .bool ∧ t = .num (Dim.base "h").get! := by
  simp only [opTy] at hty
  split at hty
  · rename_i hb; simp at hb hty; exact ⟨hb, hty.symm⟩
  · cases hty

/-- The cross-sectional mean and demeaned value keep their argument's unit. -/
theorem opTy_xs {o : Op} (ho : o = .xsMean ∨ o = .xsDemean ∨ o = .xsRank) {ts : List Ty} {to : Option Dim} {t : Ty}
    (hty : opTy o ts to = some t) : ∃ d, ts[0]? = some (.num d) ∧ t = .num d ∧ (o = .xsRank → d = Dim.one) := by
  rcases ho with rfl | rfl | rfl <;> simp only [opTy] at hty <;> revert hty <;> cases ts[0]? <;> simp <;>
    rename_i x <;> cases x <;> simp <;> intros <;> subst_vars <;> simp

/-- A window node is numeric, over at least one hour. -/
theorem opTy_window {k : Window} {h : Nat} {ts : List Ty} {to : Option Dim} {t : Ty}
    (hty : opTy (.window k h) ts to = some t) : (∃ d, t = .num d) ∧ 1 ≤ h := by
  simp only [opTy] at hty
  split at hty
  · rename_i hh
    refine ⟨?_, by simp at hh; omega⟩
    revert hty
    cases ts[0]? with
    | none => simp
    | some x => cases x <;> simp; intro hx; exact ⟨_, hx.symm⟩
  · cases hty

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

/-- A raw value written on both sides, with the same `since` state, keeps the relation. -/
theorem URel_raw (N : NumOps α) (p : Program) {u : UState α} {m : MState α} (hR : URel N p u m) (i c : Nat)
    (v : TVal α) (hv : ∀ x t, v = some (x, t) → t = p.types[i]! ∧ (t = .bool → ∃ b, x = N.truth b))
    (S : Array (Array (Option Int))) :
    URel N p (UState.mk { u.m with since := S } (u.tv.modify i (fun row => row.set! c v)) u.wtag)
      ({ m with
          vals := m.vals.modify i (fun row => row.set! c (v.map Prod.fst))
          since := S } : MState α) := by
  refine ⟨?_, hR.wins, rfl, hR.funding, hR.bar, hR.events, hR.hour, hR.maxKnown, ?_, hR.tags, hR.blank,
    hR.winNode, hR.shape⟩
  · simp only [eraseTV_modify, hR.vals]
  · intro j k x t hx
    rw [get_modify_set] at hx
    split at hx
    · rename_i hc; obtain ⟨rfl, -, -, rfl⟩ := hc; exact hv x t hx
    · exact hR.tagged j k x t hx

omit [Inhabited α] in
theorem eraseTV_set (tv : Array (Array (TVal α))) (i : Nat) (row : Array (TVal α)) :
    eraseTV (tv.set! i row) = (eraseTV tv).set! i (row.map (·.map (·.1))) := by
  unfold eraseTV
  apply Array.ext
  · simp
  · intro j h₁ h₂
    simp only [Array.set!_eq_setIfInBounds, Array.getElem_map]
    simp only [Array.set!_eq_setIfInBounds, Array.size_map, Array.size_setIfInBounds] at h₁
    rw [Array.getElem_setIfInBounds h₁, Array.getElem_setIfInBounds (by simpa using h₁)]
    split <;> simp

omit [Inhabited α] in
theorem get_set {β : Type} [Inhabited β] (xs : Array (Array β)) (i j k : Nat) (row : Array β) :
    (xs.set! i row)[j]![k]! = if j = i ∧ i < xs.size then row[k]! else xs[j]![k]! := by
  simp only [Array.set!_eq_setIfInBounds]
  by_cases hj : j < xs.size
  · rw [getElem!_pos _ j (by simpa using hj), getElem!_pos xs j hj, Array.getElem_setIfInBounds hj]
    by_cases hij : i = j
    · subst hij; simp [hj]
    · simp [hij, Ne.symm hij]
  · rw [getElem!_neg _ j (by simpa using hj), getElem!_neg xs j hj]
    split <;> simp_all

/-- A whole node row written on both sides keeps the relation, if the written values are tagged by the
node's type. -/
theorem URel_setRow (N : NumOps α) (p : Program) {u : UState α} {m : MState α} (hR : URel N p u m) (i : Nat)
    (row : Array (TVal α)) (rowM : Array (Val α))
    (hrow : ∀ (k : Nat) x t, row[k]! = some (x, t) → t = p.types[i]! ∧ (t = .bool → ∃ b, x = N.truth b))
    (he : row.map (·.map (·.1)) = rowM) :
    URel N p { u with tv := u.tv.set! i row } { m with vals := m.vals.set! i rowM } := by
  subst he
  refine ⟨?_, hR.wins, hR.since, hR.funding, hR.bar, hR.events, hR.hour, hR.maxKnown, ?_, hR.tags, hR.blank,
    hR.winNode, hR.shape⟩
  · simp only [eraseTV_set, hR.vals]
  · intro j k x t hx
    rw [get_set] at hx
    split at hx
    · rename_i hc; obtain ⟨rfl, -⟩ := hc; exact hrow k x t hx
    · exact hR.tagged j k x t hx

theorem mapM_const {ε β γ : Type} (xs : List β) (f : β → Except ε γ) (d : γ) (h : ∀ x ∈ xs, f x = .ok d) :
    xs.mapM f = .ok (xs.map fun _ => d) := by
  induction xs with
  | nil => rfl
  | cons x xs ih =>
    rw [List.mapM_cons, h x (by simp), ih fun y hy => h y (by simp [hy])]
    rfl

omit [Inhabited α] in
theorem replicate_none_get {β : Type} (n k : Nat) : (Array.replicate n (none : Option β))[k]! = none := by
  by_cases hk : k < n
  · rw [getElem!_pos _ k (by simpa using hk)]; simp
  · rw [getElem!_neg _ k (by simpa using hk)]; rfl

omit [Inhabited α] in
theorem getElem!_some_mem {β : Type} (a : Array (Option β)) (k : Nat) {y : β} (h : a[k]! = some y) :
    some y ∈ a.toList := by
  by_cases hk : k < a.size
  · rw [getElem!_pos a k hk] at h; rw [← h]; exact Array.getElem_mem_toList hk
  · rw [getElem!_neg a k hk] at h; cases h

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
    have hWi := hW.2.2.2.2.2 i hi'
    cases hn : p.nodes[i]! with
    | input inp =>
      have hev := fun (u : UState α) (_ : Tagged N p u.tv) c => evalU_leaf N p u.m u.tv i c hW hi' (by simp [hn])
      refine step_of_loop (forIn_rel _ _ _ (URel N p) ?_ u m hR)
      intro c hc u m hR
      obtain ⟨r, hr, he, ht⟩ := hev u hR.tagged c
      have hev' : MState.eval N p m i c = r.map (·.1) := by
        rw [he]; exact eval_congr N p (m₂ := { u.m with vals := eraseTV u.tv }) hR.vals.symm hR.funding.symm
          hR.bar.symm hR.events.symm hR.hour.symm i c
      have hwm : m.wins[i]![c]! = u.m.wins[i]![c]! := by rw [hR.wins]
      by_cases hl : listed[c]! = true
      · simp only [hl, ite_true, hr, hev', bind, Except.bind, hwm]
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
    | const bits d =>
      have hev := fun (u : UState α) (_ : Tagged N p u.tv) c => evalU_leaf N p u.m u.tv i c hW hi' (by simp [hn])
      refine step_of_loop (forIn_rel _ _ _ (URel N p) ?_ u m hR)
      intro c hc u m hR
      obtain ⟨r, hr, he, ht⟩ := hev u hR.tagged c
      have hev' : MState.eval N p m i c = r.map (·.1) := by
        rw [he]; exact eval_congr N p (m₂ := { u.m with vals := eraseTV u.tv }) hR.vals.symm hR.funding.symm
          hR.bar.symm hR.events.symm hR.hour.symm i c
      have hwm : m.wins[i]![c]! = u.m.wins[i]![c]! := by rw [hR.wins]
      by_cases hl : listed[c]! = true
      · simp only [hl, ite_true, hr, hev', bind, Except.bind, hwm]
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
    | param k =>
      have hev := fun (u : UState α) (_ : Tagged N p u.tv) c => evalU_leaf N p u.m u.tv i c hW hi' (by simp [hn])
      refine step_of_loop (forIn_rel _ _ _ (URel N p) ?_ u m hR)
      intro c hc u m hR
      obtain ⟨r, hr, he, ht⟩ := hev u hR.tagged c
      have hev' : MState.eval N p m i c = r.map (·.1) := by
        rw [he]; exact eval_congr N p (m₂ := { u.m with vals := eraseTV u.tv }) hR.vals.symm hR.funding.symm
          hR.bar.symm hR.events.symm hR.hour.symm i c
      have hwm : m.wins[i]![c]! = u.m.wins[i]![c]! := by rw [hR.wins]
      by_cases hl : listed[c]! = true
      · simp only [hl, ite_true, hr, hev', bind, Except.bind, hwm]
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
    | op o args =>
      rw [hn] at hWi
      cases o
      case window k h =>
        have hev := fun (u : UState α) (hT : Tagged N p u.tv) c =>
          evalU_op N p u.m u.tv i c _ args hn _ hWi.2 hT (by simp)
        obtain ⟨⟨d, hd⟩, -⟩ := opTy_window hWi.2
        refine step_of_loop (forIn_rel _ _ _ (URel N p) ?_ u m hR)
        intro c hc u m hR
        obtain ⟨r, hr, he, ht⟩ := hev u hR.tagged c
        have hev' : MState.eval N p m i c = r.map (·.1) := by
          rw [he]; exact eval_congr N p (m₂ := { u.m with vals := eraseTV u.tv }) hR.vals.symm hR.funding.symm
            hR.bar.symm hR.events.symm hR.hour.symm i c
        have hwm : m.wins[i]![c]! = u.m.wins[i]![c]! := by rw [hR.wins]
        by_cases hl : listed[c]! = true
        · simp only [hl, ite_true, hr, hev', bind, Except.bind, hwm]
          cases hw : u.m.wins[i]![c]! with
          | none =>
            refine ⟨_, _, rfl, rfl, ?_⟩
            have key := URel_update N p hR i c r ht (u.m.wins[i]![c]!) (u.wtag[i]![c]!) (hR.tags i c) (by simp [hw])
              (by simp [hw])
            rw [modify_set_self, modify_set_self] at key
            simpa [hw] using key
          | some w =>
            simp only [Bool.not_true, Bool.false_eq_true, ite_false]
            have tagged_out : ∀ (o : Val α), ∀ x' t'', (o.map (·, p.types[i]!)) = some (x', t'') →
                t'' = p.types[i]! ∧ (t'' = .bool → ∃ b, x' = N.truth b) := by
              intro o x' t'' ho; cases o <;> simp at ho; obtain ⟨-, rfl⟩ := ho; simp [hd]
            rcases r with _ | ⟨x, t⟩ <;> rcases hwt : u.wtag[i]![c]! with _ | t'
            · obtain ⟨hb', hout⟩ := push_blank N w (hR.blank i c w hwt hw)
              simp only [Option.map_none, hout, pure, Except.pure]
              refine ⟨_, _, rfl, rfl, ?_⟩
              have key := URel_update N p hR i c none (by simp) (some (w.push N none).1) none (by simp)
                (fun w' _ h => by cases h; exact hb') (fun w' _ => hR.winNode i c w hw)
              simpa [hout] using key
            · have ht' := hR.tags i c t' hwt; subst ht'
              simp only [Option.map_none, pure, Except.pure]
              refine ⟨_, _, rfl, rfl, ?_⟩
              · have key := URel_update N p hR i c (((w.push N none).2).map (·, p.types[i]!))
                  (tagged_out _) (some (w.push N none).1) (some p.types[i]!) (by simp) (by simp)
                  (fun w' _ => hR.winNode i c w hw)
                cases ho : (w.push N none).2 <;> simpa [ho] using key
            · obtain ⟨rfl, -⟩ := ht x t rfl
              simp only [Option.map_some, pure, Except.pure]
              refine ⟨_, _, rfl, rfl, ?_⟩
              · have key := URel_update N p hR i c (((w.push N (some x)).2).map (·, p.types[i]!))
                  (tagged_out _) (some (w.push N (some x)).1) (some p.types[i]!) (by simp) (by simp)
                  (fun w' _ => hR.winNode i c w hw)
                cases ho : (w.push N (some x)).2 <;> simpa [ho] using key
            · obtain ⟨rfl, -⟩ := ht x t rfl
              have ht' := hR.tags i c t' hwt; subst ht'
              simp only [Option.map_some, beq_self_eq_true, ite_true, pure, Except.pure]
              refine ⟨_, _, rfl, rfl, ?_⟩
              · have key := URel_update N p hR i c (((w.push N (some x)).2).map (·, p.types[i]!))
                  (tagged_out _) (some (w.push N (some x)).1) (some p.types[i]!) (by simp) (by simp)
                  (fun w' _ => hR.winNode i c w hw)
                cases ho : (w.push N (some x)).2 <;> simpa [ho] using key
        · simp only [hl, Bool.false_eq_true, ite_false, hwm, pure, Except.pure, bind, Except.bind]
          have key := URel_update N p hR i c none (by simp) (u.m.wins[i]![c]!) (u.wtag[i]![c]!) (hR.tags i c)
            (fun w' ht hw' => hR.blank i c w' ht hw') (fun w' hw' => hR.winNode i c w' hw')
          rw [modify_set_self, modify_set_self] at key
          cases hw : u.m.wins[i]![c]! <;> simp only [Bool.not_false, ite_true] <;> refine ⟨_, _, rfl, rfl, ?_⟩ <;>
            simpa [hw] using key
      case hoursSince =>
        obtain ⟨hb, hti⟩ := opTy_hoursSince hWi.2
        obtain ⟨a, rest, rfl⟩ : ∃ a rest, args = a :: rest := by
          cases args with
          | nil => simp at hb
          | cons a rest => exact ⟨a, rest, rfl⟩
        simp only [List.map_cons, List.getElem?_cons_zero, Option.some.injEq] at hb
        refine step_of_loop (forIn_rel _ _ _ (URel N p) ?_ u m hR)
        intro c hc u m hR
        have hva : m.vals[a]![c]! = (u.tv[a]![c]!).map (·.1) := by rw [← hR.vals, eraseTV_get]
        have hsm : m.since = u.m.since := hR.since.symm
        simp only [List.getElem!_cons_zero, hva, hsm]
        have hv : ∀ S : Array (Array (Option Int)), ∀ x t,
            (if listed[c]! = true then (S[i]![c]!).map (fun t => (N.ofInt ((hour - t) / HOUR), Ty.num (Dim.base "h").get!))
              else none) = some (x, t) → t = p.types[i]! ∧ (t = .bool → ∃ b, x = N.truth b) := by
          intro S x t hx; split at hx <;> simp at hx; obtain ⟨-, -, -, rfl⟩ := hx; simp [hti]
        rcases hu : u.tv[a]![c]! with _ | ⟨x, t⟩
        · simp only [Option.map_none, pure, Except.pure, bind, Except.bind, Bool.and_false, Bool.false_eq_true,
            ite_false]
          refine ⟨_, _, rfl, rfl, ?_⟩
          have key := URel_raw N p hR i c _ (hv u.m.since) u.m.since
          rw [show ({ u.m with since := u.m.since } : MState α) = u.m from rfl] at key
          by_cases hl : listed[c]! = true <;> simp [hl, Option.map_map, Function.comp_def] at key ⊢ <;> exact key
        · obtain ⟨rfl, -⟩ := hR.tagged a c x t hu
          rw [hb]
          simp only [Option.map_some, pure, Except.pure, bind, Except.bind]
          by_cases hf : (listed[c]! && !N.isZero x) = true
          · simp only [hf, ite_true]
            refine ⟨_, _, rfl, rfl, ?_⟩
            have key := URel_raw N p hR i c _ (hv (u.m.since.modify i fun row => row.set! c (some hour)))
              (u.m.since.modify i fun row => row.set! c (some hour))
            by_cases hl : listed[c]! = true <;> simp [hl, Option.map_map, Function.comp_def] at key ⊢ <;> exact key
          · simp only [hf, Bool.false_eq_true, ite_false]
            refine ⟨_, _, rfl, rfl, ?_⟩
            have key := URel_raw N p hR i c _ (hv u.m.since) u.m.since
            rw [show ({ u.m with since := u.m.since } : MState α) = u.m from rfl] at key
            by_cases hl : listed[c]! = true <;> simp [hl, Option.map_map, Function.comp_def] at key ⊢ <;> exact key
      case xsMean =>
        dsimp only
        obtain ⟨d, hd0, hti, -⟩ := opTy_xs (Or.inl rfl) hWi.2
        obtain ⟨a, rest, rfl⟩ : ∃ a rest, args = a :: rest := by
          cases args with
          | nil => simp at hd0
          | cons a rest => exact ⟨a, rest, rfl⟩
        simp only [List.map_cons, List.getElem?_cons_zero, Option.some.injEq] at hd0
        simp only [List.getElem!_cons_zero]
        have hX : ∀ x ∈ List.filterMap (fun c => if listed[c]! = true then Option.map (fun x => (c, x)) u.tv[a]![c]!
            else none) (List.range listed.size), x.2.2 = .num d := by
          intro x hx
          simp only [List.mem_filterMap, List.mem_range] at hx
          obtain ⟨c, -, hc⟩ := hx
          split at hc
          · cases hv : u.tv[a]![c]! with
            | none => rw [hv] at hc; cases hc
            | some y => rw [hv] at hc; cases hc; rw [(hR.tagged a c y.1 y.2 hv).1, hd0]
          · cases hc
        rw [mapM_const _ _ d fun x hx => by simp [hX x hx]; rfl]
        have hvm : ∀ c : Nat, m.vals[a]![c]! = Option.map Prod.fst (u.tv[a]![c]! : TVal α) := fun c => by
          rw [← hR.vals, eraseTV_get]
        have hXM : List.filterMap (fun c => if listed[c]! = true then Option.map (fun x => (c, x)) m.vals[a]![c]!
            else none) (List.range listed.size) =
            (List.filterMap (fun c => if listed[c]! = true then Option.map (fun x => (c, x)) u.tv[a]![c]!
              else none) (List.range listed.size)).map (fun x => (x.1, x.2.1)) := by
          rw [List.map_filterMap]; congr 1; funext c; rw [hvm]; split <;> simp [Option.map_map, Function.comp_def]
        rw [hXM]
        generalize List.filterMap (fun c => if listed[c]! = true then Option.map (fun x => (c, x)) u.tv[a]![c]!
          else none) (List.range listed.size) = X at hX ⊢
        simp only [bind, Except.bind, pure, Except.pure, throw, throwThe, MonadExceptOf.throw]
        cases X with
        | nil =>
          simp only [List.map_nil, List.all_nil, Bool.not_true, Bool.false_eq_true, ite_false, List.isEmpty_nil,
            Bool.not_true, Bool.and_false, ite_true]
          refine ⟨_, _, rfl, rfl, ?_⟩
          exact URel_setRow N p hR i _ _ (by simp [replicate_none_get]) (by simp)
        | cons x0 X =>
          simp only [List.map_cons, List.headD_cons, List.isEmpty_cons, Bool.false_eq_true, ite_false]
          rw [if_neg (by simp), if_neg (by simp)]
          refine ⟨_, _, rfl, rfl, ?_⟩
          refine URel_setRow N p hR i _ _ ?_ ?_
          · intro k x t hx
            have hm := getElem!_some_mem _ k hx
            simp only [List.toList_toArray, List.mem_map] at hm
            obtain ⟨c, -, hc⟩ := hm
            split at hc
            · cases hc
            · simp at hc; (try obtain ⟨_, -, -, rfl⟩ := hc); (try obtain ⟨-, rfl⟩ := hc); simp [hti]
          · rw [List.map_toArray]
            congr 1
            simp only [List.map_map]
            apply List.map_congr_left
            intro c _
            simp only [Function.comp_def]
            rw [show (x0.fst, x0.snd.fst) :: List.map (fun x => (x.fst, x.snd.fst)) X =
              (x0 :: X).map (fun x => (x.fst, x.snd.fst)) from rfl, List.find?_map]
            rcases hf : List.find? (fun x => x.fst == c) (x0 :: X) with _ | ⟨c', v, t⟩ <;>
              simp [Function.comp_def, hf]
      case xsDemean =>
        dsimp only
        obtain ⟨d, hd0, hti, -⟩ := opTy_xs (Or.inr (Or.inl rfl)) hWi.2
        obtain ⟨a, rest, rfl⟩ : ∃ a rest, args = a :: rest := by
          cases args with
          | nil => simp at hd0
          | cons a rest => exact ⟨a, rest, rfl⟩
        simp only [List.map_cons, List.getElem?_cons_zero, Option.some.injEq] at hd0
        simp only [List.getElem!_cons_zero]
        have hX : ∀ x ∈ List.filterMap (fun c => if listed[c]! = true then Option.map (fun x => (c, x)) u.tv[a]![c]!
            else none) (List.range listed.size), x.2.2 = .num d := by
          intro x hx
          simp only [List.mem_filterMap, List.mem_range] at hx
          obtain ⟨c, -, hc⟩ := hx
          split at hc
          · cases hv : u.tv[a]![c]! with
            | none => rw [hv] at hc; cases hc
            | some y => rw [hv] at hc; cases hc; rw [(hR.tagged a c y.1 y.2 hv).1, hd0]
          · cases hc
        rw [mapM_const _ _ d fun x hx => by simp [hX x hx]; rfl]
        have hvm : ∀ c : Nat, m.vals[a]![c]! = Option.map Prod.fst (u.tv[a]![c]! : TVal α) := fun c => by
          rw [← hR.vals, eraseTV_get]
        have hXM : List.filterMap (fun c => if listed[c]! = true then Option.map (fun x => (c, x)) m.vals[a]![c]!
            else none) (List.range listed.size) =
            (List.filterMap (fun c => if listed[c]! = true then Option.map (fun x => (c, x)) u.tv[a]![c]!
              else none) (List.range listed.size)).map (fun x => (x.1, x.2.1)) := by
          rw [List.map_filterMap]; congr 1; funext c; rw [hvm]; split <;> simp [Option.map_map, Function.comp_def]
        rw [hXM]
        generalize List.filterMap (fun c => if listed[c]! = true then Option.map (fun x => (c, x)) u.tv[a]![c]!
          else none) (List.range listed.size) = X at hX ⊢
        simp only [bind, Except.bind, pure, Except.pure, throw, throwThe, MonadExceptOf.throw]
        cases X with
        | nil =>
          simp only [List.map_nil, List.all_nil, Bool.not_true, Bool.false_eq_true, ite_false, List.isEmpty_nil,
            Bool.not_true, Bool.and_false, ite_true]
          refine ⟨_, _, rfl, rfl, ?_⟩
          exact URel_setRow N p hR i _ _ (by simp [replicate_none_get]) (by simp)
        | cons x0 X =>
          simp only [List.map_cons, List.headD_cons, List.isEmpty_cons, Bool.false_eq_true, ite_false]
          rw [if_neg (by simp), if_neg (by simp)]
          refine ⟨_, _, rfl, rfl, ?_⟩
          refine URel_setRow N p hR i _ _ ?_ ?_
          · intro k x t hx
            have hm := getElem!_some_mem _ k hx
            simp only [List.toList_toArray, List.mem_map] at hm
            obtain ⟨c, -, hc⟩ := hm
            split at hc
            · cases hc
            · simp at hc; (try obtain ⟨_, -, -, rfl⟩ := hc); (try obtain ⟨-, rfl⟩ := hc); simp [hti]
          · rw [List.map_toArray]
            congr 1
            simp only [List.map_map]
            apply List.map_congr_left
            intro c _
            simp only [Function.comp_def]
            rw [show (x0.fst, x0.snd.fst) :: List.map (fun x => (x.fst, x.snd.fst)) X =
              (x0 :: X).map (fun x => (x.fst, x.snd.fst)) from rfl, List.find?_map]
            rcases hf : List.find? (fun x => x.fst == c) (x0 :: X) with _ | ⟨c', v, t⟩ <;>
              simp [Function.comp_def, hf]
      case xsRank =>
        dsimp only
        obtain ⟨d, hd0, hti, hd1⟩ := opTy_xs (Or.inr (Or.inr rfl)) hWi.2
        have hd1' := hd1 rfl
        obtain ⟨a, rest, rfl⟩ : ∃ a rest, args = a :: rest := by
          cases args with
          | nil => simp at hd0
          | cons a rest => exact ⟨a, rest, rfl⟩
        simp only [List.map_cons, List.getElem?_cons_zero, Option.some.injEq] at hd0
        simp only [List.getElem!_cons_zero]
        have hX : ∀ x ∈ List.filterMap (fun c => if listed[c]! = true then Option.map (fun x => (c, x)) u.tv[a]![c]!
            else none) (List.range listed.size), x.2.2 = .num d := by
          intro x hx
          simp only [List.mem_filterMap, List.mem_range] at hx
          obtain ⟨c, -, hc⟩ := hx
          split at hc
          · cases hv : u.tv[a]![c]! with
            | none => rw [hv] at hc; cases hc
            | some y => rw [hv] at hc; cases hc; rw [(hR.tagged a c y.1 y.2 hv).1, hd0]
          · cases hc
        rw [mapM_const _ _ d fun x hx => by simp [hX x hx]; rfl]
        have hvm : ∀ c : Nat, m.vals[a]![c]! = Option.map Prod.fst (u.tv[a]![c]! : TVal α) := fun c => by
          rw [← hR.vals, eraseTV_get]
        have hXM : List.filterMap (fun c => if listed[c]! = true then Option.map (fun x => (c, x)) m.vals[a]![c]!
            else none) (List.range listed.size) =
            (List.filterMap (fun c => if listed[c]! = true then Option.map (fun x => (c, x)) u.tv[a]![c]!
              else none) (List.range listed.size)).map (fun x => (x.1, x.2.1)) := by
          rw [List.map_filterMap]; congr 1; funext c; rw [hvm]; split <;> simp [Option.map_map, Function.comp_def]
        rw [hXM]
        generalize List.filterMap (fun c => if listed[c]! = true then Option.map (fun x => (c, x)) u.tv[a]![c]!
          else none) (List.range listed.size) = X at hX ⊢
        simp only [bind, Except.bind, pure, Except.pure, throw, throwThe, MonadExceptOf.throw]
        cases X with
        | nil =>
          simp only [List.map_nil, List.all_nil, Bool.not_true, Bool.false_eq_true, ite_false, List.isEmpty_nil,
            Bool.not_true, Bool.and_false, ite_true]
          refine ⟨_, _, rfl, rfl, ?_⟩
          exact URel_setRow N p hR i _ _ (by simp [replicate_none_get]) (by simp)
        | cons x0 X =>
          simp only [List.map_cons, List.headD_cons, List.isEmpty_cons, Bool.false_eq_true, ite_false]
          rw [if_neg (by simp), if_neg (by simp [hd1'])]
          refine ⟨_, _, rfl, rfl, ?_⟩
          refine URel_setRow N p hR i _ _ ?_ ?_
          · intro k x t hx
            have hm := getElem!_some_mem _ k hx
            simp only [List.toList_toArray, List.mem_map] at hm
            obtain ⟨c, -, hc⟩ := hm
            split at hc
            · cases hc
            · simp at hc; (try obtain ⟨_, -, -, rfl⟩ := hc); (try obtain ⟨-, rfl⟩ := hc); simp [hti]
          · rw [List.map_toArray]
            congr 1
            simp only [List.map_map]
            apply List.map_congr_left
            intro c _
            simp only [Function.comp_def]
            rw [show (x0.fst, x0.snd.fst) :: List.map (fun x => (x.fst, x.snd.fst)) X =
              (x0 :: X).map (fun x => (x.fst, x.snd.fst)) from rfl, List.find?_map]
            rcases hf : List.find? (fun x => x.fst == c) (x0 :: X) with _ | ⟨c', v, t⟩ <;>
              simp [Function.comp_def, hf]
      all_goals
        have hev := fun (u : UState α) (hT : Tagged N p u.tv) c =>
          evalU_op N p u.m u.tv i c _ args hn _ hWi.2 hT (by simp)
        refine step_of_loop (forIn_rel _ _ _ (URel N p) ?_ u m hR)
        intro c hc u m hR
        obtain ⟨r, hr, he, ht⟩ := hev u hR.tagged c
        have hev' : MState.eval N p m i c = r.map (·.1) := by
          rw [he]; exact eval_congr N p (m₂ := { u.m with vals := eraseTV u.tv }) hR.vals.symm hR.funding.symm
            hR.bar.symm hR.events.symm hR.hour.symm i c
        have hwm : m.wins[i]![c]! = u.m.wins[i]![c]! := by rw [hR.wins]
        by_cases hl : listed[c]! = true
        · simp only [hl, ite_true, hr, hev', bind, Except.bind, hwm]
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
  · exact { h with hour := rfl }

omit [Inhabited α] in
theorem init_wins (N : NumOps α) (p : Program) (coins i c : Nat) (w : Win α)
    (h : (MState.init N p coins).wins[i]![c]! = some w) :
    ∃ k hh args, p.nodes[i]! = .op (.window k hh) args ∧ w = Win.new N k hh := by
  simp only [MState.init] at h
  by_cases hi : i < p.nodes.size
  · rw [getElem!_pos _ i (by simpa using hi), Array.getElem_map, ← getElem!_pos p.nodes i hi] at h
    split at h
    · rename_i k hh args hn
      by_cases hc : c < coins
      · rw [getElem!_pos _ c (by simpa using hc)] at h; simp at h
        exact ⟨k, hh, args, hn, h.symm⟩
      · rw [getElem!_neg _ c (by simpa using hc)] at h; cases h
    · by_cases hc : c < coins
      · rw [getElem!_pos _ c (by simpa using hc)] at h; simp at h
      · rw [getElem!_neg _ c (by simpa using hc)] at h; cases h
  · rw [getElem!_neg _ i (by simpa using hi)] at h; cases h

omit [Inhabited α] in
theorem nested_none_get {β : Type} (n k i c : Nat) : (Array.replicate n (Array.replicate k (none : Option β)))[i]![c]! = none := by
  by_cases hi : i < n
  · rw [getElem!_pos _ i (by simpa using hi)]; simp only [Array.getElem_replicate]; exact replicate_none_get k c
  · rw [getElem!_neg _ i (by simpa using hi)]; rfl

theorem init_rel (N : NumOps α) (p : Program) (hW : p.WF) (coins : Nat) :
    URel N p (UState.init N p coins) (MState.init N p coins) := by
  refine ⟨?_, rfl, rfl, rfl, rfl, rfl, rfl, rfl, ?_, ?_, ?_, ?_, ?_⟩
  · simp [eraseTV, UState.init, MState.init]
  · intro j k x t hx; simp [UState.init, nested_none_get] at hx
  · intro j k t ht; simp [UState.init, nested_none_get] at ht
  · intro j k w _ hw
    obtain ⟨kd, hh, args, hn, rfl⟩ := init_wins N p coins j k w hw
    have hj : j < p.nodes.size := by
      by_cases hj : j < p.nodes.size
      · exact hj
      · rw [getElem!_neg _ j hj] at hn; cases hn
    have h1 := (opTy_window (by have := hW.2.2.2.2.2 j hj; rw [hn] at this; exact this.2)).2
    cases kd <;> simp [Win.new, Win.Blank] <;> omega
  · intro j k w hw
    obtain ⟨kd, hh, args, hn, -⟩ := init_wins N p coins j k w hw
    exact ⟨kd, hh, args, hn⟩
  · constructor
    · simp [UState.init, MState.init]
    · intro i
      simp only [UState.init, MState.init]
      by_cases hi : i < p.nodes.size
      · rw [getElem!_pos _ i (by simpa using hi), getElem!_pos _ i (by simpa using hi), Array.getElem_map]
        simp only [Array.getElem_replicate, Array.size_replicate]
        split <;> simp
      · rw [getElem!_neg _ i (by simpa using hi), getElem!_neg _ i (by simpa using hi)]; rfl

/-- An instrumented result against an executable one: both succeed related, or both fail with the same
abort; a unit error has no counterpart. -/
def Corr {σ τ : Type} (R : σ → τ → Prop) : Except (Abort ⊕ UnitError) σ → Except Abort τ → Prop
  | .ok a, .ok b => R a b
  | .error (.inl a), .error b => a = b
  | _, _ => False

omit [Inhabited α] in
theorem forIn_corr {β σ τ : Type} (l : List β) (F : β → σ → Except (Abort ⊕ UnitError) (ForInStep σ))
    (G : β → τ → Except Abort (ForInStep τ)) (R : σ → τ → Prop)
    (hF : ∀ a u m, R u m → Corr (fun x y => ∃ x' y', x = .yield x' ∧ y = .yield y' ∧ R x' y') (F a u) (G a m)) :
    ∀ u m, R u m → Corr R (forIn l u F) (forIn l m G) := by
  induction l with
  | nil => intro u m h; exact h
  | cons a l ih =>
    intro u m h
    have hs := hF a u m h
    simp only [List.forIn_cons]
    cases hFu : F a u with
    | error e =>
      cases hGm : G a m with
      | error e' => rw [hFu, hGm] at hs; cases e with
        | inl a' => exact hs
        | inr _ => exact hs.elim
      | ok y => rw [hFu, hGm] at hs; cases e <;> exact hs.elim
    | ok x =>
      cases hGm : G a m with
      | error e' => rw [hFu, hGm] at hs; exact hs.elim
      | ok y =>
        rw [hFu, hGm] at hs
        obtain ⟨x', y', rfl, rfl, hxy⟩ := hs
        exact ih x' y' hxy

theorem URel_machine (N : NumOps α) (p : Program) {u : UState α} {m : MState α} (hR : URel N p u m) :
    u.m = m.withLocal u.m.vals m.wins m.since := by
  have h₁ := hR.wins; have h₂ := hR.since; have h₃ := hR.funding; have h₄ := hR.bar; have h₅ := hR.events
  have h₆ := hR.hour; have h₇ := hR.maxKnown
  generalize u.m = um at *
  cases um; cases m; simp_all [MState.withLocal]

/-- Preflight's first tick is hour 0 of the schedule. -/
theorem start_tickLoop (N : NumOps α) (c : Ctx α) (n : Nat) :
    (c.start N >>= c.tickLoop N c.pol.wStart (List.range' 1 n)) =
      if !c.bound then .error .inputUnavailable else c.tickLoop N c.pol.wStart (List.range' 0 (n + 1)) (c.state0 N) := by
  unfold Ctx.start
  rw [List.range'_succ]
  cases c.bound
  · rfl
  · simp only [Bool.not_true, Bool.false_eq_true, ite_false, Ctx.tickLoop, List.forIn_cons]
    simp only [show ((0 : Nat) : Int) * HOUR = 0 by simp, Int.add_zero, Nat.zero_add, bind_assoc, pure_bind]
    rfl

omit [Inhabited α] in
/-- After a delivery that kept the per-node state, the instrumented state with the delivered machine is still
related to it. -/
theorem URel_deliver (N : NumOps α) (p : Program) {u : UState α} {m : MState α} (hR : URel N p u m) (m' : MState α)
    (hv : m'.vals = m.vals) (hw : m'.wins = m.wins) (hs : m'.since = m.since) :
    URel N p ⟨m'.withLocal u.m.vals m.wins m.since, u.tv, u.wtag⟩ m' := by
  have hwu : u.m.wins = m.wins := hR.wins
  refine ⟨hR.vals.trans hv.symm, hw.symm, hs.symm, rfl, rfl, rfl, rfl, rfl, hR.tagged, hR.tags, ?_, ?_, ?_⟩
  · intro i c w ht hw'; exact hR.blank i c w ht (by rw [hwu]; exact hw')
  · intro i c w hw'; exact hR.winNode i c w (by rw [hwu]; exact hw')
  · simp only [MState.withLocal]; rw [← hwu]; exact hR.shape

omit [Inhabited α] in
theorem Corr_map {σ τ σ' τ' : Type} {R : σ → τ → Prop} {S : σ' → τ' → Prop} {x : Except (Abort ⊕ UnitError) σ}
    {y : Except Abort τ} (f : σ → σ') (g : τ → τ') (h : Corr R x y) (hR : ∀ a b, R a b → S (f a) (g b)) :
    Corr S (x >>= fun a => pure (f a)) (y.map g) := by
  cases x with
  | error e => cases y with
    | error e' => cases e <;> exact h
    | ok b => cases e <;> exact h.elim
  | ok a => cases y with
    | error e' => exact h.elim
    | ok b => exact hR a b h

/-- The instrumented schedule against the executable one. -/
theorem umachine_corr (N : NumOps α) (c : Ctx α) (hW : c.p.WF) (n : Nat) :
    Corr (fun u ms => URel N c.p u ms) (c.umachineAfter N n) (c.machineAfter N n) := by
  rw [Ctx.machineAfter_eq, start_tickLoop]
  unfold Ctx.umachineAfter Ctx.tickLoop
  have hz : [0:n + 1].size = n + 1 := by simp [Std.Legacy.Range.size]
  simp only [Std.Legacy.Range.forIn_eq_forIn_range', hz]
  cases c.bound
  · rfl
  · simp only [Bool.not_true, Bool.false_eq_true, ite_false]
    refine Corr_map (·.1) (·.machine) (forIn_corr _ _ _
      (fun (us : UState α × SState α) (s' : SState α) => URel N c.p us.1 s'.machine ∧ { us.2 with machine := s'.machine } = s')
      ?_ (UState.init N c.p c.coins, c.state0 N) (c.state0 N) ⟨init_rel N c.p hW c.coins, rfl⟩) (fun a b h => h.1)
    intro k us s' ⟨hR, hs⟩
    have e : ∀ X, ({ us.2 with machine := X } : SState α) = { s' with machine := X } := by intro X; rw [← hs]
    rw [e us.1.m, URel_machine N c.p hR, deliver_local]
    cases hd : c.deliver s' (c.pol.wStart + ↑k * HOUR + c.pol.delta) with
    | error a => rfl
    | ok r =>
      obtain ⟨hv, hw, hsn⟩ := deliver_keeps_local c s' r _ hd
      obtain ⟨u', hu', hR'⟩ := tick_rel N c.p hW (c.mask (c.pol.wStart + ↑k * HOUR)) (c.pol.wStart + ↑k * HOUR)
        _ _ (URel_deliver N c.p hR r.machine hv hw hsn)
      simp only [Except.map, Except.mapError, bind, Except.bind, pure, Except.pure]
      rw [hu']
      exact ⟨_, _, rfl, rfl, hR', rfl⟩

end Ref
