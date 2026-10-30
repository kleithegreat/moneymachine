import Ref.Proof.Checker.Inv
import Ref.Proof.Checker.TypeOp

/-! Expressions the checker accepts keep the invariant. -/

namespace Ref

variable {ok : Input → Prop}

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

theorem expr_spec (v : Json.Value) (depth : Nat) {S : CState → Prop} (hS : Frame S) :
    Spec (fun st => Inv ok st ∧ S st) (expr v depth)
      (fun i st => Inv ok st ∧ S st ∧ i < st.nodes.size) := by
  unfold expr
  refine Spec.bind (Spec.modify' (Q := fun _ st => Inv ok st ∧ S st)
    fun st h => ⟨⟨h.1.1, h.1.2, h.1.3, h.1.4, h.1.5⟩, hS.2 st h.2⟩) fun _ => ?_
  split
  · exact Spec.fail'
  rename_i hd
  dsimp only
  repeat' step
  · refine (intern_spec _ _ _ hS).conseq (fun st hp => ?_) (fun _ _ h => h)
    simp only [and_assoc] at hp
    obtain ⟨hI, hst, hx⟩ := hp
    refine ⟨hI, hst, ?_⟩
    simp only [NewOK, NodeOK, getElem!_push_eq _ _ rfl, getElem!_push_eq _ _ hI.types]
    obtain ⟨-, -, -, rfl⟩ := hx
    exact ⟨hI.inputs _ (Array.mem_of_find?_eq_some ‹_›), trivial⟩
  · refine (intern_spec _ _ _ hS).conseq (fun st hp => ?_) (fun _ _ h => h)
    simp only [and_assoc] at hp
    obtain ⟨hI, hst, -⟩ := hp
    refine ⟨hI, hst, ?_⟩
    simp [NewOK, NodeOK, getElem!_push_eq _ _ hI.types]
  · rename_i hf _
    refine (intern_spec _ _ _ hS).conseq (fun st hp => ?_) (fun _ _ h => h)
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
    refine Spec.bind (R := fun ix st => Inv ok st ∧ S st ∧ (∀ j ∈ ix, j < st.nodes.size) ∧
      ix.size = arity) ?_ fun ix => ?_
    · rw [← Array.forIn_toList]
      refine Spec.conseq (Spec.forIn_yield args.toList #[] _ (fun rest ix st => Inv ok st ∧ S st ∧
          (∀ j ∈ ix, j < st.nodes.size) ∧ ix.size + rest.length = arity) fun a rest ix => ?_) ?_ ?_
      · refine Spec.intro fun st0 ⟨_, hS0, hix0, hsz0⟩ => ?_
        refine Spec.bind (Spec.conseq (expr_spec a (depth + 1) (hS.and (Frame.le st0.nodes.size)))
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
      refine Spec.bind (R := fun r st => Inv ok st ∧ S st ∧ (∀ j ∈ ix, j < st.nodes.size) ∧
          st = s0 ∧ opTy r.1 (ix.toList.map (s0.types[·]!))
            (match r.1, r.2 with | .convert _, .num u => some u | _, _ => none) = some r.2) ?_ fun r => ?_
      · intro st ⟨⟨hI, hst, hix, hsz⟩, hs⟩ r st' h
        obtain ⟨rfl, hr⟩ := typeOp_sound _ _ _ _ _ (List.mem_of_find?_eq_some hfind) (by simp [hsz]) st r.1 r.2 st' h
        exact ⟨hI, hst, hix, hs, hr⟩
      · refine (intern_spec _ _ _ hS).conseq (fun st ⟨hI, hst, hix, hs, hr⟩ => ⟨hI, hst, ?_⟩) (fun _ _ h => h)
        subst hs
        simp only [NewOK, NodeOK, getElem!_push_eq _ _ rfl, getElem!_push_eq _ _ hI.types,
          getElem!_push_eq _ _ hI.convTo]
        refine ⟨fun a ha => hix a (by simpa using ha), ?_⟩
        rw [← hr]
        congr 1
        exact List.map_congr_left fun a ha => getElem!_push_lt _ _ (by rw [hI.types]; exact hix a (by simpa using ha))
termination_by maxDepth + 1 - depth

end Ref
