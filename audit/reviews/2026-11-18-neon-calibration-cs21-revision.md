# Neon's blind calibration: the drafted revision to study 2's criteria (round 4's D190)

Model `gemini-4-neon-xhigh` through agy, from a clean folder holding only the bundle `neon-calibration.md` (exactly GPT's materials and prompt, rebuilt from `rearchitecture` `3f911d1`). The pass bar was fixed in `audit/decisions.md` before the reply was read. The reply, verbatim:

# Review of the Proposed Dated Revision to Study 2's Criteria

## 1. False discoveries and operator levers

### F1. Wall-clock definition of "the last midnight the record reaches" fabricates CS2.1, CS2.2, and CS2.3 passes on a stopped record
- **Severity:** **Fatal (do not commit).**
- **Construction:** `draft-revision.md` redefines *"the last midnight the record reaches"* solely as *"the last midnight 31 days or more before the replay starts"* (`T + 31 days ≤ s`), with no bound from the actual end of the recorded data. Meanwhile, silent streams are treated as staleness (A3), and `R_SETTLEMENT_MISSING` fires only for *held* coins missing a due funding event (A9, A18). Three failure modes follow immediately when the recorder stops early (e.g., its volume fills around 2027-05-20, the foreseeable wall in `brief4-step7.md`):
  1. **CS2.1 ("Earned" and "Outgrew") on a zero-edge strategy:** Take a two-coin universe (Coin X, Coin Y; leverage 1). Over Days 1–100, Coin Y stays at `100` (`B̄ = 1`), while Coin X drops `100 → 90` in one print (`sum1 = −0.10`, `sum2 = 0.01`, `sum3 = −0.001`). By chance, on Day 100 the test ledger holds cash `0` and `19.5/90` units of Coin X (`Wᵇ = 19.5 < 20 = 20 × B̄`). On Day 100 the websocket recorder's volume fills and stops, while the separate, tiny `fundingHistory` collector keeps running. Over Days 101–115, Coin X crashes in reality and trades at a discount, paying negative funding `ρ = −0.0001/h` for 360 hours (`−3.6%`); Coin Y has `ρ = 0`. Because `T` keeps advancing with `s`, the replay runs through Day 115: Coin X is stale (no orders fill, price and bid stay frozen at `90`), `fundingHistory` prevents `R_SETTLEMENT_MISSING`, and V8 settles funding at the coin's frozen price `90`. Cash increases by `+0.702`, raising `Wᵇ` to `20.202 ≥ 20`. Meanwhile, Coin X's `sum1 = −0.064 < 0`, `sum2 > 0.01`, `sum3 < −0.000999`, and held-alone value `0.9324 < 1`, so `D = 0` and `B̄` remains exactly `1.0`. Freezing the mark while crediting crash-driven negative funding breaks the martingale null (K3) and increases false discoveries.
  2. **CS2.2 ("the volatility held") on a stopped record:** Over Days 1–100, forward variance is `3 v₀` (mean 0; outside `√2`). On Day 100 the account is flat and *all* recording stops. Because no coin is held, `R_SETTLEMENT_MISSING` never fires; replays advance to Day 212 with 112 zero-return days, diluting variance to `(100/212)·3 v₀ ≈ 1.415 v₀ ∈ [0.5 v₀, 2 v₀]`. Letting storage fill while flat also gives the operator a lever to convert excess volatility into `"held"`.
  3. **CS2.3 ("met") on fewer than 61 days:** Over Days 1–40, replica and vault match >50% of entries; both recorder and `mmvault` stop on Day 40 while flat. Twenty-one empty days pad the run to Day 61 with an intact vault chain.
- **Outcome changed:** Under the committed text (`criteria-study2.md`), a stopped record ends at Day 100 (or Day 40): CS2.1 is `"Not confirmed"`, CS2.2 is `"not judged"` (and CS2.2 explicitly states *"It cannot make 'held'"*), and CS2.3 is `"not judged"`. Under the revision, CS2.1 becomes **`"Earned"`** and **`"Outgrew"`**, CS2.2 becomes **`"the volatility held"`**, and CS2.3 becomes **`"met"`**.

### F2. Replay start time remains a lever—and can lock in a phantom crossing—whenever any writer or file sync lags past 30 days
- **Severity:** **Fatal (do not commit).**
- **Construction:** Monthly replay timing is unconstrained (*"once a month from February 2027"*). `draft-revision.md` claims *"when a replay starts changes nothing"* on the unverified premise that writers never write past 30 days, yet `brief4-step7.md` itself models suspended writers, delayed host transfers, stepped clocks, and items written 40 days late (and `ledger-round4.md` notes `mmvault` still pulls 30 days behind its watermark). Suppose on Day `D` (ending `T_D`), a zero-edge strategy holds Coin X with `Wᵇ = 20.5 ≥ 20` at `22:59 UTC`; at `23:30 UTC` Coin X crashes 30%, so true midnight wealth is `Wᵇ = 14.35 < 20`. Suppose recorder file `T23` is delayed in host sync until `T_D + 35d`, while `T22` and hour `23:00` funding are already on disk at `T_D + 32d`. Day `D`'s public market prices are already 32 days old, and `mm2 inspect` / operational logs reveal the missing hour. Starting the replay at `T_D + 32d` (before `T23` lands) treats `23:00–24:00` as staleness at the frozen `22:59` mark and permanently binds Day `D`'s cut without `T23`; starting at `T_D + 36d` reads `T23`.
- **Outcome changed:** `"Not confirmed"` (full record) → **`"Earned"`** (and **`"Outgrew"`** if `≥ 20 × B̄`), permanently discarding `T23` as late.

### F3. "First in the record's order" discards venue corrections inside the 30-day window
- **Severity:** **Fixable in the text.**
- **Construction:** On Day 10, the funding API returns a preliminary or erroneous rate `ρ = 0` (or negative) and restates it on Day 11 to `+0.0001` (29 days before replay; the pilot had 24 restated funding keys). Under the corrected rate, a zero-edge long-only ledger ends at `Wᵇ = 19.99 < 20`; under *"first in the record's order"*, the correction inside the cut is discarded, giving `Wᵇ = 20.01 ≥ 20`. If preliminary pulls systematically understate positive perp funding, a long-only ledger gains upward drift. Because the cut already freezes every day permanently after 31 days, *"first"* is no longer needed for cross-replay stability: *"last in the record's order within the cut"* is equally immutable while honoring venue corrections (retaining explicit priority for the pre-2026-11-01 vault copy if desired).
- **Outcome changed:** `"Not confirmed"` → **`"Earned"`** (and conversely an overstated first pull can break a true claim).

---

## 2. A true claim failing

### F4. Arbitrary-byte cuts of live hourly `.zst` streams can halt an honest replay
- **Severity:** **Fatal (do not commit).**
- **Construction:** Recorder files are hourly zstd streams read via `mmrec cat` (`kernel-v2.md` B2). When Replay 1 starts at `s`, it records the length `L` and hash of *"every file of the record"*, which includes the live hourly `.zst` file actively being written at time `s` (31 days after `T`). Unlike plain text, cutting a compressed zstd stream at an arbitrary in-flight byte `L` truncates a zstd frame mid-block (contradicting `brief4-step7.md`'s *"cut at any byte reads as the whole lines before the cut"*): Replay 2's decoder errors on the truncated prefix, or any close-time framing, compression, or rotation alters bytes `[0..L)` and trips the broken-recording hash check.
- **Outcome changed:** An honest confirming run halts (`"broken recording"`, publishes nothing) instead of running to `"Earned"` / `"Outgrew"`.

### F5. Pre-start cut binding plus wall-clock `T` permanently blinds an honest run on a delayed sync, late funding backfill, or forward clock step (and distorts CS2.2/CS2.3 on a stopped record)
- **Severity:** **Fatal (do not commit).**
- **Construction:**
  1. A coin is held on Day `D`, and a collector outage delays its funding row until `T_D + 35d`; a monthly replay at `T_D + 32d` binds Day `D`'s cut without it, triggering `R_SETTLEMENT_MISSING` and ending the study permanently at Day `D−1` (whereas under the committed text, running once the file arrives continues and confirms).
  2. If the replay host's clock steps forward (or files are unsynced) when `study2 forward` starts, the pre-start attempt row commits empty cuts for all days up to `s − 31d` in the append-only ledger, permanently ignoring real data as `"late"`.
  3. Under F1, an honest strategy with true variance `v₀` whose recorder stops flat at Day 100 receives 112 zero-return days (`variance = 0.472 v₀ < 0.5 v₀`), and if only the recorder stops at Day 40 while `mmvault` continues, the stale replica enters 0 times on Days 41–61.
- **Outcome changed:** A true confirming run is ended or blinded (`"Not confirmed"`); CS2.2 `"not judged"` → **`"the volatility did not hold"`**; CS2.3 `"not judged"` → **`"not shown"`**.

---

## 3. Consistency

### F6. Contradictions with committed criteria, uncapped horizon past Day 730, and misplaced CS2.2/CS2.3 gloss
- **Severity:** **Fatal (do not commit)** for (a); **Fixable in the text** for (b)–(d).
- **Construction:** No threshold or judged day changes, and CS2.3's *"shown more than 30 days late, or after the judging"* remains logically true (its second clause merely becomes redundant once judging waits 31 days). However:
  - **(a) Direct contradiction on stopped records:** Redefining *"the last midnight the record reaches"* as `s − 31d` contradicts CS2.1 (*"A record that stops ... ends it at the last day run"*) and CS2.2 (*"It cannot make 'held'"*) per F1.
  - **(b) No cap at the 730th judged day:** A final replay starting at `T_730 + 40d` runs through Day 739; shutting down the recorder after Day 730 while holding triggers `R_SETTLEMENT_MISSING`, and any post-Day-730 protected window triggers `R_PROTECTED` at `start`.
  - **(c) Inaccurate rationale:** *"The month's wait changes when a day is examined, never what it holds"* contradicts the cut rule itself—waiting 31 days specifically changes what a day's cut holds by capturing items written in days 1–30.
  - **(d) CS2.2/CS2.3 "first replay after":** The clarification sits *outside* the proposed revision blockquote and says *"whose horizon reaches it"* rather than *"that completes the 61st/212th judged day"* (a replay reaching Day 61 that aborts on Day 50 leaves CS2.3 `"not judged"`).
- **Outcome changed:** Spurious post-Day-730 aborts/rejections; conflicting readings of stopped records and of CS2.2/CS2.3 judging triggers.

---

## 4. Precision

### F7. Ambiguities where two implementers would read a day differently
- **Severity:** **Fixable in the text** (apart from `.zst` cuts in F4).
- **Constructions and outcomes changed:**
  1. **Day assignment of an item:** Unspecified whether days are half-open `[00:00, 24:00)` (matching A19) and which timestamp governs (`time` vs `known`—a listing at `23:30` with `lag = 1h` has `known` in the next day—vs funding `hour` `H` vs received/file time). Implementers bucket boundary events into different cuts.
  2. **Pre-freeze days and initial header state:** Vault fills replay *"from its first fill"* (months before `w_start`), and `w_start`'s initial coin rules come from pre-freeze `meta` snapshots. Unclear whether *"whose horizon reaches a day"* binds pre-freeze days (`day_end ≤ T`) or only judged days `[w_start, T)`, changing CS2.3's entry count if pre-freeze fills change.
  3. **Which attempts bind a cut:** A monthly replay invokes multiple runs (`pessimistic` 1,000 ms, diagnostic `optimistic` and 5,000 ms runs, vault fills, abort reruns). The revision omits the evaluation ledger, whether one shared cut governs all runs of a replay, and whether killed or `start`-rejected (`R_PROTECTED`, `E_HEADER`) attempts bind cuts.
  4. **Record membership, absent files, path order, mid-line cuts, unpinned reference, and hash failure:** Unspecified which file classes belong to *"every file of the record"* (`listings`? `userFunding`? temp/lock files?), that files absent from a cut have length 0 for that day, whether `brief4-step7.md`'s byte-for-byte path order uses paths relative to a canonical root (absolute paths break cross-host replay), and (inline) that mid-line cuts read only whole lines before the cut. The revision cites `briefs/4-study-2.md` without pinning a commit hash (unlike `criteria-study2.md`) and omits what a replay does when a cut hash fails.
  5. **Per-day deduplication vs timeless keys and validation order:** Vault fills are keyed by `(coin, trade_id, order_id)` without `time`; scoping deduplication *per day* fails to merge a fill whose timestamp crosses UTC midnight between two sources, double-counting it and breaking CS2.3's chain (`"not judged"`). Unspecified whether key deduplication precedes or follows dropping malformed/off-grid items: if the first item of a key is malformed and the second valid, Implementer A aborts while Implementer B continues.

---

## Verdict

**Do not commit.**

F1, F2, F4, and F5 are fatal: the revision increases false discoveries (breaking CS2.1's 5% bound and CS2.2's *"It cannot make 'held'"*), leaves an operator timing lever when writers/syncs lag past 30 days, and can halt or permanently blind honest runs on live `.zst` streams, delayed syncs, or clock jumps. Before resubmitting, redesign D189 and redraft the revision to: (1) bound `T` above by the actual end of the recorder's stream and by the 730th judged midnight, not just `s − 31d`; (2) define cut semantics compatible with `.zst` files without cutting live files from 31 days after `T` or permanently binding empty cuts on clock/sync faults; (3) use last-in-record-order within the cut for restated venue keys (or justify `"first"` and disclose the bias); and (4) resolve F6(b)–(d) and F7 inline or via a commit-pinned spec.
