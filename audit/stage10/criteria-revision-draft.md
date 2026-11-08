# Draft dated revision, stage 10 timing and readiness, 2026-11-08

**DRAFT FOR REVIEW, NOT ADOPTED CRITERIA.** It does not amend `audit/criteria.md`, freeze anything, authorize deployment or rejudge the running version. A reviewed dated revision must be committed there before a new freeze, with a new forward window settled separately. Versions and evidence are never pooled. The schedule was decided on 2026-11-08 18:04 UTC (13:04 EST) (`audit/decisions.md`). Every UTC time below is paired with Eastern (EST = UTC-5).

The derivations are in `docs/whitepaper.tex`, appendix T3 (`app:thesis-policy`). This file states what the revision says; the paper says why.

## The revision states

1. **The schedule.** Information cutoff D + 00:05 UTC (19:05 EST the day before). Acquisition starts at the cutoff. The completion deadline and the earliest session start are D + 05:00 UTC (00:00 EST). It is a choice from the recorded 2026-10-28 inventory, not a bound: 217 packed minutes with a terminal request for every listing, plus four mark windows (01:00 through 04:00 UTC (20:00 through 23:00 EST)) of 7 minutes, complete by 04:10 UTC (23:10 EST), leaving 50 minutes for extra attempts, ten-dex discovery and the unmeasured interior hourly holes and midnight resolution reads (T3). A larger inventory, holes, retries or outages may cause a miss, which is reported and never relaxed.
2. **Misses.** A late or missing attested snapshot makes main and no-reading missed for the date, with that reason. There is no late snapshot and no other date's snapshot; recovery uses only the attested bytes, and changed or lost bytes fail closed. Each date's `taken`, `acquired` and request count go in the C10.6 report, so the miss distribution is measured; changing the start after seeing it is a new identity. The tolerated misses restate C10.5 (T3): at most 28 - 20/r main sessions, r the mean accepted theses per on-time main session. The window holds exactly four Mondays and C10.5 needs four executed benchmark batches, so the revision must say whether a Monday batch recorded as five skips for want of a snapshot counts as executed.
3. **Acquisition is independent of the sessions and of model readiness.** It has its own loop. Sessions may wait for the model and the sandbox canary until the UTC date ends, and are then disclosed as missed. A crash consumes the started session; SIGTERM leaves unfinished work to the next start without backdating it.
4. **Readiness.** History the venue was never asked for, or more than one page (500 hours) before the registration, makes a market unavailable for that session (the human's decision). The hours since the last fill are fetched by the registration's own read and are not unavailability. An unavailable market raises the failed-read disclosure and commits nothing; the benchmark retries within its day or records the missed-batch skip. Eligibility is unchanged.
5. **The benchmark** reads that Monday's attested snapshot, kept to the daily bars known at Monday 00:00 UTC (Sunday 19:00 EST), so it takes no second snapshot. Its registration time follows the acquisition. A Monday with no attested snapshot by 05:00 UTC (00:00 EST) records each market as skipped, "no attested snapshot".
6. **The listing read time** is recorded in the snapshot (`listed_at`). After a restart acquisition may begin hours after the cutoff, and a market delisted meanwhile is dropped from a snapshot labelled 00:05; registration re-reads the listing at commit.
7. **What it changes.** `markets` shows the last 1h close as of 00:05 UTC (19:05 EST); main's entry is near 06:00 UTC (01:00 EST), against about 01:00 UTC (20:00 EST) in the 00:10 design, and HIP-3 equity perps are then in US cash hours. Daily bars and base-rate anchors are unchanged; the snapshot age at start is 4 h 55 min on time and strictly under 23 h 55 min. The one-hour, 100-turn, two-registration limits, the conditional ablations and the no-reading arm are unchanged. It is a new identity and window, never a pass of the 00:10 rule.

## Not cleared by this revision

The recorded inventory has ten dexes, above the five that the initial mark wave holds; shared-IP coordination with the recorder and unbounded foreground service remain blockers (`PROGRESS.md`).

## Review and evidence required before adoption

- Fresh independent review of the changed information timing, readiness and schedule; no protected observations used to choose them.
- The synthetic tests in `thesis/tests/test_refreeze_round5.py` and `test_snapshot_schedule.py`: schedule, deadline, restart, SIGKILL, request weight and rounding.
- A new manifest and forward-window decision, and prospective evidence only.
