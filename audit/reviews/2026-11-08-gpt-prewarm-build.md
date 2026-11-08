# Thesis refreeze prewarming build, review by GPT (opencode, gpt-6.1-sol high), 2026-11-08 10:41 UTC (05:41 EST)

Reviewed: `thesis-refreeze` at `e04b8d4` (Sonnet's prewarming, `e0a69a8..e04b8d4`), from a clean worktree; tests run in a scratch checkout. Prompt: `~/repos/gpt-after-reset.sh` (part 1 the build against GPT's design review `2026-11-07-gpt-funding-fill-design.md`, part 2 the three snapshot options, unranked). Reply verbatim below.

# Review of `e04b8d4`

**Verdict: not ready to refreeze.** Page-level recovery and whole-account replay work, but the build still publishes acquisition-dependent base rates as final, can suppress required repairs indefinitely, and understates its workload.

The original worktree remains unchanged. Tests ran against an exact checkout under `/tmp/opencode`; no protected prices or returns were inspected.

## Part 1 — Findings

### 1. High — unfinished acquisition can become the permanent comparator

**Where:** `thesis/runner.py:103-109`; `thesis/registry.py:183-189`; `docs/whitepaper.tex:707`.

**Failure scenario:** an eligible market has only part of its historical funding cached. Registration fetches its account-dependency range, supplies whatever historical rows happen to exist, and commits `p_ref` without checking historical acquisition readiness.

My synthetic reproduction committed:

- Partial cache: **14 windows, 14 positive, `p_ref = 0.9375`**
- Fully acquired inputs: **89 windows, 15 positive, `p_ref ≈ 0.175824`**

Later filling cannot repair the immutable registration.

**Yes: “gets its base rate from the rows ready” is precisely a partial-data base rate published as final.** The existing rule for windows the venue omitted does not make unrequested history equivalent to an established omission.

The freeze gate protects only initial readiness. Cache loss or unfinished acquisition after freezing remains exposed. A genuinely new listing cannot immediately register because of the 90-daily-bar requirement; that does not protect an already-eligible cold market.

**Outcomes changed:** comparator values and coverage, paired Brier skill, benchmark probabilities or terminal skips, and information returned to the agent.

**Required disposition:** establish comparator acquisition readiness before commitment, or preregister a different comparator lifecycle. Silently excluding cold markets would instead change eligibility.

### 2. High — repair bookkeeping is still not range-aware

**Where:** `thesis/market.py:316`; `thesis/market.py:495-504`.

**Failure scenario:** a historical funding hole was previously requested. The venue subsequently supplies it. Each hour:

1. A narrow foreground read repairs its recent range and updates `(path, False)`.
2. A wider account read sees that repair timestamp and skips historical-hole repair.

Because the older interval is already marked fetched, `_funding_gaps()` does not recover it either.

**Reproduced:** after three hourly narrow-then-wide reads, the available historical row remained absent. This ordering can continue indefinitely—for example, a narrow resolution read preceding whole-account replay.

Widening into **never-requested** history works; widening across **previously requested omissions** does not reliably work.

**Outcomes changed:** account reconciliation, sizing, managed returns, and resolution timeliness.

**Required disposition:** repair timestamps must describe the intervals actually repaired, not merely the market file.

### 3. High — T3’s cold-fill and steady-state derivations omit actual requests

**Where:** `docs/whitepaper.tex:705-707`; `thesis/market.py:346-364`; `thesis/market.py:499-502`; `thesis/runner.py:168-185`.

The individual reservation examples are correct:

| Request | Reservation |
|---|---:|
| Approximately one day of funding | 21 |
| Short candle tail | 20 |
| Full funding page | 45 |

The aggregate claims are not established by those examples.

**Cold-fill reproduction:** a complete, 40-day-old market has an age-based estimate of two funding pages, hence at most **90** under T3’s formula. Actual initial `prewarm()` reserved:

```text
45 + 43 + 20 + 45 = 153
```

After acquisition, the same call immediately performs tail and leading-omission repair. The **403,560** arithmetic is correct multiplication, but its page model omits this work; it is not a demonstrated upper bound.

**Steady-state reproduction:** an eligible, 100-day-old core market, with no missing post-listing rows, reserved on its next hourly account read:

```text
59 candle-prefix repair + 20 candle tail + 20 funding tail = 99
```

T3 budgets **41**. Candle repair still probes the prelisting portion of its 200-day scope. Genuine funding holes add further requests.

The approximately **14/min** funding-upkeep calculation is reasonable **under its stated inventory and no-additional-hole assumptions**:

```text
(348 × 21 + 278 × 45) / 1440 ≈ 13.76
```

However, inventory discovery additionally costs `20(d + 2)` per prewarm pass. That and the candle-prefix repairs are absent from the approximately **45/min** steady-state story.

**Outcomes changed:** session latency, entry hours, background completion time, and resolution service capacity.

**Required disposition:** derive and test the actual end-to-end workload, including mandatory omission probes, discovery, retries, and request packing—not just tail weights.

### 4. Medium — background discovery bypasses session holds

**Where:** `thesis/runner.py:168-179`; `thesis/market.py:325-336`; `ingest/hl.py:61`.

**Failure scenario:** the filler begins a new pass during a session. `warm_order()` calls `listings()`, whose requests use the default `background=False`. The limiter therefore treats the filler’s discovery as foreground work.

**Reproduced:** three inventory HTTP requests were admitted while a session hold was active.

Funding pages yield correctly, but the claim that the background fill cannot compete during sessions is too broad.

**Outcomes changed:** registration latency, entry boundaries, and foreground quota availability.

### 5. Medium — the normal bootstrap path is circular

**Where:** `thesis/runner.py:328-340`; `thesis/runner.py:410-414`; `cli.py:111-112`.

**Failure scenario:** this new manifest encounters cold `funding-ranges.json` caches:

- `thesis-run` refuses the unfrozen manifest before starting prewarm.
- `thesis-freeze` refuses until prewarm finishes.
- No prewarm command is exposed.

Both refusals reproduced. A deliberate standalone bootstrap invocation could work, but the supplied entry points do not perform the advertised “fill before freeze” workflow.

**Outcomes changed:** whether the new version can be prepared and started without bypassing its guards.

### 6. Medium, conditional — ignoring `funding.json` is not an input-preserving migration

**Where:** `thesis/market.py:441-449`; `thesis/market.py:455`.

**Failure scenario:** legacy cache contains `[hour, 0.1]`; the venue now returns `[hour, 0.9]`. The new reader ignores the legacy row and adopts `0.9`.

**Reproduced.** Old files are not deleted, but their immutable observations are not preserved in the new projection.

A deliberately cold, separately identified new track can be defensible. It is **not** evidence of equality with the previous cached inputs, and must not silently change reconstruction of previously judged accounts.

**Outcomes changed:** replay funding, historical window signs, and comparator values.

**Required disposition:** explicitly choose and record the input-provenance policy. Preserving legacy rows does not require pretending their entire surrounding ranges were acquired.

### 7. Medium — excess-response charging can undercount one weight unit

**Where:** `thesis/market.py:196-197`.

The additional charge is:

```python
(len(out) - reserved) // per_items
```

It should account for the difference between the total surcharge and the surcharge already reserved.

**Reproduced:** 19 funding rows reserved, 20 returned; total accounting was **20**, but the response requires **21**.

This is conditional on exceeding the assumed response bound, but that is exactly the contingency this branch promises to handle.

**Outcomes changed:** quota conformance and subsequent throttling.

## Invariants that survived execution

- **Whole-account replay:** closed-position funding remained included; the synthetic closed-position account reconciled with its funding cost.
- **Commit-time computation:** base rates remain computed at commitment, including the benchmark’s registered notional. Finding 1 concerns input readiness, not computation timing.
- **Page recovery:** SIGKILL immediately before and after the second page’s atomic replacement preserved respectively 500 and 1,000 committed rows; restart completed correctly.
- **429 handling:** one successful page followed by six actual HTTP 429 attempts preserved the first page, remained unready, and charged all seven attempts.
- **Foreground funding priority:** a session starting during an actual Exchange fill completed its narrow read; the hold stopped the next background page.
- **Coverage and widening:** readiness uses covered intervals rather than cached row extent; never-requested prefixes are discovered.
- **New listings:** the next inventory pass discovers and fills a newly appearing market. This is eventual discovery, not an eligible-cold-registration guarantee.

Shared-IP coordination, restart accounting, and the five-dex initial sampling limit remain unresolved qualifications; this build does not clear them.

## Test evidence

Tests ran in `/tmp/opencode/gpt-refreeze-e04b8d4` to avoid repository writes.

| Run | Result |
|---|---|
| Funding cache, market, shared client | **155 passed, 1 strict xfail** |
| Runner | **54 passed** |
| New adversarial probes | **8 failed assertions, 7 passed**; failures substantiate findings above |
| Full `nix develop -c pytest -n auto -q` | **1,302 passed, 10 failed, 2 skipped, 20 xfailed**, 607 s |

Full-suite failures were three absent-data/directory failures and seven missing-`bwrap` failures. Rechecking the affected subset with an installed `bwrap` and an empty scratch `data/` gave **55 passed, 2 failed**; those two hide `/tmp`, thereby hiding the scratch checkout itself. **This was not a green full-suite run.**

Reproductions: `/tmp/opencode/test_gpt_refreeze_review.py`. Logs: `/tmp/opencode/gpt-refreeze-*.log`.

## Part 2 — Ranked recommendation

The snapshot wall remains real: `thesis/runner.py:124-136` requires the newest daily tails and core hourly tails. **524 × 20 = 10,480**, or approximately **87 minutes** at 120/min, before metadata, repairs, retries, and contention. The strict xfail correctly records failure, not readiness.

### 1. **(a) Later session — lowest-risk route to the next freeze**

Preserve the full market scope and REST candle definitions; make a **dated criteria revision before freezing** (`audit/criteria.md:725`).

Specify separately:

- snapshot cutoff;
- acquisition interval;
- actual session start;
- maximum permitted snapshot age;
- outage and missed-session handling.

Merely moving `SESSION_OFFSET` is insufficient: `day()` still constructs its snapshot after readiness. Acquisition must finish before the revised start, with capacity demonstrated including the repairs found above. Do not choose the time by adding exactly 87 minutes; that is idealized tail arithmetic, not a completion bound.

This changes information timing and potentially entry hours, so it requires a new identity/window, never a pass of the original schedule.

### 2. **(c) WebSocket candles — strongest semantics-preserving candidate, but not yet certified**

Official documentation checked for this review supports candle subscriptions and separately lists the REST and WebSocket limits. **348 daily plus 176 core-hourly subscriptions = 524**, leaving nominal headroom under 1,000, **shared across the IP**. Subscription streaming is distinct from tunnelling weighted requests over WebSocket.

It could remove the routine tail wall while preserving the candle inputs—but needs all of the following.

**Source certificate**

Extend `venue/sources.toml`’s explicit `/info`-only description with the official WebSocket endpoint, read-only candle subscriptions, dated permitting evidence, schemas, and shared limits: connections, reconnects, subscriptions, and outbound messages. The existing operator decision must not silently be expanded.

**Finality and equality certificate**

The documented `Candle` schema contains a closing timestamp, but **no explicit final-candle flag**. A scheduled close timestamp does not certify that the last received update is final.

Before adoption, establish:

- boundary/update behaviour, including quiet HIP-3 markets;
- exact equality with REST for candle identity, opens and closes;
- identical normalization and availability cutoffs;
- receipt provenance, durable raw-frame hashes, and deterministic cache publication;
- a declared response to disagreement—never silently overwrite a previously used final value.

Testnet and synthetic fault tests can validate plumbing; they alone do not establish every mainnet finality assumption. Protected forward recordings must not be used to tune this unfrozen design.

**Failure handling**

- Track expected bars and subscription acknowledgements; connection health alone is insufficient.
- On disconnect, silent gaps, restart, or uncertain finality, mark affected intervals uncertain.
- Reconnect within shared limits and reconcile exact missing intervals through quota-controlled REST.
- Keep late updates without backdating their availability.
- Preserve the existing 120-second gate; a WebSocket update must not expose an unfinished close early.
- Never substitute stale closes, zeros, or a smaller universe to meet the start time.

**Does it remove the wall without a criteria change?**

It can remove the **normal-operation acquisition wall**, not the worst-case outage wall. If every close needs immediate REST confirmation, the wall remains.

It need not change scoring, eligibility, or the session schedule **if equivalence is established**. Literally, however, `audit/criteria.md:751` restricts exchange reads to the fixed `/info` adapter: allowing subscriptions needs an explicit dated transport amendment. It is not “no change anywhere.”

Also, supplying tails alone will not suppress `_cached()`’s mandatory historical repair requests. The acquisition/cache design must handle those coherently.

### 3. **(b) Older or reduced daily snapshot — feasible, but changes more of the experiment**

A uniform older cutoff is implementable and prefetchable. It changes what `prices` exposes, can delay the 90th-bar eligibility boundary, and shifts the base-rate anchor (`thesis/SCORING.md:46-49`).

A demand-loaded snapshot could reduce eager requests, but must preserve one immutable cutoff and identical main/no-reading inputs. The two-registration limit does **not** bound how many markets an agent may inspect.

This option needs an explicit, reviewed information-set policy—not opportunistically whatever bars are cached.

**Recommendation:** use **(a)** for the next refreeze after fixing Part 1; pursue **(c)** as a separately validated transport improvement. Prefer **(b)** only if the intentionally older information set is scientifically acceptable.
