# Fresh Opus bug hunt in the code study 1 rests on

A fresh Claude Opus 5.5 subagent, before study 1 is marked done (`CLAUDE.md`, Correctness). Scratch copy of `study1-build` `17b7184` and the runner's kernel build; run data read only. Run 2026-11-22 13:00 to about 13:35 UTC (08:00 to 08:35 EST). Its hunt, verbatim:

# Study 1 bug hunt: the code CS1.1's result rests on

Hunter: fresh Claude Opus 5.5 subagent, 2026-11-22. Code at `17b7184` (`/home/kevin/repos/mm-review-s1`, read only). Every demonstration ran in a scratch copy, `~/.cache/mm-hunt-s1/wt` (`git archive 17b7184`), with the kernel binary the runner used (`~/.cache/mm-study1/k/release/mm`, sha256 `e6df2244…`, equal to the manifest's `kernel/mm`). The run data under `/home/kevin/repos/mm-s1-arms/data/control-1/` was only read. Scripts: `~/.cache/mm-hunt-s1/scripts/`.

## Verdict

**No defect found that could change CS1.1's verdict or its reading.** Each line of `results.jsonl` and `searcher.jsonl` that the verdict rests on was recomputed independently of the runner and agrees exactly. Two presentation notes, neither touching a count, are at the end.

## What was recomputed, and found sound

1. **The manifest holds.** `manifest.verify()` passes in the scratch copy at `17b7184`: harness hash `6a335714…` and all 61 hashed files. Every run record names that harness hash, its own market as `campaign`, and agent `A`. `results.jsonl` and `searcher.jsonl` in the arms' worktree are byte-equal to the committed ones (sha256 `3c071adf…`, `b5cc9396…`).

2. **The sequential test.** Replaying the 43 lines in order through `outcome` and `decide`: every running count and decision matches. No line before `m042` ends the study. The first crossing is at 15 wins and 4 losses. Checked in whole numbers: `7^15·3^4 ≥ 19·5^19` holds, and `7^14·3^4 ≥ 19·5^18` fails. `decide`'s constants are `log 1.4`, `log 0.6` and `±log 19`, as step 6 states. The market lines follow the manifest's order, with no gap and no repeat.

3. **Each arm's outcome comes from the right line.** `searcher_earns` on every result line equals `earns` on the matching line of `searcher.jsonl`. `reference_median` is identical, to the bit, between the two arms on all 42 judged markets. So both arms were classified against the same reference scores on the same fresh pairs.

4. **The agent's pick.** For every market, `pick.pick` on the kept ledger gives the program whose `program_key` is the line's `pick`. Each ledger holds disclosures of its own campaign and agent `A` only. Of those, `eval`, `abort`, `check` and `run` occur. No `eval` disclosure lacks a finite `sharpe_annualized`. `abort`s are not candidates, as the definition says. `evaluations` is the daemon's count, `eval` plus `abort`, and equals each run record's `spent`.

5. **G100's pick.** For all 100 markets, `searcher.jsonl` was recomputed from G100's kept ledgers and matches. That covers the seed (`g100_seed` of the manifest's seed), 100 `eval` disclosures each, the pick's hash, the earlier bests' evaluation numbers and hashes, and the rule that the last earlier best is the pick, with the same `earns`. G100 earns on 15 of 100 markets, 7 of the first 43.

6. **Both arms saw the same market, and their ledgers are faithful.** For `m001`, `m010`, `m029` and `m042`, `pairs.write_market` was rerun in scratch. Every file of the kept study market is byte-identical to the rerun, parquet included. Each program in each arm's ledger was scored again on the regenerated market and gave its ledger `sharpe_annualized` exactly: 0 mismatches over every agent and G100 evaluation. So the agent and G100 searched one market, and `e.program` is the program the kernel scored.

7. **The classification itself was redone.** On all 43 markets (`m000` to `m042`), the agent's pick (where there is one) and G100's pick were judged again with `judge.judge`. Each recomputed `pairs_won`, `earns`, `pick_median` and `reference_median` equals its line on all 43 markets, for both arms. In this run the two picks shared one reference stream, where the original run scored them separately, so the arms' classifications are also shown not to depend on which run scored them. The 15 wins and 4 losses are exactly the markets the recomputation gives.

8. **The fast store matches the store the definition names.** `scored_store` skips `gate.markets.write`. On two fresh markets, one planted at the study's strength and one at strength 0, the two writers' outputs gave bit-identical `sharpe_annualized` for 22 programs: the reference, three agent picks and 18 G100 programs. The registered definition says "written with 180 holdout days", and the fresh pairs' scores are that definition's scores.

9. **Order in the stream does not matter.** The kernel scores a program the same whether it is first in an `mm eval -` stream or a repeat. The reference twice, and once more under another name, gave three equal scores. So scoring G100's earlier bests in one stream and the agent's pick alone does not treat the arms differently.

10. **Whose sessions they are.** For every market, `model_ids` on the transcript equals the line's `models`. Each transcript's sha256 equals its run record's `transcript_sha256`. A walk over every `model` key anywhere in every transcript finds no id but `claude-opus-5-5`. There are no `<synthetic>` lines and no fallback. All 42 sessions with a run record ended `finished` with exit 0, so no transcript lost a buffered tail.

11. **`m000`.** Its line has no run record, an empty transcript, an empty ledger, `is_agent` true (the empty set of ids is vacuously inside `SERVED`), `ended` "killed", and no pick. That makes it the agent's miss, and a loss, because G100 earns there (48 of 57, recomputed). This is CS1.1's text: "A session that leaves no pick … is the agent's miss". The miss cost the agent a loss and cannot have helped the claim (`audit/decisions.md`, 2026-11-21 04:02 UTC).

12. **The pure layer, read against the brief.** `effect`, `wins` (`≥ SHARE ×` a positive reference effect), `classify` (`≥ MAJORITY` of exactly `PAIRS`), `outcome` and `decide` are each the brief's definition line for line. `pick` and `bests` share `evaluated` and one strict-`>` rule, so ties go to the earliest evaluation in both arms. In the runner, `earns` is false whenever the session is not the agent's, has no evaluation or has no pick (L8.8).

13. **The generator.** `generate` draws everything from `sha256(id)` before using `beta`. The strength changes no draw, so a twin is the same world. The fresh ids `m/fresh/k` share no seed with any study market.

14. **The sandbox.** The sandbox binds only the Nix closure of the CLI, Python and coreutils, `/bin`, `/usr`, a minimal `/etc` and the session's own `work`, `home` and `tool`. The session cannot see the repository, G100's ledgers, the reference program or the generator. The daemon gives the kernel `--store market/store` only, never the market's synthetic `holdout/`.

15. **The report.** Its counts agree with the lines: 43 markets, 15 wins, 4 losses, 24 concordant, the agent 18/43 and G100 7/43. The result's name is architecture 5.4's second column word for word. "No better" does not appear.

## Notes (not defects of the verdict)

- **N1. The report's id-set table has a blank row.** `report.py` `model_set`, lines 45 to 46 and 67 to 77, gives `m000`, which no model answered, the key `""`. The report then prints a row `|  | 1 | 0.023 | 0/1 | …` as if an empty set of ids "answered" a session. Every count is still right, and the claim's "models that answered" line reads correctly (`claude-opus-5-5`). This changes no outcome. It is presentation: a reader may take the blank row for a missing value.
- **N2. The agent's prior.** The plant leans against lagged funding. The first example in `kernel/DSL.md`, which the agent is given, is `fade-extreme-funding`: the plant's shape. Seventeen of the agent's 18 earning picks read funding alone, and the other reads premium. Architecture 5.4 already excludes "search apart from prior, since the brief names the family the plant belongs to", so the claim as registered is unaffected. Any summary of the result should keep that exclusion beside it: the agent was handed the family, and G100 reaches it only through random draws of its funding features.
- **N3. The sessions are short.** The agent used 5 to 16 of its 100 evaluations, against G100's 100. The claim is of sessions as they end, so this is not a defect. The report's "G100 at the agent's count" column holds the equal-count comparison, and architecture 5.4 says that comparison is not claimed.
