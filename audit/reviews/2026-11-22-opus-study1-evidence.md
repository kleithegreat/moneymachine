# Fresh Opus's independent review of study 1's evidence

A fresh Claude Opus 5.5 subagent at maximum effort, which built and ran no part of study 1 and did not see the advisor's conclusion. Worktree at `study1-build` `17b7184`; the run data copied and checked byte-equal before use; the frozen kernel build. Run 2026-11-22 12:54 to 17:20 UTC (07:54 to 12:20 EST), across one usage stop. Verdict: CS1.1 is met as written. The review, verbatim:

# Study 1's evidence: an independent review before the study is marked done

Reviewer: a fresh Claude Opus 5.5 session at maximum effort, which built and ran no part of study 1 and did not see the advisor's conclusion. Written 2026-11-22, 12:54 to 17:20 UTC (07:54 to 12:20 EST), with a usage stop between. Worktree `../mm-review-s1` at `17b7184`. The run data in `../mm-s1-arms/data/control-1/` were copied to `~/.cache/mm-review-s1/`, and checked byte-equal, before any program opened them. Every kernel call used the frozen build at `~/.cache/mm-study1/k` (sha256 `e6df2244…`, the manifest's). Nothing under any `data/holdout/`, no token file, and no synthetic market's `holdout/` directory was read.

## What I confirmed, and how

**1. Registered before it ran.** `criteria: study 1` (`10fedc5`, 2026-11-13 03:06 UTC) comes before the calibration. Then the manifest, committed alone (`c5d95db`, 11-17 15:11 UTC). Then G100's arm, alone (`51e0e4c`, 15:43 UTC). Then the first session (11-21 04:00 UTC). CS1.1's text on `main` and in the worktree is byte-identical to its commit, with no revision. The brief's later revisions touch step 1's fast store and step 5, and say no definition CS1.1 names changes.

**2. Identity.** On an exact copy of `c5d95db`, `manifest.verify()` passes: harness `6a335714…` and all 61 hashes. The judged path, recomputed today, names exactly the manifest's 61 files. The interpreter is the store path in the runner's own traceback, and `claude` is the hashed 2.1.304 build. The arms checkout sat at `c5d95db`, then `51e0e4c` (which adds only `searcher.jsonl`), until 12:52 UTC on 11-22, after the last session (reflog). It is clean, with nothing untracked but `data/` and `__pycache__/`. All 42 run records carry harness `6a335714…`. Every experiment row in the 43 agent ledgers and the 43 matching G100 ledgers names kernel `e6df2244…`. The evidence files' hashes match the decisions log.

**3. One session a market, in order, never rerun.** Market directories exist for `m000` to `m042` and no further. For each of the 42 sessions:
- the time from its `launched` mark to its run record equals its recorded duration, to within a second;
- its transcript holds one session id;
- its ledger's rows fall inside that span.

Each launch follows the previous session's end by 65 to 85 s (its judging and the next market's writing), or by a stop or a window's reset. The three restarts in `runner.log` (04:01:35, 04:27:02 and 20:13:05 UTC on 11-21) fall between sessions. On all 42 markets with an evaluation, the two arms' ledgers record the same `data_hash`, window, universe and cost hashes.

**4. Each line follows from its session's files.**
- *An independent recount, by my code, of all 43 lines* found no discrepancy. It checked:
  - the run record against `run.json` and the transcript against its hash;
  - the model ids and the evaluations, from both the ledger and the daemon log;
  - the pick, as the highest disclosed Sharpe among `eval` rows with the earliest winning ties, and its hash and inputs;
  - the outcomes, the running counts, and each decision by `decide`'s rule in exact integers.

  All 100 G100 seeds follow the manifest's rule, with 100 evaluations each. The reference's median effect is bit-identical between `results.jsonl` and `searcher.jsonl` on all 42 judged markets, though the arms were judged four days apart.
- *Re-judged with the study's own `pick`, `judge` and `searcher.bests` and the frozen kernel,* each line's pick hash, inputs, pairs won, medians and verdict reproduced bit for bit:
  - the agent's pick on all 15 wins, all 3 losses with a pick, the 3 markets where both arms earn, and 3 more concordant markets: 24 of 42;
  - G100's pick and every earlier best on all 43 markets.

  The 18 agent picks not re-judged are on markets where neither arm earns, so an error there could only add a win.
- *The killed session.* The runner's own `market_line`, run on copies of `m000`'s files, rebuilds its committed line exactly. There is no run record, so "killed"; no id; an empty ledger, so no pick and the agent's miss; G100 earns, so a loss.
- *Upstream of the ledgers.*
  - G100, rerun with its derived seed on regenerated `m000` and `m042`, reproduces each kept ledger's 100 programs and scores.
  - The agent's 26 evaluated programs on `m010`, `m023` and `m042`, re-scored on the regenerated markets, give the ledgers' Sharpe bit for bit.
  - On `m042/fresh/0`, the fast store that fresh pairs use scores exactly as a full market write.
  - Every session's `brief.md`, `DSL.md` and `research.md` is byte-identical to its hashed file.

**5. The model ids rule and the miss rule.** All 2,421 assistant lines of the 42 transcripts name `claude-opus-5-5`. There is no `<synthetic>` line and no `model_refusal_fallback` line. Every init names `claude-opus-5-5`, client 2.1.304, tools Bash, Read and Write, `dontAsk` and no MCP server. So every session is the agent's. `m000` left no pick and is the agent's miss, as written.

**6. Wald's test.** `sequential.py` uses `log 1.4` a win, `log 0.6` a loss and `±log 19`: `θ ≤ 1/2` against 0.7 at nominal errors of 5%. The sum first reaches `log 19` at `m042` (15 wins, 4 losses: 3.004 against 2.944; 2.667 at `m041`). Its lowest point is −0.511, after `m000`. No session was launched after `m042`.

**7. The report.** On the committed files, `report.py` rebuilds `report.md` byte for byte (`ab2cf8db…`). Its counts and Clopper-Pearson intervals match my own (18 of 43, 0.270 to 0.579; 7 of 43, 0.068 to 0.307; 18 of 42, 0.277 to 0.590). The name is 5.4's word for word. The report never says "no better", and it states nothing beyond the name, the models, the shares and the lines' numbers.

**8. The sandbox.**
- All 126 egress requests are CONNECTs to `api.anthropic.com`.
- The 13 permission denials are the agent editing its own strategy files with `sed` or Python, plus one `--help`.
- All 210 rate-limit events read "allowed".

## Findings

**F1. The share the study met had no fallback.** *Affects:* what the result may be called. *Evidence:* none of the 42 counted sessions fell back to `claude-opus-4-8`. In the pilot, 109 of 169 did (0.475 to 0.695 by campaign, architecture 5.2). The client, its flags and the brief are the hashed ones, so the share moved on the provider's side. *Bearing:* CS1.1 already limits the claim to "the agent at some share it met", and it claims nothing at the pilot's share. But architecture 5.2 calls the study a control of "the pilot's agent as it ran". The paper and `docs/findings.md` must therefore say that every counted response came from `claude-opus-5-5`, and must not carry the result over to the pilot's searches, most of which `claude-opus-4-8` answered. Nor is the result about `claude-opus-5-5` alone: the subject is the harness as served, which here did not fall back. *A note on the statement,* which the criterion itself requires; the verdict is unchanged.

**F2. The size is 0.04308, so "at most 0.043" and L6.6 are false as stated.** *Affects:* a number in CS1.1 ("Size at most 0.043", "by chance, at most 0.043"), and the brief's L6.6 ("below `43/1000`", marked Lean). *Evidence:* my exact rational enumeration of the worst null gives 0.0430787 at 100 markets; it would be 0.0429896 had the test ended at 99. The study's `test_sequential.py` computes the same value, and passes because it allows `0.043 + 0.0005`. GPT's paper review of 11-21 found it too, and the paper now says "bounded above by 0.0431". What remains:
- no Lean file on any branch states L6.6, L6.1, L6.4, L6.5, L2.8 or L2.10, though the brief owed their proofs before step 9's report;
- L6.6 cannot be proved as written.

*A note:* the Met condition does not read the size, and 0.0431 is below the nominal 5%. A dated note under CS1.1, and whether the owed proofs (L6.6 restated at 0.0431) come first, are the advisor's call.

**F3. Market 1 is a sandbox that never started.** *Affects:* one market's outcome. *Evidence:* `runner.log` shows `FileNotFoundError: 'bwrap'` raised from `Popen`. The transcript has 0 bytes, the ledger has no row, and there is no run record. *Bearing:* a miss, as written: each market has one session, never rerun, and a session that leaves no pick is the agent's miss. It cost the agent a loss, since G100 earns there (re-judged). Without that loss, the boundary would have been crossed at `m041`. A miss can never make a claim (L6.4). Two smaller points:
- The restart put bubblewrap 0.12.0, from the locked nixpkgs, first on `PATH`. The sandbox binary is outside the harness hash, so from `m001` on it may be a different build from the pilot's. Its flags are the hashed ones, and the egress log and the denials show the same confinement.
- "Killed" is the code's word for "no run record". Here it names a session that never began.

*A note.*

**F4. The report leaves out three items it should report but never judge.** *Affects:* what is reported; nothing judged. *Evidence:* step 9's behaviour 3 and architecture 5.5 ask for each pick's pairs won "by arm", the inputs each pick reads, and each pick's median effect. The report prints these for the agent's pick only. G100's pairs won and inputs are in `searcher.jsonl` but not printed. G100's median effect is in no line, because step 7's line does not hold it. The table by set of ids also gives `m000`'s empty set a row with a blank name. *A note:* `report.py` is outside the judged path, so it can be fixed and rerun before the paper quotes it. My re-judging's outputs hold G100's medians for all 43 markets (`~/.cache/mm-review-s1/out/`).

**F5. Notes.**
- `17b7184`'s message gives the last result as 10:55 UTC. `results.jsonl` was last written at 10:10:57 UTC, a minute after `m042`'s run record. That commit skipped the suite (`--no-verify`) and adds only the two files.
- The runner treats a session with evaluations but no recorded id as not the agent's. That is stricter than the brief, and guards against a kill that loses a transcript's tail. It can only make a miss, and it never applied.
- *Accounts, pacing and shared use.* By their rate-limit events, TAMU answered `m001` to `m031` and Cornell `m032` to `m042`, as the log says. The switches and the human's pacing changed when sessions ran, never which market ran next or which code ran. The frozen `wait_for_room` paced every launch, and each restart re-ran `verify()`. Other Claude work on the same accounts could only have ended a session early, and none ended early. CS1.1's null holds for every market's session, so choosing an account after seeing results cannot raise the size. The agent earned on 12 of 31 TAMU markets and 6 of 11 Cornell markets.

## Verdict

**CS1.1 is met as written.** The study ran as registered:
- the criterion, calibration, manifest and G100's arm came in that order, frozen;
- each market had one session, in the manifest's order, and none was rerun;
- every counted session was the agent's;
- the one session that never started is a miss, as CS1.1 says.

Every line the verdict rests on reproduces from the kept files, under the study's own code and kernel: all 15 wins and 4 losses, on both arms, and every concordant market where an error could have hidden a loss. So Wald's upper boundary is first crossed at `m042`, as recorded. Nothing in the decisions log (the sandbox failure, the account switches, the pacing) could have produced the claim or helped it.

The result is stated at the share the study met: every counted response came from `claude-opus-5-5`, so it does not reach the pilot's searches (F1). Its size is 0.0431 (F2). The report should gain F4's items before the paper uses it.
