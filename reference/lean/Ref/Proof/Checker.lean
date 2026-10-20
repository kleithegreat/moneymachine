import Ref.Syntax

/-! What the checker's accepted programs satisfy: a Hoare logic for `Check`, and the invariant every
checker step keeps on its state, for any typing rule that `typeOp` agrees with. -/

namespace Ref

/-- Partial correctness: from a state satisfying P, a successful x ends in a state satisfying Q. -/
def Spec {β} (P : CState → Prop) (x : Check β) (Q : β → CState → Prop) : Prop :=
  ∀ st, P st → ∀ b st', x st = .ok (b, st') → Q b st'

namespace Spec
variable {β γ : Type} {P : CState → Prop} {Q : β → CState → Prop}

theorem pure' {b : β} (h : ∀ st, P st → Q b st) : Spec P (pure b) Q := by
  intro st hp b' st' hx; cases hx; exact h st hp

theorem bind {R : β → CState → Prop} {x : Check β} {f : β → Check γ} {Q : γ → CState → Prop}
    (hx : Spec P x R) (hf : ∀ b, Spec (R b) (f b) Q) : Spec P (x >>= f) Q := by
  intro st hp c st' h
  change (x st >>= fun r => f r.1 r.2) = _ at h
  cases hxs : x st with
  | error e => rw [hxs] at h; cases h
  | ok r => rw [hxs] at h; exact hf r.1 r.2 (hx st hp r.1 r.2 hxs) c st' h

theorem throw' {c : Code} : Spec P (throw c : Check β) Q := by
  intro st _ b st' h; cases h

theorem fail' {c : Code} : Spec P (fail c : Check β) Q := throw'

theorem get' {Q : CState → CState → Prop} (h : ∀ st, P st → Q st st) : Spec P get Q := by
  intro st hp b st' hx; cases hx; exact h st hp

theorem modify' {f : CState → CState} {Q : PUnit → CState → Prop} (h : ∀ st, P st → Q ⟨⟩ (f st)) :
    Spec P (modify f) Q := by
  intro st hp b st' hx; cases hx; exact h st hp

theorem set' {s : CState} {Q : PUnit → CState → Prop} (h : ∀ st, P st → Q ⟨⟩ s) : Spec P (set s) Q := by
  intro st hp b st' hx; cases hx; exact h st hp

theorem conseq {P' : CState → Prop} {Q' : β → CState → Prop} {x : Check β} (h : Spec P x Q)
    (hp : ∀ st, P' st → P st) (hq : ∀ b st, Q b st → Q' b st) : Spec P' x Q' :=
  fun st h' b st' hx => hq _ _ (h st (hp st h') b st' hx)

theorem forIn_list {σ : Type} (l : List β) (init : σ) (f : β → σ → Check (ForInStep σ)) (I : σ → CState → Prop)
    (hf : ∀ a ∈ l, ∀ s, Spec (I s) (f a s) (fun r st => I r.value st)) :
    Spec (I init) (forIn l init f) I := by
  induction l generalizing init with
  | nil => exact pure' fun _ h => h
  | cons a as ih =>
    simp only [List.forIn_cons]
    refine bind (hf a (by simp) init) fun r => ?_
    cases r with
    | done s => exact pure' fun _ h => h
    | yield s => exact ih s (fun a' ha' => hf a' (by simp [ha']))

theorem forIn_array {σ : Type} (xs : Array β) (init : σ) (f : β → σ → Check (ForInStep σ)) (I : σ → CState → Prop)
    (hf : ∀ a ∈ xs, ∀ s, Spec (I s) (f a s) (fun r st => I r.value st)) :
    Spec (I init) (forIn xs init f) I := by
  rw [← Array.forIn_toList]
  exact forIn_list _ _ _ _ fun a ha => hf a (by simpa using ha)

end Spec

/-- x leaves the state as it found it. -/
def Keeps {β} (x : Check β) : Prop := ∀ st b st', x st = .ok (b, st') → st' = st

namespace Keeps
variable {β γ : Type}

theorem spec {x : Check β} (h : Keeps x) (P : CState → Prop) : Spec P x (fun _ => P) :=
  fun st hp b st' hx => (h st b st' hx) ▸ hp

theorem pure' (b : β) : Keeps (pure b : Check β) := by
  intro st b' st' h; cases h; rfl

theorem fail' (c : Code) : Keeps (fail c : Check β) := by
  intro st b st' h; cases h

theorem bind {x : Check β} {f : β → Check γ} (hx : Keeps x) (hf : ∀ b, Keeps (f b)) : Keeps (x >>= f) := by
  intro st c st' h
  change (x st >>= fun r => f r.1 r.2) = _ at h
  cases hxs : x st with
  | error e => rw [hxs] at h; cases h
  | ok r => rw [hxs] at h; rw [hf r.1 r.2 c st' h, hx st r.1 r.2 hxs]

theorem forIn_list {σ : Type} (l : List β) (init : σ) (f : β → σ → Check (ForInStep σ)) (hf : ∀ a s, Keeps (f a s)) :
    Keeps (forIn l init f) := by
  induction l generalizing init with
  | nil => exact pure' _
  | cons a as ih =>
    simp only [List.forIn_cons]
    refine bind (hf a init) fun r => ?_
    cases r with
    | done s => exact pure' _
    | yield s => exact ih s

theorem forIn_array {σ : Type} (xs : Array β) (init : σ) (f : β → σ → Check (ForInStep σ))
    (hf : ∀ a s, Keeps (f a s)) : Keeps (forIn xs init f) := by
  rw [← Array.forIn_toList]; exact forIn_list _ _ _ hf

/-- Walk a do-block that never writes the state. -/
macro "keeps" : tactic => `(tactic| repeat (first
  | exact Keeps.pure' _
  | exact Keeps.fail' _
  | (refine Keeps.bind ?_ (fun _ => ?_))
  | (refine Keeps.forIn_array _ _ _ (fun _ _ => ?_))
  | (refine Keeps.forIn_list _ _ _ (fun _ _ => ?_))
  | split))

theorem discard {x : Check β} (h : Keeps x) : Keeps (discard x) := by
  intro st b st' hx
  change (x st >>= fun r => pure (PUnit.unit, r.2)) = _ at hx
  cases hxs : x st with
  | error e => rw [hxs] at hx; cases hx
  | ok r => rw [hxs] at hx; cases hx; exact h st r.1 r.2 hxs

end Keeps

theorem fields_keeps (v : Json.Value) (req opt : List String) : Keeps (fields v req opt) := by
  unfold fields; keeps

theorem asString_keeps (v : Json.Value) : Keeps (asString v) := by
  unfold asString; keeps

theorem number_keeps (v : Json.Value) : Keeps (number v) := by
  unfold number; keeps

theorem unitOf_keeps (v : Json.Value) : Keeps (unitOf v) := by
  unfold unitOf
  refine Keeps.bind (asString_keeps _) fun _ => ?_
  split
  · exact Keeps.pure' _
  · exact Keeps.fail' _


theorem Spec.bind_keeps {β γ} {P : CState → Prop} {Q : γ → CState → Prop} {x : Check β} {f : β → Check γ}
    (hx : Keeps x) (hf : ∀ b, Spec P (f b) Q) : Spec P (x >>= f) Q :=
  Spec.bind (hx.spec P) hf

theorem getElem!_push_lt {β} [Inhabited β] (xs : Array β) (y : β) {i : Nat} (h : i < xs.size) :
    (xs.push y)[i]! = xs[i]! := by
  rw [getElem!_pos (xs.push y) i (by simp; omega), getElem!_pos xs i h, Array.getElem_push_lt]

theorem getElem!_push_eq {β} [Inhabited β] (xs : Array β) (y : β) {n : Nat} (h : xs.size = n) :
    (xs.push y)[n]! = y := by
  subst h; simp

/-- A typing rule: an operator's result type from its arguments' types and its conversion target. -/
abbrev TypeRule := Op → List Ty → Option Dim → Option Ty

/-- Node i is typed by its rule, its parameter declared and its arguments before it. -/
def NodeOK (rule : TypeRule) (nparams : Nat) (punit : Nat → Dim) (nodes : Array Node) (types : Array Ty)
    (convTo : Array (Option Dim)) (i : Nat) : Prop :=
  match nodes[i]! with
  | .input inp => types[i]! = .num inp.unit
  | .const _ u => types[i]! = .num u
  | .param k => k < nparams ∧ types[i]! = .num (punit k)
  | .op o args => (∀ a ∈ args, a < i) ∧ rule o (args.map (types[·]!)) convTo[i]! = some types[i]!

/-- What every checker step keeps: aligned arrays, typed nodes and bindings to existing nodes. -/
structure Inv (rule : TypeRule) (st : CState) : Prop where
  types : st.types.size = st.nodes.size
  convTo : st.convTo.size = st.nodes.size
  nodes : ∀ i < st.nodes.size, NodeOK rule st.params.size (st.params[·]!.2.2) st.nodes st.types st.convTo i
  lets : ∀ x ∈ st.lets, x.2 < st.nodes.size

theorem NodeOK.push {rule : TypeRule} {np np' : Nat} {pu pu' : Nat → Dim} {nodes : Array Node} {types : Array Ty}
    {convTo : Array (Option Dim)} {i : Nat} (n : Node) (t : Ty) (to : Option Dim) (hi : i < nodes.size)
    (ht : types.size = nodes.size) (hc : convTo.size = nodes.size) (hnp : np ≤ np') (hpu : ∀ k < np, pu' k = pu k)
    (h : NodeOK rule np pu nodes types convTo i) :
    NodeOK rule np' pu' (nodes.push n) (types.push t) (convTo.push to) i := by
  unfold NodeOK at *
  rw [getElem!_push_lt _ _ hi, getElem!_push_lt _ _ (ht ▸ hi)]
  split at h
  · exact h
  · exact h
  · exact ⟨by omega, by rw [hpu _ h.1]; exact h.2⟩
  · refine ⟨h.1, ?_⟩
    rw [getElem!_push_lt _ _ (hc ▸ hi), ← h.2]
    congr 1
    exact List.map_congr_left fun a ha => getElem!_push_lt _ _ (by have := h.1 a ha; omega)

theorem NodeOK.params {rule : TypeRule} {np np' : Nat} {pu pu' : Nat → Dim} {nodes : Array Node} {types : Array Ty}
    {convTo : Array (Option Dim)} {i : Nat} (hnp : np ≤ np') (hpu : ∀ k < np, pu' k = pu k)
    (h : NodeOK rule np pu nodes types convTo i) : NodeOK rule np' pu' nodes types convTo i := by
  unfold NodeOK at *
  split at h
  · exact h
  · exact h
  · exact ⟨by omega, by rw [hpu _ h.1]; exact h.2⟩
  · exact h

/-- A property of the checker's state that adding a node or counting a parsed one keeps. -/
def Frame (S : CState → Prop) : Prop :=
  (∀ st n t to, st.types.size = st.nodes.size → S st →
    S { st with nodes := st.nodes.push n, types := st.types.push t, convTo := st.convTo.push to }) ∧
  ∀ st, S st → S { st with parsed := st.parsed + 1 }

theorem Frame.and {S T : CState → Prop} (hS : Frame S) (hT : Frame T) : Frame (fun st => S st ∧ T st) :=
  ⟨fun st n t to h ⟨hs, ht⟩ => ⟨hS.1 st n t to h hs, hT.1 st n t to h ht⟩, fun st ⟨hs, ht⟩ => ⟨hS.2 st hs, hT.2 st ht⟩⟩

theorem Frame.le (k : Nat) : Frame (fun st => k ≤ st.nodes.size) :=
  ⟨fun _ _ _ _ _ h => by simp; omega, fun _ h => h⟩

theorem Frame.typeAt (j : Nat) (t : Ty) : Frame (fun st => j < st.nodes.size ∧ st.types[j]! = t) :=
  ⟨fun _ _ _ _ hs ⟨hj, ht⟩ => ⟨by simp; omega, by simp only; rw [getElem!_push_lt _ _ (by omega)]; exact ht⟩,
   fun _ h => h⟩

/-- The node a step adds at the end is typed by its rule. -/
def NewOK (rule : TypeRule) (st : CState) (n : Node) (t : Ty) (to : Option Dim) : Prop :=
  NodeOK rule st.params.size (st.params[·]!.2.2) (st.nodes.push n) (st.types.push t) (st.convTo.push to) st.nodes.size

theorem intern_spec (rule : TypeRule) (n : Node) (t : Ty) (to : Option Dim) {S : CState → Prop} (hS : Frame S) :
    Spec (fun st => Inv rule st ∧ S st ∧ NewOK rule st n t to) (intern n t to)
      (fun i st => Inv rule st ∧ S st ∧ i < st.nodes.size) := by
  intro st ⟨hI, hS', hn⟩ i st' h
  unfold intern at h
  simp only [bind, StateT.bind, get, getThe, MonadStateOf.get, StateT.get, pure, set, MonadStateOf.set,
    Except.bind, Except.pure] at h
  cases hj : st.nodes.findIdx? (· == n) with
  | some j =>
    simp only [hj, StateT.pure] at h
    obtain ⟨rfl, rfl⟩ := h
    exact ⟨hI, hS', Array.findIdx?_eq_some_iff_getElem.mp hj |>.1⟩
  | none =>
    simp only [hj, StateT.bind, StateT.set, StateT.pure] at h
    obtain ⟨rfl, rfl⟩ := h
    refine ⟨⟨by simp [hI.types], by simp [hI.convTo], fun i hi => ?_, fun x hx => ?_⟩, hS.1 st n t to hI.types hS', by simp⟩
    · simp only [Array.size_push] at hi
      rcases Nat.lt_succ_iff_lt_or_eq.mp hi with hi | rfl
      · exact (hI.nodes i hi).push n t to hi hI.types hI.convTo (Nat.le_refl _) (fun _ _ => rfl)
      · exact hn
    · have := hI.lets x hx; simp; omega


theorem StateT.ite_run {σ : Type} {m : Type → Type} {β : Type} {c : Prop} [Decidable c] (x y : StateT σ m β) (s : σ) :
    (if c then x else y) s = if c then x s else y s := by
  split <;> rfl

theorem Except.ok_eq_bind {ε α β : Type} {x : Except ε α} {f : α → Except ε β} {r : β} :
    .ok r = x.bind f ↔ ∃ a, .ok a = x ∧ .ok r = f a := by
  cases x <;> simp [Except.bind]

theorem eq_ite_iff' {α : Type} {c : Prop} [Decidable c] {a b r : α} :
    r = (if c then a else b) ↔ (c ∧ r = a) ∨ (¬c ∧ r = b) := by
  split <;> simp_all

theorem StateT.discard_run {σ ε β : Type} (x : StateT σ (Except ε) β) (s : σ) :
    discard x s = (x s).bind fun r => .ok (PUnit.unit, r.2) := rfl

set_option hygiene false in
/-- Evaluate a `typeOp` run in hypothesis h, read right to left. -/
macro "tsimp" : tactic => `(tactic| simp [typeOp, bind, StateT.bind, pure, StateT.pure, fail, throw, throwThe,
  MonadExceptOf.throw, StateT.lift, Except.pure, StateT.ite_run, StateT.discard_run, Except.ok_eq_bind, eq_ite_iff',
  and_assoc, exists_and_left, exists_eq_left, Functor.map, Except.map] at h)

/-- typeOp agrees with the rule wherever the arguments match the operator's arity. -/
def TypeOpSound (rule : TypeRule) : Prop :=
  ∀ name op arity ts kvs, (name, op, arity) ∈ ops → ts.length = arity → ∀ st op' ty st',
    typeOp op ts kvs st = .ok ((op', ty), st') →
    st' = st ∧ rule op' ts (match (generalizing := false) op', ty with | .convert _, .num u => some u | _, _ => none) = some ty

theorem Spec.fail_bind {β γ} {P : CState → Prop} {Q : γ → CState → Prop} {c : Code} {f : β → Check γ} :
    Spec P (fail c >>= f) Q := by
  intro st _ b st' h; cases h

theorem Spec.get_bind {γ} {P : CState → Prop} {Q : γ → CState → Prop} {f : CState → Check γ}
    (h : ∀ s, Spec (fun st => P st ∧ st = s) (f s) Q) : Spec P (get >>= f) Q := by
  intro st hp b st' hx; exact h st st ⟨hp, rfl⟩ b st' hx

theorem Spec.intro {β} {P : CState → Prop} {Q : β → CState → Prop} {x : Check β}
    (h : ∀ s, P s → Spec (· = s) x Q) : Spec P x Q := by
  intro st hp b st' hx; exact h st hp st rfl b st' hx

/-- A loop that always continues, with an invariant indexed by the elements still to come. -/
theorem Spec.forIn_yield {β σ} (l : List β) (init : σ) (f : β → σ → Check (ForInStep σ))
    (I : List β → σ → CState → Prop)
    (hf : ∀ a rest s, Spec (I (a :: rest) s) (f a s) (fun r st => ∃ s', r = .yield s' ∧ I rest s' st)) :
    Spec (I l init) (forIn l init f) (I []) := by
  induction l generalizing init with
  | nil => exact Spec.pure' fun _ h => h
  | cons a as ih =>
    simp only [List.forIn_cons]
    refine Spec.bind (hf a as init) fun r => ?_
    intro st ⟨s', hr, hI⟩ b st' hx
    subst hr
    exact ih s' st hI b st' hx

theorem Spec.ite {β} {P : CState → Prop} {Q : β → CState → Prop} {c : Prop} [Decidable c] {x y : Check β}
    (hx : Spec (fun st => P st ∧ c) x Q) (hy : Spec (fun st => P st ∧ ¬c) y Q) : Spec P (if c then x else y) Q := by
  split
  · exact fun st hp => hx st ⟨hp, by assumption⟩
  · exact fun st hp => hy st ⟨hp, by assumption⟩

macro "step" : tactic => `(tactic| first
  | with_reducible_and_instances exact Spec.fail'
  | with_reducible_and_instances exact Spec.fail_bind
  | with_reducible_and_instances refine Spec.bind_keeps (fields_keeps _ _ _) fun _ => ?_
  | with_reducible_and_instances refine Spec.bind_keeps (asString_keeps _) fun _ => ?_
  | with_reducible_and_instances refine Spec.bind_keeps (Keeps.discard (asString_keeps _)) fun _ => ?_
  | with_reducible_and_instances refine Spec.bind_keeps (number_keeps _) fun _ => ?_
  | with_reducible_and_instances refine Spec.bind_keeps (unitOf_keeps _) fun _ => ?_
  | with_reducible_and_instances refine Spec.get_bind fun _ => ?_
  | with_reducible_and_instances refine Spec.ite ?_ ?_
  | split)

theorem expr_spec (rule : TypeRule) (hrule : TypeOpSound rule) (v : Json.Value) (depth : Nat) {S : CState → Prop} (hS : Frame S) :
    Spec (fun st => Inv rule st ∧ S st) (expr v depth)
      (fun i st => Inv rule st ∧ S st ∧ i < st.nodes.size) := by
  unfold expr
  refine Spec.bind (Spec.modify' (Q := fun _ st => Inv rule st ∧ S st)
    fun st h => ⟨⟨h.1.1, h.1.2, h.1.3, h.1.4⟩, hS.2 st h.2⟩) fun _ => ?_
  split
  · exact Spec.fail'
  rename_i hd
  dsimp only
  repeat' step
  · refine (intern_spec rule _ _ _ hS).conseq (fun st hp => ?_) (fun _ _ h => h)
    simp only [and_assoc] at hp
    obtain ⟨hI, hst, -⟩ := hp
    refine ⟨hI, hst, ?_⟩
    simp [NewOK, NodeOK, getElem!_push_eq _ _ hI.types]
  · refine (intern_spec rule _ _ _ hS).conseq (fun st hp => ?_) (fun _ _ h => h)
    simp only [and_assoc] at hp
    obtain ⟨hI, hst, -⟩ := hp
    refine ⟨hI, hst, ?_⟩
    simp [NewOK, NodeOK, getElem!_push_eq _ _ hI.types]
  · rename_i hf _
    refine (intern_spec rule _ _ _ hS).conseq (fun st hp => ?_) (fun _ _ h => h)
    simp only [and_assoc] at hp
    obtain ⟨hI, hst, -, -, -, -, -, rfl, rfl⟩ := hp
    refine ⟨hI, hst, ?_⟩
    simp only [NewOK, NodeOK, getElem!_push_eq _ _ rfl, getElem!_push_eq _ _ hI.types]
    exact ⟨(Array.findIdx?_eq_some_iff_getElem.mp hf).1, trivial⟩
  · rename_i hl
    refine Spec.pure' fun st hp => ?_
    simp only [and_assoc] at hp
    obtain ⟨hI, hst, -, -, -, -, -, -, rfl⟩ := hp
    exact ⟨hI, hst, hI.lets _ (Array.mem_of_find?_eq_some hl)⟩
  · rename_i op arity hfind kvs' _ args _
    refine Spec.bind (R := fun ix st => Inv rule st ∧ S st ∧ (∀ j ∈ ix, j < st.nodes.size) ∧
      ix.size = arity) ?_ fun ix => ?_
    · rw [← Array.forIn_toList]
      refine Spec.conseq (Spec.forIn_yield args.toList #[] _ (fun rest ix st => Inv rule st ∧ S st ∧
          (∀ j ∈ ix, j < st.nodes.size) ∧ ix.size + rest.length = arity) fun a rest ix => ?_) ?_ ?_
      · refine Spec.intro fun st0 ⟨_, hS0, hix0, hsz0⟩ => ?_
        refine Spec.bind (Spec.conseq (expr_spec rule hrule a (depth + 1) (hS.and (Frame.le st0.nodes.size)))
          (fun st h => ?_) (fun i st h => h)) fun i => Spec.pure' fun st ⟨hI, ⟨hS', hle⟩, hi⟩ => ?_
        · subst h; exact ⟨‹_›, hS0, Nat.le_refl _⟩
        · refine ⟨_, rfl, hI, hS', fun j hj => ?_, by simp at hsz0 ⊢; omega⟩
          rcases Array.mem_push.mp hj with hj | rfl
          · have := hix0 j hj; omega
          · exact hi
      · intro st hp
        simp only [and_assoc] at hp
        obtain ⟨hI, hst, -, -, -, -, -, -, -, hn⟩ := hp
        refine ⟨hI, hst, by simp, ?_⟩
        simp only [bne_iff_ne, ne_eq, Decidable.not_not] at hn
        simp [hn]
      · intro ix st ⟨hI, hst, hix, hsz⟩
        exact ⟨hI, hst, hix, by simpa using hsz⟩
    · refine Spec.get_bind fun s0 => ?_
      refine Spec.bind (R := fun r st => Inv rule st ∧ S st ∧ (∀ j ∈ ix, j < st.nodes.size) ∧
          st = s0 ∧ rule r.1 (ix.toList.map (s0.types[·]!))
            (match r.1, r.2 with | .convert _, .num u => some u | _, _ => none) = some r.2) ?_ fun r => ?_
      · intro st ⟨⟨hI, hst, hix, hsz⟩, hs⟩ r st' h
        obtain ⟨rfl, hr⟩ := hrule _ _ _ _ _ (List.mem_of_find?_eq_some hfind) (by simp [hsz]) st r.1 r.2 st' h
        exact ⟨hI, hst, hix, hs, hr⟩
      · refine (intern_spec rule _ _ _ hS).conseq (fun st ⟨hI, hst, hix, hs, hr⟩ => ⟨hI, hst, ?_⟩) (fun _ _ h => h)
        subst hs
        simp only [NewOK, NodeOK, getElem!_push_eq _ _ rfl, getElem!_push_eq _ _ hI.types,
          getElem!_push_eq _ _ hI.convTo]
        refine ⟨fun a ha => hix a (by simpa using ha), ?_⟩
        rw [← hr]
        congr 1
        exact List.map_congr_left fun a ha => getElem!_push_lt _ _ (by rw [hI.types]; exact hix a (by simpa using ha))
termination_by maxDepth + 1 - depth


theorem Frame.of {s : CState} {j : Nat} {t : Ty} (_ : s.types[j]! = t) :
    Frame (fun st => j < st.nodes.size ∧ st.types[j]! = t) := Frame.typeAt j t

theorem Frame.true : Frame (fun _ => True) := ⟨fun _ _ _ _ _ _ => trivial, fun _ _ => trivial⟩

theorem Inv.pushParam {rule : TypeRule} {st : CState} (x : String × UInt64 × Dim) (h : Inv rule st) :
    Inv rule { st with params := st.params.push x } :=
  ⟨h.types, h.convTo, fun i hi => (h.nodes i hi).params (by simp) fun k hk => by
    simp only; rw [getElem!_push_lt _ _ hk], h.lets⟩

theorem Inv.pushLet {rule : TypeRule} {st : CState} (name : String) {i : Nat} (h : Inv rule st) (hi : i < st.nodes.size) :
    Inv rule { st with lets := st.lets.push (name, i) } :=
  ⟨h.types, h.convTo, h.nodes, fun x hx => by
    rcases Array.mem_push.mp hx with hx | rfl
    · exact h.lets x hx
    · exact hi⟩

theorem Spec.pure_bind {β γ : Type} {P : CState → Prop} {Q : γ → CState → Prop} {b : β} {f : β → Check γ}
    (h : Spec P (f b) Q) : Spec P (pure b >>= f) Q := h

/-- A loop that keeps the invariant, then the rest. -/
theorem Spec.loop {β σ γ : Type} {rule : TypeRule} {P : CState → Prop} {Q : γ → CState → Prop} {xs : Array β} {init : σ}
    {f : β → σ → Check (ForInStep σ)} {g : σ → Check γ} (hP : ∀ st, P st → Inv rule st)
    (hf : ∀ a ∈ xs, ∀ s, Spec (Inv rule) (f a s) (fun _ => Inv rule)) (hg : ∀ s, Spec (Inv rule) (g s) Q) :
    Spec P (forIn xs init f >>= g) Q :=
  Spec.bind (Spec.conseq (Spec.forIn_array xs init f (fun _ => Inv rule) hf) hP (fun _ _ h => h)) hg

set_option hygiene false in
/-- The invariant out of a precondition that conjoins it with branch facts. -/
macro "inv_of" : tactic => `(tactic| first | exact h | exact h.1 | exact h.1.1 | exact h.1.1.1)

set_option hygiene false in
/-- `step`, the program's loops over parameters and bindings, and expressions under any frame. -/
macro "pstep" : tactic => `(tactic| first
  | step
  | with_reducible_and_instances refine Spec.loop (rule := rule) (fun st h => ?_) (fun _ _ _ => ?_) (fun _ => ?_)
  | with_reducible_and_instances refine Spec.bind (Spec.modify' (Q := fun _ st => Inv rule st)
      fun st h => Inv.pushParam _ h) fun _ => ?_
  | with_reducible_and_instances refine Spec.bind (Spec.modify' (Q := fun _ st => Inv rule st)
      fun st h => Inv.pushLet _ h.1 h.2.2) fun _ => ?_
  | with_reducible_and_instances exact Spec.pure' (b := ForInStep.yield _) fun _ h => h
  | with_reducible_and_instances refine Spec.pure_bind ?_
  | with_reducible_and_instances refine Spec.bind (Spec.conseq (expr_spec rule hrule (Prod.snd _) 1 Frame.true)
      (fun st h => ⟨?_, trivial⟩) (fun _ _ h => h)) fun _ => ?_
  | with_reducible_and_instances refine Spec.bind (Spec.conseq (expr_spec rule hrule (field _ "weight") 1 Frame.true)
      (fun st h => ⟨?_, trivial⟩) (fun _ _ h => h)) fun _ => ?_)

set_option maxHeartbeats 4000000 in
theorem program_spec (rule : TypeRule) (hrule : TypeOpSound rule) (v : Json.Value) :
    Spec (Inv rule) (program v) (fun p st => Inv rule st ∧ p.nodes = st.nodes ∧ p.types = st.types ∧
      p.convTo = st.convTo ∧ p.params = st.params.map (·.2) ∧ p.weight < st.nodes.size ∧
      st.types[p.weight]! = .num Dim.one ∧ ∀ q, p.prediction = some q → q < st.nodes.size ∧ st.types[q]! = .bool) := by
  unfold program
  dsimp only
  repeat' pstep
  all_goals try inv_of
  all_goals first
    | refine Spec.pure' fun st h => ?_
      simp only [and_assoc] at h
      obtain ⟨hI, -, hw, rfl, hu, rfl⟩ := h
      simp only [bne_iff_ne, ne_eq, Decidable.not_not] at hu
      subst hu
      exact ⟨hI, rfl, rfl, rfl, rfl, hw, ‹(_ : CState).types[_]! = _›, by simp⟩
    | refine Spec.intro fun st0 h0 => ?_
      simp only [and_assoc] at h0
      obtain ⟨hI0, -, hw0, rfl, hu⟩ := h0
      simp only [bne_iff_ne, ne_eq, Decidable.not_not] at hu
      subst hu
      refine Spec.bind (Spec.conseq (expr_spec rule hrule _ 1 (Frame.of ‹(_ : CState).types[_]! = Ty.num Dim.one›))
        (fun st h => by subst h; exact ⟨hI0, hw0, ‹_›⟩) (fun _ _ h => h)) fun c => ?_
      refine Spec.get_bind fun s => Spec.ite Spec.fail_bind (Spec.pure_bind (Spec.get_bind fun s' => ?_))
      refine Spec.pure' fun st h => ?_
      simp only [and_assoc] at h
      obtain ⟨hI, hw, hty, hc, rfl, hb, rfl⟩ := h
      simp only [bne_iff_ne, ne_eq, Decidable.not_not] at hb
      exact ⟨hI, rfl, rfl, rfl, rfl, hw, hty, fun q hq => by cases hq; exact ⟨hc, hb⟩⟩

/-- A program the checker accepts satisfies the well-formedness clauses under any rule `typeOp` agrees with. -/
theorem check_wf (rule : TypeRule) (hrule : TypeOpSound rule) {text : String} {p : Program} (h : check text = .ok p) :
    p.types.size = p.nodes.size ∧ p.convTo.size = p.nodes.size ∧ p.weight < p.nodes.size ∧
    p.types[p.weight]! = .num Dim.one ∧ (∀ q, p.prediction = some q → q < p.nodes.size ∧ p.types[q]! = .bool) ∧
    ∀ i < p.nodes.size, NodeOK rule p.params.size (p.params[·]!.2) p.nodes p.types p.convTo i := by
  unfold check at h
  split at h
  · cases h
  split at h
  · cases h
  rename_i v _
  split at h
  · rename_i r st hr
    cases h
    have hI0 : Inv rule {} := ⟨rfl, rfl, fun _ h => by simp at h, fun _ h => by simp at h⟩
    obtain ⟨hI, hn, ht, hc, hp, hw, hty, hpred⟩ := program_spec rule hrule v {} hI0 _ _ hr
    rw [hn, ht, hc, hp]
    refine ⟨hI.types, hI.convTo, hw, hty, hpred, fun i hi => (hI.nodes i hi).params (by simp) fun k hk => ?_⟩
    rw [getElem!_pos _ k (by simpa using hk), getElem!_pos _ k hk, Array.getElem_map]
  · cases h

end Ref
