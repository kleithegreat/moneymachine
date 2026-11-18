import Engine.TInvClauses

/-!
# R1's invariants hold of every run (brief 3 step 5)
-/

namespace Engine.Machine

def R1Inv (c : Core) : Prop := RInv c ∧ AInv c ∧ TInv c

theorem r1_closed : Closed R1Inv where
  arrive := by
    intro s w rest b hS hI hF hP hb hnext hstop
    exact ⟨rinv_arrive s w rest hP.1, ainv_arrive s w rest b hP.1 hP.2.1 hb hnext hstop, tinv_arrive s w rest hP.2.2⟩
  tick := by
    intro s time ms hS hI hF hP hn ht hstop
    exact ⟨rinv_tick s time ms hS hP.1 hn ht, ainv_tick s time ms hS hP.2.1 hn ht,
      tinv_tick s time ms hS hP.1 hP.2.2 hn ht hstop⟩
  listing := by
    intro s e rules hS hI hF hP _ _
    exact ⟨rinv_listing s e rules hP.1, ainv_listing s e rules hP.2.1, tinv_listing s e rules hP.2.2⟩
  prev := by
    intro s e hS hI hF hP _ _
    exact ⟨rinv_prev s e hP.1, ainv_prev s e hP.2.1, tinv_prev s e hP.2.2⟩
  offer := by
    intro s coin slot parts role hS hI hF hP
    exact ⟨rinv_offer s coin slot parts role hP.1, ainv_offer s coin slot parts role hP.2.1,
      tinv_offer s coin slot parts role hP.2.2⟩

theorem r1_base {program header : String} {initial : State} (h : start program header = .ok initial) :
    R1Inv (initial.recast Engine.Lang.bitsOps).core := by
  obtain ⟨cfg, p, _, _, rfl⟩ := start_shape h
  refine ⟨⟨?_, ?_, ?_, ?_, ?_, ?_⟩, ⟨?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_⟩, ⟨?_, ?_, ?_, ?_, ?_⟩⟩
  all_goals first
    | (intro l hl; simp [StateOf.core, StateOf.recast, initialState, Log.empty, Log.core] at hl; subst hl; simp)
    | (intro w hw; simp [StateOf.core, StateOf.recast, initialState] at hw)
    | simp [StateOf.core, StateOf.recast, initialState]
  · intro coin slot a ha
    simp [StateOf.core, StateOf.recast, initialState] at ha
  · intro ms hms
    simp [StateOf.core, StateOf.recast, initialState] at hms
    subst hms
    simp [StateOf.core, StateOf.recast, initialState, firstTick]

end Engine.Machine
