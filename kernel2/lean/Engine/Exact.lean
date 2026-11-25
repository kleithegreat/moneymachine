namespace Engine.Exact

/-- The integer part of the logarithm of `n` to base `b`, for `2 ≤ b`. -/
def natLog (b n : Nat) : Nat :=
  if h : b ≤ 1 ∨ n < b then 0 else natLog b (n / b) + 1
termination_by n
decreasing_by exact Nat.div_lt_self (by omega) (by omega)

theorem natLog_spec (b n : Nat) (hb : 2 ≤ b) (hn : 0 < n) :
    b ^ natLog b n ≤ n ∧ n < b ^ (natLog b n + 1) := by
  induction n using Nat.strongRecOn with
  | _ n ih =>
    rw [natLog]
    by_cases h : b ≤ 1 ∨ n < b
    · rw [dite_eq_left h]
      have : n < b := by omega
      simp only [Nat.pow_zero, Nat.zero_add, Nat.pow_one]
      omega
    · rw [dite_eq_right h]
      have hlt : n / b < n := Nat.div_lt_self hn (by omega)
      have hpos : 0 < n / b := Nat.div_pos (by omega) (by omega)
      obtain ⟨h1, h2⟩ := ih (n / b) hlt hpos
      have e1 : b ^ (natLog b (n / b) + 1) = b ^ natLog b (n / b) * b := Nat.pow_succ ..
      constructor
      · rw [e1]
        calc b ^ natLog b (n / b) * b ≤ (n / b) * b := Nat.mul_le_mul_right _ h1
          _ ≤ n := Nat.div_mul_le_self n b
      · have e2 : b ^ (natLog b (n / b) + 1 + 1) = b ^ (natLog b (n / b) + 1) * b := Nat.pow_succ ..
        rw [e2]
        have : n / b + 1 ≤ b ^ (natLog b (n / b) + 1) := h2
        calc n < (n / b + 1) * b := by
              have := Nat.lt_div_mul_add (a := n) (b := b) (by omega)
              rw [Nat.add_mul]; omega
          _ ≤ _ := Nat.mul_le_mul_right _ this

theorem natCast_pow (b n : Nat) : ((b ^ n : Nat) : Rat) = (b : Rat) ^ n := by
  induction n with
  | zero => rfl
  | succ n ih => rw [Nat.pow_succ, Rat.natCast_mul, ih, Rat.pow_succ]

theorem zpow_natCast' (b : Rat) (n : Nat) : b ^ (n : Int) = b ^ n := rfl

theorem pos_of_natCast_pos {n : Nat} (h : 0 < n) : (0 : Rat) < (n : Rat) := by exact_mod_cast h

theorem zpow_pos' {b : Rat} (hb : 0 < b) (z : Int) : 0 < b ^ z := by
  rcases z with n | n
  · simp [Rat.zpow_natCast, Rat.pow_pos hb]
  · simp only [Int.negSucc_eq, Rat.zpow_neg, Rat.inv_pos, ← Int.natCast_add_one,
      Rat.zpow_natCast, Rat.pow_pos hb]

theorem inv_mul_pos_iff {p B : Rat} (hB : 0 < B) : B⁻¹ ≤ p ↔ 1 ≤ p * B := by
  have h : B⁻¹ * B = 1 := Rat.inv_mul_cancel _ (by grind)
  have hi : 0 < B⁻¹ := Rat.inv_pos.2 hB
  constructor
  · intro h1
    have := Rat.mul_le_mul_of_nonneg_right h1 (Rat.le_of_lt hB)
    grind
  · intro h1
    exact Rat.le_of_mul_le_mul_right (by grind) hB

theorem lt_inv_mul_iff {p B : Rat} (hB : 0 < B) : p < B⁻¹ ↔ p * B < 1 := by
  have h : B⁻¹ * B = 1 := Rat.inv_mul_cancel _ (by grind)
  have hi : 0 < B⁻¹ := Rat.inv_pos.2 hB
  constructor
  · intro h1
    have := Rat.mul_lt_mul_of_pos_right h1 hB
    grind
  · intro h1
    exact Rat.lt_of_mul_lt_mul_right (by grind) (Rat.le_of_lt hB)

/-- The exponent `e` with `b ^ e ≤ p < b ^ (e + 1)`, for positive `p`. -/
def ilog (b : Nat) (p : Rat) : Int :=
  if 1 ≤ p then (natLog b p.floor.toNat : Int)
  else -((natLog b (p⁻¹.ceil - 1).toNat : Int) + 1)

theorem ilog_spec (b : Nat) (hb : 2 ≤ b) (p : Rat) (hp : 0 < p) :
    (b : Rat) ^ ilog b p ≤ p ∧ p < (b : Rat) ^ (ilog b p + 1) := by
  have hb0 : (0 : Rat) < b := pos_of_natCast_pos (by omega)
  unfold ilog
  by_cases h1 : 1 ≤ p
  · rw [ite_eq_left h1]
    have hf : 1 ≤ p.floor := Rat.le_floor_iff.2 (by simpa using h1)
    have hn : 0 < p.floor.toNat := by omega
    obtain ⟨s1, s2⟩ := natLog_spec b _ hb hn
    have hc : ((p.floor.toNat : Nat) : Rat) = (p.floor : Rat) := by
      rw [← Rat.intCast_natCast, Int.toNat_of_nonneg (by omega)]
    have hfl := Rat.floor_le p
    have hfl2 := Rat.lt_floor_add_one p
    have c1 : (b : Rat) ^ natLog b p.floor.toNat ≤ (p.floor.toNat : Rat) := by
      rw [← natCast_pow]; exact_mod_cast s1
    have c2 : ((p.floor.toNat : Nat) : Rat) + 1 ≤ (b : Rat) ^ (natLog b p.floor.toNat + 1) := by
      rw [← natCast_pow]; exact_mod_cast s2
    have e1 : ((p.floor + 1 : Int) : Rat) = (p.floor : Rat) + 1 := by simp
    rw [zpow_natCast', ← Int.natCast_add_one, zpow_natCast']
    constructor <;> grind
  · rw [ite_eq_right h1]
    have hp1 : p < 1 := Rat.not_le.1 h1
    have hx : 1 < p⁻¹ := by
      have hpi : 0 < p⁻¹ := Rat.inv_pos.2 hp
      have h : p * p⁻¹ = 1 := Rat.mul_inv_cancel _ (by grind)
      have := Rat.mul_lt_mul_of_pos_right hp1 hpi
      grind
    have hce : 1 < p⁻¹.ceil := Rat.lt_ceil_iff.2 (by simpa using hx)
    have hn : 0 < (p⁻¹.ceil - 1).toNat := by omega
    obtain ⟨s1, s2⟩ := natLog_spec b _ hb hn
    have hc : (((p⁻¹.ceil - 1).toNat : Nat) : Rat) = ((p⁻¹.ceil - 1 : Int) : Rat) := by
      rw [← Rat.intCast_natCast, Int.toNat_of_nonneg (by omega)]
    have hcl := Rat.le_ceil (x := p⁻¹)
    have hcl2 := Rat.ceil_lt (x := p⁻¹)
    have e1 : ((p⁻¹.ceil - 1 : Int) : Rat) = (p⁻¹.ceil : Rat) - 1 := by simp [Rat.intCast_sub]
    have c1 : (b : Rat) ^ natLog b (p⁻¹.ceil - 1).toNat ≤ (((p⁻¹.ceil - 1).toNat : Nat) : Rat) := by
      rw [← natCast_pow]; exact_mod_cast s1
    have c2 : (((p⁻¹.ceil - 1).toNat : Nat) : Rat) + 1 ≤ (b : Rat) ^ (natLog b (p⁻¹.ceil - 1).toNat + 1) := by
      rw [← natCast_pow]; exact_mod_cast s2
    have hpi : 0 < p⁻¹ := Rat.inv_pos.2 hp
    have hpp : p * p⁻¹ = 1 := Rat.mul_inv_cancel _ (by grind)
    have hL : 0 < (b : Rat) ^ natLog b (p⁻¹.ceil - 1).toNat := Rat.pow_pos hb0
    have hL1 : 0 < (b : Rat) ^ (natLog b (p⁻¹.ceil - 1).toNat + 1) := Rat.pow_pos hb0
    have eL : -(((natLog b (p⁻¹.ceil - 1).toNat : Nat) : Int) + 1) + 1
        = -((natLog b (p⁻¹.ceil - 1).toNat : Nat) : Int) := by omega
    rw [eL, ← Int.natCast_add_one, Rat.zpow_neg, Rat.zpow_neg, zpow_natCast', zpow_natCast']
    constructor
    · rw [inv_mul_pos_iff hL1]
      have := Rat.mul_le_mul_of_nonneg_left (a := p⁻¹) (b := (b : Rat) ^ (natLog b (p⁻¹.ceil - 1).toNat + 1)) (c := p) (by grind) (Rat.le_of_lt hp)
      grind
    · rw [lt_inv_mul_iff hL]
      have := Rat.mul_lt_mul_of_pos_left (a := (b : Rat) ^ natLog b (p⁻¹.ceil - 1).toNat) (b := p⁻¹) (c := p) (by grind) hp
      grind

/-! ### Uniform rounding -/

/-- Down to a multiple of `step`: a buy's price. -/
def roundDown (p step : Rat) : Rat := ((p / step).floor : Rat) * step

/-- Up to a multiple of `step`: a sell's price. -/
def roundUp (p step : Rat) : Rat := ((p / step).ceil : Rat) * step

/-- Toward zero: a size. -/
def roundSize (p step : Rat) : Rat := if 0 ≤ p then roundDown p step else roundUp p step

theorem div_mul_self' (p s : Rat) (hs : 0 < s) : p / s * s = p :=
  Rat.div_mul_cancel (by grind)

theorem floor_mul_bounds (p s : Rat) (hs : 0 < s) :
    ((p / s).floor : Rat) * s ≤ p ∧ p < (((p / s).floor : Rat) + 1) * s := by
  have h := div_mul_self' p s hs
  have h1 := Rat.floor_le (p / s)
  have h2 := Rat.lt_floor_add_one (p / s)
  have e : (((p / s).floor + 1 : Int) : Rat) = ((p / s).floor : Rat) + 1 := by simp
  have a := Rat.mul_le_mul_of_nonneg_right h1 (Rat.le_of_lt hs)
  have b := Rat.mul_lt_mul_of_pos_right h2 hs
  rw [e] at b
  grind

theorem ceil_mul_bounds (p s : Rat) (hs : 0 < s) :
    p ≤ ((p / s).ceil : Rat) * s ∧ ((p / s).ceil : Rat) * s < p + s := by
  have h := div_mul_self' p s hs
  have h1 := Rat.le_ceil (x := p / s)
  have h2 := Rat.ceil_lt (x := p / s)
  have a := Rat.mul_le_mul_of_nonneg_right h1 (Rat.le_of_lt hs)
  have b := Rat.mul_lt_mul_of_pos_right h2 hs
  grind

theorem div_nonneg' {p s : Rat} (hs : 0 < s) (hp : 0 ≤ p) : 0 ≤ p / s := by
  rw [Rat.div_def]
  exact Rat.mul_nonneg hp (Rat.le_of_lt (Rat.inv_pos.2 hs))

theorem div_nonpos' {p s : Rat} (hs : 0 < s) (hp : p ≤ 0) : p / s ≤ 0 := by
  have := div_nonneg' hs (show 0 ≤ -p by grind)
  rw [Rat.div_def] at this ⊢
  have e : -p * s⁻¹ = -(p * s⁻¹) := by rw [Rat.neg_mul]
  rw [e] at this
  grind

theorem rounding_parts (p step : Rat) (hstep : 0 < step) :
    (∃ k : Int, roundDown p step = (k : Rat) * step) ∧
    roundDown p step ≤ p ∧ p - roundDown p step < step ∧
    (∃ k : Int, roundUp p step = (k : Rat) * step) ∧
    p ≤ roundUp p step ∧ roundUp p step - p < step ∧
    (∃ k : Int, roundSize p step = (k : Rat) * step) ∧
    (0 ≤ p → 0 ≤ roundSize p step ∧ roundSize p step ≤ p ∧
      p - roundSize p step < step) ∧
    (p ≤ 0 → p ≤ roundSize p step ∧ roundSize p step ≤ 0 ∧
      roundSize p step - p < step) := by
  obtain ⟨d1, d2⟩ := floor_mul_bounds p step hstep
  obtain ⟨u1, u2⟩ := ceil_mul_bounds p step hstep
  have dn : ∃ k : Int, roundDown p step = (k : Rat) * step := ⟨_, rfl⟩
  have up : ∃ k : Int, roundUp p step = (k : Rat) * step := ⟨_, rfl⟩
  have hfl : 0 ≤ p → 0 ≤ roundDown p step := fun hp => by
    have h0 : 0 ≤ (p / step).floor := Rat.le_floor_iff.2 (by simpa using div_nonneg' hstep hp)
    have h1 : (0 : Rat) ≤ ((p / step).floor : Rat) := by exact_mod_cast h0
    exact Rat.mul_nonneg h1 (Rat.le_of_lt hstep)
  have hce : p ≤ 0 → roundUp p step ≤ 0 := fun hp => by
    have h0 : (p / step).ceil ≤ 0 := Rat.ceil_le_iff.2 (by simpa using div_nonpos' hstep hp)
    have h1 : ((p / step).ceil : Rat) ≤ 0 := by exact_mod_cast h0
    have := Rat.mul_le_mul_of_nonneg_right h1 (Rat.le_of_lt hstep)
    unfold roundUp
    grind
  unfold roundDown at *
  unfold roundUp at *
  refine ⟨dn, d1, by grind, up, u1, by grind, ?_, ?_, ?_⟩
  · unfold roundSize roundDown roundUp
    split
    · exact dn
    · exact up
  · intro hp
    unfold roundSize
    rw [ite_eq_left hp]
    unfold roundDown
    exact ⟨hfl hp, d1, by grind⟩
  · intro hp
    unfold roundSize
    by_cases h0 : 0 ≤ p
    · have hp0 : p = 0 := Rat.le_antisymm hp h0
      subst hp0
      have h00 : (0 : Rat) / step = 0 := by simp [Rat.div_def]
      rw [ite_eq_left (Rat.le_refl)]
      unfold roundDown
      rw [h00]
      have : (((0 : Rat).floor : Int) : Rat) = 0 := by rfl
      simp only [this]
      grind
    · rw [ite_eq_right h0]
      unfold roundUp
      exact ⟨u1, hce hp, by grind⟩

/-! ### Powers of ten -/

/-- `10 ^ z`, for an integer `z`. -/
def ten (z : Int) : Rat := (10 : Rat) ^ z

theorem ten_pos (z : Int) : 0 < ten z := zpow_pos' (by decide) z

theorem ten_succ (z : Int) : ten (z + 1) = ten z * 10 :=
  Rat.zpow_add_one (by decide) z

theorem ten_add (x y : Int) : ten (x + y) = ten x * ten y :=
  Rat.zpow_add (by decide) x y

theorem ten_zero : ten 0 = 1 := Rat.zpow_zero _

theorem one_lt_zpow {b : Rat} (hb : 1 < b) (n : Nat) : 1 < b ^ (n + 1) := by
  induction n with
  | zero => simpa using hb
  | succ n ih =>
    rw [Rat.pow_succ]
    have := Rat.mul_lt_mul_of_pos_right ih (show 0 < b by grind)
    grind

theorem zpow_lt_zpow {b : Rat} (hb : 1 < b) {x y : Int} (h : x < y) : b ^ x < b ^ y := by
  have hb0 : b ≠ 0 := by grind
  have e : y = x + (((y - x).toNat : Nat) : Int) := by omega
  have hn : (y - x).toNat = ((y - x).toNat - 1) + 1 := by omega
  have h1 := one_lt_zpow hb ((y - x).toNat - 1)
  rw [← hn] at h1
  rw [e, Rat.zpow_add hb0, zpow_natCast']
  have := Rat.mul_lt_mul_of_pos_left h1 (zpow_pos' (show 0 < b by grind) x)
  grind

theorem ten_lt {x y : Int} (h : x < y) : ten x < ten y := zpow_lt_zpow (by decide) h

theorem ten_le {x y : Int} (h : x ≤ y) : ten x ≤ ten y := by
  rcases Int.lt_or_eq_of_le h with h | h
  · exact Rat.le_of_lt (ten_lt h)
  · rw [h]; exact Rat.le_refl

theorem ten_inj {x y : Int} (h : ten x = ten y) : x = y := by
  rcases Int.lt_trichotomy x y with h1 | h1 | h1
  · have := ten_lt h1; grind
  · exact h1
  · have := ten_lt h1; grind

theorem ten_decade_unique {p : Rat} {e e' : Int}
    (h1 : ten e ≤ p) (h2 : p < ten (e + 1)) (h3 : ten e' ≤ p) (h4 : p < ten (e' + 1)) : e = e' := by
  rcases Int.lt_trichotomy e e' with h | h | h
  · have := ten_le (show e + 1 ≤ e' by omega); grind
  · exact h
  · have := ten_le (show e' + 1 ≤ e by omega); grind

theorem ilog10_spec {p : Rat} (hp : 0 < p) : ten (ilog 10 p) ≤ p ∧ p < ten (ilog 10 p + 1) := by
  have := ilog_spec 10 (by omega) p hp
  exact this

theorem ilog10_eq {p : Rat} {e : Int} (h1 : ten e ≤ p) (h2 : p < ten (e + 1)) : ilog 10 p = e := by
  have hp : 0 < p := by have := ten_pos e; grind
  obtain ⟨a, b⟩ := ilog10_spec hp
  exact ten_decade_unique a b h1 h2

/-- `p` is a multiple of `10 ^ z`: the one meaning of "multiple" the grid uses. -/
def Mult (p : Rat) (z : Int) : Prop := ∃ k : Int, p = (k : Rat) * ten z

theorem Mult.nested {p : Rat} {x y : Int} (h : x ≤ y) : Mult p y → Mult p x := by
  rintro ⟨k, hk⟩
  have e : y = x + (((y - x).toNat : Nat) : Int) := by omega
  refine ⟨k * (10 ^ (y - x).toNat : Nat), ?_⟩
  rw [e, ten_add] at hk
  unfold ten at hk
  rw [zpow_natCast'] at hk
  have : (((k * (10 ^ (y - x).toNat : Nat) : Int)) : Rat) = (k : Rat) * (10 : Rat) ^ (y - x).toNat := by
    rw [Rat.intCast_mul, Rat.intCast_natCast, natCast_pow]; rfl
  rw [this, hk]
  unfold ten
  rw [Rat.mul_assoc, Rat.mul_comm ((10 : Rat) ^ x)]

theorem Mult.pos_ge {q : Rat} {z : Int} (hq : 0 < q) : Mult q z → ten z ≤ q := by
  rintro ⟨k, hk⟩
  have ht := ten_pos z
  have hk1 : 1 ≤ k := by
    by_cases h : 1 ≤ k
    · exact h
    · have : k ≤ 0 := by omega
      have h0 : (k : Rat) ≤ 0 := by exact_mod_cast this
      have := Rat.mul_le_mul_of_nonneg_right h0 (Rat.le_of_lt ht)
      grind
  have : (1 : Rat) ≤ (k : Rat) := by exact_mod_cast hk1
  have := Rat.mul_le_mul_of_nonneg_right this (Rat.le_of_lt ht)
  grind

/-! ### The price grid (KERNEL.md A18) -/

/-- The exponent of the grid step at a positive price (A18); the fixed quantum at any other. -/
def stepExp (figures : Nat) (decimals : Int) (p : Rat) : Int :=
  if 0 < p then max (min (ilog 10 p - figures + 1) 0) (-decimals) else -decimals

def gridStep (figures : Nat) (decimals : Int) (p : Rat) : Rat :=
  ten (stepExp figures decimals p)

def isMultiple (p s : Rat) : Bool := decide (((p / s).floor : Rat) * s = p)

theorem isMultiple_iff {p s : Rat} (hs : 0 < s) :
    isMultiple p s = true ↔ ∃ k : Int, p = (k : Rat) * s := by
  unfold isMultiple
  rw [decide_eq_true_iff]
  constructor
  · intro h; exact ⟨_, h.symm⟩
  · rintro ⟨k, rfl⟩
    have : (k : Rat) * s / s = k := Rat.mul_div_cancel (by grind)
    rw [this, Rat.floor_intCast]

/-- A18's sentence: above zero, a whole multiple of `10^-decimals`, and either at most `figures`
significant figures (a multiple of the decade's quantum) or a whole number. -/
def onGrid (figures : Nat) (decimals : Int) (p : Rat) : Bool :=
  decide (0 < p) && isMultiple p (ten (-decimals)) &&
    (isMultiple p (ten (ilog 10 p - figures + 1)) || isMultiple p 1)

theorem mult_iff {p : Rat} {z : Int} : isMultiple p (ten z) = true ↔ Mult p z :=
  isMultiple_iff (ten_pos z)

theorem mult_one_iff {p : Rat} : isMultiple p 1 = true ↔ ∃ k : Int, p = (k : Rat) :=
  by
    rw [isMultiple_iff (by decide)]
    simp

theorem onGrid_iff {figures : Nat} {decimals : Int} {p : Rat} :
    onGrid figures decimals p = true ↔
      0 < p ∧ Mult p (-decimals) ∧
        (Mult p (ilog 10 p - figures + 1) ∨ ∃ k : Int, p = (k : Rat)) := by
  unfold onGrid
  simp only [Bool.and_eq_true, Bool.or_eq_true, decide_eq_true_eq, mult_iff, mult_one_iff, and_assoc]

/-- `10 ^ e` divides `m`; every `m` does when `e` is not above zero. -/
def dividesTen (m : Nat) (e : Int) : Bool := decide (e ≤ 0) || m % 10 ^ e.toNat == 0

theorem dividesTen_iff (m : Nat) (e : Int) :
    dividesTen m e = true ↔ e ≤ 0 ∨ 10 ^ e.toNat ∣ m := by
  unfold dividesTen
  simp only [Bool.or_eq_true, decide_eq_true_eq, beq_iff_eq]
  constructor
  · rintro (h | h)
    · exact Or.inl h
    · exact Or.inr (Nat.dvd_of_mod_eq_zero h)
  · rintro (h | h)
    · exact Or.inl h
    · exact Or.inr (Nat.mod_eq_zero_of_dvd h)

theorem ten_natCast (s : Nat) : ten (s : Int) = (10 : Rat) ^ s := rfl

theorem mult_scaled (n : Int) (s : Nat) (z : Int) :
    Mult ((n : Rat) / (10 : Rat) ^ s) z ↔ (z + s ≤ 0 ∨ 10 ^ (z + s).toNat ∣ n.natAbs) := by
  have hs : (10 : Rat) ^ s ≠ 0 := by
    have : 0 < (10 : Rat) ^ s := Rat.pow_pos (by decide)
    grind
  have hten : ten (z + s) = ten z * (10 : Rat) ^ s := by rw [ten_add, ten_natCast]
  have key : ∀ k : Int, (n : Rat) / (10 : Rat) ^ s = (k : Rat) * ten z ↔ (n : Rat) = (k : Rat) * ten (z + s) := by
    intro k
    rw [hten, ← Rat.mul_assoc]
    constructor
    · intro h; rw [← h, Rat.div_mul_cancel hs]
    · intro h; rw [h, Rat.mul_div_cancel hs]
  unfold Mult
  simp only [key]
  by_cases he : z + s ≤ 0
  · simp only [he, true_or, iff_true]
    obtain ⟨t, ht⟩ : ∃ t : Nat, -(z + s) = t := ⟨(-(z + s)).toNat, by omega⟩
    refine ⟨n * ((10 ^ t : Nat) : Int), ?_⟩
    have e1 : ten (z + s) * ten (-(z + s)) = 1 := by
      rw [← ten_add, show z + s + -(z + s) = 0 by omega, ten_zero]
    have e2 : ten (-(z + s)) = (((10 ^ t : Nat) : Int) : Rat) := by
      rw [ht, ten_natCast, Rat.intCast_natCast, natCast_pow]
      simp
    rw [Rat.intCast_mul, ← e2, Rat.mul_assoc, Rat.mul_comm (ten (-(z + s))), e1]
    simp
  · simp only [he, false_or]
    obtain ⟨t, ht⟩ : ∃ t : Nat, z + s = t := ⟨(z + s).toNat, by omega⟩
    have hto : (z + s).toNat = t := by omega
    rw [hto, ht, ten_natCast]
    constructor
    · rintro ⟨k, hk⟩
      have : n = k * ((10 ^ t : Nat) : Int) := by
        have : (n : Rat) = ((k * ((10 ^ t : Nat) : Int) : Int) : Rat) := by
          rw [hk, Rat.intCast_mul, Rat.intCast_natCast, natCast_pow]; simp
        exact_mod_cast this
      rw [this, Int.natAbs_mul]
      exact ⟨(k.natAbs), by simp [Nat.mul_comm]⟩
    · rintro ⟨q, hq⟩
      refine ⟨if n < 0 then -(q : Int) else q, ?_⟩
      have hn : n = (if n < 0 then -(n.natAbs : Int) else (n.natAbs : Int)) := by omega
      have hq' : (n.natAbs : Int) = (10 ^ t : Nat) * q := by exact_mod_cast hq
      by_cases hneg : n < 0
      · simp only [hneg, ite_true]
        have : n = -((10 ^ t : Nat) * q : Int) := by omega
        rw [this]; push_cast; grind
      · simp only [hneg, ite_false]
        have : n = ((10 ^ t : Nat) * q : Int) := by omega
        rw [this]; push_cast; grind


/-- A18's grid on a price held as whole units of `10 ^ -scale`: the same sentence as `onGrid` of that
rational, in natural numbers and integers alone (X3). -/
def onGridAt (figures : Nat) (decimals : Int) (scale : Nat) (n : Int) : Bool :=
  decide (0 < n) && dividesTen n.natAbs ((scale : Int) - decimals) &&
    (dividesTen n.natAbs ((natLog 10 n.natAbs : Int) - figures + 1) || dividesTen n.natAbs scale)

theorem ilog_scaled (n : Int) (s : Nat) (hn : 0 < n) :
    ilog 10 ((n : Rat) / (10 : Rat) ^ s) = (natLog 10 n.natAbs : Int) - s := by
  have hs : (0 : Rat) < (10 : Rat) ^ s := Rat.pow_pos (by decide)
  obtain ⟨h1, h2⟩ := natLog_spec 10 n.natAbs (by omega) (by omega)
  have hna : ((n.natAbs : Nat) : Int) = n := by omega
  have c1 : ((10 ^ natLog 10 n.natAbs : Nat) : Rat) ≤ (n : Rat) := by
    have : ((10 ^ natLog 10 n.natAbs : Nat) : Int) ≤ n := by omega
    exact_mod_cast this
  have c2 : (n : Rat) < ((10 ^ (natLog 10 n.natAbs + 1) : Nat) : Rat) := by
    have : n < ((10 ^ (natLog 10 n.natAbs + 1) : Nat) : Int) := by omega
    exact_mod_cast this
  rw [natCast_pow] at c1 c2
  have t1 : ten ((natLog 10 n.natAbs : Int) - s) * (10 : Rat) ^ s = (10 : Rat) ^ natLog 10 n.natAbs := by
    rw [← ten_natCast, ← ten_add, show (natLog 10 n.natAbs : Int) - s + s = natLog 10 n.natAbs by omega, ten_natCast]
  have t2 : ten ((natLog 10 n.natAbs : Int) - s + 1) * (10 : Rat) ^ s = (10 : Rat) ^ (natLog 10 n.natAbs + 1) := by
    rw [← ten_natCast, ← ten_add, show (natLog 10 n.natAbs : Int) - s + 1 + s = ((natLog 10 n.natAbs + 1 : Nat) : Int) by omega, ten_natCast]
  apply ilog10_eq
  · rw [← Rat.not_lt, Rat.div_lt_iff hs, t1]; intro h; have c1' : (10 : Rat) ^ natLog 10 n.natAbs ≤ n := by simpa using c1
    exact (Rat.not_le.mpr h) c1'
  · rw [Rat.div_lt_iff hs, Rat.mul_comm, ← Rat.mul_comm, t2]; simpa using c2

theorem onGridAt_eq (figures : Nat) (decimals : Int) (scale : Nat) (n : Int) :
    onGridAt figures decimals scale n =
      onGrid figures decimals ((n : Rat) / (10 : Rat) ^ scale) := by
  have hs : (0 : Rat) < (10 : Rat) ^ scale := Rat.pow_pos (by decide)
  rw [Bool.eq_iff_iff, onGrid_iff]
  unfold onGridAt
  simp only [Bool.and_eq_true, Bool.or_eq_true, decide_eq_true_eq, dividesTen_iff, and_assoc]
  have hpos : 0 < (n : Rat) / (10 : Rat) ^ scale ↔ 0 < n := by
    rw [Rat.lt_div_iff hs, Rat.zero_mul]
    constructor
    · intro h; exact_mod_cast h
    · intro h; exact_mod_cast h
  rw [hpos]
  by_cases hn : 0 < n
  · simp only [hn, true_and]
    rw [ilog_scaled n scale hn, mult_scaled, mult_scaled]
    have hk : (∃ k : Int, (n : Rat) / (10 : Rat) ^ scale = (k : Rat)) ↔ Mult ((n : Rat) / (10 : Rat) ^ scale) 0 := by
      unfold Mult; simp [ten_zero]
    rw [hk, mult_scaled]
    have e1 : -decimals + (scale : Int) = (scale : Int) - decimals := by omega
    have e2 : (natLog 10 n.natAbs : Int) - scale - figures + 1 + scale = (natLog 10 n.natAbs : Int) - figures + 1 := by omega
    rw [e1, e2, Int.zero_add]
  · simp [hn]

theorem gridStep_pos (figures : Nat) (decimals : Int) (p : Rat) : 0 < gridStep figures decimals p :=
  ten_pos _

theorem stepExp_eq {figures : Nat} {decimals : Int} {p : Rat} {e : Int}
    (h1 : ten e ≤ p) (h2 : p < ten (e + 1)) :
    stepExp figures decimals p = max (min (e - figures + 1) 0) (-decimals) := by
  have hp : 0 < p := by have := ten_pos e; grind
  unfold stepExp
  rw [ite_eq_left hp, ilog10_eq h1 h2]

theorem mult_combine (p : Rat) (a c : Int) :
    (Mult p a ∧ (Mult p c ∨ Mult p 0)) ↔ Mult p (max (min c 0) a) := by
  have hn : ∀ x y : Int, x ≤ y → Mult p y → Mult p x := fun x y h => Mult.nested h
  by_cases hc : c ≤ 0
  · by_cases ha : a ≤ c
    · rw [show max (min c 0) a = c by omega]
      constructor
      · rintro ⟨_, h | h⟩
        · exact h
        · exact hn c 0 hc h
      · intro h
        exact ⟨hn a c ha h, Or.inl h⟩
    · rw [show max (min c 0) a = a by omega]
      constructor
      · exact fun h => h.1
      · intro h
        exact ⟨h, Or.inl (hn c a (by omega) h)⟩
  · by_cases ha : a ≤ 0
    · rw [show max (min c 0) a = 0 by omega]
      constructor
      · rintro ⟨_, h | h⟩
        · exact hn 0 c (by omega) h
        · exact h
      · intro h
        exact ⟨hn a 0 ha h, Or.inr h⟩
    · rw [show max (min c 0) a = a by omega]
      constructor
      · exact fun h => h.1
      · intro h
        exact ⟨h, Or.inr (hn 0 a (by omega) h)⟩

/-- A18: on the grid exactly when a whole multiple of its step. -/
theorem onGrid_iff_step {figures : Nat} {decimals : Int} {p : Rat} (hp : 0 < p) :
    onGrid figures decimals p = true ↔ ∃ k : Int, p = (k : Rat) * gridStep figures decimals p := by
  obtain ⟨h1, h2⟩ := ilog10_spec hp
  rw [onGrid_iff]
  unfold gridStep
  rw [stepExp_eq h1 h2]
  have := mult_combine p (-decimals) (ilog 10 p - figures + 1)
  have e : (∃ k : Int, p = (k : Rat)) ↔ Mult p 0 := by
    unfold Mult
    rw [ten_zero]
    simp
  rw [e]
  constructor
  · rintro ⟨_, h⟩
    exact this.1 h
  · intro h
    exact ⟨hp, this.2 h⟩

/-- The greatest grid price at or below `p`, or zero when there is none. -/
def roundPriceBuy (figures : Nat) (decimals : Int) (p : Rat) : Rat :=
  if 0 < p then roundDown p (gridStep figures decimals p) else 0

/-- The least grid price at or above `p`. -/
def roundPriceSell (figures : Nat) (decimals : Int) (p : Rat) : Rat :=
  if 0 < p then roundUp p (gridStep figures decimals p) else gridStep figures decimals p

theorem ten_eq (z : Int) :
    (if 0 ≤ z then (10 : Rat) ^ z.toNat else 1 / (10 : Rat) ^ (-z).toNat) = ten z := by
  unfold ten
  split
  · rename_i h
    have : z = ((z.toNat : Nat) : Int) := by omega
    conv => rhs; rw [this]
    rfl
  · rename_i h
    have : z = -(((-z).toNat : Nat) : Int) := by omega
    conv => rhs; rw [this]
    rw [Rat.zpow_neg, zpow_natCast', Rat.div_def, Rat.one_mul]

theorem roundDown_nonneg {p s : Rat} (hs : 0 < s) (hp : 0 ≤ p) : 0 ≤ roundDown p s := by
  have h0 : 0 ≤ (p / s).floor := Rat.le_floor_iff.2 (by simpa using div_nonneg' hs hp)
  have h1 : (0 : Rat) ≤ ((p / s).floor : Rat) := by exact_mod_cast h0
  exact Rat.mul_nonneg h1 (Rat.le_of_lt hs)

theorem roundDown_ge_mult {p s : Rat} (hs : 0 < s) (k : Int) (h : (k : Rat) * s ≤ p) :
    (k : Rat) * s ≤ roundDown p s := by
  have h1 : (k : Rat) ≤ p / s := by
    apply Rat.le_of_mul_le_mul_right _ hs
    rw [div_mul_self' p s hs]
    exact h
  have h2 : k ≤ (p / s).floor := Rat.le_floor_iff.2 h1
  have h3 : (k : Rat) ≤ ((p / s).floor : Rat) := by exact_mod_cast h2
  exact Rat.mul_le_mul_of_nonneg_right h3 (Rat.le_of_lt hs)

theorem roundUp_le_mult {p s : Rat} (hs : 0 < s) (k : Int) (h : p ≤ (k : Rat) * s) :
    roundUp p s ≤ (k : Rat) * s := by
  have h1 : p / s ≤ (k : Rat) := by
    apply Rat.le_of_mul_le_mul_right _ hs
    rw [div_mul_self' p s hs]
    exact h
  have h2 : (p / s).ceil ≤ k := Rat.ceil_le_iff.2 h1
  have h3 : ((p / s).ceil : Rat) ≤ (k : Rat) := by exact_mod_cast h2
  exact Rat.mul_le_mul_of_nonneg_right h3 (Rat.le_of_lt hs)

theorem onGrid_ten {figures : Nat} {decimals : Int} (hf : 1 ≤ figures) {z : Int}
    (hz : -decimals ≤ z) : onGrid figures decimals (ten z) = true := by
  have hp := ten_pos z
  have h2 : ten z < ten (z + 1) := ten_lt (by omega)
  rw [onGrid_iff_step hp]
  unfold gridStep
  rw [stepExp_eq (Rat.le_refl) h2]
  show Mult (ten z) _
  exact Mult.nested (x := max (min (z - figures + 1) 0) (-decimals)) (y := z) (by omega)
    ⟨1, by simp⟩

theorem onGrid_decade {figures : Nat} {decimals : Int} {q : Rat} {e : Int}
    (h1 : ten e ≤ q) (h2 : q < ten (e + 1)) :
    onGrid figures decimals q = true ↔ Mult q (max (min (e - figures + 1) 0) (-decimals)) := by
  have hq : 0 < q := by have := ten_pos e; grind
  rw [onGrid_iff_step hq]
  unfold gridStep
  rw [stepExp_eq h1 h2]
  exact Iff.rfl

theorem price_setup {figures : Nat} {decimals : Int} {p : Rat} (hp : 0 < p) :
    ∃ e g : Int, ten e ≤ p ∧ p < ten (e + 1) ∧
      g = max (min (e - figures + 1) 0) (-decimals) ∧
      gridStep figures decimals p = ten g ∧
      ∀ q : Rat, ten e ≤ q → q < ten (e + 1) → (onGrid figures decimals q = true ↔ Mult q g) := by
  obtain ⟨h1, h2⟩ := ilog10_spec hp
  refine ⟨ilog 10 p, _, h1, h2, rfl, ?_, ?_⟩
  · unfold gridStep
    rw [stepExp_eq h1 h2]
  · intro q a b
    rw [onGrid_decade a b]

theorem buy_spec {figures : Nat} {decimals : Int} {p : Rat} (hf : 1 ≤ figures) (hp : 0 < p) :
    (roundPriceBuy figures decimals p = 0 ∨
      onGrid figures decimals (roundPriceBuy figures decimals p) = true) ∧
    0 ≤ roundPriceBuy figures decimals p ∧ roundPriceBuy figures decimals p ≤ p ∧
    p - roundPriceBuy figures decimals p < gridStep figures decimals p ∧
    ∀ q : Rat, onGrid figures decimals q = true → q ≤ p → q ≤ roundPriceBuy figures decimals p := by
  obtain ⟨e, g, h1, h2, hg, hgs, hdec⟩ := price_setup (figures := figures) (decimals := decimals) hp
  have hs : 0 < ten g := ten_pos g
  unfold roundPriceBuy
  rw [ite_eq_left hp, hgs]
  obtain ⟨d1, d2⟩ := floor_mul_bounds p (ten g) hs
  have hb0 : 0 ≤ roundDown p (ten g) := roundDown_nonneg hs (Rat.le_of_lt hp)
  have hbp : roundDown p (ten g) ≤ p := d1
  have hbs : p - roundDown p (ten g) < ten g := by unfold roundDown; grind
  by_cases hge : g ≤ e
  · have hk : Mult (ten e) g := Mult.nested hge ⟨1, by simp⟩
    obtain ⟨k, hk⟩ := hk
    have hlow : ten e ≤ roundDown p (ten g) := by
      have := roundDown_ge_mult hs k (by rw [← hk]; exact h1)
      rw [← hk] at this
      exact this
    refine ⟨Or.inr ?_, hb0, hbp, hbs, ?_⟩
    · rw [hdec _ hlow (by grind)]
      exact ⟨_, rfl⟩
    · intro q hq hqp
      have hq0 : 0 < q := (onGrid_iff.1 hq).1
      by_cases hlt : q < ten e
      · grind
      · have hq1 : ten e ≤ q := Rat.not_lt.1 hlt
        obtain ⟨k', hk'⟩ := (hdec q hq1 (by grind)).1 hq
        have := roundDown_ge_mult hs k' (by rw [← hk']; exact hqp)
        rw [← hk'] at this
        exact this
  · have hg2 : g = -decimals := by omega
    have hps : p < ten g := by
      have := ten_le (show e + 1 ≤ g by omega)
      grind
    have hb : roundDown p (ten g) = 0 := by
      unfold roundDown
      have hlt : p / ten g < 1 := by
        apply Rat.lt_of_mul_lt_mul_right _ (Rat.le_of_lt hs)
        rw [div_mul_self' p _ hs]
        grind
      have hf0 : (p / ten g).floor < 1 := Rat.floor_lt_iff.2 (by simpa using hlt)
      have hf1 : 0 ≤ (p / ten g).floor :=
        Rat.le_floor_iff.2 (by simpa using div_nonneg' hs (Rat.le_of_lt hp))
      have : (p / ten g).floor = 0 := by omega
      rw [this]
      simp
    refine ⟨Or.inl hb, hb0, hbp, hbs, ?_⟩
    intro q hq hqp
    obtain ⟨hq0, hm, _⟩ := onGrid_iff.1 hq
    have := Mult.pos_ge hq0 hm
    rw [hg2] at hps
    grind

theorem sell_spec {figures : Nat} {decimals : Int} {p : Rat} (hf : 1 ≤ figures) (hp : 0 < p) :
    onGrid figures decimals (roundPriceSell figures decimals p) = true ∧
    p ≤ roundPriceSell figures decimals p ∧
    roundPriceSell figures decimals p - p < gridStep figures decimals p ∧
    ∀ q : Rat, onGrid figures decimals q = true → p ≤ q → roundPriceSell figures decimals p ≤ q := by
  obtain ⟨e, g, h1, h2, hg, hgs, hdec⟩ := price_setup (figures := figures) (decimals := decimals) hp
  have hs : 0 < ten g := ten_pos g
  unfold roundPriceSell
  rw [ite_eq_left hp, hgs]
  obtain ⟨u1, u2⟩ := ceil_mul_bounds p (ten g) hs
  have hup : p ≤ roundUp p (ten g) := u1
  have hus : roundUp p (ten g) - p < ten g := by unfold roundUp; grind
  by_cases hge : g ≤ e + 1
  · obtain ⟨k, hk⟩ : Mult (ten (e + 1)) g := Mult.nested hge ⟨1, by simp⟩
    have hle : roundUp p (ten g) ≤ ten (e + 1) := by
      have := roundUp_le_mult hs k (by rw [← hk]; exact Rat.le_of_lt h2)
      rw [← hk] at this
      exact this
    have hdecl : -decimals ≤ e + 1 := by omega
    refine ⟨?_, hup, hus, ?_⟩
    · by_cases hlt : roundUp p (ten g) < ten (e + 1)
      · have hq1 : ten e ≤ roundUp p (ten g) := by grind
        rw [hdec _ hq1 hlt]
        exact ⟨_, rfl⟩
      · have : roundUp p (ten g) = ten (e + 1) := Rat.le_antisymm hle (Rat.not_lt.1 hlt)
        rw [this]
        exact onGrid_ten hf hdecl
    · intro q hq hpq
      by_cases hlt : q < ten (e + 1)
      · have hq1 : ten e ≤ q := by grind
        obtain ⟨k', hk'⟩ := (hdec q hq1 hlt).1 hq
        have := roundUp_le_mult hs k' (by rw [← hk']; exact hpq)
        rw [← hk'] at this
        exact this
      · grind
  · have hg2 : g = -decimals := by omega
    have hps : ten (e + 1) < ten g := ten_lt (by omega)
    have hsell : roundUp p (ten g) = ten g := by
      unfold roundUp
      have hlt : p / ten g ≤ 1 := by
        apply Rat.le_of_mul_le_mul_right _ hs
        rw [div_mul_self' p _ hs]
        grind
      have hpos : 0 < p / ten g := by
        have := div_nonneg' hs (Rat.le_of_lt hp)
        have hne : p / ten g ≠ 0 := by
          intro h0
          have := div_mul_self' p _ hs
          rw [h0] at this
          grind
        grind
      have c1 : (p / ten g).ceil ≤ 1 := Rat.ceil_le_iff.2 (by simpa using hlt)
      have c0 : 0 < (p / ten g).ceil := Rat.lt_ceil_iff.2 (by simpa using hpos)
      have : (p / ten g).ceil = 1 := by omega
      rw [this]
      simp
    refine ⟨?_, hup, hus, ?_⟩
    · rw [hsell]
      exact onGrid_ten hf (by omega)
    · intro q hq hpq
      rw [hsell]
      obtain ⟨hq0, hm, _⟩ := onGrid_iff.1 hq
      have := Mult.pos_ge hq0 hm
      rw [hg2]
      exact this

/-! ### Binary64, by integer arithmetic -/

/-- The nearest natural number to `r ≥ 0`, ties to even. -/
def roundHalfEven (r : Rat) : Nat :=
  let f := r.floor.toNat
  let rest := r - f
  if rest < 1 / 2 then f else if 1 / 2 < rest then f + 1 else if f % 2 = 0 then f else f + 1

theorem roundHalfEven_bounds {r : Rat} (hr : 0 ≤ r) :
    (roundHalfEven r : Rat) - 1 / 2 ≤ r ∧ r ≤ (roundHalfEven r : Rat) + 1 / 2 := by
  have hf0 : 0 ≤ r.floor := Rat.le_floor_iff.2 (by simpa using hr)
  have hc : (((r.floor.toNat : Nat) : Int) : Rat) = (r.floor : Rat) := by
    rw [Int.toNat_of_nonneg hf0]
  have hc' : ((r.floor.toNat : Nat) : Rat) = (r.floor : Rat) := by
    rw [← Rat.intCast_natCast]; exact hc
  have h1 := Rat.floor_le r
  have h2 := Rat.lt_floor_add_one r
  have e : ((r.floor + 1 : Int) : Rat) = (r.floor : Rat) + 1 := by simp
  unfold roundHalfEven
  simp only []
  split
  · rename_i h
    constructor <;> grind
  · split
    · rename_i h h'
      have : ((r.floor.toNat + 1 : Nat) : Rat) = (r.floor.toNat : Rat) + 1 := by simp
      rw [this]
      constructor <;> grind
    · rename_i h h'
      have hne : r - (r.floor.toNat : Rat) = 1 / 2 := by grind
      split
      · constructor <;> grind
      · have : ((r.floor.toNat + 1 : Nat) : Rat) = (r.floor.toNat : Rat) + 1 := by simp
        rw [this]
        constructor <;> grind

/-- The value of the low 63 bits of a double: subnormal below `2⁵²`, else normal. -/
def magValue (mag : Nat) : Rat :=
  if mag < 2 ^ 52 then (mag : Rat) * (2 : Rat) ^ (-1074 : Int)
  else ((mag % 2 ^ 52 + 2 ^ 52 : Nat) : Rat) * (2 : Rat) ^ (((mag / 2 ^ 52 : Nat) : Int) - 1075)

/-- The bit pattern of infinity: the first magnitude that is not finite. -/
def infBits : Nat := 0x7ff0000000000000

/-- A double's bits as the rational they stand for; a NaN or an infinity stands for none. -/
def decode (bits : UInt64) : Option Rat :=
  let v := bits.toNat
  let mag := v % 2 ^ 63
  if infBits ≤ mag then none else some (if 2 ^ 63 ≤ v then -magValue mag else magValue mag)

/-- The nearest binary64 to `q`, ties to even, as bits; a nonzero `q` that rounds to zero keeps its sign (IEEE 754),
and zero is positive zero. -/
def nearestBits (q : Rat) : UInt64 :=
  if q = 0 then 0
  else
    let a := if q < 0 then -q else q
    let e := max (ilog 2 a) (-1022)
    let m := roundHalfEven (a / (2 : Rat) ^ (e - 52))
    let mag := min ((e + 1022).toNat * 2 ^ 52 + m) infBits
    UInt64.ofNat ((if q < 0 then 2 ^ 63 else 0) + mag)

/-- The scaled integer `n` at scale `d` that a double's bits read as, if any (A2). -/
def readBits (d : Nat) (bits : UInt64) : Option Int :=
  match decode bits with
  | none => none
  | some x =>
    let n : Int := (x * (10 : Rat) ^ d + 1 / 2).floor
    if n.natAbs < 10 ^ 15 ∧ nearestBits ((n : Rat) / (10 : Rat) ^ d) =
        (if bits = (9223372036854775808 : UInt64) then 0 else bits) then some n else none

/-- A placed decimal `n · 10⁻ʷ` at scale `d` (A18); too many places, or out of range, is `E_DECIMAL`. -/
def putPlaced (d : Nat) (n : Int) (w : Nat) : Except String Int :=
  if d < w then .error "E_DECIMAL"
  else
    let scaled := n * 10 ^ (d - w)
    if scaled.natAbs < 10 ^ 15 then .ok scaled else .error "E_DECIMAL"

theorem zpow_le_zpow {b : Rat} (hb : 1 < b) {x y : Int} (h : x ≤ y) : b ^ x ≤ b ^ y := by
  rcases Int.lt_or_eq_of_le h with h | h
  · exact Rat.le_of_lt (zpow_lt_zpow hb h)
  · rw [h]; exact Rat.le_refl

theorem magValue_normal {e : Int} {m : Nat} (he : -1022 ≤ e) (hm1 : e = -1022 ∨ 2 ^ 52 ≤ m)
    (hm2 : m ≤ 2 ^ 53) :
    magValue ((e + 1022).toNat * 2 ^ 52 + m) = (m : Rat) * (2 : Rat) ^ (e - 52) := by
  unfold magValue
  by_cases hsub : (e + 1022).toNat * 2 ^ 52 + m < 2 ^ 52
  · rw [ite_eq_left hsub]
    have h0 : (e + 1022).toNat * 2 ^ 52 + m = m := by omega
    have h1 : e - 52 = -1074 := by omega
    rw [h0, h1]
  rw [ite_eq_right hsub]
  by_cases hm : m < 2 ^ 53
  · have h1 : ((e + 1022).toNat * 2 ^ 52 + m) % 2 ^ 52 + 2 ^ 52 = m := by omega
    have h2 : ((e + 1022).toNat * 2 ^ 52 + m) / 2 ^ 52 = (e + 1023).toNat := by omega
    have h3 : (((e + 1023).toNat : Nat) : Int) - 1075 = e - 52 := by omega
    rw [h1, h2, h3]
  · have hm' : m = 2 ^ 53 := by omega
    have h1 : ((e + 1022).toNat * 2 ^ 52 + m) % 2 ^ 52 + 2 ^ 52 = 2 ^ 52 := by omega
    have h2 : ((e + 1022).toNat * 2 ^ 52 + m) / 2 ^ 52 = (e + 1024).toNat := by omega
    have h3 : (((e + 1024).toNat : Nat) : Int) - 1075 = (e - 52) + 1 := by omega
    rw [h1, h2, h3, hm']
    have hz := Rat.zpow_add_one (q := (2 : Rat)) (by decide) (e - 52)
    have c53 : ((2 ^ 53 : Nat) : Rat) = 2 * ((2 ^ 52 : Nat) : Rat) := by
      rw [show 2 ^ 53 = 2 * 2 ^ 52 by omega, Rat.natCast_mul]
      rfl
    rw [c53, hz]
    grind

theorem decode_pos (mag : Nat) (hm : mag < infBits) :
    decode (UInt64.ofNat mag) = some (magValue mag) := by
  have hinf : infBits = 0x7ff0000000000000 := rfl
  have hv : (UInt64.ofNat mag).toNat = mag :=
    UInt64.toNat_ofNat_of_lt' (by unfold UInt64.size; omega)
  unfold decode
  simp only [hv]
  rw [Nat.mod_eq_of_lt (by omega), ite_eq_right (by omega), ite_eq_right (by omega)]

theorem decode_neg (mag : Nat) (hm : mag < infBits) :
    decode (UInt64.ofNat (2 ^ 63 + mag)) = some (-magValue mag) := by
  have hinf : infBits = 0x7ff0000000000000 := rfl
  have hv : (UInt64.ofNat (2 ^ 63 + mag)).toNat = 2 ^ 63 + mag :=
    UInt64.toNat_ofNat_of_lt' (by unfold UInt64.size; omega)
  unfold decode
  simp only [hv]
  have h1 : (2 ^ 63 + mag) % 2 ^ 63 = mag := by omega
  rw [h1, ite_eq_right (by omega), ite_eq_left (by omega)]

theorem nearest_spec {q : Rat} (hq : q ≠ 0)
    (hlo : (2 : Rat) ^ (-100 : Int) ≤ (if q < 0 then -q else q))
    (hhi : (if q < 0 then -q else q) < (2 : Rat) ^ (100 : Int)) :
    ∃ x, decode (nearestBits q) = some x ∧ nearestBits q ≠ 0 ∧
      (x - q) * 9007199254740992 ≤ (if q < 0 then -q else q) ∧
      (q - x) * 9007199254740992 ≤ (if q < 0 then -q else q) := by
  obtain ⟨a, ha⟩ : ∃ a, a = (if q < 0 then -q else q) := ⟨_, rfl⟩
  rw [← ha] at hlo hhi ⊢
  have h2pos : (0 : Rat) < 2 := by decide
  have h2gt : (1 : Rat) < 2 := by decide
  have hapos : 0 < a := by
    have := zpow_pos' h2pos (-100)
    grind
  obtain ⟨hs1, hs2⟩ : (2 : Rat) ^ (ilog 2 a) ≤ a ∧ a < (2 : Rat) ^ (ilog 2 a + 1) :=
    ilog_spec 2 (by omega) a hapos
  obtain ⟨e, he⟩ : ∃ e, e = ilog 2 a := ⟨_, rfl⟩
  rw [← he] at hs1 hs2
  have he1 : -100 ≤ e := by
    by_cases h : -100 ≤ e
    · exact h
    · have := zpow_le_zpow h2gt (show e + 1 ≤ -100 by omega)
      grind
  have he2 : e ≤ 99 := by
    by_cases h : e ≤ 99
    · exact h
    · have := zpow_le_zpow h2gt (show 100 ≤ e by omega)
      grind
  have hmax : max e (-1022) = e := by omega
  have hinf : infBits = 0x7ff0000000000000 := rfl
  have n52 : (2 : Rat) ^ 52 = 4503599627370496 := by decide
  have n53 : (2 : Rat) ^ 53 = 9007199254740992 := by decide
  have hstep : 0 < (2 : Rat) ^ (e - 52) := zpow_pos' h2pos _
  obtain ⟨s, hs⟩ : ∃ s, s = (2 : Rat) ^ (e - 52) := ⟨_, rfl⟩
  rw [← hs] at hstep
  have r1 : (2 : Rat) ^ e = s * 4503599627370496 := by
    have := Rat.zpow_add (q := (2 : Rat)) (by decide) (e - 52) 52
    rw [show e - 52 + 52 = e by omega] at this
    rw [this, ← hs, ← n52]
    rfl
  have r2 : (2 : Rat) ^ (e + 1) = s * 9007199254740992 := by
    have := Rat.zpow_add (q := (2 : Rat)) (by decide) (e - 52) 53
    rw [show e - 52 + 53 = e + 1 by omega] at this
    rw [this, ← hs, ← n53]
    rfl
  obtain ⟨t, ht⟩ : ∃ t, t = a / s := ⟨_, rfl⟩
  have hts : t * s = a := by rw [ht]; exact div_mul_self' a s hstep
  have ht1 : 4503599627370496 ≤ t := by
    apply Rat.le_of_mul_le_mul_right _ hstep
    grind
  have ht2 : t < 9007199254740992 := by
    apply Rat.lt_of_mul_lt_mul_right _ (Rat.le_of_lt hstep)
    grind
  have ht0 : 0 ≤ t := by grind
  obtain ⟨m, hm⟩ : ∃ m, m = roundHalfEven t := ⟨_, rfl⟩
  obtain ⟨b1, b2⟩ := roundHalfEven_bounds ht0
  rw [← hm] at b1 b2
  have hm1 : 2 ^ 52 ≤ m := by
    by_cases h : 2 ^ 52 ≤ m
    · exact h
    · have : m + 1 ≤ 2 ^ 52 := by omega
      have h' : ((m + 1 : Nat) : Rat) ≤ ((2 ^ 52 : Nat) : Rat) := by exact_mod_cast this
      rw [Rat.natCast_add, natCast_pow] at h'
      have : ((2 : Nat) : Rat) = 2 := rfl
      rw [this] at h'
      grind
  have hm2 : m ≤ 2 ^ 53 := by
    by_cases h : m ≤ 2 ^ 53
    · exact h
    · have : 2 ^ 53 + 1 ≤ m := by omega
      have h' : ((2 ^ 53 + 1 : Nat) : Rat) ≤ (m : Rat) := by exact_mod_cast this
      rw [Rat.natCast_add, natCast_pow] at h'
      have : ((2 : Nat) : Rat) = 2 := rfl
      rw [this] at h'
      grind
  have hmv := magValue_normal (e := e) (m := m) (by omega) (Or.inr hm1) hm2
  rw [← hs] at hmv
  have hmag : min ((e + 1022).toNat * 2 ^ 52 + m) infBits = (e + 1022).toNat * 2 ^ 52 + m := by
    omega
  have hmag0 : (e + 1022).toNat * 2 ^ 52 + m ≠ 0 := by omega
  have hnb : nearestBits q = UInt64.ofNat ((if q < 0 then 2 ^ 63 else 0) + ((e + 1022).toNat * 2 ^ 52 + m)) := by
    unfold nearestBits
    rw [ite_eq_right hq]
    dsimp only
    rw [← ha, ← he, hmax, ← hs, ← ht, ← hm, hmag]
  have d1 := hm1
  refine ⟨if q < 0 then -magValue ((e + 1022).toNat * 2 ^ 52 + m)
      else magValue ((e + 1022).toNat * 2 ^ 52 + m), ?_, ?_, ?_⟩
  · rw [hnb]
    by_cases hneg : q < 0
    · rw [ite_eq_left hneg, decode_neg _ (by omega)]
      simp [hneg]
    · rw [ite_eq_right hneg, Nat.zero_add, decode_pos _ (by omega)]
      simp [hneg]
  · rw [hnb]
    intro h
    have h' := congrArg UInt64.toNat h
    rw [UInt64.toNat_ofNat_of_lt' (by unfold UInt64.size; by_cases q < 0 <;> simp_all <;> omega)] at h'
    by_cases hneg : q < 0 <;> simp [hneg] at h' <;> omega
  · have hd1 := Rat.mul_le_mul_of_nonneg_right (show (m : Rat) - t ≤ 1 / 2 by grind) (Rat.le_of_lt hstep)
    have hd2 := Rat.mul_le_mul_of_nonneg_right (show t - (m : Rat) ≤ 1 / 2 by grind) (Rat.le_of_lt hstep)
    rw [hmv]
    by_cases hneg : q < 0
    · have hqa : q = -a := by
        rw [ha, ite_eq_left hneg]; grind
      simp only [ite_eq_left hneg]
      rw [hqa]
      constructor <;> grind
    · have hqa : q = a := by rw [ha, ite_eq_right hneg]
      simp only [ite_eq_right hneg]
      rw [hqa]
      constructor <;> grind

theorem decode_zero : decode 0 = some 0 := by
  have : (0 : UInt64).toNat = 0 := rfl
  unfold decode
  simp only [this]
  have h : ¬ infBits ≤ 0 % 2 ^ 63 := by unfold infBits; omega
  rw [ite_eq_right h, ite_eq_right (by omega)]
  unfold magValue
  simp only [Nat.zero_mod]
  rw [ite_eq_left (by omega)]
  have : ((0 : Nat) : Rat) = 0 := rfl
  rw [this, Rat.zero_mul]

theorem decode_negZero : decode 9223372036854775808 = some 0 := by
  have : (9223372036854775808 : UInt64).toNat = 2 ^ 63 := rfl
  unfold decode
  simp only [this]
  have h : ¬ infBits ≤ 2 ^ 63 % 2 ^ 63 := by unfold infBits; omega
  rw [ite_eq_right h, ite_eq_left (by omega)]
  unfold magValue
  rw [show 2 ^ 63 % 2 ^ 63 = 0 by omega, ite_eq_left (by omega)]
  have : ((0 : Nat) : Rat) = 0 := rfl
  rw [this, Rat.zero_mul]
  rfl

theorem nearestBits_zero : nearestBits 0 = 0 := by
  unfold nearestBits
  rw [ite_eq_left rfl]

theorem floor_half : ((1 : Rat) / 2).floor = 0 := by
  have h1 : 0 ≤ ((1 : Rat) / 2).floor := Rat.le_floor_iff.2 (by grind)
  have h2 : ((1 : Rat) / 2).floor < 1 := Rat.floor_lt_iff.2 (by grind)
  omega

theorem readBits_zero {d : Nat} {bits : UInt64} (h0 : bits = 0 ∨ bits = 9223372036854775808) :
    readBits d bits = some 0 := by
  have hd : decode bits = some 0 := by
    rcases h0 with h | h <;> rw [h]
    · exact decode_zero
    · exact decode_negZero
  have hz : (((0 : Int)) : Rat) / (10 : Rat) ^ d = 0 := by
    have : (((0 : Int)) : Rat) = 0 := rfl
    rw [this, Rat.div_def, Rat.zero_mul]
  have hf : ((0 : Rat) * (10 : Rat) ^ d + 1 / 2).floor = 0 := by
    rw [Rat.zero_mul]
    have : (0 : Rat) + 1 / 2 = 1 / 2 := by grind
    rw [this]
    exact floor_half
  unfold readBits
  rw [hd]
  simp only [hf, hz, nearestBits_zero]
  have : ¬ (bits ≠ 9223372036854775808 ∧ bits ≠ 0) := by grind
  by_cases hb : bits = 9223372036854775808
  · simp [hb]
  · have : bits = 0 := by grind
    simp [this]

theorem scaled_bounds {d : Nat} (hd : d ≤ 12) {N : Rat} (h1 : 1 ≤ N) (h2 : N < 1000000000000000)
    {A : Rat} (hA : A * (10 : Rat) ^ d = N) :
    (2 : Rat) ^ (-100 : Int) ≤ A ∧ A < (2 : Rat) ^ (100 : Int) := by
  have hD : (1 : Rat) ≤ (10 : Rat) ^ d := by
    have : 1 ≤ 10 ^ d := Nat.one_le_pow _ _ (by omega)
    have h : ((1 : Nat) : Rat) ≤ ((10 ^ d : Nat) : Rat) := by exact_mod_cast this
    rw [natCast_pow] at h
    exact h
  have hD2 : (10 : Rat) ^ d ≤ (10 : Rat) ^ 12 := by
    have : 10 ^ d ≤ 10 ^ 12 := Nat.pow_le_pow_right (by omega) hd
    have h : ((10 ^ d : Nat) : Rat) ≤ ((10 ^ 12 : Nat) : Rat) := by exact_mod_cast this
    rw [natCast_pow, natCast_pow] at h
    exact h
  have n1 : (10 : Rat) ^ 12 ≤ (2 : Rat) ^ 100 := by decide
  have n2 : (1000000000000000 : Rat) < (2 : Rat) ^ 100 := by decide
  have hDpos : 0 < (10 : Rat) ^ d := by grind
  have hApos : 0 < A := by
    by_cases h : 0 < A
    · exact h
    · have := Rat.mul_le_mul_of_nonneg_right (show A ≤ 0 by grind) (Rat.le_of_lt hDpos)
      grind
  have e100 : (2 : Rat) ^ (100 : Int) = (2 : Rat) ^ (100 : Nat) := rfl
  have e100' : (2 : Rat) ^ (-100 : Int) = ((2 : Rat) ^ (100 : Nat))⁻¹ := by
    rw [Rat.zpow_neg]; rfl
  constructor
  · rw [e100', inv_mul_pos_iff (by grind)]
    have := Rat.mul_le_mul_of_nonneg_left (show (10 : Rat) ^ d ≤ (2 : Rat) ^ 100 by grind) (Rat.le_of_lt hApos)
    grind
  · rw [e100]
    have := Rat.mul_le_mul_of_nonneg_left hD (Rat.le_of_lt hApos)
    grind

theorem readBits_iff {d : Nat} (hd : d ≤ 12) (bits : UInt64) (n : Int) :
    readBits d bits = some n ↔
      n.natAbs < 10 ^ 15 ∧
        nearestBits ((n : Rat) / (10 : Rat) ^ d) =
          (if bits = (9223372036854775808 : UInt64) then 0 else bits) := by
  constructor
  · intro h
    unfold readBits at h
    cases hdec : decode bits with
    | none => rw [hdec] at h; simp at h
    | some x =>
      rw [hdec] at h
      dsimp only at h
      by_cases hc : (x * (10 : Rat) ^ d + 1 / 2).floor.natAbs < 10 ^ 15 ∧
          nearestBits (((x * (10 : Rat) ^ d + 1 / 2).floor : Int) / (10 : Rat) ^ d) =
            (if bits = (9223372036854775808 : UInt64) then 0 else bits)
      · rw [ite_eq_left hc] at h
        injection h with h
        subst h
        exact hc
      · rw [ite_eq_right hc] at h
        simp at h
  · rintro ⟨hn, hb⟩
    by_cases hn0 : n = 0
    · subst hn0
      have hz : (((0 : Int)) : Rat) / (10 : Rat) ^ d = 0 := by
        have : (((0 : Int)) : Rat) = 0 := rfl
        rw [this, Rat.div_def, Rat.zero_mul]
      rw [hz, nearestBits_zero] at hb
      apply readBits_zero
      by_cases h : bits = 9223372036854775808
      · exact Or.inr h
      · rw [ite_eq_right h] at hb
        exact Or.inl hb.symm
    · have hD : 0 < (10 : Rat) ^ d := Rat.pow_pos (by decide)
      obtain ⟨q, hq⟩ : ∃ q, q = (n : Rat) / (10 : Rat) ^ d := ⟨_, rfl⟩
      rw [← hq] at hb
      have hqD : q * (10 : Rat) ^ d = n := by rw [hq]; exact div_mul_self' _ _ hD
      obtain ⟨N, A, hN1, hN2, hA, hAq, hnN⟩ : ∃ N A : Rat, 1 ≤ N ∧ N < 1000000000000000 ∧
          A * (10 : Rat) ^ d = N ∧ A = (if q < 0 then -q else q) ∧
          (q ≠ 0 ∧ ((q < 0 → (n : Rat) = -N) ∧ (¬ q < 0 → (n : Rat) = N))) := by
        have hna : (n.natAbs : Int) < 1000000000000000 := by omega
        by_cases hpos : 0 < n
        · have h1 : (1 : Int) ≤ n := by omega
          have h2 : n < 1000000000000000 := by omega
          have c1 : (1 : Rat) ≤ (n : Rat) := Rat.intCast_le_intCast.2 h1
          have c2 : (n : Rat) < 1000000000000000 := Rat.intCast_lt_intCast.2 h2
          have hq0 : ¬ q < 0 := by
            intro hlt
            have := Rat.mul_le_mul_of_nonneg_right (show q ≤ 0 by grind) (Rat.le_of_lt hD)
            grind
          refine ⟨n, q, c1, c2, hqD, by rw [ite_eq_right hq0], by grind, fun h => absurd h hq0, fun _ => rfl⟩
        · have h1 : n ≤ -1 := by omega
          have h2 : -1000000000000000 < n := by omega
          have c1 : (n : Rat) ≤ -1 := Rat.intCast_le_intCast.2 h1
          have c2 : -1000000000000000 < (n : Rat) := Rat.intCast_lt_intCast.2 h2
          have hq0 : q < 0 := by
            by_cases hlt : q < 0
            · exact hlt
            · have := Rat.mul_le_mul_of_nonneg_right (show 0 ≤ q by grind) (Rat.le_of_lt hD)
              grind
          refine ⟨-(n : Rat), -q, by grind, by grind, by grind, by rw [ite_eq_left hq0], by grind,
            fun _ => by grind, fun h => absurd hq0 h⟩
      obtain ⟨hqne, hbn⟩ := hnN
      obtain ⟨hlo, hhi⟩ := scaled_bounds hd hN1 hN2 hA
      rw [hAq] at hlo hhi
      obtain ⟨x, hx, hne, e1, e2⟩ := nearest_spec hqne hlo hhi
      have hbits : bits ≠ 9223372036854775808 := by
        intro h
        rw [ite_eq_left h] at hb
        exact hne hb
      rw [ite_eq_right hbits] at hb
      rw [hb] at hx
      unfold readBits
      rw [hx]
      simp only []
      have hfl : ((x * (10 : Rat) ^ d + 1 / 2).floor) = n := by
        have hmul1 := Rat.mul_le_mul_of_nonneg_right e1 (Rat.le_of_lt hD)
        have hmul2 := Rat.mul_le_mul_of_nonneg_right e2 (Rat.le_of_lt hD)
        have hAD : (if q < 0 then -q else q) * (10 : Rat) ^ d = N := by rw [← hAq]; exact hA
        have hle : (n : Rat) ≤ x * (10 : Rat) ^ d + 1 / 2 := by grind
        have hlt : x * (10 : Rat) ^ d + 1 / 2 < ((n + 1 : Int) : Rat) := by
          have e : ((n + 1 : Int) : Rat) = (n : Rat) + 1 := by simp
          rw [e]
          grind
        have h1 := Rat.le_floor_iff.2 hle
        have h2 := Rat.floor_lt_iff.2 hlt
        omega
      rw [hfl, ite_eq_left ⟨hn, by rw [← hq, ite_eq_right hbits]; exact hb⟩]

/-- `roundHalfEven (P / Q)` on natural numbers. -/
def roundDiv (P Q : Nat) : Nat :=
  let f := P / Q
  let r := 2 * (P % Q)
  if r < Q then f else if Q < r then f + 1 else if f % 2 = 0 then f else f + 1

/-- `nearestBits (n / pw)` for `pw` a power of ten (X3), on natural numbers and integers. -/
def nearestBitsAt (pw : Nat) (n : Int) : UInt64 :=
  if n = 0 then 0
  else
    let A := n.natAbs
    let s := Nat.log2 pw + 1
    let e : Int := (Nat.log2 (A * 2 ^ s / pw) : Int) - s
    let e' := max e (-1022)
    let m := roundDiv (A * 2 ^ (52 - e').toNat) pw
    let mag := min ((e' + 1022).toNat * 2 ^ 52 + m) infBits
    UInt64.ofNat ((if n < 0 then 2 ^ 63 else 0) + mag)

/-- A double's magnitude as a mantissa and an exponent of two. -/
def parts (mag : Nat) : Nat × Int :=
  if mag < 2 ^ 52 then (mag, -1074) else (mag % 2 ^ 52 + 2 ^ 52, ((mag / 2 ^ 52 : Nat) : Int) - 1075)

/-- `⌊S · 2 ^ E + 1/2⌋` on integers: a numerator over a power of two, never reduced. -/
def roundScaled (S E : Int) : Int :=
  if 0 ≤ E then S * 2 ^ E.toNat else (2 * S + 2 ^ (-E).toNat) / 2 ^ ((-E).toNat + 1)

/-- `readBits` on naturals and integers: a double is its mantissa and its exponent of two, a decimal its digits and
its scale; nothing is reduced (X3). -/
def readBitsFast (d : Nat) (bits : UInt64) : Option Int :=
  let v := bits.toNat
  let mag := v % 2 ^ 63
  if infBits ≤ mag then none
  else
    let pw := 10 ^ d
    let p := parts mag
    let N : Int := ((p.1 * pw : Nat) : Int)
    let n := roundScaled (if 2 ^ 63 ≤ v then -N else N) p.2
    if n.natAbs < 10 ^ 15 ∧ nearestBitsAt pw n = (if bits = (9223372036854775808 : UInt64) then 0 else bits)
    then some n else none

theorem floor_eq_of (y : Rat) (n : Int) (h1 : (n : Rat) ≤ y) (h2 : y < (n : Rat) + 1) : y.floor = n := by
  have a : n ≤ y.floor := Rat.le_floor_iff.2 h1
  have b : y.floor < n + 1 := Rat.floor_lt_iff.2 (by simpa using h2)
  omega

theorem roundDiv_eq (P Q : Nat) (hQ : 0 < Q) : roundHalfEven ((P : Rat) / (Q : Rat)) = roundDiv P Q := by
  have hQr : (0 : Rat) < (Q : Rat) := by exact_mod_cast hQ
  have hdm : Q * (P / Q) + P % Q = P := Nat.div_add_mod P Q
  have hmod : P % Q < Q := Nat.mod_lt P hQ
  have hdmr : (Q : Rat) * ((P / Q : Nat) : Rat) + ((P % Q : Nat) : Rat) = (P : Rat) := by exact_mod_cast hdm
  have hf : ((P : Rat) / (Q : Rat)).floor = ((P / Q : Nat) : Int) := by
    apply floor_eq_of
    · rw [← Rat.not_lt, Rat.div_lt_iff hQr]
      intro h
      have : ((P : Rat)) < ((P / Q : Nat) : Int) * (Q : Rat) := h
      have h2 : (0 : Rat) ≤ ((P % Q : Nat) : Rat) := by exact_mod_cast Nat.zero_le _
      simp only [Rat.intCast_natCast] at this
      grind
    · rw [Rat.div_lt_iff hQr]
      have h2 : ((P % Q : Nat) : Rat) < (Q : Rat) := by exact_mod_cast hmod
      simp only [Rat.intCast_natCast]
      grind
  have hflo : (((P : Rat) / (Q : Rat)).floor).toNat = P / Q := by rw [hf]; rfl
  unfold roundHalfEven roundDiv
  simp only [hflo]
  have hq1 : ((P : Rat) / (Q : Rat)) - ((P / Q : Nat) : Rat) < 1 / 2 ↔ 2 * (P % Q) < Q := by
    have e1 : ((P : Rat) / (Q : Rat)) - ((P / Q : Nat) : Rat) < 1 / 2 ↔ ((P : Rat) / (Q : Rat)) < 1 / 2 + ((P / Q : Nat) : Rat) :=
      ⟨fun h => by grind, fun h => by grind⟩
    rw [e1, Rat.div_lt_iff hQr]
    constructor
    · intro h
      have : ((2 * (P % Q) : Nat) : Rat) < (Q : Rat) := by push_cast; grind
      exact_mod_cast this
    · intro h
      have : ((2 * (P % Q) : Nat) : Rat) < (Q : Rat) := by exact_mod_cast h
      push_cast at this; grind
  have hq2 : 1 / 2 < ((P : Rat) / (Q : Rat)) - ((P / Q : Nat) : Rat) ↔ Q < 2 * (P % Q) := by
    have e1 : 1 / 2 < ((P : Rat) / (Q : Rat)) - ((P / Q : Nat) : Rat) ↔ 1 / 2 + ((P / Q : Nat) : Rat) < ((P : Rat) / (Q : Rat)) :=
      ⟨fun h => by grind, fun h => by grind⟩
    rw [e1, Rat.lt_div_iff hQr]
    constructor
    · intro h
      have : (Q : Rat) < ((2 * (P % Q) : Nat) : Rat) := by push_cast; grind
      exact_mod_cast this
    · intro h
      have : (Q : Rat) < ((2 * (P % Q) : Nat) : Rat) := by exact_mod_cast h
      push_cast at this; grind
  simp only [hq1, hq2]

theorem zpow_two_unique {p : Rat} {e e' : Int}
    (h1 : (2 : Rat) ^ e ≤ p) (h2 : p < (2 : Rat) ^ (e + 1)) (h3 : (2 : Rat) ^ e' ≤ p) (h4 : p < (2 : Rat) ^ (e' + 1)) :
    e = e' := by
  rcases Int.lt_trichotomy e e' with h | h | h
  · have := zpow_le_zpow (b := (2 : Rat)) (by decide) (show e + 1 ≤ e' by omega); grind
  · exact h
  · have := zpow_le_zpow (b := (2 : Rat)) (by decide) (show e' + 1 ≤ e by omega); grind

theorem ilog_two_eq {p : Rat} {e : Int} (h1 : (2 : Rat) ^ e ≤ p) (h2 : p < (2 : Rat) ^ (e + 1)) : ilog 2 p = e := by
  have hp : 0 < p := by
    have : 0 < (2 : Rat) ^ e := zpow_pos' (by decide) e
    grind
  obtain ⟨a, b⟩ := ilog_spec 2 (by omega) p hp
  have a' : (2 : Rat) ^ ilog 2 p ≤ p := by simpa using a
  have b' : p < (2 : Rat) ^ (ilog 2 p + 1) := by simpa using b
  exact zpow_two_unique a' b' h1 h2

theorem ilog2_div (A B : Nat) (hA : 0 < A) (hB : 0 < B) :
    ilog 2 ((A : Rat) / (B : Rat)) =
      (Nat.log2 (A * 2 ^ (Nat.log2 B + 1) / B) : Int) - ((Nat.log2 B + 1 : Nat) : Int) := by
  have hBr : (0 : Rat) < (B : Rat) := by exact_mod_cast hB
  obtain ⟨s, hs⟩ : ∃ s, s = Nat.log2 B + 1 := ⟨_, rfl⟩
  rw [← hs]
  have hBs : B < 2 ^ s := by rw [hs]; exact Nat.lt_log2_self
  have hY : 1 ≤ A * 2 ^ s / B := by
    rw [Nat.le_div_iff_mul_le hB]
    have : 2 ^ s ≤ A * 2 ^ s := Nat.le_mul_of_pos_left _ hA
    omega
  obtain ⟨Y, hYd⟩ : ∃ Y, Y = A * 2 ^ s / B := ⟨_, rfl⟩
  rw [← hYd] at hY ⊢
  have hY0 : Y ≠ 0 := by omega
  obtain ⟨hj1, hj2⟩ := (Nat.log2_eq_iff hY0).1 rfl
  generalize Nat.log2 Y = j at hj1 hj2 ⊢
  have hYB : Y * B ≤ A * 2 ^ s := by rw [hYd]; exact Nat.div_mul_le_self _ _
  have hYB2 : A * 2 ^ s < (Y + 1) * B := by
    rw [hYd]
    have := Nat.lt_div_mul_add (a := A * 2 ^ s) hB
    rw [Nat.add_mul, Nat.one_mul]; omega
  have hs2 : (0 : Rat) < (2 : Rat) ^ s := Rat.pow_pos (by decide)
  have c1 : ((2 ^ j * B : Nat) : Rat) ≤ ((A * 2 ^ s : Nat) : Rat) := by
    exact_mod_cast (Nat.le_trans (Nat.mul_le_mul_right B hj1) hYB)
  have c2 : ((A * 2 ^ s : Nat) : Rat) < ((2 ^ (j + 1) * B : Nat) : Rat) := by
    exact_mod_cast (Nat.lt_of_lt_of_le hYB2 (Nat.mul_le_mul_right B hj2))
  push_cast at c1 c2
  have t1 : (2 : Rat) ^ ((j : Int) - s) * (2 : Rat) ^ s = (2 : Rat) ^ j := by
    rw [← zpow_natCast' 2 s, ← zpow_natCast' 2 j, ← Rat.zpow_add (by decide)]
    congr 1; omega
  have t2 : (2 : Rat) ^ ((j : Int) - s + 1) * (2 : Rat) ^ s = (2 : Rat) ^ (j + 1) := by
    rw [← zpow_natCast' 2 s, ← zpow_natCast' 2 (j + 1), ← Rat.zpow_add (by decide)]
    congr 1; omega
  apply ilog_two_eq
  · rw [← Rat.not_lt, Rat.div_lt_iff hBr]
    intro h
    have := Rat.mul_lt_mul_of_pos_right h hs2
    have e3 : (A : Rat) * (2 : Rat) ^ s < (2 : Rat) ^ ((j : Int) - s) * (B : Rat) * (2 : Rat) ^ s := this
    have e4 : (2 : Rat) ^ ((j : Int) - s) * (B : Rat) * (2 : Rat) ^ s = (2 : Rat) ^ j * B := by
      rw [Rat.mul_assoc, Rat.mul_comm (B : Rat), ← Rat.mul_assoc, t1]
    rw [e4] at e3
    grind
  · rw [Rat.div_lt_iff hBr]
    refine Rat.not_le.1 ?_
    intro h
    have := Rat.mul_le_mul_of_nonneg_right h (Rat.le_of_lt hs2)
    have e4 : (2 : Rat) ^ ((j : Int) - s + 1) * (B : Rat) * (2 : Rat) ^ s = (2 : Rat) ^ (j + 1) * B := by
      rw [Rat.mul_assoc, Rat.mul_comm (B : Rat), ← Rat.mul_assoc, t2]
    rw [e4] at this
    grind

theorem two_pow_fifty : (2 : Rat) ^ (50 : Int) = 1125899906842624 := by
  rw [show (50 : Int) = ((50 : Nat) : Int) from rfl, zpow_natCast']
  decide +kernel

theorem nearestBitsAt_eq (d : Nat) (n : Int) (hn : n.natAbs < 10 ^ 15) :
    nearestBitsAt (10 ^ d) n = nearestBits ((n : Rat) / (10 : Rat) ^ d) := by
  have hB : 0 < 10 ^ d := Nat.pow_pos (by decide)
  have hBr : (0 : Rat) < ((10 ^ d : Nat) : Rat) := by exact_mod_cast hB
  have hBc : ((10 ^ d : Nat) : Rat) = (10 : Rat) ^ d := by rw [natCast_pow]; rfl
  rw [← hBc]
  obtain ⟨B, hBd⟩ : ∃ B, B = 10 ^ d := ⟨_, rfl⟩
  rw [← hBd] at hB hBr ⊢
  by_cases h0 : n = 0
  · subst h0
    have : ((0 : Int) : Rat) / (B : Rat) = 0 := by simp [Rat.div_def]
    rw [this]
    simp [nearestBitsAt, nearestBits_zero]
  · have hlt : (n : Rat) / (B : Rat) < 0 ↔ n < 0 := by
      rw [Rat.div_lt_iff hBr, Rat.zero_mul]; constructor <;> intro h <;> exact_mod_cast h
    have hgt : 0 < (n : Rat) / (B : Rat) ↔ 0 < n := by
      rw [Rat.lt_div_iff hBr, Rat.zero_mul]; constructor <;> intro h <;> exact_mod_cast h
    have hq0 : ((n : Rat) / (B : Rat)) ≠ 0 := by
      intro h
      rcases Int.lt_trichotomy n 0 with h1 | h1 | h1
      · have := hlt.2 h1; rw [h] at this; exact absurd this (by decide)
      · exact h0 h1
      · have := hgt.2 h1; rw [h] at this; exact absurd this (by decide)
    have hA : 0 < n.natAbs := by omega
    have hAc : (n.natAbs : Rat) = if n < 0 then -(n : Rat) else (n : Rat) := by
      by_cases hneg : n < 0
      · have : (n.natAbs : Int) = -n := by omega
        have h2 : ((n.natAbs : Nat) : Rat) = ((n.natAbs : Int) : Rat) := (Rat.intCast_natCast _).symm
        rw [ite_eq_left hneg, h2, this]; simp
      · have : (n.natAbs : Int) = n := by omega
        have h2 : ((n.natAbs : Nat) : Rat) = ((n.natAbs : Int) : Rat) := (Rat.intCast_natCast _).symm
        rw [ite_eq_right hneg, h2, this]
    have ha : (if (n : Rat) / (B : Rat) < 0 then -((n : Rat) / (B : Rat)) else (n : Rat) / (B : Rat)) =
        (n.natAbs : Rat) / (B : Rat) := by
      rw [hAc]
      by_cases hneg : n < 0
      · rw [ite_eq_left (hlt.2 hneg), ite_eq_left hneg]
        simp only [Rat.div_def, Rat.neg_mul]
      · rw [ite_eq_right (fun h => hneg (hlt.1 h)), ite_eq_right hneg]
    obtain ⟨A, hAd⟩ : ∃ A, A = n.natAbs := ⟨_, rfl⟩
    rw [← hAd] at hA hAc ha hn
    have hpos : (0 : Rat) < (A : Rat) / (B : Rat) := by
      rw [Rat.lt_div_iff hBr, Rat.zero_mul]; exact_mod_cast hA
    have hil := ilog2_div A B hA hB
    obtain ⟨hs1, hs2⟩ := ilog_spec 2 (by omega) ((A : Rat) / (B : Rat)) hpos
    have hs1' : (2 : Rat) ^ ilog 2 ((A : Rat) / (B : Rat)) ≤ (A : Rat) / (B : Rat) := by simpa using hs1
    have hpA : (A : Rat) / (B : Rat) ≤ (A : Rat) := by
      rw [← Rat.not_lt, Rat.lt_div_iff hBr]
      intro h
      have : (A : Rat) * (B : Rat) ≥ (A : Rat) := by
        have : A ≤ A * B := Nat.le_mul_of_pos_right A hB
        exact_mod_cast this
      grind
    have hA15 : (A : Rat) < 1125899906842624 := by
      have : A < 1125899906842624 := by omega
      exact_mod_cast this
    have he49 : ilog 2 ((A : Rat) / (B : Rat)) ≤ 49 := by
      by_cases h : ilog 2 ((A : Rat) / (B : Rat)) ≤ 49
      · exact h
      · have h50 : (50 : Int) ≤ ilog 2 ((A : Rat) / (B : Rat)) := by omega
        have := zpow_le_zpow (b := (2 : Rat)) (by decide) h50
        have e50 := two_pow_fifty
        grind
    obtain ⟨e, hed⟩ : ∃ e, e = max (ilog 2 ((A : Rat) / (B : Rat))) (-1022) := ⟨_, rfl⟩
    have he : e ≤ 49 := by omega
    have hm : roundHalfEven ((A : Rat) / (B : Rat) / (2 : Rat) ^ (e - 52)) = roundDiv (A * 2 ^ (52 - e).toNat) B := by
      have ht : (e - 52) = -(((52 - e).toNat : Nat) : Int) := by omega
      rw [ht, Rat.zpow_neg, zpow_natCast', Rat.div_def (A / B : Rat), Rat.inv_inv, ← roundDiv_eq _ _ hB]
      congr 1
      push_cast
      rw [Rat.div_def, Rat.div_def, Rat.mul_assoc, Rat.mul_comm (((B : Rat))⁻¹), ← Rat.mul_assoc]
    unfold nearestBitsAt nearestBits
    simp only [h0, hq0, ite_false]
    rw [ha, ← hed, hm]
    simp only [hlt]
    subst hAd
    rw [hil] at hed
    rw [← hed]

theorem floor_scaled (S E : Int) : ((S : Rat) * (2 : Rat) ^ E + 1 / 2).floor = roundScaled S E := by
  unfold roundScaled
  by_cases hE : 0 ≤ E
  · rw [ite_eq_left hE]
    obtain ⟨t, ht⟩ : ∃ t : Nat, E = t := ⟨E.toNat, by omega⟩
    have hto : E.toNat = t := by omega
    rw [hto, ht]
    apply floor_eq_of
    · have : ((S * 2 ^ t : Int) : Rat) = (S : Rat) * (2 : Rat) ^ ((t : Nat) : Int) := by
        rw [Rat.intCast_mul, zpow_natCast']; push_cast; rfl
      rw [← this]; grind
    · have : ((S * 2 ^ t : Int) : Rat) = (S : Rat) * (2 : Rat) ^ ((t : Nat) : Int) := by
        rw [Rat.intCast_mul, zpow_natCast']; push_cast; rfl
      rw [← this]; grind
  · rw [ite_eq_right hE]
    obtain ⟨k, hk⟩ : ∃ k : Nat, E = -(k : Int) := ⟨(-E).toNat, by omega⟩
    have hto : (-E).toNat = k := by omega
    rw [hto, hk]
    have h2k : (0 : Rat) < (2 : Rat) ^ k := Rat.pow_pos (by decide)
    have h2k1 : (0 : Rat) < (2 : Rat) ^ (k + 1) := Rat.pow_pos (by decide)
    have hy : ((S : Rat) * (2 : Rat) ^ (-(k : Int)) + 1 / 2) * (2 : Rat) ^ (k + 1) = (2 * S + 2 ^ k : Int) := by
      rw [Rat.zpow_neg, zpow_natCast', Rat.pow_succ]
      have hinv : ((2 : Rat) ^ k)⁻¹ * (2 : Rat) ^ k = 1 := Rat.inv_mul_cancel _ (by grind)
      push_cast
      grind
    have hp : (0 : Int) < 2 ^ (k + 1) := by
      have : 0 < 2 ^ (k + 1) := Nat.pow_pos (by decide)
      exact_mod_cast this
    have hq := Int.ediv_mul_le (2 * S + 2 ^ k) (b := 2 ^ (k + 1)) (Int.ne_of_gt hp)
    have hq2 := Int.lt_ediv_add_one_mul_self (2 * S + 2 ^ k) (b := 2 ^ (k + 1)) hp
    obtain ⟨q, hqd⟩ : ∃ q, q = (2 * S + 2 ^ k) / 2 ^ (k + 1) := ⟨_, rfl⟩
    rw [← hqd] at hq hq2 ⊢
    apply floor_eq_of
    · refine Rat.not_lt.1 ?_
      intro h
      have := Rat.mul_lt_mul_of_pos_right h h2k1
      rw [hy] at this
      have hc : ((q * 2 ^ (k + 1) : Int) : Rat) ≤ ((2 * S + 2 ^ k : Int) : Rat) := by exact_mod_cast hq
      push_cast at hc this
      grind
    · refine Rat.not_le.1 ?_
      intro h
      have := Rat.mul_le_mul_of_nonneg_right h (Rat.le_of_lt h2k1)
      rw [hy] at this
      have hc : ((2 * S + 2 ^ k : Int) : Rat) < (((q + 1) * 2 ^ (k + 1) : Int) : Rat) := by exact_mod_cast hq2
      push_cast at hc this
      grind

theorem magValue_parts (mag : Nat) : magValue mag = ((parts mag).1 : Rat) * (2 : Rat) ^ (parts mag).2 := by
  unfold magValue parts
  split <;> rfl

theorem readBitsFast_eq (d : Nat) (bits : UInt64) : readBitsFast d bits = readBits d bits := by
  unfold readBitsFast readBits decode
  by_cases hinf : infBits ≤ bits.toNat % 2 ^ 63
  · simp [hinf]
  · simp only [hinf, ite_false]
    have hfloor : ((if 2 ^ 63 ≤ bits.toNat then -magValue (bits.toNat % 2 ^ 63) else magValue (bits.toNat % 2 ^ 63)) *
          (10 : Rat) ^ d + 1 / 2).floor =
        roundScaled (if 2 ^ 63 ≤ bits.toNat then -(((parts (bits.toNat % 2 ^ 63)).fst * 10 ^ d : Nat) : Int)
          else (((parts (bits.toNat % 2 ^ 63)).fst * 10 ^ d : Nat) : Int)) (parts (bits.toNat % 2 ^ 63)).snd := by
      rw [← floor_scaled, magValue_parts]
      have h10 : (((10 ^ d : Nat) : Int) : Rat) = (10 : Rat) ^ d := by
        rw [Rat.intCast_natCast, natCast_pow]; rfl
      by_cases hneg : 2 ^ 63 ≤ bits.toNat
      · simp only [hneg, ite_true]
        congr 2
        push_cast
        rw [← h10]
        push_cast
        grind
      · simp only [hneg, ite_false]
        congr 2
        push_cast
        rw [← h10]
        push_cast
        grind
    rw [hfloor]
    generalize roundScaled (if 2 ^ 63 ≤ bits.toNat then -(((parts (bits.toNat % 2 ^ 63)).fst * 10 ^ d : Nat) : Int)
          else (((parts (bits.toNat % 2 ^ 63)).fst * 10 ^ d : Nat) : Int)) (parts (bits.toNat % 2 ^ 63)).snd = n
    by_cases hn : n.natAbs < 10 ^ 15
    · rw [nearestBitsAt_eq d n hn]
    · simp [hn]

/-- X3: the twin replaces `readBits` where it is called (Lean's `@[csimp]`). -/
@[csimp] theorem readBits_eq_readBitsFast : @readBits = @readBitsFast := by
  funext d bits
  exact (readBitsFast_eq d bits).symm

/-! ### `exp` and `log` (X4)

Pinned MPFR evaluated at 53 bits with IEEE-754 binary64 exponent range and subnormalization (`c/mpfr_ops.c`). -/

@[extern "mm2_mpfr_exp"] opaque exp (bits : UInt64) : UInt64
@[extern "mm2_mpfr_log"] opaque log (bits : UInt64) : UInt64

end Engine.Exact
