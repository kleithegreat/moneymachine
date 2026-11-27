import Engine.LogSteps

/-!
# A18's order of the wishes that arrive (brief 3 step 5; R1)

`wishLe` is a total preorder, `insertWish` and `orderWishes` sort by it and keep the wishes they are given.
-/

namespace Engine.Machine

open Engine.Orders (Wish)

theorem wishLe_total (a b : Wish) : wishLe a b = true ∨ wishLe b a = true := by
  unfold wishLe
  simp only [Bool.or_eq_true, Bool.and_eq_true, decide_eq_true_eq]
  omega

theorem wishLe_trans (a b c : Wish) (h1 : wishLe a b = true) (h2 : wishLe b c = true) : wishLe a c = true := by
  unfold wishLe at *
  simp only [Bool.or_eq_true, Bool.and_eq_true, decide_eq_true_eq] at *
  omega

theorem wishLe_refl (a : Wish) : wishLe a a = true := by
  unfold wishLe
  simp

theorem insertWish_sorted (w : Wish) : ∀ l : List Wish, l.Pairwise (fun a b => wishLe a b = true) →
    (insertWish w l).Pairwise (fun a b => wishLe a b = true) := by
  intro l
  induction l with
  | nil => intro _; simp [insertWish]
  | cons v l ih =>
    intro h
    obtain ⟨hv, hl⟩ := List.pairwise_cons.1 h
    unfold insertWish
    by_cases hw : wishLe w v = true
    · simp only [hw, ↓reduceIte]
      refine List.pairwise_cons.2 ⟨?_, h⟩
      intro x hx
      rcases List.mem_cons.1 hx with rfl | hx
      · exact hw
      · exact wishLe_trans _ _ _ hw (hv x hx)
    · simp only [hw, Bool.false_eq_true, ↓reduceIte]
      have hvw : wishLe v w = true := by
        rcases wishLe_total w v with h | h
        · exact absurd h hw
        · exact h
      refine List.pairwise_cons.2 ⟨?_, ih hl⟩
      intro x hx
      have hx' : x = w ∨ x ∈ l := by
        have : x ∈ insertWish w l := hx
        have hm : ∀ (w : Wish) (l : List Wish) (x : Wish), x ∈ insertWish w l ↔ x = w ∨ x ∈ l := by
          intro w l x
          induction l with
          | nil => simp [insertWish]
          | cons v l ih =>
            unfold insertWish
            split
            · simp
            · simp only [List.mem_cons, ih]
              exact or_left_comm
        exact (hm w l x).1 this
      rcases hx' with rfl | hx'
      · exact hvw
      · exact hv x hx'

theorem orderWishes_sorted (l : List Wish) : (orderWishes l).Pairwise (fun a b => wishLe a b = true) := by
  unfold orderWishes
  induction l with
  | nil => simp
  | cons w l ih => exact insertWish_sorted w _ ih

theorem insertWish_perm (w : Wish) : ∀ l : List Wish, (insertWish w l).Perm (w :: l) := by
  intro l
  induction l with
  | nil => exact List.Perm.refl _
  | cons v l ih =>
    unfold insertWish
    split
    · exact List.Perm.refl _
    · exact ((List.Perm.cons v ih).trans (List.Perm.swap w v l))

theorem orderWishes_perm (l : List Wish) : (orderWishes l).Perm l := by
  unfold orderWishes
  induction l with
  | nil => exact List.Perm.refl _
  | cons w l ih => exact (insertWish_perm w _).trans (List.Perm.cons w ih)

end Engine.Machine
