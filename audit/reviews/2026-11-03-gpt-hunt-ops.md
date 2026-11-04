<!-- GPT (openai/gpt-6.1-sol#high), hunt of the sandbox, daemon as a leak, deploy and mirror tooling; started 2026-11-03 03:23 UTC (2026-11-02 22:23 EST), finished by 03:31 UTC (2026-11-02 22:31 EST). Static review of e756cef. -->
# Findings

Static review only: no edits, test execution, or data access. These are reachable failure paths, not claims that production encountered them. Ranked by consequence; findings already reported in the three November 2 hunts are excluded.

**Frozen identities:** Every finding below can be fixed entirely in `ops/live.py` or `ops/jobs.py`. Such fixes change **neither** `gate/agent/harness.py`’s `harness_hash` **nor** the stage-10 manifest hash. Rebuilding would change the image digest.

## 1. A seed destination can overwrite the mirror before any safety check

**Path:** `ops/live.py:146–159`.

The destination is joined directly onto the staging directory, without rejecting absolute paths or `..`.

**Concrete input:**
```text
seed <digest> agent /path/replacement.jsonl:../../hl/polls-20261102.jsonl
```

The staging copy resolves to `/srv/moneymachine/mirror/hl/polls-20261102.jsonl`. `shutil.copy2()` overwrites that mirrored recording immediately. The destination-content check in `seed_run()` happens later, on the cluster, and cannot protect this local copy.

- **Outcome:** lost backup recordings; potentially destruction of the surviving historical bytes during recovery from primary-volume loss. Subsequent verification can detect the damage but cannot recover overwritten bytes.
- **Likelihood:** low—requires an erroneous destination, not any documented seed command. It is nevertheless a concrete destructive input to tooling advertised as refusing conflicting overwrites.
- **Hashes:** neither.

## 2. Reseeding an existing live file can silently discard concurrent appends

**Path:** `ops/live.py:169–178`.

An existing file with the expected digest is **not skipped**: it is subsequently overwritten with `copy2()`. Seeding takes no writer lock.

**Concrete interleaving:**

1. The staged day file and live destination both contain bytes `A`.
2. The destination passes the digest check at line 173.
3. Its recorder appends recording `B`.
4. Line 176 truncates and replaces the destination with staged bytes `A`.
5. The final digest matches the seed, so seeding reports success.

An interrupted copy can also damage an existing file that had already passed the check.

- **Outcome:** lost recordings despite successful seeding, contradicting the non-overwrite guarantee.
- **Likelihood:** low under the documented practice of seeding immutable inputs; reachable when an operator reseeds a live recording tree.
- **Hashes:** neither.

## 3. Batch retries do not preserve the original kernel and calibration inputs

**Path:** `ops/jobs.py:190–202`, calling `submit()` at `:117–128`; consumption at `:158–170`; collection checks at `:218–221`.

`resubmit()` preserves the original image and sweep name but calls `submit()`, which stages the **current local** `mm` and `betas.json`, rather than retaining their original recorded hashes.

**Concrete state:** a mixed sweep partly completes using calibration file A. Before retrying its failed indices, the local calibration becomes B, while `mm` remains unchanged. The retry uses B. `collect(original, retry)` accepts the combination because it compares only sweep name and kernel hash—not calibration hashes.

- **Outcome:** wrong experimental recording: one purported sweep combines campaigns generated under different planted-effect calibrations. Its promotion/power results can change silently.
- **Likelihood:** conditional on inputs changing between submission and recovery. No batch is currently queued, but this is a normal future recovery operation, not malformed input.
- **Hashes:** neither. Changing the kernel between attempts instead normally makes collection refuse the combination.

## 4. Reusing a batch run name overwrites provenance before Kubernetes accepts the deployment

**Path:** `ops/jobs.py:120–129`; existing-result shortcut at `:146–148`; collection at `:218–231`.

`submit()` permits an existing result directory and overwrites its `record.json` **before** applying the Job.

**Concrete state:** run R completed under image A. Submit R again with image B and the same kernel/sweep. The record now names B, but Kubernetes rejects the existing Job’s immutable template change. R’s old archives remain. Collection does not check image identity and can accept those archives using the overwritten record.

There is an even quieter variant: change only the calibration file and reuse the same image/run name. The Job manifest remains unchanged; the already-completed Job is accepted without executing new tasks, while its record names the new calibration.

- **Outcome:** wrong image/input provenance attached to old recordings.
- **Likelihood:** low, requiring accidental run-name reuse; particularly relevant when retrying an apparently unsuccessful submission.
- **Hashes:** neither.

## 5. Concurrent pushes can return another build’s image digest

**Path:** `ops/jobs.py:52–61`, also used by `ops/live.py:348–349`.

The image is uploaded under a mutable short-commit tag, then its digest is obtained by inspecting that tag.

**Concrete interleaving:** two pushes have the same Git HEAD but different dirty tracked trees:

1. A uploads image A under the commit tag.
2. B uploads image B under that same tag.
3. A inspects the tag and returns B’s digest, alongside A’s local image path.

Digest-pinned deployment then faithfully deploys **B**, not the build A just produced.

- **Outcome:** wrong deploy and misleading build provenance. Frozen launch checks may reject changes to covered research code, but they do not protect operational code outside those identities.
- **Likelihood:** low; requires overlapping, different builds sharing a tag.
- **Hashes:** neither.

## 6. A leftover completed helper pod can make a new seed report success without copying anything

**Path:** `ops/live.py:117–130`; fixed seed pod name at `:161–163`.

`run_pod()` applies a fixed-name Pod and treats its existing terminal phase as the result of the new invocation.

**Concrete state:** `seed-agent` succeeds, but the invoking process dies before deleting it. The operator stages different seed inputs and retries with the same image. Those inputs are not part of the Pod spec. Applying the unchanged completed Pod does not rerun it; `run_pod()` immediately reads its old successful log and returns success.

The newly staged files were never copied. Fixed-name gate pods have the analogous stale-result problem.

- **Outcome:** falsely successful seeding, missing deployment inputs, or a stale health verdict.
- **Likelihood:** uncommon, but directly reachable after client interruption or connectivity failure during helper-pod cleanup.
- **Hashes:** neither.

## 7. The deployment “gate” reports success when its checks fail

**Path:** `ops/live.py:313–327,337–343`.

The gate records diagnostics but never evaluates them:

- pytest’s return code is discarded;
- differing current/frozen harness hashes are merely printed;
- failed session results and exceptions become ordinary JSON fields;
- refused or unexpectedly reachable network destinations do not fail the command.

`gate_run()` consequently exits successfully, the Pod becomes `Succeeded`, and `gate()` prints `ok`. Even an actually failed Pod only produces printed `FAILED`; the outer command does not raise an error.

**Concrete state:** pytest reports failed isolation tests, or `harness` differs from `frozen`. The same invocation still reports `ok`.

- **Outcome:** false health/acceptance report. The detailed JSON may expose the failure to a careful reader, but neither the success label nor exit status represents it.
- **Likelihood:** whenever a tested deployment is broken—the precise condition the gate should reject.
- **Hashes:** neither.

## 8. Mirror verification can report corruption while a healthy mirror publishes its next generation

**Path:** independent CronJobs at `ops/live.py:51–54,107–108`; snapshot replacement at `:206–213`; manifest publication at `:239–241`; verification at `:249–251`.

`concurrencyPolicy: Forbid` prevents overlap within each CronJob, not between `mirror` and `mirror-verify`.

**Concrete interleaving:**

1. Verification reads manifest M, containing a ledger’s old digest.
2. Mirroring replaces that ledger with a valid newer SQLite snapshot.
3. Verification hashes the replacement against M and reports corruption.
4. Mirroring publishes the new manifest.

A mirror interruption between snapshot replacement and manifest publication leaves the same mismatch persistently, despite having started from a valid published backup.

- **Outcome:** false unhealthy report and loss of a reliably readable last-published generation—not evidence of source-recording corruption.
- **Likelihood:** plausible during scheduled overlap as mirror duration grows; also reachable after an interrupted mirror.
- **Hashes:** neither.

## Areas without an additional serious finding

I found **no additional code-defensible serious leakage path** from an agent to the holdout, ledger, another agent’s workspace/socket, or an unauthorized network destination. I also did not establish a serious timing-channel exploit. The model-API CONNECT relay and agent-visible token are explicitly acknowledged boundaries, not new findings.

The previously reported empty-evaluation hang, selection-identity mismatch, and omitted DSL hash are not repeated here. The current mirror code also fixes the earlier log/body enumeration race and missing-manifest verification success.
