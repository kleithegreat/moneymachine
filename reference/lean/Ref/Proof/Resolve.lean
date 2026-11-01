import Ref.Resolve

namespace Ref

private theorem fold_bounds {β : Type} (xs : List β) (f : Int → β → Except RuleError Int)
    (hf : ∀ k x v, f k x = .ok v → k ≤ v) (k v : Int) (h : xs.foldlM f k = .ok v) : k ≤ v := by
  induction xs generalizing k with
  | nil => cases h; exact Int.le_refl _
  | cons x xs ih =>
    simp only [List.foldlM_cons, bind, Except.bind] at h
    cases hx : f k x with
    | error e => simp only [hx] at h; contradiction
    | ok u => exact Int.le_trans (hf k x u hx) (ih u (by simpa only [hx] using h))

private def revisionStep (d : Decl) (known : Revision → Bool → Option Int → Except RuleError Int)
    (acc : Option Revision × Option Int × List Entry) (r : Revision) : Option Revision × Option Int × List Entry :=
  let (last, prev, out) := acc
  if last.any (fun p => !differs d p r) then (some r, prev, out) else
  let retract (k : Int) := (some r, some k, out ++ [⟨r, k, true⟩])
  match prev with
  | none => if r.tombstone then (some r, none, out) else
    match known r last.isSome none with
    | .ok k => (some r, some k, out ++ [⟨r, k, false⟩])
    | .error _ => (some r, none, out)
  | some p => if r.tombstone then retract (Max.max r.fetchedAt p) else
    match known r true (some p) with
    | .ok k => (some r, some k, out ++ [⟨r, k, false⟩])
    | .error _ => retract (Max.max r.fetchedAt p)

private def Ordered (prev : Option Int) (out : List Entry) : Prop :=
  out.Pairwise (fun a b => a.rev.fetchedAt ≤ b.rev.fetchedAt ∧ a.known ≤ b.known) ∧
  (∀ e ∈ out, ∀ p, prev = some p → e.known ≤ p) ∧ (prev = none → out = [])

private theorem ordered_emit {prev : Option Int} {out : List Entry} (h : Ordered prev out) (r : Revision)
    (k : Int) (ret : Bool) (hf : ∀ e ∈ out, e.rev.fetchedAt ≤ r.fetchedAt)
    (hk : ∀ p, prev = some p → p ≤ k) : Ordered (some k) (out ++ [⟨r, k, ret⟩]) := by
  have hb : ∀ e ∈ out, e.known ≤ k := by
    intro e he
    cases hp : prev with
    | none => have := h.2.2 hp; simp_all
    | some p => exact Int.le_trans (h.2.1 e he p hp) (hk p hp)
  refine ⟨?_, ?_, by simp⟩
  · exact List.pairwise_append.mpr ⟨h.1, by simp, fun e he x hx => by
      simp only [List.mem_singleton] at hx; subst x; exact ⟨hf e he, hb e he⟩⟩
  · intro e he p hp
    cases hp
    rcases List.mem_append.mp he with he | he
    · exact hb e he
    · simp only [List.mem_singleton] at he; subst e; exact Int.le_refl _

private theorem step_ordered (d : Decl) (known : Revision → Bool → Option Int → Except RuleError Int)
    (hk : ∀ r later prev k, known r later prev = .ok k → ∀ p, prev = some p → p ≤ k)
    (acc : Option Revision × Option Int × List Entry) (r : Revision)
    (h : Ordered acc.2.1 acc.2.2) (hf : ∀ e ∈ acc.2.2, e.rev.fetchedAt ≤ r.fetchedAt) :
    Ordered (revisionStep d known acc r).2.1 (revisionStep d known acc r).2.2 := by
  rcases acc with ⟨last, prev, out⟩
  unfold revisionStep
  dsimp only
  split
  · exact h
  cases prev with
  | none =>
    dsimp only
    split
    · exact h
    cases he : known r last.isSome none with
    | ok k =>
      exact ordered_emit h r k false hf (fun p hp => by simp_all)
    | error e => exact h
  | some p =>
    dsimp only
    split
    · exact ordered_emit h r _ true hf (by intro q hq; cases hq; exact Int.le_max_right ..)
    cases he : known r true (some p) with
    | ok k =>
      exact ordered_emit h r k false hf (hk r true (some p) k he)
    | error e => exact ordered_emit h r _ true hf (by intro q hq; cases hq; exact Int.le_max_right ..)

private theorem step_members (d : Decl) (known : Revision → Bool → Option Int → Except RuleError Int)
    (acc : Option Revision × Option Int × List Entry) (r : Revision) (e : Entry)
    (h : e ∈ (revisionStep d known acc r).2.2) : e ∈ acc.2.2 ∨ e.rev = r := by
  rcases acc with ⟨last, prev, out⟩
  unfold revisionStep at h
  dsimp only at h
  repeat' (split at h)
  all_goals simp only [List.mem_append, List.mem_singleton] at h
  all_goals first | exact Or.inl h | rcases h with h | rfl; exact Or.inl h; exact Or.inr rfl

private theorem fold_ordered (d : Decl) (known : Revision → Bool → Option Int → Except RuleError Int)
    (hk : ∀ r later prev k, known r later prev = .ok k → ∀ p, prev = some p → p ≤ k)
    (rs : List Revision) (hs : rs.Pairwise (fun a b => a.fetchedAt ≤ b.fetchedAt))
    (acc : Option Revision × Option Int × List Entry) (hi : Ordered acc.2.1 acc.2.2)
    (hf : ∀ e ∈ acc.2.2, ∀ r ∈ rs, e.rev.fetchedAt ≤ r.fetchedAt) :
    Ordered (rs.foldl (revisionStep d known) acc).2.1 (rs.foldl (revisionStep d known) acc).2.2 := by
  induction rs generalizing acc with
  | nil => exact hi
  | cons r rs ih =>
    obtain ⟨hsr, hsrst⟩ := List.pairwise_cons.mp hs
    apply ih hsrst (revisionStep d known acc r)
    · exact step_ordered d known hk acc r hi (fun e he => hf e he r (by simp))
    · intro e he r' hr'
      rcases step_members d known acc r e he with he | he
      · exact hf e he r' (by simp [hr'])
      · rw [he]; exact hsr r' hr'

theorem timeline_ordered (reg : Registry) (st : Stored) (V : Int) (ok : Nat → Revision → Bool)
    (fuel s : Nat) (entity : String) (event : Int) :
    (timeline reg st V ok fuel s entity event).Pairwise
      (fun a b => a.rev.fetchedAt ≤ b.rev.fetchedAt ∧ a.known ≤ b.known) := by
  cases fuel with
  | zero => simp [timeline]
  | succ fuel =>
    unfold timeline
    extract_lets d upKnown known step
    change (List.foldl (revisionStep d known) (none, none, []) (st.eligible s V entity event)).2.2.Pairwise _
    apply (fold_ordered d known ?_ _ ?_ (none, none, []) ⟨by simp, by simp, by simp⟩ (by simp)).1
    · intro r later prev k he p hp
      subst prev
      dsimp only [known] at he
      simp only [bind, Except.bind, pure, Except.pure, throw, throwThe, MonadExceptOf.throw] at he
      repeat' (split at he <;> try contradiction)
      all_goals
        have hb := fold_bounds _ _ (fun a x v hv => by
          simp only [ranged] at hv
          split at hv <;> try contradiction
          cases hv
          exact Int.le_max_left ..) _ _ he
        exact Int.le_trans (Int.le_max_right ..) hb
    · unfold Stored.eligible
      have hs := List.pairwise_mergeSort (le := fun (a b : Revision) => decide (a.fetchedAt ≤ b.fetchedAt))
        (by intro a b c hab hbc; simp only [decide_eq_true_eq] at *; omega)
        (by intro a b; simp only [Bool.or_eq_true, decide_eq_true_eq]; omega)
        ((st.rows s).filter fun r => r.entity == entity && r.event == event && decide (r.fetchedAt ≤ V))
      simpa only [decide_eq_true_eq] using hs

private structure KnownOut (P : Revision → Int → Prop) (prev : Option Int) (out : List Entry) : Prop where
  empty : prev = none ↔ out = []
  head : ∀ e ∈ out.head?, e.retraction = false
  tail : ∀ e ∈ out.tail, e.rev.fetchedAt ≤ e.known
  values : ∀ e ∈ out, e.retraction = false → P e.rev e.known

private theorem known_emit {P : Revision → Int → Prop} {prev : Option Int} {out : List Entry}
    (h : KnownOut P prev out) (r : Revision) (k : Int) (ret : Bool)
    (hr : out = [] → ret = false) (hb : out ≠ [] → r.fetchedAt ≤ k) (hv : ret = false → P r k) :
    KnownOut P (some k) (out ++ [⟨r, k, ret⟩]) := by
  constructor
  · simp
  · cases out with
    | nil => simpa using hr rfl
    | cons e es => simpa using h.head
  · cases out with
    | nil => simp
    | cons e es =>
      intro x hx
      simp only [List.cons_append, List.tail_cons, List.mem_append, List.mem_singleton] at hx
      rcases hx with hx | rfl
      · exact h.tail x hx
      · exact hb (by simp)
  · intro e he hre
    rcases List.mem_append.mp he with he | he
    · exact h.values e he hre
    · simp only [List.mem_singleton] at he; subst e; exact hv hre

private theorem step_known (d : Decl) (known : Revision → Bool → Option Int → Except RuleError Int)
    (P : Revision → Int → Prop)
    (hb : ∀ r prev k, known r true prev = .ok k → r.fetchedAt ≤ k)
    (hv : ∀ r later prev k, known r later prev = .ok k → P r k)
    (acc : Option Revision × Option Int × List Entry) (r : Revision)
    (h : KnownOut P acc.2.1 acc.2.2) :
    KnownOut P (revisionStep d known acc r).2.1 (revisionStep d known acc r).2.2 := by
  rcases acc with ⟨last, prev, out⟩
  unfold revisionStep
  dsimp only
  split
  · exact h
  cases prev with
  | none =>
    dsimp only
    split
    · exact h
    cases he : known r last.isSome none with
    | error e => exact h
    | ok k =>
      exact known_emit h r k false (by simp) (fun hn => (hn (h.empty.mp rfl)).elim)
        (fun _ => hv r last.isSome none k he)
  | some p =>
    dsimp only
    have hn : out ≠ [] := fun he => by have := h.empty.mpr he; contradiction
    split
    · exact known_emit h r _ true (fun he => (hn he).elim) (fun _ => Int.le_max_left ..) (by simp)
    cases he : known r true (some p) with
    | error e => exact known_emit h r _ true (fun he => (hn he).elim) (fun _ => Int.le_max_left ..) (by simp)
    | ok k =>
      exact known_emit h r k false (by simp) (fun _ => hb r (some p) k he)
        (fun _ => hv r true (some p) k he)

private theorem fold_known (d : Decl) (known : Revision → Bool → Option Int → Except RuleError Int)
    (P : Revision → Int → Prop)
    (hb : ∀ r prev k, known r true prev = .ok k → r.fetchedAt ≤ k)
    (hv : ∀ r later prev k, known r later prev = .ok k → P r k)
    (rs : List Revision) (acc : Option Revision × Option Int × List Entry) (h : KnownOut P acc.2.1 acc.2.2) :
    KnownOut P (rs.foldl (revisionStep d known) acc).2.1 (rs.foldl (revisionStep d known) acc).2.2 := by
  induction rs generalizing acc with
  | nil => exact h
  | cons r rs ih => exact ih _ (step_known d known P hb hv acc r h)

private theorem max_fold_lower {β : Type} (f : β → Int) (xs : List β) (a : Int) (init : Option Int)
    (h : ∃ k, init = some k ∧ a ≤ k) :
    ∃ k, xs.foldl (fun acc x => some (match acc with | some b => Max.max b (f x) | none => f x)) init = some k ∧ a ≤ k := by
  induction xs generalizing init with
  | nil => exact h
  | cons x xs ih =>
    obtain ⟨k, rfl, hk⟩ := h
    exact ih (some (Max.max k (f x))) ⟨_, rfl, Int.le_trans hk (Int.le_max_left ..)⟩

private theorem max_fold_member {β : Type} (f : β → Int) (xs : List β) (init : Option Int) (x : β) (hx : x ∈ xs) :
    ∃ k, xs.foldl (fun acc x => some (match acc with | some b => Max.max b (f x) | none => f x)) init = some k ∧ f x ≤ k := by
  induction xs generalizing init with
  | nil => simp at hx
  | cons y ys ih =>
    rcases List.mem_cons.mp hx with rfl | hx
    · simp only [List.foldl_cons]
      apply max_fold_lower
      cases init with
      | none => exact ⟨_, rfl, Int.le_refl _⟩
      | some k => exact ⟨_, rfl, Int.le_max_right ..⟩
    · exact ih _ hx

private theorem fold_max_lower (xs : List Int) (init : Int) : init ≤ xs.foldl Max.max init := by
  induction xs generalizing init with
  | nil => exact Int.le_refl _
  | cons x xs ih => exact Int.le_trans (Int.le_max_left ..) (ih _)

private theorem fold_max_member (xs : List Int) (init : Int) (x : Int) (hx : x ∈ xs) :
    x ≤ xs.foldl Max.max init := by
  induction xs generalizing init with
  | nil => simp at hx
  | cons y ys ih =>
    rcases List.mem_cons.mp hx with rfl | hx
    · exact Int.le_trans (Int.le_max_right ..) (fold_max_lower ys _)
    · exact ih _ hx

private theorem mapM_zip {β γ : Type} (xs : List β) (f : β → Except RuleError γ) (ys : List γ)
    (h : xs.mapM f = .ok ys) : ∀ x ∈ xs, ∃ y, (x, y) ∈ xs.zip ys ∧ f x = .ok y := by
  induction xs generalizing ys with
  | nil => simp
  | cons x xs ih =>
    simp only [List.mapM_cons, bind, Except.bind] at h
    cases hx : f x with
    | error e => simp only [hx] at h; contradiction
    | ok y =>
      cases ht : xs.mapM f with
      | error e => simp only [hx, ht] at h; contradiction
      | ok ys' =>
        simp only [hx, ht, pure, Except.pure, Except.ok.injEq] at h
        subst ys
        intro z hz
        rcases List.mem_cons.mp hz with rfl | hz
        · exact ⟨y, by simp, hx⟩
        · obtain ⟨v, hm, hv⟩ := ih ys' ht z hz
          exact ⟨v, by simp [hm], hv⟩

private theorem fold_lag_bound (xs : List (Dep × Int)) (k v : Int)
    (h : xs.foldlM (fun k (dep, t) => do let b ← ranged (t + dep.lag); pure (Max.max k b)) k = .ok v) :
    ∀ dep t, (dep, t) ∈ xs → t + dep.lag ≤ v := by
  induction xs generalizing k with
  | nil => simp
  | cons x xs ih =>
    rcases x with ⟨d, u⟩
    simp only [List.foldlM_cons, bind, Except.bind, ranged, pure, Except.pure] at h
    split at h <;> try contradiction
    rename_i u' hstep
    have hu' : u + d.lag ≤ u' := by
      by_cases hr : inRange (u + d.lag) = true
      · simp only [hr, ite_true, Except.ok.injEq] at hstep
        cases hstep
        exact Int.le_max_right ..
      · simp only [hr, ite_false, reduceCtorEq] at hstep
    intro dep t hm
    rcases List.mem_cons.mp hm with he | hm
    · cases he
      exact Int.le_trans hu' (fold_bounds xs
        (fun a (x : Dep × Int) => do let b ← ranged (x.2 + x.1.lag); pure (Max.max a b)) (fun a x v hv => by
        simp only [ranged, bind, Except.bind, pure, Except.pure] at hv
        split at hv <;> try contradiction
        cases hv
        exact Int.le_max_left ..) _ _ h)
    · exact ih _ h dep t hm

theorem timeline_known (reg : Registry) (st : Stored) (V : Int) (ok : Nat → Revision → Bool)
    (fuel s : Nat) (entity : String) (event : Int) :
    let tl := timeline reg st V ok (fuel + 1) s entity event
    (∀ i, 0 < i → i < tl.length → (tl[i]!).rev.fetchedAt ≤ (tl[i]!).known) ∧
    (∀ e ∈ tl.head?, e.retraction = false) ∧
    ∀ e ∈ tl, e.retraction = false → ∀ dep ∈ (reg.decls[s]!).deps,
      ((e.rev.upstream.find? (·.1 == dep.name)).map (·.2)).getD [] ≠ [] ∧
      ∀ up ∈ ((e.rev.upstream.find? (·.1 == dep.name)).map (·.2)).getD [], up.1 ∈ dep.sources ∧
        (∃ u ∈ timeline reg st V ok fuel up.1 up.2.1 up.2.2, u.rev.fetchedAt ≤ e.rev.fetchedAt) ∧
        ∀ u ∈ timeline reg st V ok fuel up.1 up.2.1 up.2.2, u.rev.fetchedAt ≤ e.rev.fetchedAt →
          u.known + dep.lag ≤ e.known := by
  let P (r : Revision) (k : Int) : Prop := ∀ dep ∈ (reg.decls[s]!).deps,
    ((r.upstream.find? (·.1 == dep.name)).map (·.2)).getD [] ≠ [] ∧
    ∀ up ∈ ((r.upstream.find? (·.1 == dep.name)).map (·.2)).getD [], up.1 ∈ dep.sources ∧
      (∃ u ∈ timeline reg st V ok fuel up.1 up.2.1 up.2.2, u.rev.fetchedAt ≤ r.fetchedAt) ∧
      ∀ u ∈ timeline reg st V ok fuel up.1 up.2.1 up.2.2, u.rev.fetchedAt ≤ r.fetchedAt →
        u.known + dep.lag ≤ k
  suffices hx : ∃ prev, KnownOut P prev (timeline reg st V ok (fuel + 1) s entity event) by
    obtain ⟨prev, hout⟩ := hx
    refine ⟨?_, hout.head, hout.values⟩
    intro i hi hlen
    rw [getElem!_pos (timeline reg st V ok (fuel + 1) s entity event) i hlen]
    apply hout.tail
    exact List.mem_iff_getElem.mpr ⟨i - 1, by simp only [List.length_tail]; omega,
      by simp only [List.getElem_tail]; congr 1; omega⟩
  unfold timeline
  extract_lets d upKnown known step
  have hb : ∀ r prev k, known r true prev = .ok k → r.fetchedAt ≤ k := by
    intro r prev k he
    dsimp only [known] at he
    simp only [ranged, bind, Except.bind, pure, Except.pure, throw, throwThe, MonadExceptOf.throw] at he
    repeat' (split at he <;> try contradiction)
    all_goals
      have hb := fold_bounds _ _ (fun a x v hv => by
        try dsimp only [ranged] at hv
        split at hv <;> try contradiction
        cases hv
        exact Int.le_max_left ..) _ _ he
      by_cases hr : inRange r.fetchedAt = true
      · simp_all only [ite_true, Except.ok.injEq]
        omega
      · simp_all only [ite_false, reduceCtorEq]
  have hup : ∀ dep u by_ t, upKnown dep u by_ = .ok t → u.1 ∈ dep.sources ∧
      (∃ x ∈ timeline reg st V ok fuel u.1 u.2.1 u.2.2, x.rev.fetchedAt ≤ by_) ∧
      ∀ x ∈ timeline reg st V ok fuel u.1 u.2.1 u.2.2, x.rev.fetchedAt ≤ by_ → x.known ≤ t := by
    intro dep u by_ t he
    dsimp only [upKnown] at he
    split at he
    · contradiction
    rename_i hsrc
    split at he
    · rename_i k hk
      cases he
      refine ⟨by simpa using hsrc, ?_, ?_⟩
      · cases hl : (timeline reg st V ok fuel u.1 u.2.1 u.2.2).filter
            (fun x => decide (x.rev.fetchedAt ≤ by_)) with
        | nil => rw [hl] at hk; simp at hk
        | cons x xs =>
          have hx : x ∈ (timeline reg st V ok fuel u.1 u.2.1 u.2.2).filter
              (fun x => decide (x.rev.fetchedAt ≤ by_)) := by rw [hl]; simp
          simp only [List.mem_filter, decide_eq_true_eq] at hx
          exact ⟨x, hx.1, hx.2⟩
      · intro x hx hfetch
        have hx' : x ∈ (timeline reg st V ok fuel u.1 u.2.1 u.2.2).filter
            (fun x => decide (x.rev.fetchedAt ≤ by_)) := by simp [hx, hfetch]
        obtain ⟨k', hk', hle⟩ := max_fold_member (·.known) _ none x hx'
        cases hk'.symm.trans hk
        exact hle
    · contradiction
  have hv : ∀ r later prev k, known r later prev = .ok k → P r k := by
    intro r later prev k he
    dsimp only [known] at he
    simp only [bind, Except.bind, pure, Except.pure, throw, throwThe, MonadExceptOf.throw] at he
    split at he
    · contradiction
    split at he
    · contradiction
    · rename_i ts hts
      repeat' (split at he <;> try contradiction)
      all_goals
        intro dep hdep
        obtain ⟨t, hzip, ht⟩ := mapM_zip _ _ ts hts dep hdep
        have hlag := fold_lag_bound _ _ _ he dep t hzip
        split at ht
        · contradiction
        rename_i ks hks
        split at ht
        · contradiction
        rename_i _ first rest
        cases ht
        refine ⟨fun hn => by
          rw [hn] at hks; simp only [List.mapM_nil, pure, Except.pure, Except.ok.injEq, reduceCtorEq] at hks, fun up hu => ?_⟩
        obtain ⟨tu, hzu, htu⟩ := mapM_zip _ _ _ hks up hu
        have hm : tu ∈ first :: rest := (List.of_mem_zip hzu).2
        have htt : tu ≤ rest.foldl Max.max first := by
          rcases List.mem_cons.mp hm with rfl | hm
          · exact fold_max_lower rest tu
          · exact fold_max_member rest _ tu hm
        obtain ⟨hs, hex, hbound⟩ := hup dep up r.fetchedAt tu htu
        exact ⟨hs, hex, fun u hu hfetch => by have := hbound u hu hfetch; omega⟩
  exact ⟨_, fold_known d known P hb hv (st.eligible s V entity event) (none, none, [])
    ⟨by simp, by simp, by simp, by simp⟩⟩

end Ref
