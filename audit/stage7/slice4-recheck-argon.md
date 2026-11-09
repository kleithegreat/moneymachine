# Stage 7 slice 4 fixes, re-check by Gemini 4 Argon (web UI), 2026-11-09 04:33 UTC (23:33 EST)

Reviewer: Gemini 4 Argon in the Gemini web UI, read-only (the rerun reports were supplied). Bundle: `~/Downloads/argon-recheck-slice4.md`, built by the advisor from `slice4` at `abdb9e3` (Argon's review of `4452591`, the rerun reports, the fix diff `4452591...abdb9e3` over `kernel` and `reference`, the whole `sim.rs`, `market.rs` and `Ref/Sim.lean`). Its new low finding (`Index::of` before `Ctx::admissible` on an out-of-range coin) cannot occur on `market::load` inputs: noted, not acted on (stage 7 parked). Reply verbatim below, as the human pasted it.

---

**Verdict:** **Merge** (all five findings from `4452591` are fixed; one new low-severity divergence on synthetic out-of-range coin indices in `Index::of` is noted below and cannot occur on `market::load` inputs).

---

### 1. Verification of Findings 1–5

| Finding | Status | Mechanism vs. `Ref/Sim.lean` | Behavior on Concrete Failing Input at `abdb9e3` | Would the New Test Fail on `4452591`? |
| --- | --- | --- | --- | --- |
| **F1 (High):** Event tie-breaker & missing slot | **Fixed** | `Market` now carries `reg: &'r [Declaration]` (`market.rs:51-52`). `Ctx::make` (`sim.rs:321`) keys `tie` off `matches!(reg[o.source].cadence, Cadence::Event { .. })`, matching `Ref/Sim.lean:214`. `Ctx::admissible` (`sim.rs:349`) enforces `matches!(d.cadence, Cadence::Event { .. }) == o.slot.is_some()`, matching `Ref/Sim.lean:430, 471`. | **Case A (`o.slot = None` on event obs):** `sim::run` (`sim.rs:615-617`) rejects the market before step 0 with `Err(Abort::Binding(...))` (`R_BINDING`), matching Lean. **Case B (`o.slot = Some(4h)` on event retraction):** Both Obs A (`recorded = 5h+10`) and Obs B (`recorded = 5h+5`) sort by `(recorded, key)`, delivering Obs B then Obs A, so tick `5h` emits `Event::Hold { why: "undefined" }`, matching Lean. | **`ctx.rs:46-55`:** **Yes** (on `4452591`, `run` returned `"ok"` instead of `"R_BINDING"`). **`delivery.rs:121-139`:** **No** — `resolve::resolve` already sets `e.slot = Some(12 * HOUR)` from the tombstone's `eventTime`, so `o.slot.is_some()` was already `true` on `4452591` (it tests `resolve.rs`'s slot retention rather than the `sim.rs:321` fix). |
| **F2 (High):** Null role cell on live role record | **Fixed** | `Ctx::admissible` (`sim.rs:336-351`) checks `role_ok` (`None => o.retraction || d.roles.is_empty()`, `Some(Bar) => d.roles.contains_key("bars") && !o.retraction`, `Some(Rate) => d.roles.contains_key("settlement") && !o.retraction`), unique final keys, `o.coin < self.coins()`, and `o.vals.len() == d.fields.len()`, aborting in `sim::run` (`sim.rs:615-617`) with `R_BINDING`, matching `Ref/Sim.lean:421-430, 471`. | On the 1-coin market where bar `4h` has `close = 100.0`, `trades = NULL` (`o.role = None`), and `retraction = false`, `ctx.admissible()` returns `false` (`role_ok == false`) and `sim::run` aborts before step 0 with `R_BINDING` instead of emitting a `"stale"` hold while feeding `close = 100.0` to `Machine`. | **`ctx.rs:59-66`:** **Yes** (on `4452591`, `run` returned `"ok"` instead of `"R_BINDING"`). |
| **F3 (Medium):** `mmdump` bar export from `o.role` | **Fixed** | `stage6` (`reference/mmdump/src/main.rs:86-116`) now reads `["open", "high", "low", "close"].map(|k| field(o, k))` and `field(o, "funding")` from `o.vals`, and returns `Err(inexact(o))` if a live role record's `o.role` is missing or its bit-patterns differ from `o.vals` (`mmdump/src/main.rs:96-107`). | On both the null-`trades` live bar (`o.role = None`) and the C1.7 canary bar (`o.vals` shifted two bars ahead of `o.role`), `stage6(&m)` returns `Err("...: its role payload is not its values")` instead of exporting `NaN`s or unshifted `o.role` prices. | **`mmdump/src/main.rs:206-225`:** **Yes** (on `4452591`, `stage6` was infallible and exported `[NaN; 4]` and `[100.0, 101.0, 99.0, 100.5]`). |
| **F4 (Medium):** Unfiltered `market.obs` in `Ctx::make` | **Fixed** | `Ctx::make` (`sim.rs:320-327`) filters `order`, `bars`, and `rates` by `delivered(s) = market.bound.get(s) == Some(&true) && !matches!(reg[s].cadence, Cadence::Evidence)`, and `Ctx::machine` (`sim.rs:367`) sizes `latest` to `self.market.reg.len()`, matching `Ref/Sim.lean:211-216, 265`. | On the market with `bound[forum_source] = false` and an observation for `forum_source` at `known = 4h + 100_000`, `Ctx::make` excludes it from `order`; `machine.max_known` stays at `4h + 60_000` and `Fill.inputs_known` at `8h` is `4h + 60_000`. | **`ctx.rs:70-81`:** **Yes** (on `4452591`, `known` was `Some(BAR + 100_000)` instead of `Some(BAR + 60_000)`). |
| **F5 (Low):** Wrong input name in `R_INPUT_UNAVAILABLE` | **Fixed** | `sim::run` (`sim.rs:607-613`) scans `prog.nodes` for `Node::Input(k)` where `!market.bound[prog.inputs[*k].source]` and formats `prog.inputs[*k].name`. | When `hl-bars-4h` is unbound and the program reads `{"input": "open"}`, `sim::run` returns `Err(Abort::InputUnavailable("open: its source is not bound in this store"))` instead of naming `"close"`. | **`ctx.rs:85-93`:** **Yes** (on `4452591`, the error started with `"close:"` instead of `"open:"`).

 |

---

### 2. New Divergences from Lean and Consistency with Rerun Reports

#### New Finding (Low / Non-Blocking)

* **[Low] `Ctx::make` calls `Index::of` before `Ctx::admissible`, panicking on a final bar with `o.coin >= coins` instead of returning `R_BINDING` (and assuming `market.bound.len() <= market.reg.len()`)**


* **Location:** `kernel/mm/src/sim.rs:236-238`, `kernel/mm/src/sim.rs:320, 323, 328, 346, 614-617` vs. `reference/lean/Ref/Sim.lean:130, 429, 469-471`.


* **Mechanism:** In `Ref/Sim.lean:130`, `Index.of` builds `barTimes` via `(Array.range coins).map fun c => ((bars.filter (·.coin == c)).map (·.openTime)).mergeSort (· ≤ ·)`, which ignores out-of-range coin indices so `c.admissible` (`Ref/Sim.lean:429, 471`) can check `o.coin < c.coins` and return `.error .binding` (`R_BINDING`). In Rust, `sim::run` (`sim.rs:614-615`) calls `Ctx::make` before `ctx.admissible()`. Inside `Ctx::make` (`sim.rs:323, 328`), `Index::of` (`sim.rs:236-238`) allocates `let mut bar_times = vec![vec![]; coins]` and indexes `bar_times[b.coin].push(b.open_time)`. Consequently, the check `o.coin < self.coins()` in `Ctx::admissible` (`sim.rs:346`) is unreachable for any final bar observation of `roles.bars`: `Index::of` panics first. (Similarly, `sim.rs:320` indexes `reg[s]` whenever `market.bound.get(s) == Some(&true)` without checking `s < reg.len()` in `admissible`.)


* **Concrete failing input:** A constructed `Market` with 1 coin (`intervals = vec![(0, END)]`), `base()` observations for coin `0`, plus one extra bar `common::bar(1, BAR, BAR + 60_000, [100.0, 101.0, 99.0, 100.0], 1.0, 1)` (`o.coin = 1`, `o.last = true`, `o.role = Some(RolePayload::Bar { .. })`), run with `{"weight": {"const": 1, "unit": "1"}}`.


* **Outcome changed:** `Ref/Sim.lean:471` returns `R_BINDING`; `sim::run` panics at `kernel/mm/src/sim.rs:238` (`index out of bounds: the len is 1 but the index is 1`). (Not reachable via `market::load`, which filters `k.coin` against `venue.coins` at `market.rs:227`.)





#### Consistency with the Supplied Rerun Evidence

The rerun reports (`slice4-differential-full-report.json` and the `933b3f4` comparison being byte-identical to `4452591`'s, and `slice4-fixes-trace-identity-794860d.json` showing `0` differences on `N1`, `N2`, `N3`, and `edge`, and the same `2` message-only differences on `liquidation` and `ruin`) are completely consistent with the diff:

* Every event row resolved from the C6.4 stores has a non-null `eventTime` key, so `e.slot` is always `Some(eventTime)` and `o.slot.is_some()` equals `matches!(reg[o.source].cadence, Cadence::Event { .. })` on all corpus observations.


* Every non-retracted bar and funding row in all six stores has non-null role cells, unique final keys, and `o.vals` matching `o.role`, so `ctx.admissible()` is `true` and `mmdump::stage6` succeeds identically on every corpus market.


* `market::load` (`market.rs:208-225`) only emits `Obs` for bound, non-evidence declarations, so filtering `order` by `delivered(obs[i].source)` (`sim.rs:320-322`) is a no-op on store-loaded markets.


* The only `R_INPUT_UNAVAILABLE` failures in the corpus (`probe-sign-forum-activity` and `probe-sign-forum-burst` on `liquidation` and `ruin`) read `forum_posts` from `forum-events`, which has only one field (`forum_posts`), so `4452591` and `abdb9e3` emit the exact same error string.



---

### 3. `reference/differential.py` Scratch Locking and Reaping (`differential.py:41-63`)

* **Can it delete a live run's scratch?**
* **No, while the run is active inside `yield work`:** `open(root / "lock", "w")` (`differential.py:47`) truncates in place without unlinking `root / "lock"`, so all processes contend on the same inode. Directory creation (`tempfile.mkdtemp`), opening `work / "lock"`, and acquiring `fcntl.flock(held, fcntl.LOCK_EX)` (`differential.py:56-58`) all happen while holding `guard` (`root / "lock"`), and `held` stays open and locked across `yield work` (`differential.py:59-61`). Any concurrent run entering `scratch()` blocks on `guard`, sees `BlockingIOError` on `fcntl.flock(fh, fcntl.LOCK_EX | fcntl.LOCK_NB)` (`differential.py:52-54`), and skips the live directory.


* **Minor teardown race after `yield work` finishes (`differential.py:59-63`):** Because `finally: shutil.rmtree(work)` (`differential.py:63`) runs *outside* `guard` (`root / "lock"`) while `shutil.rmtree(work)` unlinks `work / "lock"` before removing the rest of `work`, a second run starting mid-`rmtree` can acquire `guard`, create a new `old / "lock"` inode via `open(old / "lock", "a")` (`differential.py:50`), lock it, and run `shutil.rmtree(old)` concurrently with the exiting run's `shutil.rmtree(work)`, causing one `rmtree` to raise `FileNotFoundError`.




* **Can it leave a killed run's scratch?**
* **No, once a subsequent run enters `scratch()`:** Python 3 opens `held` (`differential.py:57`) with `O_CLOEXEC`, so child processes (`mm`, `mmdump`, `refmm`) do not inherit the lock file descriptor. When a run is killed (even via `SIGKILL`, including between `mkdtemp` at line 56 and `flock(held)` at line 58), the kernel closes its file descriptors and releases both `guard` and `held`; the next call to `scratch()` locks `old / "lock"` and removes `old` (`differential.py:50-55`). (If no subsequent run ever starts, the last killed run's directory remains in `data/differential` until the next run reaps it.)


* **`test_a_run_reaps_the_scratch_of_killed_runs_only` (`reference/tests/test_differential.py:87-107`):** Would have failed on `4452591` (`d.scratch` did not exist) and accurately tests reaping a `SIGKILL`ed process's scratch while preserving a live process's scratch.





---

### 4. Status of "What Remains" Items

* **`reference/SEMANTICS.md:102-111`:** Fixed. The stale `R_MARKET` text is replaced with `Ctx::admissible`'s exact conditions and `R_BINDING` (`SEMANTICS.md:102-106`), and the delivery order bullet now specifies bound, non-evidence sources and declared cadence (`SEMANTICS.md:109-111`).


* **Hardcoded bindings (`kernel/mm/src/market.rs:148-184`) and `EVENTS` (`reference/mmdump/src/main.rs:86-87`):** Honestly left and documented as stated (`market.rs:182` notes `BINDINGS` remains until Slice 6 wires the run manifest; `mmdump/src/main.rs:81-87` scopes `EVENTS` to the Stage 6 `Main.lean` format; and Port Plan item 4 explicitly records both deferrals).
