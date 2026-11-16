import Engine.Start
import Engine.MachineProofs

namespace Engine.Machine

/-- The program and header of the laws' concrete case, and its one quote. -/
def lawProgram : String := "{\"version\":2,\"tick\":1,\"decide_every\":1,\"leverage\":1,\"sources\":[],\"params\":[],\"let\":[],\"slots\":[],\"probes\":[]}"

def lawHeader : String := "{\"horizon\":{\"start\":1775174400000,\"end\":1775174400001},\"venue\":{\"fill\":\"optimistic\",\"lambda\":0,\"delta\":0,\"stale\":60000,\"cap\":\"10000\",\"minimum\":\"10\"},\"cash\":\"10000\",\"coins\":[{\"name\":\"A\",\"sz_decimals\":2,\"figures\":5,\"decimals\":4,\"tiers\":[{\"from\":\"0\",\"max_leverage\":10}]}],\"fees\":[{\"from\":1775174400000,\"tier\":\"base\",\"maker\":\"0.00015\",\"taker\":\"0.00045\"}],\"sources\":{\"listings\":{\"lag\":0},\"funding\":{\"encoding\":\"string\",\"lag\":0,\"late\":1000},\"quotes\":{\"encoding\":\"string\"},\"trades\":{\"encoding\":\"string\"},\"observations\":[]},\"aliases\":{\"coins\":{},\"sources\":{}}}"

def lawQuote : Event :=
  { coin := 0, time := 1775174400000, known := 1775174400000,
    payload := .quote [{ price := .placed 99 0, size := .placed 2 0 }]
                      [{ price := .placed 101 0, size := .placed 3 0 }] }

/-- The concrete case as one boolean, evaluated by the kernel. -/
def lawCheck : Bool :=
  match start lawProgram lawHeader with
  | .error _ => false
  | .ok initial =>
    let next := feed initial (pack [lawQuote])
    let final := finish next.1
    initial.count == 0 &&
      (match decodeChunk initial (pack [lawQuote]) with
        | .ok es => decide (es = [lawQuote])
        | .error _ => false) &&
      next.1.count == 1 && decide (next.1 ≠ initial) &&
      final.2.startsWith "{\"ok\":true" &&
      (next.2.trace ++ final.1.trace == "tick\t1775174400000\tA\t100\t0\t0\n")

theorem lawCheck_true : lawCheck = true := by decide +kernel

/-- The statement both laws end with: a first quote is admitted, counted, and ticked at the end. -/
theorem concrete_run :
    ∃ initial : State, start lawProgram lawHeader = .ok initial ∧ initial.count = 0 ∧
      decodeChunk initial (pack [lawQuote]) = .ok [lawQuote] ∧
      (let next := feed initial (pack [lawQuote])
       let final := finish next.1
       next.1.count = 1 ∧ next.1 ≠ initial ∧
       final.2.startsWith "{\"ok\":true" = true ∧
       next.2.trace ++ final.1.trace = "tick\t1775174400000\tA\t100\t0\t0\n") := by
  have h := lawCheck_true
  unfold lawCheck at h
  split at h
  · simp at h
  · rename_i initial hs
    refine ⟨initial, hs, ?_⟩
    simp only [Bool.and_eq_true, beq_iff_eq, decide_eq_true_eq] at h
    obtain ⟨⟨⟨⟨⟨h0, hd⟩, h1⟩, h2⟩, h3⟩, h4⟩ := h
    refine ⟨h0, ?_, h1, h2, h3, h4⟩
    revert hd
    split
    · rename_i es hes; intro he; rw [hes, of_decide_eq_true he]
    · intro hf; exact absurd hf (by simp)

end Engine.Machine
