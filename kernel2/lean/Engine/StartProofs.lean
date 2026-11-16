import Engine.Start
import Engine.Lang.SyntaxProofs

/-!
# `start`'s preflight (B3, L5)
-/

namespace Engine.Machine

open Engine.Lang

theorem bind_error_iff (p : Program) (cfg : Config) :
    bind p cfg = .error "E_UNKNOWN_INPUT" ↔
      ((∃ d ∈ p.declared, cfg.declaresSource d.1 d.2 = false) ∨ (p.readsTraded = true ∧ cfg.trades = none)) := by
  unfold bind
  by_cases h : (p.declared.any (fun d => !cfg.declaresSource d.1 d.2) || (p.readsTraded && cfg.trades.isNone)) = true
  · rw [if_pos h]
    simp only [true_iff]
    simp only [Bool.or_eq_true, List.any_eq_true, Bool.and_eq_true, Bool.not_eq_true'] at h
    rcases h with ⟨d, hd, hdd⟩ | ⟨hr, ht⟩
    · exact Or.inl ⟨d, hd, hdd⟩
    · exact Or.inr ⟨hr, by simpa using ht⟩
  · rw [if_neg h]
    simp only [Bool.or_eq_true, List.any_eq_true, Bool.and_eq_true, Bool.not_eq_true'] at h
    constructor
    · intro hh; simp at hh
    · rintro (⟨d, hd, hdd⟩ | ⟨hr, ht⟩)
      · exact absurd (Or.inl ⟨d, hd, hdd⟩) h
      · exact absurd (Or.inr ⟨hr, by simp [ht]⟩) h

theorem bind_ok_iff (p : Program) (cfg : Config) :
    bind p cfg = .ok () ↔
      ¬ ((∃ d ∈ p.declared, cfg.declaresSource d.1 d.2 = false) ∨ (p.readsTraded = true ∧ cfg.trades = none)) := by
  rw [← bind_error_iff]
  unfold bind
  by_cases h : (p.declared.any (fun d => !cfg.declaresSource d.1 d.2) || (p.readsTraded && cfg.trades.isNone)) = true
  · simp [h]
  · simp [h]

theorem prepare_eq {program header : String} {p : Program} {cfg : Config}
    (hp : parse program = .ok p) (hc : parseHeader header = .ok cfg) :
    prepare program header =
      (if meetsProtected cfg then .error "R_PROTECTED"
        else if !leverageOk p cfg then .error "E_LEVERAGE" else .ok (p, cfg)) := by
  unfold prepare
  rw [hp]
  show (do let cfg' ← parseHeader header; _) = _
  rw [hc]
  rfl

theorem prepare_ok {program header : String} {p : Program} {cfg : Config}
    (hp : parse program = .ok p) (hc : parseHeader header = .ok cfg)
    (hb : startBeforeBind program header = .ok ()) : prepare program header = .ok (p, cfg) := by
  unfold startBeforeBind at hb
  rw [prepare_eq hp hc] at hb ⊢
  split at hb
  · simp [Functor.map, Except.map] at hb
  · split at hb
    · simp [Functor.map, Except.map] at hb
    · simp [*]

theorem prepare_parts {program header : String} {p : Program} {cfg : Config}
    (h : prepare program header = .ok (p, cfg)) : parse program = .ok p ∧ parseHeader header = .ok cfg := by
  cases hp : parse program with
  | error e => exact absurd h (by simp [prepare, hp, Bind.bind, Except.bind])
  | ok q =>
    cases hc : parseHeader header with
    | error e => unfold prepare at h; rw [hp] at h; simp [hc] at h; exact absurd h (by simp [Bind.bind, Except.bind])
    | ok c =>
      rw [prepare_eq hp hc] at h
      split at h
      · simp at h
      · split at h
        · simp at h
        · injection h with h
          simp only [Prod.mk.injEq] at h
          obtain ⟨rfl, rfl⟩ := h
          exact ⟨rfl, rfl⟩

theorem start_bind_error {program header : String} {p : Program} {cfg : Config}
    (hp : parse program = .ok p) (hc : parseHeader header = .ok cfg)
    (hb : startBeforeBind program header = .ok ()) (he : bind p cfg = .error "E_UNKNOWN_INPUT") :
    start program header = .error "E_UNKNOWN_INPUT" := by
  unfold start
  rw [prepare_ok hp hc hb]
  show (do let _ ← bind p cfg; _) = _
  rw [he]
  rfl

theorem start_ok_bind {program header : String} {st : State} (h : start program header = .ok st) :
    ∃ (p : Program) (cfg : Config), parse program = .ok p ∧ parseHeader header = .ok cfg ∧ bind p cfg = .ok () := by
  unfold start at h
  cases hq : prepare program header with
  | error e => rw [hq] at h; simp [Bind.bind, Except.bind] at h
  | ok q =>
    obtain ⟨p, cfg⟩ := q
    refine ⟨p, cfg, (prepare_parts hq).1, (prepare_parts hq).2, ?_⟩
    rw [hq] at h
    cases hb : bind p cfg with
    | error e => simp [Bind.bind, Except.bind, hb] at h
    | ok u => rfl

def isOk (x : Except String State) : Bool := match x with | .ok _ => true | .error _ => false

def isError (code : String) (x : Except String State) : Bool :=
  match x with | .error c => c == code | .ok _ => false

theorem exists_ok_of {x : Except String State} (h : isOk x = true) : ∃ st, x = .ok st := by
  cases x with
  | ok st => exact ⟨st, rfl⟩
  | error _ => simp [isOk] at h

theorem eq_error_of {x : Except String State} {code : String} (h : isError code x = true) : x = .error code := by
  cases x with
  | error c => simp [isError] at h; rw [h]
  | ok _ => simp [isError] at h

end Engine.Machine
