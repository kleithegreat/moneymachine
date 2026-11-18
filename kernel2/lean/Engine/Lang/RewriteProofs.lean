import Engine.Lang.UnitsProofs
import Engine.Lang.Rewrite

/-!
# The rewrite rules keep a program's values (B3, L3)

Everything is said of cells: node `k`'s value at coin `c` in a finished tick.
-/

namespace Engine.Lang

variable {α : Type} (N : NumOps α)

/-- A node's row of a tick depends on its arguments' rows only through their cells. -/
theorem nodeFull_cells (t : Tick α) (n : Node) (count coins : Nat) (R R' : Nat → Array (Option α))
    (E E' : Nat → Array (Option Rat)) (h : ∀ (k c : Nat), (R k)[c]! = (R' k)[c]!)
    (hE : ∀ (k c : Nat), (E k)[c]! = (E' k)[c]!) (ns : Array (NS α)) :
    nodeFull N t n count coins R E ns = nodeFull N t n count coins R' E' ns := by
  have hp : ∀ c, pointVal N t n R E c = pointVal N t n R' E' c := by
    intro c; unfold pointVal; simp [h, hE]
  unfold nodeFull finalize nodeCore
  split <;> simp [h, hp]

theorem exactRow_cells (t : Tick α) (n : Node) (coins : Nat) (R R' : Nat → Array (Option α))
    (E E' : Nat → Array (Option Rat)) (h : ∀ (k c : Nat), (R k)[c]! = (R' k)[c]!)
    (hE : ∀ (k c : Nat), (E k)[c]! = (E' k)[c]!) :
    exactRow N t n coins R E = exactRow N t n coins R' E' := by
  have hp : ∀ c, pointExact N t n R E c = pointExact N t n R' E' c := by
    intro c; unfold pointExact; simp [h, hE]
  unfold exactRow
  simp only [hp]

theorem keep_finite {z y : α} (h : N.keep z = some y) : N.finite y = true := by
  unfold NumOps.keep at h
  split at h
  · simp at h; subst h; assumption
  · simp at h

theorem nodeFull_size (t : Tick α) (n : Node) (count coins : Nat) (R : Nat → Array (Option α))
    (E : Nat → Array (Option Rat)) (ns : Array (NS α)) :
    (nodeFull N t n count coins R E ns).1.size = coins := by
  simp [nodeFull, finalize]

/-- A defined cell is inside the coins, in view and finite. -/
theorem nodeFull_defined (t : Tick α) (n : Node) (count coins : Nat) (R : Nat → Array (Option α))
    (E : Nat → Array (Option Rat)) (ns : Array (NS α)) (c : Nat) (y : α)
    (h : (nodeFull N t n count coins R E ns).1[c]! = some y) :
    c < coins ∧ t.inView c = true ∧ N.finite y = true := by
  unfold nodeFull finalize at h
  simp only [] at h
  rw [rowMap_get] at h
  by_cases hc : c < coins
  · rw [ite_eq_left hc] at h
    split at h
    · rename_i hv
      obtain ⟨z, _, hz⟩ := Option.bind_eq_some_iff.1 h
      exact ⟨hc, hv, keep_finite N hz⟩
    · simp at h
  · rw [ite_eq_right hc] at h
    simp at h

theorem exactRow_size (t : Tick α) (n : Node) (coins : Nat) (R : Nat → Array (Option α))
    (E : Nat → Array (Option Rat)) : (exactRow N t n coins R E).size = coins := by
  simp [exactRow]

/-- Two programs of one size whose nodes compute the same rows, given the same rows before them, run one tick alike. -/
theorem step_same {p p' : Program} (hp : p.Ordered) (hp' : p'.Ordered) (hsize : p'.nodes.size = p.nodes.size)
    (t : Tick α) (m : Mach α)
    (hnode : ∀ k, k < p.nodes.size →
      (∀ j, j < k → (Mach.step N p' t m).vals[j]! = (Mach.step N p t m).vals[j]! ∧
        (Mach.step N p' t m).exacts[j]! = (Mach.step N p t m).exacts[j]!) →
      nodeFull N t p'.nodes[k]! m.count m.coins (argRow (Mach.step N p' t m).vals (p'.nodes[k]!).args)
        (argRow (Mach.step N p' t m).exacts (p'.nodes[k]!).args) m.ns[k]! =
      nodeFull N t p.nodes[k]! m.count m.coins (argRow (Mach.step N p t m).vals (p.nodes[k]!).args)
        (argRow (Mach.step N p t m).exacts (p.nodes[k]!).args) m.ns[k]! ∧
      exactRow N t p'.nodes[k]! m.coins (argRow (Mach.step N p' t m).vals (p'.nodes[k]!).args)
        (argRow (Mach.step N p' t m).exacts (p'.nodes[k]!).args) =
      exactRow N t p.nodes[k]! m.coins (argRow (Mach.step N p t m).vals (p.nodes[k]!).args)
        (argRow (Mach.step N p t m).exacts (p.nodes[k]!).args)) :
    Mach.step N p' t m = Mach.step N p t m := by
  have hk : ∀ k, k < p.nodes.size →
      (Mach.step N p' t m).vals[k]! = (Mach.step N p t m).vals[k]! ∧
      (Mach.step N p' t m).exacts[k]! = (Mach.step N p t m).exacts[k]! ∧
      (Mach.step N p' t m).ns[k]! = (Mach.step N p t m).ns[k]! := by
    intro k
    induction k using Nat.strongRecOn with
    | _ k ih =>
      intro hkk
      have h1 := step_row N p' t m hp' (by omega : k < p'.nodes.size)
      have h2 := step_row N p t m hp hkk
      have h3 := hnode k hkk (fun j hj => ⟨(ih j hj (by omega)).1, (ih j hj (by omega)).2.1⟩)
      rw [h3.1] at h1
      rw [h3.2] at h1
      have e1 := h1.1.trans h2.1.symm
      have e2 := h1.2.trans h2.2.symm
      exact ⟨congrArg Prod.fst e1, e2, congrArg Prod.snd e1⟩
  have hv : (build N p' t m p.nodes.size).vals = (build N p t m p.nodes.size).vals := by
    apply arr_ext (by rw [(build_size N p' t m _).1, (build_size N p t m _).1])
    intro i hi
    rw [(build_size N p' t m _).1] at hi
    have := (hk i hi).1
    rwa [step_vals, step_vals, hsize] at this
  have he : (build N p' t m p.nodes.size).exacts = (build N p t m p.nodes.size).exacts := by
    apply arr_ext (by rw [(build_size N p' t m _).2.1, (build_size N p t m _).2.1])
    intro i hi
    rw [(build_size N p' t m _).2.1] at hi
    have := (hk i hi).2.1
    rwa [step_exacts, step_exacts, hsize] at this
  have hn : (build N p' t m p.nodes.size).ns = (build N p t m p.nodes.size).ns := by
    apply arr_ext (by rw [(build_size N p' t m _).2.2, (build_size N p t m _).2.2])
    intro i hi
    rw [(build_size N p' t m _).2.2] at hi
    have := (hk i hi).2.2
    rwa [step_ns, step_ns, hsize] at this
  have hc : build N p' t m p.nodes.size = build N p t m p.nodes.size := by
    obtain ⟨c1, k1⟩ := build_count N p' t m p.nodes.size
    obtain ⟨c2, k2⟩ := build_count N p t m p.nodes.size
    cases h1 : build N p' t m p.nodes.size with
    | mk a b c d e =>
      cases h2 : build N p t m p.nodes.size with
      | mk a' b' c' d' e' =>
        rw [h1] at c1 k1 hv he hn
        rw [h2] at c2 k2 hv he hn
        simp only [] at c1 k1 c2 k2 hv he hn
        subst hv he hn
        rw [c1, c2]
        rw [k1, k2]
  unfold Mach.step
  rw [hsize, hc]

theorem nodeFull_args_irrel (t : Tick α) (o : Op) (a b : List Nat) (count coins : Nat)
    (R : Nat → Array (Option α)) (E : Nat → Array (Option Rat)) (ns : Array (NS α)) :
    nodeFull N t (.op o a) count coins R E ns = nodeFull N t (.op o b) count coins R E ns := by
  unfold nodeFull nodeCore
  cases o <;> simp [pointVal, evalNode]

theorem exactRow_args_irrel (t : Tick α) (o : Op) (a b : List Nat) (coins : Nat)
    (R : Nat → Array (Option α)) (E : Nat → Array (Option Rat)) :
    exactRow N t (.op o a) coins R E = exactRow N t (.op o b) coins R E := by
  unfold exactRow
  simp [pointExact, evalExactNode]

theorem foldl_step_eq {p p' : Program} (h : ∀ (t : Tick α) (m : Mach α), Mach.step N p' t m = Mach.step N p t m)
    (ts : List (Tick α)) : ∀ m : Mach α,
    ts.foldl (fun m t => Mach.step N p' t m) m = ts.foldl (fun m t => Mach.step N p t m) m := by
  induction ts with
  | nil => intro m; rw [List.foldl_nil, List.foldl_nil]
  | cons t ts ih => intro m; rw [List.foldl_cons, List.foldl_cons, h t m]; exact ih _

theorem run_eq_of_step {p p' : Program} (coins : Nat) (ts : List (Tick α))
    (h : ∀ (t : Tick α) (m : Mach α), Mach.step N p' t m = Mach.step N p t m)
    (hinit : Mach.init N p' coins = Mach.init N p coins) : Mach.run N p' coins ts = Mach.run N p coins ts := by
  unfold Mach.run
  rw [hinit]
  exact foldl_step_eq N h ts _

theorem redirect_nodes_size (p : Program) (i x : Nat) : (p.redirect i x).nodes.size = p.nodes.size := by
  simp [Program.redirect]

theorem array_map_get {β γ : Type} [Inhabited β] [Inhabited γ] (f : β → γ) (a : Array β) {k : Nat} (hk : k < a.size) :
    (a.map f)[k]! = f a[k]! := by
  rw [getElem!_pos (a.map f) k (by simpa using hk), getElem!_pos a k hk]
  simp

theorem redirect_nodes_get (p : Program) (i x : Nat) {k : Nat} (hk : k < p.nodes.size) :
    (p.redirect i x).nodes[k]! = match p.nodes[k]! with
      | .op o args => .op o (args.map fun k => if k == i then x else k)
      | n => n :=
  array_map_get _ p.nodes hk

theorem redirect_ordered {p : Program} {i x : Nat} (hp : p.Ordered) (hxi : x < i) : (p.redirect i x).Ordered := by
  intro k hk a ha
  rw [redirect_nodes_size] at hk
  rw [redirect_nodes_get p i x hk] at ha
  have hpk := hp k hk
  cases hn : p.nodes[k]! with
  | op o args =>
    rw [hn] at ha
    simp only [Node.args, List.mem_map] at ha
    obtain ⟨b, hb, rfl⟩ := ha
    have hbk := hpk b (by rw [hn]; exact hb)
    by_cases hbi : b == i
    · simp only [hbi, ite_true]
      have : b = i := by simpa using hbi
      subst this; omega
    · simp only [hbi]; exact hbk
  | builtin _ => rw [hn] at ha; simp [Node.args] at ha
  | source _ _ => rw [hn] at ha; simp [Node.args] at ha
  | const _ _ => rw [hn] at ha; simp [Node.args] at ha
  | slotIn _ _ => rw [hn] at ha; simp [Node.args] at ha
  | exactConst _ _ => rw [hn] at ha; simp [Node.args] at ha

/-- Node `i` holds, at every tick of every machine, what node `x` holds: its float row and its exact row. -/
def SameRows (p : Program) (i x : Nat) : Prop :=
  ∀ (t : Tick α) (m : Mach α), (Mach.step N p t m).vals[i]! = (Mach.step N p t m).vals[x]! ∧
    (Mach.step N p t m).exacts[i]! = (Mach.step N p t m).exacts[x]!

theorem argRow_redirect {β : Type} (A' A : Array (Array (Option β))) (args : List Nat) (i x : Nat)
    (hx : i ∈ args → A'[x]! = A[x]!) (hi : A[i]! = A[x]!) (ha : ∀ a ∈ args, a ≠ i → A'[a]! = A[a]!) (j c : Nat) :
    (argRow A' (args.map fun k => if k == i then x else k) j)[c]! = (argRow A args j)[c]! := by
  unfold argRow
  rw [List.getElem?_map]
  cases hj : args[j]? with
  | none => rfl
  | some a =>
    simp only [Option.map_some]
    have hmem := List.mem_of_getElem? hj
    by_cases hai : a = i
    · subst hai
      simp only [beq_self_eq_true, ite_true]
      rw [hx hmem, hi]
    · have hf : (a == i) = false := by simpa using hai
      simp only [hf, Bool.false_eq_true, ite_false]
      rw [ha a hmem hai]

theorem redirect_step {p : Program} {i x : Nat} (hp : p.Ordered) (hxi : x < i)
    (hsem : SameRows N p i x) (t : Tick α) (m : Mach α) :
    Mach.step N (p.redirect i x) t m = Mach.step N p t m := by
  apply step_same N hp (redirect_ordered hp hxi) (by rw [redirect_nodes_size]) t m
  intro k hk ih
  have hpk := hp k hk
  rw [redirect_nodes_get p i x hk]
  cases hn : p.nodes[k]! with
  | op o args =>
    simp only [Node.args]
    rw [nodeFull_args_irrel N t o (args.map fun k => if k == i then x else k) args,
      exactRow_args_irrel N t o (args.map fun k => if k == i then x else k) args]
    have hik : i ∈ args → x < k := fun hm => by have := hpk i (by rw [hn]; exact hm); omega
    have hak : ∀ a ∈ args, a ≠ i → a < k := fun a ha _ => hpk a (by rw [hn]; exact ha)
    have cellsV := argRow_redirect (Mach.step N (p.redirect i x) t m).vals (Mach.step N p t m).vals args i x
      (fun hm => (ih x (hik hm)).1) (hsem t m).1 (fun a ha hai => (ih a (hak a ha hai)).1)
    have cellsE := argRow_redirect (Mach.step N (p.redirect i x) t m).exacts (Mach.step N p t m).exacts args i x
      (fun hm => (ih x (hik hm)).2) (hsem t m).2 (fun a ha hai => (ih a (hak a ha hai)).2)
    exact ⟨nodeFull_cells N t _ _ _ _ _ _ _ cellsV cellsE _, exactRow_cells N t _ _ _ _ _ _ cellsV cellsE⟩
  | builtin _ =>
    simp only [Node.args]
    exact ⟨nodeFull_cells N t _ _ _ _ _ _ _ (fun j c => by simp [argRow]) (fun j c => by simp [argRow]) _,
      exactRow_cells N t _ _ _ _ _ _ (fun j c => by simp [argRow]) (fun j c => by simp [argRow])⟩
  | source _ _ =>
    simp only [Node.args]
    exact ⟨nodeFull_cells N t _ _ _ _ _ _ _ (fun j c => by simp [argRow]) (fun j c => by simp [argRow]) _,
      exactRow_cells N t _ _ _ _ _ _ (fun j c => by simp [argRow]) (fun j c => by simp [argRow])⟩
  | const _ _ =>
    simp only [Node.args]
    exact ⟨nodeFull_cells N t _ _ _ _ _ _ _ (fun j c => by simp [argRow]) (fun j c => by simp [argRow]) _,
      exactRow_cells N t _ _ _ _ _ _ (fun j c => by simp [argRow]) (fun j c => by simp [argRow])⟩
  | slotIn _ _ =>
    simp only [Node.args]
    exact ⟨nodeFull_cells N t _ _ _ _ _ _ _ (fun j c => by simp [argRow]) (fun j c => by simp [argRow]) _,
      exactRow_cells N t _ _ _ _ _ _ (fun j c => by simp [argRow]) (fun j c => by simp [argRow])⟩
  | exactConst _ _ =>
    simp only [Node.args]
    exact ⟨nodeFull_cells N t _ _ _ _ _ _ _ (fun j c => by simp [argRow]) (fun j c => by simp [argRow]) _,
      exactRow_cells N t _ _ _ _ _ _ (fun j c => by simp [argRow]) (fun j c => by simp [argRow])⟩

theorem redirect_wf {p : Program} {i x : Nat} (hwf : p.WF) (hxi : x < i) (hi : i < p.nodes.size)
    (hty : p.types[x]! = p.types[i]!) : (p.redirect i x).WF := by
  obtain ⟨h1, h2, h3, h4⟩ := wf_iff.1 hwf
  have hf : ∀ k, p.types[if k == i then x else k]! = p.types[k]! := by
    intro k
    by_cases hk : k == i
    · have : k = i := by simpa using hk
      subst this; simp [hty]
    · simp [hk]
  have hlt : ∀ k, k < p.nodes.size → (if k == i then x else k) < p.nodes.size := by
    intro k hk
    split <;> omega
  refine wf_iff.2 ⟨by simpa [Program.redirect] using h1, ?_, ?_, by simpa [Program.redirect, Program.slotOkb] using h4⟩
  · intro j hj
    simp only [Program.redirect, Array.toList_map, List.mem_map] at hj
    obtain ⟨q, hq, rfl⟩ := hj
    show (if q == i then x else q) < (p.redirect i x).nodes.size
    rw [redirect_nodes_size]
    exact hlt q (h2 q hq)
  · intro k hk
    rw [redirect_nodes_size] at hk
    have htypes : (p.redirect i x).types = p.types := rfl
    unfold Program.nodeOkb
    rw [redirect_nodes_get p i x hk, htypes]
    have hok := h3 k hk
    unfold Program.nodeOkb at hok
    cases hn : p.nodes[k]! with
    | op o args =>
      rw [hn] at hok
      dsimp only
      simp only [Bool.and_eq_true, List.all_eq_true, decide_eq_true_eq, beq_iff_eq] at hok ⊢
      obtain ⟨ha, ht⟩ := hok
      refine ⟨fun a' ha' => ?_, ?_⟩
      · obtain ⟨a, hamem, rfl⟩ := List.mem_map.1 ha'
        have hak := ha a hamem
        by_cases hai : a = i
        · subst hai
          simp only [ite_true]; omega
        · simp only [hai, ite_false]; exact hak
      · rw [List.map_map]
        have : ((fun x => p.types[x]!) ∘ fun k => if k = i then x else k) = fun x => p.types[x]! := by
          funext k
          simp only [Function.comp]
          by_cases hk : k = i
          · subst hk; simp [hty]
          · simp [hk]
        rw [this]; exact ht
    | builtin _ => rw [hn] at hok; exact hok
    | source _ _ => rw [hn] at hok; exact hok
    | const _ _ => rw [hn] at hok; exact hok
    | slotIn _ _ => rw [hn] at hok; exact hok
    | exactConst _ _ => rw [hn] at hok; exact hok

theorem redirect_init (p : Program) (i x coins : Nat) :
    Mach.init N (p.redirect i x) coins = Mach.init N p coins := by
  unfold Mach.init
  simp only [Program.redirect, Array.map_map, Function.comp_def]
  congr 1
  apply Array.map_congr_left
  intro n _
  cases n with
  | op o args => cases o <;> simp
  | _ => simp

theorem run_row_eq {p : Program} {i x : Nat} (hsem : SameRows N p i x)
    (ts : List (Tick α)) : ∀ m : Mach α, (m.vals[i]! = m.vals[x]! ∧ m.exacts[i]! = m.exacts[x]!) →
    ((ts.foldl (fun m t => Mach.step N p t m) m).vals[i]! = (ts.foldl (fun m t => Mach.step N p t m) m).vals[x]! ∧
      (ts.foldl (fun m t => Mach.step N p t m) m).exacts[i]! =
        (ts.foldl (fun m t => Mach.step N p t m) m).exacts[x]!) := by
  induction ts with
  | nil => intro m h; rw [List.foldl_nil]; exact h
  | cons t ts ih => intro m _; rw [List.foldl_cons]; exact ih _ (hsem t m)

theorem redirect_law {p : Program} {i x : Nat} (hwf : p.WF) (hxi : x < i) (hi : i < p.nodes.size)
    (hty : p.types[x]! = p.types[i]!) (hsem : SameRows N p i x) :
    (p.redirect i x).WF ∧ (∀ (t : Tick α) (m : Mach α), Mach.step N (p.redirect i x) t m = Mach.step N p t m) ∧
    (∀ (coins : Nat) (ts : List (Tick α)),
      Mach.run N (p.redirect i x) coins ts = Mach.run N p coins ts) ∧
    (∀ (coins : Nat) (ts : List (Tick α)),
      ((Mach.run N p coins ts).vals[i]! = (Mach.run N p coins ts).vals[x]! ∧
        (Mach.run N p coins ts).exacts[i]! = (Mach.run N p coins ts).exacts[x]!)) := by
  refine ⟨redirect_wf hwf hxi hi hty, fun t m => redirect_step N (wf_ordered hwf) hxi hsem t m,
    fun coins ts => ?_, fun coins ts => ?_⟩
  · exact run_eq_of_step N coins ts (fun t m => redirect_step N (wf_ordered hwf) hxi hsem t m)
      (redirect_init N p i x coins)
  · unfold Mach.run
    apply run_row_eq N hsem
    rw [(init_row N p coins hi).1, (init_row N p coins hi).2, (init_row N p coins (show x < p.nodes.size by omega)).1,
      (init_row N p coins (show x < p.nodes.size by omega)).2]
    exact ⟨rfl, rfl⟩

theorem replace_nodes_size (p : Program) (i : Nat) (n : Node) : (p.replace i n).nodes.size = p.nodes.size := by
  simp [Program.replace]

theorem replace_nodes_get_eq (p : Program) {i : Nat} (n : Node) (hi : i < p.nodes.size) :
    (p.replace i n).nodes[i]! = n := by
  simp [Program.replace, getElem!_pos, hi]

theorem replace_nodes_get_ne (p : Program) {i k : Nat} (n : Node) (hk : k < p.nodes.size) (hne : k ≠ i) :
    (p.replace i n).nodes[k]! = p.nodes[k]! := by
  have h1 : k < (p.nodes.set! i n).size := by simpa using hk
  simp only [Program.replace]
  rw [getElem!_pos (p.nodes.set! i n) k h1, getElem!_pos p.nodes k hk]
  simp [Array.set!_eq_setIfInBounds]
  rw [Array.getElem_setIfInBounds]
  simp [hne.symm]
  exact hk

theorem replace_ordered {p : Program} {i : Nat} (hp : p.Ordered) (hi : i < p.nodes.size) (n : Node)
    (hargs : ∀ a ∈ n.args, a < i) : (p.replace i n).Ordered := by
  intro k hk a ha
  rw [replace_nodes_size] at hk
  by_cases hki : k = i
  · subst hki
    rw [replace_nodes_get_eq p n hk] at ha
    exact hargs a ha
  · rw [replace_nodes_get_ne p n hk hki] at ha
    exact hp k hk a ha

/-- Replacing node `i` by an operator typed as it was, over earlier nodes, keeps a program well formed. -/
theorem replace_wf {p : Program} {i : Nat} (hwf : p.WF) (hi : i < p.nodes.size) (o : Op) (args : List Nat)
    (hargs : ∀ a ∈ args, a < i) (hty : opTy o (args.map (p.types[·]!)) = some p.types[i]!) :
    (p.replace i (.op o args)).WF := by
  obtain ⟨h1, h2, h3, h4⟩ := wf_iff.1 hwf
  refine wf_iff.2 ⟨by simpa [Program.replace] using h1, by simpa [Program.replace] using h2, ?_,
    by simpa [Program.replace, Program.slotOkb] using h4⟩
  intro k hk
  rw [replace_nodes_size] at hk
  have htypes : (p.replace i (.op o args)).types = p.types := rfl
  unfold Program.nodeOkb
  rw [htypes]
  by_cases hki : k = i
  · subst hki
    rw [replace_nodes_get_eq p _ hk]
    simp only [Bool.and_eq_true, List.all_eq_true, decide_eq_true_eq, beq_iff_eq]
    exact ⟨hargs, hty⟩
  · rw [replace_nodes_get_ne p _ hk hki]
    have := h3 k hk
    unfold Program.nodeOkb at this
    exact this

/-- Plain nodes with equal pointwise values compute equal rows. -/
theorem nodeFull_plain_congr (t : Tick α) {n1 n2 : Node} (h1 : n1.plain = true) (h2 : n2.plain = true)
    (count coins : Nat) (R1 R2 : Nat → Array (Option α)) (E1 E2 : Nat → Array (Option Rat)) (ns : Array (NS α))
    (hp : ∀ c, pointVal N t n1 R1 E1 c = pointVal N t n2 R2 E2 c) :
    nodeFull N t n1 count coins R1 E1 ns = nodeFull N t n2 count coins R2 E2 ns := by
  have e1 : (nodeCore N t n1 count coins R1 E1 ns) =
      (((List.range coins).map fun c => pointVal N t n1 R1 E1 c).toArray, ns) := by
    unfold nodeCore; split <;> simp_all [Node.plain]
  have e2 : (nodeCore N t n2 count coins R2 E2 ns) =
      (((List.range coins).map fun c => pointVal N t n2 R2 E2 c).toArray, ns) := by
    unfold nodeCore; split <;> simp_all [Node.plain]
  unfold nodeFull
  simp only [e1, e2, hp]

/-- A node whose exact value is never defined. -/
def Node.exactFree : Node → Bool
  | .op o _ => !o.exactValued
  | .source .. | .const .. => true
  | _ => false

theorem evalExactOp_free {o : Op} (h : o.exactValued = false) (arg : Nat → Option α) (argE : Nat → Option Rat) :
    evalExactOp N o arg argE = none := by
  cases hv : evalExactOp N o arg argE with
  | none => rfl
  | some x => have := evalExactOp_defined N hv; simp_all

theorem exactRow_free (t : Tick α) {n1 n2 : Node} (h1 : n1.exactFree = true) (h2 : n2.exactFree = true)
    (coins : Nat) (R1 R2 : Nat → Array (Option α)) (E1 E2 : Nat → Array (Option Rat)) :
    exactRow N t n1 coins R1 E1 = exactRow N t n2 coins R2 E2 := by
  have hn : ∀ (n : Node), n.exactFree = true → ∀ (R : Nat → Array (Option α)) (E : Nat → Array (Option Rat)) c,
      pointExact N t n R E c = none := by
    intro n hn R E c
    unfold pointExact
    split
    · cases n <;> simp_all [Node.exactFree, evalExactNode, evalExactOp_free N]
    · rfl
  unfold exactRow
  simp only [hn n1 h1, hn n2 h2]

theorem replace_step {p : Program} {i : Nat} (hp : p.Ordered) (hi : i < p.nodes.size) (n : Node)
    (hargs : ∀ a ∈ n.args, a < i)
    (hnode : ∀ (t : Tick α) (m : Mach α),
      nodeFull N t n m.count m.coins (argRow (Mach.step N p t m).vals n.args)
        (argRow (Mach.step N p t m).exacts n.args) m.ns[i]! =
      nodeFull N t p.nodes[i]! m.count m.coins (argRow (Mach.step N p t m).vals (p.nodes[i]!).args)
        (argRow (Mach.step N p t m).exacts (p.nodes[i]!).args) m.ns[i]! ∧
      exactRow N t n m.coins (argRow (Mach.step N p t m).vals n.args) (argRow (Mach.step N p t m).exacts n.args) =
      exactRow N t p.nodes[i]! m.coins (argRow (Mach.step N p t m).vals (p.nodes[i]!).args)
        (argRow (Mach.step N p t m).exacts (p.nodes[i]!).args))
    (t : Tick α) (m : Mach α) : Mach.step N (p.replace i n) t m = Mach.step N p t m := by
  apply step_same N hp (replace_ordered hp hi n hargs) (by rw [replace_nodes_size]) t m
  intro k hk ih
  have cells : ∀ (args : List Nat), (∀ a ∈ args, a < k) →
      (∀ j c : Nat, (argRow (Mach.step N (p.replace i n) t m).vals args j)[c]! =
        (argRow (Mach.step N p t m).vals args j)[c]!) ∧
      (∀ j c : Nat, (argRow (Mach.step N (p.replace i n) t m).exacts args j)[c]! =
        (argRow (Mach.step N p t m).exacts args j)[c]!) := by
    intro args hargs
    exact ⟨fun j c => by rw [argRow_build _ _ _ (fun a ha => (ih a (hargs a ha)).1) j],
      fun j c => by rw [argRow_build _ _ _ (fun a ha => (ih a (hargs a ha)).2) j]⟩
  by_cases hki : k = i
  · subst hki
    rw [replace_nodes_get_eq p n hk]
    obtain ⟨cV, cE⟩ := cells n.args hargs
    obtain ⟨h1, h2⟩ := hnode t m
    rw [nodeFull_cells N t n _ _ _ _ _ _ cV cE _, exactRow_cells N t n _ _ _ _ _ cV cE]
    exact ⟨h1, h2⟩
  · rw [replace_nodes_get_ne p n hk hki]
    obtain ⟨cV, cE⟩ := cells (p.nodes[k]!).args (fun a ha => hp k hk a ha)
    exact ⟨nodeFull_cells N t _ _ _ _ _ _ _ cV cE _, exactRow_cells N t _ _ _ _ _ _ cV cE⟩

theorem map_set_same {β γ : Type} [Inhabited β] [Inhabited γ] (f : β → γ) (a : Array β) (i : Nat)
    (hi : i < a.size) (x : β) (h : f x = f a[i]!) : (a.set! i x).map f = a.map f := by
  apply arr_ext (by simp)
  intro k hk
  have hk' : k < a.size := by simpa using hk
  rw [array_map_get f (a.set! i x) (by simpa using hk'), array_map_get f a hk']
  by_cases hki : k = i
  · subst hki
    simp [getElem!_pos, hk', Array.set!_eq_setIfInBounds]
    simpa [getElem!_pos, hk'] using h
  · simp [Array.set!_eq_setIfInBounds, getElem!_pos, hk']
    rw [Array.getElem_setIfInBounds]
    simp [Ne.symm hki]
    exact hk'

theorem replace_init (p : Program) {i : Nat} (hi : i < p.nodes.size) (n : Node) (coins : Nat)
    (hn : n.plain = true) (ho : p.nodes[i]!.plain = true) :
    Mach.init N (p.replace i n) coins = Mach.init N p coins := by
  have hstate : ∀ m : Node, m.plain = true → (match m with
      | Node.op (Op.window w k) _ => NS.win (Win.new N w k)
      | Node.op Op.ticksSince _ => NS.since none
      | _ => (NS.stateless : NS α)) = NS.stateless := by
    intro m hm
    cases m with
    | op o args => cases o <;> simp_all [Node.plain]
    | _ => rfl
  unfold Mach.init
  have hnodes : (p.replace i n).nodes.map (fun _ => Array.replicate coins (none : Option α)) =
      p.nodes.map (fun _ => Array.replicate coins none) :=
    map_set_same _ p.nodes i hi n rfl
  have hexacts : (p.replace i n).nodes.map (fun _ => Array.replicate coins (none : Option Rat)) =
      p.nodes.map (fun _ => Array.replicate coins none) :=
    map_set_same _ p.nodes i hi n rfl
  have hns : (p.replace i n).nodes.map (fun m => Array.replicate coins
        (match m with
         | Node.op (Op.window w k) _ => NS.win (Win.new N w k)
         | Node.op Op.ticksSince _ => NS.since none
         | _ => (NS.stateless : NS α))) =
      p.nodes.map (fun m => Array.replicate coins
        (match m with
         | Node.op (Op.window w k) _ => NS.win (Win.new N w k)
         | Node.op Op.ticksSince _ => NS.since none
         | _ => (NS.stateless : NS α))) :=
    map_set_same _ p.nodes i hi n (by rw [hstate n hn, hstate _ ho])
  simp only [hnodes, hexacts]
  congr 1

/-- A defined cell of a finished tick is inside the coins, in view and finite. -/
theorem cell_defined {p : Program} (hp : p.Ordered) (t : Tick α) (m : Mach α) {j : Nat} (hj : j < p.nodes.size)
    {c : Nat} {y : α} (h : ((Mach.step N p t m).vals[j]!)[c]! = some y) :
    c < m.coins ∧ t.inView c = true ∧ N.finite y = true := by
  have hrow := congrArg Prod.fst (step_row N p t m hp hj).1
  simp only [] at hrow
  rw [hrow] at h
  exact nodeFull_defined N t _ _ _ _ _ _ c y h

theorem cell_none {p : Program} (hp : p.Ordered) (t : Tick α) (m : Mach α) {j : Nat} (hj : j < p.nodes.size)
    {c : Nat} (h : ¬ (c < m.coins ∧ t.inView c = true)) : ((Mach.step N p t m).vals[j]!)[c]! = none := by
  cases hv : ((Mach.step N p t m).vals[j]!)[c]! with
  | none => rfl
  | some y => exact absurd ⟨(cell_defined N hp t m hj hv).1, (cell_defined N hp t m hj hv).2.1⟩ h

/-- A plain operator's cell: the operator over its arguments' cells, filtered. -/
theorem plain_cell {p : Program} (hp : p.Ordered) (t : Tick α) (m : Mach α) {j : Nat} (hj : j < p.nodes.size)
    {o : Op} {args : List Nat} (hn : p.nodes[j]! = .op o args) (hpl : (Node.op o args).plain = true) (c : Nat) :
    ((Mach.step N p t m).vals[j]!)[c]! =
      if c < m.coins ∧ t.inView c = true then
        (evalOp N o (fun k => ((argRow (Mach.step N p t m).vals args k)[c]!))
          (fun k => ((argRow (Mach.step N p t m).exacts args k)[c]!))).bind N.keep
      else none := by
  have hrow := congrArg Prod.fst (step_row N p t m hp hj).1
  simp only [] at hrow
  rw [hn] at hrow
  rw [hrow, nodeFull_plain_get N t _ hpl]
  by_cases hc : c < m.coins <;> by_cases hv : t.inView c = true <;>
    simp [hc, hv, pointVal, evalNode, Node.args]

theorem evalOp_neg (arg : Nat → Option α) (argE : Nat → Option Rat) : evalOp N .neg arg argE = (arg 0).map N.neg := by
  unfold evalOp; cases arg 0 <;> rfl
theorem evalOp_abs (arg : Nat → Option α) (argE : Nat → Option Rat) : evalOp N .abs arg argE = (arg 0).map N.abs := by
  unfold evalOp; cases arg 0 <;> rfl
theorem evalOp_not (arg : Nat → Option α) (argE : Nat → Option Rat) : evalOp N .not arg argE = (arg 0).map (fun x => N.truth (N.isZero x)) := by
  unfold evalOp; cases arg 0 <;> rfl
theorem evalOp_mul (arg : Nat → Option α) (argE : Nat → Option Rat) : evalOp N .mul arg argE = (arg 0).bind fun x => (arg 1).map (N.mul x) := by
  unfold evalOp; cases arg 0 <;> cases arg 1 <;> rfl
theorem evalOp_add (arg : Nat → Option α) (argE : Nat → Option Rat) : evalOp N .add arg argE = (arg 0).bind fun x => (arg 1).map (N.add x) := by
  unfold evalOp; cases arg 0 <;> cases arg 1 <;> rfl
theorem evalOp_sub (arg : Nat → Option α) (argE : Nat → Option Rat) : evalOp N .sub arg argE = (arg 0).bind fun x => (arg 1).map (N.sub x) := by
  unfold evalOp; cases arg 0 <;> cases arg 1 <;> rfl

theorem keep_of_finite {y : α} (h : N.finite y = true) : N.keep y = some y := by
  unfold NumOps.keep; simp [h]

theorem row_size {p : Program} (hp : p.Ordered) (t : Tick α) (m : Mach α) {j : Nat} (hj : j < p.nodes.size) :
    ((Mach.step N p t m).vals[j]!).size = m.coins := by
  have hrow := congrArg Prod.fst (step_row N p t m hp hj).1
  simp only [] at hrow
  rw [hrow]
  exact nodeFull_size N t _ _ _ _ _ _

theorem rows_eq {p : Program} (hp : p.Ordered) (t : Tick α) (m : Mach α) {i x : Nat} (hi : i < p.nodes.size)
    (hx : x < p.nodes.size)
    (h : ∀ c : Nat, ((Mach.step N p t m).vals[i]!)[c]! = ((Mach.step N p t m).vals[x]!)[c]!) :
    (Mach.step N p t m).vals[i]! = (Mach.step N p t m).vals[x]! :=
  row_ext (by rw [row_size N hp t m hi, row_size N hp t m hx]) h

theorem sem_negNeg {p : Program} (hp : p.Ordered) (hL : N.Lawful) {i a x : Nat} (hi : i < p.nodes.size)
    (hn : p.nodes[i]! = .op .neg [a]) (hna : p.nodes[a]! = .op .neg [x]) (t : Tick α) (m : Mach α) :
    (Mach.step N p t m).vals[i]! = (Mach.step N p t m).vals[x]! := by
  have hai : a < i := hp i hi a (by rw [hn]; simp [Node.args])
  have hxa : x < a := hp a (by omega) x (by rw [hna]; simp [Node.args])
  apply rows_eq N hp t m hi (by omega)
  intro c
  rw [plain_cell N hp t m hi hn (by simp [Node.plain]) c]
  by_cases hcv : c < m.coins ∧ t.inView c = true
  · rw [ite_eq_left hcv, evalOp_neg]
    simp only [argRow, List.getElem?_cons_zero]
    rw [plain_cell N hp t m (by omega) hna (by simp [Node.plain]) c, ite_eq_left hcv, evalOp_neg]
    simp only [argRow, List.getElem?_cons_zero]
    cases hw : ((Mach.step N p t m).vals[x]!)[c]! with
    | none => simp
    | some y =>
      have hfin := (cell_defined N hp t m (by omega) hw).2.2
      simp [keep_of_finite N (hL.finite_neg y hfin), hL.neg_neg y hfin, keep_of_finite N hfin]
  · rw [ite_eq_right hcv, cell_none N hp t m (by omega) hcv]

theorem const_cell {p : Program} (hp : p.Ordered) (t : Tick α) (m : Mach α) {j : Nat} (hj : j < p.nodes.size)
    {bits : UInt64} {u : Dim} (hn : p.nodes[j]! = .const bits u) (c : Nat) :
    ((Mach.step N p t m).vals[j]!)[c]! =
      if c < m.coins ∧ t.inView c = true then (some (N.ofBits bits)).bind N.keep else none := by
  have hrow := congrArg Prod.fst (step_row N p t m hp hj).1
  simp only [] at hrow
  rw [hn] at hrow
  rw [hrow, nodeFull_plain_get N t _ (by simp [Node.plain]) _ _ _ _ _ c]
  by_cases hc : c < m.coins <;> by_cases hv : t.inView c = true <;> simp [hc, hv, pointVal, evalNode]

theorem sem_absAbs {p : Program} (hp : p.Ordered) (hL : N.Lawful) {i a y : Nat} (hi : i < p.nodes.size)
    (hn : p.nodes[i]! = .op .abs [a]) (hna : p.nodes[a]! = .op .abs [y]) (t : Tick α) (m : Mach α) :
    (Mach.step N p t m).vals[i]! = (Mach.step N p t m).vals[a]! := by
  have hai : a < i := hp i hi a (by rw [hn]; simp [Node.args])
  have hya : y < a := hp a (by omega) y (by rw [hna]; simp [Node.args])
  apply rows_eq N hp t m hi (by omega)
  intro c
  rw [plain_cell N hp t m hi hn (by simp [Node.plain]) c, plain_cell N hp t m (by omega) hna (by simp [Node.plain]) c]
  by_cases hcv : c < m.coins ∧ t.inView c = true
  · rw [ite_eq_left hcv, ite_eq_left hcv, evalOp_abs, evalOp_abs]
    simp only [argRow, List.getElem?_cons_zero]
    rw [plain_cell N hp t m (by omega) hna (by simp [Node.plain]) c, ite_eq_left hcv, evalOp_abs]
    simp only [argRow, List.getElem?_cons_zero]
    cases hw : ((Mach.step N p t m).vals[y]!)[c]! with
    | none => simp
    | some w =>
      have hfin := (cell_defined N hp t m (by omega) hw).2.2
      simp [keep_of_finite N (hL.finite_abs w hfin), hL.abs_abs w hfin]
  · rw [ite_eq_right hcv, ite_eq_right hcv]

theorem sem_mulOne {p : Program} (hp : p.Ordered) (hL : N.Lawful) {i x cc : Nat} (hi : i < p.nodes.size)
    (hn : p.nodes[i]! = .op .mul [x, cc]) (hc : p.nodes[cc]! = .const 0x3FF0000000000000 Dim.one)
    (t : Tick α) (m : Mach α) : (Mach.step N p t m).vals[i]! = (Mach.step N p t m).vals[x]! := by
  have hxi : x < i := hp i hi x (by rw [hn]; simp [Node.args])
  have hci : cc < i := hp i hi cc (by rw [hn]; simp [Node.args])
  apply rows_eq N hp t m hi (by omega)
  intro c
  rw [plain_cell N hp t m hi hn (by simp [Node.plain]) c]
  by_cases hcv : c < m.coins ∧ t.inView c = true
  · rw [ite_eq_left hcv, evalOp_mul]
    simp only [argRow, List.getElem?_cons_zero, List.getElem?_cons_succ]
    rw [const_cell N hp t m (by omega) hc c, ite_eq_left hcv]
    simp only [Option.bind_some, keep_of_finite N hL.finite_one]
    cases hw : ((Mach.step N p t m).vals[x]!)[c]! with
    | none => simp
    | some w =>
      have hfin := (cell_defined N hp t m (by omega) hw).2.2
      simp [hL.mul_one w hfin, keep_of_finite N hfin]
  · rw [ite_eq_right hcv, cell_none N hp t m (by omega) hcv]

theorem sem_subZero {p : Program} (hp : p.Ordered) (hL : N.Lawful) {i x cc : Nat} {u : Dim}
    (hi : i < p.nodes.size) (hn : p.nodes[i]! = .op .sub [x, cc]) (hc : p.nodes[cc]! = .const 0 u)
    (t : Tick α) (m : Mach α) : (Mach.step N p t m).vals[i]! = (Mach.step N p t m).vals[x]! := by
  have hxi : x < i := hp i hi x (by rw [hn]; simp [Node.args])
  have hci : cc < i := hp i hi cc (by rw [hn]; simp [Node.args])
  apply rows_eq N hp t m hi (by omega)
  intro c
  rw [plain_cell N hp t m hi hn (by simp [Node.plain]) c]
  by_cases hcv : c < m.coins ∧ t.inView c = true
  · rw [ite_eq_left hcv, evalOp_sub]
    simp only [argRow, List.getElem?_cons_zero, List.getElem?_cons_succ]
    rw [const_cell N hp t m (by omega) hc c, ite_eq_left hcv]
    simp only [Option.bind_some, keep_of_finite N hL.finite_zero]
    cases hw : ((Mach.step N p t m).vals[x]!)[c]! with
    | none => simp
    | some w =>
      have hfin := (cell_defined N hp t m (by omega) hw).2.2
      simp [hL.sub_zero w hfin, keep_of_finite N hfin]
  · rw [ite_eq_right hcv, cell_none N hp t m (by omega) hcv]

theorem sem_divOne {p : Program} (hp : p.Ordered) (hL : N.Lawful) {i x cc : Nat} (hi : i < p.nodes.size)
    (hn : p.nodes[i]! = .op .div [x, cc]) (hc : p.nodes[cc]! = .const 0x3FF0000000000000 Dim.one)
    (t : Tick α) (m : Mach α) : (Mach.step N p t m).vals[i]! = (Mach.step N p t m).vals[x]! := by
  have hxi : x < i := hp i hi x (by rw [hn]; simp [Node.args])
  have hci : cc < i := hp i hi cc (by rw [hn]; simp [Node.args])
  apply rows_eq N hp t m hi (by omega)
  intro c
  rw [plain_cell N hp t m hi hn (by simp [Node.plain]) c]
  by_cases hcv : c < m.coins ∧ t.inView c = true
  · rw [ite_eq_left hcv]
    unfold evalOp
    simp only [argRow, List.getElem?_cons_zero, List.getElem?_cons_succ]
    rw [const_cell N hp t m (by omega) hc c, ite_eq_left hcv]
    simp only [Option.bind_some, keep_of_finite N hL.finite_one]
    cases hw : ((Mach.step N p t m).vals[x]!)[c]! with
    | none => simp
    | some w =>
      have hfin := (cell_defined N hp t m (by omega) hw).2.2
      simp [hL.one_ne_zero, hL.div_one w hfin, keep_of_finite N hfin]
  · rw [ite_eq_right hcv, cell_none N hp t m (by omega) hcv]

theorem sem_notNot {p : Program} (hwf : p.WF) (hL : N.Lawful) {i a cc : Nat} (hi : i < p.nodes.size)
    (hn : p.nodes[i]! = .op .not [a]) (hna : p.nodes[a]! = .op .not [cc]) (hbool : p.types[cc]! = Ty.bool)
    (t : Tick α) (m : Mach α) : (Mach.step N p t m).vals[i]! = (Mach.step N p t m).vals[cc]! := by
  have hp := wf_ordered hwf
  have hai : a < i := hp i hi a (by rw [hn]; simp [Node.args])
  have hca : cc < a := hp a (by omega) cc (by rw [hna]; simp [Node.args])
  apply rows_eq N hp t m hi (by omega)
  intro c
  rw [plain_cell N hp t m hi hn (by simp [Node.plain]) c]
  by_cases hcv : c < m.coins ∧ t.inView c = true
  · rw [ite_eq_left hcv, evalOp_not]
    simp only [argRow, List.getElem?_cons_zero]
    rw [plain_cell N hp t m (by omega) hna (by simp [Node.plain]) c, ite_eq_left hcv, evalOp_not]
    simp only [argRow, List.getElem?_cons_zero]
    cases hw : ((Mach.step N p t m).vals[cc]!)[c]! with
    | none => simp
    | some w =>
      obtain ⟨b, hb⟩ := step_boolInv N hwf t m cc (by omega) hbool c w hw
      subst hb
      simp [keep_of_finite N (hL.finite_truth _), hL.truth_zero]
  · rw [ite_eq_right hcv, cell_none N hp t m (by omega) hcv]

theorem hnode_of_evalOp (t : Tick α) {o' o : Op} {args' args : List Nat} (count coins : Nat)
    (V : Array (Array (Option α))) (VE : Array (Array (Option Rat))) (ns : Array (NS α))
    (h1 : (Node.op o' args').plain = true) (h2 : (Node.op o args).plain = true)
    (h : ∀ c, t.inView c = true →
      evalOp N o' (fun k => (argRow V args' k)[c]!) (fun k => (argRow VE args' k)[c]!) =
        evalOp N o (fun k => (argRow V args k)[c]!) (fun k => (argRow VE args k)[c]!)) :
    nodeFull N t (.op o' args') count coins (argRow V (Node.op o' args').args)
      (argRow VE (Node.op o' args').args) ns =
    nodeFull N t (.op o args) count coins (argRow V (Node.op o args).args)
      (argRow VE (Node.op o args).args) ns := by
  apply nodeFull_plain_congr N t h1 h2
  intro c
  unfold pointVal
  by_cases hv : t.inView c = true
  · simp only [hv, ite_true, evalNode, Node.args]
    exact h c hv
  · simp [hv]

theorem sem_addComm {α : Type} (N : NumOps α) (hL : N.Lawful) (A B : Option α) :
    (A.bind fun x => B.map (N.add x)) = (B.bind fun x => A.map (N.add x)) := by
  cases A <;> cases B <;> simp [hL.add_comm]

theorem sem_mulComm {α : Type} (N : NumOps α) (hL : N.Lawful) (A B : Option α) :
    (A.bind fun x => B.map (N.mul x)) = (B.bind fun x => A.map (N.mul x)) := by
  cases A <;> cases B <;> simp [hL.mul_comm]

theorem hnode_addComm (t : Tick α) (hL : N.Lawful) (a b : Nat) (count coins : Nat)
    (V : Array (Array (Option α))) (VE : Array (Array (Option Rat))) (ns : Array (NS α)) :
    nodeFull N t (.op .add [b, a]) count coins (argRow V (Node.op .add [b, a]).args)
      (argRow VE (Node.op .add [b, a]).args) ns =
    nodeFull N t (.op .add [a, b]) count coins (argRow V (Node.op .add [a, b]).args)
      (argRow VE (Node.op .add [a, b]).args) ns := by
  apply hnode_of_evalOp N t count coins V VE ns (by simp [Node.plain]) (by simp [Node.plain])
  intro c _
  rw [evalOp_add, evalOp_add]
  simp only [argRow, List.getElem?_cons_zero, List.getElem?_cons_succ]
  exact sem_addComm N hL _ _

theorem hnode_mulComm (t : Tick α) (hL : N.Lawful) (a b : Nat) (count coins : Nat)
    (V : Array (Array (Option α))) (VE : Array (Array (Option Rat))) (ns : Array (NS α)) :
    nodeFull N t (.op .mul [b, a]) count coins (argRow V (Node.op .mul [b, a]).args)
      (argRow VE (Node.op .mul [b, a]).args) ns =
    nodeFull N t (.op .mul [a, b]) count coins (argRow V (Node.op .mul [a, b]).args)
      (argRow VE (Node.op .mul [a, b]).args) ns := by
  apply hnode_of_evalOp N t count coins V VE ns (by simp [Node.plain]) (by simp [Node.plain])
  intro c _
  rw [evalOp_mul, evalOp_mul]
  simp only [argRow, List.getElem?_cons_zero, List.getElem?_cons_succ]
  exact sem_mulComm N hL _ _

theorem hnode_andComm (t : Tick α) (a b : Nat) (count coins : Nat)
    (V : Array (Array (Option α))) (VE : Array (Array (Option Rat))) (ns : Array (NS α)) :
    nodeFull N t (.op .and [b, a]) count coins (argRow V (Node.op .and [b, a]).args)
      (argRow VE (Node.op .and [b, a]).args) ns =
    nodeFull N t (.op .and [a, b]) count coins (argRow V (Node.op .and [a, b]).args)
      (argRow VE (Node.op .and [a, b]).args) ns := by
  apply hnode_of_evalOp N t count coins V VE ns (by simp [Node.plain]) (by simp [Node.plain])
  intro c _
  simp only [evalOp, argRow, List.getElem?_cons_zero, List.getElem?_cons_succ]
  cases (V[a]!)[c]! <;> cases (V[b]!)[c]! <;> simp [Bool.and_comm]

theorem hnode_orComm (t : Tick α) (a b : Nat) (count coins : Nat)
    (V : Array (Array (Option α))) (VE : Array (Array (Option Rat))) (ns : Array (NS α)) :
    nodeFull N t (.op .or [b, a]) count coins (argRow V (Node.op .or [b, a]).args)
      (argRow VE (Node.op .or [b, a]).args) ns =
    nodeFull N t (.op .or [a, b]) count coins (argRow V (Node.op .or [a, b]).args)
      (argRow VE (Node.op .or [a, b]).args) ns := by
  apply hnode_of_evalOp N t count coins V VE ns (by simp [Node.plain]) (by simp [Node.plain])
  intro c _
  simp only [evalOp, argRow, List.getElem?_cons_zero, List.getElem?_cons_succ]
  cases (V[a]!)[c]! <;> cases (V[b]!)[c]! <;> simp [Bool.or_comm]

theorem hnode_cmp (t : Tick α) (o' o : Op) (a b : Nat) (count coins : Nat)
    (V : Array (Array (Option α))) (VE : Array (Array (Option Rat))) (ns : Array (NS α))
    (hs : (o = .gt ∧ o' = .lt) ∨ (o = .lt ∧ o' = .gt) ∨ (o = .ge ∧ o' = .le) ∨ (o = .le ∧ o' = .ge)) :
    nodeFull N t (.op o' [b, a]) count coins (argRow V (Node.op o' [b, a]).args)
      (argRow VE (Node.op o' [b, a]).args) ns =
    nodeFull N t (.op o [a, b]) count coins (argRow V (Node.op o [a, b]).args)
      (argRow VE (Node.op o [a, b]).args) ns := by
  have hpl : ∀ q : Op, (q = .gt ∨ q = .lt ∨ q = .ge ∨ q = .le) → (Node.op q [b, a]).plain = true ∧ (Node.op q [a, b]).plain = true := by
    intro q hq; rcases hq with rfl | rfl | rfl | rfl <;> simp [Node.plain]
  have hp1 := hpl o' (by rcases hs with ⟨_, rfl⟩ | ⟨_, rfl⟩ | ⟨_, rfl⟩ | ⟨_, rfl⟩ <;> simp)
  have hp2 := hpl o (by rcases hs with ⟨rfl, _⟩ | ⟨rfl, _⟩ | ⟨rfl, _⟩ | ⟨rfl, _⟩ <;> simp)
  apply nodeFull_plain_congr N t (n1 := .op o' [b, a]) (n2 := .op o [a, b]) hp1.1 hp2.2
  intro c
  unfold pointVal
  by_cases hv : t.inView c = true
  · simp only [hv, ite_true, evalNode]
    rcases hs with ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ <;>
      (simp only [evalOp, Node.args, argRow, List.getElem?_cons_zero, List.getElem?_cons_succ];
       cases (V[a]!)[c]! <;> cases (V[b]!)[c]! <;> simp)
  · simp [hv]

theorem hnode_absNeg {p : Program} (hp : p.Ordered) (hL : N.Lawful) {i a x : Nat} (hi : i < p.nodes.size)
    (hn : p.nodes[i]! = .op .abs [a]) (hna : p.nodes[a]! = .op .neg [x]) (t : Tick α) (m : Mach α) :
    nodeFull N t (.op .abs [x]) m.count m.coins (argRow (Mach.step N p t m).vals (Node.op .abs [x]).args)
      (argRow (Mach.step N p t m).exacts (Node.op .abs [x]).args) m.ns[i]! =
    nodeFull N t p.nodes[i]! m.count m.coins (argRow (Mach.step N p t m).vals (p.nodes[i]!).args)
      (argRow (Mach.step N p t m).exacts (p.nodes[i]!).args) m.ns[i]! := by
  have hai : a < i := hp i hi a (by rw [hn]; simp [Node.args])
  have hxa : x < a := hp a (by omega) x (by rw [hna]; simp [Node.args])
  rw [hn]
  apply hnode_of_evalOp N t _ _ _ _ _ (by simp [Node.plain]) (by simp [Node.plain])
  intro c _
  rw [evalOp_abs, evalOp_abs]
  simp only [argRow, List.getElem?_cons_zero]
  rw [plain_cell N hp t m (by omega) hna (by simp [Node.plain]) c]
  by_cases hcv : c < m.coins ∧ t.inView c = true
  · rw [ite_eq_left hcv, evalOp_neg]
    simp only [argRow, List.getElem?_cons_zero]
    cases hw : ((Mach.step N p t m).vals[x]!)[c]! with
    | none => simp
    | some w =>
      have hfin := (cell_defined N hp t m (by omega) hw).2.2
      simp [keep_of_finite N (hL.finite_neg w hfin), hL.abs_neg w hfin]
  · rw [ite_eq_right hcv, cell_none N hp t m (by omega) hcv]

theorem hnode_ifNot {p : Program} (hp : p.Ordered) (hL : N.Lawful) {i nc a b cc : Nat} (hi : i < p.nodes.size)
    (hn : p.nodes[i]! = .op .ite [nc, a, b]) (hnn : p.nodes[nc]! = .op .not [cc]) (t : Tick α) (m : Mach α) :
    nodeFull N t (.op .ite [cc, b, a]) m.count m.coins (argRow (Mach.step N p t m).vals (Node.op .ite [cc, b, a]).args)
      (argRow (Mach.step N p t m).exacts (Node.op .ite [cc, b, a]).args) m.ns[i]! =
    nodeFull N t p.nodes[i]! m.count m.coins (argRow (Mach.step N p t m).vals (p.nodes[i]!).args)
      (argRow (Mach.step N p t m).exacts (p.nodes[i]!).args) m.ns[i]! := by
  have hnci : nc < i := hp i hi nc (by rw [hn]; simp [Node.args])
  have hcc : cc < nc := hp nc (by omega) cc (by rw [hnn]; simp [Node.args])
  rw [hn]
  apply hnode_of_evalOp N t _ _ _ _ _ (by simp [Node.plain]) (by simp [Node.plain])
  intro c _
  simp only [evalOp, argRow, List.getElem?_cons_zero, List.getElem?_cons_succ]
  rw [plain_cell N hp t m (by omega) hnn (by simp [Node.plain]) c]
  by_cases hcv : c < m.coins ∧ t.inView c = true
  · rw [ite_eq_left hcv, evalOp_not]
    simp only [argRow, List.getElem?_cons_zero]
    cases hw : ((Mach.step N p t m).vals[cc]!)[c]! with
    | none => simp
    | some w =>
      simp [keep_of_finite N (hL.finite_truth _), hL.truth_zero]
      cases hz : N.isZero w <;> simp
  · rw [ite_eq_right hcv, cell_none N hp t m (by omega) hcv]
    simp

/-- Two nodes whose types are not exact have the same exact row: nothing is defined. -/
theorem exacts_row_eq {p : Program} (hwf : p.WF) (t : Tick α) (m : Mach α) {i x : Nat} (hi : i < p.nodes.size)
    (hx : x < p.nodes.size) (hti : ∀ u, p.types[i]! ≠ Ty.exact u) (htx : ∀ u, p.types[x]! ≠ Ty.exact u) :
    (Mach.step N p t m).exacts[i]! = (Mach.step N p t m).exacts[x]! := by
  have hp := wf_ordered hwf
  have hsz : ∀ j, j < p.nodes.size → ((Mach.step N p t m).exacts[j]!).size = m.coins := by
    intro j hj
    rw [(step_row N p t m hp hj).2]
    exact exactRow_size N t _ _ _ _
  have hnone : ∀ j, j < p.nodes.size → (∀ u, p.types[j]! ≠ Ty.exact u) → ∀ c : Nat,
      ((Mach.step N p t m).exacts[j]!)[c]! = none := by
    intro j hj ht c
    cases hv : ((Mach.step N p t m).exacts[j]!)[c]! with
    | none => rfl
    | some y =>
      obtain ⟨u, hu⟩ := exact_cell_type N hwf t m hj hv
      exact absurd hu (ht u)
  apply row_ext (by rw [hsz i hi, hsz x hx])
  intro c
  rw [hnone i hi hti c, hnone x hx htx c]

/-- What L3 says of one rule's result: the program is well formed, keeps its slots and types, and runs as the
original did, tick by tick; the probes read what they read. -/
def RewriteConclusion (N : NumOps α) (p p' : Program) : Prop :=
  p'.WF ∧ p'.slots = p.slots ∧ p'.types = p.types ∧
  (∀ (t : Tick α) (m : Mach α), Mach.step N p' t m = Mach.step N p t m) ∧
  (∀ (coins : Nat) (ts : List (Tick α)), Mach.run N p' coins ts = Mach.run N p coins ts) ∧
  (∀ (coins : Nat) (ts : List (Tick α)) (j : Nat), j < p.probeNodes.size →
    (Mach.run N p' coins ts).vals[p'.probeNodes[j]!]! = (Mach.run N p coins ts).vals[p.probeNodes[j]!]! ∧
      (Mach.run N p' coins ts).exacts[p'.probeNodes[j]!]! = (Mach.run N p coins ts).exacts[p.probeNodes[j]!]!)

theorem redirect_final {p : Program} {i x : Nat} (hwf : p.WF) (hxi : x < i) (hi : i < p.nodes.size)
    (hty : p.types[x]! = p.types[i]!) (hnx : ∀ u, p.types[i]! ≠ Ty.exact u)
    (hsem : ∀ (t : Tick α) (m : Mach α), (Mach.step N p t m).vals[i]! = (Mach.step N p t m).vals[x]!) :
    RewriteConclusion N p (p.redirect i x) := by
  have hrows : SameRows N p i x := fun t m =>
    ⟨hsem t m, exacts_row_eq N hwf t m hi (by omega) hnx (by rw [hty]; exact hnx)⟩
  obtain ⟨hwf', hstep, hrun, hrow⟩ := redirect_law N hwf hxi hi hty hrows
  refine ⟨hwf', rfl, rfl, hstep, hrun, fun coins ts j hj => ?_⟩
  rw [hrun coins ts]
  have hq : (p.redirect i x).probeNodes[j]! = if p.probeNodes[j]! == i then x else p.probeNodes[j]! :=
    array_map_get _ p.probeNodes hj
  rw [hq]
  by_cases hqi : p.probeNodes[j]! == i
  · have : p.probeNodes[j]! = i := by simpa using hqi
    rw [ite_eq_left hqi, this]
    exact ⟨(hrow coins ts).1.symm, (hrow coins ts).2.symm⟩
  · rw [ite_eq_right hqi]
    exact ⟨rfl, rfl⟩

theorem replace_final {p : Program} {i : Nat} (hwf : p.WF) (hi : i < p.nodes.size) (o : Op) (args : List Nat)
    (hargs : ∀ a ∈ args, a < i) (hty : opTy o (args.map (p.types[·]!)) = some p.types[i]!)
    (hn : (Node.op o args).plain = true) (ho : p.nodes[i]!.plain = true)
    (hfn : (Node.op o args).exactFree = true) (hfo : p.nodes[i]!.exactFree = true)
    (hnode : ∀ (t : Tick α) (m : Mach α),
      nodeFull N t (.op o args) m.count m.coins (argRow (Mach.step N p t m).vals (Node.op o args).args)
        (argRow (Mach.step N p t m).exacts (Node.op o args).args) m.ns[i]! =
      nodeFull N t p.nodes[i]! m.count m.coins (argRow (Mach.step N p t m).vals (p.nodes[i]!).args)
        (argRow (Mach.step N p t m).exacts (p.nodes[i]!).args) m.ns[i]!) :
    RewriteConclusion N p (p.replace i (.op o args)) := by
  have hstep : ∀ (t : Tick α) (m : Mach α), Mach.step N (p.replace i (.op o args)) t m = Mach.step N p t m :=
    fun t m => replace_step N (wf_ordered hwf) hi (.op o args) hargs
      (fun t m => ⟨hnode t m, exactRow_free N t hfn hfo _ _ _ _ _⟩) t m
  have hrun : ∀ (coins : Nat) (ts : List (Tick α)),
      Mach.run N (p.replace i (.op o args)) coins ts = Mach.run N p coins ts := fun coins ts =>
    run_eq_of_step N coins ts hstep (replace_init N p hi (.op o args) coins hn ho)
  exact ⟨replace_wf hwf hi o args hargs hty, rfl, rfl, hstep, hrun, fun coins ts j _ => by
    rw [hrun coins ts]; exact ⟨rfl, rfl⟩⟩

end Engine.Lang
