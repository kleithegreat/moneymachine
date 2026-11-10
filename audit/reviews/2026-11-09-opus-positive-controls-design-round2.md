Reviewer: Claude Opus 5.5 (fresh session; GPT built the design) | 2026-11-09 11:58 UTC (06:58 EST) | Subject: branch `positive-controls` at `96194c8` (a0a440b..96194c8), three-dot from `main`: paper §17 PC1–PC6 (`docs/whitepaper.tex`), `audit/positive-controls-criteria-draft.md`, `audit/positive-controls-round2-design-check.py.txt`, and the PROGRESS and decisions lines. Checked against round one (`audit/reviews/2026-11-08-opus-positive-controls-design.md`, F1–F14), the meta review's recommendation 2, the human's decisions of 2026-11-08 21:44 UTC (16:44 EST) and 2026-11-09 06:59 UTC (01:59 EST), and the code: `gate/{markets,gate,search,sweep,campaign}.py`, `gate/agent/{campaigns,harness}.py`, `sandbox/session.py`, `gate/tests/test_agent_real.py`, `ops/live.py`, `CLUSTER.md`, `thesis-refreeze`'s decisions. Records: `audit/stage2/{r2-finalists.json,sweeps.json}`, `data/campaigns/{betas.json,betas-steps.jsonl,mixed.jsonl}` (stage 2 synthetic search records), `audit/stage3/null-v3.jsonl`.

Runs, all under `~/.cache/mm-rv-pc/r2`, no model, no campaign, no kernel, no protected data: GPT's design check (reproduces exactly); `num.py`/`num2.py` (t and binomial arithmetic); `sim2.py`/`sim3.py`, a rough check that uses the real N2 generator (`markets.generate`, with the frozen funding from `data/store` before `HOLDOUT_START`, hash-checked against `d07162b8…`) and numpy positions with a flat 6.5 bps cost per unit turnover, not the kernel's fills. Its numbers are good for magnitude only.

## Verdict

**Commit the criteria after fixes; no redesign needed.** The question, the pairing, the four-stage attribution, the paired material contrast, the dropped tolerance gate, the isolation classification, the C6 scope, the cost model and the account rule all answer round one at its cause. Every number checks: n = 33/k = 12 (size .02159, power .95993, and no smaller n works), the worst Clopper–Pearson half-width at 402, q = 8.210 at M = 43,906, the usage sums and fits, and the confirmation algebra. The ids are unoccupied, and no input is protected. Five findings still change criteria text or numbers, so they must be fixed before the criteria are committed alone:
- the truth assay cannot certify most plant-capturing programs at this target (R1);
- materiality depends on position size (R2);
- the forced release tests a path that the study's own releases do not use (R3);
- the harness pin goes stale when the refreeze merges (R4);
- the 402 model-free markets buy precision that no decision uses, and cost the agent's truth resolution (R5).

R1, R2 and R5 change M, q and the truth bank, so the design changes. Under CLAUDE.md, the re-review goes to another model (Argon, already queued).

## Findings, ranked

**R1. At q = 8.21 with 20 ten-year pairs, the net-mean condition leaves most material recoveries ambiguous, so C5's decision power does not survive (fail while true for C5; changes C4's truth size).** The paired contrast resolves well. In the rough model the reference's gain varies across markets with CV 0.07–0.12, so the F3 fix works for unrelated programs. The binding term is net mean > 0. Across 20 ten-year markets, the SD of net Sharpe is 0.41 for `raw` and 0.275 for `raw24` at β = 0.025, where both reach about 1 (iid would give 0.316). The two-sided half-width is therefore q·SD/√20 ≈ **0.75 and 0.50 Sharpe**. Any program that captures the plant materially but has true net S below about 0.5–0.75 can never be certified. That covers most variants weaker than the best reference.

The locked reference itself still certifies: the chance it fails is about 0.3% at SD 0.41. Discovery power at p = .5 falls from .96 to .72 if 20% of true successes are only "possible", and to .27 at 40%.
- **Construction:** in every market the agent evaluates one plant variant with true net S = 0.4 and h > 0. Certified successes are then 0 and possible successes 33. The report reads "unresolved" while discovery is in truth routine.
- **Fix:** derive the truth bank from a stated certifiable effect, for example half the reference's net Sharpe. At M = 6,604 (R5), 80 pairs give q = 5.37 and a half-width of 0.17–0.25, for 1.06M replays, fewer than today's 1.76M. Alternatively, derive a control variate. Positions are fixed before each bar and the N2 innovations are mean-zero given the past, so E m⁺ ≈ E g − E c⁰ (zero-market costs) up to clipping and compounding. That would give net mean at the gain's precision, if the kernel exposes per-step costs. Validation should then check that the reference can be certified at truth's q, not only that it is positive at 2.861.

**R2. Materiality is in absolute return units, so it depends on position size (fail while true, C4).** h = g − g_R/2 compares P&L. Suppose the agent writes exactly the locked reference at its own size, say 0.05·u instead of 0.1·u: h is then exactly 0 in every market, and the program is never resolved. At 0.02·u it is certified non-recovery, although it is the plant rule at the reference's Sharpe. The reverse also happens. The reference's mean |w| is about 0.1 × E|a| ≈ 0.008–0.009 per coin (E|a| = 0.077 for BTC and 0.093 for ETH in the frozen funding), so sign-squashed programs at the DSL's usual sizes (0.02–0.1) clear g_R/2 through exposure, not skill.
- **Fix:** derive a scale-invariant materiality from the claim. For example, the plant's contribution to the program's own risk-adjusted return (gain over its own planted-market volatility, against half the reference's), with the cluster-delta treatment PC2 already uses for Sharpe. Keep net mean > 0 separate.

**R3. The forced release exercises `campaigns.real/report`, while the study's judged releases run a new three-arm composition: two paths (pass while false, C6).** PC6 keeps the two-arm `campaigns.report` as "the sentinel's production path" and composes a separate three-arm report for the study. The reference is selected in about 30% of markets: N = 1 PSR gives Φ(−0.417) = 0.338 analytically, and 0.30 in the rough model at 3,300 steps. So the study will run on the order of 100 nonempty union releases through code that neither the forced finalist, the independent witness nor the SIGKILL test touches.
- **Construction:** the study's composition drops one arm's result from a shared-program batch, or claims twice. C6 still passes on `real/report`.
- **What the study needs from agent-real** is the per-market core: freeze; `gate.release` with its claim semantics; `committed_holdout`; per-arm `promote`/Holm with absent results as p = 1; `commit_promotions` before diagnostics; a report rebuilt from committed rows; the before-claim and after-claim recovery rules. It does not need `real()`'s stage-3 driver: `real_attempt`, the `data_root` symlinks, real-store `check_ready`, `REAL_REPORT_FROM`, single-campaign pacing, and `both_arms`' exit on legacy `audit_holds`, which C3 now rejects for a denied call.
- **Fix:** one per-market release/report that takes the arm list (A, B, R) and is run by every study market. The forced finalist, the witness and the kill test all target it. This also answers the human's deletion question precisely. The core is reused, so it stays. `real()`'s driver is not needed by the study, so it is kept or deleted on its own merits: its only use is the unspent stage-3 holdout, which is the human's call.

**R4. The harness pin is stale: the refreeze forks it, and its decision names positive controls (fail while true, C1; changes what "the pilot agent" is).** `thesis-refreeze` round eleven changes `sandbox/client.py` and `sandbox/canary.py`, so the shared harness identity becomes `3d2e6a72…` (`audit/decisions.md` on that branch, 2026-11-09 08:18 UTC (03:18 EST)). That decision says "next campaigns, including positive controls, require fresh campaign ids". PC1/C1 pin `6a335714…` and block on any frozen-identity change. Once the refreeze merges, a correct study on the frozen fork fails C1; on the old pin, it runs a client that main no longer has.
- **Fix:** pin the harness identity frozen with the refreeze. State as a qualification that A's client and canary differ from C3.2/C4.5: the new envelope rejects compound shell commands. Comparability with stage 3/4 agent behaviour is then qualified, not assumed.

**R5. The 402 model-free markets serve no named decision, and they take 91% of truth compute and the agent's resolution (changes C5's B/R design and C4's M).** The ±5-point resolution is "one sixth of the decision gap", but no decision reads B's or R's rate at that precision. R's selection is derivable in closed form (above). G100 is close to r2's G400 prior: the calibration lands near r2's N2-s1 cell (R6), where G400 screened in 24% and froze finalists in 13% of 100 markets. B on 369 extra markets adds 36,900 programs to M, which raises the agent's q from 7.21 (M = 6,604) to 8.21.
- **Fix:** run B on the 33 paired markets only. Keep R on 402 if wanted, as a check of a registered selection prediction; it adds one program to M and costs only compute. Spend the saved truth compute on R1's pairs.

**R6. The registered "S = 1" labels the funding references, while the DSL's plant in this cell is far stronger (changes PC1's framing and what C5 reports).** In the rough model, `raw` and `raw24` tie at about 1 near r2's N2-s1 β (kernel: 0.0292, `data/campaigns/betas.json`). The demeaned references lose about 1.5–2.6 Sharpe to turnover on the ten real-funding noise coins, so with frozen funding the four-reference family is in effect `raw` against `raw24`. In that r2 cell, G400 reached max DSR ≥ 0.9995 at N ≈ 395 in 6 of 100 campaigns (≥ 0.99 in 13) and screened dozens of variants (`mixed.jsonl`). Its top programs are slow cross-sectional momentum (`xs_rank` of the 4-hour high return, EMA 168–336 h): price-side exploitation of the persistent planted drift, with no funding input. So "S1's modest upper illustration" misdescribes the cell. Materiality anchored on R is a low bar for such programs, and a positive agent result will be over-read as recovery of a plausible edge.
- **Fix:** register reporting the best truth net Sharpe of any evaluated program in any arm, as the cell's empirically expressible strength, beside the target. Cite r2 N2-s1's G400 counts as this cell's prior. Register R's predicted selection rate in PC4.

**R7. The account rule checks names, not identities (pass while false, C7).** `ACCOUNTS` maps the names TAMU and Cornell to environment keys. A personal token filed under `CLAUDE_CODE_OAUTH_TOKEN_TAMU` passes any name-based allowlist, and the draft's "identity/source checks" name no mechanism.
- **Fix:** the human records non-secret SHA-256s of the allowed tokens, and the runner checks them before every session, probe and `windows()` call (each is a model call). Also register the series precedent: no other Claude work on an account while a PC session runs on it, because a crash is counted, never replaced. Give the planning minimum: at 0.75/0.07 admission, at most one session per account per five-hour window and 11 per account-week, so 33 sessions need at least about 1.5 weeks on two accounts.

**R8. A simpler deterministic kill barrier (low; C6 implementation).** The verdict can be made deterministic without ptrace: SIGSTOP the owned `mm holdout` on the inotify write to `spent.jsonl`, assert the claim is present and no result committed, then SIGKILL. A lost race fails the test as "barrier missed" and never passes it. This meets the "no sleep/poll race" requirement. Optional.

**R9. Erasure (low; no judged outcome).**
- The paper took on status ("Current priority: finish the bounded thesis refreeze…") and reconciliation history ("supersede A's narrower .50–.58 fit range and B's provisional inventory"). These belong in PROGRESS and decisions.
- The draft still restates PC1–PC6 nearly line for line (round one's F14e, partly answered); C6 duplicates PC5. Many sentences are disclaimers ("not a…, not a…"): keep one scope paragraph.
- `gate/agent/campaigns.py:38`'s comment "the thesis track also draws on Cornell" is stale: the thesis reads `PERSONAL` (`ops/live.py` `WORKLOADS`, `CLUSTER.md`).

## Round one's findings

| | Status |
|---|---|
| F1 confirmation predetermined | Answered: r2 cited, confirmation derived, per-finalist horizons. R6 adds r2's N2-s1 as this cell's direct prior. |
| F2 oracle not an upper bound | Answered in form (four references, max-family calibration, "not an upper bound"); R6: the DSL's best in this cell is momentum, far above the family. |
| F3 truth band | Answered at the cause for unrelated programs (paired contrast); R1 (net-mean band) and R2 (scale) remain. |
| F4 finding 6 | Answered: consumed returns judged, diagnostics a qualification. |
| F5 ±10% tolerance | Answered: removed, achieved CI reported. |
| F6 cost | Answered: nonlinear fits, 0.75 admission, no finite worst case claimed. |
| F7 denied tool | Answered: denied versus executed. |
| F8 pairing | Answered. |
| F9 model-free precision | Overshot: 402 without a decision (R5). |
| F10 n | Answered: decision-sized n = 33, correct arithmetic. |
| F11 sentinel | Answered in words; R3: it tests a path the study does not use. |
| F12 funding | Answered: frozen pre-embargo blob. |
| F13 truth compute | Answered: streamed by market. |
| F14 | (a)–(d) answered; (e) partly (R9); (f) superseded by the unlimited budget. |

## Constructions, per criterion (beyond GPT's own, which hold)

- **C1:** fails while true once the refreeze merges (R4). The fresh ids and content-lineage checks do reject aliasing; `data/agent` has no `pc-*` ids.
- **C2:** no new false pass. Its claim (a validated net-profitable alternative exists) survives R6, which is about labeling. Validation should also check certifiability at truth's q (R1).
- **C3:** if the study reused `both_arms`, a denied `Edit` would stop a market before B, which C3 counts as a procedure pass. R3's arm-agnostic path must not inherit that exit.
- **C4:** fails while true twice: the half-size reference (R2), and a plant variant at true S = 0.4 (R1).
- **C5:** power collapses under R1's ambiguity, and R5 inflates M.
- **C6:** passes while false when the study's own composition loses a result (R3).
- **C7:** passes while false on a misfiled personal token (R7).

## Checked and sound

- The design check reproduces exactly: 33/12, 402, M = 43,906, 1,756,240 replays, q = 8.210; $43.63 and 2.838 windows; 100-turn $84–87 and 44–50 points; 200-turn $304–349 and 155–198 points.
- The search-window Sharpe SE (0.81 analytic, 0.76 in the rough model) is right.
- The funding blob is search-era. No holdout, embargo or forward-window input is used, and no spent evidence is reused: r2 is cited as prior only.
- Paired planted and zero markets share the generator seed: `generate` draws are independent of β, and β enters only `eps`.
- The kernel pin is named and its reproduction stated.
- Using the unlimited budget only on TAMU and Cornell matches the human's decision. `ACCOUNTS` already excludes `PERSONAL`, which the thesis uses alone.
