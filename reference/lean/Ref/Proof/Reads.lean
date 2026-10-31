import Ref.Proof.Tick

namespace Ref.Reads

variable {α : Type} [Inhabited α]

def rows (c : Ctx α) : List (Obs α) := c.oOrder.toList.map (c.obs[·]!)

theorem rows_length (c : Ctx α) : (rows c).length = c.oOrder.size := by simp [rows]

theorem rows_get (c : Ctx α) (i : Nat) (hi : i < c.oOrder.size) :
    (rows c)[i]! = c.obs[c.oOrder[i]]! := by
  rw [getElem!_pos _ i (by simpa [rows] using hi)]
  simp [rows]

theorem lex_trans : ∀ (a b c : List Int), a.length = b.length → b.length = c.length →
    lexLe a b = true → lexLe b c = true → lexLe a c = true
  | [], _, _, _, _, _, _ => by simp [lexLe]
  | _ :: _, [], _, h, _, _, _ => by simp at h
  | _ :: _, _ :: _, [], _, h, _, _ => by simp at h
  | x :: xs, y :: ys, z :: zs, h₁, h₂, hab, hbc => by
    simp only [lexLe, Bool.or_eq_true, decide_eq_true_eq, Bool.and_eq_true, beq_iff_eq] at hab hbc ⊢
    simp only [List.length_cons, Nat.add_right_cancel_iff] at h₁ h₂
    rcases hab with hab | ⟨rfl, hab⟩ <;> rcases hbc with hbc | ⟨rfl, hbc⟩
    · left; omega
    · left; omega
    · left; omega
    · exact Or.inr ⟨rfl, lex_trans xs ys zs h₁ h₂ hab hbc⟩

theorem lex_total : ∀ (a b : List Int), a.length = b.length → (lexLe a b || lexLe b a) = true
  | [], _, _ => by simp [lexLe]
  | _ :: _, [], h => by simp at h
  | x :: xs, y :: ys, h => by
    simp only [List.length_cons, Nat.add_right_cancel_iff] at h
    have := lex_total xs ys h
    simp only [lexLe, Bool.or_eq_true, decide_eq_true_eq, Bool.and_eq_true, beq_iff_eq] at this ⊢
    rcases Int.lt_trichotomy x y with h₁ | rfl | h₁
    · exact Or.inl (Or.inl h₁)
    · rcases this with h₂ | h₂
      · exact Or.inl (Or.inr ⟨rfl, h₂⟩)
      · exact Or.inr (Or.inr ⟨rfl, h₂⟩)
    · exact Or.inr (Or.inl h₁)

theorem sorted (reg : Registry) (roles : Roles) (p : Program) (adm : Meta) (obs : Array (Obs α))
    (v : Venue α) (pol : Policy) (stop : Int) (req : List Nat) :
    (rows (Ctx.make reg roles p adm obs v pol stop req)).Pairwise (fun a b => a.known ≤ b.known) := by
  unfold rows Ctx.make
  rw [Array.toList_mergeSort, List.pairwise_map]
  let os := obs.filter ((adm.delivered reg).contains ·.source)
  let key (i : Nat) := [os[i]!.known, (os[i]!.source : Int), (os[i]!.coin : Int)] ++
    (if (reg.decls[os[i]!.source]!).cadence == .event then [os[i]!.recorded, os[i]!.key]
     else [os[i]!.key, os[i]!.recorded]) ++ [(i : Int)]
  have hlen : ∀ i, (key i).length = 6 := by intro i; simp [key]; split <;> rfl
  refine (List.pairwise_mergeSort (fun a b c => lex_trans (key a) (key b) (key c)
    ((hlen a).trans (hlen b).symm) ((hlen b).trans (hlen c).symm))
    (fun a b => lex_total (key a) (key b) ((hlen a).trans (hlen b).symm)) _).imp ?_
  intro i j h
  change os[i]!.known ≤ os[j]!.known
  simp only [key, List.cons_append, List.nil_append, lexLe, Bool.or_eq_true,
    decide_eq_true_eq, Bool.and_eq_true, beq_iff_eq] at h
  rcases h with h | ⟨h, _⟩ <;> omega

def Latest (c : Ctx α) (s : SState α) : Prop :=
  s.oi ≤ (rows c).length ∧ s.machine.latest.size = c.reg.decls.size ∧
    (∀ src < c.reg.decls.size, s.machine.latest[src]!.size = c.coins) ∧
    ∀ src < c.reg.decls.size, ∀ coin < c.coins,
      s.machine.latest[src]![coin]! = (((rows c).take s.oi).filter fun o => o.source == src && o.coin == coin).getLast?

theorem latest_deliver (c : Ctx α) (s : SState α) (o : Obs α) (tick : Int)
    (hs : Latest c s) (hi : s.oi < (rows c).length) (ho : (rows c)[s.oi]! = o)
    (hsrc : o.source < c.reg.decls.size) (hcoin : o.coin < c.coins) (hk : o.known ≤ tick) :
    Latest c { s with machine := { s.machine with
      maxKnown := max s.machine.maxKnown o.known
      latest := s.machine.latest.modify o.source fun row => row.set! o.coin (some o) }, oi := s.oi + 1 } := by
  obtain ⟨hb, hsz, hrows, hread⟩ := hs
  refine ⟨by dsimp; omega, by simpa using hsz, ?_, ?_⟩
  · intro src hsrc'
    rw [size_modify_set]
    exact hrows src hsrc'
  · intro src hsrc' coin hcoin'
    rw [get_modify_set]
    have htake : (rows c).take (s.oi + 1) = (rows c).take s.oi ++ [o] := by
      rw [List.take_add_one, List.getElem?_eq_getElem hi]
      simpa only [getElem!_pos (rows c) s.oi hi, Option.toList_some] using congrArg (fun x => (rows c).take s.oi ++ [x]) ho
    rw [htake, List.filter_append, List.getLast?_append]
    by_cases h : src = o.source ∧ coin = o.coin
    · obtain ⟨rfl, rfl⟩ := h
      have hc : o.coin < s.machine.latest[o.source]!.size := by rw [hrows _ hsrc]; exact hcoin
      simp only [hsz, hsrc, hc, and_self, ite_true, List.filter_cons, beq_self_eq_true,
        Bool.and_self, List.filter_nil, List.getLast?_singleton, Option.some_or]
    · have hm : ¬(o.source = src ∧ o.coin = coin) := by omega
      have hif : ¬(src = o.source ∧ o.source < s.machine.latest.size ∧ o.coin < s.machine.latest[o.source]!.size ∧ coin = o.coin) := fun h' => h ⟨h'.1, h'.2.2.2⟩
      simp only [if_neg hif,
        show (o.source == src && o.coin == coin) = false by simpa using hm,
        List.filter_cons, Bool.false_eq_true, ite_false, List.filter_nil, List.getLast?_nil, Option.none_or]
      exact hread src hsrc' coin hcoin'

def Passed (c : Ctx α) (tick : Int) (s : SState α) : Prop :=
  ∀ j < s.oi, (rows c)[j]!.known ≤ tick

theorem deliver_state (c : Ctx α)
    (hv : ∀ o ∈ rows c, o.source < c.reg.decls.size ∧ o.coin < c.coins)
    (s : SState α) (tick : Int) (hs : Latest c s) (hp : Passed c tick s) :
    Except.Holds (c.deliver s tick) fun r => Latest c r ∧ Passed c tick r ∧
      (r.oi < (rows c).length → tick < (rows c)[r.oi]!.known) := by
  induction hn : c.oOrder.size - s.oi using Nat.strongRecOn generalizing s with
  | ind n ih =>
    rw [Ctx.deliver]
    split
    · rename_i hlt
      have hrow := rows_get c s.oi hlt
      dsimp only
      split
      · rename_i hfuture
        exact Except.Holds.ok _ ⟨hs, hp, fun _ => by simpa [hrow] using hfuture⟩
      · rename_i hknown
        have hk : (c.obs[c.oOrder[s.oi]]!).known ≤ tick := by omega
        simp only [MState.deliver, show ¬(c.obs[c.oOrder[s.oi]]!).known > tick by omega, ite_false]
        have hi : s.oi < (rows c).length := by simpa [rows_length] using hlt
        have hv' := hv (c.obs[c.oOrder[s.oi]]!) (by rw [← hrow, getElem!_pos (rows c) _ hi]; exact List.getElem_mem hi)
        apply ih (c.oOrder.size - (s.oi + 1)) (by omega)
          { s with machine := { s.machine with
            maxKnown := max s.machine.maxKnown (c.obs[c.oOrder[s.oi]]!).known
            latest := s.machine.latest.modify (c.obs[c.oOrder[s.oi]]!).source fun row =>
              row.set! (c.obs[c.oOrder[s.oi]]!).coin (some (c.obs[c.oOrder[s.oi]]!)) }, oi := s.oi + 1 }
          (latest_deliver c s _ tick hs hi hrow hv'.1 hv'.2 hk) ?_ rfl
        intro j hj
        rcases Nat.lt_or_ge j s.oi with h | h
        · exact hp j h
        · have : j = s.oi := by simp only at hj; omega
          subst j
          simpa [hrow] using hk
    · rename_i hlt
      exact Except.Holds.ok _ ⟨hs, hp, fun hi => by simp only [rows_length] at hi; omega⟩

theorem cut (l : List (Obs α)) (hs : l.Pairwise fun a b => a.known ≤ b.known)
    (t : Int) (i : Nat) (hi : i ≤ l.length) (hp : ∀ j < i, l[j]!.known ≤ t)
    (hn : i < l.length → t < l[i]!.known) : l.take i = l.filter (·.known ≤ t) := by
  have ha : (l.take i).filter (·.known ≤ t) = l.take i := by
    apply List.filter_eq_self.mpr
    intro o ho
    obtain ⟨j, hj, he⟩ := List.mem_iff_getElem.mp ho
    have hji : j < i := by simp only [List.length_take] at hj; omega
    have hjl : j < l.length := by omega
    have he' : l[j]! = o := by simpa [getElem!_pos l j hjl] using he
    simpa [← he'] using hp j hji
  have hb : (l.drop i).filter (·.known ≤ t) = [] := by
    apply List.filter_eq_nil_iff.mpr
    intro o ho
    obtain ⟨j, hj, he⟩ := List.mem_iff_getElem.mp ho
    have hij : i + j < l.length := by simp only [List.length_drop] at hj; omega
    have hil : i < l.length := by omega
    have he' : l[i + j]! = o := by simpa [getElem!_pos l (i + j) hij] using he
    have hknown : l[i]!.known ≤ l[i + j]!.known := by
      by_cases hj0 : j = 0
      · subst j; simp
      · simpa only [getElem!_pos l i hil, getElem!_pos l (i + j) hij] using
          List.pairwise_iff_getElem.mp hs i (i + j) hil hij (by omega)
    have := hn hil
    simp only [decide_eq_true_eq]
    rw [← he']; omega
  have he := List.filter_append (p := fun o : Obs α => decide (o.known ≤ t)) (l.take i) (l.drop i)
  simpa [List.take_append_drop, ha, hb] using he.symm

theorem valid_rows (reg : Registry) (roles : Roles) (p : Program) (adm : Meta) (obs : Array (Obs α))
    (v : Venue α) (pol : Policy) (stop : Int) (req : List Nat)
    (had : (Ctx.make reg roles p adm obs v pol stop req).admissible = true) :
    ∀ o ∈ rows (Ctx.make reg roles p adm obs v pol stop req),
      o.source < reg.decls.size ∧ o.coin < adm.intervals.size := by
  let c := Ctx.make reg roles p adm obs v pol stop req
  intro o ho
  obtain ⟨i, hi, rfl⟩ := List.mem_map.mp ho
  have hib : i < c.obs.size := by
    simpa [c, Ctx.make, Array.toList_mergeSort] using hi
  simp only [Ctx.admissible, Bool.and_eq_true] at had
  have hall := had.2
  change c.obs.all _ = true at hall
  have h := Array.all_eq_true.mp hall i hib
  rw [← getElem!_pos c.obs i hib] at h
  simp only [Bool.and_eq_true, decide_eq_true_eq] at h
  exact ⟨h.1.1.1.1, h.1.1.1.2⟩

def Shaped (c : Ctx α) (s : SState α) : Prop :=
  Shape c.p (Array.replicate c.coins false) s.machine

theorem shaped_mask (c : Ctx α) (s : SState α) (h : Shaped c s) (hour : Int) :
    Shape c.p (c.mask hour) s.machine := by
  exact ⟨h.size, fun i hi => by simpa [Ctx.mask] using h.rows i hi, h.wins⟩

theorem init_state (N : NumOps α) (c : Ctx α) : Latest c (c.state0 N) ∧ Shaped c (c.state0 N) := by
  constructor
  · refine ⟨by simp [Ctx.state0], by simp [Ctx.state0, MState.init], ?_, ?_⟩
    · intro src hsrc
      simp [Ctx.state0, MState.init, getElem!_def, hsrc]
    · intro src hsrc coin hcoin
      simp [Ctx.state0, MState.init, getElem!_def, hsrc, hcoin]
  · refine ⟨by simp [Ctx.state0, MState.init], ?_, ?_⟩
    · intro i hi
      simp [Ctx.state0, MState.init, getElem!_def, hi]
    · intro i hi hn coin
      change ((MState.init N c.p c.reg.decls.size c.coins).wins[i]![coin]!) = none
      by_cases hw : ∃ w, (MState.init N c.p c.reg.decls.size c.coins).wins[i]![coin]! = some w
      · obtain ⟨w, hw⟩ := hw
        obtain ⟨k, n, args, hnode⟩ := init_wins N c.p c.reg.decls.size c.coins i coin w hw
        rw [hnode.1] at hn
        cases hn
      · cases he : (MState.init N c.p c.reg.decls.size c.coins).wins[i]![coin]! with
        | none => rfl
        | some w => exact (hw ⟨w, he⟩).elim

theorem shaped_deliver (c : Ctx α) (s r : SState α) (tick : Int) (hs : Shaped c s)
    (hd : c.deliver s tick = .ok r) : Shaped c r := by
  obtain ⟨hv, hw, _⟩ := deliver_keeps_local c s r tick hd
  exact ⟨hv ▸ hs.size, fun i hi => hv ▸ hs.rows i hi, fun i hi hn coin => hw ▸ hs.wins i hi hn coin⟩

def AtTick (N : NumOps α) (c : Ctx α) (hour : Int) (s : SState α) : Prop :=
  Latest c s ∧ Shaped c s ∧ Passed c (hour + c.pol.delta) s ∧
    (s.oi < (rows c).length → hour + c.pol.delta < (rows c)[s.oi]!.known) ∧
    s.machine.hour = hour ∧
    ∀ i < c.p.nodes.size, ∀ inp, c.p.nodes[i]! = .input inp → ∀ coin,
      c.listed coin hour = true → s.machine.vals[i]![coin]! = (s.machine.input inp coin).bind N.keep

theorem tick_state (N : NumOps α) (c : Ctx α) (hw : c.p.WF c.reg) (s : SState α) (hour : Int)
    (hs : Latest c s) (hshape : Shaped c s) (hp : Passed c (hour + c.pol.delta) s)
    (hstop : s.oi < (rows c).length → hour + c.pol.delta < (rows c)[s.oi]!.known) :
    AtTick N c hour { s with machine := s.machine.tick N c.p (c.mask hour) hour } := by
  obtain ⟨hd, hh⟩ := tick_spec N c.p hw (c.mask hour) hour s.machine (shaped_mask c s hshape hour)
  refine ⟨?_, ?_, hp, hstop, hh, ?_⟩
  · rcases hs with ⟨hi, hsize, hrows, hread⟩
    exact ⟨hi, hd.latest ▸ hsize, fun src hsrc => hd.latest ▸ hrows src hsrc,
      fun src hsrc coin hcoin => hd.latest ▸ hread src hsrc coin hcoin⟩
  · exact ⟨hd.shape.size, fun i hi => by simpa [Ctx.mask] using hd.shape.rows i hi, hd.shape.wins⟩
  · intro i hi inp hn coin hlisted
    have hcoin : coin < c.coins := by
      rcases Nat.lt_or_ge coin c.coins with h | h
      · exact h
      · simp only [Ctx.listed, getElem!_neg c.adm.intervals coin (by simpa [Ctx.coins] using h),
          Bool.and_eq_true, decide_eq_true_eq] at hlisted
        change 0 ≤ hour ∧ hour < 0 at hlisted
        omega
    have hmask : (c.mask hour)[coin]! = true := by
      rw [getElem!_pos (c.mask hour) coin (by simpa [Ctx.mask] using hcoin)]
      simpa [Ctx.mask] using hlisted
    have hr := (hd.rows i hi coin).2.2 (by rw [hn]; rfl)
    simpa only [hmask, ite_true, MState.eval, hn] using hr

theorem one (N : NumOps α) (c : Ctx α) (hw : c.p.WF c.reg)
    (hv : ∀ o ∈ rows c, o.source < c.reg.decls.size ∧ o.coin < c.coins)
    (n : Nat) (s : SState α) (hs : Latest c s) (hf : Shaped c s)
    (hp : Passed c (c.pol.wStart + (n : Int) * HOUR + c.pol.delta) s) :
    Except.Holds (do
      let t ← c.deliver s (c.pol.wStart + (n : Int) * HOUR + c.pol.delta)
      pure { t with machine := t.machine.tick N c.p (c.mask (c.pol.wStart + (n : Int) * HOUR)) (c.pol.wStart + (n : Int) * HOUR) })
        (AtTick N c (c.pol.wStart + (n : Int) * HOUR)) := by
  intro r hr
  cases hdel : c.deliver s (c.pol.wStart + (n : Int) * HOUR + c.pol.delta) with
  | error e => simp [hdel, bind, Except.bind] at hr
  | ok t =>
    simp only [hdel, bind, Except.bind, pure, Except.pure, Except.ok.injEq] at hr
    subst r
    obtain ⟨ht, hpass, hnext⟩ := deliver_state c hv s _ hs hp t hdel
    exact tick_state N c hw t _ ht (shaped_deliver c s t _ hf hdel) hpass hnext

theorem schedule (N : NumOps α) (c : Ctx α) (hw : c.p.WF c.reg)
    (hv : ∀ o ∈ rows c, o.source < c.reg.decls.size ∧ o.coin < c.coins) (n : Nat) :
    Except.Holds (c.tickLoop N c.pol.wStart (List.range' 0 (n + 1)) (c.state0 N))
      (AtTick N c (c.pol.wStart + (n : Int) * HOUR)) := by
  induction n with
  | zero =>
    simpa [Ctx.tickLoop, List.range'_succ, List.forIn_cons, List.forIn_nil] using
      one N c hw hv 0 (c.state0 N) (init_state N c).1 (init_state N c).2
        (fun j hj => by simp [Ctx.state0] at hj)
  | succ n ih =>
    rw [show List.range' 0 (n + 1 + 1) = List.range' 0 (n + 1) ++ [n + 1] by
      simpa using (List.range'_concat (s := 0) (n := n + 1) (step := 1)), tickLoop_append]
    refine Except.Holds.bind (x := c.tickLoop N c.pol.wStart (List.range' 0 (n + 1)) (c.state0 N))
      (f := c.tickLoop N c.pol.wStart [n + 1])
      (Q := AtTick N c (c.pol.wStart + ((n + 1 : Nat) : Int) * HOUR)) ih ?_
    intro s hs
    have hp : Passed c (c.pol.wStart + ((n + 1 : Nat) : Int) * HOUR + c.pol.delta) s := by
      intro j hj
      have := hs.2.2.1 j hj
      simp only [Int.natCast_add, Int.natCast_one, HOUR] at *
      omega
    simpa [Ctx.tickLoop, List.forIn_cons, List.forIn_nil] using one N c hw hv (n + 1) s hs.1 hs.2.1 hp

theorem read_input (N : NumOps α) (reg : Registry) (roles : Roles) (p : Program) (hw : p.WF reg)
    (adm : Meta) (obs : Array (Obs α)) (v : Venue α) (pol : Policy) (stop : Int) (req : List Nat)
    (ha : (Ctx.make reg roles p adm obs v pol stop req).admissible = true) (n : Nat) (ms : MState α)
    (hm : (Ctx.make reg roles p adm obs v pol stop req).machineAfter N n = .ok ms)
    (i : Nat) (hi : i < p.nodes.size) (inp : Input) (hn : p.nodes[i]! = .input inp) (coin : Nat)
    (hl : (Ctx.make reg roles p adm obs v pol stop req).listed coin (pol.wStart + (n : Int) * HOUR) = true) :
    let r := (((Ctx.make reg roles p adm obs v pol stop req).deliveryPrefix
      (pol.wStart + (n : Int) * HOUR + pol.delta)).filter fun o => o.source == inp.source && o.coin == coin).getLast?
    ms.vals[i]![coin]! = if inp.event && !(r.any (·.slot == some (pol.wStart + (n : Int) * HOUR))) then none
      else (r.bind (·.vals[inp.field]!)).bind N.keep := by
  let c := Ctx.make reg roles p adm obs v pol stop req
  rw [Ctx.machineAfter_eq, start_tickLoop] at hm
  cases hs : c.tickLoop N c.pol.wStart (List.range' 0 (n + 1)) (c.state0 N) with
  | error e => simp only [show Ctx.make reg roles p adm obs v pol stop req = c from rfl, hs, Except.map] at hm; cases hm
  | ok s =>
    have hms : s.machine = ms := by simpa only [show Ctx.make reg roles p adm obs v pol stop req = c from rfl, hs, Except.map, Except.ok.injEq] using hm
    subst ms
    clear hm
    have ht := schedule N c hw (valid_rows reg roles p adm obs v pol stop req ha) n s hs
    have hcoin : coin < c.coins := by
      change c.listed coin (pol.wStart + (n : Int) * HOUR) = true at hl
      rcases Nat.lt_or_ge coin c.coins with h | h
      · exact h
      · simp only [Ctx.listed, getElem!_neg c.adm.intervals coin (by simpa [Ctx.coins] using h),
          Bool.and_eq_true, decide_eq_true_eq] at hl
        change 0 ≤ _ ∧ _ < 0 at hl
        omega
    have hw' := hw.2.2.2.2.2 i hi
    rw [hn] at hw'
    have hr := ht.1.2.2.2 inp.source hw'.1.1 coin hcoin
    have hcut := cut (rows c) (sorted reg roles p adm obs v pol stop req) _ s.oi ht.1.1 ht.2.2.1 ht.2.2.2.1
    rw [hcut] at hr
    have hval := ht.2.2.2.2.2 i hi inp hn coin hl
    rw [MState.input, ht.2.2.2.2.1, hr] at hval
    rw [hval]
    change (match ((c.deliveryPrefix (pol.wStart + (n : Int) * HOUR + pol.delta)).filter
       fun (o : Obs α) => o.source == inp.source && o.coin == coin).getLast? with
      | some o => if !inp.event || o.slot == some (pol.wStart + (n : Int) * HOUR) then o.vals[inp.field]! else none
      | none => none).bind N.keep = _
    generalize ((c.deliveryPrefix (pol.wStart + (n : Int) * HOUR + pol.delta)).filter
      fun o => o.source == inp.source && o.coin == coin).getLast? = r
    cases r with
    | none => cases inp.event <;> rfl
    | some o => cases he : inp.event <;> cases hslot : (o.slot == some (pol.wStart + (n : Int) * HOUR)) <;>
        simp [he, hslot]

end Ref.Reads
