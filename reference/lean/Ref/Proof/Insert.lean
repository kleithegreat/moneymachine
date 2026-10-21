import Ref.Proof.Twin

/-! L3 for `ifNotRev`, first part: inserting a node at i, with later indices shifted, keeps every old node's
rows one place further on, through every node step and every tick. -/

namespace Ref

variable {α : Type} [Inhabited α]

/-- Where node k lives once a node is inserted at i. -/
def shift (i k : Nat) : Nat := if k ≥ i then k + 1 else k

theorem shift_inj {i a b : Nat} (h : shift i a = shift i b) : a = b := by
  unfold shift at h; split at h <;> split at h <;> omega

theorem shift_ne (i k : Nat) : shift i k ≠ i := by unfold shift; split <;> omega

omit [Inhabited α] in
theorem modify_get {β : Type} [Inhabited β] (xs : Array β) (k j : Nat) (g : β → β) :
    (xs.modify k g)[j]! = if j = k ∧ k < xs.size then g xs[k]! else xs[j]! := by
  rcases Nat.lt_or_ge j xs.size with hj | hj
  · rw [getElem!_pos _ j (by simpa using hj), Array.getElem_modify, getElem!_pos xs j hj]
    by_cases h : k = j
    · subst h; simp [hj, getElem!_pos xs k hj]
    · simp [h, Ne.symm h]
  · rw [getElem!_neg _ j (by simp; omega), getElem!_neg xs j (by omega)]
    split
    · omega
    · rfl

/-- Updating row k in place and row `shift i k` in the inserted machine keeps the correspondence. -/
theorem shifted_modify {β : Type} [Inhabited β] {i k : Nat} {xs ys : Array β} (h : ∀ k, ys[shift i k]! = xs[k]!)
    (hs : ys.size = xs.size + 1) (hi : i ≤ xs.size) (g : β → β) :
    ∀ k', (ys.modify (shift i k) g)[shift i k']! = (xs.modify k g)[k']! := by
  intro k'
  rw [modify_get, modify_get, h, h]
  have hsz : shift i k < ys.size ↔ k < xs.size := by unfold shift; split <;> omega
  by_cases hk : k' = k
  · subst hk; simp [hsz]
  · have : shift i k' ≠ shift i k := fun e => hk (shift_inj e)
    simp [this, hk]

theorem shift_lt {i k : Nat} (h : k < i) : shift i k = k := by unfold shift; split <;> omega
theorem shift_ge {i k : Nat} (h : i ≤ k) : shift i k = k + 1 := by unfold shift; split <;> omega

theorem set_get {β : Type} [Inhabited β] (xs : Array β) (k j : Nat) (v : β) :
    (xs.set! k v)[j]! = if j = k ∧ k < xs.size then v else xs[j]! := by
  simp only [Array.set!, getElem!_def, Array.getElem?_setIfInBounds]
  by_cases h : j = k
  · subst h; by_cases hk : j < xs.size <;> simp [hk]
  · have h' : k ≠ j := fun e => h e.symm
    simp [h, h']

section
variable {p : Program} {i : Nat} {n : Node} {t : Ty}

theorem ins_node (hi : i ≤ p.nodes.size) {k : Nat} (hk : k < p.nodes.size) :
    (p.insertAt i n t).nodes[shift i k]! = p.nodes[k]!.mapArgs (shift i) := by
  unfold Program.insertAt
  dsimp only
  rw [show shift i k = (if k ≥ i then k + 1 else k) from rfl, insert_shift _ (by simpa using hi)]
  rw [getElem!_pos _ k (by simpa using hk), Array.getElem_map, getElem!_pos p.nodes k hk]
  cases p.nodes[k] <;> rfl

theorem ins_new (hi : i ≤ p.nodes.size) : (p.insertAt i n t).nodes[i]! = n := by
  unfold Program.insertAt; dsimp only; rw [insert_get _ (by simpa using hi)]; simp

theorem ins_size (hi : i ≤ p.nodes.size) : (p.insertAt i n t).nodes.size = p.nodes.size + 1 := by
  unfold Program.insertAt; dsimp only; rw [insert_size _ (by simpa using hi)]; simp

theorem ins_weight : (p.insertAt i n t).weight = shift i p.weight := rfl
theorem ins_params : (p.insertAt i n t).params = p.params := rfl
end

/-- The machine of p (M) and of p with a node inserted at i (M'): each old row one place on, the same inputs. -/
structure Ins (i : Nat) (M M' : MState α) : Prop where
  vals : ∀ k : Nat, M'.vals[shift i k]! = M.vals[k]!
  wins : ∀ k : Nat, M'.wins[shift i k]! = M.wins[k]!
  since : ∀ k : Nat, M'.since[shift i k]! = M.since[k]!
  vsize : M'.vals.size = M.vals.size + 1
  wsize : M'.wins.size = M.wins.size + 1
  ssize : M'.since.size = M.since.size + 1
  ival : i ≤ M.vals.size
  iwin : i ≤ M.wins.size
  isin : i ≤ M.since.size
  funding : M'.funding = M.funding
  bar : M'.bar = M.bar
  events : M'.events = M.events
  hour : M'.hour = M.hour
  maxKnown : M'.maxKnown = M.maxKnown

theorem shifted_set {β : Type} [Inhabited β] {i k : Nat} {xs ys : Array β} (h : ∀ k, ys[shift i k]! = xs[k]!)
    (hs : ys.size = xs.size + 1) (hi : i ≤ xs.size) (v : β) :
    ∀ k', (ys.set! (shift i k) v)[shift i k']! = (xs.set! k v)[k']! := by
  intro k'
  rw [set_get, set_get, h]
  have hsz : shift i k < ys.size ↔ k < xs.size := by unfold shift; split <;> omega
  by_cases hk : k' = k
  · subst hk; simp [hsz]
  · have : shift i k' ≠ shift i k := fun e => hk (shift_inj e)
    simp [this, hk]

namespace Ins
variable {i : Nat} {M M' : MState α}

theorem vals_modify (h : Ins i M M') (k : Nat) (g : Array (Val α) → Array (Val α)) :
    Ins i { M with vals := M.vals.modify k g } { M' with vals := M'.vals.modify (shift i k) g } :=
  { h with vals := shifted_modify h.vals h.vsize h.ival g, vsize := by simp [h.vsize], ival := by simpa using h.ival }

theorem row_modify (h : Ins i M M') (k : Nat) (g : Array (Val α) → Array (Val α))
    (g' : Array (Option (Win α)) → Array (Option (Win α))) :
    Ins i { M with vals := M.vals.modify k g, wins := M.wins.modify k g' }
      { M' with vals := M'.vals.modify (shift i k) g, wins := M'.wins.modify (shift i k) g' } :=
  { h with vals := shifted_modify h.vals h.vsize h.ival g, vsize := by simp [h.vsize], ival := by simpa using h.ival,
           wins := shifted_modify h.wins h.wsize h.iwin g', wsize := by simp [h.wsize], iwin := by simpa using h.iwin }

theorem since_row_modify (h : Ins i M M') (k : Nat) (g : Array (Val α) → Array (Val α))
    (gs : Array (Option Int) → Array (Option Int)) :
    Ins i { M with vals := M.vals.modify k g, since := M.since.modify k gs }
      { M' with vals := M'.vals.modify (shift i k) g, since := M'.since.modify (shift i k) gs } :=
  { h with vals := shifted_modify h.vals h.vsize h.ival g, vsize := by simp [h.vsize], ival := by simpa using h.ival,
           since := shifted_modify h.since h.ssize h.isin gs, ssize := by simp [h.ssize], isin := by simpa using h.isin }

theorem new_row (h : Ins i M M') (g : Array (Val α) → Array (Val α))
    (g' : Array (Option (Win α)) → Array (Option (Win α))) :
    Ins i M { M' with vals := M'.vals.modify i g, wins := M'.wins.modify i g' } :=
  { h with vals := fun k => by rw [modify_ne _ _ (shift_ne i k)]; exact h.vals k, vsize := by simp [h.vsize],
           wins := fun k => by rw [modify_ne _ _ (shift_ne i k)]; exact h.wins k, wsize := by simp [h.wsize] }

theorem hour_set (h : Ins i M M') (hour : Int) : Ins i { M with hour := hour } { M' with hour := hour } :=
  { h with hour := rfl }

theorem vals_set (h : Ins i M M') (k : Nat) (v : Array (Val α)) :
    Ins i { M with vals := M.vals.set! k v } { M' with vals := M'.vals.set! (shift i k) v } :=
  { h with vals := shifted_set h.vals h.vsize h.ival v, vsize := by simp [h.vsize], ival := by simpa using h.ival }

/-- An argument's row: out-of-range argument indices read row 0, which sits before i. -/
theorem arg (h : Ins i M M') (hi0 : 0 < i) (args : List Nat) (j : Nat) :
    M'.vals[(args.map (shift i))[j]!]! = M.vals[args[j]!]! := by
  by_cases hj : j < args.length
  · rw [getElem!_pos (args.map _) j (by simpa using hj), List.getElem_map, getElem!_pos args j hj, h.vals]
  · rw [getElem!_neg (args.map _) j (by simpa using hj), getElem!_neg args j hj]
    have := h.vals 0
    rw [shift_lt hi0] at this
    exact this

theorem input (h : Ins i M M') (inp : Input) (c : Nat) : M'.input inp c = M.input inp c := by
  unfold MState.input; rw [h.funding, h.bar, h.events, h.hour]

end Ins

theorem eval_ins (N : NumOps α) {p q : Program} {i k : Nat} (hi0 : 0 < i)
    (hn : q.nodes[shift i k]! = p.nodes[k]!.mapArgs (shift i)) (hpar : q.params = p.params)
    {M M' : MState α} (h : Ins i M M') (c : Nat) :
    MState.eval N q M' (shift i k) c = MState.eval N p M k c := by
  unfold MState.eval
  rw [hn, hpar]
  cases p.nodes[k]! with
  | op o args => simp only [Node.mapArgs, h.arg hi0]
  | input inp => simp only [Node.mapArgs, h.input]
  | _ => rfl

/-- Two loops over one list, with bodies that keep a relation between their states. -/
theorem forIn_rel_id {β σ τ : Type} (l : List β) (a : σ) (b : τ) (f : β → σ → Id (ForInStep σ))
    (g : β → τ → Id (ForInStep τ)) (R : σ → τ → Prop) (h0 : R a b)
    (hf : ∀ x ∈ l, ∀ a b, R a b → ∃ a' b', f x a = .yield a' ∧ g x b = .yield b' ∧ R a' b') :
    R (forIn (m := Id) l a f) (forIn (m := Id) l b g) := by
  induction l generalizing a b with
  | nil => exact h0
  | cons x l ih =>
    obtain ⟨a', b', ha, hb, hR⟩ := hf x (by simp) a b h0
    rw [List.forIn_cons, List.forIn_cons, ha, hb]
    exact ih a' b' hR fun x' hx' => hf x' (by simp [hx'])

/-- Each old node's step keeps the relation: node shift i k of the inserted program, on M', does what node k
of p does on M. -/
theorem tickNode_ins (N : NumOps α) {p q : Program} {i k : Nat} (hi0 : 0 < i)
    (hn : q.nodes[shift i k]! = p.nodes[k]!.mapArgs (shift i)) (hpar : q.params = p.params)
    (L : Array Bool) (hour : Int) {M M' : MState α} (h : Ins i M M') :
    ∃ y y', MState.tickNode N p L hour k M = .yield y ∧ MState.tickNode N q L hour (shift i k) M' = .yield y' ∧
      Ins i y y' := by
  unfold MState.tickNode
  simp only [Std.Legacy.Range.forIn_eq_forIn_range']
  rw [hn]
  cases hk : p.nodes[k]! with
  | op o args =>
    simp only [Node.mapArgs]
    cases o
    all_goals first
      | (refine ⟨_, _, rfl, rfl, ?_⟩
         refine forIn_rel_id _ _ _ _ _ (Ins i) h fun c _ a b hab => ⟨_, _, rfl, rfl, ?_⟩
         rw [show MState.eval N q b (shift i k) c = MState.eval N p a k c from eval_ins N hi0 hn hpar hab c, hab.wins k]
         generalize a.wins[k]![c]! = w
         cases w <;> dsimp only <;> (try split) <;>
           exact hab.row_modify k _ _)
      | (dsimp only
         rw [h.arg hi0 args 0]
         exact ⟨_, _, rfl, rfl, h.vals_set k _⟩)
      | skip
    dsimp only
    refine ⟨_, _, rfl, rfl, ?_⟩
    refine forIn_rel_id _ _ _ _ _ (Ins i) h fun c _ a b hab => ?_
    rw [hab.arg hi0 args 0]
    split <;> split
    all_goals refine ⟨_, _, rfl, rfl, ?_⟩
    all_goals first
      | (rw [shifted_modify hab.since hab.ssize hab.isin _ k]; exact hab.since_row_modify k _ _)
      | (rw [hab.since k]; exact hab.vals_modify k _)
  | _ =>
    refine ⟨_, _, rfl, rfl, ?_⟩
    refine forIn_rel_id _ _ _ _ _ (Ins i) h fun c _ a b hab => ⟨_, _, rfl, rfl, ?_⟩
    rw [show MState.eval N q b (shift i k) c = MState.eval N p a k c from eval_ins N hi0 hn hpar hab c, hab.wins k]
    generalize a.wins[k]![c]! = w
    cases w <;> dsimp only <;> (try split) <;>
      exact hab.row_modify k _ _

/-- A loop whose body keeps an invariant. -/
theorem forIn_inv_id {β σ : Type} (l : List β) (a : σ) (f : β → σ → Id (ForInStep σ)) (I : σ → Prop) (h0 : I a)
    (hf : ∀ x ∈ l, ∀ a, I a → ∃ a', f x a = .yield a' ∧ I a') : I (forIn (m := Id) l a f) := by
  induction l generalizing a with
  | nil => exact h0
  | cons x l ih =>
    obtain ⟨a', ha, hI⟩ := hf x (by simp) a h0
    rw [List.forIn_cons, ha]
    exact ih a' hI fun x' hx' => hf x' (by simp [hx'])

/-- The inserted negation's step writes only its own row, which no old row maps to. -/
theorem tickNode_new (N : NumOps α) {q : Program} {i c₀ : Nat} (hnew : q.nodes[i]! = .op .not [c₀])
    (L : Array Bool) (hour : Int) {M M' : MState α} (h : Ins i M M') :
    ∃ y', MState.tickNode N q L hour i M' = .yield y' ∧ Ins i M y' := by
  unfold MState.tickNode
  simp only [Std.Legacy.Range.forIn_eq_forIn_range']
  rw [hnew]
  dsimp only
  refine ⟨_, rfl, ?_⟩
  refine forIn_inv_id _ _ _ (Ins i M) h fun c _ b hb => ⟨_, rfl, ?_⟩
  generalize b.wins[i]![c]! = w
  cases w <;> dsimp only <;> (try split) <;> exact hb.new_row _ _

theorem range_split (i n : Nat) (h : i ≤ n) : List.range' 0 n = List.range' 0 i ++ List.range' i (n - i) := by
  have e := List.range'_append_1 (s := 0) (m := i) (n := n - i)
  simp only [Nat.zero_add] at e
  rw [e]; congr 1; omega

theorem range_shift (i m : Nat) : ∀ s, i ≤ s → List.range' (s + 1) m = (List.range' s m).map (shift i) := by
  induction m with
  | zero => intros; rfl
  | succ m ih =>
    intro s hs
    rw [List.range'_succ, List.range'_succ, List.map_cons, shift_ge hs, ih (s + 1) (by omega)]

/-- A loop over two lists in turn, when every step yields. -/
theorem forIn_append_id {β σ : Type} (l₁ l₂ : List β) (a : σ) (f : β → σ → Id (ForInStep σ))
    (hf : ∀ x a, ∃ a', f x a = .yield a') :
    forIn (m := Id) (l₁ ++ l₂) a f = forIn (m := Id) l₂ (forIn (m := Id) l₁ a f) f := by
  induction l₁ generalizing a with
  | nil => rfl
  | cons x l ih =>
    obtain ⟨a', ha⟩ := hf x a
    rw [List.cons_append, List.forIn_cons, List.forIn_cons, ha]
    exact ih a'

theorem tickNode_yield (N : NumOps α) (p : Program) (L : Array Bool) (hour : Int) (k : Nat) (M : MState α) :
    ∃ M', MState.tickNode N p L hour k M = .yield M' := by
  unfold MState.tickNode; split <;> exact ⟨_, rfl⟩

/-- A tick of the inserted program keeps the relation: the old nodes as p's, then the negation at i. -/
theorem tick_ins (N : NumOps α) {p q : Program} {i c₀ : Nat} (hi0 : 0 < i) (hi : i ≤ p.nodes.size)
    (hq : q.nodes.size = p.nodes.size + 1)
    (hn : ∀ k < p.nodes.size, q.nodes[shift i k]! = p.nodes[k]!.mapArgs (shift i)) (hpar : q.params = p.params)
    (hnew : q.nodes[i]! = .op .not [c₀]) (L : Array Bool) (hour : Int) {M M' : MState α} (h : Ins i M M') :
    Ins i (M.tick N p L hour) (M'.tick N q L hour) := by
  unfold MState.tick
  simp only [Std.Legacy.Range.forIn_eq_forIn_range', range_size, hq]
  rw [range_split i p.nodes.size hi, range_split i (p.nodes.size + 1) (by omega),
    show p.nodes.size + 1 - i = (p.nodes.size - i) + 1 by omega, List.range'_succ, range_shift i _ i (Nat.le_refl i),
    forIn_append_id _ _ _ _ (tickNode_yield N p L hour), forIn_append_id _ _ _ _ (tickNode_yield N q L hour),
    List.forIn_cons]
  have s₁ : Ins i (forIn (m := Id) (List.range' 0 i) { M with hour := hour } (MState.tickNode N p L hour))
      (forIn (m := Id) (List.range' 0 i) { M' with hour := hour } (MState.tickNode N q L hour)) :=
    forIn_rel_id _ _ _ _ _ (Ins i) (h.hour_set hour) fun k hk a b hab => by
      have hk' : k < i := by have := (List.mem_range'_1.mp hk).2; omega
      have := tickNode_ins N hi0 (hn k (by omega)) hpar L hour hab
      rwa [shift_lt hk'] at this
  obtain ⟨y', hy', hY⟩ := tickNode_new N hnew L hour s₁
  simp only [hy', List.forIn_map]
  exact forIn_rel_id _ _ _ _ _ (Ins i) hY fun k hk a b hab =>
    tickNode_ins N hi0 (hn k (by have := (List.mem_range'_1.mp hk).2; omega)) hpar L hour hab
end Ref
