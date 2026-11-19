# Neon's efficiency and correctness audit of the pilot's kernel and gate, and study 1 (`study1-build`)

Model `gemini-4-neon-xhigh` through agy, in a clean detached worktree of `study1-build` (no `data/`, no tokens). Prompt below; reply verbatim. Most of this code is frozen, so its findings are notes. Advisor's checks, 2026-11-18:
- **Finding 1 confirmed as a spec deviation, not a leak.** `DSL.md` defines a window as exactly the last `hours` ticks, but `machine.rs:46-79` keeps running sums with subtraction and recomputes every `n` pushes. A huge value already evicted can still distort `sum`/`mean`/`std` until the next recompute, and `std` cancels on large, steady values. The result is a deterministic function of past data, the same in search and holdout, so it cannot leak or favour an arm. A wrong feature is still a feature the counted trials include. Kernel v2's `Win.push` copies the algorithm, so its semantics go to the architect.
- **Finding 2 checked against the record:** a parameter name with a space or `/` could give two programs one identity. A scan of the 243 programs stored as JSON in study 1's control-arm ledgers, the pilot's ledgers and the thesis ledger found no name outside `[A-Za-z0-9_]`. Restricting names is owed in kernel v2's checker, and before any new campaign on the frozen kernel.
- **Finding 3:** the `_gaps` bug at `t = 0` affects synthetic markets only. The holdout wealth's overflow would crash a campaign, never pass one. Calibration's log scanner lacks the newline rule the others have; calibration is finished.
- **Findings 4 to 10:** cost notes for the next fork, not checked.

## Prompt

# Efficiency and simplicity audit: the pilot's kernel and gate, and study 1 (branch study1-build)

You are auditing this repository's Rust kernel (`kernel/`), the Python gate (`gate/`, including the statistics: SPA and StepM via `arch.bootstrap`, the campaigns, the agent harness), and the ingest and ops code. Read `CLAUDE.md` for the rules. Much of this code is frozen: a study is running on it, and changing anything a frozen identity hashes forks that identity. So your findings are notes for the future, not changes to make now — but they must still be right.

**Find "coal": code that is provably equivalent to something much more efficient or much simpler, as it stands.**
1. **Asymptotic waste:** quadratic or worse work, repeated reads or parses of the same data, recomputation a cache or an incremental update would avoid, bootstrap loops that could be vectorised.
2. **Bespoke code where a well-known, studied algorithm or library fits:** name it, and say why the standard one is safer (statistics especially: a hand-rolled test, resampler or correction where a vetted implementation exists).
3. **Large constant factors** on the paths that dominate a campaign's wall time.

**For each finding:**
- file and lines, what the code does now, and its cost;
- the replacement;
- **why it is equivalent**: identical outputs, including random streams and floating-point order, or exactly where equivalence is only testable;
- **whether it touches frozen code:** say which identity it would fork, if you can tell.

Also flag any place where the bespoke code is not just slow but **wrong**: that matters more than speed, so lead with it if you find one.

Rank by real impact. Skip micro-optimisations and style. Answer in parts under 1,500 words each; end part 1 with "PART 1 END" if you need more than one.

## Reply

### Wrong Bespoke Code (Correctness Defects)

#### 1. Unstable rolling `sum`/`mean`/`std` with post-eviction corruption
- **Where & cost:** [machine.rs](kernel/mm/src/machine.rs#L46-L79) (`Win::Sums`, mirrored verbatim in [Machine.lean](reference/lean/Ref/Machine.lean#L68-L88)). Maintains running `sum`/`sumsq` via `+= v` and `-= v` (recomputing every `n` pushes) and computes `std` via `(*sumsq / n - m * m).max(0.0).sqrt()`.
- **Why it is wrong:**
  1. *Catastrophic cancellation & overflow:* For large-offset/magnitude inputs (e.g., `std(mul(close, volume), hours=24)` where $v \sim 10^8$–$10^9$ puts $v^2 \sim 10^{16}$–$10^{18}$, binary64 ULP $2$–$256$), `sumsq / n - m * m` cancels to garbage or `0.0`. For any finite $|v| > \sqrt{\text{f64::MAX}/n} \approx 10^{153}$, `v * v` overflows to `+inf`, yielding `None` even on a constant window (true `std = 0`).
  2. *Eviction pollution violating `DSL.md` window locality:* Because `since_exact` resets only every `n` pushes, an outlier **already evicted from the window** corrupts outputs for up to $n - 1 \le 4{,}379$ hours ($\approx 6$ months). Concrete case (no overflow): $n=100$, $x_0=10^{20}$, $x_1\dots x_{198}=1.0$. At tick 99, `since_exact` hits 100 while $x_0$ is still in `buf`, recomputes `sum = 1e20` (since `1e20 + 99.0 == 1e20`), and resets `since_exact = 0`. At tick 100, $x_0$ pops and `*sum -= 1e20` yields `0.0`; adding and popping `1.0` keeps `sum = 0.0` and `mean = 0.0` instead of `100.0`/`1.0` for **all 99 ticks `100..198`**. With finite $x_0 = 10^{200}$ (e.g. `exp(460)`), eviction computes `inf - inf = NaN`, making `std` return `None` for 99 ticks on `[1.0; 100]`.
- **Replacement:** A **two-stack sliding-window monoid queue (SWAG / Okasaki queue)** combining `(count, mean, M2)` via **Chan's parallel variance formula** (Chan, Golub & LeVeque 1979): $O(1)$ amortized per tick, **zero subtractions** (evicted outliers never pollute survivors), centered `M2` eliminates cancellation and raw squaring.
- **Equivalence:** Not bit-identical (fixes wrong outputs); exact in real arithmetic and testable against two-pass population moments.
- **Frozen code:** Yes — forks `mm` binary sha256 (`experiments.kernel`/`identity`, `ops/jobs.py` `record["mm"]`, Study 1's `manifest.json`) and C6.4's `refmm` differential parity; target for kernel v2.

#### 2. Parameter-name collisions in `param_values()` and `canon::term()`
- **Where & cost:** [dsl.rs](kernel/mm/src/dsl.rs#L609-L619) and [canon.rs](kernel/mm/src/canon.rs#L72-L73), [canon.rs](kernel/mm/src/canon.rs#L128). `param_values()` re-serializes `self.canonical()` (already computed at [main.rs](kernel/mm/src/main.rs#L324)) and matches `l.starts_with(&format!("param {} ", p.name))` ($O(|P|\cdot|V|)$). `canon::term()` formats leaves as `param/{name}/{unit}` without escaping.
- **Why it is wrong:** [dsl.rs](kernel/mm/src/dsl.rs#L378-L386) accepts arbitrary JSON keys.
  1. Unused param `"a"` with used param `"a 1"` emits `param a 1 1`, matching `starts_with("param a ")` and injecting unused `"a"` into `params`, `trial`, and `identity`.
  2. `sign(param("a/1", unit="h"))` and `sign(param("a", unit="1/h"))` both type-check (`Op::Sign` accepts any numeric unit) and produce identical egg term `(sign param/a/1/h)` and identical `equivalence_key` (spaces/parens in param names also collide with `SizeThenText`'s S-expression syntax).
- **Replacement:** Collect reachable `Node::Param(k)` indices directly during `canonical()`'s DFS ($O(|V|)$); restrict param identifiers (e.g. `[A-Za-z0-9_]+`) in `dsl.rs` or escape them in `canon.rs`.
- **Equivalence:** `param_values()` is bit-identical on space-free names and fixes names with spaces; escaping `canon.rs` bumps `R_VERSION`.
- **Frozen code:** Yes — forks `mm` binary sha256 (and `R_VERSION` if `canon.rs` changes).

#### 3. Other localized correctness bugs
- **[ingest/checks.py](ingest/checks.py#L21-L34) (`_gaps`):** Line 28 `run = run or t` treats `t = 0` as falsy. On `w_start = 0` (every synthetic market), missing `[0, 2*step)` overwrites `run` from `0` to `step`, misreporting `[step, 2*step)` and undercounting missing bars/funding. **Replacement:** `if run is None: run = t`. **Equivalence:** Identical for `start > 0`, fixes `t = 0`. **Frozen:** No.
- **[gate/gate.py](gate/gate.py#L157-L175) (`holdout_pvalues`):** Line 171 `np.cumprod(1 + bet * r)` overflows binary64 (`> 1.8e308`) on large positive long-holdout returns (e.g., 5,400 steps), raising `ValueError("holdout wealth non-finite")` (crashing the campaign) even though `bet ∈ [0, 0.5]` and `r >= -1` guarantee `1 + bet * r >= 0.5 > 0`. **Replacement:** `np.exp(-np.cumsum(np.log1p(bet * r), axis=-1).max(axis=-1, initial=0.0))`. **Equivalence:** Mathematically identical; differs by a few ULPs (testable, eliminates overflow). **Frozen:** In Study 1's `manifest.py` `judged_path()` (via `runner.py → campaigns.py → gate.py`) once step 7 freezes `manifest.json`; forks stage 2's gate.
- **[gate/control/calibrate.py](gate/control/calibrate.py#L127-L137) (`scan`):** Unlike `campaign.py:122`, `runner.py:84`, and `ops/jobs.py:509`, `scan()` does not require `line.endswith(b"\n")` and only catches `JSONDecodeError` (not `UnicodeDecodeError`). A kill between `}` and `\n` truncates to a newline-less line, so the next append in `evaluate()` joins `{...}{...}\n` and drops all later lines. **Replacement:** Require `line.endswith(b"\n")` and catch `(json.JSONDecodeError, UnicodeDecodeError)`. **Equivalence:** Identical on intact logs. **Frozen:** In Study 1 `manifest.py` `judged_path()` (via `searcher.py:16`).

---

### High-Impact "Coal" (Ranked by Real Impact)

#### 4. Market load & process/SQLite churn (~40% of Study 1's 350–443 core-hours)
- **Where & cost:** [market.rs](kernel/mm/src/market.rs#L195-L438), [main.rs](kernel/mm/src/main.rs#L92-L94), [ledger.rs](kernel/mm/src/ledger.rs#L68-L120), [measure.py](gate/control/measure.py#L69-L99). Study 1 runs ~3.5M `mm eval` starts at `0.18 s` each ([arithmetic.py.txt](audit/program/arithmetic.py.txt#L301)) $\approx$ **175 core-hours**.
  1. `Table::read` (`:205-208`) reads every Parquet file whole (`fs::read`) to hash it, then **re-opens and re-reads** it (`File::open`).
  2. `get_row_iter(None)` (`:209-227`) decodes **all** columns including `UNREAD` ones, allocates ~2M `String`/`Field` heap objects per load, and runs linear `self.names.iter().position` on every cell (and again in `resolve()` / extraction loops `:330-417`).
  3. `resolve()` (`:353`) calls `same_values(first.3, best.3)` even when `first.3 == best.3` (100% of synthetic markets), cloning `Field::Str` twice per row (~400k allocs/load).
  4. `market.rs:429-430` inserts ~198k entries into SipHash `HashMap`s (`bar_at`, `rate_at`) despite `bars`/`funding` already being sorted by `(coin, eventTime)`.
  5. `measure.py` spawns a fresh OS process + throwaway SQLite DB (15 DDL statements + 2 fsync commits deleted 50 ms later) per market, and `main.rs:92-94` reads and SHA-256 hashes the entire `mm` binary from disk on every start.
- **Replacement:** Pass `Bytes::from(bytes)` to `SerializedFileReader`; decode only required columns directly via `parquet::column::reader::ColumnReader` (already a dependency); resolve column indices once per file; compare `Cell` directly (preserving NaN inequality); index sorted per-coin slices instead of `rate_at`/`bar_at` `HashMap`s. For scratch scoring (`measure.py`), allow switching markets in a persistent worker `mm` process (caching `kernel_hash()` once and skipping disk fsyncs on scratch-only mode without weakening I6 for audited ledgers).
- **Equivalence:** The `market.rs` rewrite is **bit-for-bit identical** (same `Market`, `data_hash`, `LoadError::Holdout` order, NaN handling). Persistent scratch `mm` yields bit-identical `sharpe_annualized`.
- **Frozen code:** `kernel/mm/src/{market,main}.rs` forks `mm` binary hash; `measure.py` is in Study 1's `manifest.py`.

#### 5. Duplicate twin generation, unvectorized holdout-day loops, and duplicate Parquet writes (~32% of Study 1's wall time)
- **Where & cost:** [pairs.py](gate/control/pairs.py#L45-L97), [markets.py](gate/markets.py#L164-L240). `115 × 0.095 s` generation + `114 × 0.05 s` writes = `16.6 s`/market (**~110–140 core-hours** in Study 1).
  1. `write_pair` (`pairs.py:91-97`) calls `markets.generate` **twice independently** for planted and twin, duplicating all RNG draws (`funding_paths`, `truncated_t` × 2, `w`, `volume`) and all loops for the 6 identical unplanted coins, then `scored_store` builds and Zstd-compresses the **bit-identical 158,400-row `funding/1.parquet`** twice.
  2. `generate` (`markets.py:209-223`) runs two Python `for k in range(4380)` loops over all 730 days (and `scored_store` builds 730-day Polars DataFrames only to filter out the last 180 holdout days!), recomputing `signal = -np.clip(...)` 4,380 times in Python even when `beta == 0` (all nulls & twins) and looping even for recurrence-free `N1`/`N3`. Line 216 allocates 4 `np.arange(n)` index arrays instead of zero-copy slices `f[i:4*n+i:4]`.
- **Replacement:** Fuse `(planted, twin)` into one pass: keep full `days=730` RNG draw shapes unchanged (preserving RNG stream!), hoist vectorized `drift = planted_mask * beta * signal` outside Loop 1 (skipping when `beta == 0`; vectorizing `N1`/`N3` fully), stop both causal loops at `n_search = 3,300` for `scored_store`, compute coins `6..11` once, build Polars frames only on `0..n_search`, and `os.link` the identical `funding/1.parquet` + `venue/`/`policy.json`/`version` between planted and twin.
- **Equivalence:** **Bit-for-bit identical** (RNG streams, search-period arrays, and FP order `(px * num) / den` preserved; vectorizing Loop 2 via `np.cumprod(num / den)` would differ by $\le 1$ ULP and is only testable).
- **Frozen code:** Both files enter Study 1's `manifest.py` `judged_path()` at step 7; `markets.py` is pinned by stage 2's `null_agreement`.

#### 6. Per-evaluation market re-sorting, throwaway 150k-event traces, and `BTreeMap` book (~24% of Study 1 + dominant cost of G100/G400/H400)
- **Where & cost:** [sim.rs](kernel/mm/src/sim.rs#L90-L102), [sim.rs](kernel/mm/src/sim.rs#L250-L471), [main.rs](kernel/mm/src/main.rs#L107-L182), [canon.rs](kernel/mm/src/canon.rs#L91-L144), [machine.rs](kernel/mm/src/machine.rs#L213-L228), [machine.rs](kernel/mm/src/machine.rs#L317-L324) (re-sort copy-pasted in [mmdump/src/main.rs](reference/mmdump/src/main.rs#L58-L66)). `50 ms`/eval × 228 + `0.88 s` G100 $\approx$ **~100 core-hours** in Study 1 and the core cost of 3,700 stage 2 campaigns.
  1. `sim::run` (`:252-262`) allocates and sorts `f_order` (158,400), `b_order` (39,600), and `e_order` **from scratch on every strategy evaluation** (even when 100–400 strategies share one `Market`), and linearly searches `event_slots` on every event (`:311`).
  2. `sim::run` (`:266`) unconditionally builds `trace: Vec<Event>` (~150k events, ~12 MB) and filters it in `reported()`, even when `--trace` is absent (99.99% of runs) and `summary()` only needs 6 running scalars.
  3. `Book` uses three `BTreeMap<usize, f64>` for 12 dense coin indices `0..n`, plus 13,200 `Vec<bool>` allocations for `listed` (`:422`) and per-bar `Vec`/`BTreeMap` churn. `canon::rules()` reparses 16 `egg` pattern strings on every `evaluate()`. `machine::rank` is $O(C^2)$ per tick (quadratic if universes grow).
- **Replacement:** Pre-sort `funding`, `bars`, and flattened `(slot, Event)` directly in delivery order inside `market::load` once (cache-sequential reads); accumulate the 6 `summary` scalars directly when `--trace` is `None`; use length-`n` `Vec<f64>` in `Book` and reusable scratch buffers; cache `canon::rules()` in `OnceLock`; sort + group tie runs in `rank` ($O(C \log C)$).
- **Equivalence:** **Bit-for-bit identical** (iterating `0..n` matches `BTreeMap` FP sum order; scalar accumulation matches `trace` scan order; `rank` counts exact integers with `-0.0 == +0.0`).
- **Frozen code:** Forks `mm` binary sha256.

#### 7. Python per-row JSON+SHA256 hashing in `Store.write` (~20+ core-hours across Study 1 & Stage 2)
- **Where & cost:** [store.py](ingest/store.py#L77-L125) (`1.71 s`/2-year market = **14.6 core-hours** on Study 1's 30,800 searched markets; `~8.5 s`/10-year market $\approx$ **6+ core-hours** in `sweep.betas`, `sweep.truth`, `probes`). `Store.write` converts every row to a Python `dict`, calls `json.dumps(r, sort_keys=True)` + `sha256` (`:100-101`), and on non-empty stores **re-hashes every row of `current`** (`:112`) before anti-joining. `Store.revisions()` (`:77-87`) re-reads every historical Parquet file whenever one file is added.
- **Replacement:** Anti-join directly in Polars on `cols` (`how="anti", join_nulls=True`) and run `_hash` only on surviving changed rows; append only new Parquet files in `revisions()`; use `pairs.scored_store` for throwaway search-only markets in `sweep.net_returns` and `probes.gross_pnl` (and `calibrate.g100_trial` at next study fork). Also replace GIL-serialized `ThreadPoolExecutor` in [sweep.py](gate/sweep.py#L164-L172) with processes, parallelize [probes.py](gate/probes.py#L164-L166), and replace quadratic `np.vstack([X0, X])` in [probes.py](gate/probes.py#L50-L53) with one final `np.vstack`.
- **Equivalence:** Polars `anti` join produces identical written rows and hashes (assuming no NaN keys); `scored_store` is bit-identical on kernel outputs (L1.5).
- **Frozen code:** `store.py` and `sweep.py` enter Study 1's `manifest.py`; `probes.py` is unfrozen.

#### 8. Redundant `StepM`/clustering/DSR/SQLite passes and unvectorized `arch` bootstraps in the gate
- **Where & cost:** [gate.py](gate/gate.py#L64-L155), [campaign.py](gate/campaign.py#L44-L48).
  1. `search_decision` calls `stepm(r, screened, seed)` (`:112`), then `effective_n` (`:148-151`) **re-runs identical `stepm` for `"raw"`** plus unmemoized `stepm` for `cluster_0.9`/`cluster_0.5`.
  2. `clusters(r, 0.9)` and `clusters(r, 0.5)` (`:126-148`) compute $O(TN^2)$ `np.corrcoef` + $O(N^2)$ `linkage` **twice**.
  3. `dsr` runs **4× per strategy**, recomputing moments each time when only `s0(n)` varies.
  4. `campaign.py:44-48` calls `gate.trials()` **3×** per campaign (parsing all 400 `program` JSONs thrice; `candidates()` discards them).
  5. `arch`'s `SPA._simulate_values` runs a Python loop over `REPS=1000`, copying a `(3300, 400)` slice (~10.5 GB of scattered row gathers per `SPA` call, then repeated inside `StepM` with the exact same `seed`).
- **Replacement:** Compute `linkage` once and cut at `0.1`/`0.5`; vectorize per-column DSR moments once; pass `"raw"`'s `StepM` result and memoize `stepm` by `tuple(screened)`; query SQLite once in `campaign.py` without parsing unused `program` JSONs. For the bootstrap loop: draw the `REPS × T` multiplicity matrix $W$ once from `StationaryBootstrap(BLOCK, seed=seed)` via `np.bincount`, compute all bootstrap means in one BLAS `dgemm` (`W @ r / T`), and share it across `SPA` and `StepM`.
- **Equivalence:** First four changes are **bit-for-bit identical** (same RNG & FP order). BLAS `W @ r / T` uses identical RNG draws with different summation order, so equivalence is **testable to ~1e-14**.
- **Frozen code:** In Study 1's `manifest.py` `judged_path()` (via `campaigns.py`); not in `harness_hash`/`search.identity`.

#### 9. 24/7 mirror CronJob re-hashes entire history and re-backups immutable ledgers every 10 minutes
- **Where & cost:** [live.py](ops/live.py#L416-L453). Every 10 minutes (144×/day):
  1. `kind == "ledger"` (`:416-423`) runs **before** the unchanged `(size, mtime)` skip (`:426`), running full `sqlite3.backup()`, `PRAGMA integrity_check`, and `sha256` over NFS on every finished/parked 25 MB ledger — and `with sqlite3.connect(...)` never closes handles (use `contextlib.closing`).
  2. Line 424 runs `sha256(f, prev["size"])` **before** line 426's skip, hashing tens of GB of closed historical `.jsonl` files 144×/day (despite daily `mirror-verify`), and reads the active day file prefix twice locally (`:424`, `:445`) plus full-file back over NFS (`:449`).
- **Replacement:** Skip ledger backup when `(size, mtime)` match `prev` and no `-wal` exists; close connections with `closing()`; carry line 424's `sha256` hasher through the delta copy loop (1 local pass instead of 2; skipping unchanged past day files trades 10-min source bitrot checks for `mirror-verify`'s daily check).
- **Equivalence:** Identical mirror bytes and `MANIFEST.json` (`mm` uses rollback journal, so commits always update `.sqlite` mtime).
- **Frozen code:** Deployed mirror image (`sha256:5e81095e…`); no scientific identity.

#### 10. Bespoke statistics & cold-path ingest waste
- **Bespoke statistics with vetted replacements:**
  - `holm()` ([gate.py](gate/gate.py#L187-L194)) → `statsmodels.stats.multitest.multipletests(p, method="holm")[1]` (already in `flake.nix` and `test_gate.py`; wrap for empty/bounds validation; bit-identical; Study 1 `manifest.py`).
  - Hand-rolled Clopper-Pearson duplicated in 3 places ([sweep.py](gate/sweep.py#L251-L260), [report.py](gate/control/report.py#L32-L36), [campaigns.py](gate/agent/campaigns.py#L1071)) → `scipy.stats.binomtest(k, n).proportion_ci(method="exact")` (safer centralized edge handling; bit-identical; `sweep.py`/`campaigns.py` in `manifest.py`, `report.py` unfrozen).
  - `block_indices()` ([markets.py](gate/markets.py#L124-L132)) → `arch.bootstrap.StationaryBootstrap` (safer vetted Politis-Romano resampler, but **changes RNG stream** — distributionally equivalent only, forks `markets.py` seeds).
- **Ingest asymptotic/constant waste (unfrozen except `events.py`):**
  - [availability.py](ingest/availability.py#L38-L215): `load()` returns a single-use generator mistyped as `list[Poll]`, causing `judgment()` to re-read hundreds of MB of JSONL 2–4×; `span()` sorts twice (`:60-65`); `merge()` scans clock holes linearly ($O(P\cdot H)$ vs `bisect`, `:113`); `analyze()` builds a new **Polars `DataFrame` per boundary event** (`:195`) for two integer additions.
  - [archive.py](ingest/archive.py#L63-L209): `fetch()` parses 26 GB of raw lz4 JSONL **serially on 1 core** (`:163-166`) and sorts/deduplicates twice (`:88`, `:109`); `bars()` eagerly reads full 20-level book lists instead of `pl.scan_parquet` with predicate pushdown.
  - [events.py](ingest/events.py#L54-L88) (frozen `code_sha256`): `items()` sorts all poll observations ($O(N \log N)$) instead of a single $O(N)$ min-pass; `counts()` scans `first` per key ($O(|K|\cdot|I|)$). Both replacements are bit-identical.
