<!-- GPT (openai/gpt-6.1-sol#high), review of the C4.5 v3 qualification before commit, in an isolated directory with the draft, C4.5's text, the kernel and gate; finished by 2026-11-04 00:03 UTC (2026-11-03 19:03 EST). -->
# Criteria review

## Text I would commit

> - *Qualification, subject to dated human approval before any v3 campaign.* v3 uses the frozen implementation, with the departures described in the existing qualification and reviews; this qualification repairs none of them.
>
>   Conditional on the search information, a finalist’s raw holdout p-value is valid, including on bankrupt paths, if its positions are predictable and its integrable net step returns before shortfall absorption have nonpositive conditional means while alive and are almost surely at least −2. The gate’s predictable bets are capped at 1/2. Under these assumptions, the stopped betting process is nonnegative and has the same running maximum as the reported process. Holm requires this conditional validity for every relevant null p-value in the complete frozen family. The frozen implementation does not establish the −2 condition: normalized target weights do not bound actual held exposure, and N2’s wick support is unbounded. These conditions are not certified by observing no violations.
>
>   Beside each campaign’s class, for every finalist v3 reports the kernel’s `turnover` statistic and the minimum committed net step return, separately for the search evaluation used by the gate and any completed authorized holdout result. Turnover is not maximum held gross exposure; the committed returns are after shortfall absorption and do not measure its size. Unavailable results are identified, not reconstructed through extra evaluations or additional market-data reads; the existing missing-evidence rules remain unchanged.
>
>   For every promoted campaign, v3 also reports whether it would satisfy every establishment requirement absent promotion, with audit completeness, distinct filled trials, agents with evaluations, and evidence of receipt of another agent’s evaluation through `history`. Missing or mismatched evidence is identified. Any promotion masking non-establishment is explicitly flagged: reporting exposes that possible false-pass channel but does not remove it.
>
>   These diagnostics are computed after the decisions from committed outputs and permitted audit records, without feedback to searching agents. They are reported, never judged: no class, threshold or verdict rule changes, and no campaign is repaired, replaced or rerun.

## Findings and outcomes they could change

**Do not commit `draft.md` unchanged.** Its main statistical qualification is sound in direction, but its promised diagnostics are not generally recoverable, and reporting alone cannot prevent the masking failure.

### 1. Bound: sufficient, conditional—not established here

The −2 condition is sufficient because \(1+\lambda_t r'_t\ge0\) under the gate’s \(1/2\) cap. Bankruptcy absorption changes terminal betting wealth, but not its running maximum. This establishes **raw p-value validity**, not merely validity among surviving or promoted paths.

The draft should explicitly include predictability, integrability, conditioning on search information, and an **almost-sure** loss condition. A realized return below −2 does not necessarily make the actual betting factor negative; conversely, observing none does not establish the required distributional bound.

**Outcome affected:** the claimed error guarantee—not the frozen smoke-test verdict. Holm also needs valid raw p-values for bankrupt finalists, because those p-values participate before the positive-return filter.

### 2. Maximum held gross exposure: not generally recoverable

A full search trace permits replaying position quantities, but it does not record a complete marked portfolio at every relevant instant. Fill references and funding prices do not establish the maximum exposure-to-equity ratio throughout the run.

Holdout is worse: `reported()` removes the replay prefix, including the boundary events needed to initialize positions and cash reliably. Its reconstructed equity series is not a substitute for that missing state.

The nearest **guaranteed existing notional statistic** is the kernel’s reported `turnover`. It is a turnover diagnostic, not an exposure bound. The replacement text deliberately says exactly that.

**Outcome affected:** diagnostic feasibility and interpretation; no threshold or verdict should change.

### 3. Minimum pre-absorption return: not generally available on holdout

`Run.returns` contains absorbed returns. `gross_returns` also uses absorbed equity and is not the required pre-absorption net return; only its mean reaches the summary.

With a complete search trace, cash flows can reconstruct the shortfall at bankruptcy, when positions have been flattened. The cropped holdout trace does not generally supply the initial state needed for the same calculation.

The universally available replacement is **“minimum committed net step return, after shortfall absorption.”** It cannot test the −2 condition. A bankruptcy before the report window can leave only zero reported returns.

Also, traces are optional: the supplied gate calls do not request them, and a shared `--trace` path is overwritten for successive programs in a batch. The replacement diagnostics require only existing summaries and return blobs.

**Outcome affected:** whether the reporting promise can actually be fulfilled—not p-value validity or the frozen verdict.

### 4. Establishment reporting: useful, but not a safeguard by itself

The frozen text requires “at most 1 campaign not established.” To enforce that literally, establishment must be assessed independently of promotion precedence.

The critical example is:

- one promoted campaign that does not meet establishment requirements;
- one other non-established campaign;
- no additional promotion or unresolved campaign.

If promotion hides the first establishment failure, an exclusive-class count can report a pass. Counting both failures gives **Not established**, not **Failed**. One non-established promotion alone does not exceed the allowance.

Reporting this evidence makes the problem visible; it does not prevent an incorrect automated pass. If the frozen implementation already counts establishment independently, the channel is closed. **The classifier is not attached, so that cannot be verified here.**

**Outcome affected:** **Pass → Not established** in that configuration. Preventing it requires correct application of the existing independent requirement, not merely another report field.

### 5. Scope and evidence

The replacement adds no data access, rerun, diagnostic veto or threshold change. Establishment evidence necessarily also uses the already-required ledger, audit and agent records; simulation trace, summary and returns alone cannot prove receipt of cross-agent history.

The referenced defect tests, approval record and classification implementation are not attached. I therefore would not independently certify the exact “nine defects” count, recorded approval, or implemented establishment counting from this packet.
