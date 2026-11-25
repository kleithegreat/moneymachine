import Engine.S1Closed

/-!
# S1's universal half, from the invariants of a run's last state (brief 3 step 5)
-/

namespace Engine.Machine

open Engine.Orders (Run CycleStep OrderFill)

/-- The run's last state: the invariants of every run, and its header. -/
theorem s1_final {program header : String} {initial : State} (h : start program header = .ok initial)
    (moves : List Move) (run : Run) (hr : orderRun Engine.Lang.bitsOps initial moves = some run) :
    ∃ (final : State) (l : Log) (rows : Rows), S1Inv final.core ∧ final.cfg = initial.cfg ∧
      final.log = some l ∧ run = l.toRun rows := by
  have hC := s1_closed.and (fixed_closed initial.cfg initial.prog)
  obtain ⟨final, l, rows, hpack, hlog, hrun, _, _, _⟩ :=
    orderRun_pack hC h ⟨s1_base h, fixed_base initial⟩ moves run hr
  obtain ⟨_, _, _, _, ⟨hS, hcfg, _⟩⟩ := hpack
  exact ⟨final, l, rows, hS, hcfg, hlog, hrun⟩

theorem s1_universal {program header : String} {initial : State} (h : start program header = .ok initial)
    (moves : List Move) (run : Run) (hr : orderRun Engine.Lang.bitsOps initial moves = some run) :
    (∀ (i : Nat) (s : CycleStep), run.steps[i]? = some s →
      s.ended = (match s.trigger with
        | .fill coin units =>
          if s.before.position coin ≠ 0 ∧ s.before.position coin + units = 0 then [coin] else []
        | .liquidation => s.before.coins
        | .other => []) ∧
      (∀ coin ∈ s.before.coins,
        s.after.cycle coin = s.before.cycle coin + (if coin ∈ s.ended then 1 else 0)) ∧
      (∀ coin ∈ s.ended,
        s.after.position coin = 0 ∧ s.after.cycle coin = s.before.cycle coin + 1 ∧
        (∀ slot : Nat, s.after.filled coin slot = 0) ∧
        (∀ o ∈ s.after.orders, o.coin ≠ coin) ∧
        (∀ p ∈ run.placed, i ≤ p.step → p.order.coin = coin →
          p.order.cycle ≠ s.before.cycle coin) ∧
        (∀ f ∈ run.fills, i < f.step → f.order.coin = coin →
          f.order.cycle ≠ s.before.cycle coin) ∧
        (∀ p ∈ run.placed, i < p.step → p.order.coin = coin →
          s.before.cycle coin < p.order.cycle →
          s.time + initial.cfg.delta + initial.cfg.lambda ≤ p.order.placed))) ∧
    (∀ f ∈ run.fills,
      let magnitude := if f.units < 0 then -f.units else f.units
      let reducible := match f.order.side with
        | .sell => max 0 (f.before.position f.order.coin)
        | .buy => max 0 (-f.before.position f.order.coin)
      (match f.order.target with
        | some target => f.before.filled f.order.coin f.order.slot + magnitude ≤ target
        | none => magnitude ≤ reducible) ∧
      (f.order.reduceOnly = true → magnitude ≤ reducible)) := by
  obtain ⟨final, l, rows, ⟨_, _, hS, hT⟩, hcfg, hlog, rfl⟩ := s1_final h moves run hr
  have hc : final.core.log = some l.core := by simp [StateOf.core, hlog]
  constructor
  · intro i st hi
    have hmem : st ∈ l.steps := List.mem_of_getElem? hi
    have hg := hS.steps l.core hc st hmem
    refine ⟨hg.1, hg.2.1, fun coin hcoin => ?_⟩
    obtain ⟨g1, g2, g3, g4⟩ := hg.2.2 coin hcoin
    refine ⟨g1, g2, g3, g4, ?_, ?_, ?_⟩
    · intro p hp hip hco
      have hp' : p ∈ l.placed := hp
      obtain ⟨st', hst', hend⟩ := hS.placedOwn l.core hc p hp'
      by_cases hieq : i = p.step
      · subst hieq
        have hh : st = st' := Option.some.inj (hi.symm.trans hst')
        subst hh
        rw [hend] at hcoin
        simp at hcoin
      · have hlt : i < p.step := by omega
        have := hS.placedIdx l.core hc p hp' i st hi hlt
        rw [hco] at this
        omega
    · intro f hf hif hco
      have := hS.fillsIdx l.core hc f hf i st hi hif
      rw [hco] at this
      omega
    · intro p hp hip hco hlt
      have hp' : p ∈ l.placed := hp
      have := hT.pl l.core hc p hp' i st hi hip coin hcoin hco hlt
      show st.time + initial.cfg.delta + initial.cfg.lambda ≤ p.order.placed
      rw [← hcfg]
      exact this
  · intro f hf
    exact hS.fillsGood l.core hc f hf

end Engine.Machine
