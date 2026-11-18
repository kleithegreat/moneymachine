import Engine.StartProofs
import Engine.Lang.RewriteLaw

/-!
# Step 5's laws over every program (B3, L2, L3, N1; kernel A17, A5, A6)

The universal halves of `L2_units`, `L3_rewrite` and `N1_renaming`, restated over both arrays and the slots' wishes,
and `X1`'s second conjunct: the wishes are a function of the `when` values, the rationals the crossings give and the
tick's exact inputs.
-/

namespace Engine.Lang

variable {α : Type}

/-- B3 L2, units: erasure preserves both arrays; defined float/bool and exact values have their checked sort and
unit. -/
theorem L2_units_universal {α : Type} :
    ∀ (N : NumOps α) (p : Program), p.WF → ∀ (coins : Nat) (ts : List (Tick α)),
      ∃ m : UMach α,
        ts.foldlM (fun acc t => UMach.step N p t acc) (UMach.init N p coins) = .ok m ∧
        m.erase = Mach.run N p coins ts ∧
         (∀ i, i < p.nodes.size → ∀ c x ty, m.tagged i c = some (x, ty) →
           ty = p.types[i]! ∧ (∀ u, ty ≠ Ty.exact u) ∧
             (ty = Ty.bool → ∃ b, x = N.truth b)) ∧
         (∀ i c x u, m.exactTagged i c = some (x, u) →
           p.types[i]? = some (.exact u) ∧ m.erase.exacts[i]![c]! = some x) ∧
         (∀ i c x, m.erase.exacts[i]![c]! = some x →
            ∃ u, m.exactTagged i c = some (x, u)) :=
  fun N _ hwf coins ts => l2_units N hwf coins ts

/-- Two programs that step alike, with the same slots and types, wish alike. -/
theorem slotEval_wishes_prog (N : NumOps α) {p p' : Program} (hs : p'.slots = p.slots) (ht : p'.types = p.types)
    (hstep : ∀ (t : Tick α) (m : Mach α), Mach.step N p' t m = Mach.step N p t m) (coins : Nat) (t : Tick α)
    (m : Mach α) : (slotEval N p' coins t m).wishes = (slotEval N p coins t m).wishes := by
  simp only [slotEval, hstep t m, hs, ht]

/-- B3 L3: rewrites preserve vals AND exacts at corresponding nodes and probes, and the wishes sent at every tick.
Float matches need NumOps.Lawful; an exact match needs no such premise. -/
theorem L3_rewrite_universal {α : Type} :
     ∀ (N : NumOps α) (r : Rule) (p p' : Program) (i : Nat),
       (N.Lawful ∨ ∃ u, p.types[i]? = some (.exact u)) → p.WF → r.apply p i = some p' →
      ∀ (coins : Nat) (ts : List (Tick α)),
        p'.WF ∧
        (∀ k, k < p.nodes.size →
           (Mach.run N p' coins ts).vals[r.corr i k]! = (Mach.run N p coins ts).vals[k]! ∧
           (Mach.run N p' coins ts).exacts[r.corr i k]! = (Mach.run N p coins ts).exacts[k]!) ∧
        (∀ j, j < p.probeNodes.size →
           (Mach.run N p' coins ts).vals[p'.probeNodes[j]!]! = (Mach.run N p coins ts).vals[p.probeNodes[j]!]! ∧
            (Mach.run N p' coins ts).exacts[p'.probeNodes[j]!]! = (Mach.run N p coins ts).exacts[p.probeNodes[j]!]!) ∧
        (∀ t : Tick α,
          (slotEval N p' coins t (Mach.run N p' coins ts)).wishes =
            (slotEval N p coins t (Mach.run N p coins ts)).wishes) := by
  intro N r p p' i hLE hwf happ coins ts
  obtain ⟨hwf', hslots, htypes, hstep, hrun, hprobe⟩ := rewrite_sound N r hLE hwf happ
  refine ⟨hwf', fun k _ => ?_, hprobe coins ts, fun t => ?_⟩
  · simp only [Rule.corr]
    rw [hrun coins ts]
    exact ⟨rfl, rfl⟩
  · rw [hrun coins ts]
    exact slotEval_wishes_prog N hslots htypes hstep coins t _

open Engine.Lang Engine.Machine in
/-- B3 N1: a consistent renaming of the declared sources, in the program and in the header, with equal
exact inputs at corresponding ticks, leaves the preflight, both arrays and wishes unchanged. -/
theorem N1_renaming_universal {α : Type} :
    ∀ (names : List String) (ρ : String → String),
      (∀ s ∈ names, ∀ s' ∈ names, ρ s = ρ s' → s = s') →
      (∀ s ∈ names, validName (ρ s) = true ∧ ρ s ∉ inputNames) →
      ∀ (N : NumOps α) (p : Program) (cfg : Config), p.WF →
        (∀ d ∈ p.declared, d.1 ∈ names) → (∀ s ∈ p.sourceNames, s ∈ names) →
        (∀ o ∈ cfg.observations, o.name ∈ names) →
        ∀ (coins : Nat) (ts ts' : List (Tick α)),
          ts'.length = ts.length →
          (∀ (i : Nat) (t t' : Tick α), ts[i]? = some t → ts'[i]? = some t' →
             t'.inView = t.inView ∧ t'.time = t.time ∧ t'.exactInput = t.exactInput ∧
              ∀ c s, s ∈ p.sourceNames → t'.input c (ρ s) = t.input c s) →
          (p.rename ρ).WF ∧
          bind (p.rename ρ) (cfg.rename ρ) = bind p cfg ∧
           (Mach.run N (p.rename ρ) coins ts').vals = (Mach.run N p coins ts).vals ∧
            (Mach.run N (p.rename ρ) coins ts').exacts = (Mach.run N p coins ts).exacts ∧
           (∀ (t t' : Tick α),
             t'.inView = t.inView → t'.time = t.time → t'.exactInput = t.exactInput →
             (∀ c s, s ∈ p.sourceNames → t'.input c (ρ s) = t.input c s) →
             (slotEval N (p.rename ρ) coins t' (Mach.run N (p.rename ρ) coins ts')).wishes =
               (slotEval N p coins t (Mach.run N p coins ts)).wishes) := by
  intro names ρ hinj _ N p cfg hwf hd hs ho coins ts ts' hlen hrel
  have hin : ∀ (t t' : Tick α), (∀ c s, s ∈ p.sourceNames → t'.input c (ρ s) = t.input c s) →
      ∀ name u, Node.source name u ∈ p.nodes.toList → ∀ c, t'.input c (ρ name) = t.input c name := by
    intro t t' hi name u hmem c
    refine hi c name ?_
    simp only [Program.sourceNames, List.mem_filterMap]
    exact ⟨.source name u, hmem, rfl⟩
  have hrun := run_rename N ρ p coins ts ts' hlen (fun i t t' h1 h2 => by
    obtain ⟨hv, _, hx, hi⟩ := hrel i t t' h1 h2
    exact ⟨hv, hx, hin t t' hi⟩)
  refine ⟨wf_rename ρ hwf, bind_rename ρ names hinj p cfg hd ho, by rw [hrun], by rw [hrun], ?_⟩
  intro t t' hv _ hx hi
  rw [hrun]
  have hstep := step_rename N ρ p t t' hv hx (hin t t' hi) (Mach.run N p coins ts)
  have hs : (p.rename ρ).slots = p.slots := rfl
  have ht : (p.rename ρ).types = p.types := rfl
  simp only [slotEval, hstep, hv, hs, ht]

theorem mem_exactValues (N : NumOps α) (p : Program) (coins : Nat) (t : Tick α) (m : Mach α) {c j : Nat}
    {v : Option Rat} :
    (c, j, v) ∈ (slotEval N p coins t m).exactValues ↔
      j < p.nodes.size ∧ (p.nodes[j]!).isToExact = true ∧ c < coins ∧ v = ((Mach.step N p t m).exacts[j]!)[c]! := by
  simp only [slotEval, List.mem_flatMap, List.mem_filter, List.mem_range, List.mem_map, Prod.mk.injEq]
  constructor
  · rintro ⟨j', ⟨hj, hf⟩, c', hc, rfl, rfl, rfl⟩
    exact ⟨hj, hf, hc, rfl⟩
  · rintro ⟨hj, hf, hc, rfl⟩
    exact ⟨j, ⟨hj, hf⟩, c, hc, rfl, rfl, rfl⟩

theorem mem_whenValues (N : NumOps α) (p : Program) (coins : Nat) (t : Tick α) (m : Mach α) {c i : Nat}
    {v : Option Bool} :
    (c, i, v) ∈ (slotEval N p coins t m).whenValues ↔
      c < coins ∧ i < p.slots.size ∧ v = (Mach.step N p t m).whenAt N c p.slots[i]! := by
  simp only [slotEval, List.mem_flatMap, List.mem_range, List.mem_map, Prod.mk.injEq]
  constructor
  · rintro ⟨c', hc, i', hi, rfl, rfl, rfl⟩
    exact ⟨hc, hi, rfl⟩
  · rintro ⟨hc, hi, rfl⟩
    exact ⟨c, hc, i, hi, rfl, rfl, rfl⟩

theorem evalExactOp_congr (N₁ N₂ : NumOps α) {o : Op} (ho : o ≠ .toExact) (a₁ a₂ : Nat → Option α)
    (E₁ E₂ : Nat → Option Rat) (h0 : E₁ 0 = E₂ 0) (h1 : E₁ 1 = E₂ 1) :
    evalExactOp N₁ o a₁ E₁ = evalExactOp N₂ o a₂ E₂ := by
  cases o <;> simp_all [evalExactOp]

/-- The exact cells of two machines agree wherever the crossings' do: exact nodes read the tick's exact inputs, the
literals and each other. -/
theorem exact_cells_agree {N₁ N₂ : NumOps α} {p : Program} (hwf : p.WF) (coins : Nat) (t : Tick α)
    (m₁ m₂ : Mach α)
    (hcross : ∀ c j, c < coins → j < p.nodes.size → (p.nodes[j]!).isToExact = true →
      ((Mach.step N₁ p t m₁).exacts[j]!)[c]! = ((Mach.step N₂ p t m₂).exacts[j]!)[c]!) :
    ∀ j, j < p.nodes.size → ∀ c, c < coins → c < m₁.coins → c < m₂.coins →
      ((Mach.step N₁ p t m₁).exacts[j]!)[c]! = ((Mach.step N₂ p t m₂).exacts[j]!)[c]! := by
  have hp := wf_ordered hwf
  intro j
  induction j using Nat.strongRecOn with
  | _ j ih =>
    intro hj c hc hc1 hc2
    by_cases hx : (p.nodes[j]!).isToExact = true
    · exact hcross c j hc hj hx
    · rw [(step_row N₁ p t m₁ hp hj).2, (step_row N₂ p t m₂ hp hj).2, exactRow_get, exactRow_get, ite_eq_left hc1,
        ite_eq_left hc2]
      unfold pointExact
      cases hn : p.nodes[j]! with
      | op o args =>
        rw [hn] at hx
        have hno : o ≠ .toExact := fun h => hx (by subst h; rfl)
        have hk : ∀ k : Nat, ((argRow (Mach.step N₁ p t m₁).exacts args k)[c]!) =
            ((argRow (Mach.step N₂ p t m₂).exacts args k)[c]!) := by
          intro k
          unfold argRow
          cases hk : args[k]? with
          | none => rfl
          | some a =>
            have ha := hp j hj a (by rw [hn]; exact List.mem_of_getElem? hk)
            exact ih a ha (by omega) c hc hc1 hc2
        simp only [Node.args, evalExactNode]
        by_cases hv : t.inView c = true
        · simp only [hv, ite_true]
          exact evalExactOp_congr N₁ N₂ hno _ _ _ _ (hk 0) (hk 1)
        · simp [hv]
      | builtin _ => rfl
      | slotIn _ _ => rfl
      | exactConst _ _ => rfl
      | source _ _ => simp [evalExactNode]
      | const _ _ => simp [evalExactNode]

theorem slotOkb_bounds {p : Program} {s : Slot} (h : p.slotOkb s = true) :
    s.when < p.nodes.size ∧ s.price < p.nodes.size ∧ ∀ n, s.size = .target n → n < p.nodes.size := by
  unfold Program.slotOkb at h
  refine ⟨?_, ?_, fun n hn => ?_⟩
  · simp only [Bool.and_eq_true, decide_eq_true_eq] at h
    exact h.1.1.1.1
  · simp only [Bool.and_eq_true, decide_eq_true_eq] at h
    exact h.1.1.2
  · rw [hn] at h
    simp only [Bool.and_eq_true, decide_eq_true_eq] at h
    exact h.2.1

theorem whenAt_coins {N : NumOps α} {p : Program} (hwf : p.WF) (t : Tick α) (m : Mach α) {c : Nat} {s : Slot}
    (hs : p.slotOkb s = true) (h : (Mach.step N p t m).whenAt N c s = some true) : c < m.coins := by
  unfold Mach.whenAt at h
  obtain ⟨x, hx, _⟩ := Option.map_eq_some_iff.1 h
  exact (cell_defined N (wf_ordered hwf) t m (slotOkb_bounds hs).1 hx).1

theorem slotValue_congr (types : Array Ty) (m₁ m₂ : Mach α) (c : Nat) (s : Slot)
    (hp : (m₁.exacts[s.price]!)[c]! = (m₂.exacts[s.price]!)[c]!)
    (hn : ∀ n, s.size = .target n → (m₁.exacts[n]!)[c]! = (m₂.exacts[n]!)[c]!) :
    m₁.slotValue types c s = m₂.slotValue types c s := by
  unfold Mach.slotValue
  rw [hp]
  rcases hsz : s.size with _ | n
  · rfl
  · simp only []
    rw [hn n hsz]

end Engine.Lang

open Engine.Lang in
/-- X1's second conjunct: agreement on all when values and the rationals every exact(·) gives at one tick suffices
for equal wishes under any two NumOps, not agreement on arbitrary float probes. -/
theorem slotEval_wishes_congr :
    ∀ {α : Type} (N₁ N₂ : Engine.Lang.NumOps α) (p : Engine.Lang.Program), p.WF →
      ∀ (coins : Nat) (t : Engine.Lang.Tick α) (m₁ m₂ : Engine.Lang.Mach α),
        let a := Engine.Lang.slotEval N₁ p coins t m₁
        let b := Engine.Lang.slotEval N₂ p coins t m₂
        a.whenValues = b.whenValues → a.exactValues = b.exactValues →
        a.wishes = b.wishes := by
  intro α N₁ N₂ p hwf coins t m₁ m₂ a b hw he
  have hslots := (wf_iff.1 hwf).2.2.2.2
  have hcross : ∀ c j, c < coins → j < p.nodes.size → (p.nodes[j]!).isToExact = true →
      ((Mach.step N₁ p t m₁).exacts[j]!)[c]! = ((Mach.step N₂ p t m₂).exacts[j]!)[c]! := by
    intro c j hc hj hx
    have h1 := (mem_exactValues N₁ p coins t m₁).2 ⟨hj, hx, hc, rfl⟩
    have h1 : (c, j, ((Mach.step N₁ p t m₁).exacts[j]!)[c]!) ∈ b.exactValues := by rw [← he]; exact h1
    exact ((mem_exactValues N₂ p coins t m₂).1 h1).2.2.2
  have hwhen : ∀ c i, c < coins → i < p.slots.size →
      (Mach.step N₁ p t m₁).whenAt N₁ c p.slots[i]! = (Mach.step N₂ p t m₂).whenAt N₂ c p.slots[i]! := by
    intro c i hc hi
    have h1 := (mem_whenValues N₁ p coins t m₁).2 ⟨hc, hi, rfl⟩
    have h1 : (c, i, (Mach.step N₁ p t m₁).whenAt N₁ c p.slots[i]!) ∈ b.whenValues := by rw [← hw]; exact h1
    exact ((mem_whenValues N₂ p coins t m₂).1 h1).2.2
  have hagree := exact_cells_agree (N₁ := N₁) (N₂ := N₂) hwf coins t m₁ m₂ hcross
  show (slotEval N₁ p coins t m₁).wishes = (slotEval N₂ p coins t m₂).wishes
  simp only [slotEval]
  simp only [List.flatMap]
  congr 1
  apply List.map_congr_left
  intro c hc
  have hc' := List.mem_range.1 hc
  by_cases hv : t.inView c = true
  · simp only [hv, ite_true]
    apply List.map_congr_left
    intro i hi
    have hi' := List.mem_range.1 hi
    have hok : p.slotOkb p.slots[i]! = true := by
      have := hslots p.slots[i]! (by rw [Array.mem_toList_iff]; simp [getElem!_pos, hi'])
      exact this
    simp only [Prod.mk.injEq, true_and]
    rw [hwhen c i hc' hi']
    by_cases hw1 : (Mach.step N₂ p t m₂).whenAt N₂ c p.slots[i]! = some true
    · rw [ite_eq_left hw1, ite_eq_left hw1]
      have c2 := whenAt_coins hwf t m₂ hok hw1
      have c1 := whenAt_coins hwf t m₁ hok (by rw [hwhen c i hc' hi']; exact hw1)
      obtain ⟨_, hpr, hsz⟩ := slotOkb_bounds hok
      exact slotValue_congr p.types _ _ c _ (hagree _ hpr c hc' c1 c2) (fun n hn => hagree n (hsz n hn) c hc' c1 c2)
    · rw [ite_eq_right hw1, ite_eq_right hw1]
  · simp [hv]
