# Positive-control study design, round three, review by Gemini 4 Argon (web UI), 2026-11-09 17:07 UTC (12:07 EST)

Reviewer: Gemini 4 Argon in the Gemini web UI, read-only. Bundle: `~/Downloads/argon-review-positive-controls.md`, built by the advisor from `positive-controls` at `999ccb1`: the paper's positive-control section (lines 523-585), `audit/positive-controls-criteria-draft.md`, `audit/positive-controls-design-check.py.txt`, and the second Opus review as context. Builder of round three: Claude Opus. Reply verbatim below, as the human pasted it.

---

### Verdict

**Commit the criteria after fixes (no full redesign needed).**

Round 3 resolved the cohort sizing ($n = 33, k = 12$), removed the unconsumed 369 model-free markets ($M = 6,607$), unified the three-arm release function signature, and added token-hash checks. However, **eight defects remain** that alter pass/fail outcomes, break decision power on price-conditioned programs, allow zero-funding price-momentum strategies to pass as "material plant recovery," or permanently deadlock execution:

1. **R1/R6 gap in `PC4` / `PC.C4` (Pass while false):** The truth assay defines recovery by $\mathbb{E}[m^+_p] > 0$ and $\mathbb{E}[h_p] > 0$ comparing $\beta > 0$ against $\beta = 0$. Because $\beta > 0$ injects persistent drift into coin 0 and 1 **prices**, slow cross-sectional price-momentum programs with **zero funding inputs** (which R6 showed G400 finds in 24% of N2-s1 markets at $\text{DSR} \ge 0.9995$) have $\overline{r^+} \gg 0 \ge \overline{r^0}$ and $G_p \approx 2.0\text{--}3.0 \gg G_R/2$. They are certified as "material recovery of the hinted funding plant" without ever reading funding.
2. **CRN breakdown & planning SD underestimation in `PC4` / `PC.C5` (Fail while true):** The planning $\text{SD}(h) = 0.15$ comes from static funding-only references where positions are identical on planted and zero twins ($w^+_{k,c} \equiv w^0_{k,c}$), canceling background noise $\sigma_{k,c} x_{k,c}$. Any agent program that conditions on price, returns, drawdown, or equity-rounded $\$10$ order minimums has $w^+_{k,c} \ne w^0_{k,c}$ after the first diverged bar; uncancelled background noise pushes $\text{SD}(G_p)$ to $0.35\text{--}0.50$, collapsing truth certification power at $\rho = 0.62$ from $0.995$ to $< 0.05$ and forcing `PC.C5` into "unresolved."
3. **Denominator asymmetry in $G_{pj}$ in `PC4` / `PC.C4` (Pass while false):** $G_{pj} = \sqrt{2190}(\overline{r^+} - \overline{r^0})/\operatorname{sd}(r^+)$ divides by $\operatorname{sd}(r^+)$ alone. A program that is quiet when return dispersion is high ($\beta > 0$, tiny $\operatorname{sd}(r^+)$) and churns fees when dispersion is low ($\beta = 0$, large negative $\overline{r^0}$) inflates $G_{pj}$ arbitrarily without capturing the plant.
4. **Unnormalized $m^+_{pj}$ vs. Sharpe power derivation, plus normal-for-$t$ bug in `PC2` / `PC4` (Fail while true):** `PC4` sizes $n = 69$ assuming a test on annualized Sharpe ($\text{SD} = 0.5$), but actually tests raw mean return $m^+_{pj} = \overline{r^+}$, which is unnormalized for cross-market GARCH volatility variance. Worse, `design-check.py` line 66 computes validation failure at $q_{19} = 7.21$ using `stats.norm.cdf` ($1.09 \times 10^{-4}$) instead of `stats.nct.cdf` at $\text{df} = 19$, understating the probability of permanently bricking the study at validation by **$100\times$** ($\approx 1.1\%$ at $S = 1.0, \text{SD} = 0.41$, and $\approx 5\%$ at $S = 0.90$).
5. **Admission ceiling deadlock in `PC6` / `PC.C7` (Fail while true):** `PC6` enforces a $0.80$ window ceiling while reserving $\max(\text{measured\_max}, 0.75)$ per session. If a single 200-turn session ever uses $> 0.80$ of a 5-hour window, $\text{measured\_max} > 0.80$ forever, so $0 + \text{reservation} > 0.80$ on every idle account—permanently deadlocking the runner.
6. **Asynchronous `inotify` + `SIGSTOP` race in `PC5` / `PC.C6` (Fail while true) and single-arm forced fixture (Pass while false):** `inotify` notifies the Python watcher asynchronously *after* the compiled Rust `mm holdout` child finishes its `write()` syscall; `mm holdout` continues executing on its CPU core and can commit the 360-step result before Python wakes and delivers `SIGSTOP`, triggering an unrecoverable "barrier missed" failure. Meanwhile, `pc-v3-release` forces only `R` (with `A` stubbed), never testing cross-arm shared-program deduplication/fan-out or multi-finalist Holm step-down.
7. **Brittle fifth-size assay control ($0.02u$) exit gate in `PC4` / `PC.C4` (Fail while true):** `PC.C4` makes certified recovery of the $0.02u$ control ($T > 5.449$) a mandatory exit condition, verified only in the numpy rough model. If calibration selects `raw24` or `d24`, 4-hour step weight changes $\Delta w = 0.02 \Delta u \le 0.001$ fall below the kernel's $\$10$ minimum order and lot rounding, risking $T_h \le 5.449$ and blocking study exit even when all 33 agent runs succeed.
8. **Negative/singular confirmation horizon $g$ in `PC4` / `PC.C5` and static OAuth token hashes in `PC6` / `PC.C7`:** The horizon formula $g = \mu/2 - (v^2 + \mu^2)/8$ assumes fixed betting fraction $\lambda = 1/2$ on unnormalized returns; for any recovered finalist with $S = 0.6, v > 0.055$, $g \le 0$, yielding a negative or division-by-zero horizon. Pinning raw OAuth bearer token SHA-256s breaks mid-campaign when TAMU/Cornell tokens auto-refresh over the 1.5–3 week run.

---

### 1. Independent Arithmetic & Statistical Verification

All exact numbers in `audit/positive-controls-design-check.py.txt` reproduce as written, with three statistical discrepancies noted below:

* **Cohort sizing ($n = 33, k = 12$):**
* Null size at $p_0 = 0.20$:

$$P(X \ge 12 \mid \operatorname{Bin}(33, 0.20)) = \sum_{x=12}^{33} \binom{33}{x} 0.2^x 0.8^{33-x} = 0.0215906 \le 0.025.$$



(At $k = 11$, $P_{0.2}(X \ge 11) = 0.05084 > 0.025$.)
* Power at $p_1 = 0.50$:

$$P(X \ge 12 \mid \operatorname{Bin}(33, 0.50)) = 1 - \frac{344{,}173{,}412}{2^{33}} = 0.959933 \ge 0.95.$$


* Minimality of $n = 33$: At $n = 32$, $k = 11$ violates size ($P_{0.2}(X \ge 11) = 0.0411 > 0.025$) and $k = 12$ violates power ($P_{0.5}(X \ge 12) = 0.94991 < 0.95$). At $n = 16$, the smallest valid cutoff is $k = 8$ ($P_{0.2}(X \ge 8) = 0.0147$), giving $P_{0.5}(X \ge 8) = 0.59819 \approx 0.598$.


* **Multiplicity $M = 6{,}607$ and critical values $q$:**
* $M = 33 \times 100\text{ (A)} + 33 \times 100\text{ (B)} + 4\text{ (references)} + 3\text{ (controls)} = 6{,}607$.
* Four tails per program ($m^+_p$ and $h_p$, upper and lower) at family error $0.01$ give per-tail $\alpha = \frac{0.01}{4 \times 6{,}607} = 3.78387 \times 10^{-7}$.
* For truth ($n = 69, \text{df} = 68$): $q = t_{68,\,1 - 3.78387 \times 10^{-7}} = 5.4491$.
* For validation ($n = 20, \text{df} = 19$): $q_{19} = t_{19,\,1 - 3.78387 \times 10^{-7}} = 7.2100$.


* **Truth certification power & materiality floor $\rho \ge 0.62$:**
* Solving $P(\operatorname{Bin}(33, 0.5\pi) \ge 12) = 0.95$ gives $\pi_{\min} = 0.98188 \approx 0.982$. Setting $\pi = 0.99$ gives decision power $0.95473$ and per-condition power $0.995$.
* Under noncentral-$t$ with $\text{df} = 68$ and $d = S^*/\text{SD} = 0.5 / 0.5 = 1.0$, noncentrality is $\delta = \sqrt{69} = 8.3066$, giving $P(t_{68}(8.3066) > 5.4491) = 0.9951 \ge 0.995$ (whereas $n = 68$ gives $0.9943 < 0.995$).
* Exact standardized effect for $0.995$ power at $n = 69$ is $d_{\min} = 0.9959$. With $\text{SD}(h) = 0.15$, the required margin is $0.9959 \times 0.15 = 0.1494$, so $(\rho - 0.5)G_R \ge 0.1494$ at $G_R = 1.2$ yields $\rho \ge 0.5 + 0.1494/1.2 = 0.6245 \approx 0.62$.


* **Reference selection prediction & confirmation algebra:**
* Search SE over $3{,}300$ steps is $\sqrt{2190/3300} = 0.81465 \approx 0.815$. At $N = 1$, $\Phi(1.0/0.81465 - 1.64485) = \Phi(-0.4173) = 0.3382$; at $S = 0.5$, $\Phi(0.5/0.81465 - 1.64485) = 0.1512 \approx 0.15$.
* At $v = 0.01, \mu = 0.01/\sqrt{2190} = 2.1369 \times 10^{-4}$, $g = \mu/2 - (v^2 + \mu^2)/8 = 9.4338 \times 10^{-5}$, so $\log(20)/g = 31{,}755.4\text{ steps} = 14.50\text{ years}$.


* **Three arithmetic/statistical errors in the script and text:**
1. **Normal-for-$t$ bug on line 66 of `design-check.py`:** Line 66 computes `validation_failure_at_S1_sd041` via `stats.norm.cdf(tail(m, 19) - 1 / (0.41 / np.sqrt(20)))` $= \Phi(7.210 - 10.907) = 1.09 \times 10^{-4}$, ignoring sample variance uncertainty in the denominator of $t_{19}$. Using `stats.nct.cdf(7.210, 19, 10.907)` (matching line 24's `power()`), the true failure probability is **$0.0112$ ($1.12\%$, $103\times$ higher)**—and **$4.8\%$** if true net Sharpe at the grid point is $0.90$.
2. **Shared truth-bank correlation across the 33 markets:** Writing $\operatorname{Bin}(33, 0.5\pi)$ assumes truth certification indicators across the 33 markets are independent. Because all 33 markets are judged on the **same** 69 truth pairs (and the **same** deterministic funding blob `d07162b8...`), if Agent A discovers the same borderline variant ($S \approx 0.5$) in 16 markets, those 16 certifications have correlation $\approx 1$: they pass or fail as a single Bernoulli draw, reducing effective decision power at the floor from $0.955$ to $\approx 0.982$ (if identical) or creating correlated cluster drops.
3. **Planning SDs ($\text{SD}(S) = 0.5, \text{SD}(h) = 0.15$) are only defensible for static funding-only weights:** Because all 69 truth pairs reuse the identical funding series $f_{4k-4,c}$, a purely funding-driven reference has $w^+_{k,c} \equiv w^0_{k,c}$, so background noise $\sigma_{k,c} x_{k,c}$ cancels in $\overline{r^+} - \overline{r^0}$. For any strategy whose weights depend on prices, returns, volatility, or equity-rounded $\$10$ order minimums, $w^+_{k,c} \ne w^0_{k,c}$, uncancelled noise enters $\overline{r^+} - \overline{r^0}$, and $\text{SD}(h)$ jumps to $0.35\text{--}0.50$.



---

### 2. Ranked Findings (with Constructions and Outcomes Changed)

#### F1 (High — `PC4`, `PC.C4`, `PC.C5`): Price-only momentum passes $m^+_p > 0$ and $h_p > 0$ without using funding (Pass while false)

* **Mechanism:** The plant $\beta a_{k,c}\mathbf{1}_{c \in \{0,1\}}$ injects autocorrelated funding drift directly into coin 0 and 1 returns $\varepsilon_{k,c}$. On the $\beta = 0$ twin, that price drift is absent. Consequently, any price-only trend/momentum strategy has large positive $\overline{r^+} - \overline{r^0}$ and $G_p > G_R$.
* **Concrete construction:** Agent A (or G100 searcher B) never references funding (`f` or `a`) and submits the slow cross-sectional return-rank strategy from R6 (`xs_rank` of 4-hour high return, EMA 168–336h). On the 69 truth pairs, $\widehat{S}^+ \approx 2.2$, $\widehat{S}^0 \approx -0.1$, so $G_p \approx 2.3$ and $h_p \approx 2.3 - 0.6 = +1.7$ ($T_h > 15 > 5.449$, $T_{m^+} > 12 > 5.449$).
* **Outcome changed:** `PC.C4` certifies the program as material recovery of the hinted funding plant, and `PC.C5` rejects rarity ($p \le 0.2$) for funding-plant discovery and selection even when neither A nor B ever discovered or used the funding family.
* **Fix:** Add a third truth condition (or replace $\overline{r^0}$ in $G_{pj}$): replay each evaluated program on the planted market ($\beta > 0$) with the **funding feature stream zeroed/held at its baseline $1.25 \cdot 10^{-5}$** while keeping planted prices identical ($r^{+,\text{no-}f}$). Require $\overline{r^+} - \overline{r^{+,\text{no-}f}} > 0$ (or define $G_{pj}$ using $\overline{r^+} - \overline{r^{+,\text{no-}f}}$). Price-only momentum has $r^+ \equiv r^{+,\text{no-}f}$, giving $G^{\text{funding}}_{pj} \equiv 0$.

#### F2 (High — `PC4`, `PC.C4`, `PC.C5`): Price-conditioned funding strategies lose CRN cancellation, inflating $\text{SD}(h)$ to $\sim 0.40$ and collapsing power (Fail while true)

* **Mechanism:** When a funding strategy includes any price/return/volatility filter (e.g., trend confirmation, stop-loss, or volatility scaling), planted and zero-twin prices diverge, so $w^+_{k,c} \ne w^0_{k,c}$. Then $\overline{r^+} - \overline{r^0} = \overline{w^+ \beta a} + \overline{(w^+ - w^0)\sigma x} - \Delta\text{cost}$ carries uncancelled 10-year market noise with cross-pair SD $\approx 0.35\text{--}0.50$ Sharpe units instead of $0.15$.
* **Concrete construction:** In all 33 markets, Agent A discovers a valid funding strategy that gates $w = 0.1 u$ on coin trailing 24h volatility or return sign, achieving true net Sharpe $S^+ = 0.85$ and true plant contribution $\rho = 0.75$ ($h = 0.30$), with $\text{SD}_j(h_{pj}) = 0.42$. On $n = 69$ pairs, $\mathbb{E}[T_h] = \sqrt{69}\times 0.30 / 0.42 = 5.93$, giving certification power $\approx 0.68$ per market (or $0$ across all 33 if A writes the same AST on the shared truth bank when the single truth draw lands at $T_h = 5.1 < 5.449$).
* **Outcome changed:** True routine recovery ($p = 1.0$) yields $< 12$ certified successes and 33 possible successes, flipping `PC.C5` from "common recovery" to "unresolved."
* **Fix:** Compute the counterfactual zero-plant return along the **planted position path** $w^+_{k,c}$ (or use the funding-ablated return $r^{+,\text{no-}f}$ on the same market where noise $\sigma_{k,c}x_{k,c}$ is identical unless $f$ gates trades, and subtract $\sum_c (w^+_{k,c} - w^0_{k,c})\sigma_{k,c}x_{k,c}$ as a control variate). Also test annualized per-pair Sharpe $S^+_{pj} = \sqrt{2190}\overline{r^+_{pj}}/\operatorname{sd}(r^+_{pj})$ rather than unnormalized $m^+_{pj} = \overline{r^+_{pj}}$ so GARCH volatility draws across markets do not inflate the $t$-denominator.

#### F3 (Medium-High — `PC4`, `PC.C4`): Asymmetric denominator in $G_{pj}$ allows high-cost zero-twin churn to pass materiality (Pass while false)

* **Mechanism:** $G_{pj} = \sqrt{2190}(\overline{r^+} - \overline{r^0})/\operatorname{sd}(r^+)$ divides by $\operatorname{sd}(r^+)$ alone rather than $\max(\operatorname{sd}(r^+), \operatorname{sd}(r^0))$.
* **Concrete construction:** A program holds a tiny low-turnover position on $\beta > 0$ ($\widehat{S}^+ = 0.55$, $\operatorname{sd}(r^+) = 5 \times 10^{-5}$) and activates high-frequency noise trading whenever 30-day coin 0/1 return dispersion is below the planted level (firing constantly on $\beta = 0$, generating fee drag $\overline{r^0} = -5 \times 10^{-4}$). Then $G_{pj} = \sqrt{2190}(m^+ - (-5\times 10^{-4})) / (5 \times 10^{-5}) > +400 \gg G_{Rj}/2$, passing both $m^+_p > 0$ and $h_p > 0$ without capturing the plant.
* **Outcome changed:** Non-plant or negligible-plant programs are certified as material recoveries in `PC.C4`.
* **Fix:** Normalize $G_{pj}$ by $\sqrt{\max(\operatorname{Var}(r^+), \operatorname{Var}(r^0))}$ (or evaluate $r^0$ along the fixed trajectory $w^+$).

#### F4 (Medium-High — `PC6`, `PC.C7`): Admission rule $\max(\text{measured\_max}, 0.75) \le 0.80$ permanently deadlocks if any session uses $> 0.80$ of a 5-hour window (Fail while true)

* **Mechanism:** `PC6` states: *"Admission keeps the .8 ceiling on every window and reserves, per session, the larger of the measured maximum and .75 of a five-hour window."*
* **Concrete construction:** Session `pc-v3-m-004` runs 200 turns with large tool outputs and consumes $0.82$ of a 5-hour window (compliant with C7's "compliant use exceeds the 200-turn forecast; no finite worst case is established"). Now `measured_max = 0.82`. For `pc-v3-m-005`, even after waiting 5 hours so current window utilization is $0.00$, the required reservation is $\max(0.82, 0.75) = 0.82 > 0.80$ ceiling. No subsequent session can ever be admitted.
* **Outcome changed:** The runner deadlocks after 5 markets and cannot finish the 33-market cohort.
* **Fix:** Cap the admission reservation at the ceiling when current utilization is zero: reserve $\min(0.80, \max(\text{measured\_max}, 0.75))$ (i.e., always admit on an empty $u_{\text{5h}} = 0$ window if weekly utilization $+ 0.07 \le 0.80$).

#### F5 (Medium — `PC5`, `PC.C6`): `inotify` + `SIGSTOP` kill barrier is an asynchronous OS race, and `pc-v3-release` never tests shared-program cross-arm fan-out (Fail while true & Pass while false)

* **Mechanism:** (a) Linux `inotify` wakes the watcher asynchronously after `mm holdout` writes to `spent.jsonl`; the compiled Rust binary continues running on its core and can commit the 360-step result before Python delivers `SIGSTOP`, triggering C6's permanent "barrier missed" failure. (b) `pc-v3-release` stubs `A` (0 finalists) and forces `R` (1 finalist), so union deduplication across arms (`|union| < |F_A| + |F_R|`) and multi-finalist Holm step-down are never run.
* **Concrete construction:** (a) Under normal multi-core scheduling, `mm holdout` finishes 360 steps in $< 1\text{ ms}$ before the Python `inotify` watcher wakes up, permanently failing C6. (b) In `PC3`'s release function, the dictionary mapping union results back to arms overwrites rather than appends when two arms freeze the same AST (`result_map[ast] = arm`), dropping `A`'s result whenever `A` discovers `R`. `pc-v3-release` passes because `A` is stubbed empty, while real markets drop `A`'s promotions.
* **Outcome changed:** C6 either fails spuriously on a kernel scheduling race (fail while true) or passes while dropping shared finalists in real markets (pass while false).
* **Fix:** (a) In `pc-v3-release`, force `A` to freeze both `R` and a second reference variant alongside `R` (testing cross-arm shared-AST fan-out and $m_A = 2$ Holm step-down simultaneously). (b) Make the kill barrier synchronous in test mode (e.g., `mm holdout` pauses on an environment-specified test FIFO/pipe or `seccomp`/`ptrace` syscall stop after flushing `spent.jsonl`), or allow retry of the disposable kill-test ID if the OS scheduler misses the stop before any kill is sent.

#### F6 (Medium — `PC2`, `PC4`, `PC.C2`, `PC.C4`): Over-strict validation gate ($q_{19} = 7.21$) and mandatory $0.02u$ control certification create false-abort risk (Fail while true)

* **Mechanism:** (a) Validation applies the 6,607-program family threshold $q_{19} = 7.21$ to a single pre-registered reference $R$ on $\text{df} = 19$ pairs; true noncentral-$t$ failure probability is $1.1\%\text{--}5.0\%$, not $10^{-4}$. (b) `PC.C4` requires the $0.02u$ control to certify at $q = 5.449$ on the full kernel, where $\$10$ minimum orders block small 4-hour adjustments of 24h-smoothed references (`raw24`, `d24`).
* **Concrete construction:** Calibration selects `raw24`. On the 20 validation pairs, `raw24` has true net Sharpe $0.92$ and sample $T_{19} = 6.85 < 7.21$ ($p = 7.8 \times 10^{-7}$), permanently aborting the study before any agent runs (`PC.C2`). Or validation passes, all 33 markets complete, and on the 69 kernel truth pairs the $0.02u$ copy of `raw24` has $80\%$ of its incremental rebalancing blocked by the $\$10$ minimum order, landing at $T_h = 4.9 < 5.449$ (ambiguous) and blocking study exit under `PC.C4`.
* **Outcome changed:** A valid, net-profitable plant aborts at validation (`PC.C2`) or fails exit after full budget expenditure (`PC.C4`).
* **Fix:** Validate $R$ on the 20 validation pairs at its actual validation multiplicity ($M_{\text{val}} = 1$, two conditions $\implies \alpha = 0.01/4$, $t_{19, 1-0.0025} = 3.17$, where failure probability at $S=1, \text{SD}=0.41$ is truly $< 10^{-7}$), since $R$ is simultaneously re-certified at $q = 5.449$ on the 69 truth pairs in `PC4`. For the $0.02u$ control in `PC.C4`, require non-negative resolution (not certified non-recovery) if $\$10$ order quantization suppresses $>20\%$ of trades, while keeping $0.05u$ as mandatory certified recovery.

#### F7 (Low-Medium — `PC4`, `PC.C5`): Confirmation horizon $g = \mu/2 - (v^2 + \mu^2)/8$ can be zero or negative on valid recovered finalists (Fail while true)

* **Mechanism:** The formula assumes fixed unnormalized stake $\lambda = 1/2$ rather than scale-invariant Kelly sizing. Whenever $\mu < (v^2 + \mu^2)/4$ (which occurs for any strategy with annualized Sharpe $S = 0.6$ and 4-hour return volatility $v > 0.051$), $g \le 0$.
* **Concrete construction:** A recovered finalist has $\widehat{S}^+ = 0.65$ and $v = 0.06$ ($\mu = 8.33 \times 10^{-4}$). Then $g = 4.17 \times 10^{-4} - 4.50 \times 10^{-4} = -3.3 \times 10^{-5} < 0$, producing a negative horizon $\log(m/0.05)/g = -89{,}500\text{ steps}$ (or `ZeroDivisionError` at $g = 0$).
* **Outcome changed:** Report generation crashes or prints negative confirmation years in `PC.C5`.
* **Fix:** Use the scale-invariant plug-in half-Kelly growth rate $g = \frac{3}{8}\frac{\mu^2}{v^2 + \mu^2}$ (or report $\infty\text{ / unconfirmable at }\lambda = 1/2$ whenever $g \le 0$).

#### F8 (Low-Medium — `PC1`, `PC6`, `PC.C1`, `PC.C7`): Deferred `harness_hash()` ("whatever it is") and static OAuth bearer token hashes

* **Mechanism:** (a) Committing the PC manifest before `thesis-refreeze` freezes leaves `harness_hash()` unpinned at commit time. (b) OAuth bearer tokens (`CLAUDE_CODE_OAUTH_TOKEN_*`) expire and rotate; pinning only raw token hashes refuses valid TAMU/Cornell sessions after token refresh.
* **Concrete construction:** (a) `thesis-refreeze` edits `sandbox/client.py` after the PC manifest is committed. (b) In week 2 of the 1.5-week run, Cornell's OAuth token expires and refreshes; the runner rejects the new token hash and halts at market 21 of 33.
* **Outcome changed:** Pre-registration integrity (`PC.C1`) or campaign completion (`PC.C7`).
* **Fix:** Freeze `thesis-refreeze` *before* committing the PC manifest so `PC.C1` pins a literal 64-hex SHA-256. In `PC.C7`, verify the stationary OAuth account/organization UUID returned by the API (or allow appending refreshed token hashes tied to the same verified account UUID in an append-only audit log).

---

### 3. Independent Constructions for Each Criterion (PC.C1–PC.C7)

| Criterion | Independent "Pass While False" Construction | Independent "Fail While True" Construction |
| --- | --- | --- |
| **PC.C1** *(Prospective provenance)* | Manifest is committed while `thesis-refreeze` is still open ("whatever it is"), and `sandbox/client.py` is tuned before refreeze lands; OR features/thresholds tuned on `d07162b8...` in `r2`/development exploit the exact same unshifted timestamps in the 33 search and 69 truth markets. | A Nix store rebuild or OS update alters a non-functional binary path inside `harness_hash()`, or an unpromoted holdout evaluation truncates bar 360 on EOF, failing the exact hash/count check despite clean prospective provenance. |
| **PC.C2** *(Validated net alternative)* | The frozen funding blob's strongest spikes fall inside steps $[3300, 4020)$ (the 120-day synthetic embargo window of the 730-day market). $R$ validates at $S \approx 1.0$ over 10-year (21,900-step) validation pairs that cycle through the whole blob, but has net Sharpe $\le 0$ inside the 3,300-step search and 360-step holdout windows of the 33 markets. | $R$ has true net Sharpe $S = 0.92$ and SD $= 0.42$ in every market, but on the 20 validation pairs its sample $t$-statistic lands at $T_{19} = 6.95 < q_{19} = 7.21$ (which happens $\sim 5\%$ of the time under $t_{19}(\delta = 9.8)$), permanently blocking the study. |
| **PC.C3** *(Faithful, isolated arms)* | Agent A runs permitted read-only `Bash`/`Python` calls (`os.stat`, `/proc`, filesystem timestamps) that observe host artifacts without triggering a "forbidden tool" execution; OR A burns 40 of its 100 evaluations on syntax errors and duplicate ASTs that G100 (B) filters pre-evaluation, creating an unmodeled budget asymmetry. | One of 33 A sessions executes a harmless out-of-scope shell command (e.g., `ls ..`) or drops its final transcript hash on a 2-hour timeout flush; no cross-arm or market data leaked, yet C3 fails the entire cohort on "executed forbidden call / missing evidence." |
| **PC.C4** *(Truth & first bottlenecks)* | Agent A never touches funding features and submits R6's slow cross-sectional price momentum; because $\beta > 0$ adds drift to coin 0/1 prices, $m^+_p > 0$ and $h_p > 1.4$ certify at $t > 15$, misclassifying price momentum as funding-plant recovery. | Calibration chooses `raw24`; on the 69 kernel truth pairs, the $0.02u$ control's 4-hour rebalancing steps fall below the $\$10$ minimum order, leaving $T_h = 4.8 \le 5.449$ (ambiguous) and failing C4's mandatory control exit condition. |
| **PC.C5** *(Decision-sized inference)* | Agent A discovers a genuine funding-plus-volatility-filter strategy in 22 of 33 markets ($p = 0.67$), but because $w^+ \ne w^0$ raises $\text{SD}(h)$ to $0.40$, only 9 certify ($T_h > 5.449$) and 13 remain ambiguous. C5 passes with an "unresolved" report, failing to answer the decision question. | A recovered finalist has $\widehat{S}^+ = 0.65, v = 0.06$, making $g = \mu/2 - (v^2+\mu^2)/8 < 0$ and crashing or negating the required confirmation horizon report. |
| **PC.C6** *(Forced nonempty release)* | `pc-v3-release` stubs A (0 finalists) and forces R (1 finalist), passing C6 while a bug in `PC3`'s union-to-arm fan-out drops A's promotion whenever A and R freeze the same AST in the 33 study markets. | The compiled Rust `mm holdout` child finishes 360 steps and writes the result in $< 1\text{ ms}$ before the asynchronous Python `inotify` watcher wakes up to send `SIGSTOP`, permanently failing C6 as "barrier missed." |
| **PC.C7** *(Accounts & accounting)* | A 2-hour Claude CLI session refreshes an expired token mid-run from a default local credential store after passing the pre-session token SHA-256 check. | Session 4 uses $0.82$ of a 5-hour window, setting `measured_max = 0.82 > 0.80` ceiling and permanently deadlocking admission; OR Cornell's OAuth token rotates in week 2, changing its SHA-256 and halting the cohort at market 21. |

---

### 4. Summary of Required Edits Before Freezing

1. **In `PC4` / `PC.C4` (Truth assay):**
* Test annualized per-pair Sharpe $S^+_{pj} = \sqrt{2190}\overline{r^+_{pj}}/\operatorname{sd}(r^+_{pj}) > 0$ alongside $m^+_{pj} > 0$.
* Replace $\overline{r^0}$ in $G_{pj}$ with the funding-ablated planted return $\overline{r^{+,\text{no-}f}}$ (program $p$ replayed on the planted market with funding input held at baseline $1.25\cdot 10^{-5}$), or add $\mathbb{E}[\overline{r^+} - \overline{r^{+,\text{no-}f}}] > 0$ and normalize $G_{pj}$ by $\sqrt{\max(\operatorname{Var}(r^+), \operatorname{Var}(r^0))}$. This eliminates R6 price-momentum false positives, restores CRN cancellation ($w^+ \equiv w^{+,\text{no-}f}$ until funding gates a trade), and blocks denominator deflation.
* Relax the $0.02u$ control in `PC.C4` from "must certify at $q = 5.449$" to "resolves non-negative ($T > -5.449$), with $0.05u$ certified as recovery ($T > 5.449$)."
* Replace $g = \mu/2 - (v^2+\mu^2)/8$ with scale-invariant half-Kelly $g = \frac{3}{8}\frac{\mu^2}{v^2+\mu^2}$ (or guard $g \le 0$ as $\infty$).


2. **In `PC2` / `PC.C2` (Validation):**
* Fix line 66 of `design-check.py` to use `stats.nct.cdf` and gate 20-pair validation of $R$ at single-reference multiplicity $t_{19, 1-0.01/4} = 3.17$ (keeping $q = 5.449$ on the 69 truth pairs).


3. **In `PC5` / `PC.C6` (Release & kill test):**
* Have `pc-v3-release` force `A` to freeze both `R` and a second reference variant while `R` freezes `R`, exercising cross-arm shared-AST deduplication/fan-out and $m_A = 2$ Holm step-down.
* Replace the asynchronous `inotify` race with a synchronous test barrier (e.g., named pipe/FIFO sync after `spent.jsonl` flush in test mode).


4. **In `PC1`, `PC6` / `PC.C1`, `PC.C7` (Pins, admission, accounts):**
* Merge `thesis-refreeze` first and record the literal `harness_hash()` SHA-256 in the manifest.
* Cap per-session 5-hour admission reservation at $\min(0.80, \max(\text{measured\_max}, 0.75))$ so a single session above $0.80$ cannot deadlock future empty windows.
* Allow rotated OAuth tokens verified against the stationary TAMU/Cornell account/organization UUID.
