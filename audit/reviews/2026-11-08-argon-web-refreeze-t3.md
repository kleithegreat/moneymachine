# Thesis refreeze T3 and criteria revision, review by Gemini 4 Argon (web UI), 2026-11-08 21:42 UTC (16:42 EST)

Reviewer: Gemini 4 Argon in the Gemini web UI (its agy quota is spent), read-only: it could not run code, so the suite result was supplied. Bundle: `~/Downloads/argon-review-refreeze-t3.md`, built by the advisor from `thesis-refreeze` at `2229563` (paper T1-T3, the frozen stage 10 criteria, the revision draft, the decisions lines, `ingest/hl.py`, `thesis/market.py`, `thesis/runner.py`, the schedule and round-five tests, the Opus round-five and Sonnet T3 reviews as context). The bundle truncated the paper at line 695, after T3's first paragraph (the advisor's extraction error); T3's later paragraphs were checked through the draft and tests. Reply verbatim below, as the human pasted it; the Eastern times in [brackets] are the advisor's insertions (the reply gave UTC only).

---

**Verdict: Correct with fixes.** Every per-request weight, item reservation, ceiling surcharge, discovery cost, funding allowance, and recorded-case packing figure ($630$ requests, $17,206$ weight, $155\text{ min}$, done $\text{02:54 UTC [21:54 EST]}$) reproduces from the code, and the $\text{05:00 UTC [00:00 EST]}$ session start holds in the recorded case with over two hours of margin. However, six errors across the stress-case derivation, the Monday benchmark timing, the mark-sampling retry loop, and the criteria revision draft require fixes before freezing. (Note: the supplied bundle truncates `docs/whitepaper.tex` at line 695 after the first paragraph of T3, so T3's subsequent paragraphs are checked via the figures quoted in the prompt, `audit/stage10/criteria-revision-draft.md`, the two context reviews, and `thesis/tests/test_snapshot_schedule.py`.)

---

### 1. Arithmetic Check of Counts, Weights, and Times in T3

The table below verifies each quantity in T3 and `audit/stage10/criteria-revision-draft.md` against `ingest/hl.py`, `thesis/market.py`, `thesis/runner.py`, and `thesis/tests/test_snapshot_schedule.py`:

| Quantity | Code Mechanics & Arithmetic | Status |
| --- | --- | --- |
| **Limiter budget** | `IP_BUDGET_PER_MIN = 1200 // 2 = 600`; `BUDGET_PER_MIN = 600 - 480 = 120` weight/min (`ingest/hl.py:15-17`, `thesis/market.py:39`) | Correct |
| **Reservation & ceiling surcharge** | `max_items(body)` reserves $\min(\text{ceiling}, \lfloor\max(\text{endTime} - \text{startTime}, 0)/\text{step}\rfloor + 1)$ items (`candleSnapshot` ceiling $5,000$, `per_items = 60`; `fundingHistory` ceiling $500$, `per_items = 20`); `Exchange.post` charges $20 + \lceil\text{reserved}/\text{per\_items}\rceil$ up front and passes `per_items=None` to `Info.post`, charging $\lceil\text{len(out)}/\text{per\_items}\rceil - \lceil\text{reserved}/\text{per\_items}\rceil$ on receipt only if $\text{len(out)} \gt \text{reserved}$ (`thesis/market.py:51-59, 165-174`) | Correct |
| **Per-request candle weights** | Full $1,125$-day daily scope/prefix: $\text{reserved} \in [1081, 1140] \implies 20 + \lceil\text{reserved}/60\rceil = 39$; partial daily prefixes ($70$ listings): weights $22\text{--}31$; full $200$-day ($4,800\text{ h}$) hourly scope: $20 + \lceil 4800/60\rceil = 100$; recorded hourly prefixes ($2$ listings): weights $53, 57$; warm daily tail ($2$ items), warm hourly tail ($\le 60$ items), and $1$-item terminal empty probe: $20 + \lceil\text{reserved}/60\rceil = 21$ | Correct |
| **Discovery ($d = 10$ dexes)** | `Market.listings()` sends $1$ core `meta` ($20$) $+ 1$ `perpDexs` ($20$) $+ 10$ builder `meta` ($200$) $= 12$ requests, $240$ weight per pass (`thesis/market.py:232-238`); at $96$ background passes/day (`PREWARM_EVERY = 15 min`), $96 \times 240 = 23,040$ weight/day ($16.0$ weight/min) | Correct |
| **Daily funding allowance** | `Market.prewarm` runs once per UTC day per market (`_acquired_to < now // DAY * DAY`); a $24\text{--}25\text{ h}$ tail reserves $25\text{--}26 \in [21, 40]$ items $\implies 20 + \lceil\text{reserved}/20\rceil = 22$ weight; across $348$ listings: $348 \times 22 = 7,656$ weight/day ($5.32$ weight/min) (`thesis/market.py:415-418`) | Correct |
| **Recorded-behaviour case** | $12$ discovery ($240$) $+ 349$ tails/terminals of weight $21$ ($7,329$) $+ 269$ prefix probes ($8\times 22 + 7\times 23 + 9\times 24 + 5\times 25 + 2\times 26 + 7\times 27 + 16\times 28 + 5\times 29 + 9\times 30 + 2\times 31 + 197\times 39 + 53 + 57 = 9,637$) $= 630$ requests, $17,206$ weight; packs in $155\text{ min}$ ( both sorted and market-interleaved order); $\text{00:05 UTC [19:05 EST]} + 155\text{ min} + 2 \times 7\text{ min} = \text{02:54 UTC [21:54 EST]}$ ($2\text{ h } 6\text{ min}$ margin) | Correct |
| **Stress case (unclosed candle omitted)** | All $524$ scopes ($348$ daily $+ 176$ hourly) emit a $21$-weight terminal empty request after receiving up to $D - \text{step}$ (adding $524 - 10 = 514$ requests of weight $21$): $630 + 514 = 1,144$ requests, $17,206 + 514 \times 21 = 28,000$ weight; packs in **$252\text{ min}$** in market-interleaved order ($\text{04:45 UTC [23:45 EST]}$ with $4$ mark windows) vs. **$257\text{ min}$** in sorted order ($\text{04:50 UTC [23:50 EST]}$ with $4$ mark windows) | **Discrepancy between text and test (Error 1)** |
| **Hourly mark window** | `MarkLimit.delay` blocks non-priority charges from $H - 55\text{ s}$ (`HOUR - MARK_PREP`) until `release(due)` (at worst $H + 300\text{ s}$, `MARK_WINDOW - MARK_OFFSET`), i.e. $355\text{ s}$, plus $60\text{ s}$ for priority charges to expire $= 415\text{ s} \le 7\text{ min}$ (`thesis/market.py:143-155`) | **With $d = 10$ dexes, exceeds $7\text{ min}$ if Cohort 2 uses $H + 65\text{ s}$ (Error 2)** |
| **Dex mark send-time rule** | `slots = 120 // 20 - 1 = 5` (`thesis/market.py:280`); Cohort 1 ($5$ dexes, $100$ weight) sent at $H + 5\text{ s}$; Cohort 2 ($5$ dexes, $100$ weight) queued at $H + 6\text{ s}$ (`attempt = 1` sleeps $2^0 = 1\text{ s}$): $1$ dex takes the expired `perpDexs` ($20$ weight) slot at $\max(H + 6\text{ s}, t_{\text{disc}} + 60\text{ s}) \in [H + 6\text{ s}, H + 65\text{ s}]$ and $4$ dexes wait until Cohort 1 expires at $H + 65\text{ s}$ | **Retry loop & drain duration bug (Error 2)**

 |

---

### 2. Limiter Packing Argument, Order Dependence, and Omissions

1. **Order dependence of the zero-latency rolling $60\text{ s}$ window**:
At zero latency (`fake_clock`), every request admitted in minute $k$ is stamped at $t = 60k\text{ s}$ and expires at $t = 60(k+1)\text{ s}$, reducing the rolling window to discrete Next-Fit bin packing into capacity-$120$ bins.


* In `test_snapshot_schedule.py:92-97`, `packed()` feeds `[20]*12 + sorted(weights[12:])`. Sorting groups all $863$ requests of weight $21$ into $172$ bins of $5 \times 21 = 105$ ($15$ wasted weight/bin) and all $197$ requests of weight $39$ into $65$ bins of $3 \times 39 = 117$ ($3$ wasted weight/bin), yielding **$257\text{ minutes}$** (`test_snapshot_schedule.py:106`).


* In `Track.snapshot` (`thesis/runner.py:130-139`), requests are issued per market in lexical order. The $197$ listings with $39$-weight daily prefixes have fewer than $45$ daily bars (`1125 - 18*60 = 45`), so they hit `if len(d) < registry.MIN_DAILY_BARS: continue` (`MIN_DAILY_BARS = 90`) and never fetch `1h` bars. Their blocks $[39, 21, 21]$ pair two $39$s with two $21$s ($78 + 42 = 120$, zero waste), packing the stress case in **$252\text{ minutes}$**.


* However, if an inventory has $m$ eligible core listings younger than $45$ days (impossible since `MIN_DAILY_BARS = 90`) or if future history scope increases so eligible core markets emit $[39, 21, 21, 21, 21]$ ($123$ weight), repeating $[39, 21, 21, 21, 21]$ packs at $4$ markets per $5$ minutes ($98.4$ weight/min), which would push $1,144$ requests to $285\text{ minutes}$. Under the current code (`MIN_DAILY_BARS = 90`, `HISTORY["1d"] = 1125d`), an eligible market's daily prefix is at most $1125 - 90 = 1,035\text{ days} \implies 20 + \lceil 1035/60\rceil = 38$ weight ($22\text{--}31$ in the 2026-10-28 inventory), so $252\text{ minutes}$ is the actual code-order packing and $257\text{ minutes}$ is the sorted-order test figure.




2. **Four omissions that shrink the stress-case margin (and can push the stress case past 05:00 UTC [00:00 EST])**:
* **Afifth mark-prep block begins at $\text{04:59:05 UTC [23:59:05 EST]}$, not $\text{05:00:00 UTC [00:00:00 EST]}$**: For $H = \text{05:00 UTC [00:00 EST]}$, `MarkLimit.delay` blocks all non-priority snapshot requests starting at $H - 55\text{ s} = \text{04:59:05 UTC [23:59:05 EST]}$ (`thesis/market.py:150`). The effective completion deadline for the last snapshot request is therefore $\text{04:59:05 UTC [23:59:05 EST]}$ ($55\text{ s}$ earlier than $\text{05:00 UTC [00:00 EST]}$).


* **With $d = 10$ dexes, each hourly mark pause is $\sim 2\text{ min } 10\text{ s}$ minimum (and up to $8\text{ min}$ worst-case), not $1\text{ min}$**: Cohort 2 ($5$ dexes, $100$ weight) is admitted at $H + 65\text{ s}$, and its $100$ weight stays in `self.spent` for another $60\text{ s}$ until $H + 125\text{ s}$ (`thesis/market.py:59, 293-302`). From $H - 55\text{ s}$ to $H + 125\text{ s}$, the mark batch occupies $180\text{ s}$ ($3\text{ min}$) of elapsed time while leaving only $20$ weight ($1$ request) in $[H + 65\text{ s}, H + 125\text{ s}]$; if a retry runs at $H + 230\text{ s}$, the drain plus $60\text{ s}$ expiry is $55 + 230 + 60 = 345\text{ s}$ ($5.75\text{ min}$).


* **Pre-existing background `prewarm` debt at $\text{00:05:00 UTC [19:05:00 EST]}$ ($+1\text{ min}$)**: At $\text{00:00:00 UTC [19:00:00 EST]}$, `_acquired_to(market, now) < now // DAY * DAY` becomes true for all $348$ markets (`thesis/market.py:417`). As soon as the $\text{00:00}$ mark window releases around $\text{00:01:05}\text{--}\text{00:02:05 UTC [19:02:05 EST]}$, `prewarm` spends $5 \times 22 = 110$ background weight before `Track.snapshot` acquires `self.market.hold()` at $\text{00:05:00 UTC [19:05:00 EST]}$, costing $1\text{ minute}$ of initial expiry wait that `packed()` (`clock = [0]`) omits.


* **Foreground `Track.resolve` reads at $\text{00:05 UTC [19:05 EST]}$ and sequential HTTP latency**: Every thesis horizon $T$ is a UTC midnight (`audit/criteria.md:765`). At $D + \text{00:00 UTC [19:00 EST]}$, `positions.outcome` returns `None` because the entry/exit opening reference at $T$ is only available at $T + \delta = \text{00:02 UTC [19:02 EST]}$ (core) or $T + 5\text{ min} = \text{00:05 UTC [19:05 EST]}$ (builder). Thus `Track.resolve` runs again at $\ge \text{00:05 UTC [19:05 EST]}$ with `background=False` (`thesis/runner.py:86-90, 265`), competing directly with `Track.snapshot` inside `self.market.hold()`, while sequential HTTP latency ($\sim 0.3\text{--}1.0\text{ s}$ per request across $1,144$ requests, plus $(m-1)\ell$ window shifts whenever a $39$-weight probe waits for two $21$-weight requests to expire) adds another $2\text{--}5\text{ minutes}$. In the sorted-order stress case ($\text{04:50 UTC [23:50 EST]}$), adding $1\text{ min}$ `prewarm` debt $+ 2\text{ min}$ `resolve` $+ 6\text{ min}$ latency reaches $\text{04:59:05 UTC [23:59:05 EST]}$, triggering the $\text{05:00}$ mark window and missing $\text{05:00 UTC [00:00 EST]}$.





---

### 3. Criteria Revision Review, Adversarial Constructions, and Frozen Threshold Check

#### A. Measurability of Schedule Dependencies in `audit/stage10/criteria-revision-draft.md`

The draft measurably specifies the four nominal times ($\text{00:05 UTC [19:05 EST]}$ cutoff/start, $\text{05:00 UTC [00:00 EST]}$ session deadline/start, $\text{23:00 UTC [18:00 EST]}$ last benchmark registration hour, $\text{24:00 UTC [19:00 EST]}$ day end), the strict `acquired < 05:00 UTC [00:00 EST]` miss rule, the single-page ($500\text{ h}$) funding readiness rule, the per-day reported attestation fields (`taken`, `acquired`, `listed_at`, `requests`), and the two-cohort dex send times. However, it has two gaps against the code:

* **Item 5 claims the benchmark's information set cannot move when its registration hour moves up to $\text{23:00 UTC [18:00 EST]}$**. In reality, `Track.benchmark` (`thesis/runner.py:257-260`) calls `self.inputs("benchmark", [m], now_ms(), snapshot)` and `registry.register(..., now_ms, ..., p_is_base_rate=True)` at `t_r = now_ms()`. That (i) sets `T = monday + 21 * DAY` while `t_r` is up to `monday + 23 * HOUR`, so whenever `t_r >= Monday 12:00 UTC [07:00 EST]`, the holding duration `T - t_r <= 20.5 days` **rounds to $20\text{ days}$ instead of $21\text{ days}$**, changing the base-rate window length and the benchmark's forecast `p = p_ref`; and (ii) reads `1h` bars, `funding`, and live `listed` status at `t_r` (up to $\text{23:00 UTC [18:00 EST]}$), not $\text{00:00 UTC [19:00 EST]}$.


* **Item 1 states $252\text{ min}$ / $\text{04:45 UTC [23:45 EST]}$ ($15\text{ min}$ margin)** while the test it cites (`test_snapshot_schedule.py:106`) asserts $257\text{ min}$ ($\text{04:50 UTC [23:50 EST]}$, $10\text{ min}$ margin before $\text{05:00 UTC [00:00 EST]}$ or $9\text{ min } 5\text{ s}$ before the $\text{04:59:05 UTC [23:59:05 EST]}$ mark-prep cutoff).



#### B. Two Required Run Constructions

1. **Construction 1 — Passes the revised criteria while the protected claim (*"forecasts are made on a timely, attested, identical-for-all-arms snapshot, and every miss is recorded"*) is FALSE**:
* **Part A (Cross-arm snapshot/readiness divergence between `main` and `noread`)**: On Day $D$, the market `X` had its funding prewarmed at $t_0 = D - 20\text{d} - 4\text{h} + 30\text{min}$ (and subsequent background prewarm passes skipped or failed on `X` with transient `httpx.HTTPError` caught in `fill()`, `thesis/runner.py:376`). The daily snapshot is attested on time at $D + \text{02:54 UTC [21:54 EST]}$. At $D + \text{05:15 UTC [00:15 EST]}$, `main` registers a thesis on `X`: inside `Track.inputs` (`thesis/runner.py:105`), `Market.ready("X", now)` checks `now - _acquired_to("X", now) <= 500 * HOUR` ($499\text{ h } 45\text{ min} \le 500\text{ h} \implies \text{True}$), fetches the last page in the foreground, and commits the thesis. Suppose `main` registers on `Y` at $\text{05:15 UTC [00:15 EST]}$ instead, and then `noread` runs at $D + \text{06:15 UTC [01:15 EST]}$ and tries to register on `X`: now `now - _acquired_to("X", now) = 500\text{ h } 45\text{ min} \gt 500\text{ h}$, so `Market.ready("X", now)`is`False`and`noread`receives a failed-read`TransportError`on a market that was available to`main`during the same day's session[cite: 1]. Even when both succeed,`Track.inputs` (`thesis/runner.py:108-109`) evaluates `E_r`and funding rows at`now_ms()` (`t_r`), so `noread`at $\text{06:15 UTC [01:15 EST]}$ sizes on the $\text{06:00 UTC [01:00 EST]}$ hourly bar and funding row that did not exist when`main` registered at $\text{05:15 UTC [00:15 EST]}$.


* **Part B (Late Monday benchmark mutates its own forecast `p_ref` and reads post-midnight data)**: On a Monday, a restart delays snapshot attestation to $\text{13:10 UTC [08:10 EST]}$; `main` and `noread` are recorded missed at $\text{05:00 UTC [00:00 EST]}$, and the benchmark runs at $\text{14:00 UTC [09:00 EST]}$ (`thesis/runner.py:324-328`). Every revised criterion passes, yet at `t_r = Monday 14:00 UTC [09:00 EST]`, `T - t_r = 20.417 days` rounds to $20\text{ days}$ instead of $21\text{ days}$ (changing `p = p_ref`), `attested["listings"]` was read at `listed_at` ($\text{10:30 UTC [05:30 EST]}$), and `inputs()` reads funding and `1h` bars up to $\text{14:00 UTC [09:00 EST]}$.




2. **Construction 2 — Fails the revised criteria while the protected claim HOLDS**:
* Across the $28$-day window, $27$ days attest their snapshots at $\text{02:54 UTC [21:54 EST]}$ and run `main`, conditional ablations, and `noread` on time on the identical attested snapshot ($> 20$ accepted main theses, $0$ unrecorded misses).


* On the fourth Monday, an upstream API outage delays snapshot completion until $\text{23:05 UTC [18:05 EST]}$ (`acquired = MONDAY + 23h05m < MONDAY + DAY`).


* At $\text{05:00 UTC [00:00 EST]}$, `schedule` records `main` and `noread` as missed (`"no attested snapshot before the completion deadline"`), so no LLM session runs on late data and both misses are recorded.


* At $\text{23:05 UTC [18:05 EST]}$, the Monday snapshot is attested on disk and in the ledger, with $55\text{ minutes}$ remaining in the UTC day for the deterministic Monday benchmark to register on the `Monday 00:00 UTC [19:00 EST]` daily bars.


* However, `Track.benchmarks` (`thesis/runner.py:326-328`) computes `due = max(SESSION_OFFSET, self.attested_at(monday))` ($23\text{ h } 5\text{ min}$) and waits until `elapsed >= -(-due // HOUR) * HOUR` ($24\text{ h } 0\text{ min} = \text{MONDAY} + \text{DAY}$), at which point `elapsed < DAY` is `False`. The batch is skipped as `"run missed"`, leaving only $3$ executed benchmark batches in the $28$-day window and **failing C10.5** even though every forecast used a timely, attested, identical snapshot, every miss was recorded, and Monday's attested snapshot was ready $55\text{ minutes}$ before the day ended.





#### C. Does Any Revision Loosen a Frozen Stage 10 Threshold?

**Yes—two items in `audit/stage10/criteria-revision-draft.md` relax frozen rules in `audit/criteria.md`:**

1. **Item 8 (Dex mark send times) relaxes the frozen 2026-10-23 Sampling rule** (`audit/criteria.md:809`, *"For every builder dex and hour boundary H, a request is sent at H + 5 s"*): under Item 8, dexes $6\text{--}10$ are permitted to be sent in a later cohort at $\sim H + 65\text{ s}$ instead of $H + 5\text{ s}$.


2. **Item 5 (Monday benchmark) relaxes the frozen Monday 00:00 UTC [19:00 EST] benchmark rule** (`audit/criteria.md:859`, *"Every Monday at 00:00 UTC [19:00 EST], BTC, ETH, xyz:XYZ100, xyz:GOLD and flx:OIL are processed in that order"*): it allows the benchmark to register up to $23\text{ hours}$ later (entering up to $23\text{ hours}$ later, at `Tuesday 00:00 UTC [19:00 EST]` instead of `Monday 01:00 UTC [20:00 EST]`, over a $20\text{-day}$ holding period instead of $21\text{ days}$) while still counting as one of C10.5's "4 executed benchmark batches".



---

### 4. Other Code Issues That Can Change a Judged Thesis Result Through Timing

1. **`Track.snapshot` can starve `Track.resolve` past C10.5's 2-hour resolution deadline (`thesis/runner.py:259-272`, `ingest/hl.py:48-68`)**:
Every thesis horizon $T$ is at $\text{00:00 UTC [19:00 EST]}$, and its exit reference at $T$ becomes available at $\text{00:02 UTC [19:02 EST]}$ (core) or $\text{00:05 UTC [19:05 EST]}$ (builder), so `resolve`'s $\text{00:00 UTC [19:00 EST]}$ pass returns `None` (`outcome` unresolved) and `resolve` must score the thesis on a pass at or after $\text{00:05 UTC [19:05 EST]}$—within $2\text{ hours}$ ($\text{02:05 UTC [21:05 EST]}$) under C10.5. However, from $\text{00:05 UTC [19:05 EST]}$ to $\text{02:54 UTC [21:54 EST]}$, `Track.snapshot` hammers `WeightLimit.charge` in a tight loop. Because `WeightLimit.charge` has no FIFO queue among foreground callers, whenever `snapshot` is sending $20$- or $21$-weight requests and `resolve` needs a $22$-weight funding page (following a minute of $5 \times 24 = 120$ or $6 \times 20 = 120$), a single expiring $20\text{--}21$ slot admits `snapshot`'s next $20\text{--}21$ request before two slots can coalesce to admit `resolve`'s $22$-weight request, delaying resolution past $\text{01:30 UTC [20:30 EST]}$ (`RESOLUTION_GRACE`, triggering a false `"missing data"` record) or $\text{02:05 UTC [21:05 EST]}$ (violating C10.5).


2. **`Market.record_marks` mixes cohort pagination with error retries in one `for attempt in range(6):` loop and breaks $70\text{ s}$ before the seal (`thesis/market.py:293-302`)**:
With $10$ dexes and `slots = 5`, Cohort 2 consumes `attempt = 1` (and sleeps $1\text{ s}$ before queuing), and the cutoff `if now_ms() + MARK_PREP + TIMEOUT * 1000 >= due - MARK_OFFSET + MARK_WINDOW: break` aborts the loop at $H + 230\text{ s}$ ($H + 3\text{ min } 50\text{ s}$) instead of $H + 290\text{ s}$ ($H + 5\text{ min} - \text{TIMEOUT}$). Because each cohort wave takes $60\text{ s}$ of limiter recovery ($H + 5\text{ s}$, $H + 65\text{ s}$, $H + 125\text{ s}$, $H + 185\text{ s}$), a failed dex in Cohort 2 gets at most $2$ retries before `break` drops its mark for hour $H$, delaying invalidation or leaving a builder thesis unresolved.


3. **`Track.snapshot(now)` reuses an existing `snapshots/{now}.json` without checking whether it was attested (`thesis/runner.py:121-125`)**:
If `snapshot(cutoff)` finishes writing `snapshots/{cutoff}.json` right as `SIGTERM` arrives (`self.stop.is_set()`), `acquire()` returns without writing `snapshot_ready` (`thesis/runner.py:166-167`). If that file was written after a late restart or corrupted before attestation, a subsequent call to `snapshot(cutoff)` returns the unattested file from disk.


4. **An unattested non-Monday `snapshot(cutoff)` continues running past $\text{05:00 UTC [00:00 EST]}$ (`thesis/runner.py:121-146, 162-173`)**:
`Track.snapshot` never checks `self.stop` or `last_acquisition(date)`. If a non-Monday acquisition runs past $\text{05:00 UTC [00:00 EST]}$, `schedule` records `main` and `noread` missed at $\text{05:00 UTC [00:00 EST]}$, while `acquire` keeps holding `self.market.hold()` (blocking `prewarm`) and consuming the $120/\text{min}$ limiter until `snapshot()` finishes.



---

### Summary of Required Fixes (By File and Line)

* **`audit/stage10/criteria-revision-draft.md` (Item 1) & ` thesis/tests/test_snapshot_schedule.py:92-107**`: Reconcile the stress-case packing figure between the text ($252\text{ min}$, done $\text{04:45 UTC [23:45 EST]}$, $15\text{ min}$ margin in market-interleaved order) and `packed()` ($257\text{ min}$, done $\text{04:50 UTC [23:50 EST]}$, $10\text{ min}$ margin in sorted order, or $9\text{ min } 5\text{ s}$ before the $\text{04:59:05 UTC [23:59:05 EST]}$ mark-prep drain), and include the $1\text{ min}$ pre-existing background `prewarm` debt at $\text{00:05 UTC [19:05 EST]}$.
* **`thesis/runner.py:257-260` (`Track.benchmark`) & `audit/stage10/criteria-revision-draft.md` (Item 5)**: Either evaluate the benchmark's base-rate window duration from `monday` instead of `t_r` (or shift `T` with `t_r` by the whole-day offset) and cap `inputs()` funding/bars at `monday` so moving the registration hour past $\text{12:00 UTC [07:00 EST]}$ does not shorten the rounded base-rate window from $21\text{ days}$ to $20\text{ days}$, and allow a Monday snapshot attested in $[\text{23:00 UTC [18:00 EST]}, \text{24:00 UTC [19:00 EST]})$ to register immediately at attestation rather than waiting for $\text{24:00 UTC [19:00 EST]}$ and missing the batch (`thesis/runner.py:326-328`).
* **`thesis/market.py:293-302` (`Market.record_marks`)**: Separate cohort pagination from error retry attempts (so Cohort 2 does not sleep $1\text{ s}$ or consume a retry attempt), and change the loop abort check from `now_ms() + MARK_PREP + TIMEOUT * 1000 >= due - MARK_OFFSET + MARK_WINDOW` ($H + 230\text{ s}$) to `now_ms() + TIMEOUT * 1000 >= due - MARK_OFFSET + MARK_WINDOW` ($H + 290\text{ s}$).
* **`thesis/market.py:134` (`seal`)**: Check `h <= sent < h + MARK_WINDOW and recv <= h + MARK_WINDOW` so a sample with `sent == recv == H + MARK_WINDOW` cannot be sealed into hour $H$.
* **`ingest/hl.py:48-68` (`WeightLimit.charge`)**: Queue foreground callers in FIFO order (or give `Track.resolve` priority over `Track.snapshot`) so a $2.5\text{--}4.5\text{ h}$ snapshot at $\text{00:05 UTC [19:05 EST]}$ cannot starve midnight thesis resolutions past $\text{01:30 UTC [20:30 EST]}$ / $\text{02:05 UTC [21:05 EST]}$.
