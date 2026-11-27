import Engine.AInvClauses

/-!
# R1's tick invariants (brief 3 step 5)

The ticks of a run are the multiples of the step from the first at or after the horizon's start, one entry each in the log;
each deciding tick sent one wish for every slot of every coin in view, and no other wish was sent.
-/

namespace Engine.Machine

open Engine.Orders (Wish)

/-- Whether a tick at `t` decides, for a core. -/
def decidesC (c : Core) (t : Int) : Bool :=
  match c.cfg.tickMs, c.prog with
  | some ms, some p => decide (t % (ms * (p.decideEvery : Int)) = 0)
  | _, _ => false

def slotsC (c : Core) : Nat := match c.prog with | some p => p.slots.size | none => 0

/-- The first tick at or after the horizon's start. -/
def firstTick (start ms : Int) : Int := (start + ms - 1) / ms * ms

structure TInv (c : Core) : Prop where
  sentTick : ∀ l, c.log = some l → ∀ w ∈ l.wishes, ∃ tk ∈ l.ticks, tk.1 = w.sent
  keys : ∀ l, c.log = some l → ∀ tk ∈ l.ticks,
    (l.wishes.filter (fun w => decide (w.sent = tk.1))).map (fun w => (w.coin, w.slot)) =
      if decidesC c tk.1 then keysOf tk.2 (slotsC c) else []
  progression : ∀ l, c.log = some l → ∀ ms, c.cfg.tickMs = some ms → ∃ k : Nat,
    l.ticks.map (·.1) = (List.range k).map (fun (j : Nat) => firstTick c.cfg.start ms + (j : Int) * ms) ∧
      c.nextTick = some (firstTick c.cfg.start ms + (k : Int) * ms)
  beforeStop : ∀ l, c.log = some l → ∀ tk ∈ l.ticks, tk.1 < c.cfg.stop
  beforeNext : ∀ l, c.log = some l → ∀ tk ∈ l.ticks, ∀ t, c.nextTick = some t → tk.1 < t

theorem tInv_congr {c c' : Core} (h : TInv c) (hcfg : c'.cfg = c.cfg) (hp : c'.prog = c.prog) (hn : c'.nextTick = c.nextTick)
    (hl : c'.log.map (fun l => (l.wishes, l.ticks)) = c.log.map (fun l => (l.wishes, l.ticks))) : TInv c' := by
  have key : ∀ l', c'.log = some l' → ∃ l, c.log = some l ∧ l'.wishes = l.wishes ∧ l'.ticks = l.ticks := by
    intro l' hl'
    rw [hl'] at hl
    cases hc : c.log with
    | none => rw [hc] at hl; simp at hl
    | some l =>
      rw [hc] at hl
      simp only [Option.map_some, Option.some.injEq, Prod.mk.injEq] at hl
      exact ⟨l, rfl, hl.1, hl.2⟩
  have hd : ∀ t, decidesC c' t = decidesC c t := by intro t; simp [decidesC, hcfg, hp]
  have hs : slotsC c' = slotsC c := by simp [slotsC, hp]
  refine ⟨?_, ?_, ?_, ?_, ?_⟩
  · intro l' hl' w hw; obtain ⟨l, hlc, e1, e2⟩ := key l' hl'; rw [e1] at hw; rw [e2]; exact h.sentTick l hlc w hw
  · intro l' hl' tk htk; obtain ⟨l, hlc, e1, e2⟩ := key l' hl'; rw [e2] at htk; rw [e1, hd, hs]; exact h.keys l hlc tk htk
  · intro l' hl' ms hms; obtain ⟨l, hlc, e1, e2⟩ := key l' hl'
    rw [hcfg] at hms
    obtain ⟨k, hk1, hk2⟩ := h.progression l hlc ms hms
    exact ⟨k, by rw [e2, hcfg]; exact hk1, by rw [hn, hcfg]; exact hk2⟩
  · intro l' hl' tk htk; obtain ⟨l, hlc, e1, e2⟩ := key l' hl'; rw [e2] at htk; rw [hcfg]; exact h.beforeStop l hlc tk htk
  · intro l' hl' tk htk t ht; obtain ⟨l, hlc, e1, e2⟩ := key l' hl'; rw [e2] at htk; rw [hn] at ht
    exact h.beforeNext l hlc tk htk t ht

end Engine.Machine
