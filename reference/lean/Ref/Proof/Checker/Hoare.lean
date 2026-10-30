import Ref.Spec

/-! A Hoare logic for `Check`: `Spec`, and `Keeps` for steps that leave the state alone. -/

namespace Ref

variable {ok : Input → Prop}

/-- Partial correctness: from a state satisfying P, a successful x ends in a state satisfying Q. -/
def Spec {β} (P : CState → Prop) (x : Check β) (Q : β → CState → Prop) : Prop :=
  ∀ st, P st → ∀ b st', x st = .ok (b, st') → Q b st'

namespace Spec
variable {β γ : Type} {P : CState → Prop} {Q : β → CState → Prop}

theorem pure' {b : β} (h : ∀ st, P st → Q b st) : Spec P (pure b) Q := by
  intro st hp b' st' hx; cases hx; exact h st hp

theorem bind {R : β → CState → Prop} {x : Check β} {f : β → Check γ} {Q : γ → CState → Prop}
    (hx : Spec P x R) (hf : ∀ b, Spec (R b) (f b) Q) : Spec P (x >>= f) Q := by
  intro st hp c st' h
  change (x st >>= fun r => f r.1 r.2) = _ at h
  cases hxs : x st with
  | error e => rw [hxs] at h; cases h
  | ok r => rw [hxs] at h; exact hf r.1 r.2 (hx st hp r.1 r.2 hxs) c st' h

theorem throw' {c : Code} : Spec P (throw c : Check β) Q := by
  intro st _ b st' h; cases h

theorem fail' {c : Code} : Spec P (fail c : Check β) Q := throw'

theorem get' {Q : CState → CState → Prop} (h : ∀ st, P st → Q st st) : Spec P get Q := by
  intro st hp b st' hx; cases hx; exact h st hp

theorem modify' {f : CState → CState} {Q : PUnit → CState → Prop} (h : ∀ st, P st → Q ⟨⟩ (f st)) :
    Spec P (modify f) Q := by
  intro st hp b st' hx; cases hx; exact h st hp

theorem set' {s : CState} {Q : PUnit → CState → Prop} (h : ∀ st, P st → Q ⟨⟩ s) : Spec P (set s) Q := by
  intro st hp b st' hx; cases hx; exact h st hp

theorem conseq {P' : CState → Prop} {Q' : β → CState → Prop} {x : Check β} (h : Spec P x Q)
    (hp : ∀ st, P' st → P st) (hq : ∀ b st, Q b st → Q' b st) : Spec P' x Q' :=
  fun st h' b st' hx => hq _ _ (h st (hp st h') b st' hx)

theorem forIn_list {σ : Type} (l : List β) (init : σ) (f : β → σ → Check (ForInStep σ)) (I : σ → CState → Prop)
    (hf : ∀ a ∈ l, ∀ s, Spec (I s) (f a s) (fun r st => I r.value st)) :
    Spec (I init) (forIn l init f) I := by
  induction l generalizing init with
  | nil => exact pure' fun _ h => h
  | cons a as ih =>
    simp only [List.forIn_cons]
    refine bind (hf a (by simp) init) fun r => ?_
    cases r with
    | done s => exact pure' fun _ h => h
    | yield s => exact ih s (fun a' ha' => hf a' (by simp [ha']))

theorem forIn_array {σ : Type} (xs : Array β) (init : σ) (f : β → σ → Check (ForInStep σ)) (I : σ → CState → Prop)
    (hf : ∀ a ∈ xs, ∀ s, Spec (I s) (f a s) (fun r st => I r.value st)) :
    Spec (I init) (forIn xs init f) I := by
  rw [← Array.forIn_toList]
  exact forIn_list _ _ _ _ fun a ha => hf a (by simpa using ha)

end Spec

/-- x leaves the state as it found it. -/
def Keeps {β} (x : Check β) : Prop := ∀ st b st', x st = .ok (b, st') → st' = st

namespace Keeps
variable {β γ : Type}

theorem spec {x : Check β} (h : Keeps x) (P : CState → Prop) : Spec P x (fun _ => P) :=
  fun st hp b st' hx => (h st b st' hx) ▸ hp

theorem pure' (b : β) : Keeps (pure b : Check β) := by
  intro st b' st' h; cases h; rfl

theorem fail' (c : Code) : Keeps (fail c : Check β) := by
  intro st b st' h; cases h

theorem bind {x : Check β} {f : β → Check γ} (hx : Keeps x) (hf : ∀ b, Keeps (f b)) : Keeps (x >>= f) := by
  intro st c st' h
  change (x st >>= fun r => f r.1 r.2) = _ at h
  cases hxs : x st with
  | error e => rw [hxs] at h; cases h
  | ok r => rw [hxs] at h; rw [hf r.1 r.2 c st' h, hx st r.1 r.2 hxs]

theorem forIn_list {σ : Type} (l : List β) (init : σ) (f : β → σ → Check (ForInStep σ)) (hf : ∀ a s, Keeps (f a s)) :
    Keeps (forIn l init f) := by
  induction l generalizing init with
  | nil => exact pure' _
  | cons a as ih =>
    simp only [List.forIn_cons]
    refine bind (hf a init) fun r => ?_
    cases r with
    | done s => exact pure' _
    | yield s => exact ih s

theorem forIn_array {σ : Type} (xs : Array β) (init : σ) (f : β → σ → Check (ForInStep σ))
    (hf : ∀ a s, Keeps (f a s)) : Keeps (forIn xs init f) := by
  rw [← Array.forIn_toList]; exact forIn_list _ _ _ hf

/-- Walk a do-block that never writes the state. -/
macro "keeps" : tactic => `(tactic| repeat (first
  | exact Keeps.pure' _
  | exact Keeps.fail' _
  | (refine Keeps.bind ?_ (fun _ => ?_))
  | (refine Keeps.forIn_array _ _ _ (fun _ _ => ?_))
  | (refine Keeps.forIn_list _ _ _ (fun _ _ => ?_))
  | split))

theorem discard {x : Check β} (h : Keeps x) : Keeps (discard x) := by
  intro st b st' hx
  change (x st >>= fun r => pure (PUnit.unit, r.2)) = _ at hx
  cases hxs : x st with
  | error e => rw [hxs] at hx; cases hx
  | ok r => rw [hxs] at hx; cases hx; exact h st r.1 r.2 hxs

end Keeps

theorem fields_keeps (v : Json.Value) (req opt : List String) : Keeps (fields v req opt) := by
  unfold fields; keeps

theorem asString_keeps (v : Json.Value) : Keeps (asString v) := by
  unfold asString; keeps

theorem number_keeps (v : Json.Value) : Keeps (number v) := by
  unfold number; keeps

theorem unitOf_keeps (v : Json.Value) : Keeps (unitOf v) := by
  unfold unitOf
  refine Keeps.bind (asString_keeps _) fun _ => ?_
  split
  · exact Keeps.pure' _
  · exact Keeps.fail' _


theorem Spec.bind_keeps {β γ} {P : CState → Prop} {Q : γ → CState → Prop} {x : Check β} {f : β → Check γ}
    (hx : Keeps x) (hf : ∀ b, Spec P (f b) Q) : Spec P (x >>= f) Q :=
  Spec.bind (hx.spec P) hf

end Ref
