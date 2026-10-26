# Third Stage 1 exit review

**Stage 1 should not yet be marked complete.** Most previous gaps are closed, but the supplied assertions still fall short on fixture count, complete trace comparison, and identity/determinism evidence.

| Criterion | Judgment |
|---|---|
| C1.1 Mutants | **Met** |
| C1.2 Adversarial suite | **Met** |
| C1.3 Hand fixtures | **Not met** |
| C1.4 Differential replay | **Not established** |
| C1.5 Independent timing checker | **Met** |
| C1.6 Ledger and identity | **Not established** |
| C1.7 Leak canary, amended | **Met** |
| C1.8 Speed | **Met** |

These judgments concern the supplied sources and recorded runs, not independently rerun tests. The logs now identify clean commit `571b542de82612ef8494ccc04e60ed8404aa25c9`; their timestamps also establish that the accounting-sensitive evidence follows the October 26, 05:18 UTC revision.

## C1.1 — Met

**Criterion:** For each I1–I9, a patch admits prohibited behavior, and **“a named test that detects that behavior fails, while the unpatched suite passes”** (`criteria-stage1.md:20`).

`mutants.py:26–56` supplies the required patches and detecting commands:

| Invariant | Detecting test |
|---|---|
| I1 | `decision_sees_only_closed_bars` |
| I2 | `timing_order_holds_for_every_fill` |
| I3 | `delayed_fill_fees_funding_and_rebalance` |
| I4 | `type_checker_rejects_with_expected_code` |
| I5 | `equity_reconciles_every_step` |
| I6 | CLI `unwritable` |
| I7 | CLI `fresh_processes` |
| I8 | CLI `copied_holdout` |
| I9 | `leverage_scale_and_notional_cap` |

The runner executes each test unpatched and patched and reports a catch only for:

> `clean == 0 and mutated != 0` — `mutants.py:94–103`

`c11-mutants.txt:2–10` records every required mutant caught, with `exit 0` at line 19.

**Remaining issue:** none blocking this criterion. This establishes the specified mutation examples, not exhaustive invariant correctness.

## C1.2 — Met

**Criterion:** **“at least 30 programs covering at least 15 distinct mechanisms,”** including at least ten qualifying GPT programs, and **“Every program is rejected with exactly its expected code”** (`criteria-stage1.md:21`).

The revised inventory separates:

- **68 rejection cases:** 30 GPT, 38 Claude.
- **26 admitted programs**, outside the rejection directory.

`adversarial.rs:9–20` reads only `tests/adversarial`; lines 27–35 compare every expected and actual code. `c12-adversarial.txt:7–74` records all 68 matching rejections, without admission outcomes.

The named coverage is **19 threat-matrix mechanisms**: T1–T15 and T18–T21. Even without relying on the two truncated T15 bodies, the inspectable inventory exceeds both required minima: 66 programs and 18 mechanisms. The visible bodies embed attacks in complete strategy documents; parse-level cases concern JSON/DSL syntax, duplicate fields, invalid representations, or forbidden fields.

GPT’s restricted briefing and prompt are recorded in `redteam2-gpt.json:5–10`. Its 22 round-two attacks alone exceed the GPT minimum. Expected codes were assigned before execution (`:11–12`), and the recorded outcomes match (`:633–743`).

The retained evasion now has a root cause and fix:

> “the checker interned a conversion node by its factor alone; 5f2b538 … keys it by its target unit as well, in `mm` and the Lean model” — `c12-evasions.md:5`

Its regression body remains in `cases.txt:297–299`, and its current rejection is recorded at `c12-adversarial.txt:74`.

**Remaining issue:** none blocking the required count, coverage, provenance, rejection, or retained-regression evidence. The admitted programs are appropriately assessed under C1.7, not counted as rejection cases.

## C1.3 — Not met

**Criterion:**

> “At least 8 hand-computed scenarios match exactly, each with its expected cash, positions, fees, funding, and equity worked out in the test” — `criteria-stage1.md:22`

### I accept the floating-point reading

I accept the absolute `1e-9` comparisons here as matching the hand-computed decimal results up to binary64 roundoff (`fixtures.rs:125–126`). Many exact decimal results are not representable in binary64; equality to a rounded decimal literal is possible in some calculations but is not generally guaranteed across arithmetic paths.

My second review’s objection to tolerance *as such* was too literal. These small, fixed-dollar fixtures do not need bitwise equality to a handwritten decimal to establish their hand arithmetic.

### The remaining shortfall is the number of complete scenarios

The new `assert_account` compares all five required components (`fixtures.rs:151–156`). There are **seven** component-complete scenario checkpoints:

| Scenario | Assertion |
|---|---|
| Delayed fill, fees and funding | `fixtures.rs:178` |
| Zero-trade bar | `:198` |
| Reversal | `:216` |
| Liquidation | `:235` |
| Delisting | `:273` |
| Rounding/minimum notional | `:292` |
| Missing-bar funding settlement | `:308` |

For example:

> `(4483.4945, 50.0, 5.5055, 5.5, 10483.4945)` — `fixtures.rs:178`

The first scenario covers multiple required subjects, but that does not make it multiple scenarios. The additional 16h rebalance check at line 181 compares equity only; it does not independently assert another complete five-component account state. The bankruptcy fixture likewise does not assert all five components (`:241–256`).

`c13-fixtures.txt` establishes that the written assertions pass, but seventeen tests are not seventeen qualifying hand-computed scenarios.

**Remaining issue and outcome relevance:** the eighth component-complete scenario is missing. **The count shortfall itself cannot change returns or cause leakage.** An accounting error left untested by that missing coverage **could** change performance and a false-discovery outcome. No such error is demonstrated here.

## C1.4 — Not established

**Criterion:** W0 on the stage 0 dataset version must have its **“trace (decisions, fills, funding, equity)”** match the witness **“to $1e-6 at every step,”** with disagreements resolved and their root causes recorded (`criteria-stage1.md:23`).

The earlier numerical and dataset-identification gaps are substantially closed:

- Absolute fill-price and fee comparisons: `test_differential.py:59–63`.
- Decision weights and quantities: `:65–67`.
- Exact funding rate/reference price and absolute payment comparison: `:69–72`.
- Equity at every recorded mark: `:55–57`.
- Event multiplicities by time, type and coin: `:37–38,52`.
- Explicit dataset version **1792613363942**, with event counts and a passing run: `c14.txt:1–5`.
- Resolved disagreement history: `c14-disagreements.md:6–14`.

Two comparison limitations remain.

### 1. Event order is still discarded

The comparison is:

> `sorted((e["t"], e["type"], e.get("coin", "")) ...)`  
> — `test_differential.py:38`

That establishes a complete event **multiset**, not the ordered trace. `INVARIANTS.md:4–5` explicitly defines the trace as an **“ordered list.”** Grouping comparisons by event type also cannot detect a cross-type reorder at the same timestamp.

**Could this change an outcome?** **Yes, if it reflects actual settlement/fill/valuation sequencing:** those operations need not commute. A serialization-only reorder with unchanged computations would not itself change returns. The supplied test does not establish which situation applies to any hypothetical ordering discrepancy; it does not demonstrate an actual production discrepancy.

### 2. The recorded reconciliation value is not compared

The witness records both `equity` and `reconciled` (`witness.py:123–125`), and Rust equity events also contain `reconciled` (`fixtures.rs:355–360`). The differential assertion compares only `equity` (`test_differential.py:57`).

**Could this change an outcome?** A diagnostic-only difference need not change reported performance. An underlying bookkeeping error **could** affect other paths or later evaluations. The matching W0 equity is strong positive evidence, but does not establish agreement of that recorded accounting field.

Thus the strengthened replay passes its present comparisons, but complete trace agreement remains unestablished.

## C1.5 — Met

**Criterion:** GPT implements the checker **“from the paper and INVARIANTS.md alone”;** at least 1,000 source-bar traces, at least half planted violations, including the named timing/fill mechanisms; **“Both checkers match the labels on all of them”** (`criteria-stage1.md:24`).

The fresh implementation’s allowed inputs and full prompt are documented in `c15-gpt-checker.md:3–9`. The format and verdict specification are now within an explicitly permitted source (`INVARIANTS.md:65–86`). Supplying that documented interface does not violate the stated independence requirement.

The implementation checks timing, source selection, no-roll behavior, price and fee calculations (`gpt_checker.py:14–81`). The generator includes source bars and the required planted mechanisms (`gen.py:19–32,94–124`).

The acceptance assertions now require:

> `assert len(verdicts) == len(cases)` — `test_timing.py:30`  
> `assert planted >= len(cs) / 2` — `:38`

The judged output records:

> “2000 traces, 1159 with planted violations” — `c15-timing.txt:10`

Both complete checker comparisons pass (`:12–15`).

**Remaining issue:** none blocking this criterion.

## C1.6 — Not established

**Criterion:** Tests must show append-only triggers, **“every identity field”** in the referenced paper plus I7 hashes, no statistics on ledger failure, and **“two fresh processes produce byte-identical results”** (`criteria-stage1.md:25–26`).

### The later certificate/extractor additions are not a blocker

On the freeze history you provide, I apply the paper’s identity definition **as it stood when C1.6 was frozen**, not the later expanded definition at `whitepaper.tex:314`. Later paper edits do not silently expand a frozen criterion.

Accordingly, absent certificate/extractor columns do **not** fail this pilot exit. Their omission has no demonstrated pilot leakage or false-discovery consequence where those versioned facilities are not used. It would become material for experiments that actually depend on them.

### Established

- Populated ledger tables reject UPDATE and DELETE with “append-only”: `test_cli.py:65–74`.
- Frozen identity fields are present: `:24–25,55–57`.
- Rules, execution and executable hashes equal independently computed SHA-256 values: `:58–60`.
- Changing a store funding value changes `data_hash` and identity: `:92–104`.
- Ledger failure exits nonzero, produces empty stdout, creates no trace, and emits one `R_LEDGER` diagnostic line: `:77–84`.

These tests pass in `c16-ledger.txt:11–17`.

### Remaining issue 1: this is still not a raw-byte comparison

The subprocess helper uses:

> `capture_output=True, text=True` — `test_cli.py:40–42`

The determinism assertion then compares:

> `a.stdout.encode() == b.stdout.encode()` — `:89`

Encoding already-decoded text does not recover the original bytes. Universal-newline decoding can make `b"{}\r\n"` and `b"{}\n"` compare equal after this round trip. Binary stdout capture would establish the requested byte equality directly.

**Could this change an outcome?** **Not by itself:** the demonstrated blind spot concerns representation, not different numerical results or data access. It remains a literal determinism-evidence gap.

### Remaining issue 2: complete dataset-file hash binding is not established

I7 requires identity to pin the dataset files’ content hashes (`criteria-stage1.md:15`; `INVARIANTS.md:15`). The new mutation test proves sensitivity to **one funding file**, not that every eligible dataset file is included, or that the version boundary selects exactly the required files. Unlike the rules/execution/build checks, no expected dataset hash or complete file-digest manifest is independently checked.

**Could this change an outcome?** **Yes.** An omitted file could change evaluated data without changing identity, undermining reproducibility and the audit of what was evaluated. This is an evidence gap, not proof that the loader actually omits files.

## C1.7, amended — Met

**Criterion:** Under the explicit amendment, use the martingale market, six fixed plus five drawn seeds, **“production costs,”** and **“Every adversarial program that is admitted, plus 20 random valid programs”** with Sharpe ≤4 on every seed; the test-only leaking evaluator must exceed 20 (`criteria-stage1.md:27–28`).

The implementation now establishes:

- Twelve coins, 550 days, σ=2%, drift −σ²/2: `canary.rs:16–19,45–68`.
- Zero funding: `:71–73`.
- Production venue loading, unchanged inherited fee/minimum notional, and production per-coin cost cells: `:88–98`.
- Every admitted file must parse successfully, followed by twenty random valid programs: `:140–154`.
- Every included program runs on all eleven seeds and must satisfy `s <= 4.0`: `:158–169`.
- The deliberate timestamp leak exists in the integration-test source: `:43–60`.

`c17-amended.txt:13` logs five drawn seeds; both tests pass. The six displayed leaking Sharpes range approximately **195.88–202.64**, comfortably above 20 (`:6–11`).

**Remaining issue:** none blocking the **amended** criterion. This is not a pass of the original zero-drift-log-return criterion, nor a general false-discovery guarantee.

## C1.8 — Met

**Criterion:** Release build, excluding loading and ledger commit, including **“interpretation and all runtime checks,” “no caching,”** W0 over the search window, and **“median of 20 runs in one process ≤ 100 ms”** (`criteria-stage1.md:29`).

`bench.rs:10–15,37–38` loads data before timing and selects the search endpoint. The single-process loop makes twenty calls to the normal production `sim::run`, without a benchmark-only evaluator, cache, ledger operation, or check-disabling argument (`:19–28`). The same clean commit’s release mutation evidence exercises the production invariant guards.

The previously missing post-revision provenance is now supplied:

> “2026-10-26T11:57:04Z … (clean)” — `c18.txt:1`

The result is:

> “W0 median 15.1 ms over 20 runs (min 14.8, max 15.4)” — `c18.txt:6`

Using the upper middle observation cannot undermine the ≤100-ms conclusion.

**Remaining issue:** none blocking this criterion.

## Exit decision

The frozen exit rule is **“C1.1 to C1.8 all hold”** (`criteria-stage1.md:31`). That is not yet established: **C1.3 lacks an eighth component-complete scenario; C1.4 does not establish ordered, complete trace agreement; C1.6 still lacks literal raw-byte comparison and complete dataset-hash binding evidence.**

These are narrower remaining issues than in review two. None demonstrates an actual false discovery or production leakage incident; their outcome relevance is distinguished above.
