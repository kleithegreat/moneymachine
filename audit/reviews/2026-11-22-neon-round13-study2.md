# Neon on round 13's study 2 half (D270 to D284)

Model Gemini 4 Neon through the Gemini web UI (the human pasted `neon-r13-study2-bundle.md`, 341 KB, whole, and its prompt; reply saved as a PDF, 2026-11-22 08:13 UTC (03:13 EST)). Extracted by `pdftotext -layout`:

```text
11/22/26, 3:13 AM                                    Round 13 Specification Defect Analysis



    Round 13 Specification Defect Analysis
    https://gemini.google.com/app/ca0bce4145462406

    User prompt: See attached instructions
    Response: Round 13 closes most of round 12's core defects at their cause—specifically the
    cash-reserve rule (D278), socket-order pairing at routing (D273), the on-time book witness
    (D271), separating missing settlements from rejections (D272), packing off the capture path
    (D274), and verdict-only transitions on unchanged/diverged prefixes (D275). Three defects
    remain: two in the design that can withhold CS2.3 or end the study early, and one internal
    contradiction in VAULT.md's test spec.

    Finding 1: Any positive CronJob jitter or hourly retry permanently withholds
    CS2.3 (D277, VAULT.md)
            What it breaks: The interaction between D277's coverage rule (endTime >= instant +
            31 d) and VAULT.md's 32-day daily re-read ([watermark - 32 d, watermark]).

            Construction: On day D − 1, mmvault runs at 00:07:00 UTC. Its hourly pull sets
            watermark = (D-1) 00:07:00, and its daily re-read queries [(D-33) 00:07:00,
            (D-1) 00:07:00]. The latest instant t satisfying endTime - t >= 31 d is (D-32)
            00:07:00. On day D , the CronJob starts 10 seconds later—or fails with HTTP 500 at
            00:07 and succeeds at 01:07:00—setting watermark = D 00:07:10 (or D
            01:07:00). Its 32-day re-read queries [(D-32) 00:07:10, D 00:07:10] (or from (D-
            32) 01:07:00). The interval ((D-32) 00:07:00, (D-32) 00:07:10) (or the full
            hour) was not covered by day D − 1 (only 30d 23h 59m 50s old at endTime) and is
            excluded from day D's startTime. Because watermark is monotone, no subsequent
            daily re-read ever queries that interval.
            Outcome changed: CS2.3 is permanently withheld ("not judged" at the last firing) by a
            single millisecond of positive scheduling jitter or a single failed midnight run anywhere in
            the 62-day window.
            Defect type: Design. The 32-day re-read window has zero slack against a 31-day
            coverage threshold on a 24-hour cadence. Fix at the cause by widening the daily re-read
            (e.g., 35 days, or starting at min(watermark - 32 d, last_daily_re_read_end -
            31 d) so outages and jitter never leave an uncovered seam).

    Finding 2: D270's let-go rule counts raw queries rather than days, letting a
    delisted coin go in 30 hours
            What it breaks: D270's let-go condition in 4-study-2.md (Step 7, wall 3): "Capture_k
            holds 30 completed funding queries of it that start at its reach and were answered with
            nothing."

https://gemini.google.com/app/ca0bce4145462406                                                             1/3
11/22/26, 3:13 AM                                  Round 13 Specification Defect Analysis


            Construction: A coin is delisted on day 45 and its final settlement is delayed by 48 hours.
            On the 1st of the month, Step 1's hourly timer runs mmvault funding and then fails to
            commit Capture_k (e.g., transient IO or permission error on the capture volume) for 30
            consecutive hours. Each hourly retry runs mmvault funding, queries the delisted coin's
            reach, receives [], and atomically commits a completed funding file. When Capture_k
            succeeds on hour 30, it holds 30 completed empty queries starting at the coin's reach, so
            the coin is let go after 30 hours instead of 30 days. When the delayed settlement arrives at
            hour 48, it lands behind T_prev, fails prefix reproduction on the next replay, and ends the
            study at T*.
            Outcome changed: Premature end_study at T*, withholding CS2.1 ("Outgrew"), CS2.2,
            or CS2.3.
            Defect type: Design. Require 30 completed empty queries across 30 distinct UTC days
            (or spanning at least 30 days by their pull timestamps), not 30 raw queries.

    Finding 3: VAULT.md funding Test 1 contradicts whole-hour pagination
    (D280)
            What it breaks: VAULT.md, "Settled funding (mmvault funding)", Test 1.
            Construction: The spec requires that after a 500-row page ending at last_time, the
            next page starts at the next whole hour (last_time - (last_time mod 3_600_000)
            + 3_600_000). Test 1's first sentence still carries round 12's rule ("starting at floor_ms
            and then 1 ms after each page's last time"), while its second sentence specifies round 13's
            rule ("the next page starting at H + 1 h"). Because tests are written by an independent
            session from the spec alone, the test suite will assert last_time + 1 on the 1,200-row
            test and fail the compliant builder—or push the builder back to last_time + 1, re-
            exposing A18 to same-hour restamps.
            Outcome changed: Build/test deadlock, or regression to same-hour restamp conflicts
            that end the study under A18.
            Defect type: Text (fix Test 1's first sentence in VAULT.md).

    What I accept
            D278 (Cash reserve): Cutting each buy so cash after it is at least 1/24 of units-at-cost
            closes Neon's simultaneous-dip exhaustion at its cause. Because the cut depends only on
            pre-buy cash, pre-buy cost, and the fill's own terms, it is a valid non-negative scale under
            K1 and preserves the 5% bound.
            D273 (Pairing at routing): Routing l2Book-fast vs. l2Book-fast-unpaired from the
            single socket's frame order removes all cross-file clock, flush-order, and reconnect-skew
            bugs without adding reader complexity.


https://gemini.google.com/app/ca0bce4145462406                                                             2/3
11/22/26, 3:13 AM                                  Round 13 Specification Defect Analysis


            D271 (On-time book witness): Requiring |recv - time| <= 1 h closes the wild-
            stamp horizon leap; the host clock can only withhold a witness, never fabricate one.
            D272 (Absence vs. rejection): Pausing the month on R_SETTLEMENT_MISSING and
            ending only on record rejections cleanly separates backfillable gaps from permanent
            conflicts.
            D274, D275, D276 (Capture, transitions, operator stop): Moving packing off the capture
            path, fsyncing all pinned files and directories in Step 1, unifying non-terminal runs into
            continue so newly eligible verdicts are named, and labeling operator stops with unjudged
            figures all resolve their round 12 findings.
            D279 (Registration): Printing all four identifiers (commit, registration file SHA-256,
            w_start, State_0 SHA-256) in every report makes double substitution visible against the
            remote.
            D281, D283, D284 (Urgent recorder lines, plan order, criteria drafts): Flag-only
            delisting, valid-JSON framing fixtures, moving shutdown ahead of style/subscriptions, and
            the four drafted criteria revisions are sound (once Finding 1's coverage window is fixed in
            VAULT.md).

    Ledger

                                                                                   Changes what is built or
      Status         Point
                                                                                   run?

                     D271, D272, D273, D274, D275, D276, D278, D279,
      Agreed                                                                       Yes, as specified in round 13
                     D281, D282, D283, D284
                     Finding 1: D277 / VAULT.md 32-day daily re-read               Yes. Changes mmvault's
      Disputed
                     vs. 31-day coverage (zero jitter/retry slack)                 daily re-read window
                     Finding 2: D270 let-go rule counts 30 raw queries             Yes. Changes study2
      Disputed
                     instead of 30 distinct days / 30-day span                     forward's let-go check

                     Finding 3: VAULT.md funding Test 1 stale                      Yes (tests). Text fix in
      Disputed
                     last_time + 1 wording                                         VAULT.md Test 1




https://gemini.google.com/app/ca0bce4145462406                                                                     3/3
```
