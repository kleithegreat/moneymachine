import Ref.Spec

namespace Ref
variable {α : Type} [Inhabited α]

structure Ctx.L4Valid (c : Ctx α) : Prop where
  indexed : c.ix = Index.of c.bars c.rates c.coins
  barKeys : (c.bars.toList.map fun b => (b.coin, b.openTime)).Nodup
  barCoin : ∀ b ∈ c.bars.toList, b.coin < c.coins
  barDuration : ∀ b ∈ c.bars.toList, b.event = b.openTime + BAR

private theorem eraseDups_length_le {β : Type} [BEq β] (l : List β) : l.eraseDups.length ≤ l.length := by
  cases l with
  | nil => simp
  | cons a l =>
    rw [List.eraseDups_cons, List.length_cons, List.length_cons]
    have ih := eraseDups_length_le (l.filter fun b => !b == a)
    have := List.length_filter_le (p := fun b => !b == a) (l := l)
    omega
termination_by l.length
decreasing_by
  have := List.length_filter_le (p := fun b => !b == a) (l := l)
  simp_wf
  omega

private theorem nodup_of_eraseDups_length {β : Type} [BEq β] [LawfulBEq β] (l : List β)
    (h : l.eraseDups.length = l.length) : l.Nodup := by
  induction l with
  | nil => simp
  | cons a l ih =>
    rw [List.eraseDups_cons, List.length_cons, List.length_cons] at h
    have hle := eraseDups_length_le (l.filter fun b => !b == a)
    have hflt := List.length_filter_le (p := fun b => !b == a) (l := l)
    have hall := List.length_filter_eq_length_iff.mp (show (l.filter fun b => !b == a).length = l.length by omega)
    have hf : l.filter (fun b => !b == a) = l := List.filter_eq_self.mpr hall
    rw [hf] at h
    exact List.nodup_cons.mpr ⟨by intro ha; have := hall a ha; simp at this, ih (by omega)⟩

theorem barRow_fields (roles : Roles) (o : Obs α) (b : BarRow α) (h : barRow roles o = some b) :
    o.final = true ∧ o.source = roles.bars ∧ b.coin = o.coin ∧ b.openTime = o.key - BAR ∧ b.event = o.key := by
  unfold barRow at h
  split at h
  · split at h
    · rename_i hh
      simp only [Bool.and_eq_true, beq_iff_eq] at hh
      cases h
      exact ⟨hh.2, hh.1, rfl, rfl, rfl⟩
    · cases h
  · cases h

private theorem bars_filter_final (roles : Roles) (l : List (Obs α)) :
    l.filterMap (barRow roles) = (l.filter (·.final)).filterMap (barRow roles) := by
  induction l with
  | nil => rfl
  | cons o l ih =>
    cases hb : barRow roles o with
    | none => simp [List.filterMap_cons, List.filter_cons, hb, ih]; split <;> simp [hb]
    | some b => simp [List.filterMap_cons, List.filter_cons, hb, (barRow_fields roles o b hb).1, ih]

theorem make_l4Valid (reg : Registry) (roles : Roles) (p : Program) (adm : Meta) (obs : Array (Obs α))
    (v : Venue α) (pol : Policy) (stop : Int) (req : List Nat)
    (h : (Ctx.make reg roles p adm obs v pol stop req).admissible = true) :
    (Ctx.make reg roles p adm obs v pol stop req).L4Valid := by
  let c := Ctx.make reg roles p adm obs v pol stop req
  change c.admissible = true at h
  have hh := h
  simp only [Ctx.admissible, Bool.and_eq_true] at hh
  have hkeys : ((c.obs.toList.filter (·.final)).map fun o => (o.source, o.coin, o.key)).Nodup := by
    exact nodup_of_eraseDups_length _ (beq_iff_eq.mp hh.1)
  have hobs : ∀ o ∈ c.obs.toList, o.coin < c.coins := by
    intro o ho
    obtain ⟨i, hi, he⟩ := List.mem_iff_getElem.mp ho
    have hv := Array.all_eq_true.mp hh.2 i (by simpa using hi)
    simp only [Bool.and_eq_true, decide_eq_true_eq] at hv
    simpa only [Array.getElem_toList] using he ▸ hv.1.1.1.2
  have hbars : c.bars.toList = c.obs.toList.filterMap (barRow roles) := by
    simp only [c, Ctx.make, Array.toList_filterMap]
  refine ⟨rfl, ?_, ?_, ?_⟩
  · rw [hbars, bars_filter_final]
    change List.Pairwise (· ≠ ·) _
    rw [List.pairwise_map]
    change List.Pairwise (fun a b => (a.coin, a.openTime) ≠ (b.coin, b.openTime))
      (((c.obs.toList.filter (·.final)).filterMap (barRow roles)))
    apply List.Pairwise.filterMap (barRow roles) _ (List.pairwise_map.mp hkeys)
    intro a a' hne b hb b' hb' he
    obtain ⟨_, ha, hc, ht, _⟩ := barRow_fields roles a b hb
    obtain ⟨_, ha', hc', ht', _⟩ := barRow_fields roles a' b' hb'
    apply hne
    simp only [Prod.mk.injEq] at he ⊢
    exact ⟨ha.trans ha'.symm, by omega, by omega⟩
  · intro b hb
    obtain ⟨o, ho, hb⟩ := List.mem_filterMap.mp (hbars ▸ hb)
    rw [(barRow_fields roles o b hb).2.2.1]
    exact hobs o ho
  · intro b hb
    obtain ⟨o, _, hb⟩ := List.mem_filterMap.mp (hbars ▸ hb)
    obtain ⟨_, _, _, ht, he⟩ := barRow_fields roles o b hb
    omega

end Ref
