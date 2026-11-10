# Brief 1: the positive control, detailed design

For a fresh Claude Fable session, launched by the advisor (`data/builder/run-architect.sh`). The advisor fills in the worktree and branch, and amends this brief first if the adversarial reviews of `audit/program/architecture.md` change a choice below.

You are the project's architect. Session name: "architect: positive control". Commit each finished deliverable; do not push. Your allowance is the scarcest in the project: make targeted reads, spawn no subagents, and write conclusions to disk early.

## The study, as decided

`audit/program/architecture.md`, sections 3 (row F), 4 (study 1), 6 and 8, decide the study at the level of choices. Read them first. In short:

- **Question:** when an edge exists, does the pilot's agent find it more often than cheap search at the same budget?
- **Claim:** at a planted edge that the searcher G100 discovers in a fifth of synthetic markets, the agent discovers it in at least half.
- **Unit:** one synthetic N2 market and one isolated agent session, under the frozen stage 3 harness (`gate/agent/harness.py`, `harness_hash()` = `6a335714…`; verify it) and the frozen pilot kernel. No file either identity hashes may change.
- **Difficulty:** the plant's strength is calibrated on the baseline, before any agent session and without a model.
- **Discovery:** exact capture of the plant by an evaluated program, computed from the kernel's trace, not estimated from returns.
- **Test:** Wald's sequential test of 0.2 against 0.5, both error rates 5%, truncated at 33 markets with terminal cutoff 12.
- **Cut:** the twin-market truth bank, Student intervals, the selected-recovery test, the forced release and kill tests as criteria, the account criterion beyond one identity check.

Do not reopen these unless you hit a wall. A wall is information (`CLAUDE.md` §1): stop, say what broke and what you would change, and put it at the top of your report.

## Read

- `CLAUDE.md`, `PROGRESS.md`.
- `audit/reviews/2026-11-09-fable-meta-review.md`, sections 2 and 6B.
- The paper (`docs/whitepaper.tex`): appendix D1 (the synthetic construction and why a predictable position earns zero without the plant), S5 (the agent's and searchers' budgets), E1.
- `gate/markets.py`: `generate` (the line `eps[k] = clip(sig·x + planted_mask·beta·signal)` is the plant) and `write`.
- `gate/search.py`: `genetic`, `run` (G100).
- `gate/agent/campaigns.py`: `null_market`, `series_inputs`, `REPORT_FROM_DAY`, and how a session is launched and its ledger read.
- `kernel/mm/src/sim.rs`: `enum Event`; `kernel/mm/src/main.rs`: `--trace`.
- On branch `positive-controls` (read with `git show positive-controls:<path>`; it is not merged): the paper's PC2 (the four reference programs, the plant's formula, costs and funding blob), PC3 (isolation judged by what executed), PC6 (accounts, usage forecasts, admission), and `audit/positive-controls-design-check.py.txt`. Reuse what survives; PC4 and PC5 are replaced.

## Design questions to settle, with the architecture's recommendation

1. **The capture measure.** For a program's positions `q[t,c]` at entry price `o[t,c]`, the plant's expected gross return is `beta · Σ q·o·signal` over planted coins and steps. Define a measure that:
   - is exact given the trace and the generator's `signal`;
   - does not change when every position is scaled;
   - compares a program with the locked reference ("at least half the reference's");
   - requires positive expected net return, using the trace's realized fees, slippage and funding.

   Recommended start: alignment `κ = Σ_planted q·o·signal / Σ_all |q·o|` over the search window, material when `κ ≥ κ_R / 2` and `beta·Σ q·o·signal` exceeds realized costs. Say how clipping (`EPS_MAX`), liquidation and the `$10` minimum order enter, or why they do not. Check whether positions must be rebuilt from `Fill` events or can be read from `Decision`.
2. **The measure's own error.** Its false-discovery rate is measured where the answer is known to be chance: G100's evaluated programs on zero-plant markets, scored against the signal that would have been planted. Derive the number of markets needed to bound that rate at 1% and what happens to the test's size if it is not zero.
3. **Calibration on the baseline.** Choose the grid of strengths, the number of calibration markets (at least 1,000 at the chosen strength), and the rule that picks the strength: the largest grid value whose 95% upper bound on G100's discovery rate is at most 0.2. State the compute cost. State what the study does if no grid value qualifies (the architecture's stop rule: back to the architect). Report the reference's net Sharpe at the chosen strength; it is not a target.
4. **The sequential rule, as a table.** For each count of markets judged, the number of discoveries that accepts 0.5 and the number that accepts 0.2. Recompute by exact enumeration the size, the power and the expected count at 0.1, 0.2, 0.3, 0.35, 0.5 and 0.6 (the architecture gives size 0.041, power 0.949, expected 15.3 and 13.3; confirm or correct). State how the calibration's uncertainty about the baseline's rate enters the size.
5. **Order and sealing.** Market ids and seeds are fixed in a manifest before any session. Sessions are isolated, so each market is judged before the next starts. Show that nothing a judged market reveals can reach a later session.
6. **Sessions and accounts.** Carry PC3's rule (isolation is judged by what executed and what was disclosed, never by a tool's name) and PC6's account identity check and admission ceiling. A crash stays in the denominator as a non-discovery. Say which of these are tests and which, if any, judge a number.
7. **The manifest:** the kernel binary's hash, the harness hash, the generator and funding blob hashes, G100's identity, the ids and seeds, the chosen strength, the reference program, the capture code's hash, the stopping table.
8. **The free analyses, done first:** each arm's search-period score distribution from the stage 3 real campaign's ledger, and why that agent stopped at 9 of 100 evaluations (read its transcript). These read search-period records only. If they show a harness fault that would recur, that is a wall.
9. **What is reported and never judged:** as in the architecture's section 6.

## Deliverables

1. **`audit/program/positive-control/design.md`:** the design, every number derived or stated as a choice with its reason, every assumption written where a reviewer can attack it.
2. **`audit/program/positive-control/criteria-draft.md`:** only conditions that judge a number someone could game. Expect two or three: the sequential decision, the measure's false-discovery bound, the calibration bound. For each: the claim it supports, the derivation of every threshold, a construction of a run that passes while the claim is false, and one that fails while the claim is true. Everything else is a test.
3. **`audit/program/positive-control/build-plan.md`:** ordered steps for Sonnet. Each step states the behaviour its tests must show, in words complete enough that a session that does not build the step can write the tests from that text alone, without reading code. One commit per step. Mark the step whose result a judged number depends on (the capture measure): its independent implementation is written by another model from the spec alone.
4. **The paper:** one section replacing PC1 to PC6's role (they exist only on `positive-controls`), holding the derivations. Rebuild the PDF (`TMPDIR=/tmp nix build .#whitepaper`, copy `result` to `docs/whitepaper.pdf`, remove the link).

## Constraints

- Never read prices or returns from `data/holdout`, an embargo or the forward window [2026-11-01, 2027-01-31), live recordings included.
- No raw rows of kernel-only sources. No ssh, cluster, campaigns or model sessions. Calibration runs are the builder's, not yours; a small script to check your arithmetic is fine.
- Do not edit `audit/criteria.md` or `PROGRESS.md`.
- Read the clock (`date -u`) before writing any time, and pair it with EST (UTC−5).

## Report

End with: the design in one paragraph; the criteria, a line each; the build steps, a line each; what you are unsure of; walls; your commits.
