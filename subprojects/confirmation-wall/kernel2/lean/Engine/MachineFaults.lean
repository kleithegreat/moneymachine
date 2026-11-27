import Engine.MachineProofs

namespace Engine.Machine

/-- A check that found a fault. -/
abbrev Faulty {α : Type} (x : Checked α) : Prop := ∃ f, x = .error f

theorem admit_of_protected (s : State) (e : Event) (h : checkProtected e ≠ none) : Faulty (admit s e) := by
  unfold admit
  cases hp : checkProtected e with
  | none => simp [hp] at h
  | some f => exact ⟨f, rfl⟩

theorem admit_of_order (s : State) (e : Event) (h : checkOrder s e ≠ none) : Faulty (admit s e) := by
  unfold admit
  cases hp : checkProtected e with
  | some f => exact ⟨f, rfl⟩
  | none =>
    cases hh : checkHorizon s e with
    | some f => exact ⟨f, rfl⟩
    | none =>
      cases ho : checkOrder s e with
      | none => simp [ho] at h
      | some f => exact ⟨f, rfl⟩

theorem admit_of_ended (s : State) (e : Event) (h : checkEnded s e ≠ none) : Faulty (admit s e) := by
  unfold admit
  cases hp : checkProtected e with
  | some f => exact ⟨f, rfl⟩
  | none =>
    cases hh : checkHorizon s e with
    | some f => exact ⟨f, rfl⟩
    | none =>
      cases ho : checkOrder s e with
      | some f => exact ⟨f, rfl⟩
      | none =>
        cases he : checkEnded s e with
        | none => simp [he] at h
        | some f => exact ⟨f, rfl⟩

theorem admit_of_payload (s : State) (e : Event) (rules : Rules) (hr : s.rules[e.coin]? = some rules)
    (h : Faulty (checkPayload s e rules)) : Faulty (admit s e) := by
  unfold admit
  cases hp : checkProtected e with
  | some f => exact ⟨f, rfl⟩
  | none =>
    cases hh : checkHorizon s e with
    | some f => exact ⟨f, rfl⟩
    | none =>
      cases ho : checkOrder s e with
      | some f => exact ⟨f, rfl⟩
      | none =>
        cases he : checkEnded s e with
        | some f => exact ⟨f, rfl⟩
        | none => simp only [hr]; exact h

theorem step_reject (s : State) (e : Event) (h : Faulty (admit s e)) :
    (step s e).2 = Rows.empty ∧ (step s e).1.rejected.isSome := by
  unfold step
  cases hr : s.rejected with
  | some f => simp [hr]
  | none =>
    obtain ⟨f, hf⟩ := h
    simp [hf, StateOf.reject]

/-- A number as the rational its integer reading stands for, written as C2 states it. -/
def readRat (scale : Nat) (number : Number) : Option Rat :=
  let n := readInt scale number
  n.map (fun digits => (digits : Rat) / (10 : Rat) ^ scale)

theorem readRat_eq (scale : Nat) (number : Number) :
    readRat scale number = (readInt scale number).map (ofUnits scale) := by
  unfold readRat ofUnits
  cases readInt scale number <;> rfl

theorem ofUnits_lt_iff (scale : Nat) (a b : Int) : ofUnits scale a < ofUnits scale b ↔ a < b := by
  have hs : (0 : Rat) < (10 : Rat) ^ scale := Rat.pow_pos (by decide)
  unfold ofUnits
  rw [Rat.div_lt_iff hs, Rat.div_mul_cancel (by grind)]
  constructor <;> intro h <;> exact_mod_cast h

theorem ofUnits_le_iff (scale : Nat) (a b : Int) : ofUnits scale a ≤ ofUnits scale b ↔ a ≤ b := by
  rw [← Rat.not_lt, ← Int.not_lt, ofUnits_lt_iff]

theorem ofUnits_zero (scale : Nat) : ofUnits scale 0 = 0 := by
  unfold ofUnits
  rw [Rat.div_def]
  simp [Rat.zero_mul]

theorem ofUnits_le_zero (scale : Nat) (n : Int) : ofUnits scale n ≤ 0 ↔ n ≤ 0 := by
  have := ofUnits_le_iff scale n 0
  rwa [ofUnits_zero] at this

theorem ofUnits_lt_zero (scale : Nat) (n : Int) : ofUnits scale n < 0 ↔ n < 0 := by
  have := ofUnits_lt_iff scale n 0
  rwa [ofUnits_zero] at this

theorem zero_lt_ofUnits (scale : Nat) (n : Int) : 0 < ofUnits scale n ↔ 0 < n := by
  have := ofUnits_lt_iff scale 0 n
  rwa [ofUnits_zero] at this

theorem onGrid_ofUnits (figures : Nat) (decimals : Int) (scale : Nat) (n : Int) :
    Engine.Exact.onGrid figures decimals (ofUnits scale n) = Engine.Exact.onGridAt figures decimals scale n :=
  (Engine.Exact.onGridAt_eq figures decimals scale n).symm

def priceBadP (rules : Rules) (number : Number) : Prop :=
  match readRat 8 number with
  | none => True
  | some price => price ≤ 0 ∨ Engine.Exact.onGrid rules.figures rules.decimals price = false

def sizeBadP (rules : Rules) (number : Number) : Prop :=
  match readRat rules.szDecimals number with
  | none => True
  | some size => size ≤ 0

theorem checkPrice_ne (rules : Rules) (number : Number) (h : priceBadP rules number) :
    Faulty (checkPrice rules number) := by
  unfold checkPrice
  unfold priceBadP at h
  rw [readRat_eq] at h
  cases hr : readInt 8 number with
  | none => exact ⟨_, rfl⟩
  | some n =>
    rw [hr] at h
    simp only [Option.map_some] at h
    by_cases h0 : n ≤ 0
    · simp only [h0, ite_true]; exact ⟨_, rfl⟩
    · have : Engine.Exact.onGridAt rules.figures rules.decimals 8 n = false := by
        rcases h with h | h
        · exact absurd ((ofUnits_le_zero 8 n).1 h) h0
        · rw [← onGrid_ofUnits]; exact h
      simp only [h0, this, ite_true, ite_false]
      exact ⟨_, rfl⟩

theorem checkSize_ne (rules : Rules) (number : Number) (h : sizeBadP rules number) :
    Faulty (checkSize rules number) := by
  unfold checkSize
  unfold sizeBadP at h
  rw [readRat_eq] at h
  cases number with
  | placed d places =>
    simp only
    split
    · exact ⟨_, rfl⟩
    · cases hr : readInt rules.szDecimals (.placed d places) with
      | none => simp only []; exact ⟨_, rfl⟩
      | some n =>
        rw [hr] at h
        have : n ≤ 0 := (ofUnits_le_zero _ n).1 h
        simp only [this, ite_true]
        exact ⟨_, rfl⟩
  | bits b =>
    simp only
    cases hr : readInt rules.szDecimals (.bits b) with
    | none => exact ⟨_, rfl⟩
    | some n =>
      rw [hr] at h
      have : n ≤ 0 := (ofUnits_le_zero _ n).1 h
      simp only [this, ite_true]
      exact ⟨_, rfl⟩

theorem faulty_ne_ok {α : Type} {x : Checked α} (h : Faulty x) (a : α) : x ≠ .ok a := by
  obtain ⟨f, hf⟩ := h
  rw [hf]
  intro e
  cases e

theorem checkPrice_ok {rules : Rules} {number : Number} {p : Int} (h : checkPrice rules number = .ok p) :
    readInt 8 number = some p := by
  unfold checkPrice at h
  cases hr : readInt 8 number with
  | none => rw [hr] at h; cases h
  | some n =>
    rw [hr] at h
    dsimp only at h
    by_cases h0 : n ≤ 0
    · simp [h0, fail] at h
    · by_cases hg : Engine.Exact.onGridAt rules.figures rules.decimals 8 n = false
      · simp [h0, hg, fail] at h
      · simp only [h0, hg, ite_false] at h
        cases h
        rfl

theorem scanRest_ne (rules : Rules) (descending : Bool) :
    ∀ (ls : List Level) (before : Int),
      (∃ level ∈ ls, priceBadP rules level.price ∨ sizeBadP rules level.size) →
      Faulty (scanRest rules descending ls before) := by
  intro ls
  induction ls with
  | nil => intro before ⟨level, hl, _⟩; simp at hl
  | cons l rest ih =>
    intro before ⟨level, hl, hbad⟩
    unfold scanRest
    cases hp : checkPrice rules l.price with
    | error f => exact ⟨f, rfl⟩
    | ok price =>
      cases hs : checkSize rules l.size with
      | error f => exact ⟨f, rfl⟩
      | ok size =>
        dsimp only
        have hpl : ¬ priceBadP rules l.price := fun hb => faulty_ne_ok (checkPrice_ne rules _ hb) price hp
        have hsl : ¬ sizeBadP rules l.size := fun hb => faulty_ne_ok (checkSize_ne rules _ hb) size hs
        have hrest : ∃ level ∈ rest, priceBadP rules level.price ∨ sizeBadP rules level.size := by
          rcases List.mem_cons.mp hl with heq | hr
          · rw [heq] at hbad
            exact absurd hbad (by simp only [not_or]; exact ⟨hpl, hsl⟩)
          · exact ⟨level, hr, hbad⟩
        by_cases hc : (descending && decide (price < before) || !descending && decide (before < price)) = true
        · simp only [hc, ite_true]; exact ih _ hrest
        · simp only [hc]; exact ⟨_, rfl⟩

theorem scanSide_ne (rules : Rules) (descending : Bool) (best : Level) (rest : List Level)
    (h : ∃ level ∈ best :: rest, priceBadP rules level.price ∨ sizeBadP rules level.size) :
    Faulty (scanSide rules descending best rest) := by
  unfold scanSide
  cases hp : checkPrice rules best.price with
  | error f => exact ⟨f, rfl⟩
  | ok price =>
    cases hs : checkSize rules best.size with
    | error f => exact ⟨f, rfl⟩
    | ok size =>
      dsimp only
      have hpl : ¬ priceBadP rules best.price := fun hb => faulty_ne_ok (checkPrice_ne rules _ hb) price hp
      have hsl : ¬ sizeBadP rules best.size := fun hb => faulty_ne_ok (checkSize_ne rules _ hb) size hs
      have hrest : ∃ level ∈ rest, priceBadP rules level.price ∨ sizeBadP rules level.size := by
        obtain ⟨level, hl, hbad⟩ := h
        rcases List.mem_cons.mp hl with heq | hr
        · rw [heq] at hbad
          exact absurd hbad (by simp only [not_or]; exact ⟨hpl, hsl⟩)
        · exact ⟨level, hr, hbad⟩
      cases hr : scanRest rules descending rest price with
      | error f => exact ⟨f, rfl⟩
      | ok u => exact absurd hr (faulty_ne_ok (scanRest_ne rules descending rest price hrest) u)

theorem scanSide_ok {rules : Rules} {descending : Bool} {best : Level} {rest : List Level} {r : Int × Int}
    (h : scanSide rules descending best rest = .ok r) : readInt 8 best.price = some r.1 := by
  unfold scanSide at h
  cases hp : checkPrice rules best.price with
  | error f => rw [hp] at h; cases h
  | ok price =>
    rw [hp] at h
    dsimp only at h
    cases hs : checkSize rules best.size with
    | error f => rw [hs] at h; cases h
    | ok size =>
      rw [hs] at h
      dsimp only at h
      cases hr : scanRest rules descending rest price with
      | error f => rw [hr] at h; cases h
      | ok u =>
        rw [hr] at h
        dsimp only at h
        cases h
        exact checkPrice_ok hp

/-- A18's and A3's faults of an event's own fields, written as the law C2 states them. -/
def fieldsBadP (rules : Rules) (payload : Payload) : Prop :=
  match payload with
  | .trade _ price size _ => priceBadP rules price ∨ sizeBadP rules size
  | .quote bids asks =>
    bids = [] ∨ asks = [] ∨
    (∃ level ∈ bids ++ asks, priceBadP rules level.price ∨ sizeBadP rules level.size) ∨
    (∃ bid ask, bids.head? = some bid ∧ asks.head? = some ask ∧
      ∃ b a, readRat 8 bid.price = some b ∧ readRat 8 ask.price = some a ∧ a ≤ b)
  | .ending price =>
    match readRat 8 price with
    | none => True
    | some value => value < 0 ∨ (0 < value ∧ priceBadP rules price)
  | .funding _ rate oracle =>
    readRat 12 rate = none ∨ (∃ price, oracle = some price ∧ readRat 8 price = none)
  | .listing newRules => newRules.figures = 0 ∨ 8 < newRules.decimals ∨ 12 < newRules.szDecimals
  | .observation _ _ => False

theorem checkPayload_of_fields (s : State) (e : Event) (rules : Rules) (h : fieldsBadP rules e.payload) :
    Faulty (checkPayload s e rules) := by
  unfold checkPayload
  unfold fieldsBadP at h
  cases hpl : e.payload with
  | listing newRules =>
    rw [hpl] at h
    dsimp only at h
    rcases h with h | h | h <;> simp [h, fail] <;> exact ⟨_, rfl⟩
  | ending price =>
    rw [hpl] at h
    dsimp only at h
    simp only
    simp only [readRat_eq] at h
    cases hr : readInt 8 price with
    | none => exact ⟨_, rfl⟩
    | some n =>
      rw [hr] at h
      simp only [Option.map_some] at h
      by_cases h0 : n < 0
      · simp only [h0, ite_true]; exact ⟨_, rfl⟩
      · rcases h with h | ⟨hpos, hb⟩
        · exact absurd ((ofUnits_lt_zero 8 n).1 h) h0
        · have hn : 0 < n := (zero_lt_ofUnits 8 n).1 hpos
          have hg : Engine.Exact.onGridAt rules.figures rules.decimals 8 n = false := by
            unfold priceBadP at hb
            rw [readRat_eq] at hb
            rw [hr] at hb
            simp only [Option.map_some] at hb
            rcases hb with hb | hb
            · exact absurd ((ofUnits_le_zero 8 n).1 hb) (by omega)
            · rw [← onGrid_ofUnits]; exact hb
          simp only [h0, ite_false, hn, hg, decide_true, Bool.true_and]
          exact ⟨_, rfl⟩
  | funding hour rate oracle =>
    rw [hpl] at h
    dsimp only at h
    simp only
    simp only [readRat_eq] at h
    cases hr : readInt 12 rate with
    | none => exact ⟨_, rfl⟩
    | some _ =>
      simp only
      rcases h with h | ⟨price, ho, hnone⟩
      · rw [hr] at h; simp at h
      · subst ho
        cases hq : readInt 8 price with
        | none => simp only [hq]; exact ⟨_, rfl⟩
        | some _ => rw [hq] at hnone; simp at hnone
  | trade id price size seller =>
    rw [hpl] at h
    dsimp only at h
    simp only
    cases ht : s.cfg.trades with
    | none => exact ⟨_, rfl⟩
    | some _ =>
      simp only
      rcases h with h | h
      · cases hc : checkPrice rules price with
        | error f => exact ⟨f, rfl⟩
        | ok p => exact absurd hc (faulty_ne_ok (checkPrice_ne rules price h) p)
      · cases hc : checkPrice rules price with
        | error f => exact ⟨f, rfl⟩
        | ok p =>
          simp only
          cases hd : checkSize rules size with
          | error f => exact ⟨f, rfl⟩
          | ok z => exact absurd hd (faulty_ne_ok (checkSize_ne rules size h) z)
  | quote bids asks =>
    rw [hpl] at h
    dsimp only at h
    simp only
    cases hq : s.cfg.quotes with
    | none => exact ⟨_, rfl⟩
    | some _ =>
      simp only
      cases bids with
      | nil => exact ⟨_, rfl⟩
      | cons b rb =>
        cases asks with
        | nil => exact ⟨_, rfl⟩
        | cons a ra =>
          simp only
          cases hsb : scanSide rules true b rb with
          | error f => exact ⟨f, rfl⟩
          | ok bid =>
            cases hsa : scanSide rules false a ra with
            | error f => exact ⟨f, rfl⟩
            | ok ask =>
              simp only
              rcases h with h | h | h | h
              · exact absurd h (by simp)
              · exact absurd h (by simp)
              · obtain ⟨level, hl, hbad⟩ := h
                rcases List.mem_append.mp hl with hl | hl
                · exact absurd hsb (faulty_ne_ok (scanSide_ne rules true b rb ⟨level, hl, hbad⟩) bid)
                · exact absurd hsa (faulty_ne_ok (scanSide_ne rules false a ra ⟨level, hl, hbad⟩) ask)
              · obtain ⟨bidL, askL, hbh, hah, bq, aq, hb', ha', hle⟩ := h
                simp only [List.head?_cons, Option.some.injEq] at hbh hah
                subst hbh; subst hah
                have e1 := scanSide_ok hsb
                have e2 := scanSide_ok hsa
                simp only [readRat_eq] at hb' ha'
                rw [e1] at hb'
                rw [e2] at ha'
                simp only [Option.map_some, Option.some.injEq] at hb' ha'
                subst hb'; subst ha'
                have : ask.1 ≤ bid.1 := (ofUnits_le_iff 8 _ _).1 hle
                simp only [this, ite_true]
                exact ⟨_, rfl⟩
  | observation source bits => rw [hpl] at h; exact absurd h (by simp)

theorem checkRepeated_ne (s : State) (e : Event) (id : Int)
    (h : (∃ p, s.previous = some p ∧ p.time = e.time) ∧ (e.coin, id) ∈ s.ids) :
    checkRepeated s e id ≠ none := by
  obtain ⟨⟨p, hp, ht⟩, hm⟩ := h
  unfold checkRepeated
  rw [hp]
  have : s.ids.any (fun x => x.1 == e.coin && x.2 == id) = true := by
    rw [List.any_eq_true]
    exact ⟨(e.coin, id), hm, by simp⟩
  simp [ht, this, found]

theorem checkPayload_of_repeated (s : State) (e : Event) (rules : Rules) (id : Int)
    (h : (∃ p, s.previous = some p ∧ p.time = e.time) ∧ (e.coin, id) ∈ s.ids)
    (hp : ∃ price size seller, e.payload = .trade id price size seller) :
    Faulty (checkPayload s e rules) := by
  obtain ⟨price, size, seller, hp⟩ := hp
  unfold checkPayload
  rw [hp]
  simp only
  cases ht : s.cfg.trades with
  | none => exact ⟨_, rfl⟩
  | some _ =>
    simp only
    cases hc : checkPrice rules price with
    | error f => exact ⟨f, rfl⟩
    | ok p =>
      simp only
      cases hd : checkSize rules size with
      | error f => exact ⟨f, rfl⟩
      | ok z =>
        simp only
        have := checkRepeated_ne s e id h
        cases hr : checkRepeated s e id with
        | none => exact absurd hr this
        | some f => exact ⟨f, rfl⟩

theorem checkProtected_ne (e : Event)
    (h : ∃ window ∈ windows, window.released = false ∧ window.start ≤ e.time ∧ e.time < window.stop) :
    checkProtected e ≠ none := by
  obtain ⟨w, hw, hr, h1, h2⟩ := h
  unfold checkProtected
  have : windows.any (fun w => !w.released && decide (w.start ≤ e.time) && decide (e.time < w.stop)) = true := by
    rw [List.any_eq_true]
    exact ⟨w, hw, by simp [hr, h1, h2]⟩
  simp [this, found]

theorem checkOrder_ne (s : State) (e : Event)
    (h : ∃ p, s.previous = some p ∧ compare (eventKey e) (eventKey p) = .lt) : checkOrder s e ≠ none := by
  obtain ⟨p, hp, hc⟩ := h
  unfold checkOrder
  rw [hp]
  simp only
  rw [hc]
  simp [found]

theorem checkEnded_ne (s : State) (e : Event) (h : e.coin ∈ s.ended) : checkEnded s e ≠ none := by
  unfold checkEnded
  have : s.ended.contains e.coin = true := by simpa using h
  simp [h, found]

theorem rejected_run (state : State) (event : Event) (suffix : List Event)
    (hdec : decodeChunk state (pack [event]) = .ok [event]) (h : Faulty (admit state event)) :
    let rejected := feed state (pack [event])
    let after := feed rejected.1 (pack suffix)
    let final := finish after.1
    rejected.2.report = "" ∧ rejected.2.trace = "" ∧ after.2.report = "" ∧ after.2.trace = "" ∧
      final.1.report = "" ∧ final.1.trace = "" ∧ final.2.startsWith "{\"error\":" = true := by
  intro rejected after final
  obtain ⟨hrows, hrej⟩ := step_reject state event h
  have hgo : rejected = ((step state event).1, (step state event).2 ++ Rows.empty) := by
    show feed state (pack [event]) = _
    rw [feed_eq_go state _ [event] hdec]
    simp [go]
  obtain ⟨f, hf⟩ : ∃ f, (step state event).1.rejected = some f := by
    cases hr : (step state event).1.rejected with
    | none => rw [hr] at hrej; simp at hrej
    | some f => exact ⟨f, rfl⟩
  have h1 : rejected.1.rejected = some f := by rw [hgo]; exact hf
  have h2 : after = (rejected.1, Rows.empty) := by
    show feed rejected.1 (pack suffix) = _
    unfold feed; rw [h1]
  have h3 : final = (Rows.empty, "{\"error\":" ++ errorText f) := by
    show finish after.1 = _
    rw [h2]; unfold finish finishFull; rw [h1]
  have hr0 : rejected.2 = Rows.empty := by rw [hgo, hrows, Rows.append_empty]
  rw [hr0, h2, h3]
  refine ⟨rfl, rfl, rfl, rfl, rfl, rfl, ?_⟩
  simp only [String.startsWith_string_iff, String.toList_append, List.prefix_append]

end Engine.Machine
