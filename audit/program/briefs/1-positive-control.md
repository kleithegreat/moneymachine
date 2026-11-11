# Brief 1: the positive control, detailed design

For a fresh Claude Fable session, launched by the advisor (`data/builder/run-architect.sh`). The advisor fills in the worktree and branch, and amends this brief first if its decision on `audit/program/architecture.md` (revision 2) changes a choice below.

You are the project's architect. Session name: "architect: positive control". Commit each finished deliverable; do not push. Your allowance is the scarcest in the project: make targeted reads, spawn no subagents, and write conclusions to disk early.

## The study, as decided

`audit/program/architecture.md`, sections 3 (row F), 4 (study 1), 6, 8 and 10 (findings 3 to 5), decide the study at the level of choices. Read them first. In short:

- **Question:** when an edge exists, does the pilot's agent find it more often than cheap search at the same budget?
- **Arms.** A is the pilot's agent under the frozen stage 3 harness (`gate/agent/harness.py`, `harness_hash()` = `6a335714…`; verify it) and the frozen pilot kernel, with its brief and its budget of 100 evaluations. B is the searcher G100, run on every study market with a seed fixed in the manifest. No file either identity hashes may change.
- **Unit:** one synthetic N2 market, run by both arms. Only a market where exactly one arm succeeds carries evidence.
- **A session's pick** is its evaluated program with the highest search-period score, read from the ledger the same way for both arms. A session with no evaluation has no pick.
- **The pick carries the plant** when the alignment of its holdings with the planted signal is at least half the locked reference program's on the same market. Holdings are rebuilt from the trace's fills. The measure is a pathwise fact and claims no expected return.
- **Difficulty** is one plant strength, chosen without a model on calibration markets that share no seed with the study's: the grid value at which G100's rate is nearest 0.2, inside 0.1 to 0.3. It is a choice for power. No rate is certified.
- **Test:** Wald's sequential sign test on discordant markets, of `θ ≤ 1/2` against `θ = 0.8`, nominal errors 5%, ending undecided at 60 markets.
- **Three model-free checks** come before any session. Each is a wall, not a criterion.
- **Cut:** a certified baseline rate and its bound, a false-discovery criterion on the measure, "expected net return" in the definition of discovery, the twin-market truth bank, Student intervals, the selected-recovery test, and the release and kill tests as criteria.

Do not reopen these unless you hit a wall. A wall is information (`CLAUDE.md` §1): stop, say what broke and what you would change, and put it at the top of your report.

## Read

- `CLAUDE.md`, `PROGRESS.md`.
- `audit/reviews/2026-11-10-gpt-rearchitecture.md`, findings 3 to 5, and its lines on Argon's findings 2, 3 and 14.
- `audit/reviews/2026-11-09-fable-meta-review.md`, sections 2 and 6B.
- The paper (`docs/whitepaper.tex`): appendix D1 (the synthetic construction and why a predictable position earns zero without the plant), S5 (the agent's and searchers' budgets), E1.
- `gate/markets.py`: `generate` (the line `eps[k] = clip(sig·x + planted_mask·beta·signal)` is the plant; the clip comes after the plant is added) and `write`.
- `gate/search.py`: `genetic`, `run` (G100), and the score it maximizes.
- `gate/agent/campaigns.py`: `null_market`, `series_inputs`, `REPORT_FROM_DAY`, and how a session is launched and its ledger read.
- `kernel/mm/src/sim.rs`: `enum Event`; `kernel/mm/src/main.rs`: `--trace`.
- On branch `positive-controls` (read with `git show positive-controls:<path>`; it is not merged): the paper's PC2 (the four reference programs, the plant's formula, costs and funding blob), PC3 (isolation judged by what executed), PC6 (accounts, usage forecasts, admission), and `audit/positive-controls-design-check.py.txt`. Reuse what survives; PC4 and PC5 are replaced.

## Design questions to settle, with the architecture's recommendation

1. **The alignment measure,** specified for an independent implementation (an upper-case `.md` beside its code).
   - Recommended start: the cosine between dollar holdings and the signal, over all coins and all steps of the search window, the signal being zero off the planted coins.
   - Holdings are rebuilt from `Fill` events. `Decision.qty` is an order and not a holding: a rejected or unfilled order holds nothing, and a liquidation ends a holding. Say which trace events change a holding and at which instant.
   - Say which price turns a quantity into dollars, and show that the measure does not change when every holding is scaled.
   - The measure reads no return, so the generator's clip (`EPS_MAX`), liquidation losses, costs and the `$10` minimum order do not enter it. Confirm that from the code, or say what does enter.
   - Fix the edge cases: a pick that never holds anything, a pick held on one step, and a reference whose own alignment is near zero.
   - The threshold, half the reference's alignment, is a choice. State its reason and what a looser or stricter one does to both arms.
2. **The pick.** The ledger field that is the search-period score, the tie rule, and a session whose every evaluation failed. Show that G100's returned program is its own pick under the same rule, or say what differs.
3. **Difficulty.** The grid of strengths, the number of calibration markets at each, the rule (the grid value at which G100's rate is nearest 0.2, inside 0.1 to 0.3) and the compute cost. The rate need not vary monotonically with strength. If no grid value lands inside 0.1 to 0.3 the design returns to you. Derive what an error in the chosen strength does to power (`arithmetic.py.txt`, `sign_test`: agent 0.5 against G100 at 0.1 and at 0.3), and confirm that it cannot move the size.
4. **The three model-free checks,** each with its sample size derived from what it must detect.
   - A grid strength puts G100's rate inside 0.1 to 0.3.
   - On zero-plant markets, scored against the signal that would have been planted, G100's rate is at most a quarter of its rate at the chosen strength. Specify the counterfactual signal exactly: actual strength zero, the same seed's signal.
   - G100's picks from zero-plant markets, re-run on fresh zero-plant markets, average a net score at or below zero. This is the evaluator's leak check: the stage 1 canary misses a leak worth Sharpe 2 in 99% of runs. State the smallest leak the check detects with 95% probability, and the number of picks that takes.
5. **The sequential rule, as a table.** For each count of discordant markets, the number of agent wins at which each boundary is crossed. Recompute by exact enumeration the size, the probability of each decision and the expected count for the rows of the architecture's table (size at most 0.037; agent 0.5 against G100 0.2: upper 0.888, 30 markets expected). Confirm or correct.
6. **What each decision may be called** (architecture, section 6): the upper decision is that the agent's rate exceeds G100's at 5%; the lower is that an advantage of four in five discordant markets is rejected, and never "no better"; undecided is inconclusive.
7. **Order and sealing.** Market ids and both arms' seeds are fixed in a manifest before any session. A market is judged when both arms have run it, and before the next starts. Show that nothing a judged market reveals can reach a later session, and that G100's run on a market cannot reach the agent's.
8. **Sessions and accounts.** Carry PC3's rule (isolation is judged by what executed and what was disclosed, never by a tool's name) and PC6's account identity check and admission ceiling. A crash is a non-discovery for its arm and is never replaced, so the claim includes the agent's reliability. Say which of these are tests and which, if any, judge a number.
9. **The served model.** The harness pins a model id; the provider may change what it serves within three weeks. Say what is recorded for each session, and what the report says if it changed.
10. **The manifest:** the kernel binary's hash, the harness hash, the generator and funding blob hashes, G100's identity and seed, the market ids and seeds, the chosen strength, the reference program, the alignment code's hash, the stopping table.
11. **The free analyses, done first:** each arm's search-period score distribution from the stage 3 real campaign's ledger, and why that agent stopped at 9 of 100 evaluations (read its transcript). These read search-period records only. If they show a harness fault that would recur, that is a wall. Known already: `kernel/DSL.md`, which the frozen harness shows the agent, advertises inputs N2 lacks, and 11 of 208 evaluations in C4.5 v3 named one (`docs/future-work.md`). Those evaluations count against the budget. Say what this does to the claim, since the file cannot change without forking the harness.
12. **What is reported and never judged:** as in the architecture's section 6, including whether each session evaluated any plant-carrying program.

## Deliverables

1. **`audit/program/positive-control/design.md`:** the design, every number derived or stated as a choice with its reason, every assumption written where a reviewer can attack it.
2. **`audit/program/positive-control/criteria-draft.md`:** only conditions that judge a number someone could game. Expect two: the sequential decision, with the definitions it rests on (the pick, the alignment threshold, the crash rule), and the agreement of an independent implementation of the alignment measure. For each: the claim it supports, the derivation of every threshold, a construction of a run that passes while the claim is false, and one that fails while the claim is true. The model-free checks are walls before the study, and everything else is a test.
3. **`audit/program/positive-control/build-plan.md`:** ordered steps for Sonnet. Each step states the behaviour its tests must show, in words complete enough that a session that does not build the step can write the tests from that text alone, without reading code. One commit per step. Mark the step whose result the judged number depends on (the alignment measure): its independent implementation is written by another model from the spec alone.
4. **The paper:** one section holding the study's derivations, in the role PC1 to PC6 had on `positive-controls`. Apply `audit/program/paper-changes.md` first if a builder has not. Rebuild the PDF (`TMPDIR=/tmp nix build .#whitepaper`, copy `result` to `docs/whitepaper.pdf`, remove the link).

## Constraints

- Never read prices or returns from `data/holdout`, an embargo or the forward window [2026-11-01, 2027-01-31), live recordings included.
- No raw rows of kernel-only sources. No ssh, cluster, campaigns or model sessions. Calibration runs are the builder's, not yours; a small script to check your arithmetic is fine.
- Do not edit `audit/criteria.md` or `PROGRESS.md`.
- Read the clock (`date -u`) before writing any time, and pair it with EST (UTC−5).

## Report

End with: the design in one paragraph; the criteria, a line each; the build steps, a line each; what you are unsure of; walls; your commits.
