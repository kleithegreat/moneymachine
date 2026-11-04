<!-- GPT (openai/gpt-6.1-sol#high), hunt of how the gate decides; started 2026-11-03 04:01 UTC (2026-11-02 23:01 EST), finished by 04:12 UTC (2026-11-02 23:12 EST). Static review of 3187aa8. -->
# Findings

Static review only: no edits, test runs, or data access. These are reachable cases, not claims that recorded campaigns encountered them. Findings from the named earlier reviews are excluded.

## 1. Closing costs disappear from the mechanism check

**Paths:** `kernel/mm/src/sim.rs:371–378,394–413,425–428`; `kernel/mm/src/main.rs:308–316`; consumed by `gate/agent/campaigns.py:104–109`.

Exposure attribution happens **before** boundary fills. If a fill closes a position, its fees and slippage reduce the next equity mark, but `held_prev[c]` is then false. Consequently, that cost enters the strategy’s returns but never enters either mechanism branch. Updating `value_prev` also prevents its later recovery.

**Concrete state:** equal numbers of true- and false-labelled round trips, each followed by a flat interval:

| Branch | Return attributed before exit costs | Omitted exit cost | Actual net |
|---|---:|---:|---:|
| True | +4 bps | 5 bps | −1 bp |
| False | +3 bps | 0.1 bp | +2.9 bps |

Keep the corresponding condition unchanged through each closing decision. The check reports true > false and **passes**, although net performance has the opposite ordering. The combined strategy can still have positive search performance.

This contradicts C3’s check on **net return per exposure** (`audit/criteria.md:372`) and paper §8’s mandatory removal of failed mechanisms.

- **Outcome changed:** mechanism failure → finalist; potentially promotion, and different Holm families for other finalists.
- **Likelihood:** closing into a flat interval is ordinary strategy behaviour. Whether it reverses the branch comparison depends on costs and the observed margin.
- **Identity:** fixing attribution changes the **frozen kernel identity**, not `harness_hash`.

## 2. Undefined predictions silently shrink the mechanism denominator

**Paths:** `kernel/mm/src/machine.rs:311–313`; `kernel/mm/src/sim.rs:373–376`; `kernel/mm/src/main.rs:308–316`; `gate/agent/campaigns.py:109`.

An exposure whose prediction condition is undefined is omitted entirely. The 10–90% requirement is then calculated over the remaining, defined exposures—not all exposures.

**Concrete input/state:** a valid boolean prediction uses an `if` whose otherwise branch divides by zero. Over 10,000 held coin-intervals:

- 9,900 conditions are undefined;
- 50 are true, with positive mean return;
- 50 are false, with a lower mean.

The code reports `share_true = 0.5` and passes. Each branch actually covers only **0.5% of exposures**, below the frozen 10% minimum (`audit/criteria.md:372`). Undefined values are neither reported nor charged against that minimum.

- **Outcome changed:** insufficient-coverage mechanism → finalist, potentially promotion.
- **Likelihood:** reachable through ordinary division, logarithms, window warm-up, or unavailable event inputs; deliberate subset selection is also expressible.
- **Identity:** retaining/counting undefined exposures requires a **kernel identity change**; `harness_hash` need not change.

These first two defects change selection. They do **not**, by themselves, invalidate the betting theorem on a genuinely untouched holdout.

## 3. Swarm establishment ignores contradictory kernel identities

**Paths:** `gate/agent/campaigns.py:112–118,215–227,365–381,675–676`; `gate/kernel.py:16–21`; `gate/agent/harness.py:26–31`.

The series hashes `mm` once when loading inputs, potentially before a long pacing wait. Later evaluations execute the mutable binary pathname. Campaign rows nevertheless record the **old** hash.

`swarm_evidence` reconciles agent disclosures and counts filled trials, but never checks `experiments.kernel`. Thus its own ledger can identify a different kernel without preventing establishment.

**Concrete state:**

1. `series_inputs()` records kernel A.
2. While pacing waits, an ordinary local rebuild replaces `MM` with kernel B.
3. The campaign evaluates under B; its experiment rows correctly name B.
4. Agent audits and the gate complete normally.
5. The campaign is classified **established**, while its series row and summary name A.

Changing only the binary does not change `harness_hash`, so `check_frozen()` does not stop this. It violates the unchanged-kernel requirement of C4.5 v3 and the paper’s single frozen pilot kernel.

- **Outcome changed:** an invalid-procedure campaign can count as established rather than unresolved, potentially changing **failed → pass**.
- **Likelihood:** low in an immutable, digest-pinned deployment; realistic for a locally running series sharing a Cargo output directory.
- **Identity:** rejecting inconsistent ledger identities in `campaigns.py` changes **neither** named frozen identity. Adopting a different kernel still requires fresh judged evidence.

## 4. `REPLACE` bypasses the ledger’s append-only triggers

**Paths:** `kernel/mm/src/ledger.rs:17–30,68–76`; downstream readers `gate/gate.py:229–234,245–254`.

The ledger blocks explicit `UPDATE` and `DELETE`, but not replacement inserts. With SQLite’s `recursive_triggers` disabled, `INSERT OR REPLACE` deletes a conflicting row without firing its DELETE trigger. The code does not enforce a setting or insert guard preventing this.

**Concrete input:** through a writable SQLite connection with `recursive_triggers=OFF`, replace an existing holdout `results` row while preserving its `experiment_id`. Supply 100 returns of `0.1` and a positive `total_return`.

The replacement succeeds despite the append-only triggers. `committed_holdout` trusts the replacement without verifying `result_hash`; with one finalist, `promote` obtains approximately \(1/1.05^{99}<0.01\) and promotes it.

- **Outcome changed:** a recorded non-promotion can become a promotion; disclosures or selections can likewise be replaced.
- **Likelihood:** low: this requires a trusted database writer issuing replacement SQL. Existing campaign writers do not do so, and this is **not** a sandbox escape.
- **Identity:** a schema/trigger repair changes the **frozen kernel identity**, not `harness_hash`. Merely enabling recursive triggers on the kernel’s connection would not protect other connections.

## Where I found no additional outcome-changing bug

- **DSR, SPA and StepM:** revised DSR normalization and degeneracy rule, loss signs, consistent SPA p-value, bootstrap block parameter, screened-family selection, and effective-N diagnostics.
- **Holdout mathematics:** predictable betting fractions, inclusion of initial wealth, empty-series p-value, finite/bound checks, Holm ordering and ties, and positive-return requirement.
- **Sweep calculations:** mixed-market truth uses fresh market IDs; FDR, crash accounting, power counts and confidence-bound formulas match their stated rules.
- **Nulls and planting:** funding-price cancellation, planted-signal lag, N2 clipped-innovation recursion, and the separate event RNG supplied no additional demonstrated leakage path.
- **Budgets and swarm verdicts:** ordinary evaluation reservations count duplicates and rejections; valid-class verdict arithmetic matches v3. I found no additional intact-record wrong-class path beyond finding 3.
- **Ledger commits:** successful experiment/result/disclosure insertion is atomic.

**Unranked:** N3’s unstated volatility cap and clipped rather than rejection-truncated jumps (`gate/markets.py:170–174`) are specification differences; I did not establish a changed frozen-parameter outcome. The previously documented 539/359-step terminal-window discrepancy is not ranked anew.
