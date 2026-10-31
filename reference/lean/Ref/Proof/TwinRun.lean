import Ref.Proof.Twin
import Ref.Proof.Local

namespace Ref

variable {α : Type} [Inhabited α] {reg : Registry}

def TwinEq {ε β : Type} (x y : Except ε β) (Q : β → Prop) : Prop := x = y ∧ Except.Holds x Q

namespace TwinEq
variable {ε β γ : Type} {Q : β → Prop}

theorem pure (b : β) (h : Q b) : TwinEq (Except.pure b : Except ε β) (Except.pure b) Q :=
  ⟨rfl, Except.Holds.pure b h⟩

theorem refl {x : Except ε β} (h : Except.Holds x Q) : TwinEq x x Q := ⟨rfl, h⟩

theorem bind {R : β → Prop} {x y : Except ε β} {f g : β → Except ε γ} {Q : γ → Prop}
    (hx : TwinEq x y R) (hf : ∀ b, R b → TwinEq (f b) (g b) Q) : TwinEq (x >>= f) (y >>= g) Q := by
  refine ⟨?_, Except.Holds.bind hx.2 fun b hb => (hf b hb).2⟩
  rw [← hx.1]
  cases h : x with
  | error e => rfl
  | ok b => exact (hf b (hx.2 b h)).1

theorem ite {c : Prop} [Decidable c] {x y x' y' : Except ε β}
    (h : c → TwinEq x y Q) (h' : ¬c → TwinEq x' y' Q) :
    TwinEq (if c then x else x') (if c then y else y') Q := by
  split
  · exact h ‹_›
  · exact h' ‹_›

theorem forIn {δ σ : Type} (l : List δ) (init : σ) (f g : δ → σ → Except ε (ForInStep σ)) (I : σ → Prop)
    (h0 : I init) (hf : ∀ a ∈ l, ∀ s, I s → TwinEq (f a s) (g a s) (fun r => I r.value)) :
    TwinEq (ForIn.forIn l init f) (ForIn.forIn l init g) I := by
  induction l generalizing init with
  | nil => exact pure init h0
  | cons a as ih =>
    simp only [List.forIn_cons]
    refine bind (hf a (by simp) init h0) fun r hr => ?_
    cases r with
    | done s => exact pure s hr
    | yield s => exact ih s hr fun a' ha' => hf a' (by simp [ha'])

theorem throw_bind {e : ε} {f g : β → Except ε γ} {Q : γ → Prop} :
    TwinEq ((throw e : Except ε β) >>= f) ((throw e : Except ε β) >>= g) Q := ⟨rfl, fun _ h => by cases h⟩

theorem join {c : Prop} [Decidable c] {R : β → Prop} {x y : Except ε β} {b : β} {f g : β → Except ε γ}
    {Q : γ → Prop} (hx : c → TwinEq x y R) (hb : ¬c → R b) (hf : ∀ b, R b → TwinEq (f b) (g b) Q) :
    TwinEq (if c then x >>= f else f b) (if c then y >>= g else g b) Q :=
  ite (fun h => bind (hx h) hf) fun h => hf b (hb h)
end TwinEq

theorem shape_size {p : Program} {L L' : Array Bool} {m : MState α} (h : Shape p L m) (hL : L'.size = L.size) :
    Shape p L' m := ⟨h.size, fun a ha => (h.rows a ha).trans hL.symm, h.wins⟩

def Fits (p : Program) (coins : Nat) (m : MState α) : Prop := Shape p (Array.replicate coins false) m

theorem fits_init (N : NumOps α) (p : Program) (sources coins : Nat) : Fits p coins (MState.init N p sources coins) := by
  refine ⟨by simp [MState.init], fun a ha => ?_, fun a ha hw c => ?_⟩
  · simp only [MState.init]
    rw [getElem!_pos (Array.replicate _ _) a (by simpa using ha)]; simp
  · simp only [MState.init]
    rw [getElem!_pos _ a (by simpa using ha), Array.getElem_map]
    rw [getElem!_pos p.nodes a ha] at hw
    generalize p.nodes[a] = n at hw ⊢
    have hr : ∀ c, (Array.replicate coins (none : Option (Win α)))[c]! = none := fun c => by
      rcases Nat.lt_or_ge c coins with hc | hc
      · rw [getElem!_pos _ c (by simpa using hc)]; simp
      · rw [getElem!_neg _ c (by simp; omega)]; rfl
    cases n with
    | op o args => cases o <;> first | exact hr c | cases hw
    | _ => exact hr c

theorem fits_deliver {c : Ctx α} {p : Program} {coins : Nat} {s r : SState α} {t : Int} (h : c.deliver s t = .ok r)
    (hs : Fits p coins s.machine) : Fits p coins r.machine := by
  obtain ⟨hv, hw, -⟩ := deliver_keeps_local c s r t h
  exact ⟨hv ▸ hs.size, fun a ha => hv ▸ hs.rows a ha, fun a ha hn => hw ▸ hs.wins a ha hn⟩

theorem fits_tick (N : NumOps α) {p : Program} (hp : p.WF reg) {coins : Nat} {L : Array Bool} (hL : L.size = coins)
    (hour : Int) {m : MState α} (hm : Fits p coins m) : Fits p coins (m.tick N p L hour) :=
  shape_size (tick_spec N p hp L hour m (shape_size hm (by simp [hL]))).1.shape (by simp [hL])

theorem mask_size (c : Ctx α) (t : Int) : (c.mask t).size = c.coins := by simp [Ctx.mask]

theorem deliver_prog (p p' : Program) (c : Ctx α) (s : SState α) (t : Int) :
    ({ c with p := p' } : Ctx α).deliver s t = ({ c with p := p } : Ctx α).deliver s t := by
  fun_induction Ctx.deliver ({ c with p := p } : Ctx α) s t <;>
    rw [Ctx.deliver] <;> simp_all (config := { zetaDelta := true })
  all_goals intro; omega

theorem marks_loop_rewrite (l : List (Nat × BarRow α)) (s : SState α) :
    forIn l s (fun x s => (pure (ForInStep.yield { s with marks := s.marks.set! x.1 x.2.c }) :
      Except Abort (ForInStep (SState α)))) = .ok { s with marks := l.foldl (fun mk y => mk.set! y.1 y.2.c) s.marks } := by
  induction l generalizing s with
  | nil => rfl
  | cons x l ih => rw [List.forIn_cons, List.foldl_cons]; exact ih _

def Good (p : Program) (coins i j : Nat) (s : SState α) : Prop :=
  Fits p coins s.machine ∧ s.machine.vals[i]! = s.machine.vals[j]!

section
variable {N : NumOps α} {p p' : Program} {i j : Nat} (T : Twin (reg := reg) N p p' i j) (c : Ctx α)
include T
set_option quotPrecheck false
local notation "C" => ({ c with p := p } : Ctx α)
local notation "C'" => ({ c with p := p' } : Ctx α)

theorem tick_fits {L : Array Bool} (hL : L.size = c.coins) (hour : Int) {mm : MState α}
    (hm : Fits p c.coins mm) : mm.tick N p' L hour = mm.tick N p L hour :=
  (tick_twin T L hour mm (shape_size hm (by simp [hL]))).1

theorem tick_good {L : Array Bool} (hL : L.size = c.coins) (hour : Int) {mm : MState α}
    (hm : Fits p c.coins mm) :
    Fits p c.coins (mm.tick N p L hour) ∧ (mm.tick N p L hour).vals[i]! = (mm.tick N p L hour).vals[j]! :=
  ⟨fits_tick N T.wf hL _ hm, (tick_twin T L hour mm (shape_size hm (by simp [hL]))).2⟩

theorem tickLoop_twin (b : Int) (ks : List Nat) (s : SState α) (hs : Good p c.coins i j s) :
    TwinEq ((C').tickLoop N b ks s) ((C).tickLoop N b ks s) (Good p c.coins i j) := by
  unfold Ctx.tickLoop
  refine TwinEq.forIn _ _ _ _ _ hs fun k _ s hs => ?_
  refine TwinEq.bind (R := fun r => Fits p c.coins r.machine)
    ⟨deliver_prog p p' c _ _, fun r hr => fits_deliver hr hs.1⟩ fun r hr => ?_
  dsimp only
  change TwinEq (pure (ForInStep.yield { r with machine := r.machine.tick N p' ((C).mask (b + (k : Int) * HOUR)) (b + (k : Int) * HOUR) }))
    (pure (ForInStep.yield { r with machine := r.machine.tick N p ((C).mask (b + (k : Int) * HOUR)) (b + (k : Int) * HOUR) })) _
  rw [tick_fits T c (mask_size C _) _ hr]
  exact TwinEq.pure _ (tick_good T c (mask_size C _) _ hr)

theorem start_twin : TwinEq ((C').start N) ((C).start N) (Good p c.coins i j) := by
  have h0 : (C').state0 N = (C).state0 N := by
    simp only [Ctx.state0]; rw [init_twin T]; rfl
  unfold Ctx.start
  rw [h0]
  refine TwinEq.bind (R := fun r => Fits p c.coins r.machine)
    ⟨deliver_prog p p' c _ _, fun r hr => fits_deliver hr (fits_init N p c.reg.decls.size c.coins)⟩ fun r hr => ?_
  change TwinEq (pure { r with machine := r.machine.tick N p' ((C).mask c.pol.wStart) c.pol.wStart })
    (pure { r with machine := r.machine.tick N p ((C).mask c.pol.wStart) c.pol.wStart }) _
  rw [tick_fits T c (mask_size C _) _ hr]
  exact TwinEq.pure _ (tick_good T c (mask_size C _) _ hr)

set_option maxHeartbeats 1600000 in
theorem step_twin (b : Int) (s : SState α) (hs : Good p c.coins i j s) :
    TwinEq ((C').step N s b) ((C).step N s b) (Good p c.coins i j) := by
  refine ⟨(?_ : TwinEq _ _ (fun _ => True)).1, fun r hr => ?_⟩
  rotate_left
  · obtain ⟨q, hq, hpq⟩ := step_proj N C' s b r hr
    have hg := (tickLoop_twin T c b (List.range' 1 4) s hs).2 q hq
    have hm : q.machine = r.machine := (congrArg Prod.fst hpq).symm
    exact ⟨hm ▸ hg.1, hm ▸ hg.2⟩
  unfold Ctx.step
  have he : Ctx.execute N C' = Ctx.execute N C := rfl
  have hb : Ctx.bankrupt N C' = Ctx.bankrupt N C := rfl
  simp only [Std.Legacy.Range.forIn_eq_forIn_range', he, hb]
  have hexec : ∀ s' f r, (C).execute N s' f = .ok r → r.proj = s'.proj := fun s' f => execute_proj N C s' f
  refine TwinEq.bind (R := fun s' => s'.proj = s.proj) (TwinEq.forIn _ _ _ _ _ rfl fun k hk s₀ h₀ => ?_) fun s₁ h₁ => ?_
  · refine TwinEq.bind (TwinEq.forIn _ _ _ _ (fun s' => s'.proj = s.proj) h₀ fun x _ s' h' => ?_) fun s'' h'' => TwinEq.pure _ h''
    split
    · exact TwinEq.pure _ h'
    · exact TwinEq.throw_bind
  rw [marks_loop_rewrite]
  refine TwinEq.bind (R := fun s' => s'.proj = s.proj) (TwinEq.refl (Except.Holds.ok _ h₁)) fun s₂ h₂ => ?_
  refine TwinEq.join (R := fun s' => s'.proj = s.proj) (fun _ => TwinEq.forIn _ _ _ _ _ h₂ fun x _ s' h' => ?_) (fun _ => h₂)
    fun s₃ h₃ => ?_
  · exact TwinEq.bind (R := fun r => r.proj = s.proj) (TwinEq.refl fun r hr => (hexec _ _ r hr).trans h') fun r hr =>
      TwinEq.pure _ hr
  refine TwinEq.bind (R := fun s' => s'.proj = s.proj) (TwinEq.forIn _ _ _ _ _ h₃ fun x _ s' h' => ?_) fun s₄ h₄ => ?_
  · exact TwinEq.ite (fun _ => TwinEq.bind (R := fun r => r.proj = s.proj) (TwinEq.refl fun r hr => (hexec _ _ r hr).trans h')
      fun r hr => TwinEq.pure _ hr) fun _ => TwinEq.pure _ h'
  refine TwinEq.bind (R := fun s' => s'.proj = s.proj) (TwinEq.refl (bankrupt_proj N C s₄ b _ _ _ h₄)) fun s₅ h₅ => ?_
  refine TwinEq.ite (fun _ => TwinEq.throw_bind) fun _ => ?_
  refine TwinEq.ite (fun _ => TwinEq.throw_bind) fun _ => ?_
  refine TwinEq.join (R := fun s' => s'.proj = s.proj) (fun _ => TwinEq.forIn _ _ _ _ _ h₅ fun o _ s' h' => ?_) (fun _ => h₅)
    fun s₆ h₆ => ?_
  · split
    · exact TwinEq.ite (fun _ => TwinEq.bind (R := fun r => r.proj = s.proj)
        (TwinEq.refl fun r hr => (hexec _ _ r hr).trans h') fun r hr => TwinEq.pure _ hr) fun _ => TwinEq.pure _ h'
    · exact TwinEq.pure _ h'
  have hg : Good p c.coins i j s₆ := by
    have hm : s₆.machine = s.machine := congrArg Prod.fst h₆
    exact ⟨hm ▸ hs.1, hm ▸ hs.2⟩
  refine TwinEq.bind (tickLoop_twin T c b (List.range' 1 4) s₆ hg) fun r hr => ?_
  have hw : r.machine.vals[p'.weight]! = r.machine.vals[p.weight]! := by
    rw [T.weight]
    by_cases h : p.weight = i
    · subst h; simp [hr.2]
    · simp [h]
  refine TwinEq.bind (R := fun st => st.1.machine = r.machine) (TwinEq.forIn _ _ _ _ _ rfl fun coin _ st hst => ?_) fun st hst => ?_
  · rw [hst, hw]
    refine TwinEq.ite (fun _ => TwinEq.pure _ hst) fun _ => TwinEq.ite (fun _ => TwinEq.pure _ rfl) fun _ => ?_
    split
    · exact TwinEq.pure _ hst
    · exact TwinEq.pure _ rfl
  exact TwinEq.refl fun _ _ => trivial

theorem machineAfter_twin (n : Nat) : (C').machineAfter N n = (C).machineAfter N n := by
  rw [Ctx.machineAfter_eq, Ctx.machineAfter_eq]
  congr 1
  exact (TwinEq.bind (start_twin T c) fun s hs => tickLoop_twin T c _ _ s hs).1

theorem steps_twin (n : Nat) : (C').steps N n = (C).steps N n := by
  refine (?_ : TwinEq _ _ (fun _ => True)).1
  unfold Ctx.steps
  refine TwinEq.bind (start_twin T c) fun s₀ h₀ => ?_
  refine TwinEq.bind (TwinEq.forIn _ _ _ _ _ h₀ fun b _ s hs => ?_) fun r _ => TwinEq.refl fun _ _ => trivial
  exact TwinEq.bind (step_twin T c b s hs) fun r hr => TwinEq.pure _ hr

theorem evaluate_twin : (C').evaluate N = (C).evaluate N := by
  unfold Ctx.evaluate
  rw [steps_twin T c]
  rfl
end
end Ref
