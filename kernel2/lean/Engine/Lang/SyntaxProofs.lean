import Engine.Check

/-!
# The checker's laws: L2 over the program's text (B3)
-/

namespace Engine.Lang

theorem parseAt_wfb {text : String} {p : Program} (h : parseAt text = .ok p) : p.wfb = true := by
  unfold parseAt at h
  split at h
  · simp at h
  · split at h
    · simp at h
    · split at h
      · simp at h
      · split at h
        · injection h with h
          subst h
          assumption
        · simp at h

theorem parse_ok_iff {text : String} {p : Program} : parse text = .ok p ↔ parseAt text = .ok p := by
  unfold parse
  cases hp : parseAt text with
  | error e => simp [Except.mapError]
  | ok q => simp [Except.mapError]

theorem parse_error_iff {text : String} {code : String} :
    parse text = .error code ↔ ∃ place, parseAt text = .error (code, place) := by
  unfold parse
  cases hp : parseAt text with
  | error e => simp [Except.mapError]; constructor <;> intro h
               · exact ⟨e.2, by rw [← h]⟩
               · obtain ⟨place, h⟩ := h; rw [h]
  | ok q => simp [Except.mapError]

theorem check_ok_iff (text : String) :
    (Engine.check text).startsWith "{\"ok\":true" = true ↔ ∃ p, parse text = .ok p := by
  unfold Engine.check
  cases hp : parseAt text with
  | ok p =>
    simp only
    constructor
    · intro _; exact ⟨p, parse_ok_iff.2 hp⟩
    · intro _
      rw [String.startsWith_string_iff]
      decide
  | error e =>
    simp only
    constructor
    · intro h
      rw [String.startsWith_string_iff] at h
      simp only [String.toList_append] at h
      have h1 : "{\"error\":\"".toList = ['{', '"', 'e', 'r', 'r', 'o', 'r', '"', ':', '"'] := by decide
      have h2 : "{\"ok\":true".toList = ['{', '"', 'o', 'k', '"', ':', 't', 'r', 'u', 'e'] := by decide
      rw [h1, h2] at h
      simp at h
    · rintro ⟨p, hq⟩
      rw [parse_ok_iff, hp] at hq
      simp at hq

theorem check_error (text code : String) (h : parse text = .error code) :
    (Engine.check text).startsWith ("{\"error\":\"" ++ code ++ "\"") = true := by
  obtain ⟨place, hp⟩ := parse_error_iff.1 h
  unfold Engine.check
  rw [hp]
  simp only
  rw [String.startsWith_string_iff]
  simp only [String.toList_append]
  exact ⟨",\"at\":\"".toList ++ (Engine.Json.escape place).toList ++ "\"}".toList, by simp [List.append_assoc]⟩

end Engine.Lang
