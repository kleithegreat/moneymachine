import Engine.RInvSteps

/-!
# R1's wish invariants through a tick (brief 3 step 5)
-/

namespace Engine.Machine

open Engine.Orders (Wish)

theorem nodup_all_eq_len {β : Type} (a : β) : ∀ L : List β, L.Nodup → (∀ x ∈ L, x = a) → L.length ≤ 1 := by
  intro L
  match L with
  | [] => intro _ _; simp
  | [_] => intro _ _; simp
  | x :: y :: rest =>
    intro hn hall
    have hx := hall x (by simp)
    have hy := hall y (by simp)
    have : x = y := by rw [hx, hy]
    subst this
    simp at hn

theorem filter_orderWishes (B : List Wish) (hB : (B.map (fun x => (x.coin, x.slot))).Nodup) (coin slot : Nat) :
    (orderWishes B).filter (SameSlot coin slot) = B.filter (SameSlot coin slot) := by
  have hperm := (orderWishes_perm B).filter (SameSlot coin slot)
  have hlen : (B.filter (SameSlot coin slot)).length ≤ 1 := by
    have hn : ((B.filter (SameSlot coin slot)).map (fun x => (x.coin, x.slot))).Nodup := by
      have : (B.filter (SameSlot coin slot)).map (fun x => (x.coin, x.slot)) |>.Sublist (B.map (fun x => (x.coin, x.slot))) :=
        (List.filter_sublist).map _
      exact hB.sublist this
    have hall : ∀ x ∈ (B.filter (SameSlot coin slot)).map (fun x => (x.coin, x.slot)), x = (coin, slot) := by
      intro x hx
      simp only [List.mem_map, List.mem_filter, SameSlot, decide_eq_true_eq] at hx
      obtain ⟨y, ⟨_, hy⟩, rfl⟩ := hx
      simp [hy.1, hy.2]
    have := nodup_all_eq_len _ _ hn hall
    simpa using this
  generalize B.filter (SameSlot coin slot) = F at hperm hlen
  generalize (orderWishes B).filter (SameSlot coin slot) = G at hperm
  match F, hlen with
  | [], _ => exact List.perm_nil.1 hperm
  | [x], _ => exact (List.perm_singleton.1 hperm)

theorem tickAt_batch (s : State) (time : Int) :
    (∀ x ∈ (tickAt s time).2.2.wishes, x.sent = time ∧ x.arrives = time + s.cfg.lambda) ∧
    ((tickAt s time).2.2.wishes.map (fun x => (x.coin, x.slot))).Nodup := by
  have h := tickBody_batch (tickPre s time) time
  refine ⟨h.1, ?_⟩
  rw [tickAt_eq, h.2]
  split
  · exact keysOf_nodup _ _
  · exact List.nodup_nil

/-- RInv depends on the log only through the wishes sent and the wishes arrived. -/
theorem rinv_congr {c c' : Core} (h : RInv c) (hcfg : c'.cfg.lambda = c.cfg.lambda) (hn : c'.nextTick = c.nextTick)
    (hw : c'.wishes = c.wishes)
    (hl : c'.log.map (fun l => (l.wishes, l.arrivals)) = c.log.map (fun l => (l.wishes, l.arrivals))) : RInv c' := by
  have key : ∀ l', c'.log = some l' → ∃ l, c.log = some l ∧ l'.wishes = l.wishes ∧ l'.arrivals = l.arrivals := by
    intro l' hl'
    rw [hl'] at hl
    cases hc : c.log with
    | none => rw [hc] at hl; simp at hl
    | some l =>
      rw [hc] at hl
      simp only [Option.map_some, Option.some.injEq, Prod.mk.injEq] at hl
      exact ⟨l, rfl, hl.1, hl.2⟩
  refine ⟨?_, ?_, ?_, ?_, ?_, ?_⟩
  · intro l' hl' w hw'
    obtain ⟨l, hlc, e1, _⟩ := key l' hl'
    rw [hcfg]; rw [e1] at hw'
    exact h.sentArrives l hlc w hw'
  · intro l' hl' w hw' t ht
    obtain ⟨l, hlc, e1, _⟩ := key l' hl'
    rw [e1] at hw'; rw [hn] at ht
    exact h.sentBefore l hlc w hw' t ht
  · intro l' hl'
    obtain ⟨l, hlc, e1, _⟩ := key l' hl'
    rw [e1]
    exact h.sentPairs l hlc
  · intro w hw' t ht
    rw [hw] at hw'; rw [hn] at ht; rw [hcfg]
    exact h.queueBefore w hw' t ht
  · rw [hw]; exact h.queueSorted
  · intro l' hl' coin slot
    obtain ⟨l, hlc, e1, e2⟩ := key l' hl'
    rw [e1, e2, hw]
    exact h.fifo l hlc coin slot

end Engine.Machine
