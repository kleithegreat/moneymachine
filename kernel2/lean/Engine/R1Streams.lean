import Engine.R1Closed

/-!
# R1's streams (brief 3 step 5)
-/

namespace Engine.Machine

open Engine.Orders (Wish)

/-- The header and program of a run never change. -/
def Fixed (cfg : Config) (prog : Option Engine.Lang.Program) (c : Core) : Prop := c.cfg = cfg ∧ c.prog = prog

theorem fixed_closed (cfg : Config) (prog : Option Engine.Lang.Program) : Closed (Fixed cfg prog) where
  arrive := by
    intro s w rest b hS hI hF hP hb hnext hstop
    have fr := arriveWish_frame s w
    exact ⟨by simpa [StateOf.core, fr.cfg] using hP.1, by simpa [StateOf.core, fr.prog] using hP.2⟩
  tick := by
    intro s time ms hS hI hF hP hn ht hstop
    exact ⟨by simpa [StateOf.core, tickAt_cfg] using hP.1, by simpa [StateOf.core, tickAt_prog] using hP.2⟩
  listing := by
    intro s e rules hS hI hF hP _ _
    have hk := applyPayload_keeps s e (.listing rules)
    exact ⟨by simpa [StateOf.core, hk.cfg] using hP.1, by simpa [StateOf.core, hk.prog] using hP.2⟩
  prev := by
    intro s e hS hI hF hP _ _
    exact hP
  offer := by
    intro s coin slot parts role hS hI hF hP
    obtain ⟨e1, _⟩ := offer_fields s coin slot parts role
    exact ⟨by simpa [StateOf.core, e1] using hP.1, by simpa [StateOf.core, offer_prog] using hP.2⟩

theorem firstTick_ge (start M : Int) (hM : 0 < M) : start ≤ firstTick start M := by
  unfold firstTick
  have h1 := Int.emod_add_mul_ediv (start + M - 1) M
  have h2 := Int.emod_lt_of_pos (start + M - 1) hM
  have h3 := Int.emod_nonneg (start + M - 1) (by omega : M ≠ 0)
  have e : (start + M - 1) / M * M = M * ((start + M - 1) / M) := Int.mul_comm _ _
  omega

theorem tick_index (start stop M τ : Int) (k : Nat) (hM : 0 < M) (hs : start ≤ τ)
    (hk : stop ≤ firstTick start M + (k : Int) * M) (hτ : τ < stop) (hd : M ∣ τ) :
    ∃ j : Nat, j < k ∧ τ = firstTick start M + (j : Int) * M := by
  obtain ⟨q, hq⟩ := hd
  unfold firstTick at *
  have h1 := Int.emod_add_mul_ediv (start + M - 1) M
  have h2 := Int.emod_lt_of_pos (start + M - 1) hM
  have h3 := Int.emod_nonneg (start + M - 1) (by omega : M ≠ 0)
  generalize (start + M - 1) / M = d at *
  generalize (start + M - 1) % M = r at *
  have hdq : d ≤ q := by
    by_cases hc : d ≤ q
    · exact hc
    have hc' : q + 1 ≤ d := by omega
    have := Int.mul_le_mul_of_nonneg_left hc' (Int.le_of_lt hM)
    rw [Int.mul_add, Int.mul_one] at this
    omega
  refine ⟨(q - d).toNat, ?_, ?_⟩
  · have hn : (((q - d).toNat : Nat) : Int) = q - d := by omega
    have hlt : M * (q - d) < M * (k : Int) := by
      rw [Int.mul_sub]
      have : d * M = M * d := Int.mul_comm _ _
      have : (k : Int) * M = M * (k : Int) := Int.mul_comm _ _
      omega
    have := Int.lt_of_mul_lt_mul_left hlt (Int.le_of_lt hM)
    omega
  · have hn : (((q - d).toNat : Nat) : Int) = q - d := by omega
    rw [hn]
    rw [Int.sub_mul]
    have : d * M = M * d := Int.mul_comm _ _
    have : q * M = M * q := Int.mul_comm _ _
    omega



theorem fixed_base (initial : State) :
    Fixed initial.cfg initial.prog (initial.recast Engine.Lang.bitsOps).core := ⟨rfl, rfl⟩

/-- The run's last state: the invariants of every run, and its header and program. -/
theorem r1_final {program header : String} {initial : State} (h : start program header = .ok initial)
    (moves : List Move) (run : Engine.Orders.Run) (hr : orderRun Engine.Lang.bitsOps initial moves = some run) :
    ∃ (final : State) (l : Log) (rows : Rows), R1Inv final.core ∧ final.cfg = initial.cfg ∧ final.prog = initial.prog ∧
      final.log = some l ∧ run = l.toRun rows ∧ (∀ t, final.nextTick = some t → initial.cfg.stop ≤ t) ∧
      (∀ w ∈ final.wishes, initial.cfg.stop ≤ w.arrives) ∧
      final = (finishFull (runMoves (initial.recast Engine.Lang.bitsOps) moves).1).1 := by
  have hC := r1_closed.and (fixed_closed initial.cfg initial.prog)
  obtain ⟨final, l, rows, hpack, hlog, hrun, hn, hw, hfin⟩ :=
    orderRun_pack hC h ⟨r1_base h, fixed_base initial⟩ moves run hr
  obtain ⟨_, _, _, _, ⟨hR, hcfg, hprog⟩⟩ := hpack
  have hc : final.cfg = initial.cfg := hcfg
  refine ⟨final, l, rows, hR, hc, hprog, hlog, hrun, ?_, ?_, hfin⟩
  · intro t ht; rw [← hc]; exact hn t ht
  · intro w hw'; rw [← hc]; exact hw w hw'


open Engine.Orders (Arrival Order arrive admission) in
/-- R1's arrival and admission streams, from the invariants of the run's last state. -/
theorem r1_tail {program header : String} {initial : State} (h : start program header = .ok initial)
    (moves : List Move) (run : Engine.Orders.Run) (hr : orderRun Engine.Lang.bitsOps initial moves = some run) :
    (∀ w ∈ run.wishes, w.arrives = w.sent + initial.cfg.lambda) ∧
    run.wishes.Pairwise (fun a b => a.coin = b.coin → a.slot = b.slot → a.sent < b.sent ∧ a.arrives < b.arrives) ∧
    (∀ (coin slot : Nat),
      (run.arrivals.filter (fun a => decide (a.wish.coin = coin ∧ a.wish.slot = slot))).map (·.wish) =
        run.wishes.filter (fun w => decide (w.coin = coin ∧ w.slot = slot ∧ w.arrives < initial.cfg.stop))) ∧
    (∀ a ∈ run.arrivals, a.time = a.wish.arrives ∧ a.after = (arrive a.before a.wish).1) ∧
    run.arrivals.Pairwise (fun a b => a.time ≤ b.time) ∧
    run.admissions.Pairwise (fun a b => a.order.placed = b.order.placed →
      (a.order.reduceOnly = true ∧ b.order.reduceOnly = false) ∨
      (a.order.reduceOnly = b.order.reduceOnly ∧
        (a.order.coin < b.order.coin ∨ (a.order.coin = b.order.coin ∧ a.order.slot < b.order.slot)))) ∧
    run.admissions.filterMap (fun a => (Engine.Orders.admit a).toOption) = run.placed.map (·.order) ∧
    run.placed.Pairwise (fun a b => a.order.placed = b.order.placed →
      (a.order.reduceOnly = true ∧ b.order.reduceOnly = false) ∨
      (a.order.reduceOnly = b.order.reduceOnly ∧
        (a.order.coin < b.order.coin ∨ (a.order.coin = b.order.coin ∧ a.order.slot < b.order.slot)))) := by
  obtain ⟨final, l, rows, ⟨hR, hA, hT⟩, hcfg, hprog, hlog, rfl, hnext, hqueue, _⟩ := r1_final h moves run hr
  have hlc : final.core.log = some l.core := by simp [StateOf.core, hlog]
  have hlam : final.core.cfg.lambda = initial.cfg.lambda := by simp [StateOf.core, hcfg]
  have hsorted := hA.sorted l.core hlc
  have hKey : ∀ x y : Order, KeyLt (orderKey x) (orderKey y) →
      (x.reduceOnly = true ∧ y.reduceOnly = false) ∨
        (x.reduceOnly = y.reduceOnly ∧ (x.coin < y.coin ∨ (x.coin = y.coin ∧ x.slot < y.slot))) := fun x y hk => hk
  have hadm : l.admissions.Pairwise fun a b => a.2.placed = b.2.placed → KeyLt (orderKey a.2) (orderKey b.2) :=
    hA.admPairs l.core hlc
  have hg : ∀ (a : Engine.Orders.Book × Order) (b : Order), (Engine.Orders.admit (admission a.1 a.2)).toOption = some b → b = a.2 := by
    intro a b hab
    cases hx : Engine.Orders.admit (admission a.1 a.2) with
    | error r => rw [hx] at hab; simp [Except.toOption] at hab
    | ok o =>
      rw [hx] at hab
      simp only [Except.toOption, Option.some.injEq] at hab
      subst hab
      exact admit_ok_order hx
  refine ⟨?_, hR.sentPairs l.core hlc, ?_, hA.own l.core hlc, hsorted, ?_, ?_, ?_⟩
  · intro w hw
    have := hR.sentArrives l.core hlc w hw
    rw [hlam] at this
    exact this
  · intro coin slot
    have hf : l.wishes.filter (SameSlot coin slot) = (l.arrivals.map (·.wish)).filter (SameSlot coin slot) ++
        final.wishes.filter (SameSlot coin slot) := hR.fifo l.core hlc coin slot
    have e1 : (l.arrivals.filter (fun a => decide (a.wish.coin = coin ∧ a.wish.slot = slot))).map (·.wish) =
        (l.arrivals.map (·.wish)).filter (SameSlot coin slot) := by
      rw [List.filter_map]
      rfl
    have e2 : l.wishes.filter (fun w => decide (w.coin = coin ∧ w.slot = slot ∧ w.arrives < initial.cfg.stop)) =
        (l.wishes.filter (SameSlot coin slot)).filter (fun w => decide (w.arrives < initial.cfg.stop)) := by
      rw [List.filter_filter]
      apply List.filter_congr
      intro w _
      by_cases h1 : w.coin = coin <;> by_cases h2 : w.slot = slot <;> by_cases h3 : w.arrives < initial.cfg.stop <;>
        simp [SameSlot, h1, h2, h3]
    show (l.arrivals.filter (fun a => decide (a.wish.coin = coin ∧ a.wish.slot = slot))).map (·.wish) =
      l.wishes.filter (fun w => decide (w.coin = coin ∧ w.slot = slot ∧ w.arrives < initial.cfg.stop))
    rw [e1, e2, hf, List.filter_append]
    have e3 : ((l.arrivals.map (·.wish)).filter (SameSlot coin slot)).filter (fun w => decide (w.arrives < initial.cfg.stop)) =
        (l.arrivals.map (·.wish)).filter (SameSlot coin slot) := by
      rw [List.filter_eq_self]
      intro w hw
      simp only [List.mem_filter, List.mem_map] at hw
      obtain ⟨⟨a, ha, rfl⟩, _⟩ := hw
      have h1 := (hA.own l.core hlc a ha).1
      have h2 := hA.stop l.core hlc a ha
      simp only [StateOf.core, hcfg] at h2
      simpa [← h1] using h2
    have e4 : (final.wishes.filter (SameSlot coin slot)).filter (fun w => decide (w.arrives < initial.cfg.stop)) = [] := by
      rw [List.filter_eq_nil_iff]
      intro w hw
      simp only [List.mem_filter] at hw
      have := hqueue w hw.1
      simpa using this
    rw [e3, e4, List.append_nil]
  · show (l.admissions.map fun (b, o) => admission b o).Pairwise _
    rw [List.pairwise_map]
    exact hadm.imp fun {a b} hab hpl => hKey _ _ (hab hpl)
  · show (l.admissions.map fun (b, o) => admission b o).filterMap _ = _
    rw [List.filterMap_map]
    exact (hA.placedAdm l.core hlc).symm
  · show l.placed.Pairwise _
    have hpm : (l.placed.map (·.order)).Pairwise (fun x y => x.placed = y.placed →
        (x.reduceOnly = true ∧ y.reduceOnly = false) ∨
          (x.reduceOnly = y.reduceOnly ∧ (x.coin < y.coin ∨ (x.coin = y.coin ∧ x.slot < y.slot)))) := by
      have hpa : l.placed.map (·.order) = l.admissions.filterMap fun a => (Engine.Orders.admit (admission a.1 a.2)).toOption :=
        hA.placedAdm l.core hlc
      rw [hpa, List.pairwise_filterMap]
      refine hadm.imp ?_
      intro a b hab x hx y hy hpl
      have e1 := hg a x hx
      have e2 := hg b y hy
      subst e1; subst e2
      exact hKey _ _ (hab hpl)
    rw [List.pairwise_map] at hpm
    exact hpm


open Engine.Orders (Wish) in
/-- R1's first stream: the wishes sent at `τ` are one for each slot of each coin in view at a deciding tick, and none else. -/
theorem r1_keys {program header : String} {initial : State} (h : start program header = .ok initial)
    (moves : List Move) (run : Engine.Orders.Run) (hr : orderRun Engine.Lang.bitsOps initial moves = some run) (τ : Int) :
    (run.wishes.filter (fun w => decide (w.sent = τ))).map (fun w => (w.coin, w.slot)) =
      (if (orderHorizon initial).1 ≤ τ ∧ τ < (orderHorizon initial).2 ∧
          τ % ((orderClock initial).1 * (orderClock initial).2) = 0
       then slotKeysAt initial moves τ else []) := by
  obtain ⟨final, l, rows, ⟨hR, hA, hT⟩, hcfg, hprog, hlog, rfl, hnext, hqueue, hfin⟩ := r1_final h moves run hr
  obtain ⟨cfg, p, _, _, hinit⟩ := start_shape h
  obtain ⟨hS, _⟩ := start_facts h
  have hlc : final.core.log = some l.core := by simp [StateOf.core, hlog]
  have hMc : initial.cfg.tickMs = some ((p.tick : Int) * 1000) := by rw [hinit]; rfl
  have hpc : initial.prog = some p := by rw [hinit]; rfl
  have hM : 0 < (p.tick : Int) * 1000 := hS.1 _ hMc
  have hclock : orderClock initial = ((p.tick : Int) * 1000, (p.decideEvery : Int)) := by
    simp [orderClock, hMc, hpc]
  have hcoreCfg : final.core.cfg = initial.cfg := hcfg
  have hdec : ∀ t, decidesC final.core t = decide (t % (((p.tick : Int) * 1000) * (p.decideEvery : Int)) = 0) := by
    intro t; simp [decidesC, StateOf.core, hcfg, hprog, hMc, hpc]
  have hslots : slotsC final.core = p.slots.size := by simp [slotsC, StateOf.core, hprog, hpc]
  obtain ⟨k, hk1, hk2⟩ := hT.progression l.core hlc ((p.tick : Int) * 1000) (by simpa [StateOf.core, hcfg] using hMc)
  have hk2' : initial.cfg.stop ≤ firstTick initial.cfg.start ((p.tick : Int) * 1000) + (k : Int) * ((p.tick : Int) * 1000) := by
    have := hnext _ (by simpa [StateOf.core, hcfg] using hk2)
    simpa [StateOf.core, hcfg] using this
  have hbl : ∀ tk ∈ l.ticks, ∃ j : Nat, j < k ∧ tk.1 = firstTick initial.cfg.start ((p.tick : Int) * 1000) + (j : Int) * ((p.tick : Int) * 1000) := by
    intro tk htk
    have : tk.1 ∈ l.core.ticks.map (·.1) := List.mem_map.2 ⟨tk, htk, rfl⟩
    rw [hk1] at this
    obtain ⟨j, hj, hjt⟩ := List.mem_map.1 this
    exact ⟨j, List.mem_range.1 hj, by simp only [StateOf.core, hcfg] at hjt; exact hjt.symm⟩
  have hlb : ∀ j : Nat, j < k → ∃ tk ∈ l.ticks, tk.1 = firstTick initial.cfg.start ((p.tick : Int) * 1000) + (j : Int) * ((p.tick : Int) * 1000) := by
    intro j hj
    have : firstTick final.core.cfg.start ((p.tick : Int) * 1000) + (j : Int) * ((p.tick : Int) * 1000) ∈ (List.range k).map
        (fun (j : Nat) => firstTick final.core.cfg.start ((p.tick : Int) * 1000) + (j : Int) * ((p.tick : Int) * 1000)) := List.mem_map.2 ⟨j, List.mem_range.2 hj, rfl⟩
    rw [← hk1] at this
    obtain ⟨tk, htk, e⟩ := List.mem_map.1 this
    exact ⟨tk, htk, by simp only [StateOf.core, hcfg] at e; exact e⟩
  have hge : ∀ tk ∈ l.ticks, initial.cfg.start ≤ tk.1 := by
    intro tk htk
    obtain ⟨j, _, e⟩ := hbl tk htk
    have := firstTick_ge initial.cfg.start ((p.tick : Int) * 1000) hM
    have : 0 ≤ (j : Int) * ((p.tick : Int) * 1000) := Int.mul_nonneg (Int.natCast_nonneg j) (Int.le_of_lt hM)
    omega
  have hstopb : ∀ tk ∈ l.ticks, tk.1 < initial.cfg.stop := by
    intro tk htk
    have := hT.beforeStop l.core hlc tk htk
    simpa [StateOf.core, hcfg] using this
  have hslot : slotKeysAt initial moves τ = (match l.ticks.find? (·.1 == τ) with
      | none => [] | some tk => keysOf tk.2 p.slots.size) := by
    unfold slotKeysAt
    dsimp only
    rcases hrm : runMoves (initial.recast Engine.Lang.bitsOps) moves with ⟨fed, rr⟩
    rcases hff : finishFull fed with ⟨fin, rest, summ⟩
    rw [hrm, hff] at hfin
    have hl' : fin.log = some l := by rw [show fin = final from hfin.symm]; exact hlog
    simp only [hl', hpc]
    rfl
  rw [hclock] at *
  simp only [orderHorizon] at *
  rw [hslot]
  by_cases hc : initial.cfg.start ≤ τ ∧ τ < initial.cfg.stop ∧ τ % (((p.tick : Int) * 1000) * (p.decideEvery : Int)) = 0
  · simp only [hc, and_self, ↓reduceIte]
    obtain ⟨hs, hst, hmod⟩ := hc
    have hd : ((p.tick : Int) * 1000) ∣ τ := by
      have h1 : (((p.tick : Int) * 1000) * (p.decideEvery : Int)) ∣ τ := Int.dvd_of_emod_eq_zero hmod
      exact Int.dvd_trans (Int.dvd_mul_right _ _) h1
    obtain ⟨j, hj, hjt⟩ := tick_index initial.cfg.start initial.cfg.stop ((p.tick : Int) * 1000) τ k hM hs hk2' hst hd
    obtain ⟨tk, htk, htkτ⟩ := hlb j hj
    have hfind : (l.ticks.find? (·.1 == τ)).isSome = true := by
      rw [List.find?_isSome]
      exact ⟨tk, htk, by simp [htkτ, hjt]⟩
    obtain ⟨tk', hf⟩ := Option.isSome_iff_exists.1 hfind
    rw [hf]
    have htk' := List.mem_of_find?_eq_some hf
    have hpt := List.find?_some hf
    have hτ' : tk'.1 = τ := by simpa using hpt
    have hk := hT.keys l.core hlc tk' htk'
    rw [hτ', hdec, hslots] at hk
    simp only [hmod, decide_true, ↓reduceIte] at hk
    exact hk
  · simp only [hc, ↓reduceIte]
    by_cases hex : ∃ tk ∈ l.ticks, tk.1 = τ
    · obtain ⟨tk, htk, hτ⟩ := hex
      have hk := hT.keys l.core hlc tk htk
      rw [hτ, hdec] at hk
      have hn : ¬ (τ % (((p.tick : Int) * 1000) * (p.decideEvery : Int)) = 0) := by
        intro hm
        exact hc ⟨by rw [← hτ]; exact hge tk htk, by rw [← hτ]; exact hstopb tk htk, hm⟩
      simp only [hn, decide_false, Bool.false_eq_true, ↓reduceIte] at hk
      exact hk
    · have : l.wishes.filter (fun w => decide (w.sent = τ)) = [] := by
        rw [List.filter_eq_nil_iff]
        intro w hw
        obtain ⟨tk, htk, e⟩ := hT.sentTick l.core hlc w hw
        simp only [decide_eq_true_eq]
        intro hsent
        exact hex ⟨tk, htk, by rw [e, hsent]⟩
      show (l.wishes.filter (fun w => decide (w.sent = τ))).map _ = _
      rw [this]
      rfl

end Engine.Machine
