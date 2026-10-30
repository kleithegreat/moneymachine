import Ref.Proof.Checker.Expr

/-! What the checker's accepted programs satisfy: the parts (`Checker/`) assemble into the well-formedness of
`check` (L2's checker half). -/

namespace Ref

variable {ok : Input → Prop}

theorem Frame.of {s : CState} {j : Nat} {t : Ty} (_ : s.types[j]! = t) :
    Frame (fun st => j < st.nodes.size ∧ st.types[j]! = t) := Frame.typeAt j t

theorem Frame.true : Frame (fun _ => True) := ⟨fun _ _ _ _ _ _ => trivial, fun _ _ => trivial⟩

theorem Inv.pushParam {st : CState} (x : String × UInt64 × Dim) (h : Inv ok st) :
    Inv ok { st with params := st.params.push x } :=
  ⟨h.types, h.convTo, fun i hi => (h.nodes i hi).params (by simp) fun k hk => by
    simp only; rw [getElem!_push_lt _ _ hk], h.lets, h.inputs⟩

theorem Inv.pushLet {st : CState} (name : String) {i : Nat} (h : Inv ok st) (hi : i < st.nodes.size) :
    Inv ok { st with lets := st.lets.push (name, i) } :=
  ⟨h.types, h.convTo, h.nodes, fun x hx => by
    rcases Array.mem_push.mp hx with hx | rfl
    · exact h.lets x hx
    · exact hi, h.inputs⟩

theorem Spec.pure_bind {β γ : Type} {P : CState → Prop} {Q : γ → CState → Prop} {b : β} {f : β → Check γ}
    (h : Spec P (f b) Q) : Spec P (pure b >>= f) Q := h

/-- A loop that keeps the invariant, then the rest. -/
theorem Spec.loop {β σ γ : Type} {P : CState → Prop} {Q : γ → CState → Prop} {xs : Array β} {init : σ}
    {f : β → σ → Check (ForInStep σ)} {g : σ → Check γ} (hP : ∀ st, P st → Inv ok st)
    (hf : ∀ a ∈ xs, ∀ s, Spec (Inv ok) (f a s) (fun _ => Inv ok)) (hg : ∀ s, Spec (Inv ok) (g s) Q) :
    Spec P (forIn xs init f >>= g) Q :=
  Spec.bind (Spec.conseq (Spec.forIn_array xs init f (fun _ => Inv ok) hf) hP (fun _ _ h => h)) hg

set_option hygiene false in
/-- The invariant out of a precondition that conjoins it with branch facts. -/
macro "inv_of" : tactic => `(tactic| first | exact h | exact h.1 | exact h.1.1 | exact h.1.1.1)

set_option hygiene false in
/-- `step`, the program's loops over parameters and bindings, and expressions under any frame. -/
macro "pstep" : tactic => `(tactic| first
  | step
  | with_reducible_and_instances refine Spec.loop (ok := ok) (fun st h => ?_) (fun _ _ _ => ?_) (fun _ => ?_)
  | with_reducible_and_instances refine Spec.bind (Spec.modify' (Q := fun _ st => Inv ok st)
      fun st h => Inv.pushParam _ h) fun _ => ?_
  | with_reducible_and_instances refine Spec.bind (Spec.modify' (Q := fun _ st => Inv ok st)
      fun st h => Inv.pushLet _ h.1 h.2.2) fun _ => ?_
  | with_reducible_and_instances exact Spec.pure' (b := ForInStep.yield _) fun _ h => h
  | with_reducible_and_instances refine Spec.pure_bind ?_
  | (fail_if_success have := ‹(_ : CState).types[_]! = Ty.num _›)
    with_reducible_and_instances refine Spec.bind (Spec.conseq (expr_spec (ok := ok) _ 1 Frame.true)
      (fun st h => ⟨?_, trivial⟩) (fun _ _ h => h)) fun _ => ?_)

theorem program_spec (v : Json.Value) :
    Spec (Inv ok) (program v) (fun p st => Inv ok st ∧ p.nodes = st.nodes ∧ p.types = st.types ∧
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
      refine Spec.bind (Spec.conseq (expr_spec (ok := ok) _ 1 (Frame.of ‹(_ : CState).types[_]! = Ty.num Dim.one›))
        (fun st h => by subst h; exact ⟨hI0, hw0, ‹_›⟩) (fun _ _ h => h)) fun c => ?_
      refine Spec.get_bind fun s => Spec.ite Spec.fail_bind (Spec.pure_bind (Spec.get_bind fun s' => ?_))
      refine Spec.pure' fun st h => ?_
      simp only [and_assoc] at h
      obtain ⟨hI, hw, hty, hc, rfl, hb, rfl⟩ := h
      simp only [bne_iff_ne, ne_eq, Decidable.not_not] at hb
      exact ⟨hI, rfl, rfl, rfl, rfl, hw, hty, fun q hq => by cases hq; exact ⟨hc, hb⟩⟩

/-- Every entry of a registry's input table is an input the registry declares. -/
theorem inputs_ok (reg : Registry) : ∀ x ∈ reg.inputs, InputOK reg x.2 := by
  intro x hx
  simp only [Registry.inputs, Array.mem_flatMap, Array.mem_map, Array.mem_range] at hx
  obtain ⟨s, hs, k, hk, rfl⟩ := hx
  exact ⟨hs, hk, rfl, rfl⟩

/-- The checker's programs are well-formed against the registry whose input table it was given. -/
theorem check_wf {reg : Registry} {text : String} {p : Program} (h : check reg.inputs text = .ok p) : p.WF reg := by
  unfold check at h
  split at h
  · cases h
  split at h
  · cases h
  rename_i v _
  split at h
  · rename_i r st hr
    cases h
    have hI0 : Inv (InputOK reg) { inputs := reg.inputs } :=
      ⟨rfl, rfl, fun _ h => by simp at h, fun _ h => by simp at h, inputs_ok reg⟩
    obtain ⟨hI, hn, ht, hc, hp, hw, hty, hpred⟩ := program_spec v { inputs := reg.inputs } hI0 _ _ hr
    unfold Program.WF
    rw [hn, ht, hc, hp]
    refine ⟨hI.types, hI.convTo, hw, hty, hpred, fun i hi => (hI.nodes i hi).params (by simp) fun k hk => ?_⟩
    rw [getElem!_pos _ k (by simpa using hk), getElem!_pos _ k hk, Array.getElem_map]
  · cases h

end Ref
