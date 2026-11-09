# Positive controls: criteria draft (not frozen)

Round three, Claude Opus builder, 2026-11-09. Paper §17, PC1–PC6 (`docs/whitepaper.tex`, `sec:pc-*`), derives every number and choice below; this draft says only what is checked. `audit/positive-controls-design-check.py.txt` reproduces the arithmetic. After review (Argon, then the criteria alone, `CLAUDE.md`), these lines go into `audit/criteria.md` and are never edited.

Exit: all seven hold. No promotion, rejection or resolved-truth quota is an exit condition. Scientific ambiguity can pass a bounded report but not a claim of complete localization; missing or corrupt evidence prevents exit. Nothing started is replaced.

## PC.C1: prospective provenance

**Claim:** the evidence comes from this registered procedure, through no recycled holdout or disclosure channel.

**Pass:** PC1's manifest is committed before any development market is generated, with the kernel pinned by its full SHA256 and the harness pinned to the `harness_hash()` that the thesis refreeze freezes; the runner refuses a session under any other harness. Ids `pc-v3-m-000..032`, `pc-v3-release` and the disjoint dev/val/truth/kill namespaces are checked for occupancy and content lineage before reservation. The only funding input is PC2's frozen blob, checked by its hash. The geometry is 730/180/670 with exactly 360 reported returns. No real holdout, embargo, live or forward-window price or return is read.

**Pass while false:** a fresh id aliases an old market's content, or R's results reach A before A's freeze. Content lineage and disclosure order reject both; id strings are not trusted.
**Fail while true:** the refreeze lands and changes `harness_hash()`. The pin is the refreeze's freeze, so the correct study passes; a literal pre-refreeze hash would fail it.

## PC.C2: an expressible, validated net alternative

**Claim:** every market offers a net-profitable registered use of the plant that the DSL expresses with correct timing.

**Pass:** independent witnesses check the four references' input, decision and fill timestamps, lag, warm-up, clipping and weights (a parse is not enough; a demonstrated obstruction is "cannot express" and blocks agent admission). PC2's development grid, bracket and tie rules are applied exactly and every curve published. On the 20 validation pairs, R's net-mean and plant-Sharpe (PC4) lower endpoints are positive at the truth family's tail `q19` (PC2), before any agent session; achieved Sharpe and per-market SDs are reported against PC4's planning values. Failure blocks spending, with no retuning.

**Pass while false:** R is calibrated at gross Sharpe 1 and turnover erases it net, or the raw oracle is calibrated while a registered variant reaches 3. Net, max-over-family calibration and net validation reject both.
**Fail while true:** R validates at net 0.89 with both lower endpoints positive. It passes: no tolerance on the residual gates anything.

## PC.C3: faithful, isolated arms and one release per market

**Claim:** differences between arms come from the registered A, G100 and R procedures, not from leaked help, changed gates or a second release path.

**Pass:** 33 A sessions, 33 G100 searches and 33 R submissions at C1's ids, in PC1's order, with PC3's budgets, permissions and gate; all selections sealed before any truth or holdout outcome. Isolation is classified by execution and disclosure (PC3); legacy `audit_holds` is published and stops nothing. Every market, and PC5's fixture, is released and reported by PC3's one arm-list function; tests target that function directly. Independent tests cover evaluation 101, denied against executed tools, cross-arm and cross-market history and unauthorized disclosure.

**Pass while false:** A copies R's disclosure, or a call that looks denied executes. Order and execution evidence reject both. Or the study's release drops one arm's result from a shared-program batch: the single function and PC5's test on it reject it.
**Fail while true:** an intact A stops after six evaluations after a denied `Edit`. Procedure and isolation pass, B and R still run, and discovery is judged separately.

## PC.C4: truth and first bottlenecks

**Claim:** the report says which programs use the plant materially and net-profitably, and where each arm lost it, wherever the evidence settles it, and bounds it elsewhere.

**Pass:** after every freeze, every distinct valid evaluated program (zero-fill included), the four references and the three assay controls run on the 69 truth pairs, each member written once, streamed. Recovery, non-recovery and ambiguity follow PC4's two intervals at `q = 5.449` (`M ≤ 6,607`); R certifies its own net mean and plant Sharpe first. The half- and fifth-size copies resolve as recovery and the sign-flipped copy as non-recovery. First bottlenecks follow PC3, assigned only when invariant over ambiguous programs, otherwise bounded.

**Pass while false:** a lucky unrelated promotion is counted as recovery; a sign-squashed program at large size clears materiality through exposure. Its plant Sharpe is near zero, so it resolves as non-recovery, and unrelated promotions are reported apart.
**Fail while true:** the agent writes R at half or a fifth of its size: plant Sharpe and net Sharpe are unchanged, so it resolves as recovery (the registered controls enforce this). Or every market's only plant variant has net Sharpe 0.5 and 62% of R's plant Sharpe (at `G_R = 1.2`): certified with probability .99 at PC4's planning SDs. Below those floors a program may stay ambiguous, which is reported, never forced.

## PC.C5: decision-sized inference

**Claim:** the report answers whether material discovery and selected recovery are rare (p ≤ .2) or common (p = .5) at PC4's operating characteristics, and states what the cell can express.

**Pass:** PC4's two tests on the 33 markets, cutoff 12 certified successes, unresolved when ambiguity straddles it; the intervals, discordance tables, attrition and actual N; the strongest evaluated program's truth net Sharpe per arm; R's selections against the registered prediction `Φ(Ŝ_R/0.815 − 1.645)`; each recovered finalist's confirmation horizon; r2 cited as prior, not as new trials. Size .02159, power .95993 ideal and at least .9547 with every success at the certifiable floor; the nominal total .0532 with truth error.

**Pass while false:** 3,300 evaluations are treated as trials, the forced fixture counts as success 34, or rejecting rarity is read as p > .5 or superiority. Fixed market denominators, fixture exclusion and the stated scope reject these.
**Fail while true:** estimates come out intermediate, every selected recovery fails confirmation, or R's selections miss the prediction. Each passes as a reported result; none is an exit condition.

## PC.C6: the release path, forced nonempty

**Claim:** PC3's per-market release and report work on a nonempty union at full geometry, consumed returns and irreversible accounting included.

**Pass:** PC5's fixture through PC3's function: one union claim, exact identities and result counts, 360 returns per result, promotions committed before diagnostics and the report rebuilt from committed rows; a repeated release adds nothing. The independent witness matches every consumed return, boundary normalization, total and equity within PC5's tolerance. Kill tests on disposable ids: before the claim (unspent, unchanged retry only), after it by PC5's SIGSTOP barrier then SIGKILL (spent, missing results p = 1, never completed), and a partial multi-finalist batch.

**Pass while false:** an empty freeze, a hand-written claim, a self-comparison or boundary costs missing from consumed returns yield a clean report. The nonempty count checks, the witness and the real kill reject them; a barrier that loses its race fails as "barrier missed".
**Fail while true:** p ≈ 1 with no promotion, or finding 6 affects diagnostic summaries only. Both pass, with finding 6's qualification.

## PC.C7: accounts and accounting

**Claim:** model use runs only on the accounts the human allowed, is fully accounted for, and nothing is replayed or replaced.

**Pass:** before every session, canary, probe and `windows()` call, the token's SHA-256 is one the human recorded for TAMU or Cornell; otherwise nothing runs. No other Claude work runs on an account during a study session on it. Admission follows PC6's ceiling and reservations; every session logs account name, token hash, window deltas, tokens and API-equivalent dollars. PC6's forecasts are published beside the actuals. Every started id, manifest, hash, ledger, claim, transcript and sufficient statistic is preserved, and reports rebuild without replaying a claimed holdout.

**Pass while false:** the personal token is filed under the TAMU key. Its hash is not recorded, so nothing runs. Or a crash is replaced, or missing usage is charged zero: fixed ids and conservative telemetry reject both.
**Fail while true:** compliant use exceeds the 200-turn forecast, or the study takes three weeks. The budget is unlimited and forecasts are not caps, so both pass, reported.
