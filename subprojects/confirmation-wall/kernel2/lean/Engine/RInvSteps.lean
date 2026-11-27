import Engine.TickBatch

/-!
# The log after each move that changes a core (brief 3 step 5)

Each lemma says what a core's log is after the move, given the log before it, as an equation the invariants rewrite by.
-/

namespace Engine.Machine

open Engine.Orders (Wish)

theorem tick_decomp (s : State) (time ms : Int) (l' : LogCore)
    (h : ({ (tickAt s time).1 with nextTick := some (time + ms) } : State).core.log = some l') :
    ∃ l : Log, s.log = some l ∧
      l' = { l.core with wishes := l.wishes ++ (tickAt s time).2.2.wishes, ticks := l.ticks ++ [(time, tickView s time)] } := by
  have e := tickAt_log s time
  have h' : (tickAt s time).1.log.map Log.core = some l' := h
  rw [h'] at e
  cases hl : s.log with
  | none => rw [hl] at e; simp at e
  | some l =>
    rw [hl] at e
    exact ⟨l, rfl, (Option.some.inj e)⟩

theorem arrive_decomp (s : State) (w : Wish) (rest : List Wish) (l' : LogCore)
    (h : ({ (arriveWish s w).1 with wishes := rest } : State).core.log = some l') :
    ∃ l : Log, s.log = some l ∧
      l' = { l.core with placed := l.placed ++ arrivalPlaced s w, arrivals := l.arrivals ++ [arrivalRecord s w],
                         admissions := l.admissions ++ arrivalAdmissions s w, steps := l.steps ++ arrivalSteps s w } := by
  have e := arriveWish_log s w
  have h' : (arriveWish s w).1.log.map Log.core = some l' := h
  rw [h'] at e
  cases hl : s.log with
  | none => rw [hl] at e; simp at e
  | some l =>
    rw [hl] at e
    exact ⟨l, rfl, (Option.some.inj e)⟩

theorem offer_decomp (s : State) (coin slot : Nat) (parts : List (Nat × Rat)) (role : Engine.Ledger.Role) (l' : LogCore)
    (h : (offer s coin slot parts role).1.core.log = some l') :
    (∃ l : Log, s.log = some l ∧ offerPlan s coin slot parts = none ∧ l' = l.core) ∨
    (∃ (l : Log) (p : Taken), s.log = some l ∧ offerPlan s coin slot parts = some p ∧
      l' = { l.core with
        fills := l.fills ++ [⟨{ p.order with remainder := p.remaining }, worldBook s p.time, p.units, p.time, stepCount s⟩],
        steps := l.steps ++ [⟨worldBook s p.time, worldBook (offerFinal s coin p role) p.time, .fill coin p.units, p.time,
          if p.ends then [coin] else []⟩] }) := by
  have e := offer_log s coin slot parts role
  have h' : (offer s coin slot parts role).1.log.map Log.core = some l' := h
  rw [h'] at e
  cases hp : offerPlan s coin slot parts with
  | none =>
    rw [hp] at e
    cases hl : s.log with
    | none => simp [hl] at e
    | some l =>
      left
      exact ⟨l, rfl, rfl, by simpa [hl] using e⟩
  | some p =>
    rw [hp] at e
    cases hl : s.log with
    | none => simp [hl] at e
    | some l =>
      right
      exact ⟨l, p, rfl, rfl, by simpa [hl] using e⟩

end Engine.Machine
