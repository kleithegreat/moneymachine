import Ref.Proof.Units

/-! One tick of one program: each node's row is written once, from the rows before it. -/

namespace Ref

variable {α : Type} [Inhabited α]

/-- A loop over s, s+1, … whose body always continues, with an invariant indexed by the next element. -/
theorem forIn_range {σ : Type} (s n : Nat) (init : σ) (f : Nat → σ → Id (ForInStep σ)) (I : Nat → σ → Prop)
    (h0 : I s init) (hf : ∀ k, s ≤ k → k < s + n → ∀ x, I k x → ∃ y, f k x = .yield y ∧ I (k + 1) y) :
    I (s + n) (forIn (m := Id) (List.range' s n) init f) := by
  induction n generalizing s init with
  | zero => exact h0
  | succ n ih =>
    obtain ⟨y, hy, hI⟩ := hf s (Nat.le_refl _) (by omega) init h0
    rw [List.range'_succ, List.forIn_cons]
    simp only [hy, bind]
    have := ih (s + 1) y hI fun k h1 h2 x hx => hf k (by omega) (by omega) x hx
    rwa [show s + 1 + n = s + (n + 1) by omega] at this

theorem opTy_nil (o : Op) (to : Option Dim) : opTy o [] to = none := by
  cases o <;> simp [opTy] <;> intro _ h <;> cases h

theorem forIn_range0 {σ : Type} (n : Nat) (init : σ) (f : Nat → σ → Id (ForInStep σ)) (I : Nat → σ → Prop)
    (h0 : I 0 init) (hf : ∀ k < n, ∀ x, I k x → ∃ y, f k x = .yield y ∧ I (k + 1) y) :
    I n (forIn (m := Id) (List.range' 0 n) init f) := by
  have := forIn_range 0 n init f I h0 fun k _ hk x hx => hf k (by omega) x hx
  simpa using this

theorem forIn_range_to {σ : Type} (n : Nat) (init : σ) (f : Nat → σ → Id (ForInStep σ)) (I : Nat → σ → Prop)
    (P : σ → Prop) (h0 : I 0 init) (hf : ∀ k < n, ∀ x, I k x → ∃ y, f k x = .yield y ∧ I (k + 1) y)
    (hP : ∀ x, I n x → P x) : P (forIn (m := Id) (List.range' 0 n) init f) :=
  hP _ (forIn_range0 n init f I h0 hf)

/-- An operator node's pointwise value reads only its arguments' rows and the inputs. -/
theorem eval_rows (N : NumOps α) (p : Program) (hp : p.WF) {m₁ m₂ : MState α} {a : Nat}
    (hv : ∀ b < a, m₁.vals[b]! = m₂.vals[b]!)
    (hf : m₁.funding = m₂.funding) (hb : m₁.bar = m₂.bar) (he : m₁.events = m₂.events) (hh : m₁.hour = m₂.hour)
    (c : Nat) : MState.eval N p m₁ a c = MState.eval N p m₂ a c := by
  have hin : ∀ inp c, m₁.input inp c = m₂.input inp c := by
    intro inp c; cases inp <;> simp [MState.input, hf, hb, he, hh]
  unfold MState.eval
  cases hn : p.nodes[a]! with
  | op o args =>
    have ha : a < p.nodes.size := by
      rcases Nat.lt_or_ge a p.nodes.size with h | h
      · exact h
      · rw [getElem!_neg p.nodes a (by omega)] at hn; cases hn
    have hw := hp.2.2.2.2.2 a ha
    rw [hn] at hw
    have h0 : 0 < a := by
      cases args with
      | nil => have := hw.2; simp [opTy_nil] at this
      | cons b _ => have := hw.1 b (by simp); omega
    have harg : ∀ k : Nat, m₁.vals[args[k]!]![c]! = m₂.vals[args[k]!]![c]! := by
      intro k
      by_cases hk : k < args.length
      · rw [hv _ (hw.1 _ (by rw [getElem!_pos args k hk]; exact List.getElem_mem hk))]
      · rw [getElem!_neg args k hk, show (default : Nat) = 0 from rfl, hv 0 h0]
    simp only [harg]
  | _ => simp [hin]

/-- A stored value: Undef or finite. -/
def Fin (N : NumOps α) (v : Val α) : Prop := v = none ∨ ∃ x, v = some x ∧ N.finite x = true

omit [Inhabited α] in
theorem fin_keep (N : NumOps α) (v : Val α) : Fin N (v.bind N.keep) := by
  cases v with
  | none => exact Or.inl rfl
  | some x =>
    simp only [Option.bind_some, NumOps.keep]
    split
    · exact Or.inr ⟨x, rfl, ‹_›⟩
    · exact Or.inl rfl

def Node.isWin : Node → Bool
  | .op (.window _ _) _ => true
  | _ => false

/-- A node whose value is its pointwise value, filtered (no window, cross-section or `hours_since` state). -/
def Node.isPoint : Node → Bool
  | .op (.window _ _) _ | .op .xsMean _ | .op .xsDemean _ | .op .xsRank _ | .op .hoursSince _ => false
  | _ => true

/-- Value rows sized to the coins, and no window state on a node that is not a window. -/
structure Shape (p : Program) (L : Array Bool) (m : MState α) : Prop where
  size : m.vals.size = p.nodes.size
  rows : ∀ a < p.nodes.size, m.vals[a]!.size = L.size
  wins : ∀ a < p.nodes.size, p.nodes[a]!.isWin = false → ∀ c : Nat, m.wins[a]![c]! = none

/-- Row a after its tick: finite or Undef, Undef where unlisted, and its pointwise value if it has one. -/
def RowOK (N : NumOps α) (p : Program) (L : Array Bool) (m : MState α) (a : Nat) : Prop :=
  ∀ c : Nat, Fin N (m.vals[a]![c]!) ∧ (L[c]! = false → m.vals[a]![c]! = none) ∧
    (p.nodes[a]!.isPoint = true → m.vals[a]![c]! = if L[c]! = true then (m.eval N p a c).bind N.keep else none)

omit [Inhabited α] in
theorem fin_bind (N : NumOps α) (v : Option Int) (g : Int → α) : Fin N (v.bind fun t => N.keep (g t)) := by
  cases v with
  | none => exact Or.inl rfl
  | some t => exact fin_keep N (some (g t))

theorem range_size (n : Nat) : [:n].size = n := by simp [Std.Legacy.Range.size]

/-- The state while a tick processes its nodes: rows before k done, the rest of the machine untouched. -/
structure Done (N : NumOps α) (p : Program) (L : Array Bool) (m : MState α) (k : Nat) (s : MState α) : Prop where
  shape : Shape p L s
  funding : s.funding = m.funding
  bar : s.bar = m.bar
  events : s.events = m.events
  maxKnown : s.maxKnown = m.maxKnown
  rows : ∀ a < k, RowOK N p L s a

/-- Writing row k keeps the rows before it done. -/
theorem Done.write {N : NumOps α} {p : Program} (hp : p.WF) {L : Array Bool} {m : MState α} {k : Nat} {s y : MState α}
    (h : Done N p L m k s) (hy : Shape p L y) (hv : ∀ b ≠ k, y.vals[b]! = s.vals[b]!) (hf : y.funding = s.funding)
    (hb : y.bar = s.bar) (he : y.events = s.events) (hh : y.hour = s.hour) (hm : y.maxKnown = s.maxKnown)
    (hk : RowOK N p L y k) : Done N p L m (k + 1) y := by
  refine ⟨hy, hf.trans h.funding, hb.trans h.bar, he.trans h.events, hm.trans h.maxKnown, fun a ha => ?_⟩
  rcases Nat.lt_or_ge a k with ha' | ha'
  · intro c
    have hrow := hv a (by omega)
    have heval := eval_rows N p hp (m₁ := y) (m₂ := s) (a := a) (fun b hb => hv b (by omega)) hf hb he hh c
    rw [hrow, heval]
    exact h.rows a ha' c
  · obtain rfl : a = k := by omega
    exact hk

omit [Inhabited α] in
theorem modify_ne {β : Type} [Inhabited β] (xs : Array β) {k b : Nat} (f : β → β) (h : b ≠ k) :
    (xs.modify k f)[b]! = xs[b]! := by
  simp only [getElem!_def, Array.getElem?_modify, if_neg (Ne.symm h)]

theorem bind_keep_ite (N : NumOps α) (b : Bool) (v : Val α) :
    (if b = true then v else none).bind N.keep = if b = true then v.bind N.keep else none := by
  cases b <;> rfl

/-- One node's step keeps the tick's invariant and writes its row. -/
theorem tickNode_spec (N : NumOps α) (p : Program) (hp : p.WF) (L : Array Bool) (hour : Int) (m : MState α)
    {k : Nat} (hk : k < p.nodes.size) {s : MState α} (hd : Done N p L m k s) (hh : s.hour = hour) :
    ∃ y, MState.tickNode N p L hour k s = .yield y ∧ Done N p L m (k + 1) y ∧ y.hour = hour ∧
      ∀ b ≠ k, y.vals[b]! = s.vals[b]! := by
  unfold MState.tickNode
  simp only [Std.Legacy.Range.forIn_eq_forIn_range']
  split
  · rename_i args hn
    refine ⟨_, rfl, ?_⟩
    rw [range_size]
    have hkv : k < s.vals.size := by rw [hd.shape.size]; exact hk
    have hkr : s.vals[k]!.size = L.size := hd.shape.rows k hk
    let K : Nat → MState α → Prop := fun c₀ t =>
      t.vals.size = s.vals.size ∧ (∀ b ≠ k, t.vals[b]! = s.vals[b]!) ∧ t.vals[k]!.size = L.size ∧
      t.wins = s.wins ∧ t.funding = s.funding ∧ t.bar = s.bar ∧ t.events = s.events ∧ t.hour = s.hour ∧
      t.maxKnown = s.maxKnown ∧ ∀ c < c₀, Fin N (t.vals[k]![c]!) ∧ (L[c]! = false → t.vals[k]![c]! = none)
    refine forIn_range_to _ _ _ K (fun x => Done N p L m (k + 1) x ∧ x.hour = hour ∧ ∀ b ≠ k, x.vals[b]! = s.vals[b]!)
      ⟨rfl, fun _ _ => rfl, hkr, rfl, rfl, rfl, rfl, rfl, rfl, fun c hc => absurd hc (Nat.not_lt_zero c)⟩
      (fun c hc t ht => ?_) (fun x hK => ?_)
    · obtain ⟨hsz, hrows, hksz, hwins, hf, hb, he, hh', hm, hE⟩ := ht
      have hkt : k < t.vals.size := by rw [hsz]; exact hkv
      have hct : c < t.vals[k]!.size := by rw [hksz]; exact hc
      have step : ∀ (S : Array (Array (Option Int))) (v : Val α), Fin N v → (L[c]! = false → v = none) →
          K (c + 1) { t with vals := t.vals.modify k (fun row => row.set! c v), since := S } := by
        intro S v hv hl
        refine ⟨by simp [hsz], fun b hb => by rw [modify_ne _ _ hb]; exact hrows b hb,
          by rw [size_modify_set]; exact hksz, hwins, hf, hb, he, hh', hm, fun c' hc' => ?_⟩
        rw [get_modify_set]
        by_cases hcc : c' = c
        · subst hcc
          simp only [true_and, hkt, hct, and_self, ite_true]
          exact ⟨hv, hl⟩
        · simp only [hcc, and_false, ite_false]
          exact hE c' (by omega)
      have hv : ∀ S : Array (Array (Option Int)),
          Fin N (if L[c]! = true then (S[k]![c]!.bind fun t => N.keep (N.ofInt ((hour - t) / HOUR))) else none) := by
        intro S; split
        · exact fin_bind _ _ _
        · exact Or.inl rfl
      have hl : ∀ S : Array (Array (Option Int)), L[c]! = false →
          (if L[c]! = true then (S[k]![c]!.bind fun t => N.keep (N.ofInt ((hour - t) / HOUR))) else none) = none := by
        intro S h; simp [h]
      split <;> (split <;> exact ⟨_, rfl, step _ _ (hv _) (hl _)⟩)
    · obtain ⟨hsz, hrows, hksz, hwins, hf, hb, he, hh', hm, hE⟩ := hK
      have hpt : p.nodes[k]!.isPoint = false := by rw [hn]; rfl
      refine ⟨Done.write hp hd ⟨by rw [hsz, hd.shape.size], fun a ha => ?_, fun a ha hnw c => ?_⟩ hrows hf hb he hh' hm
        fun c => ?_, by rw [hh', hh], hrows⟩
      · by_cases hak : a = k
        · subst hak; exact hksz
        · rw [hrows a hak]; exact hd.shape.rows a ha
      · rw [hwins]; exact hd.shape.wins a ha hnw c
      · rcases Nat.lt_or_ge c L.size with hc | hc
        · exact ⟨(hE c hc).1, (hE c hc).2, fun h => by rw [hpt] at h; cases h⟩
        · have hnone : x.vals[k]![c]! = (none : Val α) := getElem!_neg (x.vals[k]!) c (by rw [hksz]; omega)
          rw [hnone]
          exact ⟨Or.inl rfl, fun _ => rfl, fun h => by rw [hpt] at h; cases h⟩
  · rename_i args hn
    refine ⟨_, rfl, ?_⟩
    have hpt : p.nodes[k]!.isPoint = false := by rw [hn]; rfl
    have hkv : k < s.vals.size := by rw [hd.shape.size]; exact hk
    refine ⟨Done.write hp hd ⟨by simp [hd.shape.size], fun a ha => ?_, fun a ha hnw c => hd.shape.wins a ha hnw c⟩
      (fun b hb => Array.getElem!_set!_ne _ _ _ _ (Ne.symm hb)) rfl rfl rfl rfl rfl (fun c => ?_), hh,
      fun b hb => Array.getElem!_set!_ne _ _ _ _ (Ne.symm hb)⟩
    · by_cases hak : a = k
      · subst hak
        rw [Array.getElem!_set!_self _ _ _ hkv]
        split <;> simp
      · rw [Array.getElem!_set!_ne _ _ _ _ (Ne.symm hak)]; exact hd.shape.rows a ha
    · rw [Array.getElem!_set!_self _ _ _ hkv]
      refine ⟨?_, fun hl => ?_, fun h => by rw [hpt] at h; cases h⟩
      · split
        · simp [replicate_none_get]; exact Or.inl rfl
        · rcases Nat.lt_or_ge c L.size with hc | hc
          · rw [getElem!_pos _ c (by simpa using hc)]
            simp only [List.getElem_toArray, List.getElem_map, List.getElem_range]
            split
            · exact Or.inl rfl
            · exact fin_keep N (some _)
          · rw [getElem!_neg _ c (by simpa using hc)]; exact Or.inl rfl
      · split
        · simp [replicate_none_get]
        · rcases Nat.lt_or_ge c L.size with hc | hc
          · rw [getElem!_pos _ c (by simpa using hc)]
            simp only [List.getElem_toArray, List.getElem_map, List.getElem_range]
            split
            · rfl
            · next fst v hf =>
              exfalso
              have hfc := List.find?_some hf
              simp only [beq_iff_eq] at hfc
              obtain ⟨c', -, hc'⟩ := List.mem_filterMap.mp (List.mem_of_find?_eq_some hf)
              split at hc'
              · next hL' =>
                obtain ⟨v', -, he'⟩ := Option.map_eq_some_iff.mp hc'
                simp only [Prod.mk.injEq] at he'
                rw [he'.1, hfc, hl] at hL'
                cases hL'
              · cases hc'
          · rw [getElem!_neg _ c (by simpa using hc)]; rfl
  · rename_i args hn
    refine ⟨_, rfl, ?_⟩
    have hpt : p.nodes[k]!.isPoint = false := by rw [hn]; rfl
    have hkv : k < s.vals.size := by rw [hd.shape.size]; exact hk
    refine ⟨Done.write hp hd ⟨by simp [hd.shape.size], fun a ha => ?_, fun a ha hnw c => hd.shape.wins a ha hnw c⟩
      (fun b hb => Array.getElem!_set!_ne _ _ _ _ (Ne.symm hb)) rfl rfl rfl rfl rfl (fun c => ?_), hh,
      fun b hb => Array.getElem!_set!_ne _ _ _ _ (Ne.symm hb)⟩
    · by_cases hak : a = k
      · subst hak
        rw [Array.getElem!_set!_self _ _ _ hkv]
        split <;> simp
      · rw [Array.getElem!_set!_ne _ _ _ _ (Ne.symm hak)]; exact hd.shape.rows a ha
    · rw [Array.getElem!_set!_self _ _ _ hkv]
      refine ⟨?_, fun hl => ?_, fun h => by rw [hpt] at h; cases h⟩
      · split
        · simp [replicate_none_get]; exact Or.inl rfl
        · rcases Nat.lt_or_ge c L.size with hc | hc
          · rw [getElem!_pos _ c (by simpa using hc)]
            simp only [List.getElem_toArray, List.getElem_map, List.getElem_range]
            split
            · exact Or.inl rfl
            · exact fin_keep N (some _)
          · rw [getElem!_neg _ c (by simpa using hc)]; exact Or.inl rfl
      · split
        · simp [replicate_none_get]
        · rcases Nat.lt_or_ge c L.size with hc | hc
          · rw [getElem!_pos _ c (by simpa using hc)]
            simp only [List.getElem_toArray, List.getElem_map, List.getElem_range]
            split
            · rfl
            · next fst v hf =>
              exfalso
              have hfc := List.find?_some hf
              simp only [beq_iff_eq] at hfc
              obtain ⟨c', -, hc'⟩ := List.mem_filterMap.mp (List.mem_of_find?_eq_some hf)
              split at hc'
              · next hL' =>
                obtain ⟨v', -, he'⟩ := Option.map_eq_some_iff.mp hc'
                simp only [Prod.mk.injEq] at he'
                rw [he'.1, hfc, hl] at hL'
                cases hL'
              · cases hc'
          · rw [getElem!_neg _ c (by simpa using hc)]; rfl
  · rename_i args hn
    refine ⟨_, rfl, ?_⟩
    have hpt : p.nodes[k]!.isPoint = false := by rw [hn]; rfl
    have hkv : k < s.vals.size := by rw [hd.shape.size]; exact hk
    refine ⟨Done.write hp hd ⟨by simp [hd.shape.size], fun a ha => ?_, fun a ha hnw c => hd.shape.wins a ha hnw c⟩
      (fun b hb => Array.getElem!_set!_ne _ _ _ _ (Ne.symm hb)) rfl rfl rfl rfl rfl (fun c => ?_), hh,
      fun b hb => Array.getElem!_set!_ne _ _ _ _ (Ne.symm hb)⟩
    · by_cases hak : a = k
      · subst hak
        rw [Array.getElem!_set!_self _ _ _ hkv]
        split <;> simp
      · rw [Array.getElem!_set!_ne _ _ _ _ (Ne.symm hak)]; exact hd.shape.rows a ha
    · rw [Array.getElem!_set!_self _ _ _ hkv]
      refine ⟨?_, fun hl => ?_, fun h => by rw [hpt] at h; cases h⟩
      · split
        · simp [replicate_none_get]; exact Or.inl rfl
        · rcases Nat.lt_or_ge c L.size with hc | hc
          · rw [getElem!_pos _ c (by simpa using hc)]
            simp only [List.getElem_toArray, List.getElem_map, List.getElem_range]
            split
            · exact Or.inl rfl
            · exact fin_keep N (some _)
          · rw [getElem!_neg _ c (by simpa using hc)]; exact Or.inl rfl
      · split
        · simp [replicate_none_get]
        · rcases Nat.lt_or_ge c L.size with hc | hc
          · rw [getElem!_pos _ c (by simpa using hc)]
            simp only [List.getElem_toArray, List.getElem_map, List.getElem_range]
            split
            · rfl
            · next fst v hf =>
              exfalso
              have hfc := List.find?_some hf
              simp only [beq_iff_eq] at hfc
              obtain ⟨c', -, hc'⟩ := List.mem_filterMap.mp (List.mem_of_find?_eq_some hf)
              split at hc'
              · next hL' =>
                obtain ⟨v', -, he'⟩ := Option.map_eq_some_iff.mp hc'
                simp only [Prod.mk.injEq] at he'
                rw [he'.1, hfc, hl] at hL'
                cases hL'
              · cases hc'
          · rw [getElem!_neg _ c (by simpa using hc)]; rfl
  · refine ⟨_, rfl, ?_⟩
    rw [range_size]
    have hkv : k < s.vals.size := by rw [hd.shape.size]; exact hk
    have hkr : s.vals[k]!.size = L.size := hd.shape.rows k hk
    let K : Nat → MState α → Prop := fun c₀ t =>
      t.vals.size = s.vals.size ∧ (∀ b ≠ k, t.vals[b]! = s.vals[b]!) ∧ t.vals[k]!.size = L.size ∧
      (∀ b ≠ k, t.wins[b]! = s.wins[b]!) ∧ (p.nodes[k]!.isWin = false → ∀ c : Nat, t.wins[k]![c]! = none) ∧
      t.funding = s.funding ∧ t.bar = s.bar ∧ t.events = s.events ∧ t.hour = s.hour ∧ t.maxKnown = s.maxKnown ∧
      ∀ c < c₀, Fin N (t.vals[k]![c]!) ∧ (L[c]! = false → t.vals[k]![c]! = none) ∧
        (p.nodes[k]!.isPoint = true → t.vals[k]![c]! = if L[c]! = true then (s.eval N p k c).bind N.keep else none)
    refine forIn_range_to _ _ _ K (fun x => Done N p L m (k + 1) x ∧ x.hour = hour ∧ ∀ b ≠ k, x.vals[b]! = s.vals[b]!)
      ⟨rfl, fun _ _ => rfl, hkr, fun _ _ => rfl, hd.shape.wins k hk, rfl, rfl, rfl, rfl, rfl,
        fun c hc => absurd hc (Nat.not_lt_zero c)⟩ (fun c hc t ht => ?_) (fun x hK => ?_)
    · obtain ⟨hsz, hrows, hksz, hwins, hwk, hf, hb, he, hh', hm, hE⟩ := ht
      refine ⟨_, rfl, ?_⟩
      have hkt : k < t.vals.size := by rw [hsz]; exact hkv
      have hct : c < t.vals[k]!.size := by rw [hksz]; exact hc
      have hev : MState.eval N p t k c = MState.eval N p s k c :=
        eval_rows N p hp (fun b hb => hrows b (by omega)) hf hb he hh' c
      rw [hev]
      generalize hw : t.wins[k]![c]! = ow
      refine ⟨by simp [hsz], fun b hb => by rw [modify_ne _ _ hb]; exact hrows b hb, by rw [size_modify_set]; exact hksz,
        fun b hb => by rw [modify_ne _ _ hb]; exact hwins b hb, fun hnw c' => ?_, hf, hb, he, hh', hm, fun c' hc' => ?_⟩
      · have hnone := hwk hnw c
        rw [hw] at hnone; subst hnone
        rw [get_modify_set]
        split
        · rfl
        · exact hwk hnw c'
      · rw [get_modify_set]
        by_cases hcc : c' = c
        · subst hcc
          simp only [true_and, hkt, hct, and_self, ite_true]
          refine ⟨fin_keep _ _, fun hl => ?_, fun hpt => ?_⟩
          · cases ow <;> simp [hl]
          · have hnw : p.nodes[k]!.isWin = false := by
              revert hpt; cases p.nodes[k]! <;> simp [Node.isPoint, Node.isWin]
              rename_i o _; cases o <;> simp
            have hnone := hwk hnw c'
            rw [hw] at hnone; subst hnone
            exact bind_keep_ite N _ _
        · simp only [hcc, and_false, ite_false]
          exact hE c' (by omega)
    · obtain ⟨hsz, hrows, hksz, hwins, hwk, hf, hb, he, hh', hm, hE⟩ := hK
      refine ⟨Done.write hp hd ⟨by rw [hsz, hd.shape.size], fun a ha => ?_, fun a ha hnw c => ?_⟩ hrows hf hb he hh' hm
        fun c => ?_, by rw [hh', hh], hrows⟩
      · by_cases hak : a = k
        · subst hak; exact hksz
        · rw [hrows a hak]; exact hd.shape.rows a ha
      · by_cases hak : a = k
        · subst hak; exact hwk hnw c
        · rw [hwins a hak]; exact hd.shape.wins a ha hnw c
      · have heval : ∀ c, MState.eval N p _ k c = MState.eval N p s k c := fun c =>
          eval_rows N p hp (fun b hb => hrows b (by omega)) hf hb he hh' c
        rw [heval]
        rcases Nat.lt_or_ge c L.size with hc | hc
        · exact hE c hc
        · have hnone : x.vals[k]![c]! = (none : Val α) := getElem!_neg (x.vals[k]!) c (by rw [hksz]; omega)
          have hL : L[c]! = false := by rw [getElem!_neg L c (by omega)]; rfl
          rw [hnone, hL]
          exact ⟨Or.inl rfl, fun _ => rfl, fun _ => rfl⟩

theorem tick_spec (N : NumOps α) (p : Program) (hp : p.WF) (L : Array Bool) (hour : Int) (m : MState α)
    (hs : Shape p L m) : Done N p L m p.nodes.size (m.tick N p L hour) ∧ (m.tick N p L hour).hour = hour := by
  unfold MState.tick
  simp only [Std.Legacy.Range.forIn_eq_forIn_range']
  rw [range_size]
  exact forIn_range0 _ _ _ (fun k s => Done N p L m k s ∧ s.hour = hour)
    ⟨⟨⟨hs.size, hs.rows, hs.wins⟩, rfl, rfl, rfl, rfl, fun a ha => absurd ha (Nat.not_lt_zero a)⟩, rfl⟩
    fun k hk s ⟨hd, hh⟩ => let ⟨y, hy, hd', hh', _⟩ := tickNode_spec N p hp L hour m hk hd hh; ⟨y, hy, hd', hh'⟩

end Ref
