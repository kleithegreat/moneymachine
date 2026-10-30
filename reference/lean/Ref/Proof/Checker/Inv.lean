import Ref.Proof.Checker.Hoare

/-! The invariant every checker step keeps, and the frames it composes with. -/

namespace Ref

variable {ok : Input → Prop}

theorem getElem!_push_lt {β} [Inhabited β] (xs : Array β) (y : β) {i : Nat} (h : i < xs.size) :
    (xs.push y)[i]! = xs[i]! := by
  rw [getElem!_pos (xs.push y) i (by simp; omega), getElem!_pos xs i h, Array.getElem_push_lt]

theorem getElem!_push_eq {β} [Inhabited β] (xs : Array β) (y : β) {n : Nat} (h : xs.size = n) :
    (xs.push y)[n]! = y := by
  subst h; simp

/-- Node i is typed by `opTy`, its parameter declared and its arguments before it. -/
def NodeOK (ok : Input → Prop) (nparams : Nat) (punit : Nat → Dim) (nodes : Array Node) (types : Array Ty)
    (convTo : Array (Option Dim)) (i : Nat) : Prop :=
  match nodes[i]! with
  | .input inp => ok inp ∧ types[i]! = .num inp.unit
  | .const _ u => types[i]! = .num u
  | .param k => k < nparams ∧ types[i]! = .num (punit k)
  | .op o args => (∀ a ∈ args, a < i) ∧ opTy o (args.map (types[·]!)) convTo[i]! = some types[i]!

/-- What every checker step keeps: aligned arrays, typed nodes (inputs among `ok`'s), bindings to existing nodes,
and an input table of `ok` inputs. -/
structure Inv (ok : Input → Prop) (st : CState) : Prop where
  types : st.types.size = st.nodes.size
  convTo : st.convTo.size = st.nodes.size
  nodes : ∀ i < st.nodes.size, NodeOK ok st.params.size (st.params[·]!.2.2) st.nodes st.types st.convTo i
  lets : ∀ x ∈ st.lets, x.2 < st.nodes.size
  inputs : ∀ x ∈ st.inputs, ok x.2

theorem NodeOK.push {np np' : Nat} {pu pu' : Nat → Dim} {nodes : Array Node} {types : Array Ty}
    {convTo : Array (Option Dim)} {i : Nat} (n : Node) (t : Ty) (to : Option Dim) (hi : i < nodes.size)
    (ht : types.size = nodes.size) (hc : convTo.size = nodes.size) (hnp : np ≤ np') (hpu : ∀ k < np, pu' k = pu k)
    (h : NodeOK ok np pu nodes types convTo i) :
    NodeOK ok np' pu' (nodes.push n) (types.push t) (convTo.push to) i := by
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

theorem NodeOK.params {np np' : Nat} {pu pu' : Nat → Dim} {nodes : Array Node} {types : Array Ty}
    {convTo : Array (Option Dim)} {i : Nat} (hnp : np ≤ np') (hpu : ∀ k < np, pu' k = pu k)
    (h : NodeOK ok np pu nodes types convTo i) : NodeOK ok np' pu' nodes types convTo i := by
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

/-- The node a step adds at the end is typed by `opTy`. -/
def NewOK (ok : Input → Prop) (st : CState) (n : Node) (t : Ty) (to : Option Dim) : Prop :=
  NodeOK ok st.params.size (st.params[·]!.2.2) (st.nodes.push n) (st.types.push t) (st.convTo.push to) st.nodes.size

theorem intern_spec (n : Node) (t : Ty) (to : Option Dim) {S : CState → Prop} (hS : Frame S) :
    Spec (fun st => Inv ok st ∧ S st ∧ NewOK ok st n t to) (intern n t to)
      (fun i st => Inv ok st ∧ S st ∧ i < st.nodes.size) := by
  intro st ⟨hI, hS', hn⟩ i st' h
  unfold intern at h
  simp only [bind, StateT.bind, get, getThe, MonadStateOf.get, StateT.get, pure, set, MonadStateOf.set,
    Except.bind, Except.pure] at h
  cases hj : (st.nodes.zip st.convTo).findIdx? (· == (n, to)) with
  | some j =>
    simp only [hj, StateT.pure] at h
    obtain ⟨rfl, rfl⟩ := h
    have := (Array.findIdx?_eq_some_iff_getElem.mp hj).1
    simp only [Array.size_zip] at this
    exact ⟨hI, hS', by omega⟩
  | none =>
    simp only [hj, StateT.bind, StateT.set, StateT.pure] at h
    obtain ⟨rfl, rfl⟩ := h
    refine ⟨⟨by simp [hI.types], by simp [hI.convTo], fun i hi => ?_, fun x hx => ?_, hI.inputs⟩, hS.1 st n t to hI.types hS', by simp⟩
    · simp only [Array.size_push] at hi
      rcases Nat.lt_succ_iff_lt_or_eq.mp hi with hi | rfl
      · exact (hI.nodes i hi).push n t to hi hI.types hI.convTo (Nat.le_refl _) (fun _ _ => rfl)
      · exact hn
    · have := hI.lets x hx; simp; omega

end Ref
