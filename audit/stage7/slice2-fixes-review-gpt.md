# Review of slice 2's fixes (0738c2d) and its run differential (1a922b7)

GPT (`openai/gpt-6.1-sol#high`, opencode), independent review from a clean worktree (no `data/`), at `1a922b7`; started 2026-11-04 10:01 UTC (05:01 EST), reply received 10:09 UTC (05:09 EST). The reply as given, tool transcript omitted.

## Findings, most severe first

1. **Finding 3 remains partially unresolved: the required run differential is incomplete.**  
   **`audit/stage7/rust-port-plan.md:35`; `audit/stage7/slice2-differential-report.json:9–15`**  
   The report excludes N2 and N3: **2,202 of 3,372 runs** remain unchecked. Fixing N1 reconstruction establishes that the harness can proceed, not that slice 2 preserves every promised run. The record honestly discloses this blocker; it is not fabricated evidence. Nevertheless, slice 2 cannot be closed on this evidence. Complete the differential on an authorized host with the frozen funding inputs.  
   **Outcomes affected:** C7.4 behavior preservation and C7.7 exact differential agreement.

2. **Corrected dependencies overwrite existing declaration versions.**  
   **`sources/forum-events/1.json:14`; `sources/governance-events/1.json:14`; `sources/registry.json:12–18`**  
   Both declarations change meaning while remaining version 1. `kernel/SOURCES.md:41,67–69` requires a new version for any declaration change and retention of version files. An earlier registry snapshot now fails its SHA-256 check against these overwritten files. Updating the active hashes does not preserve those versions. Neither declaration having been certified or bound limits current exposure, but supplies no exception to the versioning contract. Retain the original version-1 files and register corrected versions.  
   **Outcome affected:** C7.1’s versioned-declaration contract.

## Areas without additional findings

- **Dependency semantics — no findings.** Each feed now depends on exactly its own polls and sightings. This fixes the erroneous dependency closure and permitted lineage membership at their cause.

- **Input ownership — no findings.** `source::inputs` preserves declaration and field coordinates, cadence and unit as Lean’s `Registry.inputs` does. `Program::sources` matches Lean’s first-occurrence deduplication over all input nodes, not merely reachable weight nodes.

- **Tests — no findings in the asserted behavior.** All six source tests and the new CLI test passed. The dependency assertions would reject the old four-source lists. The ownership assertions distinguish registry coordinates from flattened input indices; the unchanged pre-fix API cannot compile that test. **The exact new CLI test also passes on `0738c2d^`**, as expected: registry selection already worked before these fixes. It adds coverage for original finding 3, not a regression test for a newly corrected CLI defect. Its renaming checks, and the Rust retyping checks, genuinely exercise their claims.

- **N1 explanation — no findings.** I independently reproduced all four reported market hashes. N1 hashes to `b9927e…` excluding the pin and `5a0e5a…` including its `1\n` bytes. The explanation agrees with `dd9580d` and the recorded 2026-10-27 decision; it is not a new workaround introduced here.

- **Differential record/JSON — no additional inaccuracies established.** Manifest identity, corpus hash, program count and market inventories check out. The partial scope is explicit. I did not independently replay the 1,170 runs, so their disagreement and coverage totals remain reported rather than independently reproduced.

- **Other changes — no findings.**

**Verdict: fix first.**
