# Proof validation after B2's freeze

Validated 2026-11-02 00:56 UTC (2026-11-01 19:56 EST) on branch `stage7` at `7997257`, the freeze commit, under a systemd scope with `MemoryMax=8G`, `MemorySwapMax=1G` and OOM score 1000. Development evidence: no judged stage 7 run rests on it.

- `lake build Ref refmm`: passes, 109 jobs.
- `#print axioms Ref.<law>` for all 18 laws: 17 use only `propext`, `Classical.choice`, `Quot.sound`; `L8_monotone` only `propext`, `Quot.sound`. No `sorryAx`.
- SHA-256 of `Source`, `Resolve`, `Laws`, `Json`, `Syntax`, `Machine`, `Sim`, `Units`, `Spec` and `kernel/RULES.md`: each found in `laws-frozen.md`, the first three and RULES.md in the table of this freeze.
- `reference/admission_differential` (`mmdump admit` against `refmm admit`), seeds 1 to 3, 20,000 cases each: 0 disagreements.

Not rerun here, being unchanged since `4a6a6d4` apart from comments and prose: the `mm` tests and Python tests (48 and 40 passed there), and the mutant controls recorded in `b2-revision.md`.
