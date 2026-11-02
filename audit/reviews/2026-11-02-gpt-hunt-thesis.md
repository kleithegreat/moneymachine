# Findings, ranked by consequence

Static review only: no data sought or accessed, no files changed. These are demonstrated code paths—not claims that the running system has encountered them.

**Frozen identity:** every code fix below changes files covered by the thesis manifest (`thesis/harness.py:26–44`), requiring a new thesis version and fresh forward window. None requires changing stage 3’s `harness_hash` or the kernel of judged runs.

## 1. Missing funding is treated as zero when sizing subsequent theses

**Path:** `thesis/positions.py:122–131,193–201`; `thesis/registry.py:138–141`.

When an open position lacks an hourly funding row, replay flags its managed return as incomplete but simply skips the cash payment. `admit()` nevertheless uses that cash/equity to fix the next thesis’s notional and admission permanently.

**Concrete state:** an existing long owes $10 at a funding hour absent from `data["funding"]`. Replay overstates equity by $10. A subsequent registration with `L = 0.1` receives a notional $1 too large. Near the reservation cap, this can fund a thesis that should have size zero.

This contradicts “missing, never assumed zero” and sizing from reconciled equity (`audit/criteria.md:757–766`).

- **Outcome changed:** wrong immutable sizes and admissions; wrong paper returns; potentially different cost cells and forecast outcomes.
- **Likelihood:** conditional on a funding-data gap during registration. Plausible over a long-running track; no occurrence established.

## 2. Core-market invalidation can inspect the next open instead of the invalidating close

**Path:** `thesis/positions.py:32–40,170–180`.

Invalidation calls `mark()` at the close’s availability time. With consecutive historical bars present, `mark()` selects the bar opening at that boundary and returns its **open**, not the preceding bar’s close.

**Concrete input:** a long enters at 100, with `L = 0.05`. Its first held bar closes at 94; the next bar opens at 100. The required close-based invalidation triggers, scheduling exit at the following hourly open. The implementation instead sees 100 and does not trigger. A later fall can therefore produce a materially different exit and loss.

The governing rule explicitly uses the bar’s close (`audit/criteria.md:759`).

- **Outcome changed:** wrong management decisions, returns, equity and later admissions/sizes. As-registered Brier outcomes are not directly changed by this exit.
- **Likelihood:** requires a core-market close/open difference crossing the invalidation threshold. Small candle discontinuities suffice; equality of adjacent close/open is not guaranteed.

## 3. Crash recovery silently abandons remaining sessions—and entirely missed dates

**Path:** `thesis/runner.py:121–138,166–187,263–276`; `thesis/report.py:80–81`.

A main session is marked started before execution. After a process crash, `schedule()` sees that start and never calls `day()` again. There is no recovery path to run or explicitly miss its remaining ablations and no-reading session.

**Concrete state:** main starts, accepts a thesis, then the pod dies before its ablation. On restart that date is permanently skipped. The ablation and no-reading session receive neither starts nor missed records. An unended main session also disappears from the report’s session list, which reads only `session_end`.

Separately, if the runner is down for a whole UTC date, scheduling examines only the current date; the absent date is never disclosed as missed.

- **Outcome changed:** lost ablation pairs, unaccounted no-reading sessions and incomplete session reporting; C10.5/C10.6 evidence can fail.
- **Likelihood:** any abrupt interruption during a daily sequence, or an outage spanning a date. The documented graceful SIGTERM path mitigates deliberate stops, not node failure or SIGKILL.

## 4. One completed benchmark market permanently suppresses the rest of its batch

**Path:** `thesis/runner.py:195–215,237–239,267–271,279–285`.

`benchmarked()` considers a Monday complete after **any** registration or skip.

**Concrete state:** BTC registers successfully, then ETH’s funding request raises after its retries. The scheduling loop logs the exception. Every subsequent scheduling pass sees BTC’s registration and skips the entire Monday, so ETH and the remaining three markets are never registered or given skip reasons.

This also happens after a restart between benchmark markets.

- **Outcome changed:** incomplete benchmark evidence and potentially failure of the required four executed, fully enumerated batches (`audit/criteria.md:875`).
- **Likelihood:** requires interruption or an exhausted API retry after the first recorded market. Plausible across four multi-request batches.

## 5. Missing-data statuses are deliberately scheduled after their deadline

**Path:** `thesis/runner.py:234–235,254,279–283`.

A missing-data status is written only when `now >= T + 2 hours`. The resolution loop waits five minutes **after each completed step**, with no deadline alignment.

**Concrete timing:** resolution runs at `T + 1h59m` and finds the outcome unresolved. It records nothing. The next run is at least `T + 2h04m`, when it finally records missing data—already outside C10.5’s two-hour deadline (`audit/criteria.md:876`).

- **Outcome changed:** stage-exit failure despite otherwise correct missing-data handling.
- **Likelihood:** effectively certain for a thesis still unresolved at the deadline, unless loop timing happens to land exactly on it.

## 6. A temporary historical omission becomes a permanent cache hole

**Path:** `thesis/market.py:85–97,128–134`; `thesis/positions.py:70–72`.

Cache updates start strictly after the last cached timestamp and accept only newer rows. They never revisit holes below that timestamp.

**Concrete state:** funding hours H and 3H are cached, but 2H was temporarily absent from the API response. The venue subsequently supplies 2H. Every future fetch starts after 3H, so 2H is never acquired. Any outcome requiring it remains unresolved indefinitely, although the data has become available.

The same append-only extension logic applies to candle gaps.

- **Outcome changed:** permanently missing scores and base-rate windows; failure to score within two hours of data availability; potentially insufficient resolved theses for exit.
- **Likelihood:** conditional on a temporarily omitted row followed by a newer row. Ordinary request failures alone do not trigger it.

## 7. A partially entered spread cannot close its already-open leg

**Path:** `thesis/positions.py:132–158,173`.

Exit processing skips a position until **all** legs have entered. Invalidation has the same restriction.

**Concrete state:** a spread registers at 00:30 with horizon 96H. X enters at 1H, but Y has no opening reference until 100H. X cannot take its horizon exit at 96H because the spread’s aggregate `entry` remains `None`. Y enters at 100H; exit processing can close the legs only from 101H. If Y never returns, X remains open indefinitely.

- **Outcome changed:** wrong managed exposure, funding, equity and reservation duration, affecting subsequent registrations. The as-registered outcome correctly remains unresolved when entry reaches the horizon.
- **Likelihood:** low: requires a spread and a prolonged asymmetric reference gap, such as a builder-market interruption or delisting.

## 8. Registration eligibility uses old session listings, not listings at registration

**Path:** `thesis/runner.py:96–109,115–119`; `thesis/daemon.py:72–74`; `thesis/registry.py:89–93,130–131`.

Registration refreshes market inputs, but passes the pre-session snapshot’s listings into validation.

**Concrete state:** X is listed when the snapshot is taken, then delisted before the agent registers it. Cached/history API inputs remain readable. Validation sees the old `False` delisting flag and accepts X, contrary to eligibility **at `t_r`** (`audit/criteria.md:749–751`).

- **Outcome changed:** an ineligible accepted thesis enters scoring and possibly reserves capital.
- **Likelihood:** low: requires delisting between snapshot and registration, but the snapshot can precede registration by substantial preparation and session time.

## Areas without an additional serious finding

I did not establish another serious defect in retrieval response logging/destination validation, conditional-ablation source separation, or the standalone Brier/base-rate/clustering formulas. I also found no code-defensible serious sandbox escape. These are static-review conclusions, not runtime isolation or availability tests.
