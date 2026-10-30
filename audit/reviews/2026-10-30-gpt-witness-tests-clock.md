**The witness optimization is sound for the current pilot semantics. Keep it. The clock blocker is real; do not clear it with a two-field `adjtimex` log alone.** I found two substantive weaknesses in the test changes.

Reviewed at `65902b2`. I made no changes, ran no tests or workloads, spawned no reviews, and did not access withheld data.

## Findings, ranked by consequence

### 1. High — The cluster does not yet establish clock-valid availability

The failure is straightforward:

- `ingest/sources_record.py:25–28,44` invokes `timedatectl`; exceptions become recorded errors at lines 55–57.
- `ingest/availability.py:190–193` accepts only numeric offset readings. With none, `merge` drops the host’s polls (`:88–93`).
- C0.3 requires a bracketed, sufficiently frequent and fresh **host NTP record** (`audit/criteria.md:51–53,69,81`).

**That fail-closed behavior is fine. Preserve it.**

However, two documents overstate the available evidence:

- `CLUSTER.md:74–75` calls the venue-server offset the clock check.
- `audit/cluster/handoff.md:45–49`, introduced in `342b9fd`, infers approximately 5 ms clock agreement from similar median L2-snapshot offsets.

Similar medians do not establish a per-host maximum error throughout the recording. They also do not remove snapshot-age and network-timing confounding—the rejected instrument’s original problem. The handoff’s operational reconciliation may stand, but **its clock acceptance does not**. Append a correction to `audit/decisions.md:285`, rather than treating that check as passed.

Also, the blocker’s citation is slightly wrong: the rejected instrument’s dated revision is **2026-10-21**, not October 22 (`PROGRESS.md:46`; `audit/criteria.md:46–52`).

#### Is `adjtimex.maxerror` a legitimate bound under chrony?

**Conditionally yes—not an inherently bogus field. But the proposed record is insufficient.**

Chrony actually maintains it:

- [`reference.c`, `update_sync_status`](https://github.com/mlichvar/chrony/blob/4.8/reference.c) supplies root delay/2 plus dispersion.
- [`sys_generic.c`, `set_sync_status`](https://github.com/mlichvar/chrony/blob/4.8/sys_generic.c) adds outstanding system-clock correction.
- [`sys_timex.c`, `set_sync_status`](https://github.com/mlichvar/chrony/blob/4.8/sys_timex.c) writes the kernel’s maximum-error field.

Important qualifications:

1. These are daemon/model-derived bounds, conditional on the upstream clock and model being correct—not independently measured absolute UTC errors.
2. On Linux, chrony clears `STA_UNSYNC` only when `rtcsync` is enabled. Therefore “chrony runs” alone does not establish the proposed interpretation or operational behavior.
3. **Changing `maxerror` does not prove a new NTP exchange.** Linux increments it automatically in [`second_overflow`](https://github.com/torvalds/linux/blob/v6.17/kernel/time/ntp.c). Feeding it into the existing “value changes within 40 minutes” check would defeat that check’s purpose.
4. The record must identify the actual node and clock, establish the deployed daemon/configuration, handle syscall failures and synchronization errors, and establish freshness separately.

Thus I would not label `maxerror` as `offset_ms`, nor approve `maxerror < 1 s && !STA_UNSYNC` as the entire acceptance instrument. A dated paragraph under **C5.3 alone also cannot change C0.3**.

### 2. Medium — The new guards can produce false “mutant caught” results

Commit `a472e9f` adds global pytest timeouts; `9301b81` adds the resident-memory termination mechanism.

But `kernel/mutants/mutants.py:96–105` declares a mutant caught whenever:

```text
clean == 0 and mutated != 0
```

Consequently, a mutated pytest process timing out or being killed by the memory watcher can count as successful invariant detection without the intended assertion ever firing.

The broad nonzero-exit classification predates these commits; the new guards add practical new ways to trigger it. **This is a possible false-positive path, not evidence that a recorded mutant result actually used it.**

Require structured evidence that the intended test reached its expected assertion failure. Treat timeout, resource termination, collection/setup error and build failure as **inconclusive/broken**, not “caught.”

### 3. Medium — The xfails mask more than the recorded exceptions

Commits `b30dc92` and `ef74efc` mark whole tests:

- `criteria/test_stage0.py:55–64`
- `criteria/test_stage2.py:64–70`

`strict=True` correctly makes an unexpected pass fail. `raises=AssertionError` correctly leaves many exceptions unmasked. **Those choices are useful, but insufficiently narrow.**

Examples:

- C0.7 could acquire another failing cell or insufficient sample counts and remain an expected failure. Its loop already stops at the first failed assertion.
- C2.6 could change from “power too low” to “wrong campaign count,” and remain an expected failure.

Furthermore, the decision’s claim that a missing evidence file fails is false: `criteria/evidence.py:15–16` explicitly **skips** it (`audit/decisions.md:334`).

Keep ordinary passing tests for evidence presence, schema, identity, sample counts, unaffected requirements and the recorded failure set. Narrow any xfail to the specifically waived predicate. Merely changing the marker’s reason does not constrain what it masks.

### 4. Low — The memory guard now has deliberately narrower coverage

`9301b81` replaces an inherited allocation limit with a polling watcher of the pytest process’s own RSS (`conftest.py:10–25`). Children are excluded; brief peaks can escape between samples.

This does **not** weaken the substantive assertions, and removing the limit that broke Lean subprocesses is reasonable. But aggregate protection now depends on actually using an external memory-limited scope. `-n auto` itself provides no such guarantee.

## Review 1: witness equivalence and independence

### Equivalence: accepted

For fixed dataset contents, policy and version \(v\), `Store.as_of` computes a time-independent resolved frame \(R_v\), then applies its only use of `t`:

```text
as_of(t, v) = R_v.filter(knownAt <= t)
```

Evidence: `ingest/store.py:117–125`, principally established by `fe499be`.

Since every witness decision precedes `HOLDOUT_START` (`ingest/witness.py:105,135`; `DELTA < BAR`), filtering the end snapshot produces exactly the earlier view.

This includes the awkward cases:

- **Correction:** its effective `knownAt` is computed before either time filter. Before that time, both implementations hide the key; neither falls back to its original revision.
- **Tombstone:** the version’s latest tombstone removes the key before either time filter. Both therefore omit it even for earlier decision times.
- **Restoration:** both resolve the same latest restored revision and apply the same availability rule.

That is the pilot’s explicitly amended **snapshot** behavior (`audit/criteria.md:21–30`), not ordinary bitemporal history reconstruction. Its limitations remain; this optimization does not introduce them.

The dictionary lookup preserves the unique `(coin,eventTime)` selection, inclusive availability boundary, hold behavior and arithmetic (`ingest/witness.py:90–91,139–153`). **No C1.4 comparison was removed.**

### Evidence: adequate argument; execution claims not independently reproduced here

`1f15657` provides:

- A valid source-level equivalence argument.
- A regression test exercising corrections, tombstones and restorations (`ingest/tests/test_store.py:78–87`).
- Reported byte-identical traces and exhaustive per-decision frame comparisons (`audit/stage1/witness-equivalence.md:7–18`).

The hashes alone would not prove general equivalence. The source argument does, within the stated fixed-snapshot assumptions. I could inspect the test and recorded claims, but not independently reproduce the production trace comparison in this data-free worktree.

### Independence: preserved, with the existing boundary

The witness still implements its own portfolio, decisions and accounting and does not import kernel execution or kernel-produced views. Sharing the dataset, policy and Python store does not become a new dependency because it materializes their result once.

It remains **independent execution, not an independent specification of ingestion correctness**. C1.4 cannot catch every shared interpretation mistake.

Do not carry this optimization unchanged into stage 7: the bitemporal revision at `audit/criteria.md:961` explicitly changes the property on which it relies.

### Other speed changes that are fine

- **`dcfe4b1`:** per-rule seeds, cases, assertions and nontriviality thresholds remain intact; thread panics propagate through `join().unwrap()` (`kernel/mm/tests/rules.rs:260–289`).
- **`b6b7391`, scoring differential:** sound partitioning. The initial state is anchored to seed 1010; every chunk must end at the next recorded state; total cases and disagreement checks remain (`thesis/tests/test_scoring_differential.py:63–72`). This establishes continuity by induction, rather than trusting unrelated chunk seeds.
- I inspected the state file’s structure: **17 distinct states**, initial state matching seed 1010, with Gaussian caches retained. `read_states` restores the complete state tuple (`thesis/tests/scoring_gen.py:111–112`). The independent scorer remains separate.
- **Store fixture reuse:** the randomized inputs and 1,000-example requirement are unchanged; it removes repeated construction of an otherwise fixed store.
- **`ef74efc` dev-shell launch:** no substantive check weakened.

## Review 2: what I would do

**Prefer a node-native chrony monitoring record, exported read-only to the recorders.** Have the homelab owner provide it; do not bypass the namespace restriction (`audit/decisions.md:304`), grant recorder pods `CAP_SYS_TIME`, or expose chrony’s full administrative Unix socket.

Use native tracking information, including the remaining **system-clock correction**, not merely “Last offset.” Chrony documents:

\[
E = |\text{System time correction}|+\text{Root dispersion}+\tfrac12\text{Root delay}.
\]

See the [chronyc tracking documentation](https://chrony-project.org/doc/4.8/chronyc.html). Record reference freshness and synchronization state separately.

Update consumers with a typed distinction between **offset observations** and **error bounds**. Do not disguise one as the other.

Dependencies:

- Missing historical evidence remains missing; today’s good clock cannot validate yesterday.
- Future C0.3/C0.7 windows may use the cluster only after the amended instrument and existing host-eligibility rules are satisfied.
- C5.3 hosts coverage must exclude clock-invalid contributions. Current `sources_avail.analyze` neither implements multi-host coverage nor establishes per-poll clock validity (`ingest/sources_avail.py:31–74`).
- Preserve the prospective-only qualifications and deferred C5.6 requirement; a clock repair does not admit claimed historical timestamps.
- Existing stage-0 judgments and C1.4’s pinned replay do not need reopening merely because a later recorder’s logging broke.
- **Keep Oracle’s working clock logger** until a replacement on Oracle itself is validated. A prodesk7 record cannot replace the VM’s record.

### Exact proposed revision

Append under **C5.3**, with an explicit cross-reference appended under **C0.3**:

> **Revision proposed 2026-10-30: chrony-host clock evidence. Effective prospectively upon approval and commencement of the new record.**
>
> On a host disciplined by chronyd, clock evidence may be obtained from that host’s native chrony monitoring interface. A node record may serve several recorder pods only where their use of the same host CLOCK_REALTIME is established and recorded. Host and boot identities remain distinct.
>
> The collector records, at least every five minutes: host and boot identity; daemon version and configuration identity; query send and receive times; monotonic acquisition times; selected reference identity; synchronization and leap status; reference measurement time and age; remaining system-clock correction; root delay; and root dispersion. Errors and missing fields are recorded, never replaced by zero. Records are retained append-only.
>
> A valid reading requires synchronization to an external reference, a reference measurement no older than 40 minutes, finite correction and nonnegative finite delay and dispersion, and
> `E = abs(system-clock correction) + root dispersion + root delay / 2 < 1 second`.
> This is a daemon-derived error bound conditional on the reference and clock model, not a measured signed offset. Bounds and offsets are reported separately.
>
> Valid readings must bracket the interval being certified, with no consecutive readings more than ten minutes apart. Acquisition delays are recorded and accounted for conservatively. Reboots, detected clock steps, missing evidence and invalid readings break clock-valid coverage; coverage resumes only with fresh valid evidence. Numerical changes alone do not establish a fresh NTP exchange.
>
> For the hosts revision, a poll may contribute to coverage or earliest-valid-observation selection only with qualifying evidence for its own host and clock. Source cadence, completeness, deterministic duplicate resolution and gap rules remain unchanged. A fresh 72-hour segment under this instrument is reported beside the original result. Earlier failures and missing evidence remain recorded; no earlier interval is retrospectively qualified.
>
> Prospective-only classifications and the C5.6 gate remain unchanged. This revision tightens clock-valid hosts coverage and does not relabel prior failures as passes.
>
> **C0.3 cross-reference:** For future windows on chrony hosts, the instrument above replaces the systemd-timesyncd-specific offset and numerical-change instrument. The existing bracketing, ten-minute-gap, whole-host exclusion, 24-hour eligibility and earliest-window rules remain in force. Earlier judged evidence is unchanged. Kernel `maxerror` changes alone are not evidence of exchange freshness.

That is the repair I would approve—not a venue-time substitute and not an unqualified two-field kernel record.
