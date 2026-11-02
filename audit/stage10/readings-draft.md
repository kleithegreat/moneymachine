# Draft: dated readings for stage 10's next freeze

**A draft, under review, not a criterion.** Ruled for in `audit/decisions.md`, 2026-11-02 ("the thesis bundle isn't refrozen"), from GPT's review (`audit/reviews/2026-11-02-gpt-thesis-fixes.md`). Once GPT and a fresh Opus have reviewed the round, the text goes beneath stage 10's positions in `audit/criteria.md` as dated revisions, committed alone as `criteria: stage 10`, before the refreeze. No frozen line is edited and none of these loosens a threshold. Track `thesis-a476a910d501` keeps its own rules, and its evidence is neither pooled nor carried over.

Each reading is written as the revision would read, then says what it settles.

## The four readings

### 1. P_e is the reference open

> P_j,e denotes leg j's reference opening price, before execution costs. The quantity is q_j = w_j N / P_j,e. R_gross uses reference prices and excludes funding, fees and execution costs. Adverse fills determine only net PnL and fees.

**Settles:** "at price P_j,e" could be read as the fill. SCORING.md already says `q = w · N / open(e)`, and C10.4 was judged on it. GPT's independent file took the fill.

### 2. Funding's reference, and when an hour reconciles

> Funding at hour h uses h's opening reference when present. Otherwise, for a core market, it uses the latest earlier bar's close if that close is available and non-null, else that bar's open. For a builder market, it uses the latest earlier sealed reference, on the same rule. An hour's reference not yet available is not yet missing: it is established missing only at h + the market's lag (δ for a core market, the 5-minute seal for a builder market).
>
> Hour h reconciles once two things hold. Every leg entered or due to enter by h, and not yet closed, has passed h + its lag, and each entered leg has its funding row for h. Reconciliation is in hour order and stops at the first hour that fails. Paper equity at a reconciled hour is measured after that hour's funding, exits and entries, marked at the latest price at or before h. E_r is the equity of the latest reconciled hour, or the initial equity if none has reconciled. Inside an hour's lag, a thesis therefore sizes from the hour before it, whether or not h's funding row has already been returned.
>
> A read of prices and funding has a cutoff, the time it was made. An hour whose lag passes after that cutoff is treated as not yet reached, even if the commit comes later.

**Settles:** the conflict between SCORING.md's `mark` and the 2026-10-23 revision's "latest earlier reference" for core candles (kept as SCORING.md has it, on which C10.4 was judged), and F3's window, which the last bundle excluded from the differential. GPT's position (no reconciliation before the reference) is adopted. The cutoff sentence prevents a slow read across an hour boundary from passing a reference off as missing.

### 3. A reservation's release

> Once an exit is effective, at the first hourly boundary at or after its actionable time, a leg not yet entered is suppressed and can never enter. A reservation is released when every leg is suppressed or confirmed closed at an available closing reference: a closed leg counts from its reference's availability, and a suppressed leg counts from the boundary, since it needs no price. Missing funding does not retain a closed position's reservation.

**Settles:** the release of a spread with a leg that can no longer enter. GPT's file released it only when that leg's next bar appeared.

### 4. A core open's availability

> A core candle's opening reference is available from H + δ, on its own, independently of its close. Until H + 1 h + δ its close is null. A read as of a cutoff C gives the opening references with H + δ ≤ C and the closes with H + 1 h + δ ≤ C, whether the candle was first received before or after C and whatever the cache holds, so a completed and an in-progress candle give the same reference as of the same cutoff. Availability is this rule of time, never the time the track first received the candle (a builder market's reference alone depends on receipt, through its seal). This is for the thesis track's position management only: stage 0's whole-bar convention is unchanged.

**Settles:** the bundle's "from δ, once seen", which the frozen text does not give; "once seen" is dropped, because a retrospective read would otherwise depend on the cache (F4). A horizon exit at 00:00 frees its reservation for that day's 00:10 session.

## Also for the reviewers to settle with these

The rulings need these to be stated, and the code implements them. They are not among GPT's four, so they are listed apart. Each can change a judged result only as noted.

- **Exactness.** Every number is the decimal its record states (a float's shortest form). Sizing, fills, the cost cell, invalidation, the sign of R_net and of a base-rate window, and admission are exact rational arithmetic over those, with no tolerance, so the boundaries are the frozen ones. N, size and b are recorded as exact rationals' text, because rounding b could refuse a thesis that exactly fits the cap. The 1e-9 dollars of C10.3 and the 1e-12 of C10.4 remain comparison tolerances between implementations. SCORING.md gains one line saying so.
- **Eligibility at the commit.** "Listed and not delisted at t_r" means: listed by a read of the venue made under the commit's lock, with t_r taken as that read returns. The thesis records the read's result and its start and end times. A delisting after the venue answered that read and before t_r can't be seen, and that window is the read's duration at most. The 90 completed daily bars still come from the session's snapshot.
- **A benchmark's p.** p is the p_ref computed in the commit from the registered N at t_r. If that base rate is unavailable, the market is skipped and logged.
- **Resolution records.** `at` is when a record was written and `cutoff` the data's. A status needs no market data and is written at T + 90 min when no record exists; a score can follow. A failed managed replay leaves the outcome scored and names the failure.
- **A required gap.** A hole between cached rows, or before the first hourly or funding row, is retried hourly with no age limit. The first daily row isn't retried, because that would cost a request per listed market per snapshot: a day before a market's first row can't resolve or size anything, and a base-rate window on it is omitted, as the base rate already says. If the reviewers want it retried, the cost is about 33 minutes of each snapshot at the adapter's budget.
- **Silent and not exercised.** N at E_r ≤ 0: the code keeps a hypothetical N from the initial equity, GPT's file uses 0. Only the cost tier of a size-zero thesis in a bankrupt account depends on it.

## What a refreeze then needs

Under `audit/decisions.md`: GPT and a fresh Opus on this round; these revisions committed alone; a fork of the manifest, with the previous identity kept; C10.5 restarted on a new forward window. C10.3's fixtures and C10.4's differential are judged again on a run after the revision, since the scoring path changed from floats to exact arithmetic. C10.4's independent scorer (`gpt_scoring.py`) still uses floats and the old `<=` on rounded notionals, so a C10.4 run must either stay off those boundaries or have GPT update it from the revised SCORING.md, as on 2026-10-25.
