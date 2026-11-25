# Brief 5: Earlier-Cutoff LLM Research Arm

Written 2026-11-25 02:35 UTC (2026-11-24 21:35 EST). Ready-to-run study design for an earlier-cutoff LLM research arm (`docs/whitepaper.tex`, Section "How the wall moves"; `docs/future-work.md`), running in parallel with unhinted synthetic search (`briefs/6-unhinted-search-dsl.md`) rather than blocked behind Study 2.

## 1. Objective & Wall Arithmetic

Under the leakage-control policy, a model's proposed strategy is judged only on market data strictly after the model's verified knowledge cutoff plus a safety margin. Frontier 2026 models face a months-long post-cutoff span, placing 80%-power confirmation at annualized Sharpe ~5.0 (fixed horizon) to ~5.9 (exact Kelly sequential test) or 27.6 (pilot $L=2$ saturated half-stake) at 91 days.

Selecting a model with verified knowledge cutoff **$\le$ 2024-06-30** plus a **$\ge$ 3-month margin** (post-cutoff boundary `2024-10-01 00:00 UTC (2024-09-30 20:00 EDT)`) unlocks **760 days (> 2.08 years)** of untouched pre-embargo Hyperliquid history (`[2024-10-01, 2026-10-31)` UTC), strictly before the `[2026-11-01, 2027-01-31)` forward window. With Kernel v2's exact sequential confirmer using the rule's own derived loss bound (Section 3.2), the 80%-power Sharpe benchmark drops from **~5–27.6 down to ~2.07** with **zero calendar wait**.

**Threat model & workflow rules (`CLAUDE.md`):** Honest-but-buggy threat model; Prototype-Before-Spec before committing criteria; zero new Python (`python-left` ratchet preserved — harness, readers, and orchestrator in OCaml + Lean 4 + Nix); bounded review protocol (< 50 KB bundles, max 2 rounds).

## 2. Model Selection & Cutoff Verification Protocol

1. **Candidate requirements:**
   - Documented training/knowledge cutoff **$\le$ 2024-06-30** in official vendor model cards or release technical reports (e.g., mid-2024 open-weights checkpoints served locally or pinned API snapshots with immutable checkpoint IDs).
   - **Zero tool/retrieval leakage:** no web search, external retrieval, or unlogged fallback. API requests disable all server-side tools; sandbox blocks egress except the pinned model endpoint (or local model server).
   - **Per-turn model identity enforcement:** every assistant response logs its returned `model` field. Any response naming a model ID outside the registered manifest immediately marks the session invalid (no silent upgrade to a newer model).
2. **Pre-run Cutoff Canary Battery (must score 0 leaks before launch):**
   - Run a 20-item probe testing post-`2024-06-30` public facts that affect perpetual futures or crypto macro (specific post-2024-06 Hyperliquid token listings/delistings such as FTM migration, exact post-2024-06 funding spike dates, and macro/venue events from `2024-07` to `2026-10`).
   - Acceptance: **0/20** post-cutoff recall above blind guessing; any model demonstrating post-`2024-06` recall is disqualified before touching search data.

## 3. Data Split, Feeds, and Exact Confirmer

### 3.1 Split & Protected-Window Hygiene

| Window | Dates (UTC / Eastern) | Span | Role & Access Rule |
|---|---|---|---|
| **Universe formation** | `2023-05-12` to `2023-05-31` | 20 d | Point-in-time top-volume Hyperliquid perps listed prior to `2023-05-12` (delisted coins kept; check coverage in Prototype 0) |
| **Search (selection)** | `[2023-06-01 00:00 UTC (2023-05-31 20:00 EDT), 2024-06-30 00:00 UTC (2024-06-29 20:00 EDT))` | 395 d | Agent explores via `mm2 eval` (100-eval budget, search-period Sharpe/fills/return/drawdown only) |
| **Cutoff buffer** | `[2024-06-30, 2024-10-01)` | 93 d | Unused embargo margin (>= 3 months past max model cutoff `2024-06-30`) |
| **Holdout (inference)** | `[2024-10-01 00:00 UTC (2024-09-30 20:00 EDT), 2026-10-31 00:00 UTC (2026-10-30 20:00 EDT))` | **760 d** | **Untouched, single-use.** Evaluated once in one frozen batch for frozen finalists; never opened before freeze; never touches `[2026-11-01, 2027-01-31)` |

*Alternative pure-post-cutoff split (secondary/sensitivity check, only if Prototype 0 shows universe turnover in 2023–2024 makes `2023-06` too thin):* form universe over `2024-09`, search on `[2024-10-01, 2025-04-01)` (182 d), and hold out `[2025-04-01, 2026-10-31)` (578 d = 1.58 yr, exact Kelly 80%-power Sharpe ~2.3). Primary preference is the 760-day holdout above because selection on pre-cutoff data cannot inflate the post-cutoff holdout Type-I error rate.

### 3.2 Certified Feeds & Execution Model (Kernel v2)

All feeds bind under existing certificates in `venue/sources.toml`:
- **Funding & Premium:** Hyperliquid `fundingHistory` (`2023-05-12` onward, delisted coins included; `knownAt = max(hour + 120s, reportedTime + 60s)`).
- **Bars & Price Series:** Hyperliquid `candleSnapshot` (`4h` bars rolling 5,000 candles cover `2024-07-08` onward; `1d` bars back to `2023`) and/or 4h bars reconstructed point-in-time from certified `s3://hyperliquid-archive/market_data/<YYYYMMDD>/<hour>/l2Book/<COIN>.lz4` (5-second L2 books back to `2023-04-15`: 13 coins on `2023-04-15`, 134 on `2024-06-01`, 198 on `2025-06-01`, `$0.09/GB` within the approved `$20` budget — ~$17.54 remaining or ~$2–5 for sparse/4h-boundary snapshots; list exact bytes before download per `venue/sources.toml`).
- **Optional certified exogenous feeds** (only if coverage spans `2023-06..2026-10` with certified availability): `[ecb]`, `[bis]`, `[sec]` (only where timestamped release proves `knownAt`). Prospective-only feeds (`bls`, `discourse`, `snapshot`) are excluded.
- **Evaluator & Confirmer (`Kernel v2`):**
  - Run in Kernel v2's `A16` bar-market mode (`audit/program/kernel-v2.md`, assumptions `B1`–`B5` registered and hashed before search, with half-spread `h` calibrated conservatively from `s3://hyperliquid-archive` 2023–2024 pre-holdout L2 books) so full 2-year replays run in seconds on one thread without needing 180+ GB of `node_fills_by_block` transfers.
  - **Rule's own loss bound (no $L=2$ gate saturation):** Strategies run unlevered (`gross_leverage <= 1`, cash/isolated exposure) or under an explicit stop-out bound $L_t$ proved by construction in Lean (`Engine.Ledger`), staking predictable capped plug-in Kelly $\lambda_t \in [0, 1/L_t]$ (or fixed Kelly fraction registered before holdout for target Sharpe 2.0, avoiding the pilot's saturated half-stake penalty). Holm's correction controls family-wise error across the frozen finalist batch at $\alpha = 0.05$.

## 4. Lightweight OCaml Non-Anthropic / API Harness Sketch

Zero Python (`python-left` ratchet respected). Build as a small Dune library/binary (e.g., `harness/` or `kernel2/ocaml` subcommand `mm2-agent`) reusing `recorder/` patterns:

1. **HTTP/TLS Client (`libcurl` + `jsont`/`yojson` + `Async`):**
   - Stateless `POST` via `Curl` (`In_thread.run`, TLS verified, 60 s timeout, zero silent fallback) supporting OpenAI-compatible (`/v1/chat/completions`) and local vLLM/llama.cpp endpoints with pinned `model`, `temperature = 0`, and `tools` restricted strictly to `check_strategy`, `eval_strategy`, `list_inputs`, and `submit_finalists`.
   - Every API turn, tool call, and raw `model` identifier is appended synchronously to `transcript.jsonl` (fsynced before returning tool output, eliminating Study 1's buffered-transcript hazard).
2. **OS Confinement (`bubblewrap`):**
   - Agent workspace `/work` contains only `brief.md`, `DSL.md` (or S1 surface), and agent-written strategy files.
   - A single local evaluation IPC socket/CLI talks to an outside-sandbox `mm2` daemon holding the search store and SQLite append-only ledger (`UPDATE`/`DELETE` triggers active; holdout window `[2024-10-01, 2026-10-31)` physically absent from the search store and blocked by `A13` protected-window admission).
3. **Budget & Multiplicity Accounting:**
   - Hard cap of 100 evaluations (`mm2 check` free; `mm2 eval` decrements budget and commits to ledger before returning search Sharpe, fills, total return, max drawdown). Up to 10 frozen finalists passed to one-shot `mm2 holdout`.

## 5. Prototype-Before-Spec Plan (Run Before Freezing Criteria)

Execute a 1-day prototype before locking criteria or launching campaigns:
1. **Archive & `candleSnapshot` coverage check:** verify exact coin count and missing-hour rates for top-12 `2023-05` and `2024-09` Hyperliquid perps over `2023-06-01..2026-10-31`, confirm `candleSnapshot` 4h bar availability before Jan 2027 rolling expiry, and estimate exact S3 byte cost for pre-holdout L2 half-spread calibration.
2. **Model canary probe:** verify 1–2 candidate models (`cutoff <= 2024-06-30`) pass 0/20 post-cutoff canary recall.
3. **OCaml harness smoke:** run 1 complete session on a synthetic `A16` market through `mm2-agent` + `bwrap` + `mm2` daemon to confirm latency, transcript completeness, and zero Python dependencies.

## 6. Honest One-Way Inference & Qualifications

Every report from this arm must state these limits explicitly beside any result:
- **One-way inference:** A confirmed finalist ($p_{\text{Holm}} \le 0.05$ on `[2024-10-01, 2026-10-31)`) demonstrates that an earlier-cutoff LLM agent + Kernel v2 confirmer can discover and confirm a post-cutoff edge over a 2-year horizon. **A non-confirmation or search failure proves nothing against frontier (2026) models**, whose capabilities differ substantially.
- **Designer hindsight:** Even when the model knows nothing past `2024-06`, the 2026 human researcher chose the venue (Hyperliquid, knowing it remained liquid through 2026), the universe rule, the strategy language, and the family framing in the brief. That hindsight cannot be removed by an older model cutoff.
- **Bar-market execution assumptions:** Replaying `A16` derived bars rests on assumptions `B1`–`B5` (constant calibrated half-spread, depth at extremes, path ordering) rather than recorded L2 order books and prints across all 760 days.
- **Single-use holdout:** Opening `[2024-10-01, 2026-10-31)` spends that holdout window for the `<= 2024-06` cutoff epoch; no revised strategy may retest on it.

## 7. Draft Pre-Registered Criteria (Not Committed Until Prototype Completes)

- **Gate readiness (test suite, not criterion):** `mm2` `A16` laws (`L1`, `A1`, `K1`/`K3`, `C1`, `C2`), `A13` holdout rejection test, canary 0/20 leak, and complete null calibration on synthetic `A16` series (empirical Type-I error $\le 0.05$ on 20,000 simulated conditional-null paths).
- **CEC.1 (Earlier-cutoff holdout confirmation):**
  - *Claim:* On Hyperliquid perpetual futures over the untouched post-cutoff window `[2024-10-01, 2026-10-31)` UTC, at least one strategy frozen by the earlier-cutoff agent from search on `[2023-06-01, 2024-06-30)` passes the exact sequential confirmer under the rule's own derived loss bound and Holm's correction across the frozen finalist family.
  - *Judged by:* One-shot `mm2 holdout` run of all frozen finalists (`<= 10`) simultaneously, computing exact supermartingale wealth $K_t = \prod_{s \le t} (1 + \lambda_s r_s)$ with predictable $\lambda_s \in [0, 1/L_s]$ and Holm-adjusted $p_i = \min(1, 1/\max_t K_{i,t})$.
  - *Met when:* At least one frozen finalist achieves terminal net wealth $> 1$ AND $p_{\text{Holm}, i} \le 0.05$.
  - *Otherwise:* Reported as `"not confirmed"` (never `"no edge"` and never `"frontier models fail"`), together with every finalist's terminal wealth, $\max K$, realized Sharpe, and volatility.
  - *Passes while false:* By chance, at most $0.05$ across the frozen family if conditional null $\E[r_{i,t} \mid \mathcal{F}_{t-1}] \le 0$ and pre-absorption loss $\ge -L_t$ hold and the model had zero post-`2024-06` leakage; negated if venue `A16` bar assumptions overstate real fill quality or if the model leaked post-cutoff patterns.
  - *Fails while holds:* High false-negative probability if the true edge has annualized Sharpe $< 2.0$ (under ~2.08 years, exact Kelly 80% power sits near Sharpe 2.07), if the earlier-cutoff model fails to find an edge during search, or if execution spread assumptions are overly conservative.
  - *Not claimed:* Real live trading profitability; capability bounds on frontier 2026 models; validity beyond Hyperliquid `A16` bar assumptions; or freedom from designer hindsight in venue/brief selection.
