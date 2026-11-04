# Independent review: the stage 10 thesis bundle, round 2, before a possible refreeze

**Scope.** I read everything you listed: CLAUDE.md, stage 10 of `audit/criteria.md` with its revisions, `thesis/SCORING.md`, the two hunts, GPT's F1–F9 review, the 2026-11-02 decisions, the round 2 report, the readings draft and every changed file whole. I compared each against `main`, and also read `ops/live.py`'s mirror, `ops/oci/{pull.sh,publish.py}` and the kernel's ledger busy timeout.

- This session could not execute anything (python and nix were denied), so none of this comes from running the tests. It is static reading plus hand arithmetic.
- No track data was read, and nothing was edited.

## 1. F1 to F9 against the criteria

Every fix holds. `ROUNDING` and the `1 + 1e-12` cap factor are gone. Every discrete decision now compares `Fraction`s against the frozen boundary, so no threshold is widened.

| | Hand check | Result |
|---|---|---|
| **F1** | N = 1000.0000000005, ref 100: the entry notional is exactly N, which is > 1000, so the 8 bp cell applies (`positions.py:65`). R_net ≈ −5.02e−4, o = 0.<br>Short from 100 closing at 110: R_gross = −1/10.<br>With L = 0.10000000000005, −1/10 ≤ −0.10000000000005 is false, so no trigger. With L = 0.1 it triggers (`:219–221`).<br>Cap with E = 10,000: 5 × 100 = 500 ≤ 500, so the fifth fits and the sixth is refused (`:242`). | Fixed |
| **F2** | P_in = 99.9450045·1.0001, P_out = 100.0550045·0.9999.<br>Then P_out(1−f) = 100(1−c²)(1−f²) = P_in(1+f), so q·[P_out(1−f) − P_in(1+f)] = 0 exactly, and `int(r > 0)` gives 0 (`:83,91`). | Fixed |
| **F3** | Builder long q = 10 at 100, registration at h+1 min: `settles(h)` fails because h + 300 s > the cutoff, so `book(h−1)` gives E_r = 10,000 and N = 1000.<br>At h + 5 min exactly, h reconciles with −10·0.001·M(h) and N = 999.9 (`:119–123,154–157`). Core behaves the same at δ. | Fixed |
| **F4** | Cached rows are projected to the cutoff: an open shows from H+δ, a close from H+1h+δ (`market.py:176–177`). The duplicate-row bug is fixed by keying on openTime. | Fixed |
| **F5** | Each thesis is resolved from its own legs (`runner.py:248–262`). A replay failure is recorded as `managed_failure`. `deadlines` reads only the ledger, each minute, on its own thread (`:264–271,294`). `at` is the time of the write. | Fixed |
| **F6** | p is the p_ref of the committed thesis, from its own N at t_r (`registry.py:153–159`). The probe is gone. | Fixed |
| **F7** | Interior holes are retried with no age limit. The leading hole is retried for 1h bars and funding, not for daily bars, as the draft states (`market.py:34,45–57,130`). | Fixed |
| **F8** | A stored body is checked against the response before reuse. A damaged one is moved aside with its bytes kept and logged on `repairs` (`datalayer.py:67–86,124–133`). A damaged discovery index is repaired before `body()` reads it. | Fixed |
| **F9** | Listings are read under the ledger lock, with t_r taken as that read returns. The read and its two times are recorded (`registry.py:142–150`). | Fixed |

The crash recovery and benchmark-enumeration fixes from the original hunt still hold. Their kill tests are real SIGKILLs (`test_runner.py:283–318`).

## 2. What the fixes broke or left

I found no position, score, admission or restart path that disagrees with the criteria as the draft reads them. Two items need action before the freeze (R1 and R2); the rest are lesser.

**R1. N cannot be audited from the record. Fix before the freeze; it is cheap, and it can't be added later without another fork.**
- **Where:** `registry.py:149–153` records t_r, the listings, and N, size and b. It does not record the data cutoff C, which the daemon takes before it fetches anything (`daemon.py:76`, `runner.py:90`). It also omits E_r, the reconciled hour and the existing reservations.
- **Why it matters:** under reading 2, N depends on C (`positions.py:140,154–157`). A later replay at the same C can legitimately differ in two ways:
  - a funding row the venue published after C is now cached;
  - an illiquid core market had no trade in [H, H+δ) when it was read, but a later read "as of C" shows H's open (`market.py:177`).
- **Realistic trigger:** a main-session registration around 01:00–01:05. The session runs 00:10–01:10 and the 01:00 lag ends at 01:02 (core) or 01:05 (builder). The inputs are fetched at 6 requests per minute and the commit waits for the lock, so C can precede t_r by minutes across that boundary.
- **Outcome it could change:** N, and size 0 against funded at the cap. C10.1's "reservations at the cap are exact" and C10.3's hourly reconciliation can't be checked on live data.
- **Fix:** record `cutoff`, `E_r`, `reconciled_hour` and `reserved` in the thesis.

**R2. The venue budget could stall sessions. Pre-existing, unverified, and window-wasting if true.**
- **The limit:** the adapter's budget is 120 weight a minute (`market.py:27`), deliberately what is left of the cluster IP's share (`audit/cluster/handoff.md:28`). At weight 20 that is 6 requests a minute.
- **First use of a market's funding:** a cold cache fetches 3 years of rows (`market.py:28`), about 54 pages at 20 + 25 weight each. That is about 20 minutes, and any account's first `register`, or even a refused attempt, on a market no account has used triggers it.
- **The snapshot:** it makes at least 2 requests per listed market (`runner.py:106–117`). Assuming about 200 listed markets, that is roughly an hour before a session starts.
- **Every `positions` or `register` call:** each one refetches every account market's tail (`runner.py:81–84`). With 20–30 markets in main, each call takes minutes, against Claude Code's default 2-minute Bash timeout.
- **What the diff changes:** resolution now fetches only due, unresolved theses, which is much cheaper than `main`'s all-markets pass. On the other side, the listing read waits in the rate limiter while holding the ledger lock, and hole repair adds requests.
- **Check:** the running version's session `started` against `taken`, and the spacing of its call records, answer this. That is integrity metadata, not prices. If it is confirmed, fix it in this fork: pre-warm funding caches in the background, and reuse tails within a call.

**R3. A funding row that never arrives freezes E_r for the rest of the version.**
- **Trigger:** a venue halt during which no funding settles for an hour while any position is open.
- **Consequence:** reconciliation stops at that hour forever (`positions.py:154–157`), so all later sizing uses the pre-halt equity.
- **Assessment:** this follows faithfully from "never assumed zero" plus "latest reconciled", and it is not a threshold change. The readings text should say so, and the report should show the reconciled hour (`report.py:72`).

**R4. Unresolvable theses are retried forever** (`runner.py:239–246`). Each pass costs about 2 requests per leg per such thesis from the same budget. It is low risk in 28 days and grows afterwards.

**R5. `resolve` and `deadlines` can race.** At T+90, `deadlines` can read the ledger before a `resolved` write lands and then add a "missing data" status (`runner.py:261,267–271`). `report.py:86` would list it. This is cosmetic.

**R6. The listing read comes before validation** (`registry.py:143–145`).
- A misspelled dex (for example `xzy:GOLD`) gives the agent "daemon error" instead of "not listed".
- Retries and backoff, around 30 s plus waiting for budget, happen while holding the ledger lock.
- **Fix:** check the legs' shape first, and treat an unknown dex as not listed.

**R7. Atomic writes leave transient `*.tmp` files** (`datalayer.py:128–133`, `runner.py:120–122`).
- The mirror lists every non-JSONL file and then stats or copies it (`ops/live.py:197–201,231`), so a `.tmp` that vanishes in between aborts that mirror run.
- On Oracle, rsync exits 24 for a vanished file, which `pull.sh` treats as a failed pull and records under Blockers until the next good pull.
- No data is lost. Excluding `*.tmp` in `ops/` is outside the manifest and can be done anytime.

**R8. Some agent-visible output changed.**
- The `register` response now includes `listings` and `listings_read` (`daemon.py:81`).
- In `positions`, exit legs now name their market and list only legs that actually exited (`positions.py:185–187`).
- Both are harmless, but they belong in the freeze record as changes to what agents see.

**R9. Exact-money denominators grow with the account.**
- **Why:** each entry reference's numerator enters cash through q = N/ref at exit and in funding, so the denominators grow about 5 digits per closed leg, and N's text grows the same way.
- **Size:** about 300 digits in the window, which is fine. After a year it reaches about 4–5k digits, which means seconds per replay, and the hourly report gets heavier.
- **Not a window risk.** The round 2 report's 0.62 s figure was measured on synthetic data; it should be re-measured with 5-significant-figure prices, which I could not run here.

**R10. Freeze-date timing (pre-existing).** `schedule` runs the freeze date's main session immediately if the freeze is after 00:10 (`runner.py:320`). Freezing between 00:00 and 00:10 UTC (19:00 and 19:10 EST) gives a clean first day.

## 3. The differential

It is sound and honestly reported.
- The raw table against GPT's untouched file is shown.
- Each of the five patches is shown to be needed by some scenario.
- GPT's side implements availability independently, from the full bars.
- Every mutant is caught, and the four caught only by boundary cases are disclosed.

What it cannot see:
- **The patched oracle is partly written by the builder.** Of its five source patches, one only changes the data shape (side-specific cost cells).
- **The cutoff rule is never tested independently.** In `ours_data` and `production`, the cutoff always equals `now` (`test_positions_differential.py:143–151,366`). Reading 2's cutoff sentence is checked only by unit tests.
- **The ledger path is not covered:** rational text in records, the listing read, `p_is_base_rate`.
- **Small denominators:** the scenarios use 2-decimal prices between 50 and 200, so the exact boundaries are covered only by the hand-built cases.
- **Only 3 release boundaries** are sampled per scenario.
- **The scoring path has no independent check at its exact boundaries.** `gpt_scoring.py` is still floats, so the cost-cell and zero-sign boundaries in the base rate and outcome are unchecked.
- **Venue publication delay is not modelled:** funding rows are visible exactly at h on both sides.

Recommendation: have GPT update `gpt_positions.py` and `gpt_scoring.py` from the committed readings, as it did on 2026-10-25, instead of the builder patching them. Then rerun C10.4 before the freeze, so a disagreement doesn't cost a window.

## 4. The readings

None of them loosens a threshold.

1. **Reading 1** (P_e is the reference open) is right. It matches SCORING.md, on which C10.4 was judged.
2. **Reading 2:**
   - The funding mark rule and the reconciliation rule are faithful.
   - The cutoff sentence departs from "sizing evaluated as of t_r" (criteria line 756) by the gap from C to t_r, which the code does not bound. It is defensible if it is stated like eligibility's read window, and if C is recorded (R1).
   - Add R3's consequence to the text.
3. **Reading 3** (a reservation's release) is right.
4. **Reading 4** is a reasonable choice. But "whatever the cache holds" is true for the cache, not for receipt: no rule makes a candle exist before its first trade. Say so.

Among the further points:
- **E_r ≤ 0:** rule for the code's choice. GPT's N = 0 makes R_net = total/N undefined, against "the same computation is done for size-zero theses".
- **Simultaneous exits:** I confirm only the label changes.
- **The other points** are right.

**Not ready to commit as written.**
- Strip the draft framing and the "Settles:" lines.
- Write the seven points as rules.
- Add R1 and R3, qualify reading 4, and stamp it with a UTC time.
- Then commit it alone as `criteria: stage 10`.

## 5. Also needed in this refreeze

1. SCORING.md's exactness line. The file is hashed into the manifest (`thesis/harness.py`'s `DATA`), and the line hasn't been written yet.
2. R1's recorded sizing provenance.
3. GPT's updated scorer and positions from the committed readings, with C10.4 rerun, all before the freeze.
4. The R2 measurement on the running version, and a fix if it is confirmed.
5. A freeze time between 00:00 and 00:10 UTC (19:00 and 19:10 EST) (R10).
6. Optional and outside the manifest: excluding `*.tmp` in the mirror and pull (R7).

## Verdict

**Not yet. REFREEZE once these are done:**
- **B1:** the readings committed with the edits in §4, and SCORING.md's exactness line.
- **B2:** sizing provenance recorded in the thesis (R1).
- **B3:** the venue-budget latency checked on the running version, and fixed if confirmed (R2).

No code defect in F1–F9 blocks. Fixing the lesser findings (R4 to R9) before the refreeze is cheaper than another window.
