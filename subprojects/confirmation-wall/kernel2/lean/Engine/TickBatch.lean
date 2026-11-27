import Engine.RInv

/-!
# What a tick sends and writes (brief 3 step 5; R1)

At a deciding tick every slot of every coin in view sends one wish, coin then slot; other ticks send none. The tick's entry
in the log lists which coins were in view.
-/

namespace Engine.Machine

open Engine.Orders (Wish)

/-- The coin then slot of each slot of each coin in view. -/
def keysOf (inView : List Bool) (slots : Nat) : List (Nat × Nat) :=
  (List.range inView.length).flatMap fun c => if inView.getD c false then (List.range slots).map (c, ·) else []

theorem keysOf_nodup (inView : List Bool) (slots : Nat) : (keysOf inView slots).Nodup := by
  unfold keysOf List.Nodup
  rw [List.pairwise_flatMap]
  refine ⟨?_, ?_⟩
  · intro c _
    split
    · rw [List.pairwise_map]
      exact List.nodup_range.imp fun hab h => hab (by simpa using congrArg Prod.snd h)
    · exact List.Pairwise.nil
  · refine (List.nodup_range).imp ?_
    intro a b hab x hx y hy
    split at hx
    · split at hy
      · simp only [List.mem_map] at hx hy
        obtain ⟨_, _, rfl⟩ := hx
        obtain ⟨_, _, rfl⟩ := hy
        intro h
        exact hab (by simpa using congrArg Prod.fst h)
      · simp at hy
    · simp at hx

theorem getD_map_range {β : Type} (f : Nat → β) (d : β) (n c : Nat) (h : c < n) :
    ((List.range n).map f).getD c d = f c := by
  simp [List.getD_eq_getElem?_getD, h]

/-- Whether the coin is in view at a tick of this state. -/
def inViewOf {α : Type} (s : StateOf α) (c : Nat) : Bool :=
  match s.view[c]? with
  | some v => !v.ended
  | none => false

/-- Whether the tick at `time` decides. -/
def decidesAt {α : Type} (s : StateOf α) (time : Int) : Bool :=
  match s.cfg.tickMs, s.prog with
  | some ms, some p => decide (time % (ms * (p.decideEvery : Int)) = 0)
  | _, _ => false

def slotCount {α : Type} (s : StateOf α) : Nat := match s.prog with | some p => p.slots.size | none => 0

theorem slotEvalAt_keys {α : Type} (N : Engine.Lang.NumOps α) (p : Engine.Lang.Program) (coins : Nat)
    (t : Engine.Lang.Tick α) (m : Engine.Lang.Mach α) :
    (Engine.Lang.slotEvalAt N p coins t m).wishes.map (fun x => (x.1, x.2.1)) =
      keysOf ((List.range coins).map t.inView) p.slots.size := by
  unfold Engine.Lang.slotEvalAt keysOf
  simp only [List.map_flatMap, List.length_map, List.length_range]
  simp only [List.flatMap]
  congr 1
  apply List.map_congr_left
  intro c hc
  have hc' := List.mem_range.1 hc
  rw [getD_map_range _ _ _ _ hc']
  split <;> simp [Function.comp_def]

/-- The state a tick reads: the view and the world's effects it takes by `time`, and the age counters. -/
def tickPre (s : State) (time : Int) : State := aged (releaseEffects (release s time) time)

/-- The coins in view at a tick of `s`, as the tick's log entry lists them. -/
def tickView (s : State) (time : Int) : List Bool :=
  (List.range (tickPre s time).coins.length).map (inViewOf (tickPre s time))

theorem tickPre_cfg (s : State) (time : Int) : (tickPre s time).cfg = s.cfg := rfl

theorem tickPre_prog (s : State) (time : Int) : (tickPre s time).prog = s.prog := rfl

theorem tickPre_coins (s : State) (time : Int) : (tickPre s time).coins = s.coins := rfl

theorem tickAt_eq (s : State) (time : Int) : tickAt s time = tickBody (tickPre s time) time := rfl

theorem tickBody_batch (u : State) (time : Int) :
    (∀ x ∈ (tickBody u time).2.2.wishes, x.sent = time ∧ x.arrives = time + u.cfg.lambda) ∧
    (tickBody u time).2.2.wishes.map (fun x => (x.coin, x.slot)) =
      (if decidesAt u time then keysOf ((List.range u.coins.length).map (inViewOf u)) (slotCount u) else []) := by
  have hrec : (tickBody u time).2.2.wishes = (match u.prog with
      | some p => if decidesAt u time then
          (Engine.Lang.slotEvalAt Engine.Lang.Numbers.ops p u.coins.length
            { inView := inViewOf u, input := sourceValue u, time := time,
              exactInput := fun c name slot => exactIn u time c (viewMarkAt u.cfg time u.coins c) name slot }
            (Engine.Lang.Mach.step Engine.Lang.Numbers.ops p
              { inView := inViewOf u, input := sourceValue u, time := time,
                exactInput := fun c name slot => exactIn u time c (viewMarkAt u.cfg time u.coins c) name slot }
              u.mach)).wishes.map (fun x => wishFor p u.vacct time u.cfg.lambda x.1 x.2.1 x.2.2)
        else []
      | none => []) := by
    unfold tickBody decidesAt
    cases u.prog <;> rfl
  rw [hrec]
  cases hp : u.prog with
  | none =>
    have : decidesAt u time = false := by simp [decidesAt, hp]
    simp [this]
  | some p =>
    by_cases hd : decidesAt u time = true
    · simp only [hd, ↓reduceIte, slotCount, hp]
      refine ⟨?_, ?_⟩
      · intro x hx
        simp only [List.mem_map] at hx
        obtain ⟨y, _, rfl⟩ := hx
        exact ⟨rfl, rfl⟩
      · rw [List.map_map]
        have := slotEvalAt_keys Engine.Lang.Numbers.ops p u.coins.length
          { inView := inViewOf u, input := sourceValue u, time := time,
            exactInput := fun c name slot => exactIn u time c (viewMarkAt u.cfg time u.coins c) name slot }
          (Engine.Lang.Mach.step Engine.Lang.Numbers.ops p
            { inView := inViewOf u, input := sourceValue u, time := time,
              exactInput := fun c name slot => exactIn u time c (viewMarkAt u.cfg time u.coins c) name slot }
            u.mach)
        rw [← this]
        rfl
    · have : decidesAt u time = false := by simpa using hd
      simp [this]

theorem tickAt_log (s : State) (time : Int) :
    (tickAt s time).1.log.map Log.core = s.log.map fun l =>
      { l.core with wishes := l.wishes ++ (tickAt s time).2.2.wishes, ticks := l.ticks ++ [(time, tickView s time)] } := by
  cases hl : s.log with
  | none => simp [tickAt_eq, tickBody, withLog, tickPre, aged, releaseEffects, release, hl]
  | some l =>
    simp [tickAt_eq, tickBody, withLog, tickPre, aged, releaseEffects, release, hl, Log.core, tickView, inViewOf]
    intros
    rfl

end Engine.Machine
