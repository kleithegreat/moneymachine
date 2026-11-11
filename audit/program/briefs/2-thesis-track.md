# Brief 2: a paper account in event contracts, detailed design

For a fresh Claude Fable session, launched by the advisor (`data/builder/run-architect.sh`). The advisor fills in the worktree and branch, and amends this brief first if its decision on `audit/program/architecture.md` (revision 2), or the human's answers to its open questions, change a choice below.

You are the project's architect. Session name: "architect: event account". Commit each finished deliverable; do not push. Your allowance is the scarcest in the project: make targeted reads, spawn no subagents, and write conclusions to disk early.

## Before this brief is launched

The advisor and the human supply three things. Without the first the session does not start. Without the second or third it designs to the architecture's requirements and names what is missing as a blocker.

1. **The venue certificate** (`architecture.md`, section 5.5, items 1 to 8) in `venue/sources.toml`, for one CFTC-designated exchange. The architecture recommends certifying Kalshi first.
2. **The census,** fetched by a builder under that certificate and written to `audit/program/event-account/census.md`: distinct events settling a week over the venue's recent history, by category, with scheduled end within seven days of listing or of any day the market was open, and ladders of thresholds on one underlying counted once. It reads identifiers, event grouping, category and times, and no price or outcome. It is an upper bound on what the agent can buy.
3. **The search API certificate** (section 5.6), which the freeze needs.

## The study, as decided

`audit/program/architecture.md`, sections 2.2, 2.5, 3 (row G), 4 (study 2), 5, 8 and 10, decide the study at the level of choices. Read them first. In short:

- **Question:** does anything a reading agent proposes earn a positive expected net return?
- **The account** starts with cash 1. A purchase pays a stake from cash at the cost of buying a reference stake by walking the order book the daemon recorded at registration, fees included. A payout enters cash when the venue's settlement value is recorded. Nothing else moves cash: no marks, no exits, no deadlines.
- **Null:** no purchase the frozen procedure makes, at its recorded cost, has positive conditional expected net return.
- **Test:** under the null, cash plus the conditional expected payout of open positions is a non-negative supermartingale. The null is rejected at 5% when cash reaches 20, at any time, under any dependence between contracts.
- **The mirror** is a second account from the same record, buying each purchase's complement. If it reaches 20 the procedure is said to lose net of costs. Neither reaching 20 is "not confirmed", never absence of edge.
- **Rules that are part of the experiment** (section 5.3): an open market at the recorded book and no backdating; the reference stake fills or the registration is refused; a horizon cap; one open position per event; the stake rule; the pause.
- **One arm:** the reading agent, on an immutable model snapshot. No ablation, no no-reading arm, no benchmark. The study does not answer whether reading helps.
- **Identity:** a scientific manifest and an operational layer, with three tested properties (section 5.7).
- **Venue:** one designated exchange the human could trade on. Polymarket is no part of the design: neither its hosts nor its recordings are read.

Do not reopen these unless you hit a wall. A wall is information (`CLAUDE.md` §1): stop, say what broke and what you would change, and put it at the top of your report.

## Read

- `CLAUDE.md`, `PROGRESS.md`.
- `audit/reviews/2026-11-10-gpt-rearchitecture.md`, findings 1, 2 and 7 to 11.
- `audit/decisions.md`: the entries of 2026-11-09 17:01 UTC (12:01 EST), on C10.2; of 20:34 UTC (15:34 EST), on the identity split; and of 2026-11-11, pausing Polymarket collection.
- `audit/criteria.md`, stage 10: C10.1, C10.2 and C10.6 only, with their dated revisions.
- `thesis/` on `main`: `registry.py`, `daemon.py`, `retrieval.py`, `harness.py`, `runner.py`, `brief.md`. Skim `market.py`, `positions.py`, `scoring.py` only to see what is specific to perps; they and `thesis/SCORING.md` are hash-frozen for the parked perp instance and are not edited.
- On `thesis-refreeze` (`git show thesis-refreeze:<path>`): the record-before-reply guarantee and the fail-closed transcript audit (commits `35c31f8` and `3e997c0`), which this study carries.
- On `thesis-split`: `audit/stage10/criteria-revision-round11-draft.md`, the parts on C10.2 and on the manifest's file list only.
- `venue/sources.toml`: the certified venue's entry and the `retrieval = true` hosts; `ingest/terms.py`.
- The certified venue's official API documentation and fee schedule, for the fields the certificate names. Reading documentation is not a fetch of data. A page that refuses automated access is read by the human, never worked around.
- `audit/program/event-account/census.md`.

## Design questions to settle, with the architecture's recommendation

1. **The accounting spec,** complete enough for another model to implement from it alone (an upper-case `.md` beside the code), in exact arithmetic over recorded decimals.
   - *Book to cost.* The reference stake in dollars, as a choice with its reason (stage 11's intended size is the natural one). The walk over recorded ask levels, the fee from the recorded schedule with its rounding, and every rounding taken against the account. What "the reference stake fills" means when the book is thin.
   - *Settlement to payout.* The settlement value `x` in [0, 1] for a win, a loss, a split and a void, each from the venue's rules. A payout is what the venue would pay the holder and never more.
   - *Cash.* The order of a purchase and a payout recorded at the same instant. The pause.
   - *The mirror.* Its purchases, stakes and payouts from the same record.
   - *The record.* Which recorded bytes each number is read from.
2. **Validity, written as a proof** for the paper: the supermartingale, Ville's inequality at the maximum of cash, and what the proof assumes of a purchase (A4: the recorded cost is one at which the reference stake could have been bought; the stake is set from what is recorded before the outcome). Show that it survives missing settlement records, the pause, and any rule for which purchases are made, as long as each is decided from the record so far. Do the same for the mirror.
3. **The three properties of section 5.7, as tests.** Property 2 is stated for fixed purchases and stake fractions: cash at every time is non-decreasing in each recorded payout. Say how the pause is handled in its test, since it changes which purchases happen after a missing payout.
4. **The stake rule.** Simulate the account under miscalibrated registered probabilities: overconfident, underconfident, and right about direction only. Compare half Kelly capped at 5% of cash with a fixed fraction. Choose, and state what the agent is told. If the rule gives the agent a reason to misreport its probability, that is a wall.
5. **The horizon cap** (seven days is the starting point) and **the universe.** From the census: which categories exist, what a cap of 7, 14 or 28 days admits, and how the venue's event grouping makes a ladder one bet. No price band and no category cap: validity needs none.
6. **Power,** as the architecture's table extended to the census's count and the chosen stake rule, with the turnover the horizon cap implies. State the numbers below which the design returns to you before any freeze (section 5.4: fewer than 30 distinct admitted events settling a week, or a shakedown week that stakes less than half the account's cash).
7. **Throughput and usage.** Sessions a day and registrations a session inside the personal account's 0.8 ceiling. There is no quota of purchases: the agent registers what it believes in. The shakedown week measures usage, staked share of cash and the venue's rate limits against the design's volume. It is not evidence.
8. **The reading arm.** The certified hosts, the venue's market data through the daemon, and one search API that meets section 5.6. Design the daemon's command for it: query in, recorded response out, content only through the API. If no certificate exists yet, design to the seven requirements and name what it must show.
9. **The agent's brief:** what it is told about markets, the account, the stake rule, the rules of section 5.3 and its tools. It replaces `thesis/brief.md` for this instance; `brief-ablation.md` and `brief-noread.md` have no successor.
10. **The model:** an immutable snapshot id, in the manifest. The forward design makes its cutoff irrelevant to validity, since no purchase is backdated and every outcome is settled after registration, so choose by capability and by the usage the throughput needs.
11. **The identity.** The manifest's file list; the operational layer; the operational commit recorded on each session; what each session was shown as a recorded disclosure.
12. **C10.2,** carried as two guarantees (one ledger record per call, committed before any reply byte; the client as the agent's only channel) with the transcript audit failing closed as a report line. A failed session's purchases stay in the account.
13. **The report** (section 5.2): the judged statistic; both accounts' paths; the realized net return per dollar staked and the planning table's row for the realized turnover; the same purchases costed at the delayed book; purchases of contracts whose event had already happened, apart; the count of instances frozen before this one; each session's disclosures.
14. **The stop rules** of section 8, as the daemon's behaviour: what it does at a rejection, at week 52, at a retired snapshot and at a withdrawn permission.
15. **What leaves `thesis/`** when this instance forks the track, by name, and what moves to the parked perp branch (section 5.8).

## Deliverables

1. **`audit/program/event-account/design.md`:** the design, every number derived or stated as a choice with its reason, every assumption written where a reviewer can attack it.
2. **`audit/program/event-account/criteria-draft.md`,** written as a dated revision of stage 10 for the advisor to commit alone after review (`audit/program/criteria-notes.md` is its frame). Only conditions that judge a number someone could game. Expect two: the rejection rule, and the agreement of an independent implementation of the account. For each: the claim it supports, the derivation of every threshold, a construction of a run that passes while the claim is false, and one that fails while the claim is true. Operational readiness (sessions run, books and settlements arrive, records commit before replies) is a test suite and a report, never a criterion.
3. **`audit/program/event-account/build-plan.md`:** ordered steps for Sonnet. Each step states the behaviour its tests must show, in words complete enough that a session that does not build the step can write the tests from that text alone, without reading code. One commit per step. Mark each step scientific or operational. The independent implementation of the account is not Sonnet's: another model writes it from the spec alone.
4. **The paper:** the thesis section and appendix T rewritten for this instance, with the perp design's text cut to what the parked instance needs. Apply `audit/program/paper-changes.md` first if a builder has not. Rebuild the PDF (`TMPDIR=/tmp nix build .#whitepaper`, copy `result` to `docs/whitepaper.pdf`, remove the link).

## Constraints

- Never read prices or returns from `data/holdout`, an embargo or the forward window [2026-11-01, 2027-01-31), live recordings included. The stopped thesis tracks' registered theses and market choices come from that window: do not use them.
- No Polymarket host and no Polymarket recording is read. No new host is fetched without a certificate. A 403, a 429 or any restriction goes in your report and is never worked around.
- No raw rows of kernel-only sources. No ssh, cluster, campaigns or model sessions.
- Do not edit `audit/criteria.md`, `PROGRESS.md`, `thesis/SCORING.md`, or any file `harness_hash()` covers.
- Read the clock (`date -u`) before writing any time, and pair it with EST (UTC−5).

## Report

End with: the design in one paragraph; the census by category; the criteria, a line each; the build steps, a line each; what you are unsure of; walls; your commits.
