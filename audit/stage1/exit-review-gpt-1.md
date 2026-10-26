## Verdict

**Stage 1 is not established as complete.** C1.2 is **not met** by the supplied inventory. The other seven criteria are **not established by this evidence**: their outputs report successful tests, but do not expose enough of the tests’ scope or assertions to establish the frozen requirements. That is an evidence gap, not proof that those implementations fail.

The dated revisions apply as written. C1.7 is assessed under its explicit amendment, not as a pass of the original criterion. “Supporting” does not waive C1.7 or C1.8: the exit rule requires **“C1.1 to C1.8 all hold.”**

## C1.1 — Not established by this evidence

The criterion requires **“at least one patch in `kernel/mutants/`”** for each I1–I9, and **“a named test that detects that behavior fails, while the unpatched suite passes.”**

`c11-mutants.txt` reports a caught mutant for every I1–I9 and exits successfully. This supports the runner-summary requirement. But its behavior descriptions are not named detecting tests, and it does not show the patches, the mutant-induced test failures, or the unpatched baseline passing. Extra I10/C5 mutants do not supply those missing facts.

**Needed:** the patches and a runner implementation or detailed run record linking each I1–I9 patch to its prohibited behavior and named detecting test, showing that test failing under the patch and the unpatched suite passing.

## C1.2 — Not met

The controlling requirements are **“at least 30 programs,” “at least 15 distinct mechanisms from the threat matrix,” “at least 10 programs come from a GPT red team given only the paper, `DSL.md`, and `mm --help`,”** and **“Every program is rejected with exactly its expected code.”**

The inventory counts are:

| Inventory category | Programs | Expected rejection | Expected `ADMITTED` |
|---|---:|---:|---:|
| GPT source | 34 | 8 | 26 |
| Claude source | 38 | 38 | 0 |
| **Total** | **72** | **46** | **26** |

The explicitly identified threat-matrix mechanisms are **T1–T15 and T18–T21: 19 distinct mechanisms**. T16 and T17 are absent, but the criterion requires 15, not every mechanism. `"GPT"` and `"checker"` are not additional threat-matrix mechanisms.

Thus:

- **Program count:** even the rejection-expected subset has 46 entries, exceeding 30.
- **Mechanism count:** the headers identify 19 matrix mechanisms, exceeding 15. Actual case bodies remain necessary to verify those labels and that attacks sit inside otherwise valid programs.
- **GPT requirement:** there are 34 GPT-labelled entries, but **only eight are rejection-expected programs**. The 26 admitted programs cannot supply the missing GPT rejection cases while also satisfying the universal rejection requirement. Moreover, `source: "gpt"` alone does not establish the restricted briefing.
- **Universal exact rejection:** **26 entries explicitly require admission**, meaning type-checking and execution. That directly conflicts with “Every program is rejected.” They may be valuable semantic tests, but cannot establish this frozen criterion.

`c12-adversarial.txt` reports only two passing Rust tests. The name `type_checker_rejects_with_expected_code` does not establish which cases it processes, whether it skips admitted cases, or the actual per-case codes. A green run cannot resolve the inventory contradiction.

**Needed:** a criterion-satisfying suite of at least 30 rejection programs covering at least 15 matrix mechanisms, including at least 10 qualifying GPT-authored rejection programs; provenance demonstrating GPT’s allowed inputs; case bodies establishing otherwise-valid embedding and syntactic justification for parse-error cases; and an auditable case-by-case comparison of expected and actual rejection codes with no omissions. Any discovered evasions also need their fixes and retained regression cases documented. This requires satisfying the existing criterion, not counting admitted programs as rejections.

## C1.3 — Not established by this evidence

The criterion requires **“At least 8 hand-computed scenarios match exactly,”** with **“expected cash, positions, fees, funding, and equity worked out in the test,”** covering the eight named scenarios.

The 17 passing test names suggest relevant coverage, including reversal, delayed fills, liquidation, delisting, rounding and zero-trade bars. They do not show hand calculations, expected component values, or exact comparisons. More than eight passing tests does not establish eight qualifying hand-computed scenarios.

**Needed:** the fixture implementations or equivalent auditable evidence showing the worked-out expected components and exact assertions for all eight required scenarios.

## C1.4 — Not established by this evidence

The criterion requires that **“`mm` replays W0 on the stage 0 dataset version”** and its trace **“matches the stage 0 Python witness to $1e-6 at every step.”** It also requires **“Every disagreement found along the way”** to be resolved with its root cause recorded.

`c14.txt` contains only an anonymous pytest pass count and runtime. It establishes none of the replay identity, trace coverage, comparison tolerance, or disagreement history.

**Needed:** the replay/comparison implementation and a linked passing run identifying W0, the stage 0 dataset version and witness; assertions covering decisions, fills, funding and equity at every step within $1e-6; and the disagreement/root-cause record, or an explicit record that none occurred. Dated build/run provenance is also needed to establish compliance with the I5 revision’s post-revision evidence requirement.

## C1.5 — Not established by this evidence

The criterion requires a GPT checker implemented **“from the paper and INVARIANTS.md alone,”** and **“at least 1,000 traces with source bars, at least half with labeled planted violations,”** including all four specified violation types. **“Both checkers match the labels on all of them.”**

The three passing test names support intended label and checker testing, but reveal neither corpus size nor violation counts, source-bar inclusion, exact category coverage, or GPT’s briefing.

**Needed:** GPT authorship/briefing provenance; checker and generator implementations; a corpus manifest or generation summary establishing at least 1,000 source-bar traces and at least 50% planted violations, including wrong-bar, early-bar, zero-trade-bar and time-order cases; and assertions showing both checkers match every label.

## C1.6 — Not established by this evidence

The criterion requires tests showing that **“triggers reject UPDATE and DELETE,”** the experiment row contains **“every identity field”** from the paper plus I7 hashes, ledger failure makes `mm eval` **“emit no statistics and exit nonzero,”** and **“two fresh processes produce byte-identical results.”** The wording revision changes the paper reference to §7.

The passing test names closely track these obligations, but do not expose their assertions. In particular, “every policy field” is not the same as every experiment-identity field and required content hash.

**Needed:** auditable test assertions and a linked passing run demonstrating:

- SQL triggers actually reject UPDATE and DELETE.
- Stored identity fields are checked against paper §7 and I7, including the required store-file, rules, execution and build hashes.
- A read-only or failing ledger produces no statistics on result-bearing channels and exits nonzero.
- Two independently launched processes with the same identity produce byte-identical results.

The additional spent-holdout test does not replace any of these obligations.

## C1.7, amended — Not established by this evidence

Under the amendment, the market must use Gaussian log returns with **“mean −σ²/2”**, with **“6 fixed, 5 drawn”** seeds. The retained requirement covers **“Every adversarial program that is admitted, plus 20 random valid programs”**, with net Sharpe **“≤ 4 on every seed.”**

`c17-amended.txt` does show:

- Five logged drawn seeds.
- The six fixed seeds, including the added seed.
- Leaking-evaluator Sharpes above 20 on all six displayed fixed seeds.
- Two passing tests.

But it does not show the market construction, production costs, execution of all 26 admitted inventory programs plus 20 random valid programs on every seed, or their complete threshold assertions. The printed “honest” values are not a per-program coverage record. Their negative values are not failures: the criterion imposes an upper bound, not an absolute-value bound.

**Needed:** the amended generator/test implementation and linked run evidence establishing the 12-coin, 550-day, 4h martingale market, σ = 2%, zero funding and production costs; complete program and seed coverage; the Sharpe conventions and universal ≤4 assertions; and proof that the deliberately leaking evaluator is compiled only into this test. The qualifications file records the amendment, but supplies none of this missing coverage evidence.

## C1.8 — Not established by this evidence

The criterion specifies **“data load is excluded,” “interpretation and all runtime checks are included,” “the ledger commit is excluded,” “no caching,” “W0 over the search part of W,”** and **“median of 20 runs in one process ≤ 100 ms.”**

The output establishes a reported release-build median of **14.8 ms over 20 runs** and identifies the CPU. It does not establish the timed boundaries, workload/window, absence of caching, or single-process execution.

**Needed:** the benchmark implementation and linked run/build provenance showing the exact workload, one-process loop, timing boundaries, enabled runtime checks and absence of caching. Relevant post-revision provenance must also be established.

**Conclusion:** the current record cannot support marking the stage done. C1.2 contains a substantive contradiction with the frozen acceptance language; the remaining criteria need auditable evidence behind their passing test summaries.
