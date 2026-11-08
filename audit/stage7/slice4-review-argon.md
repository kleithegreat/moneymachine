# Stage 7 slice 4, review by Gemini 4 Argon (web UI), 2026-11-08 22:18 UTC (17:18 EST)

Reviewer: Gemini 4 Argon in the Gemini web UI, read-only (it could not run code; the harness and byte-comparison reports were supplied). Bundle: `~/Downloads/argon-review-slice4.md`, built by the advisor from `slice4` at `4452591` (three-dot diff from `794860d` over `kernel` and `reference`, the whole `sim.rs`, `market.rs`, `machine.rs`, `Ref/Sim.lean`, `SEMANTICS.md`, the port plan, the slice 3/4 decision lines, the three reports). Builder: Claude Opus. Reply verbatim below, as the human pasted it.

---

**Verdict:** **Merge after fixes** (blocking for full Lean equivalence on retractions/inadmissible rows; safe on clean single-revision/current-store runs, where traces match `794860d` and `refmm`).

---

### Ranked Findings

1. **[High] Event-source delivery tie-breaker keys off `o.slot.is_some()` instead of declaration cadence, while `market::load` dropped `.unwrap_or(k.event)` on `slot**`
* **Location:** `kernel/mm/src/sim.rs:317`, `kernel/mm/src/market.rs:230` vs. `reference/lean/Ref/Sim.lean:213-214` (and `reference/mmdump/src/main.rs:100`).
* **Mechanism:** `Ref/Sim.lean:214` selects the tie-breaker from the declaration's cadence: `if (reg.decls[o.source]!).cadence == .event then [o.recorded, o.key] else [o.key, o.recorded]`. Because `Market` carries no declarations, `sim.rs:317` proxies this with `if o.slot.is_some() { (o.recorded, o.key) } else { (o.key, o.recorded) }`. Simultaneously, `market.rs:230` changed Slice 5's `e.slot.unwrap_or(k.event)` to `slot: e.slot`. Any event-source observation with `slot: None` (e.g., an event retraction without a decoded slot cell, or a test-constructed retraction) falls back to the held tie-breaker `(o.key, o.recorded)`.
* **Concrete failing input:**
* **Program:** `{"let": {"x": {"input": "forum_posts"}}, "weight": {"op": "sign", "args": [{"div": [{"ref": "x"}, {"const": 1, "unit": "ev"}]}]}}`
* **Market / revision pattern:** Coin `0`, source `forum-events` (event cadence). Two observations share `known = 5 * HOUR + DELTA`:
1. Obs A (late retraction of `4 * HOUR`): `key = 4 * HOUR, slot = None, recorded = 5 * HOUR + 10, retraction = true, vals = [None]`.
2. Obs B (live count for `5 * HOUR`): `key = 5 * HOUR, slot = Some(5 * HOUR), recorded = 5 * HOUR + 5, retraction = false, vals = [Some(3.0)]`.




* **Outcome changed:** In `Ref/Sim.lean:214`, both observations use `[recorded, key]`; Obs B (`[5h+5, 5h]`) is delivered before Obs A (`[5h+10, 4h]`), so Obs A overwrites `latest` and `forum_posts` at tick `5 * HOUR` evaluates to `None` (`Event::Hold { why: "undefined" }`). In `sim.rs:317`, Obs A uses `(key, recorded) = (4h, 5h+10)` and sorts *before* Obs B `(5h+5, 5h)`, so Obs B is delivered last and `forum_posts` evaluates to `Some(3.0)`, emitting `Event::Decision` with weight `1.0`. (Additionally, `mmdump/src/main.rs:100` serializes `o.slot` as JSON `null` instead of an integer when `o.slot` is `None`.)
* **Fix:** Store an `event: Vec<bool>` (or cadence flag per declaration) on `Market` (or `is_event: bool` on `Obs`) and restore `e.slot.or_else(|| is_event.then_some(k.event))` on event observations.




2. **[High] Non-retracted role observations with a null role cell (`o.role == None, !o.retraction`) silently drop from `Index` while still feeding `Machine`, instead of refusing with `R_BINDING` (and changing pre-Slice-4 behavior)**
* **Location:** `kernel/mm/src/market.rs:186-194`, `kernel/mm/src/market.rs:232-233`, `kernel/mm/src/sim.rs:213-221`, `kernel/mm/src/sim.rs:320-324`, `kernel/mm/src/sim.rs:358-360`, `kernel/mm/src/sim.rs:533-539` vs. `reference/lean/Ref/Sim.lean:421-430, 471`.
* **Mechanism:** In `market.rs:186-194`, `role_payload` returns `None` if *any* role column is `Cell::Null` (e.g., `trades` is null on a bar, or `fundingRate` is null on a funding row). In `Ref/Sim.lean:423-427, 471`, `Ctx.admissible` (`roleOk`) rejects any non-retracted observation of a role-capable source with `o.role == none` by aborting with `R_BINDING` before step 0. Because Rust does not check `Ctx.admissible`, `sim::run` proceeds: `bar_rows` (`sim.rs:214`) and `rates` (`sim.rs:321`) omit the observation from `Index`, `Ctx::fresh` (`sim.rs:359`) treats it as `"stale"` (`o.role.is_some() == false`), yet `Ctx::deliver` still delivers `o.vals` (e.g. non-null `close` or `premium`) into `Machine` windows.
* **Comparison with pre-Slice-4 Rust (`794860d`):** Old `market::load` defaulted a non-retracted bar's null `trades` to `0`, inserted the bar into `bar_at`, and checked `!o.retraction` in `fresh_bar` (`true`). For a non-retracted funding row with null `fundingRate`, old `market::load` inserted `f64::NAN` into `rate_at` (causing `R_ACCOUNTING` at step 6 when held, and `fresh_funding == true` at step 9), whereas new `sim.rs` drops it from `rate_at` (causing `R_SETTLEMENT_MISSING` at step 1 when held, and a `"stale"` `Hold` at step 9).
* **Concrete failing input:**
* **Market:** 1 coin, bars at `4h, 8h, 12h`, hourly funding `0..=12h`. At bar `4h`, `open = 100, high = 101, low = 99, close = 100, volume = 1`, `trades = NULL` (`Cell::Null`), `tombstone = false`.
* **Program:** `{"let": {"m": {"op": "mean", "hours": 4, "args": [{"input": "close"}]}}, "weight": {"op": "sign", "args": [{"div": [{"ref": "m"}, {"const": 1, "unit": "usd/coin"}]}]}}`


* **Outcome changed:** Lean aborts with `R_BINDING`; pre-Slice-4 Rust (`794860d`) emits `Event::Decision` at `4h + delta` (and `Event::Unfilled` at `8h` from `trades == 0`); Slice 4 (`4452591`) emits `Event::Hold { why: "stale" }` at `4h + delta` while still pushing `close = 100.0` into the `mean` window and completing with `Ok(Run)`.




3. **[Medium] `mmdump` exports bar `open, high, low, close` from `o.role` instead of `o.vals`, masking `vals`-vs-`role` divergences in differential runs**
* **Location:** `reference/mmdump/src/main.rs:92-97` vs. `kernel/mm/src/machine.rs:184-188` and `kernel/mm/src/market.rs:232-233`.
* **Mechanism:** In `market.rs:232-233`, `o.vals` decodes each field in `d.fields` independently, whereas `o.role` decodes all 5 bar role columns together (`open, high, low, close, trades`). `Machine::input` (`machine.rs:187`) reads `o.vals[inp.field]`. However, `mmdump/src/main.rs:92-97` serializes `open, high, low, close` from `o.role` (falling back to `[f64::NAN; 4]` when `o.role` is `None`), unlike `volume`, `funding`, and `premium` which use `field(o, ...)` from `o.vals`.
* **Concrete failing input:** Same market and program as Finding 2 (bar at `4h` with `close = 100.0` in `o.vals` and `trades = NULL` so `o.role = None`), or the C1.7 canary market (`canary.rs:64-66`) where `o.vals` is shifted two bars ahead while `o.role` is unchanged.
* **Outcome changed:** Rust's `Machine` sees `close = Some(100.0)` (or the shifted canary bar) in `o.vals`, whereas `mmdump` writes `NaN` (or the unshifted `o.role` prices) to `MARKET_OUT`, causing `write_streams` (Rust) and `refmm` (Lean) to disagree on node streams and decisions.




4. **[Medium] `Ctx::make` does not filter `market.obs` to bound/delivered sources**
* **Location:** `kernel/mm/src/sim.rs:315-318`, `kernel/mm/src/sim.rs:344-350`, `kernel/mm/src/machine.rs:177` vs. `reference/lean/Ref/Sim.lean:211-212`.
* **Mechanism:** `Ref/Sim.lean:211-212` filters `resolved` to `delivered := adm.delivered reg` (`resolved.filter (delivered.contains ·.source)`). `sim::run` (`sim.rs:534`) only checks that sources *referenced by `prog*` are bound (`prog.sources().into_iter().find(|&s| !market.bound[s])`), and `Ctx::make` (`sim.rs:315`) ingests all of `market.obs` without filtering by `market.bound[o.source]`.
* **Concrete failing input:**
* **Market:** `Market` with `bound[forum_source] = false`, containing an `Obs` for `forum_source` at `known = 4 * HOUR + 100_000`, while `bars` and `funding` at `4 * HOUR` have `known = 4 * HOUR + 60_000` (`policy.delta = 120_000`).
* **Program:** `{"weight": {"const": 1, "unit": "1"}}` (`prog.sources()` is empty).


* **Outcome changed:** Lean filters out the unbound source's observation in `Ctx.make`, so `Fill.inputs_known` at `8 * HOUR` is `4 * HOUR + 60_000`. Rust delivers it in `Ctx::deliver`, advancing `machine.max_known` (`machine.rs:177`) to `4 * HOUR + 100_000` and changing `Fill.inputs_known` in the trace (or panicking at `machine.rs:179` if `o.source >= market.bound.len()`).




5. **[Low] `sim::run`'s `R_INPUT_UNAVAILABLE` error names the first registered input of an unbound source rather than the input the program read**
* **Location:** `kernel/mm/src/sim.rs:534-536`.
* **Mechanism:** `prog.inputs.iter().find(|i| i.source == s)` scans the registry's input table in declaration order and picks the first input belonging to source `s`, regardless of which input node `Node::Input(k)` appeared in `prog.nodes`.
* **Concrete failing input:** A registry declaration `s` (unbound in `market.bound`) with two inputs `["alpha", "beta"]`, and a program referencing only `{"input": "beta"}`.
* **Outcome changed:** Returns `Abort::InputUnavailable("alpha: its source is not bound in this store")` instead of naming `"beta"`.





---

### Answers to Review Questions

#### 1. Semantic Equivalence (`sim.rs` / `market.rs` / `machine.rs` vs. `Ref/Sim.lean`)

* **Where they match:**
* **Latest-per-source reads, known-at cutoffs, and retractions (`machine.rs:152-188` vs. `Ref/Sim.lean:229-238, 265`):** `Machine::new` sizes `latest` to `reg.len()` (`market.bound.len()`); `deliver` enforces `o.known <= tick` (`R_CAUSALITY`), updates `max_known`, and overwrites `latest[o.source][o.coin]`; `input` returns `o.vals[inp.field]` for held inputs and requires `o.slot == Some(self.hour)` for event inputs (returning `None` on retractions since `o.vals` entries are `None`).
* **Step loop (`sim.rs:423-579` vs. `Ref/Sim.lean:270-412`):** Step bounds (`b + 2 * BAR <= stop`), initial delivery/tick at `w_start`, hourly funding on held listed positions (`b + HOUR ..= b + BAR`) priced at the latest bar's `open` with `R_SETTLEMENT_MISSING` on missing rate or bar, mark updates at `b`, adverse-extreme margin liquidation, delisting closeout at `b + BAR >= intervals[c].1`, bankruptcy closeout and negative-cash absorption, `accounting_ok` (`1e-9` scaled by `max(10_000, |e1|, peak)`), `-LOSS_BOUND` check, next-bar-open fills (`b + 3 * BAR <= stop`, `trades >= 1`, `e1 > 0`) validated by `check_fill`, hourly ticks, freshness check (`o.key == big_b && o.role.is_some()`), `MAX_GROSS` scaling (`2.0 * (1 + 1e-12)`), `MAX_ORDER_NOTIONAL` (`10,000`) truncation, and `min_notional` bypass on `w == 0.0` all match `Ref/Sim.lean` step-for-step.


* **Where they differ:** See **Findings 1, 2, and 4** above (`sim.rs:317` tie-breaking on `o.slot.is_some()`, missing `Ctx.admissible` check in `sim.rs:533-539` / `market.rs:186-238`, and unfiltered `market.obs` in `sim.rs:315`). Neither the C6.4 harness corpus nor the unit tests exercise these cases.



#### 2. The Deletions

* **What disappeared without an equivalent:**
1. Unconditional insertion of non-retracted final rows into `bar_at`/`rate_at` (`market.rs` diff lines 279-292) was replaced by `role_payload` (`market.rs:186-194`) without adding Lean's `Ctx.admissible` (`roleOk`) refusal (`Ref/Sim.lean:423-427, 471`) — see **Finding 2**.
2. `e.slot.unwrap_or(k.event)` (`market.rs` diff line 315) was replaced by `slot: e.slot` (`market.rs:230`), exposing `sim.rs:317` when an event observation has `e.slot == None` — see **Finding 1**.
3. `Bar.open_time` as a separate stored field on market bars was replaced by `o.key - BAR` (`sim.rs:216`), making `event == open_time + BAR` hold by construction (requiring the C1.7 canary update in `canary.rs:60-66`).


* **What remains that later slices/cleanups must delete:**
1. `market.rs:147-183`: `fn source(dataset: &str, policy: &Policy)` and `const BINDINGS` still hardcode the four dataset names and column lists instead of building `resolve::Source` from `reg: &[Declaration]` (scheduled for deletion in Slice 6 / C7.4, though note that `mm eval --sources` in `main.rs:82, 279` already passes `reg` into `market::load` while `resolve::resolve` ignores `reg`'s column lists).
2. `reference/mmdump/src/main.rs:85`: `const EVENTS: [&str; 2] = ["forum_posts", "gov_proposals"]` replaces `dsl::EVENT_INPUTS` inside `mmdump` to keep Stage 6 `Main.lean` compatibility until C7.7.
3. `reference/SEMANTICS.md:104`: Still says `"aborts the run before any delivery with R_MARKET"`, whereas `Ref/Sim.lean:471` and `sim.rs:56` use `R_BINDING`.





#### 3. Evaluation of the Supplied Evidence

* **Differential report (`slice4-differential-full-report.json`):**
* The explanation is **sound**: the 1,196 programs partition into `1,135` `ok` verdicts and `61` static type/parse refusals (`10 + 3 + 8 + 4 + 10 + 4 + 6 + 14 + 2 = 61`), with `verdict_disagreements: []` and `run_disagreements: []` across all 3,372 runs. The 22 `corpus_missing` entries (`adversarial-gpt40`..`gpt61 on []`) are all static-refusal test cases that have no market runs (`[]`), which is why the harness sets `pass: false`.


* **Byte-comparison reports (`slice4-trace-identity-933b3f4.json` and `slice4-trace-identity-794860d.json`):**
* The explanation is **sound**: `N1`, `N2`, and `N3` have `0` differences against `933b3f4` across all 216 programs. `liquidation` and `ruin` have `0` trace differences on the 214 `ok` programs and differ only on the 2 `R_INPUT_UNAVAILABLE` probe error messages (`sim.rs:536`). On `edge`, all 57 completed runs differ against `933b3f4` (e.g., `W0` has identical financial metrics and equity `9980.763610226464`, with `holds` dropping from `72` to `71` because an earlier revision of a restated key made one tick fresh), and `edge` has **0 differences** against the parent commit `794860d`, confirming the `edge` change came from Slice 5 (`794860d`), not Slice 4 (`4452591`).


* **What the evidence does not cover:**
1. **Multi-revision keys and retractions against Lean (`refmm`):** Per `audit/decisions.md`, `Main.lean` drops revisions / stops at `R_BINDING`, so `refmm` in the C6.4 harness never tests multi-revision timelines or retractions against Rust.
2. **`Ctx::make` sorting on event retractions:** Unit tests 16 and 19 (`machine.rs:352-394`) call `Machine::deliver` directly in manual order, bypassing `market::load` and `Ctx::make`.
3. **Inadmissible observations (`Ctx.admissible`) and scope checks (`Ctx.inScope`):** No test or corpus run exercises null role cells on non-retracted rows, duplicate `.final` keys, or out-of-range indices.
4. **`R_CAUSALITY` and cross-source delivery ordering at the same `knownAt`:** The 3,372 harness runs have `0` `R_CAUSALITY` aborts; because `Machine::latest` is per-`(source, coin)`, cross-source order at identical `knownAt` is only observable via `max_known` if `deliver` aborts mid-tick.
5. **Holdout mode (`main.rs:156` `holdout_diagnostics`) and `mm check-fills` (`main.rs:595`):** All reported runs are in `mode: "search"`.





#### 4. Anything That Could Change a Backtest Result or a Refusal

1. **Event observations with `slot: None` (`sim.rs:317`, `market.rs:230`):** Flips the delivery tie-breaker from `(recorded, key)` to `(key, recorded)`, changing whether a late correction/retraction overwrites the current hour's event count (changes backtest decisions and returns).
2. **Non-retracted bar/funding rows with a null role column (`market.rs:186-194, 232-233`, `sim.rs:359`):** Changes refusal/execution behavior vs. both Lean (`R_BINDING`) and pre-Slice-4 Rust (drops bar/rate from `Index` and forces `"stale"` holds at step 9 while still updating `Machine` windows; changes null funding rate on held positions from `R_ACCOUNTING` at step 6 to `R_SETTLEMENT_MISSING` at step 1).
3. **Decision sizing price source (`sim.rs:558-561`):** Reads `close` from `o.role` (`RolePayload::Bar`) instead of `o.vals[field["close"]]`, matching `Ref/Sim.lean:383-385` (changes sizing whenever `o.vals` and `o.role` diverge, as in `canary.rs:64-66`).
4. **Unbound source error message (`sim.rs:534-536`):** Changes the `R_INPUT_UNAVAILABLE` message string from `"dataset {ds} is not in this store"` to `"{input}: its source is not bound in this store"`.
