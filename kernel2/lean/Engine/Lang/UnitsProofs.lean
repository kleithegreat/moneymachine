import Engine.Lang.Units
import Engine.Lang.EvalProofs

/-!
# The instrumented evaluator never errs (B3, L2)
-/

namespace Engine.Lang

variable {α : Type} (N : NumOps α)

theorem rowMap_get {β : Type} [Inhabited β] (n c : Nat) (f : Nat → β) :
    (((List.range n).map f).toArray)[c]! = if c < n then f c else default := by
  by_cases h : c < n
  · rw [ite_eq_left h, getElem!_pos _ _ (by simpa using h)]
    simp
  · rw [ite_eq_right h, getElem!_neg _ _ (by simpa using h)]

/-- A node with no memory of its own: `nodeCore` computes it pointwise. -/
def Node.plain : Node → Bool
  | .op .ticksSince _ => false
  | .op .xsMean _ => false
  | .op .xsDemean _ => false
  | .op .xsRank _ => false
  | .op (.window _ _) _ => false
  | _ => true

theorem nodeFull_plain_get (t : Tick α) (n : Node) (hn : n.plain = true) (count coins : Nat)
    (argRows : Nat → Array (Option α)) (argExact : Nat → Array (Option Rat)) (ns : Array (NS α)) (c : Nat) :
    (nodeFull N t n count coins argRows argExact ns).1[c]! =
      if c < coins then (if t.inView c = true then (pointVal N t n argRows argExact c).bind N.keep else none)
      else none := by
  have hraw : (nodeCore N t n count coins argRows argExact ns).1 =
      ((List.range coins).map fun c => pointVal N t n argRows argExact c).toArray := by
    unfold nodeCore
    split <;> simp_all [Node.plain]
  unfold nodeFull finalize
  simp only [hraw]
  rw [rowMap_get]
  by_cases hc : c < coins
  · rw [ite_eq_left hc, ite_eq_left hc, rowMap_get, ite_eq_left hc]
  · rw [ite_eq_right hc, ite_eq_right hc]
    rfl

/-- Every bool-typed node's defined values are `truth` of a bool. -/
def BoolInv (p : Program) (V : Array (Array (Option α))) : Prop :=
  ∀ i : Nat, i < p.nodes.size → p.types[i]! = .bool → ∀ (c : Nat) (x : α), (V[i]!)[c]! = some x →
    ∃ b, x = N.truth b

theorem numOf_not_bool (x : Except String Dim) : (numOf x).toOption ≠ some Ty.bool := by
  cases x <;> simp [numOf, Except.map, Except.toOption]

theorem exactOf_not_bool (x : Except String Dim) : (exactOf x).toOption ≠ some Ty.bool := by
  cases x <;> simp [exactOf, Except.map, Except.toOption]

theorem iteTy_bool {a b : Option Ty} (h : iteTy a b = .ok Ty.bool) : a = some Ty.bool ∧ b = some Ty.bool := by
  unfold iteTy at h
  split at h
  · simp
  · exact absurd (by rw [h]; rfl : (numOf (sameDim _ _)).toOption = some Ty.bool) (numOf_not_bool _)
  · simp at h

theorem opTy_bool {o : Op} {ts : List Ty} (h : opTy o ts = some Ty.bool) :
    o = .gt ∨ o = .ge ∨ o = .lt ∨ o = .le ∨ o = .and ∨ o = .or ∨ o = .not ∨
      (o = .ite ∧ ts[1]? = some Ty.bool ∧ ts[2]? = some Ty.bool) ∨ o = .egt ∨ o = .ege ∨ o = .elt ∨ o = .ele := by
  unfold opTy at h
  unfold opTyE at h
  cases o <;> first | exact absurd h (numOf_not_bool _) | exact absurd h (exactOf_not_bool _) | skip
  all_goals first | simp | skip
  rcases h0 : ts[0]? with _ | _ | _ <;> simp_all [Except.toOption, bind, Except.bind]
  all_goals
    refine iteTy_bool ?_
    revert h
    cases iteTy ts[1]? ts[2]? <;> simp

theorem builtinTy_exact {n : String} {t : Ty} (h : builtinTy n = some t) : ∃ u, t = Ty.exact u := by
  unfold builtinTy at h
  cases hf : builtinUnits.find? (·.1 == n) with
  | none => simp [hf] at h
  | some d => simp [hf] at h; exact ⟨d.2, h.symm⟩

theorem keep_some {x y : α} (h : N.keep y = some x) : x = y := by
  unfold NumOps.keep at h
  split at h
  · simpa using h.symm
  · simp at h

theorem step_boolInv {p : Program} (hwf : p.WF) (t : Tick α) (m : Mach α) :
    BoolInv N p (Mach.step N p t m).vals := by
  intro i
  induction i using Nat.strongRecOn with
  | _ i ih =>
  intro hi hty c x hx
  have hrow : (Mach.step N p t m).vals[i]! =
      (nodeFull N t p.nodes[i]! m.count m.coins (argRow (Mach.step N p t m).vals (p.nodes[i]!).args)
        (argRow (Mach.step N p t m).exacts (p.nodes[i]!).args) m.ns[i]!).1 :=
    congrArg Prod.fst (step_row N p t m (wf_ordered hwf) hi).1
  have hok := (wf_iff.1 hwf).2.2.1 i hi
  cases hn : p.nodes[i]! with
  | builtin nm =>
    simp only [Program.nodeOkb, hn, hty, Bool.and_eq_true, beq_iff_eq] at hok
    obtain ⟨hs, he⟩ := hok
    obtain ⟨t', ht'⟩ := Option.isSome_iff_exists.1 hs
    obtain ⟨u, hu⟩ := builtinTy_exact ht'
    rw [ht', hu] at he
    simp at he
  | source nm u => simp [Program.nodeOkb, hn, hty] at hok
  | const b u => simp [Program.nodeOkb, hn, hty] at hok
  | slotIn nm s =>
    simp only [Program.nodeOkb, hn, hty, Bool.and_eq_true, beq_iff_eq] at hok
    obtain ⟨⟨⟨_, hs⟩, he⟩, _⟩ := hok
    obtain ⟨t', ht'⟩ := Option.isSome_iff_exists.1 hs
    obtain ⟨u, hu⟩ := builtinTy_exact ht'
    rw [ht', hu] at he
    simp at he
  | exactConst q u => simp [Program.nodeOkb, hn, hty] at hok
  | op o args =>
    obtain ⟨hargs, hty'⟩ := (nodeOkb_op hn).1 hok
    rw [hty] at hty'
    have hplain : (Node.op o args).plain = true := by
      rcases opTy_bool hty' with h | h | h | h | h | h | h | ⟨h, _⟩ | h | h | h | h <;> subst_vars <;> simp [Node.plain]
    rw [hn] at hrow
    rw [hrow, nodeFull_plain_get N t _ hplain] at hx
    by_cases hc : c < m.coins
    · rw [ite_eq_left hc] at hx
      by_cases hv : t.inView c = true
      · rw [ite_eq_left hv] at hx
        obtain ⟨y, hy, hk⟩ := Option.bind_eq_some_iff.1 hx
        have hxy := keep_some N hk
        subst hxy
        unfold pointVal at hy
        rw [ite_eq_left hv] at hy
        simp only [evalNode] at hy
        rcases opTy_bool hty' with h | h | h | h | h | h | h | ⟨h, h1, h2⟩ | h | h | h | h
        all_goals subst_vars
        all_goals simp [evalOp] at hy
        all_goals first
          | (obtain ⟨a, _, hy2⟩ := Option.bind_eq_some_iff.1 hy
             obtain ⟨b, _, hy3⟩ := Option.bind_eq_some_iff.1 hy2
             exact ⟨_, (Option.some.inj hy3).symm⟩)
          | (obtain ⟨a, _, hy2⟩ := Option.bind_eq_some_iff.1 hy
             exact ⟨_, (Option.some.inj hy2).symm⟩)
          | skip
        have hbranch : ∀ k : Nat, 1 ≤ k → k ≤ 2 → (args.map (p.types[·]!))[k]? = some Ty.bool →
            (argRow (Mach.step N p t m).vals args k)[c]! = some x → ∃ b, x = N.truth b := by
          intro k _ _ hk hv
          have hk' : args[k]?.map (p.types[·]!) = some Ty.bool := by simpa using hk
          obtain ⟨a, ha, hta⟩ := Option.map_eq_some_iff.1 hk'
          have hlt : a < i := hargs a (List.mem_of_getElem? ha)
          unfold argRow at hv
          rw [ha] at hv
          exact ih a hlt (by omega) hta c x hv
        obtain ⟨a0, _, hy2⟩ := Option.bind_eq_some_iff.1 hy
        simp only [Node.args] at hy2
        split at hy2
        · exact hbranch 1 (by omega) (by omega) h1 hy2
        · exact hbranch 2 (by omega) (by omega) h2 hy2
      · rw [ite_eq_right hv] at hx; simp at hx
    · rw [ite_eq_right hc] at hx; simp at hx

theorem numOf_some {x : Except String Dim} {t : Ty} (h : (numOf x).toOption = some t) : ∃ u, t = Ty.num u := by
  cases x <;> simp [numOf, Except.map, Except.toOption] at h
  exact ⟨_, h.symm⟩

theorem exactOf_some {x : Except String Dim} {t : Ty} (h : (exactOf x).toOption = some t) : ∃ u, t = Ty.exact u := by
  cases x <;> simp [exactOf, Except.map, Except.toOption] at h
  exact ⟨_, h.symm⟩

theorem boolOf_some {x : Except String Unit} {t : Ty} (h : (boolOf x).toOption = some t) : t = Ty.bool := by
  cases x <;> simp [boolOf, Except.map, Except.toOption] at h
  exact h.symm

theorem iteTy_kind {a b : Option Ty} {t : Ty} (h : iteTy a b = .ok t) : t = Ty.bool ∨ ∃ u, t = Ty.num u := by
  unfold iteTy at h
  split at h
  · simp at h; exact Or.inl h.symm
  · exact Or.inr (numOf_some (by rw [h]; rfl))
  · simp at h

/-- The operators whose values are exact numbers. -/
def Op.exactValued : Op → Bool
  | .eadd | .esub | .emul | .ediv | .emin | .emax | .eneg | .toExact => true
  | _ => false

theorem opTy_ite_kind {ts : List Ty} {t : Ty} (h : opTy .ite ts = some t) : t = Ty.bool ∨ ∃ u, t = Ty.num u := by
  unfold opTy opTyE at h
  rcases h0 : ts[0]? with _ | _ | _ <;> simp [h0, Except.toOption, bind, Except.bind] at h
  cases hi : iteTy ts[1]? ts[2]? with
  | error e => simp [hi] at h
  | ok y =>
    simp [hi] at h
    rw [← h]
    exact iteTy_kind hi

theorem opTy_kind {o : Op} {ts : List Ty} {t : Ty} (h : opTy o ts = some t) :
    (o.exactValued = true ∧ ∃ u, t = Ty.exact u) ∨ (o.exactValued = false ∧ (t = Ty.bool ∨ ∃ u, t = Ty.num u)) := by
  have h' := h
  unfold opTy at h
  unfold opTyE at h
  cases o <;>
    first
    | exact Or.inl ⟨rfl, exactOf_some h⟩
    | exact Or.inr ⟨rfl, Or.inr (numOf_some h)⟩
    | exact Or.inr ⟨rfl, Or.inl (boolOf_some h)⟩
    | exact Or.inr ⟨rfl, opTy_ite_kind h'⟩

theorem evalOp_exactValued {o : Op} (h : o.exactValued = true) (arg : Nat → Option α) (argE : Nat → Option Rat) :
    evalOp N o arg argE = none := by
  cases o <;> simp_all [Op.exactValued, evalOp]

theorem evalExactOp_defined {o : Op} {arg : Nat → Option α} {argE : Nat → Option Rat} {x : Rat}
    (h : evalExactOp N o arg argE = some x) : o.exactValued = true := by
  cases o <;> simp_all [Op.exactValued, evalExactOp]

theorem exactRow_get (t : Tick α) (n : Node) (coins : Nat) (R : Nat → Array (Option α))
    (E : Nat → Array (Option Rat)) (c : Nat) :
    (exactRow N t n coins R E)[c]! = if c < coins then pointExact N t n R E c else none := by
  unfold exactRow
  rw [rowMap_get]
  by_cases hc : c < coins <;> simp [hc]
  rfl

/-- A float or bool cell of a node typed exact is undefined. -/
theorem vals_none_of_exact {p : Program} (hwf : p.WF) (t : Tick α) (m : Mach α) {i : Nat} (hi : i < p.nodes.size)
    {u : Dim} (hty : p.types[i]! = Ty.exact u) (c : Nat) : ((Mach.step N p t m).vals[i]!)[c]! = none := by
  have hrow : (Mach.step N p t m).vals[i]! =
      (nodeFull N t p.nodes[i]! m.count m.coins (argRow (Mach.step N p t m).vals (p.nodes[i]!).args)
        (argRow (Mach.step N p t m).exacts (p.nodes[i]!).args) m.ns[i]!).1 :=
    congrArg Prod.fst (step_row N p t m (wf_ordered hwf) hi).1
  have hok := (wf_iff.1 hwf).2.2.1 i hi
  have hplain : ∀ n : Node, n.plain = true → p.nodes[i]! = n →
      (∀ cc f fE, evalNode N t cc n f fE = none) → ((Mach.step N p t m).vals[i]!)[c]! = none := by
    intro n hn hnode hev
    rw [hrow, hnode, nodeFull_plain_get N t n hn]
    by_cases hc : c < m.coins <;> by_cases hv : t.inView c = true <;> simp [hc, hv, pointVal, hev]
  cases hn : p.nodes[i]! with
  | builtin nm => exact hplain _ rfl hn (fun _ _ _ => rfl)
  | slotIn nm s => exact hplain _ rfl hn (fun _ _ _ => rfl)
  | exactConst q d => exact hplain _ rfl hn (fun _ _ _ => rfl)
  | source nm d => simp [Program.nodeOkb, hn, hty] at hok
  | const b d => simp [Program.nodeOkb, hn, hty] at hok
  | op o args =>
    obtain ⟨_, hty'⟩ := (nodeOkb_op hn).1 hok
    rw [hty] at hty'
    rcases opTy_kind hty' with ⟨hev, _⟩ | ⟨_, hk⟩
    · have hpl : (Node.op o args).plain = true := by cases o <;> simp_all [Op.exactValued, Node.plain]
      exact hplain _ hpl hn (fun cc f fE => by simp [evalNode, evalOp_exactValued N hev])
    · exfalso
      rcases hk with hk | ⟨v, hv⟩
      · simp at hk
      · simp at hv

/-- A defined exact cell is at a node typed exact. -/
theorem exact_cell_type {p : Program} (hwf : p.WF) (t : Tick α) (m : Mach α) {i : Nat} (hi : i < p.nodes.size)
    {c : Nat} {x : Rat} (h : ((Mach.step N p t m).exacts[i]!)[c]! = some x) : ∃ u, p.types[i]! = Ty.exact u := by
  have hrow := (step_row N p t m (wf_ordered hwf) hi).2
  have hok := (wf_iff.1 hwf).2.2.1 i hi
  rw [hrow, exactRow_get] at h
  by_cases hc : c < m.coins
  · rw [ite_eq_left hc] at h
    unfold pointExact at h
    split at h
    · cases hn : p.nodes[i]! with
      | builtin nm =>
        rw [hn] at h
        simp only [Program.nodeOkb, hn, Bool.and_eq_true, beq_iff_eq] at hok
        obtain ⟨hs, he⟩ := hok
        obtain ⟨t', ht'⟩ := Option.isSome_iff_exists.1 hs
        obtain ⟨u, hu⟩ := builtinTy_exact ht'
        rw [ht', hu] at he
        exact ⟨u, he⟩
      | slotIn nm s =>
        simp only [Program.nodeOkb, hn, Bool.and_eq_true, beq_iff_eq] at hok
        obtain ⟨⟨⟨_, hs⟩, he⟩, _⟩ := hok
        obtain ⟨t', ht'⟩ := Option.isSome_iff_exists.1 hs
        obtain ⟨u, hu⟩ := builtinTy_exact ht'
        rw [ht', hu] at he
        exact ⟨u, he⟩
      | exactConst q d =>
        simp only [Program.nodeOkb, hn, beq_iff_eq] at hok
        exact ⟨d, hok⟩
      | source nm d => rw [hn] at h; simp [evalExactNode] at h
      | const b d => rw [hn] at h; simp [evalExactNode] at h
      | op o args =>
        rw [hn] at h
        simp only [evalExactNode] at h
        have hev := evalExactOp_defined N h
        obtain ⟨_, hty'⟩ := (nodeOkb_op hn).1 hok
        rcases opTy_kind hty' with ⟨_, ⟨u, hu⟩⟩ | ⟨hf, _⟩
        · exact ⟨u, hu⟩
        · rw [hev] at hf; simp at hf
    · simp at h
  · rw [ite_eq_right hc] at h; simp at h

theorem tagBuild_ok {p : Program} (hwf : p.WF) :
    ∀ k, k ≤ p.nodes.size → ∃ ts, tagBuild p k = .ok ts ∧ ts.size = k ∧ ∀ i, i < k → ts[i]! = p.types[i]! := by
  intro k
  induction k with
  | zero => intro _; exact ⟨#[], rfl, rfl, fun i hi => by omega⟩
  | succ k ih =>
    intro hk
    obtain ⟨ts, hts, hsz, hall⟩ := ih (by omega)
    have hk' : k < p.nodes.size := hk
    have hok := (wf_iff.1 hwf).2.2.1 k hk'
    have hnode : tagNode p ts k = .ok p.types[k]! := by
      unfold tagNode
      cases hn : p.nodes[k]! with
      | builtin nm =>
        simp only [Program.nodeOkb, hn, Bool.and_eq_true, beq_iff_eq] at hok
        simp [hok.2]
      | slotIn nm s =>
        simp only [Program.nodeOkb, hn, Bool.and_eq_true, beq_iff_eq] at hok
        simp [hok.1.2]
      | source nm u => simp only [Program.nodeOkb, hn, beq_iff_eq] at hok; simp [hok]
      | const b u => simp only [Program.nodeOkb, hn, beq_iff_eq] at hok; simp [hok]
      | exactConst q u => simp only [Program.nodeOkb, hn, beq_iff_eq] at hok; simp [hok]
      | op o args =>
        obtain ⟨hargs, hty⟩ := (nodeOkb_op hn).1 hok
        have hmap : args.map (ts[·]!) = args.map (p.types[·]!) :=
          List.map_congr_left fun a ha => hall a (hargs a ha)
        simp only []
        rw [hmap]
        unfold opTy at hty
        cases h : opTyE o (args.map (p.types[·]!)) with
        | error e => rw [h] at hty; simp [Except.toOption] at hty
        | ok y => rw [h] at hty; simp [Except.toOption] at hty; simp [hty]
    refine ⟨ts.push p.types[k]!, ?_, by simp [hsz], ?_⟩
    · simp only [tagBuild, hts, hnode, bind, Except.bind, pure, Except.pure]
    · intro i hi
      by_cases hik : i < k
      · rw [push_get_lt _ _ _ (by omega)]
        exact hall i hik
      · have : i = k := by omega
        subst this
        rw [← hsz, push_get_eq]

/-- What the evaluator's state has to satisfy for L2: bools, sorts and sizes. -/
structure UnitsInv (p : Program) (m : Mach α) : Prop where
  bools : BoolInv N p m.vals
  floatNone : ∀ i : Nat, i < p.nodes.size → ∀ u, p.types[i]! = Ty.exact u → ∀ c : Nat, (m.vals[i]!)[c]! = none
  exactTyped : ∀ i : Nat, i < p.nodes.size → ∀ (c : Nat) (x : Rat), (m.exacts[i]!)[c]! = some x →
    ∃ u, p.types[i]! = Ty.exact u
  exactSize : m.exacts.size = p.nodes.size

theorem step_unitsInv {p : Program} (hwf : p.WF) (t : Tick α) (m : Mach α) : UnitsInv N p (Mach.step N p t m) :=
  ⟨step_boolInv N hwf t m, fun i hi u hu c => vals_none_of_exact N hwf t m hi hu c,
    fun i hi c x h => exact_cell_type N hwf t m hi h, by
      rw [step_exacts]; exact (build_size N p t m p.nodes.size).2.1⟩

theorem replicate_none_get (n c : Nat) : (Array.replicate n (none : Option α))[c]! = none := by
  by_cases h : c < n
  · rw [getElem!_pos _ _ (by simpa using h)]
    simp
  · rw [getElem!_neg _ _ (by simpa using h)]
    rfl

theorem init_row (p : Program) (coins : Nat) {i : Nat} (hi : i < p.nodes.size) :
    (Mach.init N p coins).vals[i]! = Array.replicate coins none ∧
      (Mach.init N p coins).exacts[i]! = Array.replicate coins none := by
  simp only [Mach.init]
  rw [getElem!_pos _ _ (by simpa using hi), getElem!_pos _ _ (by simpa using hi)]
  simp

theorem init_exacts_none (p : Program) (coins i c : Nat) : ((Mach.init N p coins).exacts[i]!)[c]! = none := by
  by_cases hi : i < p.nodes.size
  · rw [(init_row N p coins hi).2, replicate_none_get]
  · rw [getElem!_neg (Mach.init N p coins).exacts i (by simpa [Mach.init] using hi)]
    rfl

theorem init_unitsInv (p : Program) (coins : Nat) : UnitsInv N p (Mach.init N p coins) := by
  refine ⟨?_, ?_, ?_, by simp [Mach.init]⟩
  · intro i hi _ c x hx
    rw [(init_row N p coins hi).1, replicate_none_get] at hx
    simp at hx
  · intro i hi u _ c
    rw [(init_row N p coins hi).1, replicate_none_get]
  · intro i hi c x hx
    rw [init_exacts_none] at hx
    simp at hx

/-- Remembered types are the checker's once a tick has run; before it nothing is remembered and nothing is defined. -/
def TagsOk (p : Program) (u : UMach α) : Prop :=
  u.tags = p.types ∨ (u.tags = #[] ∧ ∀ i c : Nat, (u.m.exacts[i]!)[c]! = none)

theorem units_run {p : Program} (hwf : p.WF) :
    ∀ (ts : List (Tick α)) (u : UMach α), TagsOk p u → UnitsInv N p u.m →
      ∃ m : UMach α, ts.foldlM (fun acc t => UMach.step N p t acc) u = .ok m ∧
        m.erase = ts.foldl (fun m t => Mach.step N p t m) u.m ∧ TagsOk p m ∧ UnitsInv N p m.m := by
  intro ts
  induction ts with
  | nil => intro u h1 h2; exact ⟨u, rfl, rfl, h1, h2⟩
  | cons t ts ih =>
    intro u h1 h2
    obtain ⟨tags, htags, hsz, hall⟩ := tagBuild_ok hwf p.nodes.size (Nat.le_refl _)
    have htypes : tags = p.types := by
      apply arr_ext (by rw [hsz, (wf_iff.1 hwf).1])
      intro i hi
      exact hall i (by omega)
    have hstep : UMach.step N p t u = .ok ⟨Mach.step N p t u.m, tags⟩ := by
      simp only [UMach.step, bind, Except.bind, htags, pure, Except.pure]
    obtain ⟨m, hm, herase, h3, h4⟩ := ih ⟨Mach.step N p t u.m, tags⟩ (Or.inl htypes) (step_unitsInv N hwf t u.m)
    refine ⟨m, ?_, ?_, h3, h4⟩
    · simp only [List.foldlM, bind, Except.bind, hstep]
      exact hm
    · simp only [List.foldl_cons]
      exact herase

theorem l2_units {p : Program} (hwf : p.WF) (coins : Nat) (ts : List (Tick α)) :
    ∃ m : UMach α, ts.foldlM (fun acc t => UMach.step N p t acc) (UMach.init N p coins) = .ok m ∧
      m.erase = Mach.run N p coins ts ∧
      (∀ i, i < p.nodes.size → ∀ (c : Nat) (x : α) (ty : Ty), m.tagged i c = some (x, ty) →
        ty = p.types[i]! ∧ (∀ u, ty ≠ Ty.exact u) ∧ (ty = Ty.bool → ∃ b, x = N.truth b)) ∧
      (∀ i c x u, m.exactTagged i c = some (x, u) →
        p.types[i]? = some (.exact u) ∧ m.erase.exacts[i]![c]! = some x) ∧
      (∀ i c x, m.erase.exacts[i]![c]! = some x → ∃ u, m.exactTagged i c = some (x, u)) := by
  obtain ⟨m, hm, herase, h3, h4⟩ := units_run N hwf ts (UMach.init N p coins)
    (Or.inr ⟨rfl, fun i c => init_exacts_none N p coins i c⟩) (init_unitsInv N p coins)
  have hsz := (wf_iff.1 hwf).1
  have hat : ∀ i, i < p.nodes.size → p.types[i]? = some p.types[i]! := by
    intro i hi
    rw [getElem?_pos p.types i (by rw [hsz]; exact hi), getElem!_pos p.types i (by rw [hsz]; exact hi)]
  refine ⟨m, hm, herase, ?_, ?_, ?_⟩
  · intro i hi c x ty htag
    unfold UMach.tagged at htag
    split at htag
    · rename_i y t' hy ht'
      simp only [Option.some.injEq, Prod.mk.injEq] at htag
      obtain ⟨rfl, rfl⟩ := htag
      rcases h3 with h3 | ⟨h3, _⟩
      · have hty : t' = p.types[i]! := by
          rw [h3, hat i hi] at ht'
          exact (Option.some.inj ht').symm
        refine ⟨hty, fun u hu => ?_, fun hb => h4.bools i hi (hty ▸ hb) c _ hy⟩
        rw [hty] at hu
        rw [h4.floatNone i hi u hu c] at hy
        simp at hy
      · rw [h3] at ht'; simp at ht'
    · simp at htag
  · intro i c x u htag
    unfold UMach.exactTagged at htag
    split at htag
    · rename_i y d hy ht'
      simp only [Option.some.injEq, Prod.mk.injEq] at htag
      obtain ⟨rfl, rfl⟩ := htag
      refine ⟨?_, hy⟩
      rcases h3 with h3 | ⟨h3, _⟩
      · rw [h3] at ht'; exact ht'
      · rw [h3] at ht'; simp at ht'
    · simp at htag
  · intro i c x hx
    by_cases hi : i < p.nodes.size
    · obtain ⟨u, hu⟩ := h4.exactTyped i hi c x hx
      unfold UMach.exactTagged
      rcases h3 with h3 | ⟨_, h3⟩
      · have hmem : m.tags[i]? = some (.exact u) := by rw [h3, hat i hi, hu]
        simp only [UMach.erase] at hx
        rw [hx, hmem]
        exact ⟨u, rfl⟩
      · simp only [UMach.erase] at hx
        rw [h3] at hx
        simp at hx
    · simp only [UMach.erase] at hx
      rw [getElem!_neg m.m.exacts i (by rw [h4.exactSize]; exact hi)] at hx
      have h0 : ((default : Array (Option Rat))[c]!) = none := rfl
      rw [h0] at hx
      simp at hx

end Engine.Lang
