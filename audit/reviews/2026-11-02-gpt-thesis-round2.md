# Independent review: refreeze blocked

The arithmetic fixes are substantially better, but **I would not refreeze this tree yet**. F5 and F7 remain incomplete, exact-money serialization introduces a deterministic long-run failure, and the proposed readings still contain an impermissible boundary-coverage escape.

**Scope:** static review of the supplied diff, requested specifications and reviews, and changed files whole, with hand-derived cases and exact decimal-integer calculations. I did not execute Python tests, inspect track data, or edit anything. Passing counts below remain the builder’s evidence, not independently reproduced results.

## Blocking findings

### B1. F7 still abandons daily-history omissions that change benchmark inclusion

**Trigger:** an ordinary API response temporarily omits the earliest daily candle returned.

**Outcome changed:** base-rate availability, window counts, benchmark registrations and base-rate paired coverage.

Daily rows are explicitly excluded from leading-edge repair (`thesis/market.py:34,127–133`). Once later rows are cached, subsequent extension starts after their last timestamp. The omitted prefix is never requested again.

Concrete case:

- A market genuinely has daily rows from `a − 210 days` through anchor `a`, with complete funding.
- For a 21-day holding duration, these support **10** complete windows.
- The first fetch omits only `a − 210 days`.
- The cache now supports **9** windows.
- The venue restores that candle before the next snapshot, but the adapter never asks for it.

Correctly retrieved history gives, for ten positive windows, `p_ref = 11/12`. The cached history gives `p_ref = null`, so the benchmark skips the market (`thesis/scoring.py:48–57`; `thesis/runner.py:231–234`).

The justification that a day before the first cached row “can’t resolve or size anything” is false (`audit/stage10/readings-draft.md:45`). It can also determine whether a market has 89 versus 90 completed daily bars (`thesis/runner.py:111–113`).

The frozen permission to omit an **incomplete** window does not authorize keeping it incomplete after its data becomes available.

**Required:** repair required daily-prefix omissions. Remove this exception from the draft; request cost is an implementation constraint, not a semantic exemption.

### B2. F5 isolates exceptions, but not slow resolution work

**Trigger:** one market repeatedly times out while many theses await resolution.

**Outcome changed:** healthy theses receive scores after C10.5’s two-hour availability deadline.

`resolve()` still calls `score()` sequentially across every thesis and account (`thesis/runner.py:239–246`). A slow thesis therefore delays unrelated ones. The docstring’s claim that a delay holds up “only the theses that need it” is incorrect.

A reachable first-window example:

- Forty main and forty no-reading theses share failing market Y and horizon T.
- A later benchmark thesis X has all its required data available.
- Each Y request exhausts six ten-second transport timeouts plus backoffs of `1+2+4+8+16` seconds: **91 seconds**, before any limiter delay (`ingest/hl.py:16,39–48`).
- Repeating that work for 80 theses costs **7,280 seconds**, or **121 minutes 20 seconds**.
- X is processed only afterwards; the resolution loop also waits five minutes before a pass (`thesis/runner.py:293,325–329`).

The independent deadline loop correctly publishes statuses. It does **not** satisfy the separate obligation to score X within two hours of X’s data becoming available (`audit/criteria.md:881`). It can instead label X “missing data” while X merely waits behind Y.

The hanging-market test verifies statuses, not timely unrelated scores (`thesis/tests/test_runner.py:468–490`).

**Required:** bounded scheduling/failure isolation for actual scoring, including repeated failures shared by multiple theses and contention through the market adapter. Test elapsed-time guarantees for healthy scores, not just statuses.

### B3. Exact rational records eventually exceed Python’s integer-string limit

**Trigger:** ordinary repeated registrations on a continuing track.

**Outcome changed:** valid registrations begin returning daemon errors; restarting does not cure the accumulated account state.

Registration serializes each rational through `str(v)` (`thesis/registry.py:153`). `exact()` also round-trips values through decimal text (`thesis/positions.py:32–35`). The pinned runtime is Python 3.13 (`flake.nix:11`), whose default integer-to-decimal conversion limit is 4,300 digits. No override or alternative encoding is configured.

This is attainable without exotic prices or losses:

- Sequential long BTC theses;
- L = 0.1, zero funding, unchanged reference price;
- the actual frozen BTC $1k cells and fee 0.00045;
- each thesis closes before the next registration.

Both notionals remain below $1,000 as equity declines. Writing the fractional execution costs as \(c_b,c_s\),

\[
R=(1-c_s)(1-f)-(1+c_b)(1+f).
\]

Using `venue/hyperliquid/execution.json:8–16`, each completed trade multiplies equity by exactly

\[
F=\frac{39996243166880324594394951}
        {40000000000000000000000000}.
\]

Thus \(E_n=10000F^n\). After **168** completed trades, its reduced numerator has **4,302 digits**. The next registration’s N retains that numerator and fails decimal serialization with `ValueError`.

This is a continuing-track failure, not a claim that it occurs during the first 28 days. It nevertheless occurs before the 200-cluster evidence floor in this valid scenario. Fixing it later would change manifest-covered code.

The reported 300-thesis `admit` timing does not establish durable registration/reload safety (`audit/reviews/2026-11-02-thesis-bundle-round2.md:24`).

**Required:** exact persistence and parsing that survive growing rationals, plus a production-cost, ledger-round-trip longevity test. Benchmark the complete registration path. I have not established a particular wall-time stall from rational arithmetic alone.

### B4. Idempotent registration retries still fail after two acceptances

**Trigger:** the agent’s second registration commits, but its response is lost; the agent retries that request.

**Outcome changed:** the agent receives a refusal instead of its existing thesis, leaving it uncertain about an exposure that remains accepted and scored.

The daemon checks the two-registration limit **before** looking up the request ID (`thesis/daemon.py:69–76`). Once two registrations are accepted, even an identical retry returns “at most 2”.

With fewer acceptances, a retry can still fail unnecessarily because market preparation precedes the registry’s idempotency lookup (`thesis/daemon.py:75–76`; `thesis/registry.py:137–141`). A venue failure can therefore prevent returning an already committed thesis.

This is pre-existing, not introduced by round 2, but it contradicts C10.1’s retry requirement (`audit/criteria.md:845`).

**Required:** return committed retries without treating them as new admissions or requiring fresh market inputs. Preserve changed-content refusal.

### B5. F8’s repair provenance is not crash-complete

**Trigger:** SIGKILL between quarantining a damaged body and appending its repair record.

**Outcome changed:** the required repair audit permanently lacks the repair’s feed, URL and damaged-byte hash.

The rename happens first, followed by the journal append (`ingest/datalayer.py:82–87`). After that kill, the next poll sees no canonical `.gz`, writes the replacement, and never reconstructs the missing repair record (`:124–135`).

The builder accurately acknowledges this limitation (`audit/reviews/2026-11-02-thesis-bundle-round2.md:84`). A filename preserving digest and time is useful evidence, but it is not the promised repair record.

**Required:** recoverable repair provenance across this kill boundary. Preserve the damaged bytes throughout.

Also settle the documented Oracle handoff: the repaired canonical `.gz` is refused as divergent by `ops/oci/publish.py:28–30`, while newer poll-log rows can publish. Until reconciled, that backup can still reference the damaged body. This is not evidence that actual recordings are damaged; no recordings were inspected.

## F1–F9 assessment and boundary arithmetic

| Finding | Assessment |
|---|---|
| **F1 — widened thresholds** | **Fixed in the decision arithmetic.** Cost-cell, invalidation and cap comparisons now use exact rationals without epsilon (`thesis/positions.py:65,219–220,240–244`). |
| **F2 — exactly-zero outcomes** | **Fixed.** Classification precedes conversion to float (`thesis/positions.py:90–91`). |
| **F3 — intra-lag sizing** | **Fixed under the proposed reconciliation revision.** Reconciliation waits for every required lag and stops at the first failure; the data cutoff bounds it (`thesis/positions.py:119–123,140,154–157`). |
| **F4 — warm cache** | **Fixed for the reported case.** Cached candles are projected to the requested cutoff, retaining the open and nulling an unavailable close (`thesis/market.py:175–177`). |
| **F5 — resolution isolation/deadlines** | **Partial.** Exception isolation, managed-replay fallback, actual publication timestamps and independent statuses are implemented (`thesis/runner.py:243–271`). Slow-score isolation remains B2. |
| **F6 — benchmark p** | **Fixed.** The committed N produces p_ref, then benchmark p is assigned from that same result (`thesis/registry.py:153–159`). |
| **F7 — required holes** | **Partial.** Internal holes are retried without the old age limit. Required daily prefixes remain abandoned: B1. |
| **F8 — legacy bodies** | **Reuse defect fixed; crash provenance incomplete.** Decompression/content comparison prevents poisoned-file reuse (`ingest/datalayer.py:72–77,124–133`). B5 remains. |
| **F9 — commit eligibility** | **Fixed under the explicitly proposed observation convention.** Listing reads occur under the registration lock after preparation, with their interval recorded (`thesis/registry.py:135–150`). This convention still needs its dated revision. |

### Recomputed boundary cases

- **Exactly $1,000:** at reference 50.36, \(q=25000/1259\), so \(qP=1000\) exactly. A 1 bp buy fills at **50.365036**, not 50.400288.
- **Just above $1,000:** N = `1000.0000000005`, references 100 → 100.2, fee 0.00045, cells 1/8 bps. Both trades require 8 bps:

  \[
  R=1.002(0.9992)(0.99955)-(1.0008)(1.00045)
   =-0.00050249928.
  \]

  Therefore **o = 0**. At exactly N = 1000, the entry uses 1 bp and the exit 8 bps, giving **+0.00019781572**. The distinction is preserved.

- **Invalidation:** short 118.9 → close 130.79 gives exactly **−0.1**, so L = 0.1 triggers. Short 100 → 110 with L = `0.10000000000005` does **not** trigger.
- **Positive-fee zero:** the F2 references produce fills **99.95499900045** and **100.04499899955**. Both satisfy

  \[
  P_{\rm out}(1-f)=P_{\rm in}(1+f)
  =99.9999787500002025.
  \]

  Net PnL is exactly zero: **o = 0**.

- **Lag boundary:** q = 10, unchanged reference 100, funding 0.001. Immediately before the lag expires, E_r remains **10000**, N **1000**. At expiry, funding is **1**, E_r **9999**, N **999.9**. With the new reference 110, E_r becomes **10098.9**, N **1009.89**.
- **Cap:** at E_r = 10000, five reservations of 100 equal the 500 cap and fit; a sixth does not. No widened threshold remains.

The original close-based invalidation and partial-spread closure fixes also retain their intended central behavior.

## Differential: useful and mostly candid, but not the full claim

### Source patches

The quantity, gross-return and side-specific exit-cost patches are justified by `SCORING.md`. The funding fallback patch implements the proposed resolution of conflicting frozen wording. These are substantive specification resolutions, not agreement with untouched GPT code (`thesis/tests/test_positions_differential.py:32–55`).

Keeping the untouched source and reporting raw disagreement separately is good. Calling patched agreement **“approved”** remains provisional while the readings are still a draft.

The suppression patch has a narrower limitation:

- It releases a truly absent pending leg at the suppression boundary.
- Once a later entry/exit opportunity appears, the oracle can again report that opportunity’s later availability as `reservation_released_at` (`:42–45`; `thesis/tests/gpt_positions.py:568–585`).
- For X entering at 11h and closing at 96h, with Y first appearing at 100h, the retrospective release field can therefore say 100h + lag rather than X’s 96h + lag.

The comparison never directly compares release timestamps; it samples reservation balances at selected oracle-derived times (`test_positions_differential.py:200–208`). This is a checker/report limitation, not a demonstrated production admission error.

### Precision and mutant claims

Independent sizing propagation, exact equity comparisons and production-adapter coverage are real improvements.

However:

- **Not every compared monetary field is rational-exact.** R_net and exit references/fills are compared after float conversion (`:217–218,238–239`). Sizing, entry quantities/fills, managed returns and equity receive stronger comparisons.
- The mutant called **“a bar’s close counts before it ends”** changes `<=` to `<` (`:75`). That tests exclusion of the close **at its exact end**, not premature use before the end. Correct the label/power claim or add the intended early-close mutant.
- Counting an exception as a mutant catch is disclosed and reasonable, but is not necessarily a semantically correct rejection (`:403–411`).

The differential does not establish deadline scheduling, API-budget behavior, persistence/restart integrity, legacy-recorder recovery or long rational serialization. Its short synthetic accounts also do not cover B3.

## Are the readings ready to commit alone?

**No—not as written.**

1. **P_e as reference open:** sound.
2. **Funding fallback and reconciliation:** sound prospective resolution. Specify “held immediately before h” for funding eligibility, so entry-hour funding cannot be inferred.
3. **Suppression and reservation release:** sound prospective resolution; retain explicit availability timing and improve the checker’s release-field coverage.
4. **Core opening availability:** a legitimate prospective thesis-specific convention. It changes behavior and must remain explicit, separate from stage 0—not presented as already frozen.

The following need correction:

- **Daily-prefix exemption:** remove it; B1 disproves its justification.
- **C10.4 “stay off those boundaries”: reject this option.** The frozen criterion expressly requires exact-zero and other boundary coverage (`audit/criteria.md:869–876`). Avoiding disagreements by excluding boundaries weakens the check; it is not a permissible implementation clarification (`readings-draft.md:51`).
- **Nonpositive-equity N:** settle it explicitly rather than leaving it “silent and not exercised” (`:47`). Different hypothetical N values select different cost tiers and can change **o**, not merely a label. For references 100 → 100.15 with 1/8 bp cells and fee 0.00045, a $1,000 hypothetical uses the dearer exit cell and returns **−0.00030155946**; the zero-notional limiting convention uses the cheap exit cell and returns **+0.0003991750675**.
- **C10.4 tolerance:** preserve the existing relative/scaled comparison revision explicitly; do not accidentally restate it as a new absolute tolerance.

The exact-arithmetic changes do **not** loosen the numerical boundaries. Neither do the four central readings inherently require a threshold waiver. But omitting mandatory C10.4 boundaries cannot be approved as a clarification; a deliberate relaxation requires the human’s authorization.

## Before another window

Fix B1–B5, finalize the dated semantics, and have GPT update its independent scorer from the revised specification—not production code. Rejudge C10.3 and the complete C10.4 boundary suite after that revision. Add the slow-score, retry and durable-rational counterexamples.

The restart code now correctly handles the reviewed ordinary process-kill sequence: interrupted sessions are ended, remaining same-day sessions resume on the saved snapshot, and expired dates are reported missed (`thesis/runner.py:148–212,316–322`). I found no additional demonstrated session-doubling defect in that path.

The recorder changes preserve existing bytes and avoid concatenating new records onto a torn tail. They do **not** reconstruct complete old records already embedded behind a torn prefix; skipped historical lines must not be described as recovered history (`ingest/live.py:34–43`). Process-kill tests also do not establish power-loss durability.

**Verdict: BLOCKED — resolve B1–B5, remove the boundary-avoidance option, settle the remaining semantics, and obtain fresh complete independent scoring evidence before REFREEZE.**
