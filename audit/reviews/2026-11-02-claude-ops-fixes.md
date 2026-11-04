# Review: branch `ops-fixes` (bb8f502) against `main`

I read CLAUDE.md, CLUSTER.md §5, the triage entry and every changed file. I also checked the code these changes interact with: `gate/agent/campaigns.py`, `ingest/{live,hl,datalayer}.py`, `ops/oci/*` and the mirror's manifests. From `/srv/moneymachine/mirror/agent/swarm-null-2.jsonl` I read only the audit fields. I did not run the test suites: `nix develop` needs approval in this session. I edited nothing.

## Frozen identities: nothing changed

- **`kernel/`:** no file in the diff.
- **`harness_hash` inputs:** none touched. They are `gate/agent/{brief.md,research.md,swarm.md,daemon.py,harness.py}` plus the model, limits and binary.
- **Thesis manifest:** none of the changed modules are loaded by it. The manifest is every repo module `thesis.runner` and `thesis.report` import. I traced their imports by reading the source, because running the manifest command needed approval. They reach `gate.kernel`, `ingest.{policy,live,hl,fallback,datalayer,terms}` and `sandbox.*`. None of these import `gate/campaign.py`, `ingest/record.py`, `ops/live.py` or `ops/oci/publish.py`.
- **`gate/tests/test_agent_dsl.py`:** the pinned hash matches `sha256sum kernel/DSL.md`. DSL.md last changed on 2026-10-23 (b8034fd).

## Blocking findings

### 1. The torn-log recovery truncates an append-only file the mirror guards, which stops the `agent` volume's mirror in exactly the case the fix targets
`gate/campaign.py:60-71`

- **What happens:** `exclusive()` cuts a torn final line off the series log. That log is `data/agent/swarm-null-2.jsonl`, and the mirror copies it every 10 minutes. The fix only matters after a SIGKILL during a row's write, and a series restart is manual, so the mirror will almost surely have copied the torn bytes first.
- **The refusal:** after recovery, the source either got shorter or no longer matches its mirrored prefix. `mirror()` then raises "changed below its mirrored length" (`ops/live.py:212-213`). `verify()` fails daily with "source agent/… differs from its manifest".
- **Outcome it changes:** the `agent` volume stops being mirrored until someone hand-edits the mirror, which is the only copy. That volume holds the C4.5 log, the agent ledger and the campaign directories. The torn bytes are also erased for good from a judged evidence log, against "never delete recordings".
- **What is right:** the started campaign is still counted as a crash, which is conservative.
- **Fix:** recovery has to be append-only, for example by ending the fragment with a newline, plus one shared reader rule for torn lines. Or keep the old refusal and leave the repair to the human. Either way, test the mirror against the recovered log.
- **Lesser point:** the recovery sits in the lock primitive, not in `resume()`. So `real()` (`gate/agent/campaigns.py:492`), which takes `exclusive()` on C3.2's log purely as a lock, would now silently truncate a torn tail there without writing a crash row. In practice this can't be reached, because a committed summary implies a clean log. Moving the recovery into `resume()` removes the case.

### 2. The new datalayer check refuses a healthy source on a timing race and stops `thesis` and `agent` for that run
`ops/live.py:229-236`

- **The race:** `mirror()` lists files first, then copies each day file to whatever its end is at copy time. The datalayer writes a body before its row (`ingest/datalayer.py:100-104`). So a row with a new body can be appended after the listing; the source is consistent, but the check raises.
- **Order matters:** volumes run in order `hl, sources, datalayer, thesis, agent`, so every such refusal also skips `thesis` and `agent` for that run. How often this happens depends on how fast new bodies appear; I could not measure it.
- **A malformed line wedges the mirror for good:** `json.loads` on a torn or partial line anywhere in any datalayer day file raises `JSONDecodeError` on every run. That would come from a recorder killed mid-append or a host crash. After that, `thesis` and `agent` are never mirrored again.
- **Cost:** the check re-parses the whole datalayer history every 10 minutes, under a 200m CPU limit.
- **Root fix instead of a refusal:** record each day file's size before listing `raw/`, then copy each day file only up to that size. Every row in the copied prefix then has its body listed, and the check becomes an invariant that can't fail on healthy data.
- **CLUSTER.md §5** (the live system's one authoritative home) is not updated with either new refusal: this one, or `verify` refusing a missing manifest.

### 3. A request that keeps failing blocks the HL verification queue forever, and draining a backlog starves first polls
`ingest/record.py:88-91`

- **Head-of-line blocking:** a request that fails every time stays at the head of the queue. Examples are a persistent 4xx, or a `None` body that makes `any(...)` raise. The queue then never drains and grows by 11 to 22 entries an hour. Each step also burns six attempts with about 31 s of backoff in `Info.post`, which delays that step's first polls.
- **Starvation after an outage:** during a multi-hour 5xx outage, entries pile up. When it clears, the `while` loop drains the whole backlog in one `step()` at the shared 360/min weight. For example, 55 requests × 20 weight is about 3 minutes. Boundary first polls are not made during that time.
- **Outcome it changes:** gaps or late first polls in the irreplaceable HL recording (the C0.3 and C0.7 measurements). The old code lost verifications but never starved first polls.
- **Fix:** at most one verification per `step()`, so pending first polls always go first. Whether to give up on a request that fails every time is a decision; today the queue silently never drains.
- **Separately recorded, not this diff:** even without duplicates, the four-hour boundary needs 440 weight against 360/min (`audit/decisions.md:21`). That belongs under PROGRESS Blockers, not only in an audit paragraph.

### 4. The audit record contradicts the commit
`audit/decisions.md:22,26`

- The entries say "No commit was made because the full-suite gate is not met" and "`PROGRESS.md` records the blocker". Yet bb8f502 exists, and PROGRESS.md is unchanged on this branch.
- The two failing tests are caused by the clean worktree having no `data/` (missing `policy.json` and funding revisions). They are not caused by the code.
- The record is append-only, so the fix is a new line saying who committed and on which test result. CLAUDE.md requires tests to pass before every commit, so the suite should be shown passing on a checkout that has `data/` before merging.

## Not blocking, but check before merging

5. **`ops/oci/pull.sh` goes live the moment it merges.** The timer runs `/home/kevin/repos/moneymachine/ops/oci/pull.sh` every 10 minutes.
   - **Cost on both hosts:** `--checksum` (line 18) makes the VM read every pulled file, all history, on every pull. That competes with the timing-sensitive HL recorder on the VM. `publish.py:16-19` then reads every staged file and its destination in full locally, including hard-linked unchanged files that share one inode. Both costs grow with history.
   - **What `--checksum` adds:** without it, quick-check plus `publish.py` already catch every divergence except equal size *and* equal mtime with different bytes. Measure the cost or drop the flag. Also skip the comparison when source and target are the same inode.
   - **One bad file stops a whole volume:** a single diverged file blocks every new file in its volume until a human acts, so the VM stays the only copy. It does fail loudly, via Blockers. Publishing the files that are prefixes and refusing only the divergent one would keep the loudness and lose less.
   - **Checked:** `python` exists on the unit's PATH (`/etc/profiles/per-user/kevin/bin`). The tests run with the full PATH, so they could not have caught this.
6. **The stage 4 evidence check is right on real rows.** All 8 recorded `swarm-null-2` rows have `audits` keyed A1 to A4, each with `match: true` and `outside_permitted: []`. So the new assertions (`criteria/test_stages3to5.py:43-46`) pass on real evidence.
   - A crash row has no audits and fails, which matches C4.5 v2's "C4.3 holds for every campaign". It already failed on `cross_agent_history`.
   - **Gap:** C4.3's "≤ 100 per agent" is not asserted, though the summary carries `agent_evaluations`. The daemon's atomic budget makes a breach unlikely.
7. **`verify()` refusing a missing manifest is safe to deploy.** All five mirror volumes have a `MANIFEST.json` today.
8. **Deploying.** The `record.py` and `ops/live.py` changes take effect only when an image is redeployed.
   - Use `apply(digest, "mirror", "mirror-verify")` so only the CronJobs roll and nothing rolls `sources` before 2026-11-03 00:18 UTC (2026-11-02 19:18 EST).
   - Rolling `hl` leaves a gap in the recording.
   - The OCI VM runs its own checkout, so it is unaffected until that checkout is updated and the recorder restarted.

## Verdict

**Do not merge yet.** Fix first:

1. The torn-log recovery: make it append-only, or keep the refusal.
2. The mirror's datalayer check: snapshot day-file sizes before listing bodies, and make a malformed line unable to wedge the mirror.
3. The HL verification drain: at most one per step.
4. Correct the audit record about the commit, and show the full suite passing on a checkout with `data/`.

Before merging `pull.sh`, measure or remove `--checksum` and the full re-reads (point 5), because merging it changes the live pull immediately.

The DSL pin, the `verify` missing-manifest refusal and the stage 4 audit check are fine as written. Once findings 1 to 3 change, `exclusive()`, the mirror and the queue need one more review, because those changes alter the design.
