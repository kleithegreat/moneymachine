import Engine.STimeTick

/-!
# S1's invariants hold of every run (brief 3 step 5)
-/

namespace Engine.Machine

def S1Inv (c : Core) : Prop := R1Inv c ∧ BInv c ∧ SInv c ∧ TimeInv c

theorem s1_closed : Closed S1Inv where
  arrive := by
    intro s w rest b hS hI hF hP hb hnext hstop
    exact ⟨r1_closed.arrive s w rest b hS hI hF hP.1 hb hnext hstop, binv_arrive s w rest hP.2.1,
      sinv_arrive s w rest hP.2.2.1, timeInv_arrive s w rest hP.2.2.1 hP.2.2.2⟩
  tick := by
    intro s time ms hS hI hF hP hn ht hstop
    exact ⟨r1_closed.tick s time ms hS hI hF hP.1 hn ht hstop, binv_tick s time ms hP.2.1,
      sinv_tick s time ms hP.2.2.1, timeInv_tick s time ms hn hP.2.1 hP.2.2.1 hP.1.2.2 hP.2.2.2⟩
  listing := by
    intro s e rules hS hI hF hP h1 h2
    exact ⟨r1_closed.listing s e rules hS hI hF hP.1 h1 h2, binv_listing s e rules hP.2.1,
      sinv_listing s e rules hP.2.2.1, timeInv_listing s e rules hP.2.2.2⟩
  prev := by
    intro s e hS hI hF hP h1 h2 h3
    exact ⟨r1_closed.prev s e hS hI hF hP.1 h1 h2 h3, binv_prev s e hP.2.1, sinv_prev s e h3 hP.2.2.1,
      timeInv_prev s e hP.2.2.2⟩
  offer := by
    intro s coin slot parts role hS hI hF hP
    exact ⟨r1_closed.offer s coin slot parts role hS hI hF hP.1, binv_offer s coin slot parts role hP.2.1,
      sinv_offer s coin slot parts role hP.2.1 hP.2.2.1, timeInv_offer s coin slot parts role hP.2.1 hP.2.2.1 hP.2.2.2⟩

theorem s1_base {program header : String} {initial : State} (h : start program header = .ok initial) :
    S1Inv (initial.recast Engine.Lang.bitsOps).core := by
  have hr := r1_base h
  obtain ⟨cfg, p, _, _, rfl⟩ := start_shape h
  refine ⟨hr, ⟨?_, ?_, ?_⟩, ⟨?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_⟩, ⟨?_, ?_, ?_, ?_, ?_⟩⟩
  all_goals first
    | (intro l hl; simp [StateOf.core, StateOf.recast, initialState, Log.empty, Log.core] at hl; subst hl; simp)
    | (intro w hw; simp [StateOf.core, StateOf.recast, initialState] at hw)
    | simp [StateOf.core, StateOf.recast, initialState]
  · simp [Shape, World.Acct.initial, Engine.Ledger.initial]
  · simp [Shape, World.Acct.initial, Engine.Ledger.initial]
  · simp [World.Acct.initial] at hw
  · intro k hk K hK
    simp only [StateOf.core, StateOf.recast, initialState, World.Acct.initial] at hk ⊢
    simp [hk, hK]
  · intro k
    exact Nat.le_refl _
  · intro x hx
    simp [StateOf.core, StateOf.recast, initialState] at hx
  · intro w hw
    simp [StateOf.core, StateOf.recast, initialState] at hw

end Engine.Machine
