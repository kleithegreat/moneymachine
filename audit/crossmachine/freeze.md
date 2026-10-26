# Cross-machine bit-identity test, frozen 2026-10-26 21:00 UTC (17:00 EDT), before any run on a homelab worker

Human request of 2026-10-26: before any judged use of the homelab workers, run the same campaigns here and on a
worker and compare them byte for byte; if they differ, pin the CPU feature set on every machine from the start of the
next judged run, never mid-run, and retest.

- **Code:** commit f2264a6, shipped to the worker as `git archive`, with `ops/crossmachine.py` from the freeze commit. This PC's side is the stage 2 null sweep as
  recorded (`data/campaigns/null.jsonl` and `data/campaigns/null/<id>/ledger.sqlite.xz`, run 15:52–20:03 UTC from
  dbe192b's gate and kernel; f2264a6 changed only the pool size, and every task is seeded by its id).
- **Worker:** prodesk5 (192.168.8.229, i5-8500T, no AVX-512). This PC: AVX-512, numpy dispatching
  X86_V2, X86_V3, X86_V4 and AVX512_ICL. Each side's features are recorded by `ops/crossmachine.py run`.
- **Campaigns (nine, one per model and searcher, fixed now):** c24-N1-G100-0, c24-N1-G400-0, c24-N1-H400-0,
  c24-N2-G100-0, c24-N2-G400-0, c24-N2-H400-0, c24-N3-G100-0, c24-N3-G400-0, c24-N3-H400-0.
- **Comparison (`ops/crossmachine.py compare`):** per campaign, equal result rows except `seconds`, and equal ledgers
  (every table, every row in rowid order, every column except the wall-clock `created`; return blobs byte for byte).
  Identical means all nine are identical on both; anything else is a difference, reported per campaign.

## Test 1 result, 2026-10-26 21:14 UTC (17:14 EDT): not identical

The first attempt crashed six campaigns before any comparison: N2 and N3 calibrate funding from `data/store`, which
had not been shipped (it holds only search-period rows: every eventTime precedes the holdout start). Shipped, all nine
reran (21:09–21:12 UTC). `result-1-compare.json`: every result row is identical (all fields but `seconds`), and every
`results` row (return blobs and result hashes) is identical, on a machine without AVX-512. The ledgers differ only in
`experiments.kernel` and the identities built from it (`experiments.identity`, the disclosures' `identity`): each
machine compiled its own `mm`, and the binary embeds its source path, so its hash differs (here `0aff52fc…`, the
sweep's recorded kernel; prodesk5 `82e44e46…`). No CPU-feature difference was observed.

## Test 2, frozen 2026-10-26 21:14 UTC (17:14 EDT), before it runs

Fix (§1: one kernel, not a per-machine allowance): workers never build `mm`; they run this PC's binary, copied byte
for byte (sha256 `0aff52fcf03dc63050c86a013b45cc0699e664c092c3e0f2e5cc572dcd231e3e`, built for generic x86-64).
Same nine campaigns, same code, same comparison, with the `kernel` column now included as it always was.

## Test 2 result, 2026-10-26 21:19 UTC (17:19 EDT): identical

Run on prodesk5 21:15–21:18 UTC with the shipped binary: all nine campaigns identical (`result-2-compare.json`):
result rows, return blobs, and every ledger column but the wall-clock `created`, kernel identity included. numpy
dispatched X86_V2 and X86_V3 there against X86_V4 and AVX512_ICL here, without effect on any output. prodesk7 and
gmktec (an AMD CPU) each run this same test before their first judged use.

## Test 2 on prodesk7 and gmktec, 2026-10-26 21:39 UTC (17:39 EDT): identical

Run from 21:34 UTC with the same shipped binary: all nine campaigns identical on both (`result-2-compare-prodesk7.json`,
`result-2-compare-gmktec.json`), gmktec on an AMD Ryzen 5 3500U. numpy dispatched X86_V2 and X86_V3 on both.

## Test 3, frozen 2026-10-26 23:49 UTC (19:49 EDT), before it runs: the mixed-campaign path

Human request of 2026-10-26: before stage 2's mixed sweep fans out across this PC and the homelab, check the mixed
path byte for byte on the workers. Campaigns (never judged; the mixed sweep's construction under ids `xm-…` with
fixed test betas, `ops/crossmachine.py specs()`): xm-N2-s1-0 (beta 0.01), xm-N3-s3-0 (beta 0.03) and xm-N2-long-0
(the long-holdout cell: 1,450-day market, 900-day holdout, beta 0.1). Each runs on this PC and on prodesk7, gmktec
and prodesk5, with the same code (gate and kernel unchanged since f2264a6; harness from this commit) and the same
`mm` (sha256 `0aff52fc…`). Comparison as test 2: result rows except `seconds`, ledgers except `created`, against
this PC's run. Identical means all three identical on every worker; otherwise the mixed sweep and what follows run
on this PC alone.

## Test 3 result, 2026-10-26 23:53 UTC (19:53 EDT): identical

All three mixed-path campaigns, the long cell included, are identical on prodesk7, gmktec and prodesk5 against this
PC (`result-3-compare-*.json`): result rows, return blobs and ledgers. Campaign times: this PC 42–44 s (one worker,
beside the betas calibration); prodesk7 76–79 s and prodesk5 61–64 s (two workers each); gmktec 117–122 s (two
workers). The mixed sweep may fan out.
