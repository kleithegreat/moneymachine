# Brief 6: Study 1 Offline Diagnostic, Unhinted Cell 2, and Agent DSL Surface A/B

Written 2026-11-25 02:35 UTC (2026-11-24 21:35 EST). Reopens **A DSL designed for agents** (`docs/future-work.md`; `audit/reviews/2026-11-08-sonnet-research-dsl.md`) alongside **Study 1 Cell 2 (Unhinted Plant)** (`docs/whitepaper.tex`, Section "Study 1").

## 1. Motivation & Observed Gap

Study 1 (`audit/control-1/report.md`, `audit/control-1/results.jsonl`) crossed its sequential upper boundary at market 43 (`18/43` agent wins vs `7/43` G100; `15` agent-only vs `4` G100-only discordant wins). However, inspecting `results.jsonl` exposes a striking gap:
- The brief named **funding dislocations**, and `kernel/DSL.md` opened at line 10 with `fade-extreme-funding` (the exact shape of the planted drift).
- Even with that explicit hint, the 42 completed `claude-opus-5-5` sessions **failed on 24 of 42 markets** (57.1%) and stopped on their own after only **5 to 16 evaluations (median 9.5)** out of a 100-evaluation budget!
- Across those 24 failures in `audit/control-1/results.jsonl`: 8 final picks read `close` alone, 4 read `funding` alone, 10 mixed `funding` with `close`/`open`/`volume`, and 2 read `premium` (`+ close`). Meanwhile, Stage 4 (`audit/stage4/null-summary-v3.json`) recorded 11 of 208 wasted evaluations on `R_INPUT_UNAVAILABLE` because `DSL.md` advertised `forum_posts` and `gov_proposals` that N2 lacked.

Before running new LLM campaigns, Part A runs a **zero-cost offline diagnostic** on Study 1's kept data; Part B tests **unhinted discovery (Cell 2)** and an **agent-facing DSL surface A/B** at equal budget with identical kernel semantics.

---

## 2. Part A: Zero-Cost Offline Diagnostic of Study 1 (`audit/control-1/` + Kept Sessions)

**Goal:** Measure *why* `claude-opus-5-5` stopped at median 9.5/100 evaluations and failed 24/42 markets despite the `DSL.md` hint, without spending API budget.

**Inputs (read-only):**
- `audit/control-1/results.jsonl`, `searcher.jsonl`, `manifest.json`, `report.md` (already on `main`).
- The 42 kept per-market agent ledgers and transcripts from the archived Study 1 run store (`audit/reviews/2026-11-22-opus-study1-evidence.md`).

**Measurements to compute (implemented in OCaml, zero new Python):**
1. **Per-evaluation trajectory ($m = 1 \dots 42$):**
   - Count of `mm check` calls (valid vs syntax/unit error codes), `mm eval` calls (`eval` vs `abort` reason codes), duplicate canonical equivalence keys, and `sharpe_annualized` trajectory across evals $1 \dots k$.
   - Compare each session's *best intermediate* program against its *picked* program: on the 24 failing markets, did the agent evaluate an earning program (e.g., a clean `funding` fade) and **abandon it** for a higher in-sample-Sharpe `close` noise fit, or did it **never evaluate** a clean `funding` program?
2. **Failure-mode taxonomy for the 24 failing picks:**
   - **Sign / direction error** (long high funding instead of short),
   - **Threshold / scaling error** (e.g., copying `DSL.md`'s `thr = 0.0001` threshold when the plant scales around `1.25e-5 ± 1e-4` or over-filtering so trades rarely fire),
   - **Noise takeover** (mixing `close`/`open`/`volume` lags that score higher in-sample Sharpe on the 550-day search slice than simple `funding` fades),
   - **Syntax / missing-input friction** (`check` errors, `R_INPUT_UNAVAILABLE`, `prediction.condition` range rejections).
3. **Early-stopping audit:**
   - Classify final transcript turns before exit: stopped because an in-sample Sharpe threshold was satisfied, stopped because `brief.md` warned *"Many weak variants of one idea hurt you"*, or stopped after exhausting idea diversity.

**Deliverable & Exit Gate:** Write `audit/control-2/study1-diagnostic.md` (never modifying `audit/control-1/`). Use its empirical findings to finalize the V1 surface treatments in Part B **before** locking Cell 2 criteria (ensuring Part B fixes measured friction rather than guessed friction).

---

## 3. Part B: Study 1 Cell 2 (Unhinted Plant) + Agent DSL Surface A/B

### 3.1 Core Design Principles (`audit/reviews/2026-11-08-sonnet-research-dsl.md`)

1. **Identical kernel semantics:** Every strategy authored on the improved surface (`S1`) compiles deterministically to the **exact same canonical JSON AST** before kernel evaluation, hashing, canonicalization, and statistical gating. No new kernel operators, no learned parameters, no state changes (`hold` compiles to undefined weight), and no change to execution or null Type-I control.
2. **Kernel v2 execution (`A16` bar mode):** Since `archive/pilot` (`mm`) is retired from new work, Cell 2 runs in Kernel v2 (`A16` derived bar-and-funding synthetic markets) on Lean 4 + OCaml, reproducing the Study 1 twin-pair methodology (`57` fresh pairs per market, `39/57` majority rule, `5` model-free walls before any agent session).
3. **Model & provider pinning:** Pin one explicit model checkpoint (e.g., `claude-opus-5-5` or non-Anthropic API model via `mm2-agent`) with strict single-model enforcement (any fallback/mismatch logged and scored per manifest rule) and full synchronous transcript recording.

### 3.2 Unhinted Plant Family (Cell 2)

- **Strict no-hint condition:** The plant MUST **not** be named in `brief.md` and MUST **not** appear in `DSL.md` or any example corpus. Furthermore, the plant MUST **not** depend on `funding` or `premium` (which Study 1's agent already anchors on from crypto priors).
- **Candidate synthetic plant (verified via Prototype-Before-Spec):**
  - Generate synthetic N2-style GARCH markets with zero funding drift and plant a known, reversible signal in **price/volume** dynamics across 6 of 12 coins — for example, a **24h-volume-conditioned 4h/12h cross-sectional return reversal** (`-sign(xs_demean(close / lag(close, 12) - 1))` scaled when `volume / mean(volume, 168) > 1.2`, or a volatility-scaled cross-sectional intraday range-reversion signal using `high`, `low`, `close`, `volume`).
  - **Brief & examples:** `brief.md` states only the market mechanics, available inputs, and budget — zero mention of reversal, volume conditioning, or funding dislocations. `DSL.md` examples show purely mechanical plumbing (a dummy constant-zero/neutral unit-conversion and `xs_demean` wiring snippet, zero economic strategy examples).
- **Pre-run calibration & 5 model-free walls (same as Study 1):**
  1. Twins identical outside planted coins' returns/GARCH variance.
  2. Locked reference program wins positive effect on $\ge 95\%$ of `10,000` check-market pairs.
  3. Five mirror pairs' even parts pass Wall 3 ($\le 4/200$ earns).
  4. Bisection on `1,600` markets + check on `10,000` fresh markets calibrates plant strength $\beta$ so **G100 earns at rate $0.15 \pm 0.005$** (check band $[0.12, 0.18]$).
  5. Wall 5: constant long and constant short earn $\le 14/200$ markets (and include a plain 1-bar momentum/reversal blind screen check beside constant positions so trivial non-interactive rules cannot pass silently).

### 3.3 Microbenchmark First (Zero Market Data, Cheap)

Before launching paid planted-market campaigns, run a **200-task blind microbenchmark** comparing baseline JSON (`S0`) vs improved surface (`S1`) on fixed English strategy specifications (covering units, time conversions, `lag`/`ema`/`xs_rank`, `hold` semantics, and available vs unavailable inputs):
- Metrics: first-try `mm2 check` pass rate, wasted-input / `R_INPUT_UNAVAILABLE` count, tokens to first valid AST, and exact round-trip canonical JSON equivalence (`S1` AST == reference `S0` AST).
- **Gate:** `S1` proceeds to live Cell 2 A/B only if it beats `S0` on first-try valid rate and eliminates `R_INPUT_UNAVAILABLE` in the microbenchmark.

### 3.4 Experimental Arms & Comparisons (Budget = 100 Evaluations Each)

| Arm | Surface & Brief | Budget | Kernel / Semantics |
|---|---|---|---|
| **G100** | Random + genetic searcher over identical AST | 100 evals | Kernel v2 `A16` |
| **S0** (Baseline Unhinted) | Pilot JSON DSL (`DSL.md` verbatim minus `fade-extreme-funding` hint; raw `mm2 check` errors) | 100 evals | Kernel v2 `A16` |
| **S1** (Agent DSL Surface) | Improved surface: (1) free `mm2 inputs` catalog, (2) manifest-aware `mm2 check` with offending AST path + unit hints, (3) compact infix/S-expr authoring syntax compiling 1-to-1 to canonical JSON + explicit `hold` alias, (4) neutral plumbing examples, (5) calibrated stopping guidance (do not exit at eval 9 on vague anxiety; explore distinct canonical ideas up to budget 100) | 100 evals | **Identical** canonical JSON + Kernel v2 `A16` |

**Complete-null non-regression check (`S1` vs `S0`):** Run 20 simulated complete-null markets per arm under the exact statistical gate (`DSR` + `SPA` + `Romano-Wolf` + single-shot holdout) to verify that higher budget utilization under `S1` does not inflate false promotions (expected: `0/20` promotions in both arms; secondary: report actual `evaluations` spent and distinct canonical keys `N`).

## 4. Sequential Inference & Power Budget

- **Paired sequential design (max 100 markets, manifest-seeded):** On each market $m = 0 \dots 99$, run **G100**, **S0**, and **S1** on the same planted market seed (in independent isolated sessions with no shared memory) and score each arm's highest-Sharpe pick on $m$'s 57 fresh twin pairs.
- **Two pre-registered Wald SPRT tests ($\alpha = 0.025$ each, $\pm \log 39 = \pm 3.6636$, family-wise worst-null size $\le 0.05$ by Bonferroni):**
  1. **Hypothesis H1 (Unhinted Capability: S0 vs G100):** $\theta \le 1/2$ vs $\theta = 0.7$ on markets discordant between `S0` and `G100` (11 straight wins claim; 6 straight losses stop — exact integer bounds checked in `Ref/Study1.lean` generalized to threshold 39).
  2. **Hypothesis H2 (Surface Effect: S1 vs S0 at equal 100-eval budget):** $\theta \le 1/2$ vs $\theta = 0.7$ on markets discordant between `S1` and `S0`.
- **Expected run length & early stop:** At $\alpha = 0.025$, 11 discordant wins cross `claim`; if `S0` earns at `0.15` (no better than `G100` without hints) and `S1` earns at `0.40–0.50`, H2 resolves in roughly 30–50 markets, while H1 hits futility (`not shown`) or stays undecided. Both arms run on the same market sequence; each test stops independently at its own boundary, and neither extends past 100 markets.

## 5. Draft Pre-Registered Criteria (Committed After Part A + Microbenchmark)

- **CS3.1 (Unhinted capability, S0 vs G100):**
  - *Claim:* On unhinted synthetic markets carrying a planted signal absent from the brief and guide, the baseline-surface agent ends on a program earning from the plant more often than G100's 100 evaluations.
  - *Judged by:* Exact-integer Wald SPRT ($\theta \le 1/2$ vs $\theta = 0.7$, $\pm \log 39$, $\alpha \le 0.025$, cap 100 markets).
  - *Met / Otherwise:* Met at upper boundary; `"not shown"` at lower boundary; `"inconclusive"` at 100 markets (never `"no better"`).
- **CS3.2 (Agent DSL surface, S1 vs S0):**
  - *Claim:* Under identical canonical kernel semantics, kernel `A16`, and 100-evaluation budget on unhinted synthetic markets, the improved agent-facing surface (`S1`) ends on an earning program more often than the baseline surface (`S0`), while recording zero null-market false promotions across 20 complete-null smoke markets.
  - *Judged by:* Exact-integer Wald SPRT ($\theta \le 1/2$ vs $\theta = 0.7$, $\pm \log 39$, $\alpha \le 0.025$, cap 100 markets) plus null-smoke gate check (`0/20` promotions on complete nulls).
  - *Secondary (reported, not judged):* Mean/median evaluations used, wasted `check`/`eval` rejections, `R_INPUT_UNAVAILABLE` count, distinct canonical equivalence keys per session, and equal-evaluation G100 score.
  - *Not claimed:* Real-market edge; optimality over all DSL syntaxes; performance on models outside the pinned manifest checkpoint; or that surface improvements reduce true statistical multiplicity (tracked explicitly via $N$ and null smoke).
