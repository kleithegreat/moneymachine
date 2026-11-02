# Independent review: refreeze blocked

The bundle fixes the principal reported failures, but **this tree is not ready to refreeze**. Remaining counterexamples can change forecast outcomes, benchmark probabilities, sizing, resolution timeliness, and recording integrity.

**Scope:** I read the supplied diff, the requested specifications and reports, and the changed files whole. This was static review with hand-derived cases and synthetic arithmetic—not an independently executed pytest run. No track data was read; nothing was edited.

## Blocking findings

### F1. The rounding fix changes the frozen thresholds

**Outcome changed:** cost cells, binary forecast outcomes, invalidation times, and potentially admissions.

`thesis/positions.py:57` replaces the $1000 boundary with approximately `$1000.000000001`. This repairs the intended exact-$1000 case, but also admits genuinely larger notionals to the cheaper cell. `thesis/positions.py:192` similarly triggers invalidation for losses genuinely smaller than L. The admission comparison also uses the widened boundary (`thesis/positions.py:213`).

The frozen rules require exact discrete decisions; their numerical comparison tolerances do not authorize moving these boundaries (`thesis/SCORING.md:35`; `audit/criteria.md:758–759,863`).

**Concrete cost counterexample:**

- N = `1000.0000000005`, entry reference 100.
- Buy cells: 1 bp / 8 bps; sell cells: 1 bp / 8 bps.
- Exit reference 100.2; fee 0.00045.
- The entry genuinely exceeds $1000, so it requires 8 bps.
- Correct R_net ≈ **−0.00050249928**, hence **o = 0**.
- The widened comparison selects 1 bp, producing R_net ≈ **+0.00019781572**, hence **o = 1**.

This N is attainable through an allowed high-precision L; it does not require an invalid registration.

Likewise, a short from 100 closing at 110 has a 10% gross loss. With L = `0.10000000000005`, it has **not** reached L, but the widened invalidation comparison triggers.

**Required:** preserve the mathematical boundaries through suitable arithmetic, rather than a blanket epsilon. If deliberately retaining wider frozen thresholds, obtain the human’s authorization and record the change prospectively. Calling it “rounding” does not make every newly admitted case a tie.

### F2. Exactly-zero outcomes remain wrong—with nonzero fees and one leg

**Outcome changed:** o, Brier scores, base-rate window counts, and paired scores.

The report dismisses this boundary as requiring two offsetting legs and no fee (`audit/reviews/2026-11-02-thesis-bundle.md:72`). That is false.

Take:

- N = 500;
- fee f = 0.00045;
- entry and exit cost cells c = 0.0001;
- entry reference `99.9450045 = 100(1−c)(1−f)`;
- exit reference `100.0550045 = 100(1+c)(1+f)`;
- zero funding.

Both trades remain below $1000. Writing their adverse fills as P_in and P_out:

\[
P_{\rm out}(1-f)=P_{\rm in}(1+f).
\]

Therefore the exact net PnL is zero, with **one long leg and positive fees and execution costs**. Binary64 evaluation of the implementation’s expression gives approximately `+7.827×10⁻¹⁵` dollars, hence **o = 1** at `thesis/positions.py:74–80`.

The frozen answer is **o = 0**, explicitly (`audit/criteria.md:767,869`).

**Required:** an exact-zero/sign-boundary regression and arithmetic that preserves the required outcome classification. A blanket “small positive means zero” tolerance would introduce a different incorrect threshold.

### F3. Sizing during a reference’s availability lag is still unsettled—and reachable

**Outcome changed:** immutable N, reservations, and cap admission.

The ordinary missing-funding fix is sound, but the excluded intra-lag case is not resolved by noting that sessions start at 00:10.

For a builder leg, consider registration at **h + 1 minute**:

- Latest reconciled equity is $10,000.
- An existing long has q = 10; the previous sealed reference is 100.
- Hour h’s funding row, rate 0.001, is already returned.
- M(h) is not available until the five-minute seal.

The implementation applies h’s funding immediately, using the earlier reference, and sizes from approximately **$9999**, giving **N = 999.9** at L = 0.1 (`thesis/positions.py:133–144,210–214`). GPT waits for reconciliation and uses **N = 1000** (`thesis/tests/gpt_positions.py:774–789,834–838,1031–1044`).

An **unsealed** reference is not yet a reference established to be **missing**. The frozen availability and latest-reconciled-equity requirements support waiting, not prematurely valuing this hour using the missing-reference fallback (`audit/criteria.md:757,786,791–794`).

This matters operationally: a main session may last until 01:10, and later sessions/readiness waits can cross any hourly boundary (`thesis/harness.py:18`; `thesis/runner.py:172–178`). Registrations are not confined to 00:10.

**Required:** settle the reconciliation/availability rule in a dated revision and test both sides of each lag boundary. Do not exclude this window from the differential.

### F4. A warm candle cache can hide an opening reference that a cold cache returns

**Outcome changed:** fills, reservation release, equity, and subsequent sizing/admission.

In-progress rows are constructed **only from the current fetch**, while cached rows are returned only after their closes become available (`thesis/market.py:113–116,149–155`).

Consequently:

1. Cache a completed candle opening at H.
2. Request an earlier cutoff, H + 10 minutes.
3. The cached H row is filtered out as not yet completed.
4. Fetching starts after the latest cached row, so no H progress row is reconstructed.
5. H’s already-available open disappears.

With a cold cache, that same cutoff returns `[H, open, None]`.

For a position whose horizon is H, this can mean “closed and reservation released” versus “still open and reserved.” With a preceding close of 100, H’s open of 110, and q = 10, it can also change marked equity by $100.

Past-cutoff reads are not hypothetical API usage: the benchmark explicitly replays at Monday’s cutoff (`thesis/runner.py:229`), and concurrent callers capture cutoffs before obtaining the market-cache lock.

**Required:** project cached candles to the requested cutoff—open present, close null when appropriate—and test cache-order independence. The synthetic adapter in the differential already performs that projection; production `Market.bars` does not (`thesis/tests/test_positions_differential.py:94–102`).

### F5. Resolution still fails C10.5 under unrelated-market failures or slow passes

**Outcome changed:** missing or late scores/statuses, and misleading resolution timestamps.

There are three related failures.

1. **Unrelated markets block a resolvable thesis.** Resolution fetches every market ever used by an account, including those belonging only to other theses (`thesis/runner.py:94–95,250–257`). If thesis X is fully resolvable but an unrelated Y request repeatedly fails, X receives “missing data” instead of its available score. That violates scoring within two hours of the needed data becoming available (`audit/criteria.md:876`).

2. **A replay exception is not safely handled.** If data fetching succeeds but `positions.run` raises, `data` remains non-null and `managed` remains empty. A resolvable outcome then reaches `managed[th["id"]]`, raising again outside the handler (`thesis/runner.py:250–260`). No fallback status is written for that thesis or the remaining loop.

3. **Ninety minutes is scheduling slack, not a deadline guarantee.** Fetching and replay happen before status publication, without an overall deadline. The five-minute wait starts after the preceding pass finishes (`thesis/runner.py:284,315–321`). A pass starting at T + 95 minutes and taking 31 minutes publishes late, while its content still says `"at": T + 95 minutes` (`thesis/runner.py:261–263`).

**Required:** separate deadline/status publication from potentially slow market work, isolate forecast resolution by its required inputs, handle managed-replay failure independently, and timestamp actual publication. Test elapsed wall time and failures in both fetching and replay—not just instantaneous exceptions.

### F6. A recovered benchmark can register a probability different from its own base rate

**Outcome changed:** benchmark p and Brier score; potentially erroneous “no base rate” skips.

The benchmark’s probe N comes from equity replayed at **Monday**, while the actual registration sizes at its later **t_r** (`thesis/runner.py:229–239`; `thesis/registry.py:142–144`).

Costs depend on N. Therefore the probe’s p_ref need not equal the registered thesis’s p_ref.

**Concrete case using the frozen ETH cells:**

- Initial Monday probe N = $1000.
- BTC registers, then the batch is interrupted.
- BTC subsequently enters and gains enough that resumed ETH registration has N > $1000.
- Give ETH historical windows a 10.5 bp reference-price increase and zero funding.
- With the frozen 0.00045 fee and ETH sell-$10k cell:
  - entry using ETH’s $1000 buy cell gives R ≈ **+0.00000907505**;
  - entry using ETH’s $10k buy cell gives R ≈ **−0.00001279779**.

Those cells are in `venue/hyperliquid/execution.json:18–25`.

With ten such complete windows, the probe estimates **11/12**, while the registered notional estimates **1/12**. The request retains the former as p; registration records the latter as p_ref.

That violates the benchmark definition, **“p is its base rate”** (`audit/criteria.md:817`).

**Required:** derive benchmark sizing, base rate, and p together from the registration’s committed inputs and time. Add an interrupted-batch regression in which equity changes before recovery. The current flat, zero-cost benchmark fixtures cannot expose this.

### F7. Hole repair still silently abandons data the criteria require

**Outcome changed:** permanently unresolved outcomes, missing base-rate windows, and indefinitely stale sizing equity.

`fetch_start` repairs only gaps **between cached rows within 90 days** (`thesis/market.py:31,42–45`). Thus:

- missing rows before the first cached row are never revisited;
- a hole ages out after 90 days, even if it remains necessary to resolve a thesis or reconcile the account;
- older base-rate holes remain missing even after the venue supplies them.

The maximum holding horizon does not bound how late missing data may arrive. C10.5 requires scoring after availability, and the track continues after exit (`audit/criteria.md:876,889`). No frozen rule expires that obligation after 90 days.

**Required:** retain and retry outstanding required gaps, including coverage edges. A bounded repair workload is reasonable; silently expiring the obligation is not. The builder report’s “accepted limit” is not a criteria revision.

### F8. Atomic writes do not cure legacy poisoned body files

**Outcome changed:** newly recorded polls reference corrupt bodies; discovery feeds can terminate recording again.

The new temporary-write/fsync/rename sequence protects **new** final paths. But reuse still checks only `raw.exists()` (`ingest/datalayer.py:103–111`).

On a volume produced by the old writer:

1. A truncated `raw/<digest>.gz` already exists.
2. A later poll receives the complete, identical body.
3. The file is reused unchecked.
4. Another successful poll references the corrupt body.

For a discovery index, `body()` then raises during `poll`, escaping the recording loop (`ingest/datalayer.py:65–67,81–82,128–129`).

This is acknowledged but left unfixed in the report (`audit/reviews/2026-11-02-thesis-bundle.md:81`). A thesis refreeze changes the campaign—not the shared datalayer volume.

**Required:** validate decompression and content hash before reusing legacy bodies; preserve damaged bytes and record repair/quarantine provenance. Test a pre-existing truncated **final `.gz`**, not only failures produced by the new writer. I am not claiming such damage occurred; no recordings were inspected.

### F9. Listing refresh still precedes potentially lengthy registration preparation

**Outcome changed:** acceptance of a delisted market at t_r.

The refresh removes the session-snapshot dependency, but it occurs **before** fetching the account’s bars/funding. Only afterwards does registration read t_r and validate the earlier listing observation (`thesis/runner.py:89–92`; `thesis/registry.py:134–135`).

A market delisting during that preparation is still accepted. The added test covers delisting before `inputs`, not during it (`thesis/tests/test_runner.py:442–451`).

**Required:** move final eligibility validation to the commit boundary, with an explicit observation/cutoff convention and recorded provenance. Test delisting while input preparation is delayed. The criterion requires eligibility as of t_r, not merely a fresher session snapshot (`audit/criteria.md:749–751`).

## Hand checks of the principal fixes

| Case | Recomputed result and assessment |
|---|---|
| **Invalidation at a close** | Long from 100, L = 0.05, held bar closes at 94: R_gross = −0.06. If that bar ends at 12:00, actionability is 12:02 and exit is 13:00—not 12:00, irrespective of the 12:00 open. The changed close lookup implements this (`thesis/positions.py:185–193`). F1 concerns its widened boundary, not the close-selection fix. |
| **Exactly $1000 cost cell** | q = 1000/50.36. The mathematical reference notional is exactly $1000. At 1 bp, buy fill = **50.365036**; at 8 bps it would be **50.400288**. Selecting the former fixes the original case. F1 shows why widening the boundary is not an exact repair. |
| **Sizing after missing funding** | q = 10 from 100; funding at hour 30 is missing; price becomes 110 from hour 31. The account cannot use the later $100 gain as reconciled equity. E_r stays $10,000, b = $100, N = $1000—not $1010. The fix does this and retains immutable registered sizes when the row arrives (`thesis/positions.py:133–144,207–215`). F3 is the separate intra-lag case. |
| **Missing-data deadline** | With zero-duration five-minute passes, first status now falls in **[T+90 min, T+95 min)**, rather than after T+120. Later resolution is allowed because “missing data” does not mark the thesis resolved (`thesis/runner.py:245–263`). F5 shows the untested elapsed-time and failure-isolation paths. |
| **Crash during a day** | Main has committed `main-1`, then dies before `session_end`. Restart adds an interrupted end, does not rerun main, reloads its saved snapshot, and runs `ablation-main-1` then noread. A second restart does not repeat them. After the date expires, remaining sessions are reported missed (`thesis/runner.py:149–213,306–312`). The ledger-driven recovery is sound for this case. |
| **Interrupted benchmark batch** | BTC committed; ETH raises. Same-day recovery starts with ETH, not BTC. Recovery after Monday logs ETH and every remaining market missed individually (`thesis/runner.py:265–269,295–304`). Enumeration is fixed; F6 concerns the probability of a delayed registration. |

The partial-spread fix also has the right central result: an entered X leg can close at T even when Y never entered; Y does not subsequently open, the forecast stays unresolved, and X’s actual PnL remains in the account (`thesis/positions.py:145–173`). The reservation timing needs the clarification below.

For sequential recorder operation, the newline separator preserves existing bytes and prevents a newly appended record joining a torn tail; complete JSON lacking only its newline survives (`ingest/live.py:24–43`). It does **not** reconstruct successful old records already concatenated into an invalid historical line. Such a line is skipped intact; that limitation must not be described as recovered history.

## The differential: useful evidence, narrower than claimed

There are **three semantic readings implemented by four source replacements** (`thesis/tests/test_positions_differential.py:25–39`).

### Are the patches sound?

- **Quantity and R_gross use the reference open:** **yes.** Quantity is explicit in `SCORING.md:32`; using the reference open for gross return is consistent with keeping execution costs outside gross PnL. The criteria should explicitly identify P_e as that reference.
- **Funding after a missing core bar uses the previous close:** **consistent with SCORING.md, but not an unambiguous reading of all frozen text.** `SCORING.md:39` says previous close when available; the October 23 revision says latest earlier reference (`audit/criteria.md:794`). This is a specification conflict, not merely an oracle mistake. Resolve it by dated revision before relying on patched agreement.
- **A never-entered leg need not hold a reservation forever:** **sound in principle.** However, the replacement does not establish all release-time semantics, and the differential never directly compares `reservation_released_at`. The oracle can still assign a later retrospective release when a previously absent entry/exit reference eventually appears (`thesis/tests/gpt_positions.py:568–585`).

### What it actually establishes

It supplies useful independent-algorithm evidence for the selected generated paths. It is **not** agreement with the untouched GPT implementation, nor an end-to-end check of production market adaptation and persistence.

Important gaps:

- The generator deliberately removes registrations inside the first five minutes of an hour (`test_positions_differential.py:82–84`), excluding F3.
- `close()` uses **relative** `1e-9`, permitting about **$10⁻⁵ at $10,000**, not the claimed $10⁻⁹ dollar agreement (`:125–128`; compare `audit/criteria.md:863`).
- Both replay histories receive **GPT’s sizing**, not their independently calculated sizing (`:140–147`). Sizing differences are checked locally, but their downstream consequences are not independently propagated.
- Entry references, quantities and fill prices are not directly compared; entry time and exit reference are (`:170–178`).
- There is no hourly equity-trace comparison or direct reservation-release comparison; only final sizing equity is checked (`:183–185`).
- It bypasses `Market.bars`, the ledger, scheduling and restart behavior.
- Symmetric buy/sell cells, no fallback terms, and the acknowledged omitted boundaries restrict coverage (`:77–79,104–116`).

**Required:** retain the independent source and distinguish raw disagreement from approved-spec agreement; adopt the resolved rules through the independent checker’s specification; add deterministic boundary cases, production-adapter tests, absolute money comparisons, and intermediate state comparisons.

## Required dated specification decisions

Append these prospectively; do not edit the frozen paragraphs.

### 1. Quantity and R_gross: **open, not adverse fill**

The code is right under SCORING.md, but the umbrella criteria are ambiguous.

> P_j,e denotes the leg’s reference opening price, before execution costs. Quantity is w_j N/P_j,e. R_gross uses reference prices and excludes funding, fees and execution costs. Adverse fills determine net PnL and fees.

### 2. Funding after a missing bar: **resolve the conflicting texts**

The code follows SCORING.md; the literal “latest earlier reference” wording is insufficient for core candles.

To preserve the scored convention:

> Funding uses the settled hour’s opening reference when present. Otherwise, for core candles, take the latest earlier bar and use its available non-null close, otherwise its open. For builder markets, use the latest earlier sealed opening reference. An unsealed reference is not yet established missing.

Also specify when an hour is reconciled and what sizing uses before then. That resolves F3 rather than merely documenting its exclusion.

### 3. Reservation release: **actual closure versus pending suppression**

Releasing a never-entered leg is justified; exact timing is under-specified.

> Once an exit becomes effective, pending legs are suppressed and cannot subsequently enter. A reservation is released when every leg is either suppressed or confirmed closed using an available closing reference. Missing funding does not retain a closed position’s reservation. State explicitly the suppression boundary and the fill-reference availability time used for release.

The current code largely implements this distinction, but it needs lag-boundary and missing-reference fixtures.

### 4. Core open available from δ, once seen: **reasonable design, not yet frozen**

The frozen text does not explicitly give core opens this separate availability rule. The choice can change reservations and admissions, so it cannot remain only a docstring/report decision (`thesis/market.py:142–155`; report `:59`).

> A core candle’s opening reference may be used independently of its close, no earlier than H+δ and its qualifying observation. Until H+1h+δ, its close is null. Completed and in-progress representations must give identical as-of opening references, independent of cache warmth. Specify how observation receipt times govern retrospective cutoffs.

This must be isolated from stage 0’s whole-bar convention and accompanied by the F4 correction.

### Human authorization

The four clarifications need dated, reviewed decisions before the new freeze. They do not inherently require lowering an exit threshold.

**Human authorization is required if the project instead keeps deliberately widened frozen thresholds, expires the scoring obligation, or relaxes C10.5’s deadlines/counts.** I recommend correcting those behaviors, not requesting waivers. Earlier failures remain earlier failures.

## Before spending another window

Before refreezing:

1. Fix F1–F9 and add counterexample regressions.
2. Commit the dated semantic decisions before new judged evidence.
3. Revalidate the independent comparison with the omitted boundaries and production adapter.
4. Exercise real restart/failure paths, including legacy final body files, delayed benchmark recovery, and slow resolution—not only clean temporary directories and instantaneous exceptions.
5. Fork the manifest, retain the previous identity, and restart C10.5. Do not pool evidence or carry the old window forward (`audit/criteria.md:729,872`).

The builder’s reported passing suite is useful, but these counterexamples are outside what that suite establishes. No inspection of track prices or returns is needed to fix them.

**Verdict: BLOCKED — fix F1–F9 and freeze the dated semantic resolutions before REFREEZE.**
