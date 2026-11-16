import Engine.MachineProofs

namespace Engine.Machine

theorem admit_of_protected (s : State) (e : Event) (h : checkProtected e ≠ none) : admit s e ≠ none := by
  unfold admit
  cases hp : checkProtected e with
  | none => simp [hp] at h
  | some f => simp

theorem admit_of_order (s : State) (e : Event) (h : checkOrder s e ≠ none) : admit s e ≠ none := by
  unfold admit
  cases hp : checkProtected e with
  | some f => simp
  | none =>
    cases hh : checkHorizon s e with
    | some f => simp
    | none =>
      cases ho : checkOrder s e with
      | none => simp [ho] at h
      | some f => simp

theorem admit_of_ended (s : State) (e : Event) (h : checkEnded s e ≠ none) : admit s e ≠ none := by
  unfold admit
  cases hp : checkProtected e with
  | some f => simp
  | none =>
    cases hh : checkHorizon s e with
    | some f => simp
    | none =>
      cases ho : checkOrder s e with
      | some f => simp
      | none =>
        cases he : checkEnded s e with
        | none => simp [he] at h
        | some f => simp

theorem admit_of_payload (s : State) (e : Event) (rules : Rules) (hr : s.rules[e.coin]? = some rules)
    (h : checkPayload s e rules ≠ none) : admit s e ≠ none := by
  unfold admit
  cases hp : checkProtected e with
  | some f => simp
  | none =>
    cases hh : checkHorizon s e with
    | some f => simp
    | none =>
      cases ho : checkOrder s e with
      | some f => simp
      | none =>
        cases he : checkEnded s e with
        | some f => simp
        | none => simp [hr, h]

theorem step_reject (s : State) (e : Event) (h : admit s e ≠ none) :
    (step s e).2 = Rows.empty ∧ (step s e).1.rejected.isSome := by
  unfold step
  cases hr : s.rejected with
  | some f => simp [hr]
  | none =>
    cases ha : admit s e with
    | none => simp [ha] at h
    | some f => simp [State.reject]

def priceBadP (rules : Rules) (number : Number) : Prop :=
  match readRat 8 number with
  | none => True
  | some price => price ≤ 0 ∨ Engine.Exact.onGrid rules.figures rules.decimals price = false

def sizeBadP (rules : Rules) (number : Number) : Prop :=
  match readRat rules.szDecimals number with
  | none => True
  | some size => size ≤ 0

theorem checkPrice_ne (rules : Rules) (number : Number) (h : priceBadP rules number) :
    checkPrice rules number ≠ none := by
  unfold checkPrice
  unfold priceBadP at h
  split
  · simp [found]
  · rename_i price hp
    rw [hp] at h
    by_cases h0 : price ≤ 0
    · simp [h0, found]
    · have : Engine.Exact.onGrid rules.figures rules.decimals price = false := by
        rcases h with h | h
        · exact absurd h h0
        · exact h
      simp [h0, this, found]

theorem checkSize_ne (rules : Rules) (number : Number) (h : sizeBadP rules number) :
    checkSize rules number ≠ none := by
  unfold checkSize
  unfold sizeBadP at h
  cases number with
  | placed d places =>
    simp only
    split
    · simp [found]
    · split
      · simp [found]
      · rename_i size hs
        rw [hs] at h
        have : size ≤ 0 := h
        simp [this, found]
  | bits b =>
    simp only
    split
    · simp [found]
    · rename_i size hs
      rw [hs] at h
      have : size ≤ 0 := h
      simp [this, found]

theorem scanSide_ne (rules : Rules) (descending : Bool) :
    ∀ (ls : List Level) (previous : Option Rat),
      (∃ level ∈ ls, priceBadP rules level.price ∨ sizeBadP rules level.size) →
      scanSide rules descending ls previous ≠ none := by
  intro ls
  induction ls with
  | nil => intro previous ⟨level, hl, _⟩; simp at hl
  | cons l rest ih =>
    intro previous ⟨level, hl, hbad⟩
    unfold scanSide
    split
    · simp [found]
    · rename_i price hp
      by_cases h0 : price ≤ 0
      · simp [h0, found]
      · by_cases hg : Engine.Exact.onGrid rules.figures rules.decimals price = false
        · simp [h0, hg, found]
        · have hg' : Engine.Exact.onGrid rules.figures rules.decimals price = true := by simpa using hg
          rw [if_neg h0, if_neg (by simp [hg'])]
          cases hs : checkSize rules l.size with
          | some f => simp
          | none =>
            have hpl : ¬ priceBadP rules l.price := by
              unfold priceBadP; rw [hp]; simp [h0, hg']
            have hsl : ¬ sizeBadP rules l.size := by
              intro hb; exact checkSize_ne rules l.size hb hs
            simp only
            have hrest : ∃ level ∈ rest, priceBadP rules level.price ∨ sizeBadP rules level.size := by
              rcases List.mem_cons.mp hl with heq | hr
              · rw [heq] at hbad
                exact absurd hbad (by simp only [not_or]; exact ⟨hpl, hsl⟩)
              · exact ⟨level, hr, hbad⟩
            cases previous with
            | none => exact ih _ hrest
            | some before =>
              by_cases hc : (descending && decide (price < before) || !descending && decide (before < price)) = true
              · simp only [hc, if_true]; exact ih _ hrest
              · simp only [hc, if_false, found]; simp

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
    checkPayload s e rules ≠ none := by
  unfold checkPayload
  unfold fieldsBadP at h
  cases hpl : e.payload with
  | listing newRules =>
    rw [hpl] at h
    dsimp only at h
    rcases h with h | h | h <;> simp [h, found]
  | ending price =>
    rw [hpl] at h
    dsimp only at h
    simp only
    split
    · simp [found]
    · rename_i value hv
      rw [hv] at h
      by_cases h0 : value < 0
      · simp [h0, found]
      · rcases h with h | ⟨hpos, hb⟩
        · exact absurd h h0
        · have hg : Engine.Exact.onGrid rules.figures rules.decimals value = false := by
            unfold priceBadP at hb
            rw [hv] at hb
            rcases hb with hb | hb
            · exact absurd hb (Rat.not_le.mpr hpos)
            · exact hb
          simp [h0, hpos, hg, found]
  | funding hour rate oracle =>
    rw [hpl] at h
    dsimp only at h
    simp only
    cases hr : readRat 12 rate with
    | none => simp [found]
    | some _ =>
      rcases h with h | ⟨price, ho, hnone⟩
      · rw [hr] at h; simp at h
      · subst ho
        simp [hnone, found]
  | trade id price size seller =>
    rw [hpl] at h
    dsimp only at h
    simp only
    cases ht : s.cfg.trades with
    | none => simp [found]
    | some _ =>
      simp only
      rcases h with h | h
      · have := checkPrice_ne rules price h
        cases hc : checkPrice rules price with
        | none => exact absurd hc this
        | some f => simp
      · cases hc : checkPrice rules price with
        | some f => simp
        | none =>
          have := checkSize_ne rules size h
          cases hd : checkSize rules size with
          | none => exact absurd hd this
          | some f => simp
  | quote bids asks =>
    rw [hpl] at h
    dsimp only at h
    simp only
    cases hq : s.cfg.quotes with
    | none => simp [found]
    | some _ =>
      simp only
      by_cases hb : bids.isEmpty || asks.isEmpty
      · simp [hb, found]
      · simp only [hb, Bool.false_eq_true, if_false, ite_false]
        have hbids : bids ≠ [] := by intro e; simp [e] at hb
        have hasks : asks ≠ [] := by intro e; simp [e] at hb
        cases hsb : scanSide rules true bids none with
        | some f => simp
        | none =>
          cases hsa : scanSide rules false asks none with
          | some f => simp
          | none =>
            simp only
            rcases h with h | h | h | h
            · exact absurd h hbids
            · exact absurd h hasks
            · obtain ⟨level, hl, hbad⟩ := h
              rcases List.mem_append.mp hl with hl | hl
              · exact absurd hsb (scanSide_ne rules true bids none ⟨level, hl, hbad⟩)
              · exact absurd hsa (scanSide_ne rules false asks none ⟨level, hl, hbad⟩)
            · obtain ⟨bid, ask, hbh, hah, b, a, hb', ha', hle⟩ := h
              have hc : crossed bids asks = true := by
                unfold crossed
                rw [hbh, hah]
                simp [hb', ha', hle]
              simp [hc, found]
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
    checkPayload s e rules ≠ none := by
  obtain ⟨price, size, seller, hp⟩ := hp
  unfold checkPayload
  rw [hp]
  simp only
  cases ht : s.cfg.trades with
  | none => simp [found]
  | some _ =>
    simp only
    cases hc : checkPrice rules price with
    | some f => simp
    | none =>
      cases hd : checkSize rules size with
      | some f => simp
      | none =>
        simp only
        have := checkRepeated_ne s e id h
        cases hr : checkRepeated s e id with
        | none => exact absurd hr this
        | some f => simp

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
    (hdec : decodeChunk state (pack [event]) = .ok [event]) (h : admit state event ≠ none) :
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
    rw [h2]; unfold finish; rw [h1]
  have hr0 : rejected.2 = Rows.empty := by rw [hgo, hrows, Rows.append_empty]
  rw [hr0, h2, h3]
  refine ⟨rfl, rfl, rfl, rfl, rfl, rfl, ?_⟩
  simp only [String.startsWith_string_iff, String.toList_append, List.prefix_append]

end Engine.Machine
