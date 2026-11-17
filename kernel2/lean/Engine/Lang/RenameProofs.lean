import Engine.Lang.EvalProofs

/-!
# Renaming a source (B3, N1)

The evaluator reads a declared source by its name and nothing else reads a name, so a consistent renaming of the
program's sources and of the ticks' inputs changes no node's value.
-/

namespace Engine.Lang

variable {α : Type} (N : NumOps α)

theorem nodeFull_tick (t t' : Tick α) (n : Node) (hv : t'.inView = t.inView)
    (he : ∀ c f, evalNode N t' c n f = evalNode N t c n f) (count coins : Nat)
    (argRows : Nat → Array (Option α)) (ns : Array (NS α)) :
    nodeFull N t' n count coins argRows ns = nodeFull N t n count coins argRows ns := by
  have hp : ∀ c, pointVal N t' n argRows c = pointVal N t n argRows c := by
    intro c
    unfold pointVal
    rw [hv, he]
  unfold nodeFull finalize nodeCore
  split <;> simp [hv, hp]

theorem rename_nodes_size (ρ : String → String) (p : Program) : (p.rename ρ).nodes.size = p.nodes.size := by
  simp [Program.rename]

theorem rename_nodes_get (ρ : String → String) (p : Program) {k : Nat} (hk : k < p.nodes.size) :
    (p.rename ρ).nodes[k]! = (p.nodes[k]!).rename ρ := by
  simp [Program.rename, getElem!_pos, hk]

theorem build_rename (ρ : String → String) (p : Program) (t t' : Tick α) (hv : t'.inView = t.inView)
    (hin : ∀ name u, Node.source name u ∈ p.nodes.toList → ∀ c, t'.input c (ρ name) = t.input c name)
    (m : Mach α) {k : Nat} (hk : k ≤ p.nodes.size) :
    build N (p.rename ρ) t' m k = build N p t m k := by
  induction k with
  | zero => rfl
  | succ k ih =>
    have hk' : k < p.nodes.size := hk
    have ih := ih (by omega)
    simp only [build]
    rw [ih, rename_nodes_get ρ p hk']
    have hcore : ∀ (vs : Array (Array (Option α))) (ns : Array (NS α)),
        nodeStep N t' ((p.nodes[k]!).rename ρ) m.count m.coins vs ns = nodeStep N t (p.nodes[k]!) m.count m.coins vs ns := by
      intro vs ns
      have hmem : p.nodes[k]! ∈ p.nodes.toList := by
        simp [getElem!_pos, hk']
      unfold nodeStep
      cases hn : p.nodes[k]! with
      | source name u =>
        rw [hn] at hmem
        have hs := hin name u hmem
        simp only [Node.rename, Node.args]
        have hp : ∀ c argRows, pointVal N t' (Node.source (ρ name) u) argRows c =
            pointVal N t (Node.source name u) argRows c := by
          intro c argRows
          simp [pointVal, hv, evalNode, hs c]
        unfold nodeFull finalize nodeCore
        simp [hp, hv]
      | builtin n => simp only [Node.rename]; exact nodeFull_tick N t t' _ hv (fun c f => by simp [evalNode]) _ _ _ _
      | slotIn n s => simp only [Node.rename]; exact nodeFull_tick N t t' _ hv (fun c f => by simp [evalNode]) _ _ _ _
      | exactConst q u => simp only [Node.rename]; exact nodeFull_tick N t t' _ hv (fun c f => by simp [evalNode]) _ _ _ _
      | const b u => simp only [Node.rename]; exact nodeFull_tick N t t' _ hv (fun c f => by simp [evalNode]) _ _ _ _
      | op o args => simp only [Node.rename]; exact nodeFull_tick N t t' _ hv (fun c f => by simp [evalNode]) _ _ _ _
    rw [hcore]

theorem step_rename (ρ : String → String) (p : Program) (t t' : Tick α) (hv : t'.inView = t.inView)
    (hin : ∀ name u, Node.source name u ∈ p.nodes.toList → ∀ c, t'.input c (ρ name) = t.input c name)
    (m : Mach α) : Mach.step N (p.rename ρ) t' m = Mach.step N p t m := by
  unfold Mach.step
  rw [rename_nodes_size, build_rename N ρ p t t' hv hin m (Nat.le_refl _)]

theorem init_rename (ρ : String → String) (p : Program) (coins : Nat) :
    Mach.init N (p.rename ρ) coins = Mach.init N p coins := by
  unfold Mach.init
  simp only [Program.rename, Array.map_map, Function.comp_def]
  congr 1
  apply Array.map_congr_left
  intro n _
  cases n <;> simp [Node.rename]

theorem run_rename_aux (ρ : String → String) (p : Program) :
    ∀ (ts ts' : List (Tick α)), ts'.length = ts.length →
      (∀ (i : Nat) (t t' : Tick α), ts[i]? = some t → ts'[i]? = some t' → t'.inView = t.inView ∧
        ∀ name u, Node.source name u ∈ p.nodes.toList → ∀ c, t'.input c (ρ name) = t.input c name) →
      ∀ m : Mach α, ts'.foldl (fun m t => Mach.step N (p.rename ρ) t m) m = ts.foldl (fun m t => Mach.step N p t m) m := by
  intro ts
  induction ts with
  | nil =>
    intro ts' hlen _ m
    cases ts' with
    | nil => rw [List.foldl_nil, List.foldl_nil]
    | cons _ _ => simp at hlen
  | cons t ts ih =>
    intro ts' hlen hrel m
    cases ts' with
    | nil => simp at hlen
    | cons t' ts' =>
      obtain ⟨hv, hs⟩ := hrel 0 t t' rfl rfl
      have h1 : Mach.step N (p.rename ρ) t' m = Mach.step N p t m := step_rename N ρ p t t' hv hs m
      have h2 := ih ts' (Nat.succ.inj hlen) (fun i a b ha hb => hrel (i + 1) a b ha hb) (Mach.step N p t m)
      rw [List.foldl_cons, List.foldl_cons, h1]
      exact h2

theorem run_rename (ρ : String → String) (p : Program) (coins : Nat) (ts ts' : List (Tick α))
    (hlen : ts'.length = ts.length)
    (hrel : ∀ (i : Nat) (t t' : Tick α), ts[i]? = some t → ts'[i]? = some t' → t'.inView = t.inView ∧
        ∀ name u, Node.source name u ∈ p.nodes.toList → ∀ c, t'.input c (ρ name) = t.input c name) :
    Mach.run N (p.rename ρ) coins ts' = Mach.run N p coins ts := by
  unfold Mach.run
  rw [init_rename N ρ p coins]
  exact run_rename_aux N ρ p ts ts' hlen hrel _

theorem nodeOkb_rename (ρ : String → String) (p : Program) {i : Nat} (hi : i < p.nodes.size) :
    (p.rename ρ).nodeOkb i = p.nodeOkb i := by
  unfold Program.nodeOkb
  rw [rename_nodes_get ρ p hi]
  cases hn : p.nodes[i]! <;> simp [Node.rename, Program.rename] <;> rfl

theorem wf_rename (ρ : String → String) {p : Program} (h : p.WF) : (p.rename ρ).WF := by
  obtain ⟨h1, h2, h3, h4⟩ := wf_iff.1 h
  refine wf_iff.2 ⟨by simpa [Program.rename] using h1, by simpa [Program.rename] using h2, ?_,
    by simpa [Program.rename, Program.slotOkb] using h4⟩
  intro i hi
  rw [rename_nodes_size] at hi
  rw [nodeOkb_rename ρ p hi]
  exact h3 i hi

end Engine.Lang
