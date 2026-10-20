/-! Properties of `Except` computations, closed under the monad's operations: which errors one avoids,
and what holds of its result. -/

namespace Ref

/-- x never fails with error e. -/
def Except.Avoids {ε β} (e : ε) (x : Except ε β) : Prop := x ≠ .error e

namespace Except.Avoids
variable {ε β γ : Type} {e : ε}

theorem pure (b : β) : Avoids e (Except.pure b : Except ε β) := by
  intro h; cases h

theorem ok (b : β) : Avoids e (Except.ok b : Except ε β) := by
  intro h; cases h

theorem throw {e' : ε} (h : e' ≠ e) : Avoids e (Except.error e' : Except ε β) := by
  intro h'; cases h'; exact h rfl

theorem bind {x : Except ε β} {f : β → Except ε γ} (hx : Avoids e x) (hf : ∀ b, Avoids e (f b)) :
    Avoids e (x >>= f) := by
  intro h
  cases x with
  | error e' => exact hx (by simpa [Bind.bind, Except.bind] using h)
  | ok b => exact hf b (by simpa [Bind.bind, Except.bind] using h)

theorem ite {c : Prop} [Decidable c] {x y : Except ε β} (hx : Avoids e x) (hy : Avoids e y) :
    Avoids e (if c then x else y) := by
  split <;> assumption

theorem forIn_list {σ : Type} (l : List β) (init : σ) (f : β → σ → Except ε (ForInStep σ))
    (hf : ∀ b s, Avoids e (f b s)) : Avoids e (forIn l init f) := by
  induction l generalizing init with
  | nil => exact ok init
  | cons b bs ih =>
    simp only [List.forIn_cons]
    apply bind (hf b init)
    intro r
    cases r with
    | done s => exact ok s
    | yield s => exact ih s

end Except.Avoids

/-- Every result x succeeds with satisfies Q. -/
def Except.Holds {ε β} (x : Except ε β) (Q : β → Prop) : Prop := ∀ b, x = .ok b → Q b

namespace Except.Holds
variable {ε β γ : Type} {Q : β → Prop}

theorem pure (b : β) (h : Q b) : Holds (Except.pure b : Except ε β) Q := by
  intro b' hb; cases hb; exact h

theorem ok (b : β) (h : Q b) : Holds (Except.ok b : Except ε β) Q := by
  intro b' hb; cases hb; exact h

theorem error (e : ε) : Holds (Except.error e : Except ε β) Q := by
  intro b h; cases h

theorem bind {R : β → Prop} {x : Except ε β} {f : β → Except ε γ} {Q : γ → Prop} (hx : Holds x R)
    (hf : ∀ b, R b → Holds (f b) Q) : Holds (x >>= f) Q := by
  intro c h
  cases hxs : x with
  | error e => rw [hxs] at h; cases h
  | ok b => rw [hxs] at h; exact hf b (hx b hxs) c h

theorem ite {c : Prop} [Decidable c] {x y : Except ε β} (hx : Holds x Q) (hy : Holds y Q) :
    Holds (if c then x else y) Q := by
  split <;> assumption

theorem throw' (e : ε) : Holds (throw e : Except ε β) Q := by
  intro b h; cases h

theorem conseq {x : Except ε β} {Q' : β → Prop} (h : Holds x Q) (hq : ∀ b, Q b → Q' b) : Holds x Q' :=
  fun b hb => hq b (h b hb)

theorem forIn_list {σ : Type} (l : List β) (init : σ) (f : β → σ → Except ε (ForInStep σ)) (I : σ → Prop)
    (h0 : I init) (hf : ∀ a ∈ l, ∀ s, I s → Holds (f a s) (fun r => I r.value)) : Holds (forIn l init f) I := by
  induction l generalizing init with
  | nil => exact ok init h0
  | cons a as ih =>
    simp only [List.forIn_cons]
    refine bind (hf a (by simp) init h0) fun r hr => ?_
    cases r with
    | done s => exact ok s hr
    | yield s => exact ih s hr fun a' ha' => hf a' (by simp [ha'])

end Except.Holds

/-- A loop whose body always continues runs over l₁ ++ l₂ as over l₁, then l₂. -/
theorem Except.forIn_append_yield {ε β σ : Type} (l₁ l₂ : List β) (s : σ) (F : β → σ → Except ε (ForInStep σ))
    (hF : ∀ a r, Holds (F a r) (fun st => ∃ v, st = .yield v)) :
    forIn (l₁ ++ l₂) s F = forIn l₁ s F >>= fun r => forIn l₂ r F := by
  induction l₁ generalizing s with
  | nil => rfl
  | cons a as ih =>
    simp only [List.cons_append, List.forIn_cons]
    cases h : F a s with
    | error e => rfl
    | ok st =>
      obtain ⟨v, rfl⟩ := hF a s _ h
      exact ih v

end Ref
