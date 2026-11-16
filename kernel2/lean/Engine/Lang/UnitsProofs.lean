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
  · rw [if_pos h, getElem!_pos _ _ (by simpa using h)]
    simp
  · rw [if_neg h, getElem!_neg _ _ (by simpa using h)]

/-- A node with no memory of its own: `nodeCore` computes it pointwise. -/
def Node.plain : Node → Bool
  | .op .ticksSince _ => false
  | .op .xsMean _ => false
  | .op .xsDemean _ => false
  | .op .xsRank _ => false
  | .op (.window _ _) _ => false
  | _ => true

theorem nodeCore_plain_get (t : Tick α) (n : Node) (hn : n.plain = true) (count coins : Nat)
    (argRows : Nat → Array (Option α)) (ns : Array (NS α)) (c : Nat) :
    (nodeCore N t n count coins argRows ns).1[c]! = if c < coins then (pointVal N t n argRows c).bind N.keep else none := by
  have : nodeCore N t n count coins argRows ns =
      (((List.range coins).map fun c => (pointVal N t n argRows c).bind N.keep).toArray, ns) := by
    unfold nodeCore
    split <;> simp_all [Node.plain]
  rw [this]
  exact rowMap_get coins c _

/-- Every bool-typed node's defined values are `truth` of a bool. -/
def BoolInv (p : Program) (V : Array (Array (Option α))) : Prop :=
  ∀ i : Nat, i < p.nodes.size → p.types[i]! = .bool → ∀ (c : Nat) (x : α), (V[i]!)[c]! = some x →
    ∃ b, x = N.truth b

theorem numOf_not_bool (x : Except String Dim) : (numOf x).toOption ≠ some Ty.bool := by
  cases x <;> simp [numOf, Except.map, Except.toOption]

theorem iteTy_bool {a b : Option Ty} (h : iteTy a b = .ok Ty.bool) : a = some Ty.bool ∧ b = some Ty.bool := by
  unfold iteTy at h
  split at h
  · simp
  · exact absurd (by rw [h]; rfl : (numOf (sameDim _ _)).toOption = some Ty.bool) (numOf_not_bool _)
  · simp at h

theorem opTy_bool {o : Op} {ts : List Ty} (h : opTy o ts = some Ty.bool) :
    o = .gt ∨ o = .ge ∨ o = .lt ∨ o = .le ∨ o = .and ∨ o = .or ∨ o = .not ∨
      (o = .ite ∧ ts[1]? = some Ty.bool ∧ ts[2]? = some Ty.bool) := by
  unfold opTy at h
  unfold opTyE at h
  cases o <;> first | exact absurd h (numOf_not_bool _) | skip
  all_goals first | simp | skip
  rcases h0 : ts[0]? with _ | _ | _ <;> simp_all [Except.toOption, bind, Except.bind, pure, Except.pure]
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
      (nodeCore N t p.nodes[i]! m.count m.coins (argRow (Mach.step N p t m).vals (p.nodes[i]!).args) m.ns[i]!).1 :=
    congrArg Prod.fst (step_row N p t m (wf_ordered hwf) hi)
  have hok := (wf_iff.1 hwf).2.2 i hi
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
  | op o args =>
    obtain ⟨hargs, hty'⟩ := (nodeOkb_op hn).1 hok
    rw [hty] at hty'
    have hplain : (Node.op o args).plain = true := by
      rcases opTy_bool hty' with h | h | h | h | h | h | h | ⟨h, _⟩ <;> subst_vars <;> simp [Node.plain]
    rw [hn] at hrow
    rw [hrow, nodeCore_plain_get N t _ hplain] at hx
    by_cases hc : c < m.coins
    · rw [if_pos hc] at hx
      unfold pointVal at hx
      by_cases hv : t.inView c = true
      · rw [if_pos hv] at hx
        obtain ⟨y, hy, hk⟩ := Option.bind_eq_some_iff.1 hx
        have hxy := keep_some N hk
        subst hxy
        simp only [evalNode] at hy
        rcases opTy_bool hty' with h | h | h | h | h | h | h | ⟨h, h1, h2⟩
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
      · rw [if_neg hv] at hx; simp at hx
    · rw [if_neg hc] at hx; simp at hx

/-- Remembered types are the checker's. -/
def TagsOk (p : Program) (tags : Array (Option Ty)) : Prop :=
  tags.size = p.nodes.size ∧ ∀ i : Nat, i < p.nodes.size → ∀ t : Ty, tags[i]! = some t → t = p.types[i]!

theorem filterMap_tags (p : Program) (ts : Array (Option Ty)) (args : List Nat)
    (hts : ∀ a ∈ args, ∀ t : Ty, ts[a]! = some t → t = p.types[a]!)
    (hall : (args.map (ts[·]!)).all Option.isSome = true) :
    (args.map (ts[·]!)).filterMap id = args.map (p.types[·]!) := by
  induction args with
  | nil => rfl
  | cons a rest ih =>
    simp only [List.map_cons, List.all_cons, Bool.and_eq_true] at hall ⊢
    obtain ⟨h1, h2⟩ := hall
    obtain ⟨t, ht⟩ := Option.isSome_iff_exists.1 h1
    rw [List.filterMap_cons_some (b := t) (by simpa using ht), hts a (by simp) t ht,
      ih (fun b hb => hts b (by simp [hb])) h2]

theorem tagNode_ok {p : Program} (hwf : p.WF) {vals : Array (Array (Option α))} {ts : Array (Option Ty)}
    {prev : Option Ty} {k : Nat} (hk : k < p.nodes.size)
    (hts : ∀ i, i < k → ∀ t : Ty, ts[i]! = some t → t = p.types[i]!)
    (hprev : ∀ t : Ty, prev = some t → t = p.types[k]!) :
    ∃ r, tagNode p vals ts prev k = .ok r ∧ ∀ t : Ty, r = some t → t = p.types[k]! := by
  have hok := (wf_iff.1 hwf).2.2 k hk
  unfold tagNode
  cases hn : p.nodes[k]! with
  | builtin nm =>
    simp only [Program.nodeOkb, hn, Bool.and_eq_true, beq_iff_eq] at hok
    refine ⟨_, rfl, ?_⟩
    intro t ht
    split at ht
    · simpa [hok.2] using ht.symm
    · exact hprev t ht
  | source nm u =>
    simp only [Program.nodeOkb, hn, beq_iff_eq] at hok
    refine ⟨_, rfl, ?_⟩
    intro t ht
    split at ht
    · simp only [Option.some.injEq] at ht; rw [← ht, hok]
    · exact hprev t ht
  | const b u =>
    simp only [Program.nodeOkb, hn, beq_iff_eq] at hok
    refine ⟨_, rfl, ?_⟩
    intro t ht
    split at ht
    · simp only [Option.some.injEq] at ht; rw [← ht, hok]
    · exact hprev t ht
  | op o args =>
    obtain ⟨hargs, hty⟩ := (nodeOkb_op hn).1 hok
    simp only []
    by_cases hall : (args.map (ts[·]!)).all Option.isSome = true
    · rw [if_pos hall]
      have hmap := filterMap_tags p ts args (fun a ha t h => hts a (hargs a ha) t h) hall
      rw [hmap]
      have hE : opTyE o (args.map (p.types[·]!)) = .ok p.types[k]! := by
        unfold opTy at hty
        cases h : opTyE o (args.map (p.types[·]!)) with
        | error e => rw [h] at hty; simp [Except.toOption] at hty
        | ok y => rw [h] at hty; simp [Except.toOption] at hty; rw [hty]
      rw [hE]
      refine ⟨_, rfl, ?_⟩
      intro t ht
      simp [Except.map] at ht
      exact ht.symm
    · rw [if_neg hall]
      exact ⟨_, rfl, hprev⟩

theorem tagBuild_ok {p : Program} (hwf : p.WF) (vals : Array (Array (Option α))) {prev : Array (Option Ty)}
    (hprev : TagsOk p prev) :
    ∀ k, k ≤ p.nodes.size → ∃ ts, tagBuild p vals prev k = .ok ts ∧ ts.size = k ∧
      ∀ i, i < k → ∀ t : Ty, ts[i]! = some t → t = p.types[i]! := by
  intro k
  induction k with
  | zero => intro _; exact ⟨#[], rfl, rfl, fun i hi => by omega⟩
  | succ k ih =>
    intro hk
    obtain ⟨ts, hts, hsz, hall⟩ := ih (by omega)
    obtain ⟨r, hr, hrt⟩ := tagNode_ok (vals := vals) hwf (ts := ts) (prev := prev[k]!) (k := k) (by omega) hall
      (fun t ht => hprev.2 k (by omega) t ht)
    refine ⟨ts.push r, ?_, by simp [hsz], ?_⟩
    · simp only [tagBuild, hts, bind, Except.bind, hr, pure, Except.pure]
    · intro i hi t ht
      by_cases hik : i < k
      · rw [push_get_lt _ _ _ (by omega)] at ht
        exact hall i hik t ht
      · have : i = k := by omega
        subst this
        rw [← hsz, push_get_eq] at ht
        exact hrt t ht

theorem units_run {p : Program} (hwf : p.WF) :
    ∀ (ts : List (Tick α)) (u : UMach α), TagsOk p u.tags → BoolInv N p u.m.vals →
      ∃ m : UMach α, ts.foldlM (fun acc t => UMach.step N p t acc) u = .ok m ∧
        m.erase = ts.foldl (fun m t => Mach.step N p t m) u.m ∧ TagsOk p m.tags ∧ BoolInv N p m.m.vals := by
  intro ts
  induction ts with
  | nil => intro u h1 h2; exact ⟨u, rfl, rfl, h1, h2⟩
  | cons t ts ih =>
    intro u h1 h2
    obtain ⟨tags, htags, hsz, hall⟩ := tagBuild_ok hwf (Mach.step N p t u.m).vals h1 p.nodes.size (Nat.le_refl _)
    have hstep : UMach.step N p t u = .ok ⟨Mach.step N p t u.m, tags⟩ := by
      simp only [UMach.step, bind, Except.bind, htags, pure, Except.pure]
    obtain ⟨m, hm, herase, h3, h4⟩ := ih ⟨Mach.step N p t u.m, tags⟩ ⟨hsz, fun i hi => hall i hi⟩
      (step_boolInv N hwf t u.m)
    refine ⟨m, ?_, ?_, h3, h4⟩
    · simp only [List.foldlM, bind, Except.bind, hstep]
      exact hm
    · simp only [List.foldl_cons]
      exact herase

theorem replicate_none_get (n c : Nat) : (Array.replicate n (none : Option α))[c]! = none := by
  by_cases h : c < n
  · rw [getElem!_pos _ _ (by simpa using h)]
    simp
  · rw [getElem!_neg _ _ (by simpa using h)]
    rfl

theorem init_boolInv (p : Program) (coins : Nat) : BoolInv N p (Mach.init N p coins).vals := by
  intro i hi _ c x hx
  have hrow : (Mach.init N p coins).vals[i]! = Array.replicate coins none := by
    simp only [Mach.init]
    rw [getElem!_pos _ _ (by simpa using hi)]
    simp
  rw [hrow, replicate_none_get] at hx
  simp at hx

theorem l2_units {p : Program} (hwf : p.WF) (coins : Nat) (ts : List (Tick α)) :
    ∃ m : UMach α, ts.foldlM (fun acc t => UMach.step N p t acc) (UMach.init N p coins) = .ok m ∧
      m.erase = Mach.run N p coins ts ∧
      ∀ i, i < p.nodes.size → ∀ (c : Nat) (x : α) (ty : Ty), m.tagged i c = some (x, ty) →
        ty = p.types[i]! ∧ (ty = Ty.bool → ∃ b, x = N.truth b) := by
  have hinit : TagsOk p (UMach.init N p coins).tags := by
    refine ⟨by simp [UMach.init], ?_⟩
    intro i hi t ht
    simp [UMach.init, getElem!_pos, hi] at ht
  obtain ⟨m, hm, herase, h3, h4⟩ := units_run N hwf ts (UMach.init N p coins) hinit (init_boolInv N p coins)
  refine ⟨m, hm, herase, ?_⟩
  intro i hi c x ty htag
  unfold UMach.tagged at htag
  split at htag
  · rename_i y t' hy ht'
    simp only [Option.some.injEq, Prod.mk.injEq] at htag
    obtain ⟨rfl, rfl⟩ := htag
    have hty := h3.2 i hi _ ht'
    exact ⟨hty, fun hb => h4 i hi (hty ▸ hb) c _ hy⟩
  · simp at htag

end Engine.Lang
