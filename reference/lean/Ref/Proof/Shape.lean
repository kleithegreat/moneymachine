import Ref.Proof.Admission

namespace Ref

variable {α : Type} [Inhabited α]

private def roleKind (r : Option (RolePayload α)) : Nat :=
  match r with | none => 0 | some (.bar ..) => 1 | some (.rate _) => 2

private structure Shape where
  source : Nat
  coin : Nat
  key : Int
  slot : Option Int
  known : Int
  count : Nat
  role : Nat
  final : Bool
  retraction : Bool
  recorded : Int
  deriving DecidableEq

private def shape (o : Obs α) : Shape :=
  ⟨o.source, o.coin, o.key, o.slot, o.known, o.vals.size, roleKind o.role, o.final, o.retraction, o.recorded⟩

private theorem shape_eq {a b : Obs α} (h : a.sameShape b = true) : shape a = shape b := by
  dsimp only [Obs.sameShape] at h
  simp only [Bool.and_eq_true, beq_iff_eq] at h
  rcases h with ⟨⟨⟨⟨⟨⟨⟨⟨⟨hs, hc⟩, hk⟩, hl⟩, hn⟩, hv⟩, hr⟩, hf⟩, ht⟩, hd⟩
  simp only [shape, Shape.mk.injEq]
  exact ⟨hs, hc, hk, hl, hn, hv, hr, hf, ht, hd⟩

private theorem shape_map {a b : Array (Obs α)} (hlen : a.size = b.size)
    (h : ∀ i < a.size, (a[i]!).sameShape b[i]! = true) : a.toList.map shape = b.toList.map shape := by
  apply List.ext_getElem
  · simpa using hlen
  · intro i hi hj
    simp only [List.getElem_map, Array.getElem_toList]
    apply shape_eq
    simpa only [getElem!_pos, show i < a.size from by simpa using hi,
      show i < b.size from by simpa using hj] using h i (by simpa using hi)

private theorem map_shape_congr {β : Type} {xs ys : List (Obs α)} (h : xs.map shape = ys.map shape)
    (f g : Obs α → β) (hf : ∀ a b, shape a = shape b → f a = g b) : xs.map f = ys.map g := by
  induction xs generalizing ys with
  | nil => cases ys <;> simp_all
  | cons a xs ih =>
    cases ys with
    | nil => simp_all
    | cons b ys =>
      simp only [List.map_cons, List.cons.injEq] at h ⊢
      exact ⟨hf a b h.1, ih h.2⟩

private theorem filter_shape {xs ys : List (Obs α)} (h : xs.map shape = ys.map shape)
    (f : Obs α → Bool) (hf : ∀ a b, shape a = shape b → f a = f b) :
    (xs.filter f).map shape = (ys.filter f).map shape := by
  induction xs generalizing ys with
  | nil => cases ys <;> simp_all
  | cons a xs ih =>
    cases ys with
    | nil => simp_all
    | cons b ys =>
      simp only [List.map_cons, List.cons.injEq] at h
      simp only [List.filter_cons, hf a b h.1]
      split <;> simp only [List.map_cons, List.cons.injEq, h.1, ih h.2, and_self]

private theorem all_shape_congr {xs ys : List (Obs α)} (h : xs.map shape = ys.map shape)
    (f g : Obs α → Bool) (hf : ∀ a b, shape a = shape b → f a = g b) : xs.all f = ys.all g := by
  simpa only [List.all_map, Function.comp_def, id_eq] using
    congrArg (fun l : List Bool => l.all id) (map_shape_congr h f g hf)

private theorem shape_admissible (reg : Registry) (roles : Roles) (p : Program) (adm : Meta) (v : Venue α)
    (pol : Policy) (stop : Int) (req : List Nat) (a b : Array (Obs α))
    (h : a.toList.map shape = b.toList.map shape) :
    (Ctx.make reg roles p adm a v pol stop req).admissible =
      (Ctx.make reg roles p adm b v pol stop req).admissible := by
  have ho : ((a.filter ((adm.delivered reg).contains ·.source)).toList).map shape =
      ((b.filter ((adm.delivered reg).contains ·.source)).toList).map shape := by
    simp only [Array.toList_filter]
    exact filter_shape h _ fun x y hxy => by rw [show x.source = y.source from congrArg Shape.source hxy]
  have hk := map_shape_congr (filter_shape ho (·.final) fun x y hxy => congrArg Shape.final hxy)
    (fun o => (o.source, o.coin, o.key)) (fun o => (o.source, o.coin, o.key)) fun x y hxy => by
      rw [show x.source = y.source from congrArg Shape.source hxy,
        show x.coin = y.coin from congrArg Shape.coin hxy, show x.key = y.key from congrArg Shape.key hxy]
  unfold Ctx.admissible
  dsimp only [Ctx.make, Ctx.coins]
  simp only [Array.toList_filter] at hk ⊢
  rw [hk]
  congr 1
  simp only [← Array.all_toList]
  exact all_shape_congr ho _ _ fun x y hxy => by
    have hs := congrArg Shape.source hxy
    have hc := congrArg Shape.coin hxy
    have hn := congrArg Shape.count hxy
    have hr := congrArg Shape.role hxy
    have ht := congrArg Shape.retraction hxy
    have hl := congrArg Shape.slot hxy
    dsimp [shape] at hs hc hn hr ht hl
    cases hx : x.role with
    | none =>
      cases hy : y.role with
      | none => simp_all [roleKind]; rfl
      | some ry => cases ry <;> simp_all [roleKind] <;> rfl
    | some rx =>
      cases rx <;> cases hy : y.role with
      | none => simp_all [roleKind]
      | some ry => cases ry <;> simp_all [roleKind] <;> rfl

private theorem shape_scope (reg : Registry) (roles : Roles) (p : Program) (adm : Meta) (v : Venue α)
    (pol : Policy) (stop : Int) (req : List Nat) (a b : Array (Obs α))
    (h : a.toList.map shape = b.toList.map shape) :
    (Ctx.make reg roles p adm a v pol stop req).inScope =
      (Ctx.make reg roles p adm b v pol stop req).inScope := by
  have ho : ((a.filter ((adm.delivered reg).contains ·.source)).toList).map shape =
      ((b.filter ((adm.delivered reg).contains ·.source)).toList).map shape := by
    simp only [Array.toList_filter]
    exact filter_shape h _ fun x y hxy => by rw [show x.source = y.source from congrArg Shape.source hxy]
  have hr (x y : Obs α) (hxy : shape x = shape y) :
      (Ctx.make reg roles p adm a v pol stop req).readFrom x =
        (Ctx.make reg roles p adm b v pol stop req).readFrom y := by
    have hs := congrArg Shape.source hxy
    have hk := congrArg Shape.key hxy
    have hn := congrArg Shape.known hxy
    have hf := congrArg Shape.final hxy
    have hr := congrArg Shape.role hxy
    dsimp [shape] at hs hk hn hf hr
    unfold Ctx.readFrom
    dsimp only [Ctx.make, Ctx.firstTick, Ctx.lastTick, Ctx.useEnd, Ctx.bounds]
    cases hx : x.role with
    | none =>
      cases hy : y.role with
      | none => simp_all [roleKind]; rfl
      | some ry => cases ry <;> simp_all [roleKind]
    | some rx =>
      cases rx <;> cases hy : y.role with
      | none => simp_all [roleKind]
      | some ry => cases ry <;> simp_all [roleKind] <;> rfl
  unfold Ctx.inScope
  congr 1
  unfold Ctx.accesses
  change List.flatMap _ ((a.filter ((adm.delivered reg).contains ·.source)).toList) =
    List.flatMap _ ((b.filter ((adm.delivered reg).contains ·.source)).toList)
  rw [List.flatMap_def, List.flatMap_def]
  apply congrArg List.flatten
  exact map_shape_congr ho _ _ fun x y hxy => by
    have hs := congrArg Shape.source hxy
    have hc := congrArg Shape.coin hxy
    have hk := congrArg Shape.key hxy
    dsimp [shape] at hs hc hk
    rw [hr x y hxy]
    simp only [Ctx.make, Ctx.useEnd, Ctx.firstTick, hs, hc, hk]

theorem admit_shape (reg : Registry) (roles : Roles) (p : Program) (adm : Meta) (ld₁ ld₂ : Loader α)
    (v : Venue α) (pol : Policy) (stop : Int) (mode : Mode) (hR : ld₁.rows = ld₂.rows)
    (hS : ∀ req, (ld₁.resolve req).isSome = (ld₂.resolve req).isSome ∧ ∀ o₁ o₂, ld₁.resolve req = some o₁ →
      ld₂.resolve req = some o₂ → o₁.size = o₂.size ∧ ∀ i < o₁.size, (o₁[i]!).sameShape o₂[i]! = true) :
    failureOf (admit reg roles p adm ld₁ v pol stop mode) =
      failureOf (admit reg roles p adm ld₂ v pol stop mode) := by
  unfold admit
  rw [hR]
  cases h1 : stage1 reg roles p adm mode <;> simp only [Except.mapError, bind, Except.bind, failureOf]
  rename_i req
  cases h2 : stage2 adm mode (ld₂.rows req) <;> simp only [Except.mapError, Except.bind, failureOf]
  obtain ⟨hv, hs⟩ := hS req
  cases ha : ld₁.resolve req <;> cases hb : ld₂.resolve req
  all_goals simp only [ha, hb, Option.isSome_none, Option.isSome_some] at hv
  all_goals try contradiction
  · rfl
  rename_i a b
  obtain ⟨hlen, hs⟩ := hs a b ha hb
  have hshape := shape_map hlen hs
  dsimp only
  rw [shape_admissible reg roles p adm v pol stop req a b hshape,
    shape_scope reg roles p adm v pol stop req a b hshape]
  cases (Ctx.make reg roles p adm b v pol stop req).admissible <;>
    cases (Ctx.make reg roles p adm b v pol stop req).inScope <;>
    simp [throw, throwThe, MonadExceptOf.throw, pure, Except.pure]

end Ref
