import Ref.Proof.Checker

/-! Every input the program's text names is compiled to a node (L5_text). -/

namespace Ref
open Json

variable {ok : Input → Prop}

/-! ## The occurrence traversal over unique keys -/

theorem mem_inj_of_nodup {β γ} [DecidableEq γ] {f : β → γ} {l : List β} (h : (l.map f).Nodup) {x y : β} (hx : x ∈ l)
    (hy : y ∈ l) (hxy : f x = f y) : x = y := by
  induction l with
  | nil => cases hx
  | cons a as ih =>
    simp only [List.map_cons, List.nodup_cons, List.mem_map, not_exists, not_and] at h
    rcases List.mem_cons.mp hx with rfl | hx' <;> rcases List.mem_cons.mp hy with rfl | hy'
    · rfl
    · exact absurd hxy.symm (h.1 _ hy')
    · exact absurd hxy (h.1 _ hx')
    · exact ih h.2 hx' hy'

theorem mentions_obj {name : String} {kvs : Array (String × Value)} (h : (Value.obj kvs).mentions name = true) :
    ∃ x ∈ kvs, (x.1 = "input" ∧ x.2 = .str name) ∨ x.2.mentions name = true := by
  rw [Value.mentions] at h
  simp only [Array.any_eq_true, Bool.or_eq_true, Bool.and_eq_true, beq_iff_eq] at h
  obtain ⟨i, hi, h⟩ := h
  generalize kvs.attach[i] = y at h
  obtain ⟨⟨k, v⟩, hy⟩ := y
  refine ⟨_, hy, ?_⟩
  cases v <;> simp_all

theorem mentions_arr {name : String} {xs : Array Value} (h : (Value.arr xs).mentions name = true) :
    ∃ x ∈ xs, x.mentions name = true := by
  rw [Value.mentions] at h
  simp only [Array.any_eq_true] at h
  obtain ⟨i, hi, h⟩ := h
  generalize xs.attach[i] = y at h
  exact ⟨_, y.2, h⟩

theorem uniqueKeys_obj {kvs : Array (String × Value)} (h : (Value.obj kvs).uniqueKeys = true) :
    (kvs.toList.map (·.1)).Nodup ∧ ∀ x ∈ kvs, x.2.uniqueKeys = true := by
  rw [Value.uniqueKeys] at h
  simp only [Bool.and_eq_true, decide_eq_true_eq, Array.all_eq_true] at h
  refine ⟨h.1, fun x hx => ?_⟩
  obtain ⟨i, hi, he⟩ := Array.getElem_of_mem (Array.mem_attach kvs ⟨x, hx⟩)
  have := h.2 i hi
  rwa [he] at this

theorem uniqueKeys_arr {xs : Array Value} (h : (Value.arr xs).uniqueKeys = true) :
    ∀ x ∈ xs, x.uniqueKeys = true := by
  rw [Value.uniqueKeys] at h
  simp only [Array.all_eq_true] at h
  intro x hx
  obtain ⟨i, hi, he⟩ := Array.getElem_of_mem (Array.mem_attach xs ⟨x, hx⟩)
  have := h i hi
  rwa [he] at this

theorem get_of_mem {kvs : Array (String × Value)} (hN : (kvs.toList.map (·.1)).Nodup) {x : String × Value}
    (hx : x ∈ kvs) : (Value.obj kvs).get? x.1 = some x.2 := by
  simp only [Value.get?]
  cases hf : kvs.find? (·.1 == x.1) with
  | none => exact absurd (Array.find?_eq_none.mp hf x hx) (by simp)
  | some y =>
    have hy := Array.find?_some hf
    obtain rfl : y = x := mem_inj_of_nodup hN (by simpa using Array.mem_of_find?_eq_some hf) (by simpa using hx)
      (by simpa using hy)
    rfl

theorem field_of_mem {kvs : Array (String × Value)} (hN : (kvs.toList.map (·.1)).Nodup) {x : String × Value}
    (hx : x ∈ kvs) : field kvs x.1 = x.2 := by
  have h := get_of_mem hN hx
  simp only [Value.get?] at h
  simp [field, h]

theorem field_unique {kvs : Array (String × Value)} (h : (Value.obj kvs).uniqueKeys = true) (k : String) :
    (field kvs k).uniqueKeys = true := by
  unfold field
  cases hf : kvs.find? (·.1 == k) with
  | none => simp [Value.uniqueKeys]
  | some y => exact (uniqueKeys_obj h).2 y (Array.mem_of_find?_eq_some hf)

/-! ## What a successful checker step says about its value -/

theorem Spec.bind_ret {β γ} {P : CState → Prop} {Q : γ → CState → Prop} {x : Check β} {f : β → Check γ}
    {R : β → Prop} (hx : Keeps x) (hR : ∀ st b st', x st = .ok (b, st') → R b) (hf : ∀ b, R b → Spec P (f b) Q) :
    Spec P (x >>= f) Q := by
  intro st hp c st' h
  change (x st >>= fun r => f r.1 r.2) = _ at h
  cases hxs : x st with
  | error e => rw [hxs] at h; cases h
  | ok r =>
    rw [hxs] at h
    obtain ⟨b, s⟩ := r
    obtain rfl := hx st b s hxs
    exact hf b (hR _ b _ hxs) _ hp c st' h

theorem Spec.ite' {β} {P : CState → Prop} {Q : β → CState → Prop} {c : Prop} [Decidable c] {x y : Check β}
    (hx : c → Spec P x Q) (hy : ¬c → Spec P y Q) : Spec P (if c then x else y) Q := by
  split
  · exact hx ‹_›
  · exact hy ‹_›

theorem forIn_yield_all {β} (l : List β) {f : β → PUnit → Check (ForInStep PUnit)} {p : β → Prop}
    (hf : ∀ a st r st', f a PUnit.unit st = .ok (r, st') → p a ∧ r = .yield PUnit.unit) :
    Spec (fun _ => True) (forIn l PUnit.unit f) (fun _ _ => ∀ a ∈ l, p a) := by
  refine Spec.conseq (Spec.forIn_yield l PUnit.unit f (fun rest _ _ => (∀ a ∈ rest, p a) → ∀ a ∈ l, p a) fun a rest s => ?_)
    (fun _ _ h => h) (fun _ _ h => h (by simp))
  intro st h r st' hx
  obtain ⟨ha, rfl⟩ := hf a st r st' hx
  exact ⟨_, rfl, fun hr => h fun b hb => (List.mem_cons.mp hb).elim (· ▸ ha) (hr b)⟩

theorem fields_ret (v : Value) (req opt : List String) :
    ∀ st r st', fields v req opt st = .ok (r, st') → v = .obj r ∧ ∀ x ∈ r, x.1 ∈ req ∨ x.1 ∈ opt := by
  refine fun st r st' h => (?_ : Spec (fun _ => True) (fields v req opt)
    (fun r _ => v = .obj r ∧ ∀ x ∈ r, x.1 ∈ req ∨ x.1 ∈ opt)) st trivial r st' h
  unfold fields
  split
  · rename_i kvs
    rw [← Array.forIn_toList]
    refine Spec.bind (forIn_yield_all kvs.toList (p := fun x => x.1 ∈ req ∨ x.1 ∈ opt) ?_) fun _ => ?_
    · rintro ⟨k, _⟩ st r st' h
      dsimp only at h
      split at h
      · cases h
      · cases h
        simp_all [Decidable.or_iff_not_imp_left]
    · exact Spec.bind_keeps (by keeps) fun _ => Spec.pure' fun _ h => ⟨rfl, fun x hx => h x (by simpa using hx)⟩
  · exact Spec.fail'

theorem asString_ret (c : Value) : ∀ st s st', asString c st = .ok (s, st') → c = .str s := by
  intro st s st' h
  cases c <;> first | (cases h; done) | (cases h; rfl)

theorem unitOf_ret (c : Value) : ∀ st u st', unitOf c st = .ok (u, st') → ∃ s, c = .str s := by
  intro st u st' h
  cases c <;> first | (cases h; done) | exact ⟨_, rfl⟩

theorem number_ret (name : String) (c : Value) : ∀ st b st', number c st = .ok (b, st') → c.mentions name = false := by
  intro st b st' h
  cases c <;> first | (cases h; done) | simp [Value.mentions]

theorem intern_nodes (n : Node) (t : Ty) (to : Option Dim) :
    ∀ st i st', intern n t to st = .ok (i, st') → n ∈ st'.nodes ∧ ∀ m ∈ st.nodes, m ∈ st'.nodes := by
  intro st i st' h
  unfold intern at h
  simp only [bind, StateT.bind, get, getThe, MonadStateOf.get, StateT.get, pure, set, MonadStateOf.set,
    Except.bind, Except.pure] at h
  cases hj : (st.nodes.zip st.convTo).findIdx? (· == (n, to)) with
  | some j =>
    simp only [hj, StateT.pure] at h
    obtain ⟨rfl, rfl⟩ := h
    obtain ⟨hlt, he, -⟩ := Array.findIdx?_eq_some_iff_getElem.mp hj
    simp only [Array.getElem_zip, beq_iff_eq, Prod.mk.injEq] at he
    exact ⟨he.1 ▸ Array.getElem_mem _, fun _ h => h⟩
  | none =>
    simp only [hj, StateT.bind, StateT.set, StateT.pure] at h
    obtain ⟨rfl, rfl⟩ := h
    exact ⟨by simp, fun _ h => Array.mem_push_of_mem _ h⟩

theorem typeOp_keeps (op : Op) (ts : List Ty) (kvs : Array (String × Value)) : Keeps (typeOp op ts kvs) := by
  unfold typeOp
  dsimp only
  cases op <;> repeat (first
    | exact Keeps.pure' _
    | exact Keeps.fail' _
    | exact unitOf_keeps _
    | refine Keeps.discard ?_
    | refine Keeps.bind ?_ (fun _ => ?_)
    | split)

theorem typeOp_extra (op : Op) (ts : List Ty) (kvs : Array (String × Value)) :
    ∀ st r st', typeOp op ts kvs st = .ok (r, st') → (match op with
      | .window .. => ∃ i, field kvs "hours" = .int i
      | .convert _ => ∃ s, field kvs "to" = .str s
      | _ => True) := by
  intro st r st' h
  cases op
  case convert =>
    refine (?_ : Spec (fun _ => True) (typeOp (.convert _) ts kvs) (fun _ _ => ∃ s, field kvs "to" = .str s)) st trivial r st' h
    unfold typeOp
    dsimp only
    exact Spec.bind_ret (unitOf_keeps _) (unitOf_ret _) fun _ hs _ _ _ _ _ => hs
  case window =>
    refine (?_ : Spec (fun _ => True) (typeOp (.window _ _) ts kvs) (fun _ _ => ∃ i, field kvs "hours" = .int i)) st trivial r st' h
    unfold typeOp
    dsimp only
    refine Spec.bind (R := fun _ _ => True) (fun _ _ _ _ _ => trivial) fun _ => ?_
    generalize hj : field kvs "hours" = j
    cases j
    all_goals first
      | exact fun _ _ _ _ _ => ⟨_, rfl⟩
      | exact Spec.fail'
  all_goals trivial

/-! ## A named input survives into the nodes -/

/-- What may stand where a mention was found: an expression mentioning the input, or, as the body of a let named
`input`, its bare name, which the checker refuses. -/
def Occ (name : String) (v : Value) : Prop := v.mentions name = true ∨ v = .str name

/-- The invariant, the input table, and the input's node already present or still to come (`r`). -/
def J (ok : Input → Prop) (T : Array (String × Input)) (inp : Input) (r : Prop) (st : CState) : Prop :=
  Inv ok st ∧ st.inputs = T ∧ (.input inp ∈ st.nodes ∨ r)

theorem J.mono {T : Array (String × Input)} {inp : Input} {r r' : Prop} {st : CState} (h : r → r') :
    J ok T inp r st → J ok T inp r' st := fun ⟨a, b, c⟩ => ⟨a, b, c.imp_right h⟩

theorem J.has {T : Array (String × Input)} {inp : Input} {r : Prop} {st : CState} (hr : ¬r) (h : J ok T inp r st) :
    .input inp ∈ st.nodes := h.2.2.elim id (absurd · hr)

theorem Frame.inputs (T : Array (String × Input)) : Frame (fun st => st.inputs = T) :=
  ⟨fun _ _ _ _ _ h => h, fun _ h => h⟩

theorem Frame.has (n : Node) : Frame (fun st => n ∈ st.nodes) :=
  ⟨fun _ _ _ _ _ h => Array.mem_push_of_mem _ h, fun _ h => h⟩

theorem expr_step {T : Array (String × Input)} {inp : Input} {name : String} {r : Prop} {e : Value} {d : Nat}
    (hmain : Occ name e → Spec (fun st => Inv ok st ∧ st.inputs = T) (expr e d) (fun _ st => .input inp ∈ st.nodes)) :
    Spec (J ok T inp (Occ name e ∨ r)) (expr e d) (fun i st => J ok T inp r st ∧ i < st.nodes.size) := by
  intro st ⟨hI, hT, hor⟩ b st' hx
  rcases hor with h | h | h
  · obtain ⟨hI', ⟨hT', h'⟩, hb⟩ := expr_spec e d ((Frame.inputs T).and (Frame.has _)) st ⟨hI, hT, h⟩ b st' hx
    exact ⟨⟨hI', hT', .inl h'⟩, hb⟩
  · obtain ⟨hI', hT', hb⟩ := expr_spec e d (Frame.inputs T) st ⟨hI, hT⟩ b st' hx
    exact ⟨⟨hI', hT', .inl (hmain h st ⟨hI, hT⟩ b st' hx)⟩, hb⟩
  · obtain ⟨hI', hT', hb⟩ := expr_spec e d (Frame.inputs T) st ⟨hI, hT⟩ b st' hx
    exact ⟨⟨hI', hT', .inr h⟩, hb⟩

theorem expr_bind {β} {T : Array (String × Input)} {inp : Input} {name : String} {r : Prop} {e : Value} {d : Nat}
    {f : Nat → Check β} {Q : β → CState → Prop}
    (hmain : Occ name e → Spec (fun st => Inv ok st ∧ st.inputs = T) (expr e d) (fun _ st => .input inp ∈ st.nodes))
    (hf : ∀ i, Spec (J ok T inp r) (f i) Q) : Spec (J ok T inp (Occ name e ∨ r)) (expr e d >>= f) Q :=
  Spec.bind (Spec.conseq (expr_step hmain) (fun _ h => h) (fun _ _ h => h.1)) hf

theorem Spec.get_bind' {γ} {P : CState → Prop} {Q : γ → CState → Prop} {f : CState → Check γ}
    (h : ∀ s, Spec P (f s) Q) : Spec P (get >>= f) Q := fun st hp b st' hx => h st st hp b st' hx

theorem str_no_mention {name s : String} {c : Value} (hc : c = .str s) (h : c.mentions name = true) : False := by
  subst hc; simp [Value.mentions] at h

theorem int_no_mention {name : String} {i : Int} {c : Value} (hc : c = .int i) (h : c.mentions name = true) : False := by
  subst hc; simp [Value.mentions] at h

theorem any_key {kvs : Array (String × Value)} {x : String × Value} (hx : x ∈ kvs) :
    (kvs.any fun y => y.1 == x.1) = true := by
  obtain ⟨i, hi, rfl⟩ := Array.getElem_of_mem hx
  exact Array.any_eq_true.mpr ⟨i, hi, by simp⟩

theorem expr_has {T : Array (String × Input)} {inp : Input} {name : String} (hT : ∀ x ∈ T, x.1 = name → x.2 = inp)
    (v : Value) (depth : Nat) (hU : v.uniqueKeys = true) (hM : Occ name v) :
    Spec (fun st => Inv ok st ∧ st.inputs = T) (expr v depth) (fun _ st => .input inp ∈ st.nodes) := by
  unfold expr
  refine Spec.bind (Spec.modify' (Q := fun _ st => Inv ok st ∧ st.inputs = T)
    fun st h => ⟨⟨h.1.1, h.1.2, h.1.3, h.1.4, h.1.5⟩, h.2⟩) fun _ => ?_
  split
  · exact Spec.fail'
  rename_i hd
  dsimp only
  refine Spec.get_bind' fun _ => Spec.ite' (fun _ => Spec.fail_bind) fun _ => Spec.pure_bind ?_
  split
  rotate_left
  · exact Spec.fail'
  rename_i kvs
  obtain ⟨hN, -⟩ := uniqueKeys_obj hU
  obtain ⟨x, hx, hxm⟩ : ∃ x ∈ kvs, (x.1 = "input" ∧ x.2 = .str name) ∨ x.2.mentions name = true := by
    rcases hM with h | h
    · exact mentions_obj h
    · cases h
  have hfx := field_of_mem hN hx
  refine Spec.ite' (fun hin => ?_) fun hnin => ?_
  · refine Spec.bind_ret (fields_keeps _ _ _) (fields_ret _ _ _) fun r ⟨hr, hk⟩ => ?_
    cases hr
    refine Spec.bind_ret (asString_keeps _) (asString_ret _) fun s hs => ?_
    have hk1 : x.1 = "input" := by simpa using hk x hx
    have hx2 : x.2 = .str s := by rw [← hfx, hk1]; exact hs
    obtain rfl : s = name := by
      rcases hxm with ⟨-, h⟩ | h
      · rw [hx2] at h; cases h; rfl
      · exact (str_no_mention hx2 h).elim
    refine Spec.get_bind fun s' => Spec.intro fun st0 h0 => ?_
    have hTs : s'.inputs = T := by rw [← h0.2]; exact h0.1.2
    split
    · rename_i fst i hf
      have hm := Array.mem_of_find?_eq_some hf
      obtain rfl : i = inp := hT _ (hTs ▸ hm) (by simpa using Array.find?_some hf)
      exact fun st _ b st' hx' => (intern_nodes _ _ _ st b st' hx').1
    · exact Spec.fail_bind
  have hxM : x.2.mentions name = true := by
    rcases hxm with ⟨h, -⟩ | h
    · exact absurd (h ▸ any_key hx) hnin
    · exact h
  have nostr : ∀ k s, x.1 = k → field kvs k = .str s → False := fun k s hk hs =>
    str_no_mention (by rw [← hfx, hk]; exact hs) hxM
  refine Spec.ite' (fun _ => ?_) fun _ => ?_
  · refine Spec.bind_ret (fields_keeps _ _ _) (fields_ret _ _ _) fun r ⟨hr, hk⟩ => ?_
    cases hr
    refine Spec.bind_ret (number_keeps _) (number_ret name _) fun _ hb => ?_
    refine Spec.bind_ret (unitOf_keeps _) (unitOf_ret _) fun _ ⟨su, hu⟩ => ?_
    have := hk x hx
    simp only [List.mem_cons, List.not_mem_nil, or_false] at this
    rcases this with h | h
    · rw [← h, hfx, hxM] at hb; cases hb
    · exact (nostr _ _ h hu).elim
  refine Spec.ite' (fun _ => ?_) fun _ => ?_
  · refine Spec.bind_ret (fields_keeps _ _ _) (fields_ret _ _ _) fun r ⟨hr, hk⟩ => ?_
    cases hr
    refine Spec.bind_ret (asString_keeps _) (asString_ret _) fun _ hs => ?_
    exact (nostr _ _ (by simpa using hk x hx) hs).elim
  refine Spec.ite' (fun _ => ?_) fun _ => ?_
  · refine Spec.bind_ret (fields_keeps _ _ _) (fields_ret _ _ _) fun r ⟨hr, hk⟩ => ?_
    cases hr
    refine Spec.bind_ret (asString_keeps _) (asString_ret _) fun _ hs => ?_
    exact (nostr _ _ (by simpa using hk x hx) hs).elim
  refine Spec.ite' (fun _ => Spec.fail_bind) fun _ => ?_
  refine Spec.bind_ret (asString_keeps _) (asString_ret _) fun _ hs => ?_
  split
  rotate_left
  · exact Spec.fail'
  rename_i op arity hfind
  refine Spec.bind_ret (fields_keeps _ _ _) (fields_ret _ _ _) fun r ⟨hr, hk⟩ => ?_
  cases hr
  split
  rotate_left
  · exact Spec.fail'
  rename_i args hargs
  refine Spec.ite' (fun _ => Spec.fail_bind) fun _ => ?_
  have hUargs : ∀ a ∈ args, a.uniqueKeys = true := uniqueKeys_arr (hargs ▸ field_unique hU "args")
  have hk' := hk x hx
  simp only [List.mem_append, List.mem_cons, List.not_mem_nil, or_false] at hk'
  refine Spec.bind (R := fun _ st => J ok T inp (x.1 ∈ match op with
      | .window .. => ["hours"]
      | .convert _ => ["to"]
      | _ => []) st) ?_ fun ix => ?_
  · rw [← Array.forIn_toList]
    refine Spec.conseq (Spec.forIn_yield args.toList #[] _ (fun rest _ st => J ok T inp ((∃ a ∈ rest, Occ name a) ∨ x.1 ∈ match op with
      | .window .. => ["hours"]
      | .convert _ => ["to"]
      | _ => []) st ∧ ∀ a ∈ rest, a.uniqueKeys = true) fun a rest ix => ?_) (fun st h => ⟨⟨h.1, h.2, .inr ?_⟩, by simpa using hUargs⟩)
      (fun _ st h => J.mono (by simp) h.1)
    · refine Spec.intro fun st0 ⟨hJ0, hU0⟩ => ?_
      refine Spec.bind (Spec.conseq (expr_step (r := (∃ b ∈ rest, Occ name b) ∨ _)
        fun h => expr_has hT a (depth + 1) (hU0 a (by simp)) h) (fun st h => ?_) (fun _ _ h => h.1))
        fun i => Spec.pure' fun st h => ⟨_, rfl, h, fun b hb => hU0 b (by simp [hb])⟩
      subst h
      exact J.mono (by simp only [List.mem_cons, exists_eq_or_imp]; exact (or_assoc).mp) hJ0
    · rcases hk' with (h | h) | h
      · exact (nostr _ _ h hs).elim
      · have h2 : x.2 = .arr args := by rw [← hfx, h]; exact hargs
        rw [h2] at hxM
        obtain ⟨a, ha, hm⟩ := mentions_arr hxM
        exact .inl ⟨a, by simpa using ha, .inl hm⟩
      · exact .inr h
  · refine Spec.get_bind' fun _ => Spec.bind_ret (typeOp_keeps _ _ _) (typeOp_extra _ _ _) fun _ ht => ?_
    intro st hJ i st' hi
    obtain ⟨-, hmono⟩ := intern_nodes _ _ _ st i st' hi
    rcases hJ.2.2 with h | h
    · exact hmono _ h
    · exfalso
      cases op <;> simp at h
      · obtain ⟨_, hj⟩ := ht
        exact nostr _ _ h hj
      · obtain ⟨_, hj⟩ := ht
        exact int_no_mention (by rw [← hfx, h]; exact hj) hxM
termination_by maxDepth + 1 - depth
decreasing_by omega

/-! ## Through the program -/

theorem get_unique {kvs : Array (String × Value)} (h : (Value.obj kvs).uniqueKeys = true) {k : String} {c : Value}
    (hc : (Value.obj kvs).get? k = some c) : c.uniqueKeys = true := by
  simp only [Value.get?, Option.map_eq_some_iff] at hc
  obtain ⟨y, hy, rfl⟩ := hc
  exact (uniqueKeys_obj h).2 y (Array.mem_of_find?_eq_some hy)

theorem params_loop {T : Array (String × Input)} {inp : Input} {r : Prop} (ps : Array (String × Value)) :
    Spec (J ok T inp r) (forIn ps PUnit.unit fun x _ => do
      let s ← fields x.2 ["value", "unit"] []
      let b ← number (field s "value")
      let u ← unitOf (field s "unit")
      modify fun st => { st with params := st.params.push (x.1, b, u) }
      pure (ForInStep.yield PUnit.unit)) (fun _ => J ok T inp r) :=
  Spec.forIn_array _ _ _ (fun _ => J ok T inp r) fun _ _ _ =>
    Spec.bind_keeps (fields_keeps _ _ _) fun _ => Spec.bind_keeps (number_keeps _) fun _ =>
    Spec.bind_keeps (unitOf_keeps _) fun _ =>
    Spec.bind (Spec.modify' (Q := fun _ => J ok T inp r) fun _ (h : J ok T inp r _) => ⟨Inv.pushParam _ h.1, h.2⟩) fun _ =>
    Spec.pure' fun _ h => h

theorem lets_loop {T : Array (String × Input)} {inp : Input} {name : String} {r : Prop}
    (hT : ∀ x ∈ T, x.1 = name → x.2 = inp) (ls : Array (String × Value)) (hU : ∀ x ∈ ls, x.2.uniqueKeys = true) :
    Spec (J ok T inp ((∃ x ∈ ls, Occ name x.2) ∨ r)) (forIn ls PUnit.unit fun x _ => do
      let i ← expr x.2 1
      modify fun st => { st with lets := st.lets.push (x.1, i) }
      pure (ForInStep.yield PUnit.unit)) (fun _ => J ok T inp r) := by
  rw [← Array.forIn_toList]
  refine Spec.conseq (Spec.forIn_yield ls.toList PUnit.unit _ (fun rest _ st =>
    J ok T inp ((∃ x ∈ rest, Occ name x.2) ∨ r) st ∧ ∀ x ∈ rest, x.2.uniqueKeys = true) fun a rest _ => ?_)
    (fun st h => ⟨J.mono (by simp) h, by simpa using hU⟩) (fun _ st h => J.mono (by simp) h.1)
  refine Spec.intro fun st0 ⟨hJ0, hU0⟩ => ?_
  refine Spec.bind (R := fun i st => J ok T inp ((∃ x ∈ rest, Occ name x.2) ∨ r) st ∧ i < st.nodes.size)
    (Spec.conseq (expr_step fun h => expr_has hT a.2 1 (hU0 a (by simp)) h) (fun st h => ?_) (fun _ _ h => h)) fun i => ?_
  · subst h
    exact J.mono (by simp only [List.mem_cons, exists_eq_or_imp]; exact (or_assoc).mp) hJ0
  · refine Spec.bind (Spec.modify' (Q := fun _ st => J ok T inp ((∃ x ∈ rest, Occ name x.2) ∨ r) st)
      fun st h => ⟨Inv.pushLet _ h.1.1 h.2, h.1.2⟩) fun _ => Spec.pure' fun _ h => ⟨_, rfl, h, fun x hx => hU0 x (by simp [hx])⟩

/-- A mention in a let's body. -/
def LM (name : String) (v : Value) : Prop := ∃ l, v.get? "let" = some l ∧ l.mentions name = true
/-- A mention in the prediction's condition. -/
def PM (name : String) (v : Value) : Prop :=
  ∃ pk, v.get? "prediction" = some (.obj pk) ∧ (field pk "condition").mentions name = true

theorem program_has {T : Array (String × Input)} {inp : Input} {name : String} (hT : ∀ x ∈ T, x.1 = name → x.2 = inp)
    (kvs : Array (String × Value)) (hU : (Value.obj kvs).uniqueKeys = true) :
    Spec (J ok T inp (LM name (.obj kvs) ∨ Occ name (field kvs "weight") ∨ PM name (.obj kvs))) (program (.obj kvs))
      (fun _ st => .input inp ∈ st.nodes) := by
  have hL : ∀ ls, (Value.obj kvs).get? "let" = some (.obj ls) → LM name (.obj kvs) → ∃ x ∈ ls, Occ name x.2 := by
    rintro ls hl ⟨l, hl', hm⟩
    rw [hl] at hl'
    cases hl'
    obtain ⟨x, hx, h⟩ := mentions_obj hm
    exact ⟨x, hx, h.elim (.inr ·.2) .inl⟩
  have hL0 : (∀ p, (Value.obj kvs).get? "let" = some p → False) → ¬LM name (.obj kvs) := by
    rintro hl ⟨l, hl', -⟩
    exact hl _ hl'
  have hP0 : (Value.obj kvs).get? "prediction" = none → ¬PM name (.obj kvs) := by
    rintro hl ⟨l, hl', -⟩
    rw [hl] at hl'
    cases hl'
  unfold program
  dsimp only
  refine Spec.bind_ret (fields_keeps _ _ _) (fields_ret _ _ _) fun r hr => ?_
  cases hr.1
  repeat' (first
    | with_reducible_and_instances exact Spec.fail'
    | with_reducible_and_instances exact Spec.fail_bind
    | with_reducible_and_instances refine Spec.bind_keeps (fields_keeps _ _ _) fun _ => ?_
    | with_reducible_and_instances refine Spec.bind_keeps (asString_keeps _) fun _ => ?_
    | with_reducible_and_instances refine Spec.bind_keeps (Keeps.discard (asString_keeps _)) fun _ => ?_
    | with_reducible_and_instances refine Spec.ite' (fun _ => ?_) fun _ => ?_
    | with_reducible_and_instances refine Spec.pure_bind ?_
    | split)
  all_goals try with_reducible_and_instances refine Spec.bind (params_loop _) fun _ => ?_
  all_goals first
    | with_reducible_and_instances exact Spec.fail_bind
    | with_reducible_and_instances refine Spec.bind (Spec.conseq (lets_loop hT _ (fun x hx =>
        (uniqueKeys_obj (get_unique hU ‹_›)).2 x hx) (r := Occ name (field kvs "weight") ∨ PM name (.obj kvs)))
        (fun st h => J.mono (fun hh => hh.elim (.inl ∘ hL _ ‹_›) .inr) h) (fun _ _ h => h)) fun _ => ?_
    | refine Spec.conseq ?_ (fun st h => J.mono (fun hh => hh.elim (fun h' => absurd h' (hL0 ‹_›)) id) h) (fun _ _ h => h)
  all_goals try with_reducible_and_instances exact Spec.fail_bind
  all_goals with_reducible_and_instances refine expr_bind (fun h => expr_has hT _ 1 (field_unique hU "weight") h) fun _ => ?_
  all_goals repeat' (first
    | with_reducible_and_instances exact Spec.fail_bind
    | with_reducible_and_instances refine Spec.get_bind' fun _ => ?_
    | with_reducible_and_instances refine Spec.ite' (fun _ => ?_) fun _ => ?_
    | with_reducible_and_instances refine Spec.pure_bind ?_
    | split)
  all_goals first
    | with_reducible_and_instances exact Spec.pure' fun _ h => J.has (hP0 ‹_›) h
    | with_reducible_and_instances refine Spec.bind_ret (fields_keeps _ _ _) (fields_ret _ _ _) fun pk hp => ?_
      obtain ⟨rfl, -⟩ := hp
      have hq := ‹(Value.obj kvs).get? "prediction" = some _›
      refine Spec.conseq (P := J ok T inp (Occ name (field pk "condition") ∨ False)) ?_ (fun _ h => J.mono ?_ h) (fun _ _ h => h)
      · with_reducible_and_instances refine expr_bind (fun h => expr_has hT _ 1 (field_unique (get_unique hU hq) "condition") h) fun _ => ?_
        refine Spec.get_bind' fun _ => Spec.ite' (fun _ => Spec.fail_bind) fun _ => Spec.pure_bind ?_
        exact Spec.get_bind' fun _ => Spec.pure' fun _ h => J.has id h
      · rintro ⟨pk2, hk, hm⟩
        rw [hq] at hk
        cases hk
        exact .inl (.inl hm)

/-! ## The law's conclusion -/

theorem nodup_of_eraseDups {β} [BEq β] [LawfulBEq β] [DecidableEq β] (l : List β) (h : l.eraseDups.length = l.length) :
    l.Nodup := by
  have hle : ∀ (n : Nat) (l : List β), l.length ≤ n → l.eraseDups.length ≤ l.length := by
    intro n
    induction n with
    | zero => intro l hl; cases l <;> simp_all
    | succ n ih =>
      intro l hl
      cases l with
      | nil => simp
      | cons a as =>
        rw [List.eraseDups_cons]
        have hf := List.length_filter_le (fun b => !b == a) as
        have := ih (as.filter fun b => !b == a) (by simp at hl; omega)
        simp only [List.length_cons]
        omega
  induction hn : l.length generalizing l with
  | zero => cases l <;> simp_all
  | succ n ih =>
    cases l with
    | nil => simp at hn
    | cons a as =>
      rw [List.eraseDups_cons] at h
      simp only [List.length_cons] at h hn
      have hf := List.length_filter_le (fun b => !b == a) as
      have := hle _ (as.filter fun b => !b == a) (Nat.le_refl _)
      have hlen : (as.filter fun b => !b == a).length = as.length := by omega
      have hall := List.length_filter_eq_length_iff.mp hlen
      have hsame : as.filter (fun b => !b == a) = as := List.filter_eq_self.mpr hall
      rw [hsame] at h
      refine List.nodup_cons.mpr ⟨fun ha => by simpa using hall a ha, ih as (by omega) (by omega)⟩

theorem toList_eq_range {β} [Inhabited β] (xs : Array β) : xs.toList = (List.range xs.size).map (xs[·]!) := by
  apply List.ext_getElem
  · simp
  · intro i h _
    simp only [List.getElem_map, List.getElem_range, Array.getElem_toList]
    exact (getElem!_pos xs i (by simpa using h)).symm

theorem inputs_nodup (reg : Registry) (h : reg.Valid) : (reg.inputs.toList.map (·.1)).Nodup := by
  unfold Registry.Valid Registry.valid at h
  simp only [Bool.and_eq_true, beq_iff_eq] at h
  have hn := nodup_of_eraseDups _ h.1.1.1.1.1
  suffices he : reg.inputs.toList.map (·.1) = reg.decls.toList.flatMap fun d => d.fields.toList.map (·.1) by
    rw [he]; exact hn
  rw [toList_eq_range reg.decls]
  simp only [Registry.inputs, Array.toList_flatMap, Array.toList_range, Array.toList_map, List.flatMap_map, List.map_flatMap,
    List.map_map]
  congr 1
  funext a
  rw [toList_eq_range (reg.decls[a]!).fields]
  simp [Function.comp_def]

theorem mem_closure (reg : Registry) (fuel : Nat) {xs : List Nat} {s : Nat} (h : s ∈ xs) : s ∈ reg.closure fuel xs := by
  cases fuel <;> simp [Registry.closure, List.mem_eraseDups, h]

theorem any_mem {β} {xs : Array β} {p : β → Bool} (h : xs.any p = true) : ∃ x ∈ xs, p x = true := by
  obtain ⟨i, hi, h⟩ := Array.any_eq_true.mp h
  exact ⟨_, Array.getElem_mem hi, h⟩

/-- What `InputRef` found, as the three places the program compiles. -/
theorem pending_of_ref {name : String} {kvs : Array (String × Value)} (hU : (Value.obj kvs).uniqueKeys = true)
    (hR : ((kvs.any fun (k, v) => (k == "weight" || k == "let") && v.mentions name) ||
      (kvs.any fun (k, v) => k == "prediction" && match v with
        | .obj pk => pk.any fun (k', c) => k' == "condition" && c.mentions name
        | _ => false)) = true) :
    LM name (.obj kvs) ∨ Occ name (field kvs "weight") ∨ PM name (.obj kvs) := by
  obtain ⟨hN, hV⟩ := uniqueKeys_obj hU
  rcases (Bool.or_eq_true _ _).mp hR with h | h
  · obtain ⟨⟨k, c⟩, hy, hm⟩ := any_mem h
    simp only [Bool.and_eq_true, Bool.or_eq_true, beq_iff_eq] at hm
    obtain ⟨rfl | rfl, hm⟩ := hm
    · exact .inr (.inl (.inl ((field_of_mem hN hy).symm ▸ hm)))
    · exact .inl ⟨c, get_of_mem hN hy, hm⟩
  · obtain ⟨⟨k, c⟩, hy, hm⟩ := any_mem h
    simp only [Bool.and_eq_true, beq_iff_eq] at hm
    obtain ⟨rfl, hm⟩ := hm
    cases c
    all_goals try (cases hm; done)
    rename_i pk
    obtain ⟨⟨k', c⟩, hz, hm⟩ := any_mem hm
    simp only [Bool.and_eq_true, beq_iff_eq] at hm
    obtain ⟨rfl, hm⟩ := hm
    exact .inr (.inr ⟨pk, get_of_mem hN hy, (field_of_mem (uniqueKeys_obj (hV _ hy)).1 hz).symm ▸ hm⟩)

theorem text_required (reg : Registry) (hV : reg.Valid) (roles : Roles) (adm : Meta) (text name : String) (p : Program)
    (inp : Input) (h : check reg.inputs text = .ok p) (hR : InputRef text name) (hN : (name, inp) ∈ reg.inputs.toList) :
    inp.source ∈ adm.required reg roles p := by
  have hT : ∀ x ∈ reg.inputs, x.1 = name → x.2 = inp := fun x hx hn => by
    rw [mem_inj_of_nodup (inputs_nodup reg hV) (by simpa using hx) hN hn]
  have hI0 : Inv (fun _ => True) { inputs := reg.inputs } :=
    ⟨rfl, rfl, fun _ h => by simp at h, fun _ h => by simp at h, fun _ _ => trivial⟩
  have hnode : Node.input inp ∈ p.nodes := by
    unfold check at h
    unfold InputRef at hR
    split at h
    · cases h
    split at h
    · cases h
    rename_i v hp
    rw [hp] at hR
    split at h
    · cases h
    rename_i hu
    split at h
    · rename_i r st hr
      cases h
      cases v
      all_goals try (cases hR; done)
      rename_i kvs
      have hU : (Value.obj kvs).uniqueKeys = true := by simpa using hu
      have hn := program_has (ok := fun _ => True) hT kvs hU _ ⟨hI0, rfl, .inr (pending_of_ref hU hR)⟩ _ _ hr
      obtain ⟨-, hps, -⟩ := program_spec _ _ hI0 _ _ hr
      rw [hps]
      exact hn
    · cases h
  refine mem_closure reg _ ?_
  simp only [List.mem_append, Program.sources, List.mem_eraseDups, List.mem_filterMap]
  exact .inl (.inr ⟨.input inp, by simpa using hnode, rfl⟩)

/-! The duplicate-key rule where nothing compiled would notice (the corpus's `kernel/tests/adversarial/gpt27`, `gpt28`
hold it in the weight): a duplicate inside an unused let is refused, and the same text without it passes. -/

private def textTable : Array (String × Input) := #[("funding", ⟨0, 0, false, (Dim.parse "1/h").get!⟩)]
private def textProgram (body : String) : String :=
  r#"{"dsl":1,"name":"n","mechanism":{"counterparty":"-","predictions":[],"capacity":"-"},"let":{"hidden":"# ++ body ++
    r#"},"weight":{"const":0,"unit":"1"}}"#

#guard match check textTable (textProgram r#"{"input":"funding","input":"funding"}"#) with
  | .error .parse => true
  | _ => false
#guard match check textTable (textProgram r#"{"input":"funding"}"#) with
  | .ok _ => true
  | _ => false

end Ref
