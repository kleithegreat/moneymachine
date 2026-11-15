# Argon (Gemini 4 Argon High, agy CLI) on kernel version 2 and study 2: round 6, confirming

Run 2026-11-15 02:20 to 02:27 UTC (2026-11-14 21:20 to 21:27 EST) from a clean bundle (`~/.cache/mm-argon/kv2-r6`): `rearchitecture` at `8106078`, Fable's report 6, both round-5 reviews and the human's answers. Links to `audit/program/` are on `rearchitecture`. Verbatim below.

### 1. Round-5 Findings: Fixed at the Cause, or Not?

#### Argon's Round-5 Findings ([argon-r5.md](audit/program/argon-r5.md))
- **Finding 1.1 (`D29 / K1 ★` downward 128-bit rounding of stored balances):** **Fixed at its cause** — stored balance rounding is deleted; the test ledger trades whole test lots of $10^{-30}$ and keeps every unit and cash balance exact on a fixed rational grid ([kernel-v2.md](audit/program/kernel-v2.md#L194-L202), [K1 ★](audit/program/kernel-v2.md#L345-L350)).
- **Finding 1.2 (`D29 / O5` negative `free_cash` and negative scale after funding):** **Fixed at its cause** — per-cycle unspent budgets are deleted; each cycle's scale is $\phi \cdot C_{t^-} / d$ read directly from current cash $C_{t^-} \ge 0$ ([kernel-v2.md](audit/program/kernel-v2.md#L195), [architecture.md](audit/program/architecture.md#L271-L273)).
- **Finding 1.3 (`K1 ★` promising row-fold wealth at intermediate events):** **Fixed at its cause** — `K1 ★` now states that the row fold equals the event fold in cash and units after every event and in wealth at each UTC day's end ([kernel-v2.md](audit/program/kernel-v2.md#L349)).
- **Finding 2 (`T1 ★` listing settlement price update & short liquidation direction):** **Fixed at its cause** — a listing's end moves the coin's price to the settlement price before closing (`A3` [kernel-v2.md](audit/program/kernel-v2.md#L51), `A12` [L180](audit/program/kernel-v2.md#L180)), and `A10` closes liquidated shorts against ask levels at $\max(\text{ask\_level}, P_c)$ ([kernel-v2.md](audit/program/kernel-v2.md#L168), `T1 ★` [L334](audit/program/kernel-v2.md#L334)).
- **Finding 3 (`D30 / O4` sub-hourly rebalancer passing the 1h/1d guard):** **Fixed at its cause** — the claim that the guard clears a record is withdrawn; the guard is now a negative control (1m, 5m, 1h, 1d clocks) that can only refuse registration and is quoted alongside every use of `"outgrew"` ([architecture.md](audit/program/architecture.md#L295-L298), [§6.5](audit/program/architecture.md#L358)).
- **Finding 4.1 (`D12-v5` mid-day span ends losing partial-day events & resetting `least_return`):** **Fixed at its cause** — `A12` writes a coin row for every universe coin at each span's end (after settlement) as well as at each UTC day's end ([kernel-v2.md](audit/program/kernel-v2.md#L189)), and `K1 ★` checks `least_return >= -1` across every row so far, of any span ([kernel-v2.md](audit/program/kernel-v2.md#L350)).
- **Finding 4.2 (`D12-v5` `n` undefined at $D = 0$, empty-span `least_return`, and log-slack bound):** **Fixed at its cause** — `n` is $2^{40}$ times the least of $1, 2, 4, \dots$ at or above $D$ (`K2 ★` [kernel-v2.md](audit/program/kernel-v2.md#L351)), `least_return` is the least of the returns and zero (`A12` [L189](audit/program/kernel-v2.md#L189)), and the log-slack bound is stated as $D / 2^{40}$ ([architecture.md](audit/program/architecture.md#L302)).
- **Finding 4.3 (`D12-v5` multiplier search upper bound when $Q_c < 0$):** **Fixed at its cause** — the upper search bound is widened to $\max_c(S_{1,c} - \min(Q_c, 0)) + 1$ ([architecture.md](audit/program/architecture.md#L302), [arithmetic.py.txt](audit/program/arithmetic.py.txt#L177)).
- **Finding 5 (`D14-v5` Layer 2 join staleness at same-ms quotes & multi-fill print size):** **Fixed at its cause** — the engine marks each print with world staleness in the trace (`A3` [kernel-v2.md](audit/program/kernel-v2.md#L52), `A12` [L192](audit/program/kernel-v2.md#L192)) for the join to read directly, and the matched print's size must cover the sum of matched fills ([architecture.md](audit/program/architecture.md#L342)).

#### GPT's Round-5 Findings ([gpt-r5.md](audit/program/gpt-r5.md))
- **Finding 1 (`D29 / O5` funding makes free cash and scale negative):** **Fixed at its cause** — unspent budgets are deleted and scales read only current cash $C_{t^-} \ge 0$ ([kernel-v2.md](audit/program/kernel-v2.md#L195), [architecture.md](audit/program/architecture.md#L271-L273)).
- **Finding 2 (`K1` downward-rounded balances are not a lower bound):** **Fixed at its cause** — only trade sizes are rounded (to whole test lots of $10^{-30}$ toward zero), leaving all stored balances exact ([kernel-v2.md](audit/program/kernel-v2.md#L194-L202), [K1 ★](audit/program/kernel-v2.md#L347)).
- **Finding 3 (`T1` short liquidation buyback, settlement price update, and non-negative fees):** **Fixed at its cause** — both liquidation sides and the settlement price update are written out, and `start` rejects any fee schedule with a negative rate (`A8` [kernel-v2.md](audit/program/kernel-v2.md#L158), `A10` [L168](audit/program/kernel-v2.md#L168), `A12` [L180](audit/program/kernel-v2.md#L180), `T1 ★` [L334](audit/program/kernel-v2.md#L334)).
- **Finding 4 (`D30 / O4` hourly/daily guard & static holdings with funding beating mixes):** **Fixed at its cause** — the guard's safety reading is withdrawn, and each span's bar now takes the maximum with every universe coin held alone with its funding paid in cash ([architecture.md](audit/program/architecture.md#L291), `K2 ★` [kernel-v2.md](audit/program/kernel-v2.md#L351)).
- **Finding 5 (Rung 2 sufficient condition omitting coin identity & "fills better than the tape"):** **Fixed at its cause** — the sufficient condition is stated on the whole event (which coin, what return, and when), and maker gains are attributed to later price moves rather than fills better than the tape ([architecture.md](audit/program/architecture.md#L292), [L299](audit/program/architecture.md#L299)).
- **Attack 5 Notes (`K2` domain and log-slack):** **Fixed at its cause** — `K2 ★` explicitly restricts its bound to records with no return below $-1$ ([kernel-v2.md](audit/program/kernel-v2.md#L351)) and quotes the log-slack bound as $D / 2^{40}$ ([architecture.md](audit/program/architecture.md#L302)).
- **Attack 6 Notes (`D32` terminal payment in the stopped supermartingale & `V16` conditionality):** **Fixed at its cause** — the terminal funding payment is deducted from $W$ (leaving $W \ge 0$ under V16) before killing $W$ to zero, and the 5% size is stated as conditional on V16 ([architecture.md](audit/program/architecture.md#L276), `A14` [kernel-v2.md](audit/program/kernel-v2.md#L236)).
- **Attack 7 Note (`D14-v5` Layer 2 join does not establish a placement history):** **Fixed at its cause** — [architecture.md](audit/program/architecture.md#L342) explicitly states that a matching print shows `optimistic` fills a live eligible order there, not that a valid placement history exists.

---

### 2. Check 2: The Stake Rule (D34)

**No finding.**
1. **No scale or balance below zero:** Initially $C_0 = 1 > 0$ and $U_{c,0} = 0$. Since $\phi \in (0, 1]$ and $d > 0$ ([kernel-v2.md](audit/program/kernel-v2.md#L345)), a cycle's scale at its first buy is $s_c = \phi C_{t^-} / d \ge 0$ whenever $C_{t^-} \ge 0$. At any buy of the account with price $p > 0$ and fee rate $f \ge 0$, the uncut target in units is $s_c \cdot \max(0, \min(\text{notional}, d - \text{followed}_c)) / p \ge 0$, which is capped at $C_{t^-} / (p(1+f)) \ge 0$ and floored to whole test lots of $10^{-30}$ ([build-plan.md](audit/program/build-plan.md#L159)). Thus $\Delta U_{c,t} \ge 0$ and $C_t = C_{t^-} - \Delta U_{c,t} p(1+f) \ge 0$. At any sale that does not take the account short, the account sold a fraction $\alpha = \Delta q / q_{\text{before}} \in (0, 1]$, so $\Delta U_{c,t} \in [0, U_{c,t^-}]$ and $U_{c,t} = U_{c,t^-} - \Delta U_{c,t} \ge 0$ (with $U_{c,t} = 0$ when $\alpha = 1$). A fill that takes the account short or a funding payment exceeding $C_{t^-}$ immediately ends the ledger ([kernel-v2.md](audit/program/kernel-v2.md#L197)).
2. **No change in the books outside fills and funding:** `cash` and `units` change only at the account's buy/sell fill rows and funding rows; quote moves, non-account prints, wishes, cancellations, cycle ends, and `absorbed` rows move neither cash nor units ([kernel-v2.md](audit/program/kernel-v2.md#L194-L200)).
3. **First-come-first-served cash sharing touches only power:** By `T1 ★`, any non-negative purchase $\Delta U_{c,t} \ge 0$ at $p_{\text{fill}} \ge P_{c,t}$ and fee $f \ge 0$ changes immediate wealth by $\Delta U_{c,t}(P_{c,t} - p_{\text{fill}}(1+f)) \le 0$, and between trades $w_{c,t^-} = U_{c,t^-} P_{c,t^-} / W_{t^-} \in [0, 1]$. Cutting a later cycle's buy to the remaining cash $C_{t^-} / (p_{\text{fill}}(1+f))$ is an adapted choice of a smaller non-negative trade size $\Delta U_{c,t} \ge 0$; it can reduce exposure (power) when cycles overlap deeply, and can never increase $W$ or alter the 5% size.

---

### 3. Check 3: The Ledger's Grid (D35)

**No finding.**
1. **Units grid ($10^{-30}$):** Every buy and partial sale rounds units down to whole multiples of $\ell_{\text{test}} = 10^{-30}$, and a full sale ($\alpha = 1$) sells all $U_{c,t^-} \in \mathbb{Z} \cdot 10^{-30}$ units, leaving $0$ ([kernel-v2.md](audit/program/kernel-v2.md#L194-L196)).
2. **Cash grid ($\frac{1}{2} \cdot 10^{-50}$):**
   - By `A2` ([kernel-v2.md](audit/program/kernel-v2.md#L28)) and `A14` V1 ([L223](audit/program/kernel-v2.md#L223)), every admitted price (including bar-derived quotes and prints in `A16` [L263-L265](audit/program/kernel-v2.md#L263-L265)) lies on a grid of at most 8 decimals ($\mathbb{Z} \cdot 10^{-8}$), every quote mid is a half-sum of two prices ($\mathbb{Z} \cdot \frac{1}{2} 10^{-8}$), and every fee or funding rate has at most 12 decimals ($\mathbb{Z} \cdot 10^{-12}$).
   - At a buy or sale of $\Delta U \in \mathbb{Z} \cdot 10^{-30}$ units at price $p \in \mathbb{Z} \cdot \frac{1}{2} 10^{-8}$ and fee rate $f \in \mathbb{Z} \cdot 10^{-12}$, the cash change is $\mp \Delta U \cdot p \cdot (1 \pm f) \in \mathbb{Z} \cdot \frac{1}{2} 10^{-50}$.
   - At a funding payment (`A9` [kernel-v2.md](audit/program/kernel-v2.md#L162)), one unit pays $O \cdot \rho \in \left(\mathbb{Z} \cdot \frac{1}{2} 10^{-8}\right) \cdot \left(\mathbb{Z} \cdot 10^{-12}\right) = \mathbb{Z} \cdot \frac{1}{2} 10^{-20}$ (and because the test ledger holds $U_c > 0$ only when the account holds $q_{\text{acct}} > 0$, `cash_paid / position_before` in the funding row recovers $O \cdot \rho$ exactly). Multiplying by $U_c \in \mathbb{Z} \cdot 10^{-30}$ gives a cash change in $\mathbb{Z} \cdot \frac{1}{2} 10^{-50}$.
3. **No precision growth with run length:** Because every unit balance is an integer multiple of $10^{-30}$ and every cash balance is an integer multiple of $\frac{1}{2} 10^{-50}$, the reduced rational denominator of `units` always divides $10^{30} < 2^{100}$ and that of `cash` always divides $2 \cdot 10^{50} < 2^{168}$, independent of the number of events. Each cycle's `scale` and `followed` are computed from a single snapshot of `cash` and deleted when the cycle closes.

---

### 4. Check 4: Law T1 as Now Stated (D40)

**No finding.**
Checking all three kinds of fill (`A12` [kernel-v2.md](audit/program/kernel-v2.md#L185)) against `T1 ★` ([L334](audit/program/kernel-v2.md#L334)):
1. **Fees (`A8` [L158](audit/program/kernel-v2.md#L158)):** `start` (and Step 2's replay) rejects any fee schedule with a negative rate, and settlements charge zero fee, so no fill has a negative fee.
2. **Order fills (`A7` [L129-L147](audit/program/kernel-v2.md#L129-L147)):**
   - *Arrivals (taker at a quote with $b < a$ and $P_c = (b+a)/2$):* A buy takes ask levels $a_i \ge a_1 = a > P_c$; a sell takes bid levels $b_i \le b_1 = b < P_c$.
   - *Resting on a print at $x$ ($P_c = x$):* Under `pessimistic` / `optimistic`, a buy at $p$ fills only when $x < p$ / $x \le p$, at $p_{\text{fill}} = p \ge x = P_c$; a sell at $p$ fills only when $x > p$ / $x \ge p$, at $p_{\text{fill}} = p \le x = P_c$.
   - *Resting on a quote under `optimistic` ($P_c = (b+a)/2$):* A buy at $p$ fills only when $a \le p$, at $p_{\text{fill}} = p \ge a > P_c$; a sell at $p$ fills only when $b \ge p$, at $p_{\text{fill}} = p \le b < P_c$.
   - *Bar-derived events (`A16` [L258-L265](audit/program/kernel-v2.md#L258-L265)):* Processed one event at a time in `A3` order, updating $P_c$ at each print and quote before fills run.
3. **Liquidation closes, including tails beyond recorded levels (`A10` [L168](audit/program/kernel-v2.md#L168)):**
   - Every held coin has a latest quote (no order can fill before a coin's first quote because the coin is stale, `A3` [L52](audit/program/kernel-v2.md#L52)).
   - *Long close (sale):* Each bid level $b_i$ fills at $\min(b_i, P_c) \le P_c$, and any tail beyond the recorded bid levels closes at the last level's fill price $\min(b_k, P_c) \le P_c$.
   - *Short close (buyback):* Each ask level $a_i$ fills at $\max(a_i, P_c) \ge P_c$, and any tail beyond the recorded ask levels closes at the last level's fill price $\max(a_m, P_c) \ge P_c$.
4. **Listing settlement, long or short (`A3` [L51](audit/program/kernel-v2.md#L51), `A12` [L180](audit/program/kernel-v2.md#L180)):**
   - The coin's price is moved to $P_c = P_{\text{settle}}$ *before* its position is closed at $p_{\text{fill}} = P_{\text{settle}}$. Thus a long's closing sale has $p_{\text{fill}} = P_{\text{settle}} \le P_c$ and a short's closing buyback has $p_{\text{fill}} = P_{\text{settle}} \ge P_c$.

---

### 5. Check 5: The Bar's New Term and K2's Domain (D36)

**No finding.**
1. **No solvent holding with funding beats the bar — within one span or across multiple spans:**
   - In a single span starting at prices $P_{c,0}$ where coin $c$ ends at price $P_{c,t}$ and a unit of coin $c$ paid cumulative funding $F_{c,t}$, a non-traded holding that puts initial cash weights $w_c \ge 0$ into coin $c$ ($u_c = w_c / P_{c,0}$ units) and $w_0 = 1 - \sum_c w_c \ge 0$ into cash has wealth:
     $$H_t = w_0 - \sum_c u_c F_{c,t} + \sum_c u_c P_{c,t} = w_0 \cdot 1 + \sum_c w_c \left(\frac{P_{c,t} - F_{c,t}}{P_{c,0}}\right) \le \max\!\left(1,\ \max_c \frac{P_{c,t} - F_{c,t}}{P_{c,0}}\right) \le \bar{B}_{\text{span}},$$
     since $(1 - D/n)^{-n} \ge 1$ for all $D \ge 0$.
   - **Across span boundaries:** When Span 1 ends at $T_1$ (at a universe coin's settlement), a solvent non-traded holding has cash $C_{T_1} \ge 0$ (including any settlement proceeds of the delisted coin) and remaining units $u_c \ge 0$, with total wealth $H_{T_1} = C_{T_1} + \sum_c u_c P_{c, T_1} \le \bar{B}_{\text{Span 1}}$. Because `A12` ([kernel-v2.md](audit/program/kernel-v2.md#L189)) starts Span 2 from the exact post-settlement prices $P_{c, \text{Span 2}, 0} = P_{c, T_1}$, at the start of Span 2 the holding is a valid non-negative portfolio with weights $w'_0 = C_{T_1} / H_{T_1} \ge 0$ and $w'_c = u_c P_{c, T_1} / H_{T_1} \ge 0$ ($\sum w' = 1$). Thus at $T_2$ in Span 2, $H_{T_2} \le H_{T_1} \bar{B}_{\text{Span 2}} \le \bar{B}_{\text{Span 1}} \bar{B}_{\text{Span 2}} = \bar{B}_{T_2}$.
2. **No span boundary loses an event:** Writing a coin row for every universe coin at each span's end after the settlement (`A12` [kernel-v2.md](audit/program/kernel-v2.md#L189), `P1 ★` [L342](audit/program/kernel-v2.md#L342)) captures all events between the previous UTC midnight and a mid-day delisting, and `K2 ★` multiplies the completed spans' bars with the current span's day-end bar ([L351](audit/program/kernel-v2.md#L351)).
3. **The veto across spans and K2's domain:** `K1 ★` ([kernel-v2.md](audit/program/kernel-v2.md#L350)) and `K2 ★` ([L351](audit/program/kernel-v2.md#L351)) check that no coin's row so far, *of any span*, held a return below $-1$, and `K2 ★` restricts its dominance claim to records where every return is $\ge -1$ (for $r_k = -1$ and $b_{c_k} = 1$, the mix's product is $0 \le \bar{B}$; for $b_{c_k} r_k > -1$, $\log(1 + b_{c_k} r_k) \le b_{c_k} r_k - b_{c_k}^2 r_k^2 / 2 + b_{c_k}^3 r_k^3 / 3$ applies).

---

### 6. Check 6: The Guard (D37 and D38)

1. **No sentence reads the guard as clearing a record:** Every mention of the guard ([fable-report-6.md](audit/program/fable-report-6.md#L28-L33), [kernel-v2.md](audit/program/kernel-v2.md#L362), [L384](audit/program/kernel-v2.md#L384), [architecture.md](audit/program/architecture.md#L295-L298), [L358](audit/program/architecture.md#L358), [build-plan.md](audit/program/build-plan.md#L174)) treats it strictly as a negative control that can refuse Rung 2's registration or be quoted beside `"outgrew"`, and Step 10 Test 14 explicitly asserts its silence on the astride-minute market where an between-tick rebalancer outgrows the bar.
2. **The refusal threshold:** Refusing to register Rung 2 when any of the four clock rules reaches $20^{212/730} \approx 2.39\times$ the bar over the 212-day pre-freeze replay ([architecture.md](audit/program/architecture.md#L358)) can only withhold Rung 2 (freezing Study 2 with Rung 1 alone) and never inflates Type I error.
3. **The rules' books computed from the engine's trace (D38) — one intra-tick ordering note/finding:**

#### Finding 1 (Check 6 — D38): At a clock tick that coincides with an hourly funding settlement, `guard` must deduct the tick row's funding on pre-tick units *before* rebalancing to the mix
- **Outcome changed:** Whether Rung 2 is registered at the §6.5 pre-freeze guard and the guard figure quoted beside `"outgrew"` ([architecture.md](audit/program/architecture.md#L297), [L306](audit/program/architecture.md#L306), [L358](audit/program/architecture.md#L358)).
- **The specification gap:**
  - By `A9` ([kernel-v2.md](audit/program/kernel-v2.md#L162)), funding settles on the hour, which coincides with every 1-minute, 5-minute, and 1-hour tick $\tau_k$.
  - In the engine's event order (`A3` [kernel-v2.md](audit/program/kernel-v2.md#L38-L46), `A12` [L181-L183](audit/program/kernel-v2.md#L181-L183)), at timestamp $\tau_k$, funding (class 2) and quotes/prints (class 3) happen *before* the tick (class 4). The trace row at tick $\tau_k$ bundles each coin's price at $\tau_k$ together with *"what a unit of it paid in funding since the tick before"* (`A12` [L192](audit/program/kernel-v2.md#L192)).
  - Neither `B1` ([kernel-v2.md](audit/program/kernel-v2.md#L292)) nor Step 10 Test 14 ([build-plan.md](audit/program/build-plan.md#L174)) states whether, upon reading tick $\tau_k$'s trace row, `guard` applies the row's funding *before* or *after* rebalancing to the mix at $\tau_k$'s prices (in [arithmetic.py.txt](audit/program/arithmetic.py.txt#L507-L520), `guard_reach` runs on a funding-free market, and [L681-L687](audit/program/arithmetic.py.txt#L681-L687) calls `rebalance` then `fund` once).
- **Concrete construction:**
  - Take a guard rule on the 1-hour clock with weight $w_A = 0.9$ in Coin A and $0.1$ in cash. At $\tau_0 = 0$, $P_{A,0} = 100$, so the rule holds $U_{A,0} = 0.009$ units ($0.90$ value) and $C_0 = 0.10$ cash.
  - During the first hour $(0, \tau_1]$, Coin A rises to $P_{A,1} = 400$, and at the hourly settlement at $\tau_1 = 60\text{ min}$ Coin A charges $F_A = 15$ per unit ($3.75\%$ of price, within the $4\%/\text{h}$ cap).
  - **In the world's causal order (funding before tick):** At the funding event in $(0, \tau_1]$, the rule holds $U_{A,0} = 0.009$ units and owes $0.009 \times 15 = 0.135 > 0.10 = C_0$, so its cash cannot meet the payment and **the rule ends** (`ended = True`).
  - **If `guard` rebalances at $\tau_1$ before applying $\tau_1$'s funding:** Rebalancing at $P_{A,1} = 400$ first sells $0.000675$ units into cash (raising cash to $0.10 \times (0.10 + 0.009 \times 400) = 0.37$ and lowering units to $U_{A,1} = 0.008325$), and then deducts $0.008325 \times 15 = 0.124875 \le 0.37$, so **the rule survives instead of ending and underpays funding**.
- **Smallest change that removes the cause:** In `B1` ([kernel-v2.md](audit/program/kernel-v2.md#L292)) and Step 10 Test 14 ([build-plan.md](audit/program/build-plan.md#L174)), state that at each tick, `guard` deducts the tick row's funding on the units held since the previous tick *before* any span-end switch or clock rebalance at that tick.

---

### 7. Check 7: Rung 2's Null as Reworded, and the Two Claims with Their Limits (D39)

**No finding.**
1. **Rung 2's sufficient condition ([architecture.md](audit/program/architecture.md#L292)):** Requiring each price event as a whole (which coin $C_k$, what return $R_k > -1$, and when) to have one law $\mathbb{P}_0$ whatever came before makes the single-event log-optimal constant mix $b^* \in \arg\max_{b \in \Delta} \mathbb{E}_{\mathbb{P}_0}[\log(1 + b_{C_k} R_k)]$ satisfy the Kuhn-Tucker condition $\mathbb{E}[(1 + w_{k-1, C_k} R_k) / (1 + b^*_{C_k} R_k) \mid \mathcal{F}_{k-1}] \le 1$ for every adapted portfolio $w_{k-1} \in \Delta$. This closes GPT's Round-5 Finding 5 (predictable coin alternation).
2. **The two claims and their limits ([architecture.md](audit/program/architecture.md#L276), [L306](audit/program/architecture.md#L306)):** Both claims state `"assuming our orders move nobody"` (`V10`), rest on `V16` for their 5% size, decline to claim skill, and accompany every use of `"outgrew"` with the limit that cross-event predictability allows a rule without skill to outgrow every constant mix, alongside the guard's maximum ratio to the bar.

---

### 8. Check 8: The Build Plan's Steps 9 and 10

1. **Step 9 ([build-plan.md](audit/program/build-plan.md#L137-L150)):** **No empty or constant instrument passes.** Tests 1–5 and `P1 ★` check exact rational identities for cash, units, prices, first prices, unit funding, and least returns, two-sided `2⁻¹²⁸` brackets on the three sums, span-end rows on a mid-day delisting where a coin doubled, and trace print-staleness marks on both sides of the gap boundary; Tests 6–9 check schema rejections, process-kill durability (`W1`), hash sensitivity (`D1`), and renaming (`N1`).
2. **Step 10 ([build-plan.md](audit/program/build-plan.md#L152-L180)):**
   - For `confirm`, `guard`, the OCaml multiplier proposer, the OCaml mix proposer, and Layer 2's join and measurement runner, **no empty or constant instrument passes Tests 1–15** (Test 11 fails a never-confirming `confirm`; Tests 1, 7, 10, 13 fail an always-confirming `confirm`; Tests 2, 3, 5, 10 check exact hand-worked rationals and require the multiplier proposer to find $\mu = 7.5$ with $D = 7.5$; Test 14 requires the 5-minute guard rule to reach $\ge 20\bar{B}$ on the 5-minute pair market and all four clocks to stay $< \bar{B}$ on the astride market; Test 15 checks both positive and negative cases of the join and planted order classes).
   - **However, two OCaml items listed in Step 10's "Builds" line have no tests in Step 10:**

#### Finding 2 (Check 8 — Step 10): [build-plan.md](audit/program/build-plan.md#L158) lists `the decimation of the fast period, the block bootstrap` under Step 10's OCaml builds, but Tests 1–15 never call or test either one
- **Outcome changed:** Pre-freeze registration of $\phi$ and $d$ and the reported pre-freeze power forecast ([architecture.md](audit/program/architecture.md#L334), [L357](audit/program/architecture.md#L357), [L370](audit/program/architecture.md#L370)): an empty or constant `block bootstrap` (e.g., always returning power `0`) passes all 15 tests of Step 10.
- **Concrete construction:**
  - In [build-plan.md](audit/program/build-plan.md#L158), Step 10 specifies: *"Builds, in OCaml: the proposer of multipliers and the proposer of the guard's mixes (any search; neither is trusted), layer 2's join and the runner of its measurement, **the decimation of the fast period, the block bootstrap**."*
  - None of Tests 1 to 15 ([build-plan.md](audit/program/build-plan.md#L160-L175)) invokes `the decimation of the fast period` or `the block bootstrap`. Consequently, a Step 10 builder who writes `let decimate x = x` and `let block_bootstrap _ = 0.0` passes every test in Step 10.
  - Moreover, `the decimation of the fast period` is an unused carryover from an earlier round (Layer 2 now stratifies its measurement by the archive's cadence period in [architecture.md](audit/program/architecture.md#L343) rather than decimating), while `the block bootstrap` is used in [architecture.md](audit/program/architecture.md#L334) and [L357](audit/program/architecture.md#L357) to choose $\phi$ and $d$ and forecast power before the freeze, but its resampling unit on the test ledger's report rows is not specified in [build-plan.md](audit/program/build-plan.md#L158).
- **Smallest change that removes the cause:** Remove `the decimation of the fast period` from [build-plan.md](audit/program/build-plan.md#L158), and either move `the block bootstrap` to Study 2's criteria alongside the replica's program and registered constants ([build-plan.md](audit/program/build-plan.md#L180)) or specify its block unit (e.g., resampling blocks of UTC days) and add a test in Step 10 on planted-drift vs. driftless fixtures that a constant bootstrap fails.

---

### 9. Convergence Ledger and Verdict

#### Points Agreed
1. **All Round-5 findings resolved at their causes (`D34`–`D40`, `D14-v6`):** Deleting unspent budgets (`D34`), trading whole test lots of $10^{-30}$ on an exact rational grid (`D35`), writing out both sides of liquidations, settlement price updates, and non-negative fees in `T1 ★` (`D40`), adding each coin held alone with funding to the bar and emitting span-end rows (`D36`), recasting the guard as a negative control (`D37`), stating Rung 2's sufficient condition on the full marked event (`D39`), and marking print staleness in the engine's trace for Layer 2's join (`D14-v6`) all hold under adversarial check.
2. **Checks 2, 3, 4, 5, 7 and Step 9:** Complete and sound with no remaining findings.

#### Specification Edits for Step 10 (No Architecture Dispute)

| ID | Item | Finding | Smallest Change | Blocks Architecture or Steps 0–9? |
|---|---|---|---|---|
| **D38-order** | Intra-tick order of funding vs. rebalance in `guard` (`B1` [kernel-v2.md](audit/program/kernel-v2.md#L292), Step 10 Test 14 [build-plan.md](audit/program/build-plan.md#L174)) | Finding 1 | State that at each tick, `guard` deducts the tick row's funding on the units held since the previous tick *before* rebalancing at that tick. | **No** (one-line clarification in `B1` / Step 10 Test 14) |
| **Step-10-OCaml** | Untested `decimation of the fast period, the block bootstrap` in Step 10 ([build-plan.md](audit/program/build-plan.md#L158)) | Finding 2 | Drop `the decimation of the fast period` from [build-plan.md](audit/program/build-plan.md#L158), and either defer `the block bootstrap` to Study 2's criteria ([L180](audit/program/build-plan.md#L180)) or add its specification and test in Step 10. | **No** (one-line edit in [build-plan.md](audit/program/build-plan.md#L158)) |

#### Plain Verdict
**Converged** on the architecture, kernel semantics, test ledger, comparator, and laws (with the two one-line Step-10 specification edits in the table above applied before Step 10's test author runs). No open dispute remains between reviewer and architect. Study 2's criteria can be written and the build can proceed.
