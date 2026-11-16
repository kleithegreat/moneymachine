## Verdict: **not accepted**

The pairing rule is coherent **conditional on V22**, and X3 is a sound design for the optimization. However, two source-validation claims are stronger than the specified checks.

### 1. The vault witness does not check a print’s time, and only lower-bounds its size

**Location:** `trades-source.diff`, brief 3, step 6, test 10; architecture §6.4.

The specified witness joins by coin and `tid`, checks price and aggressor, and requires sufficient size. It does **not explicitly require the print’s timestamp to equal the vault fill’s timestamp**.

Construction:

- A real sell-aggressor match occurs at 10,000 ms, price 99, size 1.
- Both archived counterpart rows instead say 12,000 ms, agreeing on all pairing fields.
- An independent simulated buy at 100 arrives and rests at 11,000 ms.
- With the real timestamp, that print cannot fill it under `pessimistic`; with the archived timestamp, it fills.
- The vault’s independently recorded fill still joins successfully: same coin, `tid`, price, side and sufficient size.

Choose fresh quotes throughout, so staleness rejects neither version. Alternatively, moving the timestamp across a stale boundary changes the engine’s staleness mark and therefore layer 2’s classification.

Similarly, changing **both** archived sizes from 1 to 2 passes the stated lower-bound witness while supplying an extra unit of simulated executable flow.

These constructions violate V22; they are **not** counterexamples assuming a perfectly faithful stream. The defect is that “every vault fill has its print” sounds stronger than the actual witness. That witness establishes neither timestamp fidelity nor exact quantity fidelity.

**Outcomes changed:** `pessimistic` fills; layer 2’s timing and staleness measurements; replay cash flows, entries, funding exposure and subsequent orders; consequently the bootstrap’s selected `φ,d` and potentially rung-2 registration.

**Required:** explicitly compare timestamps. State whether the size witness establishes equality or only coverage, and name undetected overstatement as a source-assumption failure if only coverage is intended.

### 2. Coin-day uniqueness does not refuse every differently repeated match

**Location:** `kernel-v2.md`, V22 and B2; `trades-source.diff`, step 6, test 10.

V22 says a match written twice with a difference would become two prints, “which the trade id’s uniqueness refuses.” The actual uniqueness scope is **one coin-day**.

Construction:

1. One valid pair produces a sell-aggressor print with coin C, `tid = k`, price 99, size 1, on day D.
2. The stream repeats the pair with both timestamps shifted into day D+1.
3. Each pair satisfies the derivation.
4. Each coin-day contains `k` only once.
5. There are no unpaired rows or exact duplicates.

Both prints survive. Put a fresh, eligible resting buy at 100 on D+1: the second print credits flow that did not occur then. If the vault did not participate, its witness sees nothing. If it did, the missing timestamp check in finding 1 further weakens detection.

Again, this is a **failure of V22**, not a failure under V22. But it directly contradicts the claimed refusal mechanism.

**Outcomes changed:** extra `pessimistic` fills and price events; replay returns and the confirmer’s bar; guard refusal and pre-freeze parameter selection. Extra price events can matter even when no order fills.

**Required:** either enforce the appropriate wider identity scope, after establishing the venue’s identity guarantees, or narrow the promise and explicitly identify cross-day repetitions as an undetected failure mode. Wider deduplication must not silently assume that `tid` is globally collision-free.

### What the pairing itself establishes

For an authentic, complete, correctly ordered stream in which the venue’s fields have the assumed meanings, the rule:

- emits one match, rather than doubling its size;
- copies the pair’s price, size and time;
- takes aggressor direction from the crossed row;
- rejects or escalates the specified inconsistent and unmatched cases.

I found no construction satisfying **all those premises** that nevertheless changes those fields.

However, matching two rows is not independent evidence of order-book execution. The claim that every accepted execution class corresponds to a public book trade remains part of the source-semantics assumption. Inspecting one hour’s layout, or comparing two implementations of the same pairing sentence, does not establish it. In particular, paired non-book execution classes must not escape scrutiny merely because only **unpaired** rows receive the proposed `dir` classification. I am not asserting that the archive actually contains such a pair.

### Non-validating-node assumption

**Substantially stated correctly:** V22 explicitly assumes completeness, uniqueness and chain fidelity; supplies the vault and unmatched-row witnesses; and acknowledges an invisible missing block without vault activity.

That is an appropriately limited witness, not canonical-chain validation. The failure account needs the additional directions above: wrong time, excess size and surviving duplicate/spurious paired flow. Missing prints are not uniformly conservative at whole-run level: changing one fill changes later exposure and decisions.

### X3 and `@[csimp]`: accepted as a design

An actually kernel-checked equality

```lean
@Exact.readBits = @Exact.readBitsFast
@Exact.onGrid = @Exact.onGridFast
```

over the complete input types excludes any differing returned value or rejection decision. Substituting equals in pure callers preserves every judged computation. NaNs, subnormals, negative rationals and exceptional cases cannot be omitted from that equality.

This remains conditional on the declared compiler/runtime trust boundary, and the supplied changes specify future proofs rather than demonstrate completed proofs. There is no additional semantic loophole inherent in `csimp`.

**Performance note:** profiling the functions at 90% is only a necessary screening condition, not sufficient evidence of ninefold acceleration. At exactly 90%, their own acceleration must be at least 81-fold to achieve ninefold overall. The required subsequent measurements already guard feasibility; this note changes no judged numerical result.
