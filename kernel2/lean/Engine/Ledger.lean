namespace Engine.Ledger

inductive Role where
  | maker
  | taker
  deriving DecidableEq, Repr

structure Position where
  units : Rat
  cost : Rat
  deriving DecidableEq, Repr

structure Tier where
  start : Int
  name : String
  maker : Rat
  taker : Rat
  deriving DecidableEq, Repr

inductive Event where
  | fill (time : Int) (coin : Nat) (units price : Rat) (role : Role)
  | funding (time hour : Int) (coin : Nat) (oracle rate : Rat)
  | absorb

structure State where
  cash : Rat
  positions : List Position
  realized : Rat
  fees : Rat
  funding : Rat
  absorbed : Rat
  bankrupt : Bool
  deriving DecidableEq, Repr

structure Receipt where
  state : State
  fee : Rat
  closedPnl : Rat
  tier : Option String
  rate : Option Rat

def initial (cash : Rat) (coins : Nat) : State :=
  { cash, positions := List.replicate coins { units := 0, cost := 0 },
    realized := 0, fees := 0, funding := 0, absorbed := 0, bankrupt := false }

def position (s : State) (coin : Nat) : Position :=
  (s.positions[coin]?).getD { units := 0, cost := 0 }

def entry (s : State) (coin : Nat) : Option Rat :=
  let p := position s coin
  if p.units = 0 then none else some (p.cost / p.units)

def equity (s : State) (marks : List Rat) : Rat :=
  s.cash + (s.positions.zip marks).foldl (fun total (p, m) => total + p.units * m) 0

def unrealized (s : State) (marks : List Rat) : Rat :=
  (s.positions.zip marks).foldl (fun total (p, m) => total + p.units * m - p.cost) 0

/-- The tier in force at `time`: the last of the list that has started. -/
def active : List Tier → Int → Option Tier
  | [], _ => none
  | t :: ts, time =>
    match active ts time with
    | some a => some a
    | none => if t.start ≤ time then some t else none

def rateOk (t : Tier) : Bool :=
  decide (0 ≤ t.maker ∧ t.maker ≤ 1 ∧ 0 ≤ t.taker ∧ t.taker ≤ 1)

def scheduleOk (fees : List Tier) : Bool :=
  fees.all rateOk && decide (fees.Pairwise (fun a b => a.start < b.start))

/-- The position after a fill and the profit it realizes: exact, with no rounding. -/
def fillPosition (old : Position) (units price : Rat) : Position × Rat :=
  let next := old.units + units
  let pnl := if old.units * units < 0 then
      min (if old.units < 0 then -old.units else old.units)
          (if units < 0 then -units else units) *
        (if old.units < 0 then -1 else 1) * (price - old.cost / old.units)
    else 0
  let cost := if old.units = 0 ∨ 0 < old.units * units then old.cost + units * price
    else if next = 0 then 0
    else if 0 < old.units * next then old.cost * next / old.units
    else next * price
  ({ units := next, cost }, pnl)

def step (fees : List Tier) (s : State) (event : Event) : Except String Receipt :=
  if s.bankrupt then .error "E_BANKRUPT" else
  match event with
  | .fill time coin units price role =>
    if coin < s.positions.length ∧ units ≠ 0 ∧ 0 < price then
      match active fees time with
      | none => .error "E_NO_TIER"
      | some tier =>
        let rate := match role with
          | .maker => tier.maker
          | .taker => tier.taker
        let fee := (if units < 0 then -units else units) * price * rate
        let moved := fillPosition (position s coin) units price
        .ok { state := { s with
                cash := s.cash - units * price - fee
                positions := s.positions.set coin moved.1
                realized := s.realized + moved.2
                fees := s.fees + fee },
              fee, closedPnl := moved.2, tier := some tier.name, rate := some rate }
    else .error "E_FILL"
  | .funding _ _ coin oracle rate =>
    if coin < s.positions.length then
      let payment := (position s coin).units * oracle * rate
      .ok { state := { s with cash := s.cash - payment, funding := s.funding + payment },
            fee := 0, closedPnl := 0, tier := none, rate := none }
    else .error "E_FUNDING"
  | .absorb =>
    if (∀ p ∈ s.positions, p.units = 0 ∧ p.cost = 0) ∧ s.cash ≤ 0 then
      .ok { state := { s with cash := 0, absorbed := s.absorbed - s.cash, bankrupt := true },
            fee := 0, closedPnl := 0, tier := none, rate := none }
    else .error "E_ABSORB"

def replayStep (fees : List Tier) (init : State) (acc : Except String (List Receipt))
    (event : Event) : Except String (List Receipt) :=
  match acc with
  | .error code => .error code
  | .ok receipts =>
    let state := (receipts.getLast?).map Receipt.state |>.getD init
    match step fees state event with
    | .error code => .error code
    | .ok receipt => .ok (receipts ++ [receipt])

def replay (cash : Rat) (coins : Nat) (fees : List Tier) (events : List Event) :
    Except String (List Receipt) :=
  if scheduleOk fees then events.foldl (replayStep fees (initial cash coins)) (.ok [])
  else .error "E_FEE_SCHEDULE"

/-- The due-hour check: every held hour whose lateness has run out inside the horizon has its
funding event, inside the lateness. -/
def checkFunding (start finish late : Int) (held : List (Nat × Int)) (events : List Event) :
    Except String Unit :=
  let supplied (o : Nat × Int) : Bool := events.any fun
    | .funding time hour coin _ _ =>
      decide (coin = o.1 ∧ hour = o.2 ∧ hour ≤ time ∧ time ≤ hour + late)
    | _ => false
  let missing (o : Nat × Int) : Bool :=
    decide (o.2 % 3600000 = 0 ∧ start ≤ o.2 ∧ o.2 + late < finish) && !supplied o
  if held.any missing then .error "R_SETTLEMENT_MISSING" else .ok ()


theorem active_spec : ∀ (l : List Tier) (time : Int) (a : Tier),
    active l time = some a → a ∈ l ∧ a.start ≤ time
  | [], _, _, h => by simp [active] at h
  | t :: ts, time, a, h => by
    simp only [active] at h
    split at h
    · rename_i b hb
      have ih := active_spec ts time b hb
      cases h
      exact ⟨List.mem_cons_of_mem _ ih.1, ih.2⟩
    · split at h
      · rename_i hle
        cases h
        exact ⟨List.mem_cons_self, hle⟩
      · cases h

theorem active_eq : ∀ (l : List Tier) (time : Int) (x : Tier),
    l.Pairwise (fun a b => a.start < b.start) → x ∈ l → x.start ≤ time →
    (∀ y ∈ l, y.start ≤ time → y.start ≤ x.start) → active l time = some x
  | [], _, _, _, hx, _, _ => by simp at hx
  | t :: ts, time, x, hp, hx, hxt, hmax => by
    rw [List.pairwise_cons] at hp
    obtain ⟨hhead, htail⟩ := hp
    simp only [active]
    rcases List.mem_cons.1 hx with rfl | hxs
    · have hnone : active ts time = none := by
        cases h : active ts time with
        | none => rfl
        | some a =>
          have ⟨ha, hat⟩ := active_spec ts time a h
          have := hmax a (List.mem_cons_of_mem _ ha) hat
          have := hhead a ha
          omega
      rw [hnone]
      simp [hxt]
    · have := active_eq ts time x htail hxs hxt
        (fun y hy hyt => hmax y (List.mem_cons_of_mem _ hy) hyt)
      rw [this]

def totalCost : List Position → Rat
  | [] => 0
  | p :: ps => p.cost + totalCost ps

theorem foldl_cost_acc : ∀ (ps : List Position) (a : Rat),
    ps.foldl (fun total p => total + p.cost) a = a + totalCost ps
  | [], a => by simp only [List.foldl_nil, totalCost]; grind
  | p :: ps, a => by
    simp only [List.foldl_cons, totalCost]
    rw [foldl_cost_acc ps (a + p.cost)]
    grind

theorem foldl_cost (ps : List Position) :
    ps.foldl (fun total p => total + p.cost) 0 = totalCost ps := by
  rw [foldl_cost_acc]
  grind

theorem totalCost_set : ∀ (ps : List Position) (i : Nat) (p : Position), i < ps.length →
    totalCost (ps.set i p) = totalCost ps - ((ps[i]?).getD ⟨0, 0⟩).cost + p.cost
  | [], i, p, h => by simp at h
  | q :: qs, 0, p, _ => by
    simp only [List.set_cons_zero, totalCost, List.getElem?_cons_zero, Option.getD_some]
    grind
  | q :: qs, i + 1, p, h => by
    have ih := totalCost_set qs i p (by simpa using h)
    simp only [List.set_cons_succ, totalCost, List.getElem?_cons_succ]
    grind

theorem totalCost_replicate (n : Nat) : totalCost (List.replicate n ⟨0, 0⟩) = 0 := by
  induction n with
  | zero => rfl
  | succ n ih =>
    simp only [List.replicate_succ, totalCost]
    grind

theorem opp_sign {q u : Rat} (h : q * u < 0) : (q < 0 ∧ 0 < u) ∨ (0 < q ∧ u < 0) := by
  have hq : q < 0 ∨ q = 0 ∨ 0 < q := by grind
  have hu : u < 0 ∨ u = 0 ∨ 0 < u := by grind
  rcases hq with hq | hq | hq <;> rcases hu with hu | hu | hu
  · have h1 : 0 < -q := by grind
    have h2 : 0 < -u := by grind
    have := Rat.mul_pos h1 h2
    grind
  · subst hu; simp at h
  · exact Or.inl ⟨hq, hu⟩
  · subst hq; simp at h
  · subst hq; simp at h
  · subst hq; simp at h
  · exact Or.inr ⟨hq, hu⟩
  · subst hu; simp at h
  · have := Rat.mul_pos hq hu
    grind

theorem fill_cost (old : Position) (units price : Rat) (hu : units ≠ 0) :
    (fillPosition old units price).1.cost =
      old.cost + units * price + (fillPosition old units price).2 := by
  unfold fillPosition
  simp only
  by_cases h0 : old.units = 0
  · simp [h0]; grind
  by_cases hp : 0 < old.units * units
  · have : ¬ old.units * units < 0 := by grind
    simp [hp, this]; grind
  have hn : old.units * units < 0 := by
    have : old.units * units ≠ 0 := by
      intro h
      rcases Rat.mul_eq_zero.1 h with h | h <;> contradiction
    grind
  simp only [hn, ↓reduceIte, h0, hp, false_or]
  have hmin : ∀ a b : Rat, min a b = if a ≤ b then a else b := fun a b => rfl
  rcases opp_sign hn with ⟨hq, hu'⟩ | ⟨hq, hu'⟩
  · have hu'' : ¬ units < 0 := by grind
    have hnq : 0 < -old.units := by grind
    simp only [hq, hu'', ↓reduceIte, hmin]
    by_cases hz : old.units + units = 0
    · have : units = -old.units := by grind
      simp only [this]
      grind
    by_cases hpos : 0 < old.units + units
    · have h1 := Rat.mul_pos hnq hpos
      have h2 : ¬ 0 < old.units * (old.units + units) := by grind
      have h3 : -old.units ≤ units := by grind
      simp only [hz, h2, h3, ↓reduceIte]
      grind
    · have hneg : old.units + units < 0 := by grind
      have h1 := Rat.mul_pos hnq (show 0 < -(old.units + units) by grind)
      have h2 : 0 < old.units * (old.units + units) := by grind
      have h3 : ¬ -old.units ≤ units := by grind
      simp only [hz, h2, h3, ↓reduceIte]
      grind
  · have hu'' : units < 0 := hu'
    have hnu : 0 < -units := by grind
    have hq' : ¬ old.units < 0 := by grind
    simp only [hq', hu'', ↓reduceIte, hmin]
    by_cases hz : old.units + units = 0
    · have : units = -old.units := by grind
      simp only [this]
      grind
    by_cases hpos : 0 < old.units + units
    · have h1 := Rat.mul_pos hq hpos
      have h2 : 0 < old.units * (old.units + units) := by grind
      have h3 : ¬ old.units ≤ -units := by grind
      simp only [hz, h2, h3, ↓reduceIte]
      grind
    · have hneg : old.units + units < 0 := by grind
      have h1 := Rat.mul_pos hq (show 0 < -(old.units + units) by grind)
      have h2 : ¬ 0 < old.units * (old.units + units) := by grind
      have h3 : old.units ≤ -units := by grind
      simp only [hz, h2, h3, ↓reduceIte]
      grind

def flow : Event → Rat
  | .fill _ _ units price _ => units * price
  | .funding .. => 0
  | .absorb => 0

theorem step_balances (fees : List Tier) (s : State) (event : Event) (r : Receipt)
    (h : step fees s event = .ok r) :
    r.state.cash - r.state.absorbed + r.state.fees + r.state.funding + flow event =
      s.cash - s.absorbed + s.fees + s.funding ∧
    r.state.cash - r.state.realized + totalCost r.state.positions + r.state.fees
        + r.state.funding - r.state.absorbed =
      s.cash - s.realized + totalCost s.positions + s.fees + s.funding - s.absorbed := by
  unfold step at h
  split at h
  · cases h
  · split at h
    · rename_i time coin units price role
      split at h
      · rename_i hc
        split at h
        · cases h
        · rename_i tier _
          cases h
          have hcost := fill_cost (position s coin) units price hc.2.1
          have hset := totalCost_set s.positions coin
            (fillPosition (position s coin) units price).1 hc.1
          have hpos : (s.positions[coin]?).getD ⟨0, 0⟩ = position s coin := rfl
          rw [hpos] at hset
          simp only [flow]
          constructor <;> grind
      · cases h
    · rename_i time hour coin oracle rate
      split at h
      · cases h
        simp only [flow]
        constructor <;> grind
      · cases h
    · split at h
      · cases h
        simp only [flow]
        constructor <;> grind
      · cases h

def Chain (fees : List Tier) : State → List Event → List Receipt → Prop
  | _, [], [] => True
  | s, e :: es, r :: rs => step fees s e = .ok r ∧ Chain fees r.state es rs
  | _, _, _ => False

theorem fold_error (fees : List Tier) (init : State) (events : List Event) (code : String) :
    events.foldl (replayStep fees init) (.error code) = .error code := by
  induction events with
  | nil => rfl
  | cons e es ih => exact ih

theorem fold_chain (fees : List Tier) (init : State) :
    ∀ (events : List Event) (acc rs : List Receipt),
      events.foldl (replayStep fees init) (.ok acc) = .ok rs →
      ∃ tail, rs = acc ++ tail ∧
        Chain fees ((acc.getLast?).map Receipt.state |>.getD init) events tail
  | [], acc, rs, h => by
    simp only [List.foldl_nil, Except.ok.injEq] at h
    subst h
    exact ⟨[], by simp, by simp [Chain]⟩
  | e :: es, acc, rs, h => by
    simp only [List.foldl_cons, replayStep] at h
    split at h
    · rename_i code hcode
      rw [fold_error] at h
      cases h
    · rename_i r hr
      obtain ⟨tail, hrs, hchain⟩ := fold_chain fees init es (acc ++ [r]) rs h
      refine ⟨r :: tail, by simpa using hrs, ?_⟩
      simp only [List.getLast?_append, List.getLast?_singleton, Option.some_or] at hchain
      exact ⟨hr, hchain⟩

theorem replay_chain {cash : Rat} {coins : Nat} {fees : List Tier} {events : List Event}
    {rs : List Receipt} (h : replay cash coins fees events = .ok rs) :
    scheduleOk fees = true ∧ Chain fees (initial cash coins) events rs := by
  unfold replay at h
  split at h
  · rename_i hs
    obtain ⟨tail, hrs, hchain⟩ := fold_chain fees (initial cash coins) events [] rs h
    subst hrs
    exact ⟨hs, by simpa using hchain⟩
  · cases h

def Bal (s t : State) (n : Rat) : Prop :=
  t.cash - t.absorbed + t.fees + t.funding + n = s.cash - s.absorbed + s.fees + s.funding ∧
  t.cash - t.realized + totalCost t.positions + t.fees + t.funding - t.absorbed =
    s.cash - s.realized + totalCost s.positions + s.fees + s.funding - s.absorbed

theorem foldl_flow_acc : ∀ (l : List Event) (a : Rat),
    l.foldl (fun total event => total + flow event) a =
      a + l.foldl (fun total event => total + flow event) 0
  | [], a => by simp only [List.foldl_nil]; grind
  | e :: es, a => by
    simp only [List.foldl_cons]
    rw [foldl_flow_acc es (a + flow e), foldl_flow_acc es (0 + flow e)]
    grind

theorem chain_prefix (fees : List Tier) :
    ∀ (events : List Event) (s : State) (rs : List Receipt), Chain fees s events rs →
      rs.length = events.length ∧
      ∀ k, k ≤ events.length →
        Bal s (((rs.take k).getLast?).map Receipt.state |>.getD s)
          ((events.take k).foldl (fun total event => total + flow event) 0)
  | [], s, [], _ => by
    refine ⟨rfl, fun k hk => ?_⟩
    have : k = 0 := by simpa using hk
    subst this
    simp only [List.take_zero, List.getLast?_nil, Option.map_none, Option.getD_none,
      List.foldl_nil, Bal]
    grind
  | [], _, _ :: _, h => by simp [Chain] at h
  | _ :: _, _, [], h => by simp [Chain] at h
  | e :: es, s, r :: rs, h => by
    obtain ⟨hstep, hchain⟩ := h
    obtain ⟨hlen, hk⟩ := chain_prefix fees es r.state rs hchain
    refine ⟨by simp [hlen], fun k hkle => ?_⟩
    have hb := step_balances fees s e r hstep
    cases k with
    | zero =>
      simp only [List.take_zero, List.getLast?_nil, Option.map_none, Option.getD_none,
        List.foldl_nil, Bal]
      grind
    | succ k =>
      have hle : k ≤ es.length := by simpa using hkle
      obtain ⟨b1, b2⟩ := hk k hle
      simp only [List.take_succ_cons, List.getLast?_cons, List.foldl_cons]
      rw [foldl_flow_acc]
      refine ⟨?_, ?_⟩
      · obtain ⟨c1, c2⟩ := hb
        grind
      · obtain ⟨c1, c2⟩ := hb
        grind

theorem position_set (st : State) (ps : List Position) (coin : Nat) (p : Position)
    (h : coin < ps.length) (hst : st.positions = ps.set coin p) : position st coin = p := by
  simp [position, hst, h]

theorem position_set_ne (st : State) (ps : List Position) (coin other : Nat) (p : Position)
    (hne : other ≠ coin) (hst : st.positions = ps.set coin p) :
    position st other = position { st with positions := ps } other := by
  simp [position, hst, hne.symm]

theorem supplied_iff (late : Int) (o : Nat × Int) (events : List Event) :
    (events.any fun
      | .funding time hour coin _ _ =>
        decide (coin = o.1 ∧ hour = o.2 ∧ hour ≤ time ∧ time ≤ hour + late)
      | _ => false) = true ↔
    ∃ event ∈ events, match event with
      | .funding time hour coin _ _ =>
          coin = o.1 ∧ hour = o.2 ∧ hour ≤ time ∧ time ≤ hour + late
      | _ => False := by
  rw [List.any_eq_true]
  constructor
  · rintro ⟨e, he, h⟩
    refine ⟨e, he, ?_⟩
    cases e with
    | fill => simp at h
    | funding => simpa using h
    | absorb => simp at h
  · rintro ⟨e, he, h⟩
    refine ⟨e, he, ?_⟩
    cases e with
    | fill => simp at h
    | funding => simpa using h
    | absorb => simp at h

theorem checkFunding_error_iff (start finish late : Int) (held : List (Nat × Int))
    (events : List Event) :
    checkFunding start finish late held events = .error "R_SETTLEMENT_MISSING" ↔
    ∃ obligation ∈ held, obligation.2 % 3600000 = 0 ∧ start ≤ obligation.2 ∧
      obligation.2 + late < finish ∧
      ¬ ∃ event ∈ events, match event with
        | .funding time hour coin _ _ =>
            coin = obligation.1 ∧ hour = obligation.2 ∧ hour ≤ time ∧ time ≤ hour + late
        | _ => False := by
  unfold checkFunding
  dsimp only
  split
  · rename_i h
    simp only [true_iff]
    rw [List.any_eq_true] at h
    obtain ⟨o, ho, h⟩ := h
    simp only [Bool.and_eq_true, decide_eq_true_eq, Bool.not_eq_true'] at h
    refine ⟨o, ho, h.1.1, h.1.2.1, h.1.2.2, ?_⟩
    rw [← supplied_iff late o events]
    simpa using h.2
  · rename_i h
    simp only [Bool.not_eq_true, List.any_eq_false] at h
    simp only [reduceCtorEq, false_iff]
    rintro ⟨o, ho, h1, h2, h3, h4⟩
    have := h o ho
    simp only [Bool.and_eq_false_iff] at this
    rw [← supplied_iff late o events] at h4
    simp_all

theorem checkFunding_ok_iff (start finish late : Int) (held : List (Nat × Int))
    (events : List Event) :
    checkFunding start finish late held events = .ok () ↔
    ¬ ∃ obligation ∈ held, obligation.2 % 3600000 = 0 ∧ start ≤ obligation.2 ∧
      obligation.2 + late < finish ∧
      ¬ ∃ event ∈ events, match event with
        | .funding time hour coin _ _ =>
            coin = obligation.1 ∧ hour = obligation.2 ∧ hour ≤ time ∧ time ≤ hour + late
        | _ => False := by
  rw [← checkFunding_error_iff]
  unfold checkFunding
  dsimp only
  split <;> simp
