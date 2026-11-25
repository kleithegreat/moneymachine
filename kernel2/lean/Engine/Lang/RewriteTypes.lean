import Engine.Lang.Syntax

/-!
# What the rewrite rules do to a node's type (B3, L3)
-/

namespace Engine.Lang

theorem sameDim_swap (a b : Dim) : (numOf (sameDim a b)).toOption = (numOf (sameDim b a)).toOption := by
  by_cases h : a = b
  · subst h; rfl
  · have h' : ¬ b = a := fun h' => h h'.symm
    simp [numOf, sameDim, h, h', Except.map, Except.toOption]

theorem Dim.mul_comm' (a b : Dim) : Dim.mul a b = Dim.mul b a := by
  unfold Dim.mul Dim.zip
  have h1 : List.zipWith (· + ·) a.e b.e = List.zipWith (· + ·) b.e a.e := by
    rw [List.zipWith_comm]
    congr 1
    funext x y
    exact Int.add_comm y x
  rw [h1]
  by_cases h : a.e.length = b.e.length
  · simp [h]
  · have : ¬ b.e.length = a.e.length := fun h' => h h'.symm
    simp [h, this]

theorem opTy_add_swap (x y : Ty) : opTy .add [x, y] = opTy .add [y, x] := by
  cases x <;> cases y <;> simp [opTy, opTyE, Except.toOption, bind, Except.bind]
  all_goals first | exact sameDim_swap _ _ | skip

theorem opTy_mul_swap (x y : Ty) : opTy .mul [x, y] = opTy .mul [y, x] := by
  cases x <;> cases y <;> simp [opTy, opTyE, Except.toOption, bind, Except.bind]
  rename_i u v
  rw [Dim.mul_comm' u v]

theorem opTy_and_swap (x y : Ty) : opTy .and [x, y] = opTy .and [y, x] := by
  cases x <;> cases y <;> simp [opTy, opTyE, Except.toOption, bind, Except.bind]

theorem opTy_or_swap (x y : Ty) : opTy .or [x, y] = opTy .or [y, x] := by
  cases x <;> cases y <;> simp [opTy, opTyE, Except.toOption, bind, Except.bind]

theorem opTy_cmp {o o' : Op}
    (hs : (o = .gt ∧ o' = .lt) ∨ (o = .lt ∧ o' = .gt) ∨ (o = .ge ∧ o' = .le) ∨ (o = .le ∧ o' = .ge)) (x y : Ty) :
    opTy o' [y, x] = opTy o [x, y] := by
  rcases hs with ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ <;>
  · cases x <;> cases y <;>
      simp [opTy, opTyE, Except.map, Except.toOption, bind, Except.bind, pure, Except.pure, boolOf, sameDim] <;>
      (rename_i u v; by_cases h : u = v <;> simp [h, Ne.symm])

theorem opTy_unary_num {o : Op} (ho : o = .neg ∨ o = .abs) {s t : Ty} (h : opTy o [s] = some t) :
    t = s ∧ ∃ u, s = .num u := by
  rcases ho with rfl | rfl <;>
  · cases s <;> simp [opTy, opTyE, numOf, Except.map, Except.toOption] at h ⊢ <;>
      exact h.symm

theorem opTy_not_inv {s t : Ty} (h : opTy .not [s] = some t) : s = .bool ∧ t = .bool := by
  cases s <;> simp [opTy, opTyE, boolOf, Except.map, Except.toOption] at h ⊢ <;>
    exact h.symm

theorem zipWith_zero7 (e : List Int) (hl : e.length = 7) :
    List.zipWith (· + ·) e [0, 0, 0, 0, 0, 0, 0] = e := by
  rcases e with _ | ⟨a, _ | ⟨b, _ | ⟨c, _ | ⟨d, _ | ⟨f, _ | ⟨g, _ | ⟨k, _ | ⟨z, rest⟩⟩⟩⟩⟩⟩⟩⟩ <;> simp_all

theorem zipWith_sub_zero7 (e : List Int) (hl : e.length = 7) :
    List.zipWith (· - ·) e [0, 0, 0, 0, 0, 0, 0] = e := by
  rcases e with _ | ⟨a, _ | ⟨b, _ | ⟨c, _ | ⟨d, _ | ⟨f, _ | ⟨g, _ | ⟨k, _ | ⟨z, rest⟩⟩⟩⟩⟩⟩⟩⟩ <;> simp_all

theorem ite_some_inv (c : Bool) (a w : Dim) (h : (if c = true then some a else none) = some w) :
    c = true ∧ a = w := by
  cases hc : c <;> simp [hc] at h ⊢
  exact h

theorem Dim.mul_one_eq {u w : Dim} (h : Dim.mul u Dim.one = some w) : w = u := by
  unfold Dim.mul Dim.zip at h
  obtain ⟨e⟩ := u
  simp only [Dim.one] at h
  obtain ⟨hc, h⟩ := ite_some_inv _ _ _ h
  simp only [Bool.and_eq_true, beq_iff_eq] at hc
  subst h
  have := zipWith_zero7 e (by simpa using hc.1)
  simp [this]

theorem Dim.div_one_eq {u w : Dim} (h : Dim.div u Dim.one = some w) : w = u := by
  unfold Dim.div Dim.zip at h
  obtain ⟨e⟩ := u
  simp only [Dim.one] at h
  obtain ⟨hc, h⟩ := ite_some_inv _ _ _ h
  simp only [Bool.and_eq_true, beq_iff_eq] at hc
  subst h
  have := zipWith_sub_zero7 e (by simpa using hc.1)
  simp [this]

theorem opTy_mul_one {s t : Ty} (h : opTy .mul [s, .num Dim.one] = some t) : t = s ∧ ∃ u, s = .num u := by
  cases s <;> simp [opTy, opTyE, numOf, Except.map, Except.toOption, bind, Except.bind] at h ⊢
  rename_i u
  cases hm : Dim.mul u Dim.one with
  | none => simp [hm] at h
  | some w => simp [hm] at h; rw [← h, Dim.mul_one_eq hm]

theorem opTy_div_one {s t : Ty} (h : opTy .div [s, .num Dim.one] = some t) : t = s ∧ ∃ u, s = .num u := by
  cases s <;> simp [opTy, opTyE, numOf, Except.map, Except.toOption, bind, Except.bind] at h ⊢
  rename_i u
  cases hm : Dim.div u Dim.one with
  | none => simp [hm] at h
  | some w => simp [hm] at h; rw [← h, Dim.div_one_eq hm]

theorem opTy_sub_inv {u : Dim} {s2 t : Ty} (h : opTy .sub [.num u, s2] = some t) : t = .num u := by
  cases s2 <;> simp [opTy, opTyE, numOf, sameDim, Except.map, Except.toOption, bind, Except.bind] at h
  rename_i v
  by_cases huv : u = v
  · subst huv; simp at h; exact h.symm
  · simp [huv] at h

theorem opTy_ite_swap (x y : Ty) : opTy .ite [.bool, x, y] = opTy .ite [.bool, y, x] := by
  cases x <;> cases y <;>
    simp [opTy, opTyE, iteTy, Except.toOption, bind, Except.bind]
  all_goals first | exact sameDim_swap _ _ | skip

end Engine.Lang
