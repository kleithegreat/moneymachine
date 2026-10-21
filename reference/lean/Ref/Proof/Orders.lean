import Ref.Proof.Fills

/-! Exactly once: a ledger of decisions, pending orders and their resolutions in the trace. -/

namespace Ref

variable {α : Type} [Inhabited α]

/-- A decision's key: its time and coin. -/
def dkey : Event α → Option (Int × Nat)
  | .decision t c _ _ => some (t, c)
  | _ => none

/-- The key of the decision an ordinary fill or an Unfilled record resolves. -/
def rkey (δ : Int) : Event α → Option (Int × Nat)
  | .fill f => if f.why = .fill then some (f.decided, f.coin) else none
  | .unfilled t c _ => some (t - BAR + δ, c)
  | _ => none

/-- L4_orders' resolution of the decision (t, c, q). -/
def Resolves (δ t : Int) (c : Nat) (q : α) (e : Event α) : Prop :=
  (∃ f : Fill α, e = Event.fill f ∧ f.why = .fill ∧ f.coin = c ∧ f.decided = t ∧ f.qty = q) ∨
    e = Event.unfilled (t - δ + BAR) c q

omit [Inhabited α] in
theorem rkey_of_resolves {δ t : Int} {c : Nat} {q : α} {e : Event α} (h : Resolves δ t c q e) : rkey δ e = some (t, c) := by
  rcases h with ⟨f, rfl, hw, rfl, rfl, -⟩ | rfl
  · simp [rkey, hw]
  · simp only [rkey, Option.some.injEq, Prod.mk.injEq, and_true]; omega

/-- Two entries of a list with the same key, among keys without repeats, are one entry. -/
theorem key_index {β κ : Type} {g : β → Option κ} {T : List β} (h : (T.filterMap g).Nodup) {i j : Nat} {a b : β}
    {k : κ} (hi : T[i]? = some a) (hj : T[j]? = some b) (ha : g a = some k) (hb : g b = some k) : i = j := by
  induction T generalizing i j with
  | nil => simp at hi
  | cons x T ih =>
    have tail : (T.filterMap g).Nodup := by
      rw [List.filterMap_cons] at h; split at h
      · exact h
      · exact (List.nodup_cons.mp h).2
    cases i <;> cases j
    · rfl
    · simp only [List.getElem?_cons_zero, Option.some.injEq, List.getElem?_cons_succ] at hi hj
      subst hi
      rw [List.filterMap_cons, ha] at h
      exact absurd (List.mem_filterMap.mpr ⟨b, List.mem_of_getElem? hj, hb⟩) (List.nodup_cons.mp h).1
    · simp only [List.getElem?_cons_zero, Option.some.injEq, List.getElem?_cons_succ] at hi hj
      subst hj
      rw [List.filterMap_cons, hb] at h
      exact absurd (List.mem_filterMap.mpr ⟨a, List.mem_of_getElem? hi, ha⟩) (List.nodup_cons.mp h).1
    · simp only [List.getElem?_cons_succ] at hi hj
      exact congrArg (· + 1) (ih tail hi hj)

/-- A later resolution of the decision at i. -/
def Resolved (δ : Int) (T : List (Event α)) (i : Nat) (t : Int) (c : Nat) (q : α) : Prop :=
  ∃ j, i < j ∧ ∃ e, T[j]? = some e ∧ Resolves δ t c q e

/-- The trace T with pending orders P, whose decisions are no later than d: decision and resolution keys are
unique, each pending order has its decision and no resolution, each decision is pending, resolved later or
past the run's fills, each resolution has an earlier decision, and an Unfilled record has no traded bar or
falls at a time in U (an insolvent step). -/
structure Ledger (m : Market α) (δ stop : Int) (U : Int → Prop) (T : List (Event α)) (P : List (Order α)) (d : Int) : Prop where
  dnodup : (T.filterMap dkey).Nodup
  rnodup : (T.filterMap (rkey δ)).Nodup
  dmax : ∀ e ∈ T, ∀ t c, dkey e = some (t, c) → t ≤ d
  pend : ∀ o ∈ P, ∃ (i : Nat) (w : α), T[i]? = some (Event.decision o.decided o.coin w o.qty)
  fresh : ∀ o ∈ P, ∀ e ∈ T, rkey δ e ≠ some (o.decided, o.coin)
  pnodup : (P.map fun o => (o.decided, o.coin)).Nodup
  fate : ∀ (i : Nat) (t : Int) (c : Nat) (w q : α), T[i]? = some (Event.decision t c w q) →
    (∃ o ∈ P, o.decided = t ∧ o.coin = c ∧ o.qty = q) ∨ Resolved δ T i t c q ∨ stop < t - δ + 3 * BAR
  cause : ∀ (j : Nat) (e : Event α) (t : Int) (c : Nat), T[j]? = some e → rkey δ e = some (t, c) →
    ∃ (i : Nat) (w q : α), i < j ∧ T[i]? = some (Event.decision t c w q) ∧ Resolves δ t c q e
  unfilled : ∀ t c q, Event.unfilled t c q ∈ T → (∀ bar, barAt m c t = some bar → bar.trades < 1) ∨ U t

theorem get_lift {β : Type} {T : List β} {j : Nat} {x : β} (U : List β) (h : T[j]? = some x) : (T ++ U)[j]? = some x := by
  rw [List.getElem?_append_left (List.getElem?_eq_some_iff.mp h).1, h]

theorem get_concat {β : Type} {T : List β} {e x : β} {i : Nat} (h : (T ++ [e])[i]? = some x) :
    T[i]? = some x ∨ (i = T.length ∧ x = e) := by
  rcases Nat.lt_or_ge i T.length with hi | hi
  · rw [List.getElem?_append_left hi] at h; exact Or.inl h
  · rw [List.getElem?_append_right hi] at h
    obtain ⟨k, rfl⟩ := Nat.exists_eq_add_of_le hi
    cases k with
    | zero => simp at h; exact Or.inr ⟨rfl, h.symm⟩
    | succ k => simp at h

theorem get_last {β : Type} (T : List β) (e : β) : (T ++ [e])[T.length]? = some e := by simp

omit [Inhabited α] in
theorem Resolved.lift {δ : Int} {T : List (Event α)} {i : Nat} {t : Int} {c : Nat} {q : α} (U : List (Event α))
    (h : Resolved δ T i t c q) : Resolved δ (T ++ U) i t c q :=
  let ⟨j, hij, e, he, hr⟩ := h
  ⟨j, hij, e, get_lift U he, hr⟩

namespace Ledger
variable {m : Market α} {δ stop : Int} {U : Int → Prop} {T : List (Event α)} {P : List (Order α)} {d : Int}

theorem weaken {U' : Int → Prop} (h : Ledger m δ stop U T P d) (hU : ∀ t, U t → U' t) : Ledger m δ stop U' T P d :=
  { h with unfilled := fun t c q hu => (h.unfilled t c q hu).imp_right (hU t) }

theorem mono {d' : Int} (h : Ledger m δ stop U T P d) (hd : d ≤ d') : Ledger m δ stop U T P d' :=
  { h with dmax := fun e he t c hk => Int.le_trans (h.dmax e he t c hk) hd }

/-- An event that is neither a decision nor a resolution keeps the ledger. -/
theorem push {e : Event α} (h : Ledger m δ stop U T P d) (hd : dkey e = none) (hr : rkey δ e = none) :
    Ledger m δ stop U (T ++ [e]) P d where
  dnodup := by simpa [List.filterMap_append, hd] using h.dnodup
  rnodup := by simpa [List.filterMap_append, hr] using h.rnodup
  dmax e' he' t c hk := by
    rcases List.mem_append.mp he' with he' | he'
    · exact h.dmax e' he' t c hk
    · rw [List.mem_singleton.mp he', hd] at hk; cases hk
  pend o ho := let ⟨i, w, hi⟩ := h.pend o ho; ⟨i, w, get_lift _ hi⟩
  fresh o ho e' he' := by
    rcases List.mem_append.mp he' with he' | he'
    · exact h.fresh o ho e' he'
    · rw [List.mem_singleton.mp he', hr]; simp
  pnodup := h.pnodup
  fate i t c w q hi := by
    rcases get_concat hi with hi | ⟨-, hx⟩
    · exact (h.fate i t c w q hi).imp_right (Or.imp_left (Resolved.lift _))
    · rw [← hx] at hd; cases hd
  cause j e' t c hj hk := by
    rcases get_concat hj with hj | ⟨-, rfl⟩
    · obtain ⟨i, w, q, hij, hi, hres⟩ := h.cause j e' t c hj hk
      exact ⟨i, w, q, hij, get_lift _ hi, hres⟩
    · rw [hr] at hk; cases hk
  unfilled t c q hu := by
    rcases List.mem_append.mp hu with hu | hu
    · exact h.unfilled t c q hu
    · rw [← List.mem_singleton.mp hu] at hr; cases hr

/-- The first pending order's resolution. -/
theorem resolve {o : Order α} {e : Event α} (h : Ledger m δ stop U T (o :: P) d) (hd : dkey e = none)
    (hr : rkey δ e = some (o.decided, o.coin)) (hres : Resolves δ o.decided o.coin o.qty e)
    (hu : ∀ t c q, e = .unfilled t c q → (∀ bar, barAt m c t = some bar → bar.trades < 1) ∨ U t) :
    Ledger m δ stop U (T ++ [e]) P d where
  dnodup := by simpa [List.filterMap_append, hd] using h.dnodup
  rnodup := by
    rw [List.filterMap_append, List.nodup_append]
    refine ⟨h.rnodup, by simp [hr], fun a ha b hb => ?_⟩
    simp only [List.filterMap_cons, hr, List.filterMap_nil, List.mem_singleton] at hb
    obtain ⟨e', he', hk⟩ := List.mem_filterMap.mp ha
    rintro rfl
    exact h.fresh o (by simp) e' he' (hk.trans (congrArg some hb))
  dmax e' he' t c hk := by
    rcases List.mem_append.mp he' with he' | he'
    · exact h.dmax e' he' t c hk
    · rw [List.mem_singleton.mp he', hd] at hk; cases hk
  pend o' ho' := let ⟨i, w, hi⟩ := h.pend o' (by simp [ho']); ⟨i, w, get_lift _ hi⟩
  fresh o' ho' e' he' := by
    rcases List.mem_append.mp he' with he' | he'
    · exact h.fresh o' (by simp [ho']) e' he'
    · rw [List.mem_singleton.mp he', hr]
      intro hk
      have := h.pnodup
      simp only [List.map_cons, List.nodup_cons, List.mem_map] at this
      exact this.1 ⟨o', ho', by simpa using hk.symm⟩
  pnodup := (List.nodup_cons.mp h.pnodup).2
  fate i t c w q hi := by
    rcases get_concat hi with hi | ⟨-, hx⟩
    · rcases h.fate i t c w q hi with ⟨o', ho', ht, hc, hq⟩ | hres' | hstop
      · rcases List.mem_cons.mp ho' with rfl | ho'
        · refine Or.inr (Or.inl ⟨T.length, (List.getElem?_eq_some_iff.mp hi).1, e, get_last T e, ?_⟩)
          rw [← ht, ← hc, ← hq]; exact hres
        · exact Or.inl ⟨o', ho', ht, hc, hq⟩
      · exact Or.inr (Or.inl (hres'.lift _))
      · exact Or.inr (Or.inr hstop)
    · rw [← hx] at hd; cases hd
  cause j e' t c hj hk := by
    rcases get_concat hj with hj | ⟨rfl, rfl⟩
    · obtain ⟨i, w, q, hij, hi, hres'⟩ := h.cause j e' t c hj hk
      exact ⟨i, w, q, hij, get_lift _ hi, hres'⟩
    · rw [hr] at hk
      cases hk
      obtain ⟨i, w, hi⟩ := h.pend o (by simp)
      exact ⟨i, w, o.qty, (List.getElem?_eq_some_iff.mp hi).1, get_lift _ hi, hres⟩
  unfilled t c q hmem := by
    rcases List.mem_append.mp hmem with hmem | hmem
    · exact h.unfilled t c q hmem
    · exact hu t c q (List.mem_singleton.mp hmem).symm

omit [Inhabited α] in
/-- Orders whose fills would come after the run's last fills leave unresolved. -/
theorem drop (h : Ledger m δ stop U T P d) (hP : ∀ o ∈ P, stop < o.decided - δ + 3 * BAR) : Ledger m δ stop U T [] d where
  dnodup := h.dnodup
  rnodup := h.rnodup
  dmax := h.dmax
  pend := by simp
  fresh := by simp
  pnodup := by simp
  fate i t c w q hi := by
    rcases h.fate i t c w q hi with ⟨o, ho, rfl, -, -⟩ | hres | hstop
    · exact Or.inr (Or.inr (hP o ho))
    · exact Or.inr (Or.inl hres)
    · exact Or.inr (Or.inr hstop)
  cause := h.cause
  unfilled := h.unfilled

/-- A new decision, no earlier than every decision before it and with a fresh key, and its pending order. -/
theorem decide {t : Int} {c : Nat} {w q : α} {o : Order α} (h : Ledger m δ stop U T P d) (hdt : d ≤ t)
    (ho : o.decided = t ∧ o.coin = c ∧ o.qty = q) (hnew : ∀ e ∈ T, dkey e ≠ some (t, c)) :
    Ledger m δ stop U (T ++ [.decision t c w q]) (P ++ [o]) t where
  dnodup := by
    rw [List.filterMap_append, List.nodup_append]
    refine ⟨h.dnodup, by simp [dkey], fun a ha b hb => ?_⟩
    simp only [List.filterMap_cons, dkey, List.filterMap_nil, List.mem_singleton] at hb
    obtain ⟨e', he', hk⟩ := List.mem_filterMap.mp ha
    rintro rfl
    exact hnew e' he' (hk.trans (congrArg some hb))
  rnodup := by simpa [List.filterMap_append, List.filterMap_cons, rkey] using h.rnodup
  dmax e' he' t' c' hk := by
    rcases List.mem_append.mp he' with he' | he'
    · exact Int.le_trans (h.dmax e' he' t' c' hk) hdt
    · rw [List.mem_singleton.mp he'] at hk; cases hk; exact Int.le_refl _
  pend o' ho' := by
    rcases List.mem_append.mp ho' with ho' | ho'
    · let ⟨i, w', hi⟩ := h.pend o' ho'; exact ⟨i, w', get_lift _ hi⟩
    · rw [List.mem_singleton.mp ho', ho.1, ho.2.1, ho.2.2]; exact ⟨T.length, w, get_last T _⟩
  fresh o' ho' e' he' := by
    rcases List.mem_append.mp he' with he' | he'
    · rcases List.mem_append.mp ho' with ho' | ho'
      · exact h.fresh o' ho' e' he'
      · rw [List.mem_singleton.mp ho', ho.1, ho.2.1]
        intro hk
        obtain ⟨j, hj⟩ := List.mem_iff_getElem?.mp he'
        obtain ⟨i, w', q', -, hi, -⟩ := h.cause j e' t c hj hk
        exact hnew _ (List.mem_of_getElem? hi) rfl
    · rw [List.mem_singleton.mp he']; simp [rkey]
  pnodup := by
    rw [List.map_append, List.nodup_append]
    refine ⟨h.pnodup, by simp, fun a ha b hb => ?_⟩
    simp only [List.map_cons, List.map_nil, List.mem_singleton, ho.1, ho.2.1] at hb
    obtain ⟨o', ho', rfl⟩ := List.mem_map.mp ha
    rintro hk
    obtain ⟨i, w', hi⟩ := h.pend o' ho'
    exact hnew _ (List.mem_of_getElem? hi) (by simp [dkey, hk ▸ hb])
  fate i t' c' w' q' hi := by
    rcases get_concat hi with hi | ⟨-, hx⟩
    · rcases h.fate i t' c' w' q' hi with ⟨o', ho', hrest⟩ | hres | hstop
      · exact Or.inl ⟨o', List.mem_append_left _ ho', hrest⟩
      · exact Or.inr (Or.inl (hres.lift _))
      · exact Or.inr (Or.inr hstop)
    · cases hx; exact Or.inl ⟨o, by simp, ho⟩
  cause j e' t' c' hj hk := by
    rcases get_concat hj with hj | ⟨-, rfl⟩
    · obtain ⟨i, w', q', hij, hi, hres⟩ := h.cause j e' t' c' hj hk
      exact ⟨i, w', q', hij, get_lift _ hi, hres⟩
    · simp [rkey] at hk
  unfilled t' c' q' hmem := by
    rcases List.mem_append.mp hmem with hmem | hmem
    · exact h.unfilled t' c' q' hmem
    · simp at hmem

theorem nil : Ledger m δ stop U [] [] d where
  dnodup := by simp
  rnodup := by simp
  dmax := by simp
  pend := by simp
  fresh := by simp
  pnodup := by simp
  fate := by simp
  cause := by simp
  unfilled := by simp

theorem push' {t : Array (Event α)} {e : Event α} (h : Ledger m δ stop U t.toList P d) (hd : dkey e = none)
    (hr : rkey δ e = none) : Ledger m δ stop U (t.push e).toList P d := by
  rw [Array.toList_push]; exact h.push hd hr

end Ledger

theorem barAt_none (m : Market α) (coins : Nat) (hA : m.Admissible) {c : Nat} {t : Int}
    (h : (m.index coins).barAt[(c, t)]? = none) : barAt m c t = none := by
  unfold barAt
  rw [List.find?_eq_none]
  intro bar hb hp
  obtain ⟨i, hi, rfl⟩ := List.getElem_of_mem hb
  simp only [Bool.and_eq_true, beq_iff_eq] at hp
  have := barAt_complete m coins hA (i := i) (by simpa using hi)
  simp only [Array.getElem_toList] at hp
  rw [hp.1, hp.2, h] at this
  cases this

/-- Due times t = w0 + (k + 1)·BAR whose step k ended with equity that is not positive. -/
def Insolvent (N : NumOps α) (w0 : Int) (E : Array α) (t : Int) : Prop :=
  ∃ (k : Nat) (e : α), E[k]? = some e ∧ t = w0 + ((k : Int) + 1) * BAR ∧ N.lt N.zero e = false

/-- Due times whose step ended with positive equity. -/
def Solvent (N : NumOps α) (w0 : Int) (E : Array α) (t : Int) : Prop :=
  ∃ (k : Nat) (e : α), E[k]? = some e ∧ t = w0 + ((k : Int) + 1) * BAR ∧ N.lt N.zero e = true

theorem get_push {E : Array α} {k : Nat} {e : α} (x : α) (h : E[k]? = some e) : (E.push x)[k]? = some e := by
  rw [Array.getElem?_push, if_neg (Nat.ne_of_lt (Array.getElem?_eq_some_iff.mp h).1)]; exact h

theorem Insolvent.push {N : NumOps α} {w0 : Int} {E : Array α} {t : Int} (x : α) (h : Insolvent N w0 E t) :
    Insolvent N w0 (E.push x) t :=
  let ⟨k, e, hk, ht, he⟩ := h; ⟨k, e, get_push x hk, ht, he⟩

theorem Solvent.push {N : NumOps α} {w0 : Int} {E : Array α} {t : Int} (x : α) (h : Solvent N w0 E t) :
    Solvent N w0 (E.push x) t :=
  let ⟨k, e, hk, ht, he⟩ := h; ⟨k, e, get_push x hk, ht, he⟩

/-- The ledger after j steps: the state's pending orders, decisions no later than step j's, Unfilled records
at insolvent steps, ordinary fills at solvent ones, and one equity per step. -/
def LedgerAt (N : NumOps α) (m : Market α) (pol : Policy) (stop : Int) (j : Nat) (s : SState α) : Prop :=
  Ledger m pol.delta stop (Insolvent N pol.wStart s.equity) s.trace.toList (s.orders.map (·.2))
      (pol.wStart + ↑j * BAR + pol.delta) ∧
    (∀ f, Event.fill f ∈ s.trace.toList → f.why = .fill → Solvent N pol.wStart s.equity f.filled) ∧
    s.equity.size = j

theorem execute_equity (N : NumOps α) (c : Ctx α) (s r : SState α) (f : Fill α) (h : c.execute N s f = .ok r) :
    r.equity = s.equity := by
  unfold Ctx.execute at h
  cases hc : checkFill N f c.m c.ix c.v with
  | error e => rw [hc] at h; cases h
  | ok u => rw [hc] at h; cases h; rfl

/-- Fills that are not ordinary, or pushes of other events, keep the solvency of ordinary fills. -/
theorem solvent_push {N : NumOps α} {w0 : Int} {E : Array α} {t : Array (Event α)} {e : Event α}
    (h : ∀ f, Event.fill f ∈ t.toList → f.why = .fill → Solvent N w0 E f.filled)
    (he : ∀ f, e = Event.fill f → f.why ≠ .fill) :
    ∀ f, Event.fill f ∈ (t.push e).toList → f.why = .fill → Solvent N w0 E f.filled := fun f hf hw => by
  rcases fill_mem_push hf with hf | hf
  · exact h f hf hw
  · exact absurd hw (he f hf)

theorem step_ledger (N : NumOps α) (p : Program) (m : Market α) (hA : m.Admissible) (v : Venue α) (pol : Policy)
    (stop : Int) (j : Nat) (s : SState α) (h4 : Inv4 N p m v pol stop j s) (h : LedgerAt N m pol stop j s) :
    Except.Holds ((Ctx.make p m v pol stop).step N s (pol.wStart + ↑j * BAR)) (LedgerAt N m pol stop (j + 1)) := by
  have hBAR : (0 : Int) < BAR := by unfold BAR HOUR; omega
  unfold Ctx.step
  simp only [Std.Legacy.Range.forIn_eq_forIn_range']
  let Q : SState α → Prop := fun s' => LedgerAt N m pol stop j s' ∧ s'.orders = s.orders ∧ s'.equity = s.equity
  have Q_push : ∀ s' (e : Event α), dkey e = none → rkey pol.delta e = none → (∀ f, e = .fill f → f.why ≠ .fill) →
      Q s' → Q { s' with trace := s'.trace.push e } := fun s' e hd hr hf hQ =>
    ⟨⟨hQ.1.1.push' hd hr, solvent_push hQ.1.2.1 hf, hQ.1.2.2⟩, hQ.2⟩
  have Q_close : ∀ s' r coin (q ref : α) (why : Why) t src, why ≠ .fill → Q s' →
      (Ctx.make p m v pol stop).execute N s' ((Ctx.make p m v pol stop).closeout N coin q ref why t src) = .ok r →
      Q r := by
    intro s' r coin q ref why t src hwhy hQ hr
    obtain ⟨-, htr, ho, -⟩ := execute_spec N _ s' r _ hr
    have he := execute_equity N _ s' r _ hr
    refine ⟨?_, ho.trans hQ.2.1, he.trans hQ.2.2⟩
    unfold LedgerAt; rw [htr, ho, he]
    exact ⟨hQ.1.1.push' rfl (by simp [rkey, Ctx.closeout, hwhy]),
      solvent_push hQ.1.2.1 fun f hf => by cases hf; exact hwhy, hQ.1.2.2⟩
  refine Except.Holds.bind (R := Q) (Except.Holds.forIn_list _ _ _ _ ⟨h, rfl, rfl⟩ fun k _ s₀ hQ₀ => ?_)
    fun s₁ hQ₁ => ?_
  · refine Except.Holds.bind (Except.Holds.forIn_list _ _ _ Q hQ₀ fun x _ s' hQ => ?_) fun s'' h'' =>
      Except.Holds.pure _ h''
    split
    · exact Except.Holds.pure _ (Q_push _ _ rfl rfl (fun f hf => by cases hf) hQ)
    · exact Except.Holds.pure _ hQ
  rw [marks_loop]
  refine Except.Holds.bind (Except.Holds.ok _ rfl) fun s₂ hs₂ => ?_
  subst hs₂
  refine Except.Holds.join (R := Q) (fun _ => Except.Holds.forIn_list _ _ _ Q hQ₁ fun x hx s' hQ => ?_) (fun _ => hQ₁)
    fun s₃ hQ₃ => ?_
  · exact Except.Holds.bind (R := Q) (fun r hr => Q_close _ _ _ _ _ _ _ _ (by decide) hQ hr) fun r hr =>
      Except.Holds.pure _ hr
  refine Except.Holds.bind (R := Q) (Except.Holds.forIn_list _ _ _ Q hQ₃ fun x hx s' hQ => ?_) fun s₄' hQ₄' => ?_
  · refine Except.Holds.ite ?_ (Except.Holds.pure _ hQ)
    exact Except.Holds.bind (R := Q) (fun r hr => Q_close _ _ _ _ _ _ _ _ (by decide) hQ hr) fun r hr =>
      Except.Holds.pure _ hr
  refine Except.Holds.bind (R := Q) ?_ fun s₄ hQ₄ => ?_
  · unfold Ctx.bankrupt
    refine Except.Holds.ite (Except.Holds.pure _ hQ₄') ?_
    refine Except.Holds.bind (R := Q) (Except.Holds.forIn_list _ _ _ Q hQ₄' fun x _ s' hQ => ?_)
      fun s' hQ' => Except.Holds.pure _ hQ'
    exact Except.Holds.bind (R := Q) (fun r hr => Q_close _ _ _ _ _ _ _ _ (by decide) hQ hr) fun r hr =>
      Except.Holds.pure _ hr
  refine Except.Holds.ite holds_throw_bind ?_
  refine Except.Holds.ite holds_throw_bind ?_
  have hsize : s₄.equity.size = j := hQ₄.1.2.2
  let E₅ := s₄.equity.push (Book.equity N s₄.book s₄.marks)
  have hdue : pol.wStart + ↑j * BAR + BAR = pol.wStart + ((j : Int) + 1) * BAR := by rw [Int.add_mul, Int.one_mul]; omega
  have hlast : E₅[j]? = some (Book.equity N s₄.book s₄.marks) := by simp [E₅, ← hsize]
  let I : List (Order α) → SState α → Prop := fun rest s' =>
    Ledger m pol.delta stop (Insolvent N pol.wStart E₅) s'.trace.toList rest (pol.wStart + ↑j * BAR + pol.delta) ∧
      s'.orders = [] ∧ (∀ o ∈ rest, o.decided = pol.wStart + ↑j * BAR + pol.delta) ∧
      (∀ f, Event.fill f ∈ s'.trace.toList → f.why = .fill → Solvent N pol.wStart E₅ f.filled) ∧ s'.equity = E₅
  have hI₅ : ∀ (s' : SState α) (e : Event α), dkey e = none → rkey pol.delta e = none → (∀ f, e ≠ .fill f) →
      s'.trace = s₄.trace.push e → s'.orders = s₄.orders.filter (fun x => x.fst != pol.wStart + ↑j * BAR + BAR) →
      s'.equity = E₅ → I ((s₄.orders.filter fun x => x.fst == pol.wStart + ↑j * BAR + BAR).map (·.2)) s' := by
    intro s' e hd hr hf htr ho he
    have hdue' : s₄.orders.filter (fun x => x.fst == pol.wStart + ↑j * BAR + BAR) = s₄.orders :=
      List.filter_eq_self.mpr fun x hx => by simp [(h4.orders x (hQ₄.2.1 ▸ hx)).1]
    refine ⟨?_, ?_, fun o ho => ?_, ?_, he⟩
    · rw [htr, hdue']; exact (hQ₄.1.1.weaken fun t => Insolvent.push _).push' hd hr
    · rw [ho, List.filter_eq_nil_iff]
      intro x hx; simp [(h4.orders x (hQ₄.2.1 ▸ hx)).1]
    · rw [hdue'] at ho
      obtain ⟨x, hx, rfl⟩ := List.mem_map.mp ho
      exact (h4.orders x (hQ₄.2.1 ▸ hx)).2.1
    · rw [htr]
      exact solvent_push (fun f hf hw => (hQ₄.1.2.1 f hf hw).push _) fun f hfe => absurd hfe (hf f)
  have I_unfilled : ∀ s' (o : Order α) rest, I (o :: rest) s' →
      ((∀ bar, barAt m o.coin (pol.wStart + ↑j * BAR + BAR) = some bar → bar.trades < 1) ∨
        Insolvent N pol.wStart E₅ (pol.wStart + ↑j * BAR + BAR)) →
      I rest { s' with trace := s'.trace.push (.unfilled (pol.wStart + ↑j * BAR + BAR) o.coin o.qty) } := by
    intro s' o rest hI hbar
    have hd := hI.2.2.1 o (List.mem_cons_self ..)
    refine ⟨?_, hI.2.1, fun o' ho' => hI.2.2.1 o' (List.mem_cons_of_mem _ ho'),
      solvent_push hI.2.2.2.1 (fun f hf => by cases hf), hI.2.2.2.2⟩
    rw [Array.toList_push]
    refine hI.1.resolve rfl (by simp only [rkey, hd]; congr 2; omega) (Or.inr (by rw [hd]; congr 1; omega))
      fun t c q he => ?_
    cases he; exact hbar
  refine Except.Holds.join (R := I []) (fun _ => Except.Holds.forIn_suffix _ _ _ I
    (hI₅ _ _ rfl rfl (fun f h => by cases h) rfl rfl rfl) fun o rest s' hI => ?_) (fun hstop => ?_) fun s₆ hI₆ => ?_
  · split
    · rename_i i hbi
      obtain ⟨hi, hspec⟩ := barAt_spec m _ hA hbi
      refine Except.Holds.ite_cond (fun htr => ?_) fun htr => Except.Holds.pure _ ⟨_, rfl, I_unfilled _ _ _ hI ?_⟩
      · refine Except.Holds.bind (fun r hr => ?_) fun r hr => Except.Holds.pure _ ⟨r, rfl, hr⟩
        obtain ⟨-, htr', ho', -⟩ := execute_spec N _ s' r _ hr
        have he := execute_equity N _ s' r _ hr
        have hpos := (Bool.and_eq_true_iff.mp htr).2
        refine ⟨?_, ho'.trans hI.2.1, fun o' ho'' => hI.2.2.1 o' (List.mem_cons_of_mem _ ho''), fun f hf hw => ?_,
          he.trans hI.2.2.2.2⟩
        · rw [htr', Array.toList_push]
          exact hI.1.resolve rfl (by simp [rkey]) (Or.inl ⟨_, rfl, rfl, rfl, rfl, rfl⟩) fun _ _ _ he => by cases he
        · rw [htr'] at hf
          rcases fill_mem_push hf with hf | hf
          · exact hI.2.2.2.1 f hf hw
          · cases hf; exact ⟨j, _, hlast, hdue, hpos⟩
      · by_cases ht : m.bars[i]!.trades ≥ 1
        · refine Or.inr ⟨j, _, hlast, hdue, ?_⟩
          simpa [Ctx.make, ht] using htr
        · refine Or.inl fun bar hbar => ?_
          rw [hspec] at hbar; cases hbar
          rw [getElem!_pos m.bars i hi] at ht; omega
    · exact Except.Holds.pure _ ⟨_, rfl, I_unfilled _ _ _ hI (Or.inl fun bar hbar => by
        rw [barAt_none m _ hA (by assumption)] at hbar; cases hbar)⟩
  · have hstop : ¬(pol.wStart + ↑j * BAR + 3 * BAR ≤ stop) := hstop
    have I_drop : ∀ l s', I l s' → I [] s' := fun l s' ⟨hL, ho, hd, hf, he⟩ =>
      ⟨hL.drop fun o hmem => by rw [hd o hmem]; omega, ho, by simp, hf, he⟩
    exact I_drop _ _ (hI₅ _ _ rfl rfl (fun f h => by cases h) rfl rfl rfl)
  refine tickLoop_bind_graft N _ (pol.wStart + (j : Int) * BAR) (List.range' 1 4) s₆ s₆ _ rfl fun r _ => ?_
  let W : List Nat → SState α × List (Nat × α) → Prop := fun rest st =>
    (Ledger m pol.delta stop (Insolvent N pol.wStart E₅) st.1.trace.toList [] (pol.wStart + ↑j * BAR + pol.delta) ∧
      st.1.orders = [] ∧ (∀ f, Event.fill f ∈ st.1.trace.toList → f.why = .fill → Solvent N pol.wStart E₅ f.filled) ∧
      st.1.equity = E₅) ∧
      rest.Nodup ∧ (st.2.map (·.1)).Nodup ∧ ∀ x ∈ st.2, x.1 ∉ rest
  have W_skip : ∀ a rest st, W (a :: rest) st → W rest st := fun a rest st hW =>
    ⟨hW.1, (List.nodup_cons.mp hW.2.1).2, hW.2.2.1, fun x hx hr => hW.2.2.2 x hx (List.mem_cons_of_mem _ hr)⟩
  have W_hold : ∀ l (st : SState α × List (Nat × α)) t c why, W l st →
      W l ({ st.1 with trace := st.1.trace.push (.hold t c why) }, st.2) := fun l st t c why hW =>
    ⟨⟨hW.1.1.push' rfl rfl, hW.1.2.1, solvent_push hW.1.2.2.1 (fun f h => by cases h), hW.1.2.2.2⟩, hW.2⟩
  have W_add : ∀ a rest (st : SState α × List (Nat × α)) w, W (a :: rest) st → W rest (st.1, st.2 ++ [(a, w)]) := by
    intro a rest st w hW
    refine ⟨hW.1, (List.nodup_cons.mp hW.2.1).2, ?_, fun x hx hr => ?_⟩
    · rw [List.map_append, List.nodup_append]
      exact ⟨hW.2.2.1, by simp, fun x hx y hy => by
        simp only [List.map_cons, List.map_nil, List.mem_singleton] at hy
        obtain ⟨z, hz, rfl⟩ := List.mem_map.mp hx
        rintro rfl; exact hW.2.2.2 z hz (hy ▸ List.mem_cons_self ..)⟩
    · rcases List.mem_append.mp hx with hx | hx
      · exact hW.2.2.2 x hx (List.mem_cons_of_mem _ hr)
      · rw [List.mem_singleton.mp hx] at hr; exact (List.nodup_cons.mp hW.2.1).1 hr
  refine Except.Holds.bind (R := W []) (Except.Holds.forIn_suffix _ _ _ W ⟨⟨hI₆.1, hI₆.2.1, hI₆.2.2.2.1, hI₆.2.2.2.2⟩,
    List.nodup_range' .., by simp, by simp⟩ fun c₀ rest st hW => ?_) fun st hW => ?_
  · refine Except.Holds.ite (Except.Holds.pure _ ⟨_, rfl, W_skip _ _ _ hW⟩) (Except.Holds.ite
      (Except.Holds.pure _ ⟨_, rfl, W_skip _ _ _ (W_hold _ _ _ _ _ hW)⟩) ?_)
    split
    · exact Except.Holds.pure _ ⟨_, rfl, W_add _ _ _ _ hW⟩
    · exact Except.Holds.pure _ ⟨_, rfl, W_skip _ _ _ (W_hold _ _ _ _ _ hW)⟩
  refine Except.Holds.ite holds_throw_bind ?_
  let O : List (Nat × α) → SState α → Prop := fun rest s' =>
    Ledger m pol.delta stop (Insolvent N pol.wStart E₅) s'.trace.toList (s'.orders.map (·.2))
        (pol.wStart + ↑j * BAR + BAR + pol.delta) ∧
      (∀ e ∈ s'.trace.toList, ∀ c', dkey e = some (pol.wStart + ↑j * BAR + BAR + pol.delta, c') → c' ∉ rest.map (·.1)) ∧
      (rest.map (·.1)).Nodup ∧
      (∀ f, Event.fill f ∈ s'.trace.toList → f.why = .fill → Solvent N pol.wStart E₅ f.filled) ∧ s'.equity = E₅
  have O_skip : ∀ x rest s', O (x :: rest) s' → O rest s' := fun x rest s' hO =>
    ⟨hO.1, fun e he c' hk hr => hO.2.1 e he c' hk (List.mem_cons_of_mem _ hr), (List.nodup_cons.mp hO.2.2.1).2,
      hO.2.2.2⟩
  have O_order : ∀ (x : Nat × α) rest s' (w q pr : α) (mk : Int), O (x :: rest) s' →
      O rest { s' with trace := s'.trace.push (.decision (pol.wStart + ↑j * BAR + BAR + pol.delta) x.1 w q),
                       orders := s'.orders ++ [(pol.wStart + ↑j * BAR + BAR + BAR,
                         ⟨x.1, q, pr, mk, pol.wStart + ↑j * BAR + BAR + pol.delta⟩)] } := by
    intro x rest s' w q pr mk hO
    refine ⟨?_, fun e he c' hk hr => ?_, (List.nodup_cons.mp hO.2.2.1).2,
      solvent_push hO.2.2.2.1 (fun f h => by cases h), hO.2.2.2.2⟩
    · rw [Array.toList_push, List.map_append]
      exact hO.1.decide (Int.le_refl _) ⟨rfl, rfl, rfl⟩ fun e he hk => hO.2.1 e he x.1 hk (List.mem_cons_self ..)
    · rw [Array.toList_push] at he
      rcases List.mem_append.mp he with he | he
      · exact hO.2.1 e he c' hk (List.mem_cons_of_mem _ hr)
      · rw [List.mem_singleton.mp he] at hk
        simp only [dkey, Option.some.injEq, Prod.mk.injEq] at hk
        rw [← hk.2] at hr
        exact (List.nodup_cons.mp hO.2.2.1).1 hr
  refine Except.Holds.bind (R := O []) (Except.Holds.forIn_suffix _ _ _ O ⟨?_, fun e he c' hk => ?_, hW.2.2.1,
    hW.1.2.2.1, hW.1.2.2.2⟩ fun x rest s' hO => ?_) fun s₈ hO₈ => ?_
  · rw [hW.1.2.1]; exact hW.1.1.mono (by omega)
  · have := hW.1.1.dmax e he _ _ hk; omega
  · refine Except.Holds.ite ?_ ?_ <;>
      exact Except.Holds.ite (Except.Holds.pure _ ⟨_, rfl, O_order _ _ _ _ _ _ _ hO⟩)
        (Except.Holds.pure _ ⟨_, rfl, O_skip _ _ _ hO⟩)
  refine Except.Holds.pure _ ?_
  unfold LedgerAt
  have : pol.wStart + ((j + 1 : Nat) : Int) * BAR + pol.delta = pol.wStart + ↑j * BAR + BAR + pol.delta := by
    push_cast; rw [Int.add_mul, Int.one_mul]; omega
  rw [this, hO₈.2.2.2.2]
  exact ⟨hO₈.1, hO₈.2.2.2.1, by simp [E₅, hsize]⟩

theorem steps_ledger (N : NumOps α) (p : Program) (m : Market α) (hA : m.Admissible) (v : Venue α) (pol : Policy)
    (stop : Int) (j : Nat) (hj : j ≤ (Ctx.make p m v pol stop).bounds.length) :
    Except.Holds ((Ctx.make p m v pol stop).steps N j)
      (fun s => Inv4 N p m v pol stop j s ∧ LedgerAt N m pol stop j s) := by
  refine steps_induct N _ (fun j s => Inv4 N p m v pol stop j s ∧ LedgerAt N m pol stop j s)
    ((start_inv4 N p m v pol stop).and fun s hs => ?_) (fun j s ⟨h4, hl⟩ =>
      (step_inv4 N p m hA v pol stop j s h4).and (step_ledger N p m hA v pol stop j s h4 hl)) j hj
  obtain ⟨htr, ho, -, -, he⟩ := start_state N _ s hs
  unfold LedgerAt; rw [htr, ho, he]; exact ⟨Ledger.nil, by simp, rfl⟩

end Ref
