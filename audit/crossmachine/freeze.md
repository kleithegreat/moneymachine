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

## Test 4, frozen 2026-10-27 01:26 UTC (21:26 EDT), before it runs: the calibration path

Human request of 2026-10-26: fan the betas calibration out only if the cross-machine evidence covers its path.
`ops/calibration_check.py` computes `sweep.net_returns` (generation, write, `mm eval`) for the oracle on a ten-year N2
market (beta 0.025, market xc-N2-0) and for the weight-2.0 oracle on a two-year long-cell market (beta 0.1,
xc-long-0), never judged ids, printing the sha256 of each returns array. Identical means the same hashes on this
PC, prodesk7, gmktec and prodesk5; then calibration keys may fan out, otherwise betas runs here.

## Test 4 result, 2026-10-27 01:28 UTC (21:28 EDT): identical

Both markets' returns hash the same on this PC, prodesk7, gmktec and prodesk5 (xc-N2-0
`cfbad50e…`, 21,899 steps; xc-long-0 `bfa46e0f…`, 4,379 steps). Calibration keys may fan out.

## Test 5, frozen 2026-10-27 01:42 UTC (21:42 EDT), before it runs: the I5 revision's binary

Human decision of 2026-10-27: before the mixed sweep uses the new `mm` (I5 scaled by peak equity; sha256
`52db7b687648b5fbad19ad52a76d40d3b8719a94483d12106b9081572107807c`, built from this commit's `kernel/mm/src/sim.rs`):
- **(a) Reproduction.** On this PC it reruns 15 recorded null campaigns, test 2's nine and c24-N1-G100-150,
  c24-N1-H400-200, c24-N2-G400-77, c24-N2-H400-38, c24-N3-G100-123, c24-N3-H400-299, compared with the null sweep's
  records by `ops/crossmachine.py compare-kernel`: result rows except `seconds`, ledgers except `created` and the
  kernel identity (the `kernel` and `identity` columns, the disclosures' `identity`; validated on test 1's
  kernel-only difference, which it alone accepts).
- **(b) Cross-machine.** The binary copied to every worker reruns test 2's nine and test 3's three, compared with this
  PC's runs of the same binary by `compare` (kernel identity included).
- I5's mutant was rerun on this tree before the freeze: caught.
Identical in both parts lets the mixed sweep use this binary; otherwise it does not.

## Test 5 result, 2026-10-27 02:01 UTC (22:01 EDT): identical

(a) The new binary reproduces all 15 recorded null campaigns apart from the kernel identity (`result-5a-reproduction.json`);
every local ledger carries the new kernel `52db7b68…`, so the new binary ran. (b) On prodesk7, gmktec and prodesk5 the
same binary matches this PC on all 12 campaigns, kernel identity included (`result-5b-compare-*.json`). The mixed sweep
may use it.

## Test 6, 2026-10-27 19:49 UTC (15:49 EDT): the revised gate path (screen, patched StepM, holdout)

Asked for by the human's plan of 2026-10-27 before the round-r2 rerun, and not frozen here before it ran. At commit
c301a1f, each host built the flake's shell (arch with upstream's StepM fix) and ran the seven never-judged mixed test
specs (`xm-N2-s1-0` to `xm-N3-s3-0` and `xm-N2-long-0`, test betas). `xm-N2-long-0` exercises the whole revised
path: SPA rejects, the screen admits and StepM keeps 113 finalists, and the holdout runs. `compare` against this PC:
**identical** on prodesk7, gmktec and prodesk5, every result row except `seconds` and every ledger, kernel identity
included (`result-6-compare-*.json`). The round-r2 sweeps may fan out.

## Test 7, frozen 2026-10-27 21:21 UTC (17:21 EDT), before it runs: the loader-memory candidate

Human decision of 2026-10-27: land `mm`'s loader memory fix before round r2 (typed columns of 16-byte cells instead of a
map per row, unread metadata columns not stored, resolution by a stable sort on the key), results bit-identical.
Candidate: sha256 `3a732069413d050f334229e3e1bcf8d804f2e10ba21ad0365dd5187f6ed081b7`, built from the working tree with `CARGO_TARGET_DIR=kernel/target-loader` (two builds,
same hash); its source is committed after (b) passes and must rebuild to this hash. Shipped until then: `52db7b68…`.
- **(a) Reproduction.** `ops/crossmachine.py reproduce` reruns, with the candidate, the search phase of 25 recorded
  first-round campaigns on markets regenerated from their ids: c24-{N1,N2,N3}-{G100,G400,H400}-{7,211} and
  c25-{N2,N3}-s{1,2,3}-42 and c25-N2-long-42. Each ledger must equal the recorded one apart from `created` and the
  kernel identity (the first round froze no finalist, so its ledgers are all kernel output), and must carry the
  candidate's kernel identity.
- **(b) Suite.** `cli check` with `CARGO_TARGET_DIR` at the candidate: pytest (kernel-calling tests run the
  candidate), the kernel's cargo tests (I5's fixture among them) and every mutant caught; the only allowed failure
  is the known C0.7 criterion.
- **(c) Corpus differential.** C6.4's frozen corpus (`differential-run`), with `mmdump` rebuilt on the candidate's
  loader: every verdict and every run equal to the Lean reference's, byte for byte.
- **(d) Cross-machine.** The candidate copied byte for byte to prodesk7, gmktec and prodesk5 reruns the seven `xm-`
  mixed test specs, compared by `compare` with this PC's candidate runs, kernel identity included.

All four pass: the candidate becomes `kernel/target/release/mm` on every host and round r2's plan pins its hash.
Any failure: it does not ship, and round r2 runs on `52db7b68…`.

## Test 7 result, 2026-10-28 00:29 UTC (20:29 EDT): all four parts pass; the candidate ships

- **(a)** All 25 first-round campaigns' search phases reproduce their recorded ledgers apart from `created` and the
  kernel identity, and every reproduced ledger carries the candidate's (`result-7a-reproduce.json`).
- **(b)** `cli check` on the candidate: only the known C0.7 criterion fails; 17 mutants caught, among them I8's,
  which mutates the rewritten resolver's holdout line.
- **(c)** All 1,196 verdicts and 3,372 runs of C6.4's frozen corpus equal the Lean reference's, byte for byte
  (`result-7c-differential.json`), as in its judged report on the same manifest. That report's `pass` is false
  only because `complete()` checks the frozen corpus against the live adversarial suite, which gained 22 rejection
  cases (`adversarial-gpt40` to `gpt61`) after the freeze; the candidate checked those in (b). A fresh corpus is
  stage 7's (PROGRESS). Running it first needed the market hash to leave out the `version` pin (`audit/decisions.md`).
- **(d)** The candidate copied to prodesk7, gmktec and prodesk5 matches this PC on the seven `xm-` specs, kernel
  identity included (`result-7d-compare-*.json`).

Installed as `kernel/target/release/mm` (`3a732069…`) on this PC, prodesk7 and prodesk5, and on gmktec once its last
preview campaigns end. The committed source (dd9580d) rebuilds to this hash. Measured with it: a ten-year evaluation
936 MiB (was 4,279), a campaign 533 to 684 MiB (was about 1 to 2.5 GB); pools are sized from these.
