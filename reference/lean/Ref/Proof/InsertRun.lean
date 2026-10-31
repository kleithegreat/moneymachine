import Ref.Proof.Insert
import Ref.Proof.TwinRun

/-! L3 for `ifNotRev`: the program with a negation inserted at i runs alike. Its machine keeps every old row one
place on (`Ins`) after every delivery, tick and step, and every other part of its state is equal, so its
schedule, steps and traces are p's. Rewriting node i + 1 in place then gives a twin (`ifNotRev_sound`). -/

namespace Ref
variable {α : Type} [Inhabited α]

/-- x and y fail alike, or succeed with related results. -/
def RelH {ε β γ : Type} (x : Except ε β) (y : Except ε γ) (R : β → γ → Prop) : Prop :=
  match x, y with
  | .ok a, .ok b => R a b
  | .error e, .error e' => e = e'
  | _, _ => False

def StepR {β γ : Type} (R : β → γ → Prop) : ForInStep β → ForInStep γ → Prop
  | .yield a, .yield b => R a b
  | .done a, .done b => R a b
  | _, _ => False

namespace RelH
variable {ε β γ β' γ' : Type} {R : β → γ → Prop}

theorem pure {a : β} {b : γ} (h : R a b) : RelH (Pure.pure a : Except ε β) (Pure.pure b) R := h

theorem throw (e : ε) : RelH (MonadExcept.throw e : Except ε β) (MonadExcept.throw e : Except ε γ) R := rfl

theorem bind {x : Except ε β} {y : Except ε γ} {f : β → Except ε β'} {g : γ → Except ε γ'} {S : β' → γ' → Prop}
    (hx : RelH x y R) (hf : ∀ a b, R a b → RelH (f a) (g b) S) : RelH (x >>= f) (y >>= g) S := by
  cases x <;> cases y <;> simp only [RelH] at hx ⊢ <;> first | exact hx.elim | exact hx | exact hf _ _ hx

theorem ite {c : Prop} [Decidable c] {x x' : Except ε β} {y y' : Except ε γ} (h₁ : c → RelH x y R)
    (h₂ : ¬c → RelH x' y' R) : RelH (if c then x else x') (if c then y else y') R := by
  split
  · exact h₁ ‹_›
  · exact h₂ ‹_›

theorem throw_bind {e : ε} {f : β → Except ε β'} {g : γ → Except ε γ'} {S : β' → γ' → Prop} :
    RelH ((MonadExcept.throw e : Except ε β) >>= f) ((MonadExcept.throw e : Except ε γ) >>= g) S := rfl

theorem forIn {δ : Type} (l : List δ) {a : β} {b : γ} (f : δ → β → Except ε (ForInStep β))
    (g : δ → γ → Except ε (ForInStep γ)) (h0 : R a b)
    (hf : ∀ v ∈ l, ∀ a b, R a b → RelH (f v a) (g v b) (StepR R)) : RelH (forIn l a f) (forIn l b g) R := by
  induction l generalizing a b with
  | nil => exact h0
  | cons v l ih =>
    rw [List.forIn_cons, List.forIn_cons]
    refine bind (hf v (by simp) a b h0) fun s t hst => ?_
    cases s <;> cases t <;> simp only [StepR] at hst <;>
      first | exact hst.elim | exact hst | exact ih hst fun v' hv' => hf v' (by simp [hv'])

theorem map {x : Except ε β} {y : Except ε γ} {f : β → β'} {g : γ → β'} (h : RelH x y R)
    (hfg : ∀ a b, R a b → f a = g b) : x.map f = y.map g := by
  cases x <;> cases y <;> simp only [RelH] at h <;> simp [Except.map, h] <;> first | exact h.elim | exact hfg _ _ h

theorem join {c : Prop} [Decidable c] {x : Except ε β} {y : Except ε γ} {a : β} {b : γ} {k : β → Except ε β'}
    {k' : γ → Except ε γ'} {S : β' → γ' → Prop} (hx : c → RelH x y R) (hb : ¬c → R a b)
    (hk : ∀ a b, R a b → RelH (k a) (k' b) S) : RelH (if c then x >>= k else k a) (if c then y >>= k' else k' b) S :=
  ite (fun h => bind (hx h) hk) fun h => hk a b (hb h)

theorem ok {a : β} {b : γ} (h : R a b) : RelH (Except.ok a : Except ε β) (Except.ok b) R := h

theorem map_rel {x : Except ε β} {y : Except ε γ} {f : β → β'} {g : γ → γ'} {S : β' → γ' → Prop}
    (h : RelH x y R) (hfg : ∀ a b, R a b → S (f a) (g b)) : RelH (x.map f) (y.map g) S := by
  cases x <;> cases y <;> simp only [RelH, Except.map] at h ⊢ <;> first | exact h.elim | exact h | exact hfg _ _ h

end RelH

/-- The facts the run needs about q, p with a negation of an earlier node inserted at i. -/
structure InsProg (p q : Program) (i : Nat) : Prop where
  pos : 0 < i
  le : i ≤ p.nodes.size
  size : q.nodes.size = p.nodes.size + 1
  node : ∀ k < p.nodes.size, q.nodes[shift i k]! = p.nodes[k]!.mapArgs (shift i)
  params : q.params = p.params
  new : ∃ c₀, q.nodes[i]! = .op .not [c₀]
  weight : q.weight = shift i p.weight

/-- States alike but for their machines, which correspond. -/
def SRel (i : Nat) (a b : SState α) : Prop := b = { a with machine := b.machine } ∧ Ins i a.machine b.machine

theorem Ins.local {i : Nat} {M M' : MState α} (h : Ins i M M') : M' = M.withLocal M'.vals M'.wins M'.since := by
  have := h.latest; have := h.hour; have := h.maxKnown
  cases M; cases M'
  simp_all [MState.withLocal]

theorem filterMap_insertIdx {β γ : Type} (g : β → Option γ) (l : List β) (k : Nat) (x : β) (hx : g x = none) :
    (l.insertIdx k x).filterMap g = l.filterMap g := by
  induction l generalizing k with
  | nil => cases k <;> simp [hx]
  | cons a l ih =>
    cases k with
    | zero => simp [hx]
    | succ k => simp [List.insertIdx_succ_cons, List.filterMap_cons, ih]

theorem insProg_of {p : Program} {i c : Nat} (hi0 : 0 < i) (hi : i ≤ p.nodes.size) :
    InsProg p (p.insertAt i (.op .not [c]) .bool) i where
  pos := hi0
  le := hi
  size := ins_size hi
  node := fun _ hk => ins_node hi hk
  params := rfl
  new := ⟨c, ins_new hi⟩
  weight := rfl

theorem replicate_shift {β : Type} [Inhabited β] {i n : Nat} (hi : i ≤ n) (x : β) (k : Nat) :
    (Array.replicate (n + 1) x)[shift i k]! = (Array.replicate n x)[k]! := by
  have hsz : shift i k < n + 1 ↔ k < n := by unfold shift; split <;> omega
  by_cases hk : k < n
  · rw [getElem!_pos _ _ (by simpa using hsz.mpr hk), getElem!_pos _ _ (by simpa using hk)]; simp
  · rw [getElem!_neg _ _ (by simpa using fun h => hk (hsz.mp h)), getElem!_neg _ _ (by simpa using hk)]

theorem init_ins (N : NumOps α) {p q : Program} {i : Nat} (P : InsProg p q i) (sources coins : Nat) :
    Ins i (MState.init N p sources coins) (MState.init N q sources coins) where
  vals k := by unfold MState.init; rw [P.size]; exact replicate_shift P.le _ k
  since k := by unfold MState.init; rw [P.size]; exact replicate_shift P.le _ k
  wins k := by
    unfold MState.init
    have hsz : shift i k < q.nodes.size ↔ k < p.nodes.size := by
      have := P.le; rw [P.size]; unfold shift; split <;> omega
    by_cases hk : k < p.nodes.size
    · rw [getElem!_pos _ _ (by simpa using hsz.mpr hk), getElem!_pos _ _ (by simpa using hk), Array.getElem_map,
        Array.getElem_map, ← getElem!_pos q.nodes _ (hsz.mpr hk), ← getElem!_pos p.nodes _ hk, P.node k hk]
      cases p.nodes[k]! with
      | op o args => cases o <;> rfl
      | _ => rfl
    · rw [getElem!_neg _ _ (by simpa using fun h => hk (hsz.mp h)), getElem!_neg _ _ (by simpa using hk)]
  vsize := by simp [MState.init, P.size]
  wsize := by simp [MState.init, P.size]
  ssize := by simp [MState.init, P.size]
  ival := by simpa [MState.init] using P.le
  iwin := by simpa [MState.init] using P.le
  isin := by simpa [MState.init] using P.le
  latest := rfl
  hour := rfl
  maxKnown := rfl

theorem deliver_ins (c : Ctx α) {i : Nat} {a b : SState α} (h : SRel i a b) (t : Int) :
    RelH (c.deliver a t) (c.deliver b t) (SRel i) := by
  obtain ⟨hb, hI⟩ := h
  have e : b = { a with machine := a.machine.withLocal b.machine.vals b.machine.wins b.machine.since } := by
    rw [← hI.local]; exact hb
  rw [e, deliver_local]
  cases hd : c.deliver a t with
  | error e => rfl
  | ok r =>
    obtain ⟨hv, hw, hs⟩ := deliver_keeps_local c a r t hd
    refine ⟨rfl, ?_⟩
    exact {
      vals := fun k => by simp only [MState.withLocal, hv]; exact hI.vals k
      wins := fun k => by simp only [MState.withLocal, hw]; exact hI.wins k
      since := fun k => by simp only [MState.withLocal, hs]; exact hI.since k
      vsize := by simp only [MState.withLocal, hv]; exact hI.vsize
      wsize := by simp only [MState.withLocal, hw]; exact hI.wsize
      ssize := by simp only [MState.withLocal, hs]; exact hI.ssize
      ival := by rw [hv]; exact hI.ival
      iwin := by rw [hw]; exact hI.iwin
      isin := by rw [hs]; exact hI.isin
      latest := rfl, hour := rfl, maxKnown := rfl }

theorem SRel.machine {i : Nat} {a b : SState α} (h : SRel i a b) {X X' : MState α} (hX : Ins i X X') :
    SRel i { a with machine := X } { b with machine := X' } := by
  obtain ⟨hb, -⟩ := h
  refine ⟨?_, hX⟩
  rw [hb]

theorem SRel.exists {i : Nat} {a b : SState α} (h : SRel i a b) :
    ∃ M', b = { a with machine := M' } ∧ Ins i a.machine M' := ⟨b.machine, h.1, h.2⟩

theorem SRel.same {i : Nat} {a : SState α} {M' : MState α} (h : Ins i a.machine M') :
    SRel i a { a with machine := M' } := ⟨rfl, h⟩

theorem execute_ins (N : NumOps α) (c : Ctx α) {i : Nat} {a b : SState α} (h : SRel i a b) (f : Fill α) :
    RelH (c.execute N a f) (c.execute N b f) (SRel i) := by
  obtain ⟨M', rfl, hI⟩ := h.exists
  unfold Ctx.execute
  cases checkFill N f c.bars c.ix c.v with
  | error e => rfl
  | ok u => exact RelH.bind (RelH.ok (R := fun _ _ => True) trivial) fun _ _ _ => RelH.pure (SRel.same hI)

theorem bankrupt_ins (N : NumOps α) (c : Ctx α) {i : Nat} {a b : SState α} (h : SRel i a b) (t : Int)
    (adv : Nat → α → α) (lat : List (Nat × BarRow α)) :
    RelH (c.bankrupt N a t adv lat) (c.bankrupt N b t adv lat) (SRel i) := by
  obtain ⟨M', rfl, hI⟩ := h.exists
  unfold Ctx.bankrupt
  refine RelH.ite (fun _ => SRel.same hI) fun _ => RelH.bind (RelH.forIn _ _ _ (SRel.same hI) fun x _ a b hab =>
    RelH.bind (execute_ins N c hab _) fun a b hab => hab) fun a b hab => ?_
  obtain ⟨M'', rfl, hI'⟩ := hab.exists
  exact RelH.pure (SRel.same hI')

section
variable (N : NumOps α) {p q : Program} {i : Nat} (P : InsProg p q i) (ctx : Ctx α)
include P
set_option quotPrecheck false
local notation "C" => ({ ctx with p := p } : Ctx α)
local notation "C'" => ({ ctx with p := q } : Ctx α)

theorem tickLoop_ins (base : Int) (ks : List Nat) {a b : SState α} (h : SRel i a b) :
    RelH ((C).tickLoop N base ks a) ((C').tickLoop N base ks b) (SRel i) := by
  unfold Ctx.tickLoop
  refine RelH.forIn _ _ _ h fun k _ a b hab => ?_
  rw [← deliver_prog p q ctx]
  refine RelH.bind (deliver_ins _ hab _) fun a b hab => ?_
  obtain ⟨c₀, hnew⟩ := P.new
  exact RelH.pure (hab.machine (tick_ins N P.pos P.le P.size P.node P.params hnew _ _ hab.2))

theorem start_ins : RelH ((C).start N) ((C').start N) (SRel i) := by
  unfold Ctx.start
  rw [← deliver_prog p q ctx]
  have h0 : SRel i ((C).state0 N) ((C').state0 N) := ⟨rfl, init_ins N P _ _⟩
  refine RelH.bind (deliver_ins _ h0 _) fun a b hab => ?_
  obtain ⟨c₀, hnew⟩ := P.new
  exact RelH.pure (hab.machine (tick_ins N P.pos P.le P.size P.node P.params hnew _ _ hab.2))

theorem machineAfter_ins (n : Nat) :
    RelH ((C).machineAfter N n) ((C').machineAfter N n) (Ins i) := by
  rw [Ctx.machineAfter_eq, Ctx.machineAfter_eq]
  exact RelH.map_rel (RelH.bind (start_ins N P ctx) fun a b hab =>
    tickLoop_ins N P ctx ctx.pol.wStart (List.range' 1 n) hab) fun a b hab => hab.2
theorem step_ins (b : Int) {s s' : SState α} (h : SRel i s s') :
    RelH ((C).step N s b) ((C').step N s' b) (SRel i) := by
  have e₁ : (C').bars = (C).bars := rfl
  have e₂ : (C').ix = (C).ix := rfl
  have e₃ : (C').v = (C).v := rfl
  have e₄ : (C').pol = (C).pol := rfl
  have e₅ : (C').stop = (C).stop := rfl
  have e₆ : (C').coins = (C).coins := rfl
  have e₇ : (C').mask = (C).mask := rfl
  have e₈ : Ctx.execute N C' = Ctx.execute N C := rfl
  have e₉ : Ctx.closeout N C' = Ctx.closeout N C := rfl
  have e₁₀ : Ctx.bankrupt N C' = Ctx.bankrupt N C := rfl
  obtain ⟨hs, hI⟩ := h
  generalize s'.machine = M' at hs hI
  subst hs
  unfold Ctx.step
  simp only [Std.Legacy.Range.forIn_eq_forIn_range', e₁, e₂, e₃, e₄, e₅, e₆, e₇, e₈, e₉, e₁₀]
  refine RelH.bind (RelH.forIn _ _ _ (SRel.same hI) fun k _ x y hxy => ?_) fun s₁ s₁' h₁ => ?_
  · obtain ⟨My, rfl, hIy⟩ := hxy.exists
    refine RelH.bind (RelH.forIn _ _ _ (SRel.same hIy) fun c _ x y hxy => ?_) fun a b hab => hab
    obtain ⟨My, rfl, hIy⟩ := hxy.exists
    split
    · exact RelH.pure ⟨rfl, hIy⟩
    · exact RelH.throw_bind
  obtain ⟨M₁, rfl, hI₁⟩ := h₁.exists
  rw [marks_loop_rewrite, marks_loop_rewrite]
  refine RelH.bind (R := SRel i) (RelH.ok ⟨rfl, hI₁⟩) fun s₂ s₂' h₂ => ?_
  obtain ⟨M₂, rfl, hI₂⟩ := h₂.exists
  refine RelH.join (R := SRel i) (fun _ => RelH.forIn _ _ _ ⟨rfl, hI₂⟩ fun x _ a b hab =>
    RelH.bind (execute_ins N _ hab _) fun a b hab => RelH.pure hab) (fun _ => ⟨rfl, hI₂⟩) fun s₃ s₃' h₃ => ?_
  obtain ⟨M₃, rfl, hI₃⟩ := h₃.exists
  refine RelH.bind (R := SRel i) (RelH.forIn _ _ _ ⟨rfl, hI₃⟩ fun x _ a b hab => ?_) fun s₄ s₄' h₄ => ?_
  · obtain ⟨Mb, rfl, hIb⟩ := hab.exists
    exact RelH.ite (fun _ => RelH.bind (execute_ins N _ ⟨rfl, hIb⟩ _) fun a b hab => RelH.pure hab)
      fun _ => RelH.pure ⟨rfl, hIb⟩
  refine RelH.bind (R := SRel i) (bankrupt_ins N _ h₄ _ _ _) fun s₅ s₅' h₅ => ?_
  obtain ⟨M₅, rfl, hI₅⟩ := h₅.exists
  refine RelH.ite (fun _ => RelH.throw_bind) fun _ => ?_
  refine RelH.ite (fun _ => RelH.throw_bind) fun _ => ?_
  refine RelH.join (R := SRel i) (fun _ => RelH.forIn _ _ _ ⟨rfl, hI₅⟩ fun o _ a b hab => ?_) (fun _ => ⟨rfl, hI₅⟩)
    fun s₆ s₆' h₆ => ?_
  · obtain ⟨Mb, rfl, hIb⟩ := hab.exists
    split
    · exact RelH.ite (fun _ => RelH.bind (execute_ins N _ ⟨rfl, hIb⟩ _) fun a b hab => RelH.pure hab)
        fun _ => RelH.pure ⟨rfl, hIb⟩
    · exact RelH.pure ⟨rfl, hIb⟩
  refine RelH.bind (tickLoop_ins N P ctx b (List.range' 1 4) h₆) fun r r' hr => ?_
  obtain ⟨Mr, rfl, hIr⟩ := hr.exists
  have hq : (C').p = q := rfl
  have hp : (C).p = p := rfl
  refine RelH.bind (R := fun st st' => SRel i st.1 st'.1 ∧ st'.2 = st.2)
    (RelH.forIn _ _ _ ⟨⟨rfl, hIr⟩, rfl⟩ fun c _ st st' hst => ?_) fun st st' hst => ?_
  · obtain ⟨a, ws⟩ := st
    obtain ⟨b', ws'⟩ := st'
    obtain ⟨hab, hws⟩ := hst
    dsimp only at hab hws
    subst hws
    obtain ⟨Mb, rfl, hIb⟩ := hab.exists
    dsimp only
    rw [hIb.latest, P.weight, hIb.vals]
    refine RelH.ite (fun _ => RelH.pure ⟨⟨rfl, hIb⟩, rfl⟩) fun _ => RelH.ite (fun _ => RelH.pure ⟨⟨rfl, hIb⟩, rfl⟩)
      fun _ => ?_
    cases a.machine.vals[p.weight]![c]! <;> exact RelH.pure ⟨⟨rfl, hIb⟩, rfl⟩
  obtain ⟨a, ws⟩ := st
  obtain ⟨b', ws'⟩ := st'
  obtain ⟨hab, hws⟩ := hst
  dsimp only at hab hws
  subst hws
  obtain ⟨Mb, rfl, hIb⟩ := hab.exists
  refine RelH.ite (fun _ => RelH.throw_bind) fun _ => ?_
  refine RelH.bind (R := SRel i) (RelH.forIn _ _ _ ⟨rfl, hIb⟩ fun x _ a b hab => ?_) fun s₉ s₉' h₉ => RelH.pure h₉
  obtain ⟨Mc, rfl, hIc⟩ := hab.exists
  dsimp only
  rw [hIc.latest, hIc.maxKnown]
  repeat (first | exact RelH.pure ⟨rfl, hIc⟩ | refine RelH.ite (fun _ => ?_) (fun _ => ?_))

theorem steps_ins (n : Nat) :
    RelH ((C).steps N n) ((C').steps N n) (SRel i) := by
  unfold Ctx.steps
  rw [show (C').bounds = (C).bounds from rfl]
  exact RelH.bind (start_ins N P ctx) fun a b hab => RelH.bind (RelH.forIn _ _ _ hab fun bb _ x y hxy =>
    RelH.bind (step_ins N P ctx bb hxy) fun x y h => RelH.pure h) fun x y h => RelH.pure h
end


/-- `ite(c, b, a)` at i + 1 equals `ite(not c, a, b)`, its negation sitting at i, on the rows a tick has written. -/
theorem ifNotRev_eval (N : NumOps α) (hN : N.Lawful) {q : Program} {i c a b : Nat}
    (hn : q.nodes[i + 1]! = .op .ite [c, b, a]) (hc : q.nodes[i]! = .op .not [c]) (L : Array Bool) (m s : MState α)
    (hd : Done N q L m (i + 1) s) (c' : Nat) (hl : L[c']! = true) :
    MState.eval N { q with nodes := q.nodes.set! (i + 1) (.op .ite [i, a, b]) } s (i + 1) c' =
      MState.eval N q s (i + 1) c' := by
  have hi := op_lt hn
  simp only [MState.eval, hn, Array.getElem!_set!_self _ _ _ hi, List.getElem!_cons_zero, List.getElem!_cons_succ]
  rw [row_listed hd (Nat.lt_succ_self i) (by rw [hc]; try rfl) hl]
  simp only [MState.eval, hc, List.getElem!_cons_zero]
  generalize s.vals[c]![c']! = C
  cases C with
  | none => rfl
  | some v =>
    simp only [NumOps.keep, hN.finite_truth, Option.bind_some, ite_true, bind, Option.bind, hN.truth_zero]
    cases N.isZero v <;> rfl

theorem RelH.eq_of {ε β : Type} {x y : Except ε β} (h : RelH x y (· = ·)) : x = y := by
  cases x <;> cases y <;> simp only [RelH] at h <;> first | exact h.elim | rw [h]

theorem sources_insert {p : Program} {i c : Nat} (hi : i ≤ p.nodes.size) :
    (p.insertAt i (.op .not [c]) .bool).sources = p.sources := by
  unfold Program.sources Program.insertAt
  dsimp only
  rw [Array.insertIdx!, dif_pos (by simpa using hi), Array.toList_insertIdx,
    filterMap_insertIdx _ _ _ _ rfl, Array.toList_map, List.filterMap_map]
  congr 1
  congr 1
  funext n
  cases n <;> rfl

/-- L3 for `ifNotRev`: an insertion of `not c` at i, then node i + 1 rewritten in place. -/
theorem ifNotRev_sound (N : NumOps α) (hN : N.Lawful) {reg : Registry} {p p' : Program} {i : Nat} (hp : p.WF reg)
    (h : Rule.ifNotRev.apply p i = some p') (ctx : Ctx α) :
    p'.WF reg ∧ p'.sources = p.sources ∧
    (∀ n, (({ ctx with p := p' } : Ctx α).machineAfter N n).isOk = (({ ctx with p := p } : Ctx α).machineAfter N n).isOk ∧
      ∀ ms ms', ({ ctx with p := p } : Ctx α).machineAfter N n = .ok ms → ({ ctx with p := p' } : Ctx α).machineAfter N n = .ok ms' →
         ∀ k < p.nodes.size, ms'.vals[Rule.ifNotRev.corr i k]! = ms.vals[k]!) ∧
    (∀ j, (({ ctx with p := p' } : Ctx α).steps N j).map (·.trace) = (({ ctx with p := p } : Ctx α).steps N j).map (·.trace)) ∧
    ({ ctx with p := p' } : Ctx α).evaluate N = ({ ctx with p := p } : Ctx α).evaluate N := by
  unfold Rule.apply at h
  split at h
  all_goals first | contradiction | (cases h; done) | skip
  rename_i c b a _ hn
  simp only [Option.some.injEq] at h
  subst h
  have hi := op_lt hn
  obtain ⟨hai, hti⟩ := WF.op hp hi hn
  have hci : c < i := hai c (by simp)
  have hbi : b < i := hai b (by simp)
  have hai' : a < i := hai a (by simp)
  simp only [List.map_cons, List.map_nil] at hti
  have hcb := (opTy_ite (to' := p.convTo[i]!) hti).1
  have hq : (p.insertAt i (.op .not [c]) .bool).WF reg := insert_wf hp hi hci hcb
  have P : InsProg p (p.insertAt i (.op .not [c]) .bool) i := insProg_of (by omega) (by omega)
  have hn₁ : (p.insertAt i (.op .not [c]) .bool).nodes[i + 1]! = .op .ite [c, b, a] := by
    have := P.node i hi
    rw [shift_ge (Nat.le_refl i), hn] at this
    rw [this]; simp [Node.mapArgs, shift_lt hci, shift_lt hbi, shift_lt hai']
  have hc₁ : (p.insertAt i (.op .not [c]) .bool).nodes[i]! = .op .not [c] := ins_new (by omega)
  have hiT : i ≤ p.types.size := by obtain ⟨h1, h2, h3, -⟩ := hp; omega
  have hiC : i ≤ p.convTo.size := by obtain ⟨h1, h2, h3, -⟩ := hp; omega
  have hT : ∀ j, (p.insertAt i (.op .not [c]) .bool).types[shift i j]! = p.types[j]! := fun j => insert_shift _ hiT _ j
  have hC : (p.insertAt i (.op .not [c]) .bool).convTo[i + 1]! = p.convTo[i]! := by
    have := insert_shift p.convTo hiC (none : Option Dim) i; rwa [if_pos (Nat.le_refl i)] at this
  have hTi : (p.insertAt i (.op .not [c]) .bool).types[i]! = .bool := by
    show (p.types.insertIdx! i .bool)[i]! = .bool; rw [insert_get _ hiT]; simp
  have T := twin_set N hq (i := i + 1) (by rw [P.size]; omega) (o := .ite) (args := [i, a, b])
    (fun x hx => by simp only [List.mem_cons, List.not_mem_nil, or_false] at hx; omega)
    (by
      have ha := hT a; have hb := hT b; have hi1 := hT i
      rw [shift_lt hai'] at ha; rw [shift_lt hbi] at hb; rw [shift_ge (Nat.le_refl i)] at hi1
      simp only [List.map_cons, List.map_nil, hTi, ha, hb, hi1, hC]
      exact (opTy_ite hti).2)
    (by rw [hn₁]; rfl) rfl hn₁ (ifNotRev_eval N hN hn₁ hc₁)
  have hcorr : ∀ k, Rule.ifNotRev.corr i k = shift i k := fun k => by simp [Rule.corr, shift]
  refine ⟨T.wf', (sources_twin T).trans (sources_insert (by omega)), fun n => ?_, fun j => ?_, ?_⟩
  · rw [machineAfter_twin T ctx n]
    have R := machineAfter_ins N P ctx n
    refine ⟨?_, fun ms ms' h₁ h₂ k _ => ?_⟩
    · revert R
      cases ({ ctx with p := p } : Ctx α).machineAfter N n <;>
        cases ({ ctx with p := p.insertAt i (.op .not [c]) .bool } : Ctx α).machineAfter N n <;> simp [RelH, Except.isOk, Except.toBool]
    · rw [h₁, h₂] at R
      rw [hcorr]; exact R.vals k
  · rw [steps_twin T ctx]
    exact (RelH.map (steps_ins N P ctx j) fun a b hab => by
      obtain ⟨M, rfl, -⟩ := hab.exists; rfl).symm
  · rw [evaluate_twin T ctx]
    refine (RelH.eq_of ?_).symm
    unfold Ctx.evaluate
    dsimp only
    rw [show ({ ctx with p := p.insertAt i (.op .not [c]) .bool } : Ctx α).bounds = ({ ctx with p := p } : Ctx α).bounds from rfl]
    exact RelH.bind (steps_ins N P ctx _) fun a b hab => by
      obtain ⟨M, rfl, -⟩ := hab.exists; rfl
end Ref
