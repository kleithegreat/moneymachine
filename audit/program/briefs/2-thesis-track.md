# Brief 2: the thesis track on event contracts, detailed design

For a fresh Claude Fable session, launched by the advisor (`data/builder/run-architect.sh`). The advisor fills in the worktree and branch, and amends this brief first if the adversarial reviews of `audit/program/architecture.md`, or the human's answers to its open questions, change a choice below.

You are the project's architect. Session name: "architect: thesis track". Commit each finished deliverable; do not push. Your allowance is the scarcest in the project: make targeted reads, spawn no subagents, and write conclusions to disk early.

## The study, as decided

`audit/program/architecture.md`, sections 2.3 to 2.5, 3 (rows E and G), 4 (study 2), 5, 8 and 10, decide the study at the level of choices. Read them first. In short:

- **Question:** does anything a reading agent proposes earn a positive expected net return?
- **A thesis** is a paper position in an exchange-traded event contract, with the agent's probability, registered before the outcome. The first venue is Polymarket's public data API, already certified and on the retrieval allowlist (`venue/sources.toml`, `[polymarket]`).
- **Claim:** the paper portfolio of the agent's registered positions, sized by rule and priced at recorded quotes with fees, has a positive mean weekly net return.
- **One arm:** the reading agent. Three comparisons are replayed without a model from recorded bytes: the market price as a forecast, a coin-flip side on the same markets, and the same positions from the next recorded quote.
- **Unit:** the calendar week of the marked-to-market portfolio. No clusters, no ablation, no benchmark.
- **Protocol:** the one-sided Student statistic of weekly net returns, at week 26 (level 1%) and week 52 (level 4%), with critical values set by simulation at the worst null the admission rules allow.
- **Admission rules, part of the test:** one open position per event, a cap per category, an entry-price band.
- **Accounting:** fill at the ask of the daemon's own quote at registration plus the fee; mark at the recorded bid; a missing mark carries forward; a position never resolved loses its stake; no position ever leaves the portfolio.
- **Identity:** a scientific manifest and an operational layer, with the invariant that scoring is a pure function of recorded bytes and the manifest.
- **Throughput:** about 60 admitted positions a week, measured in a shakedown week that is not evidence.

Do not reopen these unless you hit a wall. A wall is information (`CLAUDE.md` §1): stop, say what broke and what you would change, and put it at the top of your report.

## Read

- `CLAUDE.md`, `PROGRESS.md`.
- `audit/decisions.md`: the entries of 2026-11-09 17:01 UTC (12:01 EST), on C10.2, and 20:34 UTC (15:34 EST), on the identity split.
- `audit/criteria.md`, stage 10: C10.1, C10.2 and C10.6 only, with their dated revisions.
- `thesis/` on `main` (1,642 lines): `registry.py`, `daemon.py`, `retrieval.py`, `harness.py`, `runner.py`, `brief.md`. Skim `market.py`, `positions.py`, `scoring.py` only to see what is specific to perps; they and `thesis/SCORING.md` are hash-frozen for the parked perp instance and are not edited.
- On `thesis-refreeze` (`git show thesis-refreeze:<path>`): the record-before-reply guarantee and the fail-closed transcript audit (commits `35c31f8` and `3e997c0`), which this study carries.
- On `thesis-split`: `audit/stage10/criteria-revision-round11-draft.md`, the parts on C10.2 and on the manifest's file list only.
- `venue/sources.toml`, `[polymarket]` and the six `retrieval = true` hosts; `venue/sources/datalayer.json`, the two Polymarket feeds; `ingest/terms.py`.
- `gate/gate.py`: the betting test, for the reported wealth.
- The venue's public API documentation for the market fields you rely on (event grouping, category, scheduled end, fees, resolution status). Reading documentation is not a fetch of data.

## Count first, before designing

How many distinct events resolve a week, by category, among markets a small stake could trade? Take it from the data layer's closed-market recordings, reading only identifiers, event grouping, category or tags, close time and volume, never a price or an outcome. Record the access in the design, as the Holdout rule asks. If fewer than 30 a week remain after the admission rules you intend, that is a wall: the study's power rests on this count (`architecture.md`, section 9, item 2).

## Design questions to settle, with the architecture's recommendation

1. **Universe and admission.** Which categories are in. The architecture's recommendation: exclude sports and games of chance, where prices are the fastest and most professionally set, and treat a ladder of thresholds on one underlying as one event. Then the liquidity floor, the entry-price band, the per-category cap, the cap on a contract's scheduled end (28 days is the starting point), and the stake as a fraction of initial equity so that open stakes stay inside it. Each is a scientific parameter: derive it or state it as a choice with its reason.
2. **The accounting spec,** complete enough for another model to implement from it alone (an upper-case `.md` beside the code). Fill, fee, weekly mark, resolution, a disputed or split resolution, a missing mark, a position never resolved, an early exit by the agent at the bid, the week's boundary, and the weekly net return as a fraction of initial equity. Exact arithmetic over recorded decimals, as the perp spec does.
3. **The worst admissible null.** The test's size must be at most its level under every null the admission rules allow. Specify that family for the simulation that sets the two critical values: positions bought at the top of the price band, concentration at the category cap, weeks in which one headline resolves positions across categories, and weeks with few positions. The architecture's simulation (one-sided 5% Student test, mean-zero favorites: size 6.4% at 26 weeks with 20 independent clusters a week at price 0.90, 26% with one cluster at 0.95) is the starting point, not the answer. If no price band and cap give a usable test, that is a wall.
4. **Power,** as a table over per-bet effect and realized independent bets a week, at both looks, from the same simulation.
5. **Paper fills.** The data API's best ask carries no size. Decide what a fill at that ask may claim, what the liquidity floor buys, and what the report must say. If the design needs order-book depth, it needs a host the certificate does not name: say so; that is the human's decision, not a workaround.
6. **Throughput.** Sessions a day and registrations a session that reach about 60 admitted positions a week inside the personal account's 0.8 ceiling. The shakedown week measures usage and realized breadth. State the numbers below which the design returns to you before any freeze.
7. **The reading arm.** The agent reads the six certified hosts and one search API that meets the architecture's section 5.4. The search API is a precondition of the freeze: without it the treatment is starved, and a null says little. Design the daemon's command for it (query in, recorded response out, content only through the API). If the advisor's survey has produced a certificate, design to it; if not, design to the requirements and name what the certificate must show.
8. **The agent's brief:** what it is told about markets, admission, scoring and its tools. It replaces `thesis/brief.md` for this instance; `brief-ablation.md` and `brief-noread.md` have no successor.
9. **The model,** which is in the manifest. The forward design makes its cutoff irrelevant to validity, so choose by capability and by the usage the throughput needs.
10. **The identity.** The manifest's file list; the operational layer; the test that replays one record under two operational commits and requires identical scores; the operational commit recorded on each session; what each session was shown as a recorded disclosure.
11. **C10.2,** carried as two guarantees (one ledger record per call, committed before any reply byte; the client as the agent's only channel) with the transcript audit failing closed as a report line. A failed session's positions stay in the portfolio.
12. **The report:** the judged statistic at each look, then everything reported and never judged (`architecture.md`, section 5.5).
13. **What leaves `thesis/`** when this instance forks the track, by name, and what moves to the parked perp branch.

## Deliverables

1. **`audit/program/thesis-events/design.md`:** the design, every number derived or stated as a choice with its reason, every assumption written where a reviewer can attack it.
2. **`audit/program/thesis-events/criteria-draft.md`,** written as a dated revision of stage 10 for the advisor to commit alone after review. Only conditions that judge a number someone could game. Expect two: the protocol, and the agreement of an independent implementation of the accounting. For each: the claim it supports, the derivation of every threshold, a construction of a run that passes while the claim is false, and one that fails while the claim is true. Operational readiness (sessions run, marks arrive, records commit before replies) is a test suite and a report, never a criterion.
3. **`audit/program/thesis-events/build-plan.md`:** ordered steps for Sonnet. Each step states the behaviour its tests must show, in words complete enough that a session that does not build the step can write the tests from that text alone, without reading code. One commit per step. Mark each step scientific or operational. The independent accounting implementation is not Sonnet's: another model writes it from the spec alone.
4. **The paper:** the thesis section and appendix T rewritten for this instance, with the perp design's text cut to what the parked instance needs. Rebuild the PDF (`TMPDIR=/tmp nix build .#whitepaper`, copy `result` to `docs/whitepaper.pdf`, remove the link).

## Constraints

- Never read prices or returns from `data/holdout`, an embargo or the forward window [2026-11-01, 2027-01-31), live recordings included. The stopped thesis tracks' registered theses and market choices come from that window: do not use them.
- No new host is fetched without a certificate. A 403 or a restriction goes in your report and is never worked around.
- No raw rows of kernel-only sources. No ssh, cluster, campaigns or model sessions.
- Do not edit `audit/criteria.md`, `PROGRESS.md`, `thesis/SCORING.md`, or any file `harness_hash()` covers.
- Read the clock (`date -u`) before writing any time, and pair it with EST (UTC−5).

## Report

End with: the design in one paragraph; the event count by category; the criteria, a line each; the build steps, a line each; what you are unsure of; walls; your commits.
