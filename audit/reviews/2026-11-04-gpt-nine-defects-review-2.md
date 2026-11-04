<!-- GPT (openai/gpt-6.1-sol#high), consulted fresh from a clean worktree at bc3700b (branch claude/nine-defects-spec-qhpaks); finished 2026-11-04 05:29 UTC (00:29 EST). Reply taken verbatim. -->
# Review of `bc3700b`

**Substantially improved, but not completely closed.** The corrected, bounded synthetic-null design now has a sound −2 argument. The reversal counterexample and mechanism-attribution ambiguities are resolved. However, the paper still overstates the bound’s scope, the listing definition omits the no-delisting case, and the new result-hash check lacks a complete specification.

This was static review of the requested diff, both reviews, decisions, specifications and reproducers. **No files changed; no tests or suite ran.**

## Findings

### 1. High — The summaries and paper claim more than the loss-bound argument proves

**Locations:** `reference/SEMANTICS.md:24–25`; `docs/whitepaper.tex:281,330,350`.

**Outcome affected:** which configurations and campaign results can legitimately claim the holdout error guarantee.

The detailed argument in §7 requires **both** gaplessness and a carrying-loss/cost envelope:
\[
\Lambda\kappa\le1,\qquad m\le\tfrac12-2\kappa.
\]
Gaplessness alone does not establish −2. Nevertheless:

- The semantics introduction says the bound holds “by construction on gapless markets.”
- Paper theorem 6 says the stop-out proves it on markets opening at the previous close.
- The gate introduction, line 330, still identifies the scope assumption as **losses capped at equity**—the insufficient assumption this revision otherwise correctly replaces.

A counterexample to the unrestricted gapless claim, with zero costs and funding:

- Cash −$10,000, long 200 coins, mark $75: equity $5,000, gross $15,000.
- This book survives the 25% maintenance check.
- The next bar opens at $75 and closes, with its low, at $7.50.
- Stop-out leaves pre-absorption equity −$8,500:
  \[
  r'=\frac{-8500-5000}{5000}=-2.7.
  \]

This is **not** a counterexample to the revised synthetic generators: it violates their excursion envelope. It demonstrates why that envelope must accompany the gapless qualification.

There is also a proof-status distinction to preserve. The new −2 argument is a **mathematical argument in the specification**, not the existing Lean `L6_bounded` theorem. That theorem establishes the reported −1 floor for the frozen model. Paper §6’s introduction, saying the statements below are proved in Lean, does not clearly distinguish these.

The paper’s revised holdout paragraph is otherwise mathematically correct. Its surrounding scope and verification claims need to match it.

### 2. Medium — `end(c)` is undefined for a coin without a delisting record

**Locations:** `reference/SEMANTICS.md:94–103,199–202`.

**Outcome affected:** market admission, listing masks, funding, eligibility and closeouts—including ordinary N1–N3 runs.

The new contract correctly requires a dated delisting observation for coins marked delisted. But §7 defines:
\[
end(c)=\min(E,\operatorname{knownAt}(\text{delisting record}))
\]
without defining the case where there is no such record. The previous explicit “∞ if none” disappeared.

This is particularly consequential because the synthetic nulls expressly have **no delistings**. An independent implementer needs the ordinary optional-record rule: absent delisting means `end(c) = E`.

**K1’s unchanged fixture is a separate, acknowledged admission issue.** It marks S0 delisted but supplies no dated record. A faithful corrected implementation must reject that market, not infer the record from its last trade. Consequently, the branch cannot literally claim that **all nine unchanged tests pass**. Supplying causal delisting evidence while retaining K1’s assertions would preserve the test’s purpose; retrospective inference would restore the defect.

### 3. Low — The new gate hash check is not independently implementable from the specification alone

**Location:** `kernel/INVARIANTS.md`, I6.

**Outcome affected:** acceptance of committed results and interoperability between independently implemented kernel and gate components.

I6 now requires recomputing `result_hash` “from its returns and summary,” but specifies neither the digest algorithm nor the byte encoding.

The existing implementation uses:
```text
SHA256(stored summary UTF-8 bytes || concatenated little-endian binary64 returns)
```
That definition currently requires reading `kernel/mm/src/main.rs:346–348`. Parsing and reserializing the summary, hashing the components in reverse order, or using textual returns would produce different hashes.

The rejection behavior should also be explicit enough that an invalid row cannot silently shrink the frozen Holm family. The full-family requirement remains binding.

## Disposition of both earlier reviews

| Earlier finding | Assessment at `bc3700b` |
|---|---|
| **GPT 1 / Claude 3:** gross-reducing reversal breaks leverage proof | **Resolved.** Only non-sign-crossing reductions receive the exception; reversals must satisfy admission. The cost cross-term is corrected. |
| **GPT 1:** claimed real-gap extension is false | **Resolved in the detailed argument.** The extension is withdrawn; real-market −2 is explicitly assumed. |
| **GPT 2 / Claude 5c:** exposure boundaries, labels, terminal intervals, reversal allocation, zero population | **Resolved.** Scheduled step boundaries, lagged labels regardless of fills, terminal marks, whole-reversal allocation and `N = 0` behavior are now explicit. |
| **GPT 3 / Claude 1:** delisting provenance | **Cause resolved.** Recorded venue-rules evidence replaces retrospective trading inference; missing evidence blocks admission. Finding 2 above remains. |
| **Claude 1b:** delisting closeout followed by reopening | **Resolved.** The coin must still be listed at fill time. |
| **Claude 2:** corrected outputs contradict byte identity | **Resolved by the reviewed temporal ordering.** Identity is judged at the tagged pre-fix implementation, then fixes land without a compatibility switch. |
| **Claude 4:** overbroad ledger guarantee and duplicate-strategy conflict | **Resolved within the narrowed threat model.** Schema-preserving replacement must abort; harmless strategy insertion is a no-op; hash verification is required. See Finding 3 and the security note below. |
| **Claude 5a:** missing run/listing names | **Mostly resolved.** Run bounds and names are defined; the absent-delisting case remains missing. |
| **Claude 5b:** division by zero after bankruptcy | **Resolved.** Nonpositive post-fill equity skips scaling and sizing. |
| **Claude 5d:** summary-field definitions | **Resolved.** Fill count, fees, slippage and turnover are defined. |
| **GPT 4 / Claude 6:** new execution and generator policy | **Resolved as a policy decision, not derived necessity.** The latest decision expressly adopts Λ = 4, fill rejection and tighter generator clipping. |
| **Claude 7:** frozen DSL misleads future agents | **Addressed as a deployment obligation.** `PROGRESS.md` requires its revision with the corrected-engine harness fork. It is deliberately not changed for the frozen pilot. |

These are general rules addressing the causes, not fixture-specific exceptions.

## Would the nine tests pass?

Assuming the natural no-delisting default identified above:

| Test | Static result against corrected semantics |
|---|---|
| **K1** | **Not unchanged:** its input is now inadmissible. With an appropriate recorded delisting observation, its assertions follow. |
| **K2** | **Yes:** stop-out cancels every due order; the fixture remains flat at $500. |
| **K3** | **Yes:** held gross consumes the available target budget; the fixture reaches $9,000 rather than adding fresh exposure. |
| **K4** | **Yes:** post-fill equity $9,979.99 produces the −0.200-coin order. |
| **K5** | **Yes:** the reporting account remains zero after prefix bankruptcy; total return remains −1. |
| **K6** | **Yes:** the boundary entry stays in the trace; fees and slippage are $10 each, turnover $10,000, with two fills. |
| **M1** | **Yes:** each round trip contributes −$4 / $10,000, including its closing costs. |
| **M2** | **Yes:** one true, one false and 200 undefined exposures make both defined branches fall below 10% coverage. |
| **M4** | **Yes:** the schema-preserving replacing insert must raise `append-only`, including from the separate connection. |

## The −2 proof, step by step

**For the corrected, bounded, gapless synthetic nulls, the argument now works.**

Let \(E_t\) be the equity recorded at a boundary **before ordinary fills**.

1. **Before ordinary fills:** surviving stop-out leaves adverse-price gross within \(4E\). Moving prices favorably to their marks preserves that inequality: equity increases at least as much as gross can increase. Delisting reductions preserve it when \(4\kappa\le1\). Thus \(G_0\le4E_t\).

2. **During fills:** gaplessness makes reference opens equal those marks. Execution costs cannot raise equity. For a non-sign-crossing reduction of reference notional \(D\), gross falls by \(D\), while equity falls by at most \(\kappa D\). Hence the leverage inequality is preserved. Other fills must satisfy it explicitly.

3. **After fills:** consequently,
   \[
   G_1\le4E_{\text{post}}\le4E_t.
   \]
   This no longer relies on the false claim about gross-reducing reversals.

4. **Traded notional:** with at most one ordinary fill per coin, the triangle inequality gives
   \[
   D_{\text{total}}\le G_0+G_1\le8E_t.
   \]
   Boundary execution costs therefore cost at most \(8\kappa E_t\).

5. **Following bar:** carrying, funding and any adverse closeout lose at most \(mG_1\). Therefore
   \[
   r'\ge-8\kappa-4m=-4(2\kappa+m).
   \]

6. **Generator envelope:** \(c/o<1.48\). For an adverse close move, loss including funding is bounded by \(0.3\), plus a wick below \(0.148\). For a favorable close move, the alternative open-to-extreme calculation bounds loss by \(0.2792\). Closeout cost adds less than \(1.628\kappa\). With the checked \(\kappa\le0.003\), \(m<0.46\), giving
   \[
   r'>-4(0.006+0.46)=-1.864>-2.
   \]

7. **Statistical consequence:** under the separate conditional nonpositive-mean hypothesis, predictable bets with \(\lambda\le1/2\) give nonnegative stopped betting wealth. At bankruptcy, neither the raw terminal factor nor the reported −1 factor can create a new maximum. Earlier factors coincide; later reported returns are zero. Thus the running maxima coincide, Ville applies, and Holm applies to the frozen family.

The favorable/adverse split and \(sf\) fee cross-term now address the earlier proof objections correctly.

## Assumed versus proven

- **Reported returns ≥ −1:** enforced by absorption; covered by the existing frozen-model bounded-return theorem.
- **Corrected synthetic-null pre-absorption returns ≥ −2:** established by the above argument **with the generator and cost conditions**, not by gaplessness alone; not yet an implemented or Lean-checked correction.
- **Real-market pre-absorption returns ≥ −2:** an almost-sure scope assumption. Realized diagnostics cannot establish it.
- **Conditional nonpositive means:** a separate requirement, not a consequence of bounded losses. The null generators’ symmetric innovation and adverse execution argument supplies this separately.

### Notes

- The narrowed ledger contract honestly excludes schema-changing writers. An unkeyed hash detects inconsistent corruption, **not** an actor replacing both content and hash. This is not an unresolved schema-preserving `REPLACE` bypass.
- Λ = 4 and tighter clipping are substantive, reviewed policy changes. Old calibration evidence does not automatically validate the corrected configuration.
- The strict statement “lows stay above \(0.9\min(o,c)\)” should be “at least”; capped wicks can attain equality. Positivity and the bound are unaffected.

**Bottom line:** the core synthetic-bound repair and exposure semantics are now sound. Correct the remaining scope claims and input/hash contract gaps before calling the specification fully independently implementable or claiming nine unchanged passing reproducers.
