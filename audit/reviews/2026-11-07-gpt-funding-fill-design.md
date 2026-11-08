GPT (gpt-6.1-sol, high), fresh read-only consult in a clean worktree at thesis-refreeze e0a69a8, 2026-11-08 02:20 UTC (2026-11-07 21:20 EST): the advisor's option-3 design for refreeze finding 2, before any build.

# Review: bounded registration funding and background backfill

The separation between account-replay data and historical-comparator data is useful. **However, two premises are false in this tree: base rates are computed at registration, not resolution; and account replay needs closed positions’ funding, not just currently open positions’.** The proposal cannot be adopted as a semantics-preserving fetching optimization.

Scope: static, read-only review. No tests executed or protected recordings inspected. External API claims and the ~352-market/~590k-weight inventory estimates remain unverified.

## Findings

### 1. High — registration needs historical funding today, and the benchmark cannot defer its forecast

**Where:** `thesis/registry.py:175-189`; `thesis/runner.py:229-238`; `thesis/report.py:46-57`; `audit/criteria.md:962-964`.

Every accepted registration computes and permanently records `p_ref`, `base_windows`, and `base_positive`. The live resolver does not compute a base rate. Reports consume the registration’s recorded `p_ref`; filling the cache later changes nothing in that record.

The benchmark is a stronger dependency: `p_is_base_rate=True` means its **forecast probability itself** is the base rate computed from its registered notional at commit. Without one, registration returns `"no base rate"` and the runner logs a terminal skip.

**Failure scenario:** a new market receives only post-entry funding. Main/no-reading registration commits `p_ref=None`; subsequent backfill never restores its comparison. The same policy makes cold benchmark markets skip instead of registering.

**Outcomes changed:** baseline coverage, paired Brier scores, skill and bootstrap intervals; benchmark membership, forecasts and account trajectory. The returned thesis also exposes `p_ref` to the agent (`thesis/daemon.py:90`), so deferring it changes information available before the agent’s next decision.

**Required change:** either preserve commit-time base rates through prewarming, or explicitly preregister deferred comparator computation for the new version. Benchmark history must still be ready **before its registration**, unless the benchmark definition is separately revised. Its probability cannot first be chosen at resolution.

### 2. High — “earliest open position” is not a sufficient bound for the existing account replay

**Where:** `thesis/runner.py:90-102`; `thesis/positions.py:135-168,174-190,237-248`; `audit/criteria.md:925-937`.

Admission replays **all previously registered theses from the initial account**, including closed positions. There is no persisted account checkpoint replacing their historical funding contributions.

Furthermore, closing a position despite missing funding releases its reservation, but does not repair reconciliation. Reconciliation remains stopped at the first missing hour—even after that position closes.

**Failure scenario:** a closed long paid $100 funding. A later registration has no currently open positions, so an open-only read supplies no historical funding. Full replay cannot reconstruct the closed trade’s funding and stops reconciliation early. With otherwise flat prices and zero costs, the correct equity could be $9,900 while the truncated replay sizes from $10,000.

Retaining old cached rows avoids this particular example **only if every required old row is already present and returned**. Closure does not establish that condition.

**Outcomes changed:** `E_r`, reconciled hour, notional, admission under the cap, managed returns and reported equity.

**Required change:** without a checkpoint redesign, retain and supply funding required by the account’s **whole replay**, including closed positions. A simple conservative fetch bound is the earliest relevant registration/entry across that replay, per market—not the earliest currently open position.

For spreads, do not derive the bound from the displayed aggregate entry time: it is the latest leg entry (`thesis/positions.py:199-201`), while an earlier-entered leg may already owe funding.

### 3. High — deferred comparator work needs its own completion state; outcome resolution does not provide one

**Where:** `thesis/runner.py:244-270,272-279`; `thesis/scoring.py:50-57,64-74`; `thesis/SCORING.md:40,48-56`; `thesis/report.py:55-68`.

Three different states must remain distinct:

1. **Outcome funding missing:** the outcome remains unresolved.
2. **Comparator acquisition unfinished:** its eventual window population is not yet established.
3. **Comparator acquisition finished, but fewer than ten complete windows:** `p_ref` is legitimately unavailable.

The existing scoring rule permits an outcome to resolve and contribute to ordinary Brier and ablation scores without a base-rate pair. It omits incomplete historical windows; it does **not** require every historical funding hour to exist before resolving an unrelated forward outcome.

**Failure scenario:** the filler has collected ten recent windows and computes a provisional base rate while older eligible windows remain unrequested. That provisional estimate is published as final. Alternatively, registration’s `None` becomes indistinguishable from a genuinely unavailable comparator and is never revisited.

The current resolver skips theses once their outcome is resolved. Merely adding comparator computation inside that loop would leave unfinished comparator jobs stranded after outcome resolution.

**Outcomes changed:** comparator estimates, pair eligibility, coverage counts, skill and intervals; potentially resolution timing if unrelated historical work blocks the forward outcome.

**Required change:** if deferral is adopted, record separate append-only comparator status/results, using frozen thesis inputs and an explicit acquisition-completion policy. Continue comparator work independently of outcome completion. Never substitute zero funding, a default probability, or an acquisition-dependent subset of windows.

### 4. High — the cache is not currently range-aware enough for partial-to-full extension

**Where:** `thesis/market.py:56-70,275-302,370-376`.

Adding a `start` argument alone is insufficient:

- `holes()` examines all cached internal gaps; it does not clip every span to the requested interval.
- Repair bookkeeping is one timestamp per file, not per covered interval.
- After a narrow read marks the file repaired, a wider request can take the tail-only fast path and fail to fetch its missing prefix.
- Returning only the requested suffix would deprive full account replay of previously cached closed-position funding.

Also, the existing fetch scope is a rolling **1,125 days**, not a known listing date (`thesis/market.py:36,288`). Requests before the first observed row are deliberately retried.

**Failure scenario:** registration fills a recent suffix. The filler immediately requests the historical range, but the recent repair timestamp and present tail suppress backward expansion. Conversely, a narrow session read notices an unrelated old gap and starts historical acquisition in-session.

**Outcomes changed:** replay completeness, base-rate window counts and values, and session latency.

**Required invariants:**

- Requested coverage controls network work; existing row extent does not establish coverage.
- Widening a request must immediately discover its uncovered prefix.
- Backward extension preserves every existing timestamp/value.
- Session reads cannot trigger repairs outside their required range.
- Fetch scope and the rows supplied to each consumer are explicitly distinguished.

Partial/full equality holds only when both consumers receive identical rows over every dependency interval. “Cached values never change” does not establish that equality: a row first fetched later might have a different venue value. Exact equivalence to an earlier full fetch therefore also depends on source stability or canonical acquisition provenance.

### 5. High — naïve background filling moves the session wall onto a cache lock and loses progress on failure

**Where:** `thesis/market.py:278-301`; `ingest/hl.py:93-104`.

`_cached()` holds the market-file lock across the entire fetch. `Info.funding()` accumulates every page in memory and returns only when pagination finishes. The cache commits only afterwards.

**Failure scenarios:**

- A filler begins a long history for a market just before a session needs its recent tail. The session waits on the file lock for the whole backfill.
- The filler is killed, or its last page exhausts retries. All earlier fetched pages from that call remain uncommitted, so restart repeats their network cost.
- A structurally valid short page ends pagination even though required hours remain missing. Treating “pagination returned” as “history complete” publishes an incomplete comparator.

**Outcomes changed:** session completion, accepted registrations, data readiness and C10.5 deadlines.

**Required change:** commit validated progress page by page, release cache ownership between pages, and allow foreground work to proceed without waiting for an entire historical fill. Resume from durable rows/coverage, and determine completeness from required intervals and explicit omissions—not response length alone.

A 429, timeout or malformed page must leave the job pending, preserve committed progress and consume its attempt’s quota. Kill tests should cover page receipt, persistence and completion-record boundaries.

### 6. High — one shared in-process limiter neither reserves foreground capacity nor enforces the IP commitment

**Where:** `ingest/hl.py:23-45`; `thesis/market.py:91-104,116-118,249-252`; `thesis/runner.py:59-66,295-297,386-389`; `venue/sources.toml:13-20`.

Sharing the existing `Exchange` limiter is necessary for an in-process filler, but insufficient:

- Ordinary filler, registration and resolution requests have no differentiated priority.
- Already-spent background reservations remain spent when a session starts.
- An independent filler process, report `Track`, desktop client or recorder has separate accounting.
- Limiter state disappears on restart.
- Recorder post-response item debt remains outside the thesis’s reservation model.

**Failure scenario:** a filler spends two 45-weight reservations immediately before foreground reads, then continues competing with them. A separate report or restarted process simultaneously spends another independent allowance.

**Outcomes changed:** registration and resolution latency, hourly mark availability, recorder losses, and conformance to the combined 600/min commitment.

**Required change:** run the filler through the same admission authority, give it genuinely preemptible/page-granular scheduling, and account for outstanding reservations before foreground work. Enforce cross-process allocation/exclusivity and conservative restart behavior. “Outside sessions” must mean background work has actually yielded, not merely that its job was started earlier.

This proposal does not clear the already-recorded global-coordination blocker.

### 7. Medium–High — the advertised spare-weight and top-up costs omit this implementation’s reservations and repair load

**Where:** `thesis/market.py:43,123-128,285-293`; `docs/whitepaper.tex:699-703`; `audit/criteria.md:963-964`.

Every thesis funding attempt reserves **45**, including short and empty pages. Thus:

- Two pages fit in a 120-weight rolling minute; three do not.
- A daily one-page update for 352 markets reserves  
  `352 × 45 / 1440 = 11 weight/min` on average, not approximately five.
- The approximately-five figure corresponds to actual short-page charges, not current admission reservations.
- Retrying one leading missing-history span per market every hour would alone reserve  
  `352 × 45 / 60 = 264 weight/min`.

The last case matters because dates before the first cached row are retried without a known listing boundary. An all-market maintenance loop can spend its budget repeatedly asking for prelisting or permanently absent history.

**Failure scenario:** optional all-market filling and repair consume the quota assigned to registered theses; a thesis with the minimum 72-hour horizon reaches resolution with comparator acquisition still pending.

**Outcomes changed:** comparator availability and coverage, foreground latency, and resolution deadlines.

**Required change:** derive costs from reserved attempts, retries, repair policy and actual non-session availability. Prioritize required registered-market work and benchmark readiness over optional inventory filling. The ~590k/~four-day estimate is not a demonstrated scheduler bound.

Do not eliminate genuine missing-row retries merely to make the estimate fit; their hourly retry behavior is frozen.

### 8. Medium–High — removing cold funding does not establish a cold-session or full-track capacity guarantee

**Where:** `thesis/runner.py:104-127`; `thesis/market.py:123-128,321-324`; `docs/whitepaper.tex:701-705`; `thesis/tests/test_market.py:644-655`.

The initial snapshot still reads daily histories across listings and hourly histories for eligible core markets. Candle requests reserve 103, so two do not fit together within 120. Core account replay also depends on retained hourly candles; the supplied latest-5,000 retention claim means losing sufficiently old cached candles cannot be repaired by a funding filler.

Separately, the every-dex initial sampling wave still requires `20(1+d) ≤ 120`, hence `d ≤ 5`. Funding deferral does not change that constraint.

**Failure scenario:** funding registration becomes fast, but snapshot construction delays session startup, hourly data are unavailable after cache loss, or discovery finds more than five builder dexes.

**Outcomes changed:** session timing and availability, replayability, builder reference completeness and C10.5 evidence.

**Required change:** demonstrate the complete workload and recovery envelope. Keep the impossible cold-funding arithmetic as a recorded limitation; add a real end-to-end regression for the replacement data path rather than treating that arithmetic test as proof of the new design.

## Caller audit

| Path | Historical funding dependency |
|---|---|
| Request validation, prerequisites, eligibility | No long funding dependency; form, time, listings and daily-bar checks (`registry.py:80-135`). |
| Admission/sizing | Whole account replay, including closed positions (`registry.py:181`; `positions.py:237-248`). No pre-account funding needed. |
| Main/no-reading registration | Historical comparator computed at commit (`registry.py:183-184`). |
| Benchmark registration | Historical comparator is the forecast itself (`runner.py:235-236`; `registry.py:185-188`). |
| `positions` / discretionary `exit` | Whole account replay (`daemon.py:92-102`; `runner.py:100-102`). |
| Conditional ablation | Daily snapshot and probability submission only; no funding/base-rate call (`runner.py:164-173,211-212`; `daemon.py:105-114`). |
| Forward resolution | Thesis entry-to-horizon funding; managed replay uses its management path. No base-rate computation (`runner.py:257-270`). |
| Live report | Recorded base rates plus whole account replay (`report.py:46-68`). |
| Standalone scorer | Computes base rates from supplied historical input (`scoring.py:101-112`); it is not the live resolution path. |

## Specification, C10.5 and identity consequences

**Preserving commit-time comparators through prewarming:** no scoring-formula revision is inherently necessary. Range-aware fetching must still preserve the missing-data, repair and replay rules.

**Deferring comparators until after registration:** requires a reviewed, dated criteria revision before the new freeze. It conflicts directly with commit-time baseline evaluation and the explicit rule that a base rate computed at `t_r` omits windows incomplete then (`audit/criteria.md:763,962-964`). Specify:

- which daily snapshot, funding acquisition policy, `N`, fees and costs are frozen;
- when comparator acquisition is pending versus finally unavailable;
- append-only result records and report consumption;
- whether/how deferred results become visible to agents;
- benchmark readiness and skip behavior.

`SCORING.md`’s numerical formulas can remain unchanged if given identical final inputs, but the deferred lifecycle must be specified. Revising formulas, exclusions or missing-status meaning requires corresponding specification and independent-check updates.

For **C10.5** (`audit/criteria.md:884-891`):

- publish a score or explicit missing-data status within two hours of each horizon;
- retain the subsequent two-hour scoring requirement when required data become available—local filler completion must not silently redefine availability;
- a resolved outcome without a base-rate pair can count as resolved under the existing scoring rules;
- four benchmark batches must still enumerate registrations and genuine skips; cold acquisition is not evidence of a market inherently lacking a base rate;
- the new identity starts a fresh 28-day window. Prior-version evidence is not pooled.

Changes to loaded runner, market, registry, scoring or report code—and `SCORING.md` itself—change the manifest (`thesis/harness.py:22-44`). Put any filler implementation/configuration affecting results inside that identity. Mutable caches are not themselves manifest-hashed, so provenance and append-only completion records remain necessary.

## Simpler design

**Prefer mandatory prewarming over deferred baseline semantics.**

1. Before the new freeze, backfill the historical funding required by every currently eligible market’s comparator; prioritize the five benchmark markets.
2. Maintain that coverage outside sessions and prepare approaching-eligibility markets ahead of time.
3. Keep base-rate computation and benchmark forecasts at registration, with the existing immutable records and report path.
4. Make foreground fetching cover the account’s whole replay dependency interval, while retaining all previously cached rows.
5. Use one page-granular acquisition/cache mechanism and the shared admission authority.

This avoids a second comparator lifecycle, late report joins and a benchmark-definition change. It costs startup preparation rather than session time. Unexpected cold markets, source holes and cache-loss recovery still need an explicit readiness policy; silently adding “warm cache” as an eligibility condition would itself change the criteria.

Under the supplied external claims, websocket subscriptions do not supply the missing historical comparator, and requester-pays S3 is not an automatically authorized free alternative.

## Verdict

**Sound with changes.** Separating replay acquisition from historical backfill is sound, but **open-position-only replay and resolution-time base rates are not valid descriptions of the current system**. Preserve whole-account replay dependencies, keep benchmark probabilities commit-time, and preferably remove the wall through prewarming rather than changing comparator semantics. Global quota coordination and builder-sampling capacity remain independent refreeze blockers.
