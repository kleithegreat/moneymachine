import Engine.Exact

namespace Engine.Exact

theorem sq_le_sq {a b : Rat} (ha : 0 ≤ a) (h : a ≤ b) : a * a ≤ b * b := by
  have hb : 0 ≤ b := Rat.le_trans ha h
  calc a * a ≤ a * b := Rat.mul_le_mul_of_nonneg_left h ha
    _ ≤ b * b := Rat.mul_le_mul_of_nonneg_right h hb

theorem sq_lt_sq {a b : Rat} (ha : 0 ≤ a) (h : a < b) : a * a < b * b := by
  have hb : 0 < b := by grind
  have h1 : a * a ≤ a * b := Rat.mul_le_mul_of_nonneg_left (Rat.le_of_lt h) ha
  have h2 : a * b < b * b := Rat.mul_lt_mul_of_pos_right h hb
  grind

theorem sq_inj {a b : Rat} (ha : 0 ≤ a) (h : a ≤ b) (e : b * b ≤ a * a) : a = b := by
  apply Classical.byContradiction
  intro hne
  have hlt : a < b := Rat.lt_of_le_of_ne h hne
  have := sq_lt_sq ha hlt
  grind

theorem roundHalfEven_cases {t : Rat} (ht : 0 ≤ t) :
    ∃ f : Nat, (f : Rat) ≤ t ∧ t < (f : Rat) + 1 ∧
      ((roundHalfEven t = f ∧ t - f ≤ 1 / 2 ∧ (t - f = 1 / 2 → f % 2 = 0)) ∨
       (roundHalfEven t = f + 1 ∧ 1 / 2 ≤ t - f ∧ (t - f = 1 / 2 → f % 2 = 1))) := by
  have hf0 : 0 ≤ t.floor := Rat.le_floor_iff.2 (by simpa using ht)
  have hc' : ((t.floor.toNat : Nat) : Rat) = (t.floor : Rat) := by
    rw [← Rat.intCast_natCast, Int.toNat_of_nonneg hf0]
  have h1 := Rat.floor_le t
  have h2 := Rat.lt_floor_add_one t
  refine ⟨t.floor.toNat, by grind, by grind, ?_⟩
  unfold roundHalfEven
  simp only []
  split
  · rename_i h
    left
    refine ⟨rfl, by grind, fun hh => ?_⟩
    rw [hh] at h
    exact (Rat.lt_irrefl h).elim
  · split
    · rename_i h h'
      right
      refine ⟨rfl, by grind, fun hh => ?_⟩
      rw [hh] at h'
      exact (Rat.lt_irrefl h').elim
    · rename_i h h'
      have hne : t - (t.floor.toNat : Rat) = 1 / 2 := by grind
      split
      · left
        exact ⟨rfl, by grind, fun _ => by assumption⟩
      · right
        exact ⟨rfl, by grind, fun _ => by omega⟩

theorem roundHalfEven_nearest {t : Rat} (ht : 0 ≤ t) (k : Int) :
    ((roundHalfEven t : Rat) - t) * ((roundHalfEven t : Rat) - t) ≤
      ((k : Rat) - t) * ((k : Rat) - t) ∧
    (((roundHalfEven t : Rat) - t) * ((roundHalfEven t : Rat) - t) =
        ((k : Rat) - t) * ((k : Rat) - t) →
      (k : Rat) ≠ (roundHalfEven t : Rat) → roundHalfEven t % 2 = 0) := by
  obtain ⟨f, hf1, hf2, hc⟩ := roundHalfEven_cases ht
  have hk : (k : Rat) ≤ f ∨ (f : Rat) + 1 ≤ k := by
    by_cases h : k ≤ (f : Int)
    · left
      exact_mod_cast h
    · right
      have : (f : Int) + 1 ≤ k := by omega
      exact_mod_cast this
  rcases hc with ⟨hm, h1, h2⟩ | ⟨hm, h1, h2⟩
  · have hmc : (roundHalfEven t : Rat) = f := by exact_mod_cast hm
    rw [hmc]
    rcases hk with hk | hk
    · have A := sq_le_sq (a := t - f) (b := t - k) (by grind) (by grind)
      refine ⟨by grind, fun heq hne => ?_⟩
      have := sq_inj (a := t - f) (b := t - k) (by grind) (by grind) (by grind)
      grind
    · have A := sq_le_sq (a := t - f) (b := k - t) (by grind) (by grind)
      refine ⟨by grind, fun heq _ => ?_⟩
      have := sq_inj (a := t - f) (b := k - t) (by grind) (by grind) (by grind)
      have := h2 (by grind)
      omega
  · have hmc : (roundHalfEven t : Rat) = f + 1 := by exact_mod_cast hm
    rw [hmc]
    rcases hk with hk | hk
    · have A := sq_le_sq (a := f + 1 - t) (b := t - k) (by grind) (by grind)
      refine ⟨by grind, fun heq _ => ?_⟩
      have := sq_inj (a := f + 1 - t) (b := t - k) (by grind) (by grind) (by grind)
      have := h2 (by grind)
      omega
    · have A := sq_le_sq (a := f + 1 - t) (b := k - t) (by grind) (by grind)
      refine ⟨by grind, fun heq hne => ?_⟩
      have := sq_inj (a := f + 1 - t) (b := k - t) (by grind) (by grind) (by grind)
      grind

theorem roundHalfEven_ge {t : Rat} (ht : 0 ≤ t) {N : Nat} (hN : N % 2 = 0)
    (h : (N : Rat) - 1 / 2 ≤ t) : N ≤ roundHalfEven t := by
  obtain ⟨f, hf1, hf2, hc⟩ := roundHalfEven_cases ht
  rcases hc with ⟨hm, h1, h2⟩ | ⟨hm, h1, h2⟩
  · rw [hm]
    have hcases : N ≤ f ∨ f + 1 = N ∨ f + 2 ≤ N := by omega
    rcases hcases with hc | hc | hc
    · exact hc
    · have hcast : (N : Rat) = f + 1 := by exact_mod_cast hc.symm
      have := h2 (by grind)
      omega
    · have hcast : (f : Rat) + 2 ≤ N := by exact_mod_cast hc
      grind
  · rw [hm]
    by_cases hc : N ≤ f + 1
    · exact hc
    · have hcast : (f : Rat) + 2 ≤ N := by exact_mod_cast (show f + 2 ≤ N by omega)
      grind

theorem round_vs {t τ : Rat} (ht : 0 ≤ t)
    (hτ : (∃ k : Int, τ = k) ∨ ((2 : Rat) ^ 52 ≤ t ∧ τ ≤ (2 : Rat) ^ 52 - 1 / 2)) :
    ((roundHalfEven t : Rat) - t) * ((roundHalfEven t : Rat) - t) ≤ (τ - t) * (τ - t) ∧
    (((roundHalfEven t : Rat) - t) * ((roundHalfEven t : Rat) - t) = (τ - t) * (τ - t) →
      τ ≠ (roundHalfEven t : Rat) → roundHalfEven t % 2 = 0) := by
  rcases hτ with ⟨k, hk⟩ | ⟨h1, h2⟩
  · subst hk
    exact roundHalfEven_nearest ht k
  · have hk := (roundHalfEven_nearest ht ((2 : Int) ^ 52)).1
    have e52 : (((2 : Int) ^ 52 : Int) : Rat) = (2 : Rat) ^ 52 := by push_cast; rfl
    rw [e52] at hk
    have hlt := sq_lt_sq (a := t - (2 : Rat) ^ 52) (b := t - τ) (by grind) (by grind)
    have hle : ((roundHalfEven t : Rat) - t) * ((roundHalfEven t : Rat) - t) <
        (τ - t) * (τ - t) := by grind
    exact ⟨Rat.le_of_lt hle, fun heq => by grind⟩

theorem zpow_split (c : Rat) (x y : Int) : c * (2 : Rat) ^ x = (c * (2 : Rat) ^ (x - y)) * (2 : Rat) ^ y := by
  have h := Rat.zpow_add (q := (2 : Rat)) (by decide) (x - y) y
  rw [show x - y + y = x by omega] at h
  rw [h, Rat.mul_assoc]

theorem zpow_neg_one : (2 : Rat) ^ (-1 : Int) = 1 / 2 := by
  have h := Rat.zpow_neg (2 : Rat) 1
  rw [Rat.zpow_one] at h
  rw [show (-1 : Int) = -(1 : Int) from rfl, h]
  grind

theorem grid_aux {e : Int} {c : Nat} {x : Int} (hc : c < 2 ^ 53)
    (hj : e - 52 ≤ x ∨ (x < e - 52 ∧ -1022 < e)) :
    ∃ τ : Rat, (c : Rat) * (2 : Rat) ^ x = τ * (2 : Rat) ^ (e - 52) ∧ 0 ≤ τ ∧
      ((∃ k : Int, τ = k) ∨ (-1022 < e ∧ τ ≤ (2 : Rat) ^ 52 - 1 / 2)) := by
  refine ⟨(c : Rat) * (2 : Rat) ^ (x - (e - 52)), zpow_split _ _ _, ?_⟩
  have hp : 0 < (2 : Rat) ^ (x - (e - 52)) := zpow_pos' (by decide) _
  have hc0 : (0 : Rat) ≤ c := Rat.natCast_nonneg (a := c)
  refine ⟨Rat.mul_nonneg hc0 (Rat.le_of_lt hp), ?_⟩
  rcases hj with hj | ⟨hj, he⟩
  · left
    obtain ⟨n, hn⟩ : ∃ n : Nat, x - (e - 52) = n := ⟨(x - (e - 52)).toNat, by omega⟩
    refine ⟨(c : Int) * 2 ^ n, ?_⟩
    rw [hn, Rat.zpow_natCast]
    push_cast
    rfl
  · right
    refine ⟨he, ?_⟩
    have h1 : (2 : Rat) ^ (x - (e - 52)) ≤ 1 / 2 := by
      rw [← zpow_neg_one]
      exact zpow_le_zpow (by decide) (by omega)
    have h2 : (c : Rat) ≤ (2 : Rat) ^ 53 - 1 := by
      have : c + 1 ≤ 2 ^ 53 := hc
      have h' : ((c + 1 : Nat) : Rat) ≤ ((2 ^ 53 : Nat) : Rat) := by exact_mod_cast this
      rw [Rat.natCast_add, natCast_pow] at h'
      have : ((2 : Nat) : Rat) = 2 := rfl
      rw [this] at h'
      have : ((1 : Nat) : Rat) = 1 := rfl
      grind
    have n52 : (2 : Rat) ^ 52 = 4503599627370496 := by decide
    have n53 : (2 : Rat) ^ 53 = 9007199254740992 := by decide
    have h3 := Rat.mul_le_mul_of_nonneg_left h1 hc0
    grind

theorem magValue_grid (e : Int) (he : -1022 ≤ e) (mag : Nat) :
    ∃ τ : Rat, magValue mag = τ * (2 : Rat) ^ (e - 52) ∧ 0 ≤ τ ∧
      ((∃ k : Int, τ = k) ∨ (-1022 < e ∧ τ ≤ (2 : Rat) ^ 52 - 1 / 2)) := by
  unfold magValue
  split
  · exact grid_aux (e := e) (c := mag) (x := -1074) (by omega) (by omega)
  · exact grid_aux (e := e) (c := mag % 2 ^ 52 + 2 ^ 52) (x := ((mag / 2 ^ 52 : Nat) : Int) - 1075)
      (by omega) (by omega)

theorem binade_facts {a : Rat} (ha : 0 < a) {e : Int} (he : e = max (ilog 2 a) (-1022))
    {s t : Rat} (hs : s = (2 : Rat) ^ (e - 52)) (ht : t = a / s) :
    0 < s ∧ t * s = a ∧ 0 ≤ t ∧ t < 9007199254740992 ∧ (-1022 < e → 4503599627370496 ≤ t) ∧
      (2 : Rat) ^ e = s * 4503599627370496 ∧ (2 : Rat) ^ (e + 1) = s * 9007199254740992 := by
  have h2pos : (0 : Rat) < 2 := by decide
  have h2gt : (1 : Rat) < 2 := by decide
  have hstep : 0 < s := hs ▸ zpow_pos' h2pos _
  obtain ⟨hs1, hs2⟩ : (2 : Rat) ^ (ilog 2 a) ≤ a ∧ a < (2 : Rat) ^ (ilog 2 a + 1) :=
    ilog_spec 2 (by omega) a ha
  have n52 : (2 : Rat) ^ 52 = 4503599627370496 := by decide
  have n53 : (2 : Rat) ^ 53 = 9007199254740992 := by decide
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
  have hts : t * s = a := by rw [ht]; exact div_mul_self' a s hstep
  have ht0 : 0 ≤ t := ht ▸ div_nonneg' hstep (Rat.le_of_lt ha)
  have hup := zpow_le_zpow h2gt (show ilog 2 a + 1 ≤ e + 1 by omega)
  refine ⟨hstep, hts, ht0, ?_, fun hlow => ?_, r1, r2⟩
  · apply Rat.lt_of_mul_lt_mul_right _ (Rat.le_of_lt hstep)
    grind
  · have hilog : ilog 2 a = e := by omega
    rw [hilog] at hs1
    apply Rat.le_of_mul_le_mul_right _ hstep
    grind

theorem cancel_sq {A B c : Rat} (hc : 0 < c) (hle : A ≤ B) (h : A * c = B * c) : A = B := by
  apply Classical.byContradiction
  intro hne
  have hlt : A < B := Rat.lt_of_le_of_ne hle hne
  have := Rat.mul_lt_mul_of_pos_right hlt hc
  grind

theorem mag_level {a s t : Rat} {e : Int} {m mag' : Nat} (he : -1022 ≤ e) (hs : 0 < s)
    (hs' : s = (2 : Rat) ^ (e - 52)) (hts : t * s = a) (ht0 : 0 ≤ t)
    (hlow : -1022 < e → 4503599627370496 ≤ t) (hm : m = roundHalfEven t) :
    ((m : Rat) * s - a) * ((m : Rat) * s - a) ≤ (magValue mag' - a) * (magValue mag' - a) ∧
    (((m : Rat) * s - a) * ((m : Rat) * s - a) = (magValue mag' - a) * (magValue mag' - a) →
      magValue mag' ≠ (m : Rat) * s → m % 2 = 0) := by
  obtain ⟨τ, hM, hτ0, hτ⟩ := magValue_grid e he mag'
  rw [← hs'] at hM
  have n52 : (2 : Rat) ^ 52 = 4503599627370496 := by decide
  have hτ' : (∃ k : Int, τ = k) ∨ ((2 : Rat) ^ 52 ≤ t ∧ τ ≤ (2 : Rat) ^ 52 - 1 / 2) := by
    rcases hτ with hk | ⟨h1, h2⟩
    · exact Or.inl hk
    · exact Or.inr ⟨by rw [n52]; exact hlow h1, h2⟩
  subst hm
  obtain ⟨k1, k2⟩ := round_vs ht0 hτ'
  have hss : 0 < s * s := Rat.mul_pos hs hs
  have e1 : ((roundHalfEven t : Rat) * s - a) * ((roundHalfEven t : Rat) * s - a) =
      (((roundHalfEven t : Rat) - t) * ((roundHalfEven t : Rat) - t)) * (s * s) := by
    rw [← hts]
    grind
  have e2 : (magValue mag' - a) * (magValue mag' - a) = ((τ - t) * (τ - t)) * (s * s) := by
    rw [hM, ← hts]
    grind
  rw [e1, e2]
  refine ⟨Rat.mul_le_mul_of_nonneg_right k1 (Rat.le_of_lt hss), fun heq hne => ?_⟩
  have heq' := cancel_sq hss k1 heq
  refine k2 heq' (fun h => hne ?_)
  rw [hM, h]

theorem signed_nearest {a V M σ τ : Rat} {P : Prop} (ha : 0 < a) (hM : 0 ≤ M)
    (hσ : σ = 1 ∨ σ = -1) (hτ : τ = 1 ∨ τ = -1)
    (h1 : (V - a) * (V - a) ≤ (M - a) * (M - a))
    (h2 : (V - a) * (V - a) = (M - a) * (M - a) → M ≠ V → P) :
    (σ * V - σ * a) * (σ * V - σ * a) ≤ (τ * M - σ * a) * (τ * M - σ * a) ∧
    ((τ * M - σ * a) * (τ * M - σ * a) = (σ * V - σ * a) * (σ * V - σ * a) →
      τ * M ≠ σ * V → P) := by
  have hMa : 0 ≤ M * a := Rat.mul_nonneg hM (Rat.le_of_lt ha)
  rcases hσ with rfl | rfl <;> rcases hτ with rfl | rfl
  · refine ⟨by grind, fun heq hne => h2 (by grind) (fun h => hne (by rw [h]))⟩
  · refine ⟨by grind, fun heq hne => ?_⟩
    have hM0 : M = 0 := by
      apply Classical.byContradiction
      intro hne0
      have : 0 < M := Rat.lt_of_le_of_ne hM (Ne.symm hne0)
      have := Rat.mul_pos this ha
      grind
    have hV0 : V ≠ 0 := fun hV0 => hne (by rw [hM0, hV0]; grind)
    exact h2 (by grind) (fun h => hV0 (by rw [hM0] at h; exact h.symm))
  · refine ⟨by grind, fun heq hne => ?_⟩
    have hM0 : M = 0 := by
      apply Classical.byContradiction
      intro hne0
      have : 0 < M := Rat.lt_of_le_of_ne hM (Ne.symm hne0)
      have := Rat.mul_pos this ha
      grind
    have hV0 : V ≠ 0 := fun hV0 => hne (by rw [hM0, hV0]; grind)
    exact h2 (by grind) (fun h => hV0 (by rw [hM0] at h; exact h.symm))
  · refine ⟨by grind, fun heq hne => h2 (by grind) (fun h => hne (by rw [h]))⟩

theorem magValue_nonneg (mag : Nat) : 0 ≤ magValue mag := by
  unfold magValue
  split
  · exact Rat.mul_nonneg (Rat.natCast_nonneg (a := mag)) (Rat.le_of_lt (zpow_pos' (by decide) _))
  · exact Rat.mul_nonneg (Rat.natCast_nonneg (a := _)) (Rat.le_of_lt (zpow_pos' (by decide) _))

theorem threshold_top {e : Int} {s : Rat} (he : e = 1023) (r1 : (2 : Rat) ^ e = s * 4503599627370496) :
    (2 - (2 : Rat) ^ (-53 : Int)) * (2 : Rat) ^ (1023 : Int) = s * (9007199254740992 - 1 / 2) := by
  subst he
  have h := Rat.zpow_add (q := (2 : Rat)) (by decide) (-53) 53
  have n53 : (2 : Rat) ^ (53 : Int) = 9007199254740992 := by decide
  rw [show (-53 : Int) + 53 = 0 by omega, Rat.zpow_zero, n53] at h
  rw [r1]
  grind

theorem threshold_bounds :
    (2 : Rat) ^ (1023 : Int) ≤ (2 - (2 : Rat) ^ (-53 : Int)) * (2 : Rat) ^ (1023 : Int) ∧
    (2 - (2 : Rat) ^ (-53 : Int)) * (2 : Rat) ^ (1023 : Int) < (2 : Rat) ^ (1023 : Int) * 2 := by
  have hc1 : (2 : Rat) ^ (-53 : Int) ≤ 1 := by
    have := zpow_le_zpow (b := (2 : Rat)) (by decide) (show (-53 : Int) ≤ 0 by omega)
    rwa [Rat.zpow_zero] at this
  have hc0 : 0 < (2 : Rat) ^ (-53 : Int) := zpow_pos' (by decide) _
  have hP : 0 < (2 : Rat) ^ (1023 : Int) := zpow_pos' (by decide) _
  have h1 := Rat.mul_le_mul_of_nonneg_right hc1 (Rat.le_of_lt hP)
  have h2 := Rat.mul_pos hc0 hP
  constructor <;> grind

theorem nearestBits_ieee :
    Engine.Exact.nearestBits 0 = 0 ∧
    ∀ q : Rat, q ≠ 0 →
      ((2 ^ 63 ≤ (Engine.Exact.nearestBits q).toNat) ↔ q < 0) ∧
      ((2 - (2 : Rat) ^ (-53 : Int)) * (2 : Rat) ^ (1023 : Int) ≤ (if q < 0 then -q else q) →
        (Engine.Exact.nearestBits q).toNat % 2 ^ 63 = Engine.Exact.infBits) ∧
      ((if q < 0 then -q else q) < (2 - (2 : Rat) ^ (-53 : Int)) * (2 : Rat) ^ (1023 : Int) →
        ∃ v, Engine.Exact.decode (Engine.Exact.nearestBits q) = some v ∧
          ∀ (b : UInt64) (w : Rat), Engine.Exact.decode b = some w →
            (v - q) * (v - q) ≤ (w - q) * (w - q) ∧
            ((w - q) * (w - q) = (v - q) * (v - q) → w ≠ v →
              (Engine.Exact.nearestBits q).toNat % 2 = 0)) := by
  refine ⟨nearestBits_zero, fun q hq => ?_⟩
  obtain ⟨a, ha⟩ : ∃ a, a = (if q < 0 then -q else q) := ⟨_, rfl⟩
  rw [← ha]
  have hapos : 0 < a := by
    by_cases hneg : q < 0
    · rw [ite_eq_left hneg] at ha
      grind
    · rw [ite_eq_right hneg] at ha
      grind
  obtain ⟨e, he⟩ : ∃ e, e = max (ilog 2 a) (-1022) := ⟨_, rfl⟩
  obtain ⟨s, hs⟩ : ∃ s, s = (2 : Rat) ^ (e - 52) := ⟨_, rfl⟩
  obtain ⟨t, ht⟩ : ∃ t, t = a / s := ⟨_, rfl⟩
  obtain ⟨m, hm⟩ : ∃ m, m = roundHalfEven t := ⟨_, rfl⟩
  obtain ⟨hspos, hts, ht0, ht2, hlow, r1, r2⟩ := binade_facts hapos he hs ht
  obtain ⟨b1, b2⟩ := roundHalfEven_bounds ht0
  rw [← hm] at b1 b2
  have he1 : -1022 ≤ e := by omega
  have hm1 : -1022 < e → 2 ^ 52 ≤ m := by
    intro hlt
    have := hlow hlt
    by_cases h : 2 ^ 52 ≤ m
    · exact h
    · have : ((m + 1 : Nat) : Rat) ≤ ((2 ^ 52 : Nat) : Rat) := by exact_mod_cast (show m + 1 ≤ 2 ^ 52 by omega)
      rw [Rat.natCast_add, natCast_pow] at this
      have h2 : ((2 : Nat) : Rat) = 2 := rfl
      have h4 : (2 : Rat) ^ 52 = 4503599627370496 := by decide
      rw [h2, h4] at this
      grind
  have hm2 : m ≤ 2 ^ 53 := by
    by_cases h : m ≤ 2 ^ 53
    · exact h
    · have : ((2 ^ 53 + 1 : Nat) : Rat) ≤ (m : Rat) := by exact_mod_cast (show 2 ^ 53 + 1 ≤ m by omega)
      rw [Rat.natCast_add, natCast_pow] at this
      have h2 : ((2 : Nat) : Rat) = 2 := rfl
      have h4 : (2 : Rat) ^ 53 = 9007199254740992 := by decide
      rw [h2, h4] at this
      grind
  have hV : magValue ((e + 1022).toNat * 2 ^ 52 + m) = (m : Rat) * s := by
    rw [hs]
    exact magValue_normal he1 (by omega) hm2
  obtain ⟨raw, hraw⟩ : ∃ raw, raw = (e + 1022).toNat * 2 ^ 52 + m := ⟨_, rfl⟩
  rw [← hraw] at hV
  obtain ⟨sg, hsg⟩ : ∃ sg : Nat, sg = if q < 0 then 2 ^ 63 else 0 := ⟨_, rfl⟩
  have hsg1 : q < 0 → sg = 2 ^ 63 := fun h => by rw [hsg, ite_eq_left h]
  have hsg2 : ¬ q < 0 → sg = 0 := fun h => by rw [hsg, ite_eq_right h]
  have hsgc : sg = 2 ^ 63 ∨ sg = 0 := by
    by_cases h : q < 0
    · exact Or.inl (hsg1 h)
    · exact Or.inr (hsg2 h)
  have hinf : infBits = 0x7ff0000000000000 := rfl
  have hnb : nearestBits q = UInt64.ofNat (sg + min raw infBits) := by
    unfold nearestBits
    rw [ite_eq_right hq]
    dsimp only
    rw [← ha, ← he, ← hs, ← ht, ← hm, ← hraw, ← hsg]
  have htoNat : (nearestBits q).toNat = sg + min raw infBits := by
    rw [hnb]
    exact UInt64.toNat_ofNat_of_lt' (by unfold UInt64.size; omega)
  refine ⟨?_, fun hT => ?_, fun hT => ?_⟩
  · rw [htoNat]
    by_cases hneg : q < 0
    · have := hsg1 hneg
      exact ⟨fun _ => hneg, fun _ => by omega⟩
    · have := hsg2 hneg
      exact ⟨fun h => by omega, fun h => absurd h hneg⟩
  · have hrawinf : infBits ≤ raw := by
      by_cases h1023 : e = 1023
      · have hT' := threshold_top h1023 r1
        rw [hT'] at hT
        have : 9007199254740992 - 1 / 2 ≤ t := by
          apply Rat.le_of_mul_le_mul_right _ hspos
          grind
        have hN := roundHalfEven_ge (N := 2 ^ 53) ht0 (by omega) (by
          have h4 : ((2 ^ 53 : Nat) : Rat) = 9007199254740992 := by decide
          rw [h4]
          exact this)
        omega
      · by_cases hbig : 1024 ≤ e
        · have := hm1 (by omega)
          omega
        · have hup := zpow_le_zpow (b := (2 : Rat)) (by decide) (show e + 1 ≤ 1023 by omega)
          have := (threshold_bounds).1
          have := Rat.mul_lt_mul_of_pos_right ht2 hspos
          grind
    rw [htoNat]
    omega
  · have hP : 0 < (2 : Rat) ^ (1023 : Int) := zpow_pos' (by decide) _
    have hroom : e ≤ 1023 := by
      apply Classical.byContradiction
      intro hbig
      have h1 := zpow_le_zpow (b := (2 : Rat)) (by decide) (show 1023 + 1 ≤ e by omega)
      have h2 := Rat.zpow_add_one (q := (2 : Rat)) (by decide) 1023
      have := (threshold_bounds).2
      have hl := Rat.mul_le_mul_of_nonneg_right (hlow (by omega)) (Rat.le_of_lt hspos)
      grind
    have hrawlt : raw < infBits := by
      by_cases h1023 : e = 1023
      · have hT' := threshold_top h1023 r1
        rw [hT'] at hT
        have : t < 9007199254740992 - 1 / 2 := by
          apply Rat.lt_of_mul_lt_mul_right _ (Rat.le_of_lt hspos)
          grind
        have : m < 9007199254740992 := by
          have : (m : Rat) < 9007199254740992 := by grind
          exact_mod_cast this
        omega
      · omega
    have hmin : min raw infBits = raw := by omega
    have hdec : decode (nearestBits q) = some ((if q < 0 then -1 else 1) * ((m : Rat) * s)) := by
      rw [hnb, hmin, ← hV]
      by_cases hneg : q < 0
      · rw [hsg1 hneg, decode_neg _ hrawlt]
        simp only [hneg, ite_true]
        grind
      · rw [hsg2 hneg, Nat.zero_add, decode_pos _ hrawlt]
        simp [hneg]
    refine ⟨_, hdec, fun b w hw => ?_⟩
    obtain ⟨σ, hσ⟩ : ∃ σ : Rat, σ = if q < 0 then -1 else 1 := ⟨_, rfl⟩
    rw [← hσ]
    have hσc : σ = 1 ∨ σ = -1 := by
      by_cases h : q < 0
      · exact Or.inr (by rw [hσ, ite_eq_left h])
      · exact Or.inl (by rw [hσ, ite_eq_right h])
    have hσa : σ * a = q := by
      by_cases hneg : q < 0
      · rw [hσ, ite_eq_left hneg, ha, ite_eq_left hneg]
        grind
      · rw [hσ, ite_eq_right hneg, ha, ite_eq_right hneg]
        grind
    unfold decode at hw
    simp only [] at hw
    by_cases hfin : infBits ≤ b.toNat % 2 ^ 63
    · rw [ite_eq_left hfin] at hw
      exact absurd hw (by simp)
    · rw [ite_eq_right hfin] at hw
      obtain ⟨τ, hτ⟩ : ∃ τ : Rat, τ = if 2 ^ 63 ≤ b.toNat then -1 else 1 := ⟨_, rfl⟩
      have hτc : τ = 1 ∨ τ = -1 := by
        by_cases h : 2 ^ 63 ≤ b.toNat
        · exact Or.inr (by rw [hτ, ite_eq_left h])
        · exact Or.inl (by rw [hτ, ite_eq_right h])
      have hwM : w = τ * magValue (b.toNat % 2 ^ 63) := by
        have hw' := Option.some.inj hw
        rw [← hw', hτ]
        by_cases h : 2 ^ 63 ≤ b.toNat
        · rw [ite_eq_left h, ite_eq_left h]
          grind
        · rw [ite_eq_right h, ite_eq_right h]
          grind
      have hml := mag_level (mag' := b.toNat % 2 ^ 63) he1 hspos hs hts ht0 hlow hm
      have hev : m % 2 = 0 → (nearestBits q).toNat % 2 = 0 := fun h => by
        rw [htoNat, hmin]
        omega
      have sn := signed_nearest (σ := σ) (τ := τ) (V := (m : Rat) * s)
        (M := magValue (b.toNat % 2 ^ 63)) (P := (nearestBits q).toNat % 2 = 0) hapos
        (magValue_nonneg _) hσc hτc hml.1 (fun h1 h2 => hev (hml.2 h1 h2))
      rw [hσa] at sn
      rw [hwM]
      exact sn

end Engine.Exact
