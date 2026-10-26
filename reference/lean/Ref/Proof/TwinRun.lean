import Ref.Proof.Twin
import Ref.Proof.View

/-! L3 for the in-place rules, from ticks to runs: a twin program has the same machine schedule and the same runs. -/

namespace Ref

variable {α : Type} [Inhabited α]

theorem shape_size {p : Program} {L L' : Array Bool} {m : MState α} (h : Shape p L m) (hL : L'.size = L.size) :
    Shape p L' m :=
  ⟨h.size, fun a ha => (h.rows a ha).trans hL.symm, h.wins⟩

/-- A machine of p over `coins` coins: value rows sized to them, and no window state off window nodes. -/
def Fits (p : Program) (coins : Nat) (m : MState α) : Prop := Shape p (Array.replicate coins false) m

theorem fits_init (N : NumOps α) (p : Program) (coins : Nat) : Fits p coins (MState.init N p coins) := by
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

theorem fits_tick (N : NumOps α) {p : Program} (hp : p.WF) {coins : Nat} {L : Array Bool} (hL : L.size = coins)
    (hour : Int) {m : MState α} (hm : Fits p coins m) : Fits p coins (m.tick N p L hour) :=
  shape_size (tick_spec N p hp L hour m (shape_size hm (by simp [hL]))).1.shape (by simp [hL])

omit [Inhabited α] in
theorem mask_size (c : Ctx α) (t : Int) : (c.mask t).size = c.coins := by simp [Ctx.mask]

/-- Delivery reads the market and the delivery orders, never the program. -/
theorem deliver_prog (p p' : Program) (m : Market α) (v : Venue α) (pol : Policy) (stop : Int) (s : SState α) (t : Int) :
    (Ctx.make p' m v pol stop).deliver s t = (Ctx.make p m v pol stop).deliver s t := by
  simp only [Ctx.deliver, deliverFunding_cursor, deliverBars_cursor, deliverEvents_cursor]
  rfl

section
variable {N : NumOps α} {p p' : Program} {i j : Nat} (T : Twin N p p' i j) (m : Market α) (v : Venue α) (pol : Policy)
  (stop : Int)
include T

theorem tick_fits {L : Array Bool} (hL : L.size = m.intervals.size) (hour : Int) {mm : MState α}
    (hm : Fits p m.intervals.size mm) : mm.tick N p' L hour = mm.tick N p L hour :=
  (tick_twin T L hour mm (shape_size hm (by simp [hL]))).1

/-- A machine of p that fits, with node i's row equal to node j's, as every tick leaves it. -/
def Good (p : Program) (coins i j : Nat) (s : SState α) : Prop :=
  Fits p coins s.machine ∧ s.machine.vals[i]! = s.machine.vals[j]!

theorem tick_good {L : Array Bool} (hL : L.size = m.intervals.size) (hour : Int) {mm : MState α}
    (hm : Fits p m.intervals.size mm) :
    Fits p m.intervals.size (mm.tick N p L hour) ∧ (mm.tick N p L hour).vals[i]! = (mm.tick N p L hour).vals[j]! :=
  ⟨fits_tick N T.wf hL _ hm, (tick_twin T L hour mm (shape_size hm (by simp [hL]))).2⟩

theorem tickLoop_twin (b : Int) (ks : List Nat) (s : SState α) (hs : Good p m.intervals.size i j s) :
    EqH ((Ctx.make p' m v pol stop).tickLoop N b ks s) ((Ctx.make p m v pol stop).tickLoop N b ks s)
      (Good p m.intervals.size i j) := by
  unfold Ctx.tickLoop
  refine EqH.forIn _ _ _ _ _ hs fun k _ s hs => ?_
  refine EqH.bind (R := fun r => Fits p m.intervals.size r.machine)
    ⟨deliver_prog p p' m v pol stop _ _, fun r hr => fits_deliver hr hs.1⟩ fun r hr => ?_
  rw [show (Ctx.make p' m v pol stop).p = p' from rfl, show (Ctx.make p m v pol stop).p = p from rfl,
    show (Ctx.make p' m v pol stop).mask = (Ctx.make p m v pol stop).mask from rfl,
    tick_fits T m (mask_size _ _) _ hr]
  exact EqH.pure _ (tick_good T m (mask_size (Ctx.make p m v pol stop) _) _ hr)

theorem start_twin : EqH ((Ctx.make p' m v pol stop).start N) ((Ctx.make p m v pol stop).start N)
    (Good p m.intervals.size i j) := by
  have hb : (Ctx.make p' m v pol stop).bound = (Ctx.make p m v pol stop).bound := by
    simp only [Ctx.bound]; rw [show (Ctx.make p' m v pol stop).p = p' from rfl, slots_twin T]; rfl
  have h0 : (Ctx.make p' m v pol stop).state0 N = (Ctx.make p m v pol stop).state0 N := by
    simp only [Ctx.state0]; rw [show (Ctx.make p' m v pol stop).p = p' from rfl, init_twin T]; rfl
  unfold Ctx.start
  rw [hb, h0]
  refine EqH.ite (fun _ => EqH.throw_bind) fun _ => ?_
  refine EqH.bind (R := fun r => Fits p m.intervals.size r.machine)
    ⟨deliver_prog p p' m v pol stop _ _, fun r hr => fits_deliver hr (fits_init N p m.intervals.size)⟩ fun r hr => ?_
  rw [show (Ctx.make p' m v pol stop).p = p' from rfl, show (Ctx.make p m v pol stop).p = p from rfl,
    show (Ctx.make p' m v pol stop).mask = (Ctx.make p m v pol stop).mask from rfl,
    tick_fits T m (mask_size _ _) _ hr]
  exact EqH.pure _ (tick_good T m (mask_size (Ctx.make p m v pol stop) _) _ hr)

theorem step_twin (b : Int) (s : SState α) (hs : Good p m.intervals.size i j s) :
    EqH ((Ctx.make p' m v pol stop).step N s b) ((Ctx.make p m v pol stop).step N s b) (Good p m.intervals.size i j) := by
  refine ⟨(?_ : EqH _ _ (fun _ => True)).1, fun r hr => ?_⟩
  rotate_left
  · obtain ⟨q, hq, hpq⟩ := step_proj N _ s b r hr
    have hg := (tickLoop_twin T m v pol stop b (List.range' 1 4) s hs).2 q hq
    obtain ⟨hm, -⟩ := proj_eq hpq
    exact ⟨hm ▸ hg.1, hm ▸ hg.2⟩
  unfold Ctx.step
  simp only [Std.Legacy.Range.forIn_eq_forIn_range']
  have e₁ : (Ctx.make p' m v pol stop).m = (Ctx.make p m v pol stop).m := rfl
  have e₂ : (Ctx.make p' m v pol stop).ix = (Ctx.make p m v pol stop).ix := rfl
  have e₃ : (Ctx.make p' m v pol stop).v = (Ctx.make p m v pol stop).v := rfl
  have e₄ : (Ctx.make p' m v pol stop).pol = (Ctx.make p m v pol stop).pol := rfl
  have e₅ : (Ctx.make p' m v pol stop).stop = (Ctx.make p m v pol stop).stop := rfl
  have e₆ : (Ctx.make p' m v pol stop).coins = (Ctx.make p m v pol stop).coins := rfl
  have e₇ : (Ctx.make p' m v pol stop).mask = (Ctx.make p m v pol stop).mask := rfl
  have e₈ : Ctx.execute N (Ctx.make p' m v pol stop) = Ctx.execute N (Ctx.make p m v pol stop) := rfl
  have e₉ : Ctx.closeout N (Ctx.make p' m v pol stop) = Ctx.closeout N (Ctx.make p m v pol stop) := rfl
  have e₁₀ : Ctx.bankrupt N (Ctx.make p' m v pol stop) = Ctx.bankrupt N (Ctx.make p m v pol stop) := rfl
  simp only [e₁, e₂, e₃, e₄, e₅, e₆, e₇, e₈, e₉, e₁₀]
  have hexec : ∀ s' f r, (Ctx.make p m v pol stop).execute N s' f = .ok r → r.proj = s'.proj :=
    fun s' f => execute_proj N _ s' f
  refine EqH.bind (R := fun s' => s'.proj = s.proj) (EqH.forIn _ _ _ _ _ rfl fun k hk s₀ h₀ => ?_) fun s₁ h₁ => ?_
  · refine EqH.bind (EqH.forIn _ _ _ _ (fun s' => s'.proj = s.proj) h₀ fun x _ s' h' => ?_) fun s'' h'' => EqH.pure _ h''
    split
    · exact EqH.pure _ h'
    · exact EqH.throw_bind
  rw [marks_loop]
  refine EqH.bind (R := fun s' => s'.proj = s.proj) (EqH.refl (Except.Holds.ok _ h₁)) fun s₂ h₂ => ?_
  refine EqH.join (R := fun s' => s'.proj = s.proj) (fun _ => EqH.forIn _ _ _ _ _ h₂ fun x _ s' h' => ?_) (fun _ => h₂)
    fun s₃ h₃ => ?_
  · exact EqH.bind (R := fun r => r.proj = s.proj) (EqH.refl fun r hr => (hexec _ _ r hr).trans h') fun r hr =>
      EqH.pure _ hr
  refine EqH.bind (R := fun s' => s'.proj = s.proj) (EqH.forIn _ _ _ _ _ h₃ fun x _ s' h' => ?_) fun s₄ h₄ => ?_
  · exact EqH.ite (fun _ => EqH.bind (R := fun r => r.proj = s.proj) (EqH.refl fun r hr => (hexec _ _ r hr).trans h')
      fun r hr => EqH.pure _ hr) fun _ => EqH.pure _ h'
  refine EqH.bind (R := fun s' => s'.proj = s.proj) (EqH.refl (bankrupt_proj N _ s₄ b _ _ _ h₄)) fun s₅ h₅ => ?_
  refine EqH.ite (fun _ => EqH.throw_bind) fun _ => ?_
  refine EqH.ite (fun _ => EqH.throw_bind) fun _ => ?_
  refine EqH.join (R := fun s' => s'.proj = s.proj) (fun _ => EqH.forIn _ _ _ _ _ h₅ fun o _ s' h' => ?_) (fun _ => h₅)
    fun s₆ h₆ => ?_
  · split
    · exact EqH.ite (fun _ => EqH.bind (R := fun r => r.proj = s.proj)
        (EqH.refl fun r hr => (hexec _ _ r hr).trans h') fun r hr => EqH.pure _ hr) fun _ => EqH.pure _ h'
    · exact EqH.pure _ h'
  have hg : Good p m.intervals.size i j s₆ := by obtain ⟨hm, -⟩ := proj_eq h₆; exact ⟨hm ▸ hs.1, hm ▸ hs.2⟩
  refine EqH.bind (tickLoop_twin T m v pol stop b (List.range' 1 4) s₆ hg) fun r hr => ?_
  rw [show (Ctx.make p' m v pol stop).p = p' from rfl, show (Ctx.make p m v pol stop).p = p from rfl, T.weight]
  have hw : r.machine.vals[if p.weight == i then j else p.weight]! = r.machine.vals[p.weight]! := by
    by_cases h : p.weight = i
    · subst h; simp [hr.2]
    · simp [h]
  refine EqH.bind (R := fun st => st.1.machine = r.machine) (EqH.forIn _ _ _ _ _ rfl fun c _ st hst => ?_) fun st hst => ?_
  · rw [hst, hw]
    refine EqH.ite (fun _ => EqH.pure _ hst) fun _ => EqH.ite (fun _ => EqH.pure _ rfl) fun _ => ?_
    split
    · exact EqH.pure _ hst
    · exact EqH.pure _ rfl
  exact EqH.refl fun _ _ => trivial

theorem machineAfter_twin (n : Nat) :
    (Ctx.make p' m v pol stop).machineAfter N n = (Ctx.make p m v pol stop).machineAfter N n := by
  rw [Ctx.machineAfter_eq, Ctx.machineAfter_eq]
  congr 1
  exact (EqH.bind (start_twin T m v pol stop) fun s hs => tickLoop_twin T m v pol stop _ _ s hs).1

theorem steps_twin (n : Nat) : (Ctx.make p' m v pol stop).steps N n = (Ctx.make p m v pol stop).steps N n := by
  refine (?_ : EqH _ _ (fun _ => True)).1
  unfold Ctx.steps
  refine EqH.bind (start_twin T m v pol stop) fun s₀ h₀ => ?_
  rw [show (Ctx.make p' m v pol stop).bounds = (Ctx.make p m v pol stop).bounds from rfl]
  refine EqH.bind (EqH.forIn _ _ _ _ _ h₀ fun b _ s hs => ?_) fun r _ => EqH.refl fun _ _ => trivial
  exact EqH.bind (step_twin T m v pol stop b s hs) fun r hr => EqH.pure _ hr

theorem run_twin : run N p' m v pol stop = run N p m v pol stop := by
  unfold run
  dsimp only
  rw [show (Ctx.make p' m v pol stop).bounds = (Ctx.make p m v pol stop).bounds from rfl, steps_twin T m v pol stop]

end

end Ref
