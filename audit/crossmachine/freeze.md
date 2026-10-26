# Cross-machine bit-identity test, frozen 2026-10-26 21:05 UTC (17:05 EDT), before any run on a homelab worker

Human request of 2026-10-26: before any judged use of the homelab workers, run the same campaigns here and on a
worker and compare them byte for byte; if they differ, pin the CPU feature set on every machine from the start of the
next judged run, never mid-run, and retest.

- **Code:** commit f2264a6, shipped to the worker as `git archive`. This PC's side is the stage 2 null sweep as
  recorded (`data/campaigns/null.jsonl` and `data/campaigns/null/<id>/ledger.sqlite.xz`, run 15:52–20:03 UTC from
  dbe192b's gate and kernel; f2264a6 changed only the pool size, and every task is seeded by its id).
- **Worker:** prodesk5 (192.168.8.229, i5-8500T, no AVX-512). This PC: AVX-512, numpy dispatching
  X86_V2, X86_V3, X86_V4 and AVX512_ICL. Each side's features are recorded by `ops/crossmachine.py run`.
- **Campaigns (nine, one per model and searcher, fixed now):** c24-N1-G100-0, c24-N1-G400-0, c24-N1-H400-0,
  c24-N2-G100-0, c24-N2-G400-0, c24-N2-H400-0, c24-N3-G100-0, c24-N3-G400-0, c24-N3-H400-0.
- **Comparison (`ops/crossmachine.py compare`):** per campaign, equal result rows except `seconds`, and equal ledgers
  (every table, every row in rowid order, every column except the wall-clock `created`; return blobs byte for byte).
  Identical means all nine are identical on both; anything else is a difference, reported per campaign.
