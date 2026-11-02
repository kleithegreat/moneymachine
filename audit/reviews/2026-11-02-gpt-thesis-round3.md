**Fix check:** B1–B5 and R1, R6, R7 are fixed for their reported counterexamples. R2’s tail reuse is implemented, but introduces this blocker.

## Blocking finding: a newly completed daily candle disappears from the next snapshot

**Where:** `thesis/market.py:143–150`; eligibility exclusion at `thesis/runner.py:115–117`.

**Trigger:** the Monday benchmark reads daily candles at midnight, then the main session reads them at 00:10, within the one-hour repair interval.

At midnight, the just-ended daily candle is retained in `pending` because its availability delay has not expired. At 00:10:

1. Line 143 finds that candle in `pending` and skips fetching.
2. Lines 149–150 delete it because it is now final.
3. Nothing adds its final version to the disk cache.

The snapshot consequently omits a completed day. A market whose 90th daily candle just completed remains wrongly excluded as having only 89 days; the saved session snapshot preserves that exclusion.

**Reproduced:** identical venue data returned **89** completed days at midnight, **89** from the warm cache at 00:10, and **90** from a cold cache at 00:10. No corrupted files or API failure was involved. The existing 90 market, recorder and ops tests pass but miss this transition.

**BLOCKED — R2’s daily-candle finalization regression makes session eligibility wrong.**
