# Second exit review

**Stage 1 must not yet be marked done.** The added sources establish much more than pass counts, but several assertions are weaker than the frozen requirements.

| Criterion | Judgment |
|---|---|
| C1.1 Mutants | **Met** |
| C1.2 Adversarial suite | **Not met** |
| C1.3 Hand fixtures | **Not met** |
| C1.4 Differential replay | **Not established** |
| C1.5 Independent timing checker | **Not met** |
| C1.6 Ledger and identity | **Not established** |
| C1.7 Leak canary, amended | **Not established** |
| C1.8 Speed | **Not established** |

“Not established” means the implementation might satisfy the requirement, but this evidence does not demonstrate it. “Not met” below identifies a contradiction or shortfall visible in the supplied suite or procedure—not necessarily a production-kernel defect.

I apply the dated revisions in `criteria-stage1.md`, including the C1.7 amendment. The exit rule remains **“C1.1 to C1.8 all hold”** (`criteria-stage1.md:31`).

## C1.1 — Met

The requirement is **“For each of I1–I9, at least one patch … admits a specific prohibited behavior,”** with **“a named test that detects that behavior”** failing under the patch while the unpatched suite passes (`criteria-stage1.md:20`).

The replacement patches and named commands are now explicit:

| Invariant | Prohibited behavior and detecting test | Source |
|---|---|---|
| I1 | Future bars delivered; `decision_sees_only_closed_bars` | `mutants.py:26–29` |
| I2 | Submission before decision; `timing_order_holds_for_every_fill` | `mutants.py:30–33` |
| I3 | Fill at the close; `delayed_fill_fees_funding_and_rebalance` | `mutants.py:34–37` |
| I4 | Addition ignores units; `type_checker_rejects_with_expected_code` | `mutants.py:38–40` |
| I5 | Funding omitted from the ledger; `equity_reconciles_every_step` | `mutants.py:41–43` |
| I6 | Printing before commit; CLI `unwritable` test | `mutants.py:44–45` |
| I7 | Wall-clock value in results; CLI `fresh_processes` test | `mutants.py:46–48` |
| I8 | Holdout rows admitted; CLI `copied_holdout` test | `mutants.py:49–50` |
| I9 | Leverage and notional limits disabled; `leverage_scale_and_notional_cap` | `mutants.py:51–56` |

The detecting assertions are substantive. Examples include the exact first causal decision (`fixtures.rs:319–324`), timing inequalities (`fixtures.rs:329–337`), independent accounting comparison (`fixtures.rs:303–314`), and bounded size and weight (`fixtures.rs:292–298`).

The runner first executes each command unpatched, applies uniquely matching edits, then executes it patched (`mutants.py:92–101`). It reports “caught” only when:

> `clean == 0 and mutated != 0` — `mutants.py:102–103`

`c11-mutants.txt:1–9,18` records all required mutants caught and exit zero. `test_mutants_apply.py:12–15` additionally checks that the replacement targets remain unique.

**Remaining gap:** none blocking this criterion. This establishes the specified mutation-detection examples, not exhaustive correctness of I1–I9.

## C1.2 — Not met

The controlling words are **“at least 30 programs covering at least 15 distinct mechanisms,” “At least 10 programs come from a GPT red team given only”** the permitted material, and **“Every program is rejected with exactly its expected code”** (`criteria-stage1.md:21`).

### What the new evidence establishes

The updated inventory contains:

| Source | Rejection-expected | Admission-expected | Total |
|---|---:|---:|---:|
| GPT | 30 | 26 | 56 |
| Claude | 38 | 0 | 38 |
| **Total** | **68** | **26** | **94** |

The named threat-matrix coverage remains T1–T15 and T18–T21: 19 mechanisms. The bodies now substantiate many mechanisms directly—for example negative lag, mixed time bases, input offsets, unit relabeling, execution overrides, and duplicate keys (`adversarial-cases.txt:137–167,257–263,297–299,353–359,365–398`).

Round two closes the previous GPT-count and briefing gaps:

- Its allowed inputs and full prompt are recorded in `redteam2-gpt.json:5–10`.
- Its 22 complete attacks are supplied.
- Expected codes were assigned from the specification **before** execution (`redteam2-gpt.json:11–12,609–631`).
- All 22 actual codes match (`redteam2-gpt.json:633–743`).

GPT’s original `null` codes do not invalidate that evidence: the criterion requires programs to declare expected codes, not that GPT itself invent the code vocabulary.

The harness also now prints every comparison and fails on mismatches (`adversarial.rs:27–35`); the full run records those comparisons (`c12-adversarial.txt:8–101`).

### Why it still fails

The suite still deliberately admits 26 programs. Its implementation explicitly converts successful parsing into:

> `_| "ADMITTED".to_string()` — `adversarial.rs:29`

and accepts that outcome whenever the header expects it (`adversarial.rs:28–35`). The run confirms admission, for example in `c12-adversarial.txt:8–16,22–34,38,41`.

That contradicts **“Every program is rejected.”** Having 68 successful rejection cases does not remove the universal requirement over the supplied suite. The admitted programs are often legitimate runtime probes; their admission is **not, by itself, evidence of leakage or a kernel bug**.

Two further evidence limitations remain:

- The T15 bodies are truncated (`adversarial-cases.txt:341–348`), preventing complete inspection of their otherwise-valid construction.
- A previously successful unit-checker evasion is described and retained (`adversarial-cases.txt:401–403`), with current rejection recorded (`c12-adversarial.txt:101`), but its fix and compliance with the referenced §1 bug procedure are not supplied.

**Outcome relevance:** merely classifying valid runtime probes as admitted is not a demonstrated false discovery. However, unresolved runtime probes or incompletely documented fixes could conceal leakage, execution, or unit errors. The universal-rejection contradiction is independently sufficient to fail C1.2.

## C1.3 — Not met

The requirement is **“At least 8 hand-computed scenarios match exactly,”** with **“expected cash, positions, fees, funding, and equity worked out in the test”** (`criteria-stage1.md:22`).

The fixtures now show genuine hand calculations. The delayed-fill test works through quantities, execution prices, fees, funding, cash, and equity (`fixtures.rs:134–151`); reversal includes independent realized/unrealized arithmetic (`fixtures.rs:174–181`).

But the required component-complete scenarios are not present:

- **Zero-trade bar:** asserts an unfilled event and the subsequent fill’s quantity, price, and time, but no worked-out cash, fees, funding, or equity (`fixtures.rs:156–164`).
- **Liquidation:** calculates the margin breach and asserts liquidation quantity, reference, price, and time, but not resulting cash, fees, funding, positions, and equity (`fixtures.rs:186–198`).
- **Delisting:** asserts closeout quantity, price, time, and ordinary-fill count, not the complete account outcome (`fixtures.rs:223–233`).
- **Min-notional/rounding:** asserts quantities, fill count, and closing time, without the required account components (`fixtures.rs:237–249`).
- **Funding settlement:** asserts settlement reference and payment, plus a missing-rate rejection, but not a complete hand-computed account state (`fixtures.rs:253–264`).

Nor are the numerical comparisons literally exact:

> `(a - b).abs() < 1e-9` — `fixtures.rs:123–125`

The passing 17-test record (`c13-fixtures.txt:4–23`) establishes the assertions actually written, not the stronger component-complete requirement.

**Missing precisely:** eight qualifying scenarios with all five expected components worked out and compared as required. The component omissions are decisive even apart from the tolerance issue.

**Outcome relevance:** yes. Incorrect cash movement, fee charging, funding signs, or residual positions can inflate performance while the currently asserted fill fields remain correct.

## C1.4 — Not established

The requirement is a W0 replay on **“the stage 0 dataset version”** whose **“trace (decisions, fills, funding, equity)”** matches **“to $1e-6 at every step,”** with every disagreement resolved and its root cause recorded (`criteria-stage1.md:23`).

The test now visibly launches `mm eval` on `kernel/strategies/w0.json`, passes a stage-0-derived version, and invokes the Python witness (`test_differential.py:17–20,33–42`). Equity timestamps and absolute equity differences are checked at every recorded mark (`test_differential.py:45–47`).

The remaining comparison gaps are material:

1. **Fill prices use relative, not absolute, tolerance:**

   > `abs(a["price"] - b["price"]) <= TOL * a["price"]`  
   > — `test_differential.py:52`

   With `TOL = 1e-6` (`:14`), prices above $1 can differ by more than $1e-6 and pass.

2. **Funding compares only event existence:**

   > `key = lambda e: (e["t"], e["coin"])`  
   > — `test_differential.py:58–59`

   Rates and settlement prices—present in the witness trace (`witness.py:105–108`)—are not compared. Neither are payment amounts independently compared.

3. **Decisions compare only time, coin, and quantity** (`test_differential.py:55–56`), although the witness records rate, price, and input availability times (`witness.py:152–153`).

4. Filtering event types, and sorting funding keys, does not verify the complete cross-event ordering.

The disagreement record is useful: it identifies ordering, fill eligibility, universe/arithmetic/order, and revision-resolution causes, and states that the judged October 26 run followed their resolution (`c14-disagreements.md:3–14`). It improves the history evidence substantially. It does not repair the comparison omissions.

The selected numeric dataset version and content identity are also absent from `c14.txt`; the selection rule is “latest” ingest report rather than an explicitly recorded version (`test_differential.py:17–20`).

**Missing precisely:** complete required trace comparisons at the stated absolute tolerance, plus the judged replay’s explicit dataset identity.

**Outcome relevance:** yes. Funding errors, execution-price discrepancies, and incorrect settlement/fill ordering can change returns or mask timing leakage even when aggregate equity agrees within tolerance.

## C1.5 — Not met

The criterion requires GPT to implement the checker **“from the paper and INVARIANTS.md alone,”** at least 1,000 source-bar traces, **“at least half with labeled planted violations,”** and **“Both checkers match the labels on all of them”** (`criteria-stage1.md:24`).

The supplied provenance explicitly names an additional input:

> “from whitepaper.tex, INVARIANTS.md **and FORMAT.md alone**”  
> — `gpt_checker.py:1–2`

`FORMAT.md` includes more than field names: it specifies exact floating-point calculation/comparison order and verdict precedence (`FORMAT.md:15–23`). Thus the documented implementation procedure does not satisfy the stipulated input restriction.

Other parts are substantially supported:

- The test generates 2,000 cases (`test_timing.py:24`).
- Each includes source bars (`gen.py:19–32,207`).
- Planted wrong-bar, early-bar, zero-trade, and timing violations are implemented (`gen.py:94–124`).
- The GPT checker implements timing and source-bar checks (`gpt_checker.py:10–11,22–50`).

Two acceptance gaps remain independently:

- The label-count assertion permits only **900 violations out of 2,000**:

  > `>= len(cs) / 2 - 100` — `test_timing.py:35`

  The generator’s 60% planting probability (`gen.py:202`) makes adequate coverage likely, but the actual count is not reported. This is not evidence that the realized corpus had fewer than half.

- Kernel verdicts are compared through `zip` without checking cardinality or IDs (`test_timing.py:29–30,43–45`). A shortened matching output—even empty output—can pass that assertion. The GPT-side list does cover every generated case (`:53`).

**Missing precisely:** compliant restricted-input provenance, the realized violation count establishing at least half, and a complete one-to-one kernel-verdict comparison.

**Outcome relevance:** yes. Shared checking assumptions or silently omitted verdicts could leave timing/fill violations undetected. The extra briefing does not itself prove that either checker is wrong.

## C1.6 — Not established

The requirement includes **“every identity field in paper §[7] plus the I7 hashes,” “emit no statistics,”** and **“two fresh processes produce byte-identical results”** (`criteria-stage1.md:25–26`).

### Established

UPDATE and DELETE are attempted against populated ledger tables and must raise an `IntegrityError` containing “append-only” (`test_cli.py:60–69`). The judged run passes this test (`c16-ledger.txt:10`).

The read-only-ledger test establishes nonzero exit, empty stdout, and absence of two named statistics from stderr (`test_cli.py:72–79`).

### Not established

**Identity completeness and correctness.** Paper §7 lists dataset **and certificate versions**, extractor versions, execution/fee versions, availability conventions, simulator version, and the other identity fields (`whitepaper.tex:313–314`).

The test checks a fixed field list (`test_cli.py:22–23`) only for nonempty values:

> `assert all(row[k] not in (None, "") for k in IDENTITY)`  
> — `test_cli.py:55`

It does not establish certificate/extractor-version representation, including explicit non-applicability where appropriate. Nor does it verify that `data_hash`, `rules_hash`, `execution_hash`, and `kernel` actually bind the required contents and build. Nonempty strings cannot establish I7’s content-hash obligation (`criteria-stage1.md:15`).

**Byte identity.** The fresh processes are real subprocesses (`test_cli.py:36–44`), but their outputs are decoded and reduced to disclosure objects:

> `json.loads(...stdout)["disclosure"]` … `assert a == b`  
> — `test_cli.py:82–85`

That proves JSON-value equality, not byte-identical results.

**No statistics on ledger failure.** The stderr assertion excludes only `"sharpe"` and `"equity"` (`test_cli.py:79`). Other statistics could pass. No result-file/trace assertion is present. The first red-team output specifically proposed ledger failure with `--trace` (`gpt-test-cases.json:1313–1329`), but that experiment’s outcome is not supplied.

**Outcome relevance:** identity or disclosure gaps can materially affect leakage accounting and false-discovery control. Serialization-only byte differences need not change statistical outcomes, but the required determinism evidence remains missing.

## C1.7, amended — Not established

The amended requirement retains **“production costs,” “Every adversarial program that is admitted, plus 20 random valid programs,”** and Sharpe **“≤ 4 on every seed,”** while specifying martingale log returns and six fixed plus five drawn seeds (`criteria-stage1.md:27–28`).

Most implementation obligations are now supported:

- Twelve coins, 550 days, 4h bars, σ = 2%, and the amended drift appear in `canary.rs:15–18,45–53`.
- Funding is zero (`canary.rs:70–72`).
- Every successfully parsed adversarial program is included, followed by 20 randomly generated valid programs (`canary.rs:138–155`).
- Six fixed and five test-time seeds are used and logged; every included program must satisfy `s <= 4.0` (`canary.rs:159–169`; `c17-amended.txt:7`).
- Sharpe is annualized from 4h returns, with zero returned for zero variance (`canary.rs:100–105`).
- The deliberately leaking timestamp construction resides in the integration-test source (`canary.rs:42–59`); the test binary and successful power checks are recorded in `c17-amended.txt:4,8–17`.

The remaining gap is **production costs**. The source itself says:

> “production fee and a **production-like cost table**”  
> — `canary.rs:3`

It hard-codes a 0.00045 fee and identical 2/4-bps tables for every synthetic coin (`canary.rs:87–95`). No supplied production cost artifact or comparison establishes that these are the required production costs.

**Missing precisely:** evidence binding the canary’s fee/cost configuration to the production model, and a qualifying run if those configurations differ.

**Outcome relevance:** yes. Changing costs can change net Sharpe and threshold outcomes. The broad program/seed coverage is now established; the cost condition is not.

## C1.8 — Not established

The requirement specifies **“interpretation and all runtime checks,” “no caching,” “W0 over the search part of W,”** and a **“median of 20 runs in one process ≤ 100 ms”** (`criteria-stage1.md:29`). The I5 revision additionally requires post-revision evidence (`:13`).

The benchmark now establishes its outer timing boundaries:

- Data and venue loading occur before timing (`bench.rs:10–15,37`).
- W0 is parsed before the loop (`bench.rs:19–20,38`).
- Twenty calls to `sim::run` execute within one process; the timer surrounds each evaluation, with no ledger operation or result cache in the harness (`bench.rs:21–28,38`).
- The search endpoint is derived from the policy (`bench.rs:13–14`).
- The release-build log reports 14.8 ms, with every measured run below 15.4 ms (`c18.txt:1–8`). Using the upper middle observation rather than averaging the two middle observations cannot undermine the ≤100-ms conclusion here.

What remains unestablished is the judged implementation/build provenance: `c18.txt` supplies no date or build identity tying that measurement to the amended accounting implementation **after October 26, 05:18 UTC**. The benchmark’s comment claims every runtime check and no caching (`bench.rs:1–2`), but the supplied evaluator implementation does not independently establish those internal properties.

**Missing precisely:** a post-revision build/run link establishing that the measured evaluator includes all required runtime checks and does not reuse cached evaluations.

**Outcome relevance:** a missing timestamp alone does not create leakage. An older or check-disabled evaluator could affect leakage/accounting outcomes; speed alone is not evidence of false-discovery control.

## Exit decision

**Do not mark Stage 1 done.** The expanded evidence establishes C1.1 and closes many earlier evidentiary gaps, including qualifying GPT rejection cases and canary program/seed coverage. It does not establish all eight criteria exactly as written.
