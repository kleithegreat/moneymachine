<!-- GPT (openai/gpt-6.1-sol#high), consulted fresh from a clean worktree at 870c407 (branch claude/nine-defects-spec-qhpaks); finished 2026-11-04 05:00 UTC (00:00 EST). Reply taken verbatim. -->
# Review of `870c407`

**Not ready to adopt unchanged.** Most reproducer fixes are direct and causal, but the stated leverage invariant is false, the real-market extension of the loss bound has a counterexample, and mechanism attribution remains insufficiently specified.

The corrected stopped-supermartingale theorem is sound. The tightened **gapless synthetic nulls can satisfy its −2 condition**, but not through the proof currently written.

I read `CLAUDE.md`, `PROGRESS.md`, the parent diff, the nine tests and cited reviews. No files were changed; this is specification review and algebra, not an implementation test run.

## Findings

### 1. High — The fill rule contradicts the leverage invariant used in the proof

**Locations:** `reference/SEMANTICS.md:228–230,264–274`; `kernel/INVARIANTS.md` I3 and I9.  
**Outcomes affected:** accepted fills, liquidation timing, portfolio returns, and the claimed holdout guarantee.

A fill is permitted if it leaves gross within four times equity **or merely lowers gross**. Lower gross does not imply lower leverage: a reversal can trade nearly twice the existing position while barely reducing gross.

For example, before a fill:

- Cash = $3,000; position = −20; mark = $120.
- Equity = $600; gross = $2,400, exactly four times equity.
- Buy 39.99 at $120.24, with zero fee.

Afterward:

- Position = +19.99; gross = $2,398.80 — **lower**, so the fill is allowed.
- Equity = $590.4024.
- Leverage ≈ **4.063**, contradicting I9.

The proof’s assertion that a reducing fill lowers gross “by far more than its cost lowers equity” is therefore false. `Λκ < 1` suffices for an ordinary partial close, not for every gross-reducing reversal. An implementer must choose between the operational permission and the invariant.

**The claimed gap extension also fails under that permission.** Use the same initial book, zero costs, and a pending buy of 39.99:

- Next open = $179.28.
- That bar’s high = $179.28, low = close = $120.
- The fill reduces marked gross from $2,400 to $2,398.80, so it is allowed.
- Its resulting equity, and the equity after the next adverse closeout, is **−$1,770.6072**.

Thus
\[
r'=\frac{-1770.6072-600}{600}=-3.951012.
\]

Yet the largest adverse carrying excursion from the previous $120 mark is \(m=0.494\), with \(\kappa=0\), satisfying the stated \(m\le 1/2-2\kappa\) condition. A pending quantity of 39.99 is compatible with the earlier $100-price, $1,000-equity decision and weight 1.999.

Consequently, “a gap at the open counts in \(m\)” does not establish the claimed extension. The gap and reversal can incur losses that the specified carrying-loss envelope does not cover.

### 2. High — Exposure boundaries and labels are not uniquely implementable

**Location:** `reference/SEMANTICS.md:305–313`.  
**Outcomes affected:** mechanism branch means, coverage, finalist selection, and downstream Holm families.

The new denominator correctly includes undefined exposures. But the exposure population and its labels remain ambiguous:

- An exposure is “one bar”, yet ends at the “next fill instant”. Does that mean every scheduled fill phase, including one without a fill, or the next actual fill?
- Which decision labels an unchanged position when there is no order, an undefined-weight hold, or an unfilled order?
- What ends the final exposure when the position remains open at the horizon?
- At a reversal, the entire fill is assigned to the following exposure because the account remains non-flat. Is that intended, including the closing component’s costs?
- What is reported when \(N=0\)?

This directly matters to M2’s reproducer: it has only two actual fills but 202 held coin-bars. The specification must produce one true exposure, one false exposure, and 200 undefined exposures. Reading “the decision whose fills opened the bar” as the entry decision instead keeps the initial labels throughout the unchanged positions.

**M1’s simple round-trip fixture has the intended answer. M2’s corrected coverage formula is right. But a faithful independent implementation is not yet guaranteed to produce either test’s complete exposure stream.** The prior mechanism consultation explicitly requested these boundary and label rules.

### 3. Medium — K1 removes anticipatory eligibility, but leaves the listing input contract incomplete

**Locations:** `reference/SEMANTICS.md:90–99,195–196,234`; I1.  
**Outcomes affected:** causal isolation, delisting closeouts, funding obligations, and returns.

Replacing eight-hour anticipatory eligibility with current listing status removes the demonstrated allocation lookahead **provided `end(c)` is a genuinely causal venue observation**.

However, the contract does not specify that observation’s representation or provenance. The observation schema contains funding, bars and event counts, but no listing-end record. The existing loader derives the end from the last traded bar across loaded history—the original underlying problem.

An independent implementer needs to know:

- Where the actual delisting event comes from.
- Its availability and revision rules.
- What happens when that event is unavailable.

Assigning `knownAt = end(c)` to a retrospectively inferred last-trade endpoint would not make its provenance causal. The abstract prohibition is correct; the concrete adapter contract is unfinished.

### 4. Medium — These changes include a new execution and null-market policy

**Locations:** I9; `reference/SEMANTICS.md` §7; `gate/NULLS.md:62–68`.  
**Outcomes affected:** liquidation frequency, trading returns, calibration, planted-signal power, and later implementation comparisons.

A 25% maintenance floor, fill-time rejection, ε clipping at 0.3 and wick clipping at 0.1 are substantive model changes—not consequences required by the nine fixture assertions.

They can be reasonable choices for establishing a bounded-null design, but Λ = 4 is a policy choice, not a theorem derived from the target-weight budget of 2. They should be accepted and evaluated as such. The fresh-campaign-ID requirement correctly prevents silently transferring old evidence; old calibration and bit-identical comparison expectations must likewise not transfer automatically.

## Does each revision kill its reproduced cause?

| Defect | Judgment |
|---|---|
| **K1 — future-dependent eligibility** | Correct abstract replacement; concrete listing-event provenance remains unspecified. |
| **K2 — close reopens after liquidation** | **Yes.** Canceling all due orders removes the stale signed-quantity cause, rather than special-casing zero weights. |
| **K3 — holds reserve no budget** | **Yes for the reproducer.** Held gross consumes the fresh-target budget. This does not itself guarantee actual held gross ≤ 2. |
| **K4 — pre-fill sizing equity** | **Yes.** Explicit post-fill equity removes the stale sizing basis. |
| **K5 — bankruptcy resurrection** | **Yes.** Window initialization preserves absorbing bankruptcy. |
| **K6 — missing boundary fills** | **Yes.** Cutting the ordered trace after the boundary Equity record preserves costs belonging to the next return. |
| **M1 — omitted closing costs** | **Yes for the simple round trip**, but general exposure allocation needs Finding 2 resolved. |
| **M2 — undefined-label denominator** | **The arithmetic cause is fixed**; the reproducer’s labels and counts are not uniquely specified. |
| **M4 — replacement bypass** | **Yes as a behavioral requirement.** It explicitly covers replacing conflicts from other connections while preserving harmless duplicate-strategy insertion. |

## The −2 bound and theorem

### The theorem is sound

With predictable bets, integrable pre-absorption returns having nonpositive conditional means, and \(r'_t\ge-2\), the stopped betting wealth is a nonnegative supermartingale. Bankruptcy cannot create a new running maximum under either return convention; subsequent reported returns are zero. Therefore the raw p-values remain valid, including bankrupt paths, and Holm applies to the complete frozen family.

### The tightened synthetic design has sufficient slack—but needs a different proof

For gapless N1–N3, let \(E\) be the recorded equity **before ordinary boundary fills**.

A workable argument is:

1. Margin leaves pre-fill gross at most \(4E\).
2. During fills, equity cannot increase through execution costs. Either admission branch therefore keeps gross at most **\(4E\)**, although not necessarily four times *post-fill* equity.
3. With at most one ordinary fill per coin, total fill notional is at most \(8E\).
4. The new ε, funding and wick envelopes give a carrying/closeout loss envelope below 0.46.

There is also a small accounting correction: for buy-side slippage rate \(s\) and taker fee \(f\), the actual cost per reference notional is **\(s+f+sf\)**, not merely \(s+f\). The synthetic envelope has ample slack for this correction: using 0.003002 gives
\[
r' > -8(0.003002)-4(0.46) > -2.
\]

Thus I do **not** find a −2 counterexample for the tightened, gapless null design under its stated funding and cost caps. I do find that the published proof uses a false invariant, and its real-market extension is false.

Finally, even a repaired observed-\(m\) calculation would be diagnostic, not proof of an **almost-sure** real-market bound. Checking or reporting realized excursions cannot replace a distributional assumption or a valid overshoot treatment.
