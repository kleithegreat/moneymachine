/-! Study 1's owed statements: the sequential sign test's rule (L6.1, L6.4, L6.5, L6.6) and the pair rule (L2.8, L2.10).
Whole-number arithmetic throughout; nothing here rounds. -/

namespace Ref.Study1

/-! ### The sequential rule -/

/-- The rule's upper boundary, in whole numbers: `7^wins × 3^losses ≥ 19 × 5^(wins + losses)`. -/
def claim (w l : Nat) : Prop := 19 * 5 ^ (w + l) ≤ 7 ^ w * 3 ^ l

/-- The rule's lower boundary: `19 × 7^wins × 3^losses ≤ 5^(wins + losses)`. -/
def futility (w l : Nat) : Prop := 19 * (7 ^ w * 3 ^ l) ≤ 5 ^ (w + l)

instance (w l : Nat) : Decidable (claim w l) := inferInstanceAs (Decidable (_ ≤ _))
instance (w l : Nat) : Decidable (futility w l) := inferInstanceAs (Decidable (_ ≤ _))

/-- L6.1 (Lean): neither boundary is ever an equality, for every count, so no state sits on one. -/
theorem claim_ne (w l : Nat) : 19 * 5 ^ (w + l) ≠ 7 ^ w * 3 ^ l := by
  intro h
  rcases Nat.eq_zero_or_pos (w + l) with h0 | hpos
  · have hw : w = 0 := by omega
    have hl : l = 0 := by omega
    subst hw; subst hl; simp at h
  · have h5 : 5 ∣ 7 ^ w * 3 ^ l := by
      rw [← h]
      obtain ⟨k, hk⟩ : ∃ k, w + l = k + 1 := ⟨w + l - 1, by omega⟩
      rw [hk, Nat.pow_succ]
      exact Nat.dvd_trans (Nat.dvd_mul_left 5 (5 ^ k)) (Nat.dvd_mul_left _ 19)
    have hc7 : Nat.Coprime 5 (7 ^ w) := Nat.Coprime.pow_right _ (by decide)
    have hc3 : Nat.Coprime 5 (3 ^ l) := Nat.Coprime.pow_right _ (by decide)
    have hc := Nat.Coprime.mul_right hc7 hc3
    have := Nat.Coprime.eq_one_of_dvd hc h5
    omega

theorem futility_ne (w l : Nat) : 19 * (7 ^ w * 3 ^ l) ≠ 5 ^ (w + l) := by
  intro h
  have h19 : 19 ∣ 5 ^ (w + l) := ⟨_, h.symm⟩
  have hc : Nat.Coprime 19 (5 ^ (w + l)) := Nat.Coprime.pow_right _ (by decide)
  have := Nat.Coprime.eq_one_of_dvd hc h19
  omega

theorem claim_drop_loss {w l : Nat} (h : claim w (l + 1)) : claim w l := by
  unfold claim at *
  have e1 : w + (l + 1) = (w + l) + 1 := by omega
  have e2 : 7 ^ w * 3 ^ (l + 1) = 3 * (7 ^ w * 3 ^ l) := by
    rw [Nat.pow_succ, Nat.mul_comm (3 ^ l) 3, Nat.mul_left_comm]
  have e3 : 5 ^ ((w + l) + 1) = 5 ^ (w + l) * 5 := Nat.pow_succ 5 (w + l)
  rw [e1, e2, e3] at h
  omega

theorem claim_add_win {w l : Nat} (h : claim w l) : claim (w + 1) l := by
  unfold claim at *
  have e1 : w + 1 + l = (w + l) + 1 := by omega
  have e2 : 7 ^ (w + 1) * 3 ^ l = 7 * (7 ^ w * 3 ^ l) := by
    rw [Nat.pow_succ, Nat.mul_comm (7 ^ w) 7, Nat.mul_assoc]
  have e3 : 5 ^ ((w + l) + 1) = 5 ^ (w + l) * 5 := Nat.pow_succ 5 (w + l)
  rw [e1, e2, e3]
  omega

theorem futility_add_loss {w l : Nat} (h : futility w l) : futility w (l + 1) := by
  unfold futility at *
  have e1 : w + (l + 1) = (w + l) + 1 := by omega
  have e2 : 7 ^ w * 3 ^ (l + 1) = 3 * (7 ^ w * 3 ^ l) := by
    rw [Nat.pow_succ, Nat.mul_comm (3 ^ l) 3, Nat.mul_left_comm]
  have e3 : 5 ^ ((w + l) + 1) = 5 ^ (w + l) * 5 := Nat.pow_succ 5 (w + l)
  rw [e1, e2, e3]
  omega

theorem futility_drop_win {w l : Nat} (h : futility (w + 1) l) : futility w l := by
  unfold futility at *
  have e1 : w + 1 + l = (w + l) + 1 := by omega
  have e2 : 7 ^ (w + 1) * 3 ^ l = 7 * (7 ^ w * 3 ^ l) := by
    rw [Nat.pow_succ, Nat.mul_comm (7 ^ w) 7, Nat.mul_assoc]
  have e3 : 5 ^ ((w + l) + 1) = 5 ^ (w + l) * 5 := Nat.pow_succ 5 (w + l)
  rw [e1, e2, e3] at h
  omega

theorem claim_add_wins {w l : Nat} (a : Nat) (h : claim w l) : claim (w + a) l := by
  induction a with
  | zero => simpa using h
  | succ a ih => exact claim_add_win ih

theorem claim_drop_losses {w l : Nat} (b : Nat) (h : claim w (l + b)) : claim w l := by
  induction b generalizing l with
  | zero => simpa using h
  | succ b ih =>
    apply claim_drop_loss
    apply ih
    have : l + 1 + b = l + (b + 1) := by omega
    rw [this]
    exact h

theorem futility_add_losses {w l : Nat} (b : Nat) (h : futility w l) : futility w (l + b) := by
  induction b with
  | zero => simpa using h
  | succ b ih => exact futility_add_loss ih

theorem futility_drop_wins {w l : Nat} (a : Nat) (h : futility (w + a) l) : futility w l := by
  induction a generalizing w with
  | zero => simpa using h
  | succ a ih =>
    apply futility_drop_win
    apply ih
    have : w + 1 + a = w + (a + 1) := by omega
    rw [this]
    exact h

/-- More wins and fewer losses never leave `claim`. -/
theorem claim_mono {w l w' l' : Nat} (h : claim w l) (hw : w ≤ w') (hl : l' ≤ l) : claim w' l' := by
  obtain ⟨a, rfl⟩ := Nat.exists_eq_add_of_le hw
  obtain ⟨b, rfl⟩ := Nat.exists_eq_add_of_le hl
  exact claim_add_wins a (claim_drop_losses b h)

/-- Fewer wins and more losses never leave `futility`. -/
theorem futility_mono {w l w' l' : Nat} (h : futility w' l') (hw : w ≤ w') (hl : l' ≤ l) : futility w l := by
  obtain ⟨a, rfl⟩ := Nat.exists_eq_add_of_le hw
  obtain ⟨b, rfl⟩ := Nat.exists_eq_add_of_le hl
  exact futility_add_losses b (futility_drop_wins a h)

/-! ### Sequences of markets -/

/-- A market's outcome for the agent against the searcher; a concordant market moves neither count. -/
inductive Out where
  | loss
  | conc
  | win

/-- Loss below concordant below win. -/
def Out.rank : Out → Nat
  | .loss => 0
  | .conc => 1
  | .win => 2

def Out.dw : Out → Nat
  | .win => 1
  | _ => 0

def Out.dl : Out → Nat
  | .loss => 1
  | _ => 0

/-- `o'` is at least as good as `o`. -/
def Better (o o' : Out) : Prop := o.rank ≤ o'.rank

theorem Better.dw {o o' : Out} (h : Better o o') : o.dw ≤ o'.dw := by
  cases o <;> cases o' <;> simp_all [Better, Out.rank, Out.dw]

theorem Better.dl {o o' : Out} (h : Better o o') : o'.dl ≤ o.dl := by
  cases o <;> cases o' <;> simp_all [Better, Out.rank, Out.dl]

/-- Two sequences of equal length, the second at least as good at every market. -/
inductive Pointwise : List Out → List Out → Prop where
  | nil : Pointwise [] []
  | cons {o o' : Out} {os os' : List Out} : Better o o' → Pointwise os os' → Pointwise (o :: os) (o' :: os')

/-- Whether the sequence's first non-`continue` decision, read from the counts `(w, l)`, is `claim`. -/
def claimsFrom : Nat → Nat → List Out → Bool
  | _, _, [] => false
  | w, l, o :: os =>
    if claim (w + o.dw) (l + o.dl) then true
    else if futility (w + o.dw) (l + o.dl) then false
    else claimsFrom (w + o.dw) (l + o.dl) os

def claims (xs : List Out) : Bool := claimsFrom 0 0 xs

/-- L6.4 (Lean), dominance: replace outcomes of a sequence that claims by better ones, and it still claims. -/
theorem dominance_from {ys xs : List Out} (hb : Pointwise ys xs) :
    ∀ {w l w' l' : Nat}, w ≤ w' → l' ≤ l → claimsFrom w l ys = true → claimsFrom w' l' xs = true := by
  induction hb with
  | nil => intro w l w' l' _ _ h; simp [claimsFrom] at h
  | @cons o o' os os' ho _ ih =>
    intro w l w' l' hw hl h
    have hw' : w + o.dw ≤ w' + o'.dw := Nat.add_le_add hw ho.dw
    have hl' : l' + o'.dl ≤ l + o.dl := Nat.add_le_add hl ho.dl
    simp only [claimsFrom] at h ⊢
    by_cases hc : claim (w + o.dw) (l + o.dl)
    · simp [claim_mono hc hw' hl']
    · by_cases hf : futility (w + o.dw) (l + o.dl)
      · simp [hc, hf] at h
      · have hf' : ¬ futility (w' + o'.dw) (l' + o'.dl) := fun hf' => hf (futility_mono hf' hw' hl')
        simp only [hc, hf, ite_false] at h
        by_cases hc' : claim (w' + o'.dw) (l' + o'.dl)
        · simp [hc']
        · simp only [hc', hf', ite_false]
          exact ih hw' hl' h

theorem dominance {ys xs : List Out} (hb : Pointwise ys xs) (h : claims ys = true) :
    claims xs = true :=
  dominance_from hb (Nat.le_refl 0) (Nat.le_refl 0) h

/-- `Drops xs ys`: `ys` is `xs` with some concordant markets removed. -/
inductive Drops : List Out → List Out → Prop where
  | nil : Drops [] []
  | keep (o : Out) {xs ys : List Out} : Drops xs ys → Drops (o :: xs) (o :: ys)
  | drop {xs ys : List Out} : Drops xs ys → Drops (Out.conc :: xs) ys

theorem remove_from {xs ys : List Out} (hd : Drops xs ys) :
    ∀ {w l : Nat}, ¬ claim w l → ¬ futility w l → claimsFrom w l xs = true → claimsFrom w l ys = true := by
  induction hd with
  | nil => intro w l _ _ h; simp [claimsFrom] at h
  | keep o _ ih =>
    intro w l hc hf h
    simp only [claimsFrom] at h ⊢
    by_cases hc' : claim (w + o.dw) (l + o.dl)
    · simp [hc']
    · by_cases hf' : futility (w + o.dw) (l + o.dl)
      · simp [hc', hf'] at h
      · simp only [hc', hf', ite_false] at h ⊢
        exact ih hc' hf' h
  | drop _ ih =>
    intro w l hc hf h
    simp only [claimsFrom, Out.dw, Out.dl, Nat.add_zero, hc, hf, ite_false] at h
    exact ih hc hf h

theorem not_claim_zero : ¬ claim 0 0 := by decide
theorem not_futility_zero : ¬ futility 0 0 := by decide

/-- L6.5 (Lean): remove any concordant markets from a sequence that claims, and it still claims. -/
theorem remove_concordant {xs ys : List Out} (hd : Drops xs ys) (h : claims xs = true) : claims ys = true :=
  remove_from hd not_claim_zero not_futility_zero h

/-! ### The size under a fair coin -/

/-- Every sequence of `n` markets that is a win or a loss. -/
def allSeqs : Nat → List (List Out)
  | 0 => [[]]
  | n + 1 => (allSeqs n).map (Out.win :: ·) ++ (allSeqs n).map (Out.loss :: ·)

theorem length_allSeqs (n : Nat) : (allSeqs n).length = 2 ^ n := by
  induction n with
  | zero => rfl
  | succ n ih =>
    simp only [allSeqs, List.length_append, List.length_map, ih, Nat.pow_succ]
    omega

/-- How many of the `2^n` sequences of `n` further wins and losses claim, from counts `(w, l)`: the recursion on the first market. -/
def cnt : Nat → Nat → Nat → Nat
  | 0, _, _ => 0
  | n + 1, w, l =>
    (if claim (w + 1) l then 2 ^ n else if futility (w + 1) l then 0 else cnt n (w + 1) l)
      + (if claim w (l + 1) then 2 ^ n else if futility w (l + 1) then 0 else cnt n w (l + 1))

theorem cnt_eq (n : Nat) : ∀ w l, cnt n w l = (allSeqs n).countP (claimsFrom w l) := by
  induction n with
  | zero => intro w l; simp [cnt, allSeqs, claimsFrom]
  | succ n ih =>
    intro w l
    simp only [cnt, allSeqs, List.countP_append, List.countP_map]
    have hwin : (allSeqs n).countP (claimsFrom w l ∘ (Out.win :: ·)) = 
        if claim (w + 1) l then 2 ^ n else if futility (w + 1) l then 0 else cnt n (w + 1) l := by
      by_cases hc : claim (w + 1) l
      · simp [Function.comp_def, claimsFrom, Out.dw, Out.dl, hc, List.countP_true, length_allSeqs]
      · by_cases hf : futility (w + 1) l
        · simp [Function.comp_def, claimsFrom, Out.dw, Out.dl, hc, hf]
        · simp only [Function.comp_def, claimsFrom, Out.dw, Out.dl, Nat.add_zero, hc, hf, ite_false, ih]
    have hloss : (allSeqs n).countP (claimsFrom w l ∘ (Out.loss :: ·)) = 
        if claim w (l + 1) then 2 ^ n else if futility w (l + 1) then 0 else cnt n w (l + 1) := by
      by_cases hc : claim w (l + 1)
      · simp [Function.comp_def, claimsFrom, Out.dw, Out.dl, hc, List.countP_true, length_allSeqs]
      · by_cases hf : futility w (l + 1)
        · simp [Function.comp_def, claimsFrom, Out.dw, Out.dl, hc, hf]
        · simp only [Function.comp_def, claimsFrom, Out.dw, Out.dl, Nat.add_zero, hc, hf, ite_false, ih]
    rw [hwin, hloss]

/-- The same counts as `cnt`, one layer for all win counts `w ≤ k` at once (the losses are `k - w`), so that the kernel evaluates 100 markets
in whole numbers without the recursion's repeated states. -/
def layer : Nat → Nat → List Nat
  | 0, k => List.replicate (k + 1) 0
  | n + 1, k =>
    let t := layer n (k + 1)
    (List.range (k + 1)).map fun w =>
      (if claim (w + 1) (k - w) then 2 ^ n else if futility (w + 1) (k - w) then 0 else t.getD (w + 1) 0)
        + (if claim w (k - w + 1) then 2 ^ n else if futility w (k - w + 1) then 0 else t.getD w 0)

theorem layer_eq (n : Nat) : ∀ k w, w ≤ k → (layer n k).getD w 0 = cnt n w (k - w) := by
  induction n with
  | zero => intro k w hw; simp [layer, cnt, List.getD_eq_getElem?_getD, show w < k + 1 by omega]
  | succ n ih =>
    intro k w hw
    have h1 := ih (k + 1) (w + 1) (by omega)
    have h2 := ih (k + 1) w (by omega)
    have e1 : k + 1 - (w + 1) = k - w := by omega
    have e2 : k + 1 - w = k - w + 1 := by omega
    rw [e1] at h1
    rw [e2] at h2
    simp only [layer, cnt, List.getD_eq_getElem?_getD, List.getElem?_map, List.getElem?_range (show w < k + 1 by omega),
      Option.map_some, Option.getD_some]
    rw [← List.getD_eq_getElem?_getD, ← List.getD_eq_getElem?_getD, h1, h2]

/-- The number of the `2^100` sequences of 100 wins and losses that claim. -/
def claimCount : Nat := (layer 100 0).getD 0 0

theorem claimCount_eq : claimCount = (allSeqs 100).countP claims := by
  have := layer_eq 100 0 0 (Nat.le_refl 0)
  rw [cnt_eq] at this
  exact this

/-- L6.6 (Lean): when each of 100 markets is a win or a loss with chance one half (the `2^100` sequences equally likely), the chance of
`claim` is below 431/10000, which is 0.0431. -/
theorem size_below : claimCount * 10000 < 431 * 2 ^ 100 := by decide +kernel

/-- The exact worst-null size is 0.0430787: the count lies strictly between 0.04307 and 0.04308 of `2^100`. -/
theorem size_value : 4307 * 2 ^ 100 < claimCount * 100000 ∧ claimCount * 100000 < 4308 * 2 ^ 100 := by decide +kernel

/-- L6.6 as a chance over the explicit sample space. -/
theorem size_chance : (allSeqs 100).countP claims * 10000 < 431 * (allSeqs 100).length := by
  rw [← claimCount_eq, length_allSeqs]
  exact size_below

/-! ### The pair rule -/

/-- The rule's constants. -/
def PAIRS : Nat := 57
def MAJORITY : Nat := 39

/-- A program wins a pair when its effect and the reference's are both defined, the reference's is positive and the program's is at
least `SHARE = 1/2` times it. Effects are integers in one common unit (the comparison is scale-free, so a unit of `2^-14` makes the
study's scores integers). -/
def wonPair : Option Int → Option Int → Bool
  | some e, some r => decide (0 < r ∧ r ≤ 2 * e)
  | _, _ => false

def wonCount (es rs : List (Option Int)) : Nat := (List.zipWith wonPair es rs).countP id

/-- The exact negation: every defined effect negated. -/
def negate (es : List (Option Int)) : List (Option Int) := es.map (Option.map (- ·))

/-- L2.8 (Lean), first half: a pick and its exact negation never win the same pair. -/
theorem not_both_won (e r : Option Int) : ¬ (wonPair e r = true ∧ wonPair (Option.map (- ·) e) r = true) := by
  cases e <;> cases r <;> simp only [wonPair, Option.map, decide_eq_true_eq, Bool.false_eq_true, and_false, not_false_eq_true]
  rename_i e r
  omega

theorem wonCount_add_negate (es rs : List (Option Int)) : wonCount es rs + wonCount (negate es) rs ≤ rs.length := by
  induction rs generalizing es with
  | nil => cases es <;> simp [wonCount, negate]
  | cons r rs ih =>
    cases es with
    | nil => simp [wonCount, negate]
    | cons e es =>
      have h := ih es
      have hn := not_both_won e r
      unfold wonCount negate at *
      simp only [List.map_cons, List.zipWith_cons_cons, List.countP_cons, List.length_cons] at *
      by_cases h1 : wonPair e r = true
      · have : wonPair (Option.map (- ·) e) r = false := by
          cases h2 : wonPair (Option.map (- ·) e) r
          · rfl
          · exact absurd ⟨h1, h2⟩ hn
        simp [h1, this]
        omega
      · simp only [h1]
        by_cases h2 : wonPair (Option.map (- ·) e) r = true <;> simp [h2] <;> omega

/-- L2.8 (Lean), second half: with `PAIRS` pairs the two counts sum to at most `PAIRS`, and the two never both reach `MAJORITY`, because
`2 × MAJORITY > PAIRS`. -/
theorem negation_never_both_earn (es rs : List (Option Int)) (hr : rs.length = PAIRS) :
    wonCount es rs + wonCount (negate es) rs ≤ PAIRS ∧ ¬ (MAJORITY ≤ wonCount es rs ∧ MAJORITY ≤ wonCount (negate es) rs) := by
  have h := wonCount_add_negate es rs
  rw [hr] at h
  refine ⟨h, ?_⟩
  unfold MAJORITY PAIRS at *
  omega

/-- Row `n` of Pascal's triangle. -/
def pascal : Nat → List Nat
  | 0 => [1]
  | n + 1 => List.zipWith (· + ·) (0 :: pascal n) (pascal n ++ [0])

/-- The row is the binomial row: it has `n + 1` entries summing to `2^n`. -/
theorem pascal_57_sound : (pascal 57).length = 58 ∧ (pascal 57).sum = 2 ^ 57 := by decide +kernel

/-- L2.10 (Lean): the sum of `C(57, k)` for `k` from 39 to 57 is at most `2^57 / 200`, so the chance of at least `MAJORITY` wins in
`PAIRS` fair trials is at most 0.005. -/
theorem rule_bound : ((pascal 57).drop 39).sum * 200 ≤ 2 ^ 57 := by decide +kernel

end Ref.Study1
