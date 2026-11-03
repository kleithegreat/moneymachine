<!-- Claude (claude-opus-5-5), fresh read-only session on the personal account, reviewing the kernel fork decision without the advisor's view; finished 2026-11-03 23:55 UTC (18:55 EST). Static reading of 406eb54. -->
# Claude review

Read-only review as of 2026-11-03 23:48 UTC (18:48 EST). I changed nothing. For each defect I asked one question: can it push a null campaign's chance of promoting above the bound the gate guarantees? Whether a defect "changes returns" is the wrong test.

## (1) Can each defect raise null promotions under N1–N3?

**The exact limited-liability argument, which both consultations and `gate/NULLS.md` get wrong.** The bet is capped at λ_t ≤ 0.5/B, with B = 1 (`gate/gate.py:149`). Promotion needs a positive total return (`gate.py:252`), and a bankruptcy step returns −1 (`kernel/mm/src/sim.rs:357-363,380-384`). So every promoted path is a path that never went bankrupt.

Now build the betting wealth V from the *untruncated* returns r′, stopped at the first bankruptcy τ:
- If positions are predictable, the gross P&L q·o·ε has mean zero (`NULLS.md:21-33`), and costs and liquidations only subtract. So V is a supermartingale.
- V stays nonnegative while 1 + λr′ ≥ 0, which means r′ ≥ −2. In words: the shortfall the venue absorbs is no larger than the equity at the start of that step.
- Optional stopping then gives P(promote) ≤ α·(1 + E[K_{τ−1}·(λ_τ|r′_τ| − 1)⁺]).

So limited liability only breaks the guarantee when one 4-hour step loses **more than twice** its starting equity. With the gross budget held at 2:
- A long can lose at most 100% of its notional.
- A short needs ε ≈ 0.5 plus a wick about 9.6 standard deviations out (`markets.py:184,195`), which has a probability around 1e-21.

So with a correct kernel the guarantee is effectively exact in N1–N3. `NULLS.md`'s rule, "claimed only for evaluations that never go bankrupt", is both unnecessary and wrong. It is unnecessary because the derivation above covers bankrupt paths. It is wrong because returns conditioned on survival can have a positive mean, as GPT noted.

| Defect | Kind | Can it push P(promote) above α under N1–N3? |
|---|---|---|
| Gate 1: closing costs missing from the mechanism check | selection | **No.** Holm is valid for any family chosen on search data, so this moves the rate only *within* α. |
| Gate 2: undefined conditions dropped from the 10–90% denominator | selection | **No**, for the same reason. |
| Gate 3: kernel identity not checked at establishment | classification | Not a promotion channel. It can wrongly mark a campaign established and so change the series verdict. Fixed by `956066c`, but **that commit is not in the deployed `29a25cb`**. |
| Gate 4: `INSERT OR REPLACE` gets past the append-only triggers | integrity | **No** with the kernel's own writers, none of which issue replacement SQL. |
| Kernel 1: delisting lookahead | lookahead | **Cannot occur.** Coins that aren't delisted get the fixed interval (w_start, end) (`market.rs:420-421`), and every null coin is written as not delisted (`markets.py:236`). On real data it is fatal, since no bound survives acausal positions. |
| Kernel 2: a pending close reopens the position after liquidation | causal | **Yes, but narrowly.** Maintenance liquidation leaves equity below notional/20 (`sim.rs:343-344`). The reopened position is then about 20× leverage, so a ≥10% move against it breaks the 2× condition. The trigger needs a liquidation, which at 2× gross is essentially unreachable in N2. |
| Kernel 3: positions held because their weight is undefined take no gross budget | causal | **Yes. It is the only realistic route.** Gross can reach about 2 × 12 coins (`sim.rs:433-461`), and at 10× an 8–20% move against the book breaks the 2× condition. A rolling z-score of funding goes undefined coin by coin, because real funding sits at its floor for long stretches. It also creates the liquidations that kernel 2 needs. |
| Kernel 4: orders sized from pre-fill equity | causal | **No.** The sizing error is the size of the costs, because a synthetic bar opens at the previous close. |
| Kernel 5: reporting revives an account already bankrupt | reporting | **No.** The returns are all zero, so p = 1, and a total of 0 fails the "> 0" rule. |
| Kernel 6: boundary fill missing from the holdout trace | reporting | **No.** The judged returns include the cost. |

Where GPT is wrong:
- It says kernel 2's reopened position "can subsequently profit" and kernel 3 makes "large positive excursions more attainable". Neither is a channel: Ville's bound does not depend on variance.
- The 04:20 entry says the advisor's first reading ("a filter before the holdout can't raise false discoveries") was wrong. That reading is correct with one change: the filter can't raise false discoveries *above α*.
- Neither consultation noticed that the Lean law L1 *assumes* `m₁.intervals = m₂.intervals` (`reference/lean/Ref/Laws.lean:27`). The delisting lookahead sits outside that proved statement. This is the weak-law failure paper §6 warns about: L1 is a narrower claim than theorem 1.

## (2) Recommendation: run v3 on the frozen kernel, under an exact qualification rather than a widened one, and fix the spec once

1. **Before 2026-11-07 04:00 UTC (2026-11-06 23:00 EST)**, roll `agent-series` to an image containing `956066c`.
2. Replace v3's qualification with the derivation above: the lookahead can't occur, the selection defects stay within α, and execution matters only through a step losing more than 2× its equity, which kernel 3 (and after it kernel 2) can reach. Bankruptcies are already reported, and every agent null record so far lists none.
3. Revise `NULLS.md`'s bankruptcy paragraph with a dated correction, checked independently by GPT, because it states a false-discovery argument.
4. Fix all nine defects **in the spec**, not in a fork on `main`:
   - `reference/SEMANTICS.md` currently specifies them (§7, steps 4, 7 and 9).
   - The Lean reference agrees with `mm`.
   - Stage 7's frozen B2 port follows those same definitions.
   - L1 gets a dated revision so that the listing intervals are part of the history.

   Stage 7's port and the Lean engine then implement the corrected spec. A Rust fork on `main` would be a third implementation of the same fix.
5. The Lean stage's criteria should rerun stage 2's complete-null cells on the corrected engine, including strategies whose weights go undefined. That is where null calibration of corrected execution belongs, not in ten expensive agent campaigns.

**What this costs:**
- **Evidence:** v3 speaks for the legacy execution, as every pilot result does (`CLAUDE.md`, Tech).
- **Identity:** none.
- **Time:** none.

**What a fork costs, by my estimate:**
- A spec change, Lean re-proofs, the Rust fix, tests from another model, a fresh hunt, a refreeze and a redeploy: 1–3 weeks.
- GPT's nearly exhausted budget (decision of 03:02).
- A new C7.4 baseline for stage 7.
- Single-kernel continuity for the pilot.
- It delays stage 7's merge, which waits on stage 4's swarm smoke test (`audit/criteria.md:976-977`).

Waiting for Lean is circular, as GPT says.

## (3) Before any real campaign, and effect on recorded results

**Must be fixed before any real campaign:** all nine, plus deploying the identity check. The order of urgency:
1. Kernel 1 (acausal, and reachable: FTM is marked delisted in the real venue rules).
2. Kernels 3 and 2. Real 4-hour moves on alts make losses beyond 2× equity reachable under hidden leverage.
3. The rest.

Under the roadmap the next real campaign is stage 8, after the Lean stage. **If anything earlier would open a real holdout, it waits.**

**Recorded results:**
- **No judgment changes.**
  - Stage 3 had zero finalists.
  - C3.2 and C4.5 v1/v2 had no candidates and no bankruptcies.
  - C2.4's 0 of 300 stands as a statement about this kernel.
  - The thesis track uses `thesis/positions.py` and a pinned binary (`thesis/runner.py:347`), so it is untouched.
- **Two meanings need recording:**
  - Stage 6's non-interference claim is L1 as stated, which is narrower than §6's theorem 1.
  - Stage 3's real search returns include the acausal 8-hour exclusion before FTM's last trade.

## (4) What would change my mind

- **Toward a fork before v3:** synthetic search evidence (no holdout involved) that agents' strategies reach a held gross above about 4, or have bankruptcy steps with a shortfall above one equity. The checks are stage 2's N3-G400 bankruptcy and v1/v2's ledgers. Also: a real campaign scheduled before the Lean engine.
- **Toward waiting:** a credible Lean date before stage 7's merge, with the ordering revised.
- **Against my derivation:** finding a promotion path that the "> 0 total return" rule doesn't exclude after a bankruptcy, or a predictable-position argument that fails for liquidation timing.
