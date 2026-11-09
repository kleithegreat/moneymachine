# Positive controls: criteria draft (not frozen)

Round four, Claude Opus builder, 2026-11-09. Paper §17, PC1–PC6 (`docs/whitepaper.tex`, `sec:pc-*`), derives every number and choice below; this draft says only what is checked. `audit/positive-controls-design-check.py.txt` reproduces the arithmetic. After review (Argon, then the criteria alone, `CLAUDE.md`), these lines go into `audit/criteria.md` and are never edited.

Exit: all seven hold. No promotion, rejection or resolved-truth quota is an exit condition. Scientific ambiguity can pass a bounded report but not a claim of complete localization; missing or corrupt evidence prevents exit. Nothing started is replaced.

## PC.C1: prospective provenance

**Claim:** the evidence comes from this registered procedure, through no recycled holdout or disclosure channel.

**Pass:** PC1's manifest is committed after the thesis refreeze lands and before any development market is generated, with the kernel pinned by its full SHA256 and the harness by the refreeze's `harness_hash()` as a literal 64-hex value; the runner refuses a session under any other harness. Ids `pc-v3-m-000..032`, `pc-v3-release` and the disjoint dev/val/truth/kill namespaces are checked for occupancy and content lineage before reservation. The only funding input is PC2's frozen blob, checked by its hash. The geometry is 730/180/670 with exactly 360 reported returns. No real holdout, embargo, live or forward-window price or return is read.

**Pass while false:** a fresh id aliases an old market's content, or R's results reach A before A's freeze. Content lineage and disclosure order reject both; id strings are not trusted.
**Fail while true:** a flake update changes the `claude` build, which `harness_hash()` includes, while the agent's behaviour would be unchanged: the runner refuses every session. That is intended: the build is part of the harness and the flake lock pins it, so the correct study passes under the pinned lock, and a changed build takes a new manifest with new ids.

## PC.C2: an expressible, validated net alternative

**Claim:** every market offers a net-profitable registered use of the plant that the DSL expresses with correct timing.

**Pass:** independent witnesses check the four references' input, decision and fill timestamps, lag, warm-up, clipping and weights (a parse is not enough; a demonstrated obstruction is "cannot express" and blocks agent admission). PC2's development grid, bracket and tie rules are applied exactly and every curve published. On the 20 validation pairs, R's net-Sharpe and plant-Sharpe (PC4) lower endpoints are positive at one program's `q = 3.174` (PC2), before any agent session; achieved Sharpe and per-market SDs are reported against PC4's planning values. Failure blocks spending, with no retuning.

**Pass while false:** R is calibrated at gross Sharpe 1 and turnover erases it net, or the raw oracle is calibrated while a registered variant reaches 3. Net, max-over-family calibration and net validation reject both.
**Fail while true:** R's true net Sharpe is 1 at per-market SD 0.5 and the 20-pair draw lands low. The interval is one program's, so it fails with probability 2·10⁻⁷, not the truth family's tail; R at net 0.89 with both lower endpoints positive passes, since no tolerance on the residual gates anything.

## PC.C3: faithful, isolated arms and one release per market

**Claim:** differences between arms come from the registered A, G100 and R procedures, not from leaked help, changed gates or a second release path.

**Pass:** 33 A sessions, 33 G100 searches and 33 R submissions at C1's ids, in PC1's order, with PC3's budgets, permissions and gate; all selections sealed before any truth or holdout outcome. Isolation is classified by execution and disclosure (PC3); legacy `audit_holds` is published and stops nothing. Every market, and PC5's fixture, is released and reported by PC3's one arm-list function; tests target that function directly. Independent tests cover evaluation 101, denied against executed tools, cross-arm and cross-market history and unauthorized disclosure.

**Pass while false:** A copies R's disclosure, or a call that looks denied executes. Order and execution evidence reject both. Or the study's release drops one arm's result from a shared-program batch: the single function and PC5's test on it reject it.
**Fail while true:** an intact A stops after six evaluations after a denied `Edit`. Procedure and isolation pass, B and R still run, and discovery is judged separately.

## PC.C4: truth and first bottlenecks

**Claim:** the report says which programs capture the plant materially and net-profitably, by any route, and where each arm lost it, wherever the evidence settles it, and bounds it elsewhere.

**Pass:** after every freeze, every distinct valid evaluated program (zero-fill included), the four references and the two assay controls run on the 73 truth pairs, each member written once, streamed. Recovery, non-recovery and ambiguity follow PC4's two intervals, per-pair net Sharpe `S` and `h = G − G_R/2` with the gross plant Sharpe `G`, at `q = 5.419` (`M ≤ 6,606`); R certifies its own `S` and `G` first. The half-size copy resolves as recovery and the sign-flipped copy as non-recovery. First bottlenecks follow PC3, assigned only when invariant over ambiguous programs, otherwise bounded. Recovered programs that read funding are marked.

**Pass while false:** a lucky unrelated promotion is counted as recovery; a program holds the plant beside a large unrelated book; or a program trades heavily only when it sees no plant, so its zero twin pays costs the planted market does not. The first is reported apart; the second's `G` is small, since its risk is in the denominator; the third gains nothing, since `G` is gross and the twin's trading has zero expected gross return (D1).
**Fail while true:** the agent captures the plant by price momentum without reading funding: the plant pays it, so it is recovery, marked as not reading funding. Or the agent writes R at half its size: `G` and `S` are unchanged, so it resolves as recovery (the registered control enforces this). Or every market's only plant variant has net Sharpe 0.5 and 81% of R's plant Sharpe (at `G_R = 1.2`), with the twins' positions parting like slow sign momentum's: certified with probability .995 at PC4's planning SDs. Below those floors a program may stay ambiguous, which is reported, never forced.

## PC.C5: decision-sized inference

**Claim:** the report answers whether material discovery and selected recovery are rare (p ≤ .2) or common (p = .5) at PC4's operating characteristics, and states what the cell can express.

**Pass:** PC4's two tests on the 33 markets, cutoff 12 certified successes, unresolved when ambiguity straddles it; the intervals, discordance tables, attrition and actual N; the strongest evaluated program's truth net Sharpe per arm; R's selections against the registered prediction `Φ(Ŝ_R/0.815 − 1.645)`; each recovered finalist's confirmation horizon at the gate's limiting bet (PC4), finite whenever its truth mean is positive; r2 cited as prior, not as new trials. Size .02159, power .95993 ideal and at least .9509 with every success at the certifiable floor, under any sharing of programs among markets; the nominal total .0532 with truth error.

**Pass while false:** 3,300 evaluations are treated as trials, the forced fixture counts as success 34, rejecting rarity is read as p > .5 or superiority, or one program found in 17 markets is counted as 17 independent certifications. Fixed market denominators, fixture exclusion, the stated scope and power sized over every sharing reject these.
**Fail while true:** estimates come out intermediate, every selected recovery fails confirmation, or R's selections miss the prediction. Each passes as a reported result; none is an exit condition.

## PC.C6: the release path, forced nonempty

**Claim:** PC3's per-market release and report work on a nonempty union at full geometry, consumed returns and irreversible accounting included.

**Pass:** PC5's fixture through PC3's function, with A freezing R and its half-size copy and R freezing R: one union claim of two programs, the shared result mapped to both arms, A's Holm over two finalists, exact identities and result counts, 360 returns per result, promotions committed before diagnostics and the report rebuilt from committed rows; a repeated release adds nothing. The independent witness matches every consumed return, boundary normalization, total and equity within PC5's tolerance. Kill tests on disposable ids: before the claim (unspent, unchanged retry only), after it at PC5's lock barrier then SIGKILL (spent, missing results p = 1, never completed), and a partial three-finalist batch stopped by a ledger trigger after one result.

**Pass while false:** an empty freeze, a hand-written claim, a self-comparison, boundary costs missing from consumed returns, or a release that keeps one arm's copy of a shared program and drops the other's yield a clean report. The nonempty count checks, the shared finalist, the witness and the real kill reject them.
**Fail while true:** p ≈ 1 with no promotion, finding 6 affects diagnostic summaries only, or the kernel would finish its batch within a millisecond of the claim. All pass: the barrier is a lock the kernel waits on, so its speed cannot beat it.

## PC.C7: accounts and accounting

**Claim:** model use runs only on the accounts the human allowed, is fully accounted for, and nothing is replayed or replaced.

**Pass:** before every session, canary, probe and `windows()` call, the account identity resolved from the token about to be used is one the human recorded for TAMU or Cornell; otherwise nothing runs. No other Claude work runs on an account during a study session on it. Admission follows PC6's ceiling and reservations, each capped at the ceiling; every session logs account identity, window deltas, tokens and API-equivalent dollars. PC6's forecasts are published beside the actuals. Every started id, manifest, hash, ledger, claim, transcript and sufficient statistic is preserved, and reports rebuild without replaying a claimed holdout.

**Pass while false:** the personal token is filed under the TAMU key while the cached login still names TAMU. The identity is resolved from the token in use, so nothing runs. Or a crash is replaced, or missing usage is charged zero: fixed ids and conservative telemetry reject both.
**Fail while true:** compliant use exceeds the 200-turn forecast, one session uses .82 of a five-hour window, TAMU's token is refreshed mid-study, or the study takes three weeks. The budget is unlimited and forecasts are not caps; the capped reservation waits for an unused window; the account, not the token, is checked. All pass, reported.
