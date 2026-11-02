# Stage 10: readings for the next freeze

*Revision 2026-11-02 22:37 UTC (17:37 EST), before the next track version's freeze.* Ruled for in `audit/decisions.md` ("the thesis bundle isn't refrozen", 2026-11-02 09:41 UTC (04:41 EST), and "thesis round 2 not refrozen", 18:23 UTC (13:23 EST)). Drafted from GPT's review of the fixes (`audit/reviews/2026-11-02-gpt-thesis-fixes.md`), then reviewed by GPT and a fresh Opus (`audit/reviews/2026-11-02-{gpt,claude}-thesis-round2.md`). This text goes beneath stage 10 in `audit/criteria.md` as one dated revision, committed alone as `criteria: stage 10` before the refreeze.
- No frozen line is edited, and none of these loosens a threshold.
- Track `thesis-a476a910d501` keeps its own rules, and its evidence is neither pooled nor carried over.
- Each rule is judged only on evidence produced after it.

## Positions

1. **The entry reference.** P_j,e is leg j's reference opening price, before execution costs.
   - The quantity is q_j = w_j N / P_j,e.
   - R_gross uses reference prices and excludes funding, fees and execution costs.
   - Adverse fills determine only net PnL and fees.
2. **Funding.** A leg pays hour h's funding if it was held immediately before h. A leg entering at h pays none of h's funding, and a leg exiting at h pays all of it.
   - Hour h's funding uses h's opening reference when present.
   - Otherwise, for a core market, it uses the latest earlier bar's close if that close is available and not null, else that bar's open.
   - A builder market uses its latest earlier sealed reference, on the same rule.
   - An hour's reference that is not yet available is not yet missing. It is established missing only at h plus the market's lag: δ for a core market, the 5-minute seal for a builder market.
3. **Reconciliation.** Hour h reconciles once both of these hold:
   - every leg entered or due to enter by h, and not yet closed, has passed h plus its lag;
   - each entered leg has its funding row for h.

   Further rules:
   - Hours reconcile in order, and reconciliation stops at the first hour that fails.
   - Paper equity at a reconciled hour is measured after that hour's funding, exits and entries, marked at the latest price at or before h.
   - E_r is the equity of the latest reconciled hour, or the initial equity if no hour has reconciled. Inside an hour's lag, a thesis therefore sizes from the hour before it, whether or not h's funding row has already been returned.
   - A funding row that never arrives stops reconciliation at the hour before it for the rest of the track version. Every later thesis then sizes from that hour's equity, which the report shows.
4. **The data's cutoff.** A registration reads prices and funding as of a cutoff C, the time that read starts, before t_r.
   - An hour whose lag passes after C counts as not yet reached, even though the commit comes later.
   - Sizing as of t_r means sizing on what was available by C. The gap from C to t_r is the time the inputs took to read.
   - The thesis records C, E_r, the reconciled hour and the reservations already open, so its N can be checked from the record. Replays use the recorded sizes and never recompute them.
5. **A reservation's release.** An exit is effective at the first hourly boundary at or after its actionable time. From then on, a leg not yet entered is suppressed and can never enter.
   - A reservation is released once every leg is suppressed or confirmed closed at an available closing reference.
   - A closed leg counts from its reference's availability. A suppressed leg counts from the boundary, since it needs no price.
   - Missing funding does not keep a closed position's reservation.
6. **A core open's availability.** For the thesis track's position management only, a core candle's opening reference is available from H + δ, independently of its close, which is null until H + 1 h + δ.
   - A read as of a cutoff C gives the opens with H + δ ≤ C and the closes with H + 1 h + δ ≤ C. This holds whenever the track first received the candle and whatever the cache holds.
   - This rule is about time given the venue's candles. It does not make a candle exist: the venue has no candle for an hour until that market's first trade in it. A read at C before that trade sees no reference for H. A later read as of the same C shows H's open, which is why sizing is checked from the record (rule 4), not from a replay.
   - A builder market's reference depends on receipt, through its seal.
   - This is a convention of the thesis track, chosen prospectively. Stage 0's whole-bar convention is unchanged.
7. **Simultaneous exits.** Exits actionable at the same instant are labelled invalidation, then discretionary, then horizon. Only the recorded reason depends on this: no time, price, return or score reads it.
8. **Equity at or below zero.** If E_r ≤ 0, the thesis has size zero. Its hypothetical notional is N = 0.01 × the initial equity / L, so its outcome, a return per N, is defined like any other size-zero thesis's.

## Arithmetic, eligibility and records

9. **Exactness.** Every recorded number is the decimal its record states, a float's shortest form, or an exact rational's text.
   - The following are exact rational arithmetic over those numbers, with no tolerance, so every boundary is the frozen one:
     - sizing, fills and the cost cell;
     - invalidation;
     - the sign of R_net and of a base-rate window;
     - admission under the cap.
   - N, size, b, E_r and the open reservations are recorded as exact rationals' text, of whatever length. Rounding b could refuse a thesis that exactly fits the cap.
   - Between implementations, C10.3's 1e-9 dollars and C10.4's comparison of finite scores (its revision of 2026-10-20, |a − b| ≤ 1e-12 · max(1, |a|, |b|)) are unchanged.
   - SCORING.md states the same.
10. **Eligibility at the commit.** "Listed and not delisted at t_r" means listed by a read of the venue made under the commit's lock, with t_r taken as that read returns.
    - The thesis records the read's result and its start and end times.
    - A delisting after the venue answered that read and before t_r can't be seen. That window is at most the read's duration.
    - A request's form is checked before the venue is read. A builder dex that the venue doesn't list lists none of its markets.
    - The 90 completed daily bars still come from the session's snapshot.
11. **A benchmark's p.** p is the p_ref computed in the commit from the registered N at t_r. If that base rate is unavailable, the market is skipped and logged.
12. **Data the venue omitted.** Any row missing from a market's cached hourly bars, daily bars or funding is retried every hour, with no age limit. This includes rows before the first cached one.
    - A result computed while a row is missing treats it as missing. An outcome stays unresolved until the row arrives. A base rate computed at t_r omits a window that was incomplete at t_r.
13. **Resolution records.** A record's `at` is when it was written, and its `cutoff` is when its data were read.
    - A status needs no market data. It is written at T + 90 min when no record exists, and a score can follow it.
    - A failed managed replay leaves the outcome scored and names the failure.

## Judging

- **C10.3.** Its fixtures are judged again on a run after this revision, since the position code moved from floats to exact arithmetic.
- **C10.4.** It is judged again, on a run after this revision, with GPT's scorer and its independent positions updated by GPT from this text and SCORING.md, not by the builder.
  - The run covers every boundary case C10.4 lists, R_net exactly 0 included. No case is avoided.
  - Raw disagreement with GPT's previous files is reported apart from agreement under this revision.
