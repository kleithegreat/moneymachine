# RULES.md draft review: a fresh-context Opus subagent (2026-10-26)

Labeled per CLAUDE.md: GPT first appeared unavailable (a probe hung), so a fresh-context Opus subagent reviewed the
draft, reading only RULES.md, the stage 7 criteria and paper §5. GPT then answered a second probe and reviewed the
same draft (`rules-review-gpt.md`). Both reviews were merged into one revision before the freeze.

Its findings, in order:
1. `floor` can overflow (floor(−2^62, 3600000) < −2^62), contradicting the draft.
2. A checked rule can backdate (`floor(t)` alone; a derived rule ignoring its deps). Proposed: a lower-bound set LB
   that must be non-empty and contain every declared dependency.
3. Corrections inherit their original knownAt under a rule like eventTime + δ. Proposed: the resolver takes the
   later of the rule and the revision's fetch time.
4–10. Strict JSON undefined (BOM, NaN, surrogates, trailing content); number spelling and big integers; −0; booleans
   as integers in Python; name comparison; depth counting and limits for rules and rows; a size limit.
11–14. Malformed rows have no code (proposed `R_ROW`); check-time versus evaluation-time precedence; unreferenced
   members; no short-circuit in `max`.
15–19. The visibility boundary (knownAt ≤ t); dependency semantics (resolver-supplied, maximum over upstream
   revisions); integer storage of Time columns; versioning; a conformance case format.
20. No witness-or-fallback operator: decide whether an absent witness rejects the row or the recorder supplies one.
