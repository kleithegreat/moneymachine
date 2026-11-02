# Findings

Ranked by consequence. This is a static review: no edits, test execution, or data access. These are reachable failure cases, not claims that recorded campaigns suffered them. Stage 3’s recorded zero-finalist outcome leaves the real holdout-release defects below unexercised.

## 1. Recovery can commit promotions before the previous holdout process has finished

**Path:** `gate/gate.py:199–205` launches `mm holdout` as an ordinary child. The campaign lock in `gate/campaign.py:54–59` is not passed through that exec. If a non-PID-1 runner is killed after the claim, its kernel child can remain alive.

A replacement runner acquires the lock, sees the claim, and skips release (`gate/agent/campaigns.py:499–505`). It immediately reports whatever results are currently committed. Unfinished finalists become `ABSENT`, with p-value 1 and return 0 (`gate/agent/campaigns.py:456–461`; `gate/gate.py:226`).

The old child can subsequently commit its in-flight result before discovering its broken stdout pipe (`kernel/mm/src/main.rs:385–393,486`). The already-committed promotion decision then disagrees with the completed ledger; another report is refused at `gate/agent/campaigns.py:447–448`.

- **Outcome:** wrong missing-result recordings, potentially a lost promotion, and an irreconcilable recovery report.
- **Likelihood:** low in the documented cluster deployment: Python is PID 1, so namespace teardown kills remaining children. Reachable for a locally launched real campaign killed during release.
- **Frozen identity:** an orchestration fix in `campaigns.py`, `campaign.py`, or `gate.py` need not change the named frozen hashes. A kernel-based fix would change the judged kernel.

## 2. Stage 4’s evidence checks can accept campaigns whose required audits failed

**Concrete state:** all four agents evaluated something and exchanged history, but one kernel dies during an evaluation. `Daemon.eval` returns and logs `KERNEL` without a corresponding ledger abort (`gate/agent/daemon.py:62–64,126`). The model session can subsequently finish normally.

`audit_run` detects the extra expected abort (`gate/agent/campaigns.py:60–87`). Nevertheless:

- `counts_as_promotion` ignores audit failures (`gate/agent/campaigns.py:169–173`);
- the summary merely stores those audits (`gate/agent/campaigns.py:551–557`);
- the stage-4 evidence test checks counts, history and total evaluations, **not those audits** (`criteria/test_stages3to5.py:39–42`).

Ten such otherwise satisfactory rows can pass that test despite violating the per-campaign C4.3 audit requirement (`audit/criteria.md:458–474`). Stage 3 has an explicit equivalent audit check; stage 4 does not.

- **Outcome:** an automated stage-exit check can pass invalid evidence.
- **Likelihood:** conditional on a kernel/recording failure; directly relevant to the running swarm series.
- **Frozen identity:** fixing the evidence check alone changes none of the named frozen identities. Fixing daemon behavior changes `harness_hash` and requires fresh campaign evidence.

## 3. The frozen harness does not hash `DSL.md`, although every agent reads it

`build_workspace` copies `kernel/DSL.md` into the agent’s workspace (`gate/agent/harness.py:21–23`). `harness_hash` hashes the other research documents and implementation files, but omits that file (`gate/agent/harness.py:26–31`).

Thus changing the DSL instructions produces different agent input while `check_frozen` still succeeds (`gate/agent/campaigns.py:55–57`). Null campaigns and a real arm can run under different instructions while recording the same harness identity.

- **Outcome:** invalid calibration/procedure identity; the recorded freeze does not identify everything supplied to the agent.
- **Likelihood:** dormant while images and documentation remain unchanged; triggered by an otherwise ordinary DSL-documentation update.
- **Frozen identity:** **yes**. Repairing the hash changes `harness_hash`, forcing fresh null IDs and, for a changed real arm, a later holdout. It does not itself change the thesis manifest or kernel.

## 4. An empty evaluation file can hang the campaign beyond its wall-time limit

**Input:** `./mm-agent eval empty.json`, where the file is empty or whitespace-only.

The daemon spends a budget slot, sends a blank line, then waits for a response (`gate/agent/daemon.py:56–62`). The kernel explicitly filters blank stdin lines and waits for another program (`kernel/mm/src/main.rs:294–297`). No response arrives.

Killing the model at its wall limit does not resolve this: `run_agent` calls `daemon.close()` before writing its run record (`gate/agent/harness.py:39–44`). That closes the server before closing kernel stdin (`gate/agent/daemon.py:133–136`); `server_close()` waits for the blocked request handler (`sandbox/server.py:25–30`).

- **Outcome:** no completed run/result recording; the series stalls until externally killed, after which recovery counts the campaign as a crash/promotion.
- **Likelihood:** low but straightforward—one accidentally empty strategy file suffices.
- **Frozen identity:** **yes** for a daemon fix. A shared-server fix would also change the thesis manifest.

## 5. A torn series-log append prevents the promised crash recovery

**State:** a runner dies while appending its campaign result, leaving a final fragment such as `{"id":"swarm-null-2-N2-5",`.

Results are appended directly to JSONL (`gate/agent/campaigns.py:294–295`). On restart, `campaign.resume` calls `recorded`, which unconditionally parses every line (`gate/campaign.py:46–47,67–74`). The fragment raises `JSONDecodeError` **before** the started directory can be recorded as an interrupted campaign.

Every subsequent restart fails at the same point.

- **Outcome:** interrupted campaigns remain unrecorded and the remainder of the series cannot run; a stage can be blocked indefinitely.
- **Likelihood:** uncommon, but a concrete abrupt-termination or partial-write failure in the very path intended to recover from interruption.
- **Frozen identity:** no change to the named hashes is required for a recording/recovery fix.

## 6. One experiment identity can name different committed results

For a program carrying a prediction, evaluate it normally and then with `--mechanism on`—the normal agent-to-mechanism-check path.

The experiment identity does not include the mechanism flag or prediction (`kernel/mm/src/main.rs:335–340`; `kernel/mm/src/dsl.rs:570–605`). But enabling the check adds a mechanism result to the summary, and that summary participates in `result_hash` (`kernel/mm/src/main.rs:342–348`).

Consequently, the ledger can contain identical experiment identities with different summaries and result hashes. Changing only the prediction can similarly change the mechanism result without changing the identity.

- **Outcome:** invalid determinism/identity evidence under I7 (`audit/criteria.md:106`); not, by itself, a demonstrated wrong trading promotion.
- **Likelihood:** routine whenever a finalist reaches the mechanism check.
- **Frozen identity:** **yes: the kernel**. Adopting the changed binary in the thesis track would also change its manifest.

## 7. Agent selections discard parameter values and use the wrong identity namespace

On successful evaluation, the daemon remembers `disclosure.strategy`, not the trial identity (`gate/agent/daemon.py:71`). `select` records that value (`gate/agent/daemon.py:100–106`).

For example, evaluate the same parameterized weight program at sizes 0.01 and 0.02, then select either one. Both selections record the same strategy hash: canonical strategy identity excludes parameter values (`kernel/mm/src/dsl.rs:594,608–618`), while a trial includes them (`kernel/mm/src/ledger.rs:6–12`).

The mismatch is explicit downstream: `Ledger.selected` supplies the identifiers that holdout validation compares against **trial** keys (`kernel/mm/src/main.rs:422–431`).

- **Outcome:** the selection table cannot distinguish which parameterized candidate the agent chose. Current campaign promotions avoid this because the gate freezes its own trial keys rather than using agent selections.
- **Likelihood:** normal parameterized research; not an exceptional failure.
- **Frozen identity:** **yes**, because the recording fix is in the hashed daemon.

## 8. The real comparison reports equivalence classes as “distinct canonical strategies”

`comparison` computes `COUNT(DISTINCT equivalence)` and labels it `distinct_canonical` (`gate/agent/campaigns.py:516–520`).

A strategy with weight `x` and one with weight `mul(x, 1)` have different existing canonical strategy hashes, but share an equivalence key under the frozen rewrite rule (`kernel/CANONICAL.md:3,29`). After evaluating both, the report says one distinct canonical strategy instead of two.

- **Outcome:** a wrong C3.4 comparison count; no direct promotion change.
- **Likelihood:** plausible in ordinary adaptive research and mutation-based searches.
- **Frozen identity:** none of the named hashes needs to change for this reporting correction.

## 9. Memory sizing ignores limits on ancestor cgroups

**State:** the process’s own cgroup has `memory.max = max`, but its parent is limited to 2 GB and already uses 1.5 GB.

`available()` examines only the immediate cgroup (`gate/compute.py:11–14`), so it can return the host’s much larger available memory. `workers()` then admits several approximately 1-GB campaign workers (`gate/compute.py:18–21`; `gate/sweep.py:57–67`) into a hierarchy with only 0.5 GB remaining.

- **Outcome:** avoidable OOM deaths, lost work and crash-counted campaign outcomes.
- **Likelihood:** low for the documented directly capped scopes/containers; reachable under nested capped cgroups. The live swarm does not use this worker-sizing function.
- **Frozen identity:** no named frozen identity changes for a `compute.py` correction.

## Areas without a serious finding

I found no separate serious defect in the implemented DSR, betting p-value or Holm calculations, or in the ledger transaction that atomically commits an experiment, result and disclosure. The real recovery rule retaining missing finalists in Holm with p-value 1 is correct; finding 1 concerns deciding that a result is missing before its writer has stopped.
