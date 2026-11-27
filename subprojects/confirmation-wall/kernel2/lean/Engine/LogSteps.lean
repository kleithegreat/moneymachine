import Engine.Closure

/-!
# What each move writes in the log (brief 3 step 5)

The three moves that write the log append to some of its lists and leave the others as they were. Each list's lemma reads
the log as an option, `none` for an ordinary run.
-/

namespace Engine.Machine

open Engine.Orders (Wish Book Order Placement Arrival CycleStep OrderFill Trigger arrive cancelSlot)

variable {α : Type}

/-! ### A wish arrives -/

/-- What the arrival of `w` at `s` appends to a log's lists. -/
def arrivalSteps (s : StateOf α) (w : Wish) : List CycleStep :=
  let effects := arrivalEffects (worldBook s w.arrives) w
  if effects.isEmpty then []
  else [⟨worldBook s w.arrives, worldBook (emit s w.arrives effects).1 w.arrives, .other, w.arrives, []⟩]

def arrivalAdmissions (s : StateOf α) (w : Wish) : List (Book × Order) :=
  let book := worldBook s w.arrives
  if ((arrive book w).2.any fun tag => tag == "placed" || tag.startsWith "refused:") then
    (Option.map (fun o => (cancelSlot book w.coin w.slot, o)) (Engine.Orders.prepare (cancelSlot book w.coin w.slot) w)).toList
  else []

def arrivalPlaced (s : StateOf α) (w : Wish) : List Placement :=
  let book := worldBook s w.arrives
  if (arrive book w).2.contains "placed" then
    ((Engine.Orders.prepare (cancelSlot book w.coin w.slot) w).bind fun o =>
      w.value.map fun v => (⟨o, v, book.rules w.coin, stepCount s⟩ : Placement)).toList
  else []

def arrivalRecord (s : StateOf α) (w : Wish) : Arrival :=
  ⟨worldBook s w.arrives, (arrive (worldBook s w.arrives) w).1, w, w.arrives⟩

theorem arriveWish_log (s : StateOf α) (w : Wish) :
    (arriveWish s w).1.log.map Log.core = s.log.map fun l =>
      { l.core with placed := l.placed ++ arrivalPlaced s w, arrivals := l.arrivals ++ [arrivalRecord s w],
                    admissions := l.admissions ++ arrivalAdmissions s w, steps := l.steps ++ arrivalSteps s w } := by
  cases hl : s.log with
  | none => simp [arriveWish, pushHistory, withLog, emit_log, hl]
  | some l => simp [arriveWish, pushHistory, withLog, emit_log, hl, Log.core, arrivalPlaced, arrivalRecord,
      arrivalAdmissions, arrivalSteps]

/-! ### An order fills -/

/-- The state after the fill and the cycle's end of an offer, before the log. -/
def offerFinal (s : StateOf α) (coin : Nat) (p : Taken) (role : Engine.Ledger.Role) : StateOf α :=
  let s1 := (emit s p.time [Engine.World.Effect.fill p.order p.units p.price role]).1
  let cancels := if p.ends then (s1.acct.orders.filter (·.coin == coin)).map fun o => Engine.World.Effect.cancelled o "cycle_end"
    else []
  (emit s1 p.time (cancels ++ if p.ends then [Engine.World.Effect.cycleEnd coin (s.acct.cycle coin)] else [])).1

theorem applyOffer_log (s : StateOf α) (coin : Nat) (p : Taken) (role : Engine.Ledger.Role) :
    (applyOffer s coin p role).1.log.map Log.core = s.log.map fun l =>
      { l.core with
        fills := l.fills ++ [⟨{ p.order with remainder := p.remaining }, worldBook s p.time, p.units, p.time, stepCount s⟩],
        steps := l.steps ++ [⟨worldBook s p.time, worldBook (offerFinal s coin p role) p.time, .fill coin p.units, p.time,
          if p.ends then [coin] else []⟩] } := by
  cases hl : s.log with
  | none => simp [applyOffer, pushHistory, withLog, emit_log, hl]
  | some l => simp [applyOffer, pushHistory, withLog, emit_log, hl, Log.core, offerFinal]

theorem offer_log (s : StateOf α) (coin slot : Nat) (parts : List (Nat × Rat)) (role : Engine.Ledger.Role) :
    (offer s coin slot parts role).1.log.map Log.core = match offerPlan s coin slot parts with
      | none => s.log.map Log.core
      | some p => s.log.map fun l =>
        { l.core with
          fills := l.fills ++ [⟨{ p.order with remainder := p.remaining }, worldBook s p.time, p.units, p.time, stepCount s⟩],
          steps := l.steps ++ [⟨worldBook s p.time, worldBook (offerFinal s coin p role) p.time, .fill coin p.units, p.time,
            if p.ends then [coin] else []⟩] } := by
  unfold offer
  cases offerPlan s coin slot parts with
  | none => rfl
  | some p => exact applyOffer_log s coin p role

end Engine.Machine
