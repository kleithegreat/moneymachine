# Review: `ops-fixes` fixes (`79a2014..f1fe325`) against the six rulings

**Verdict: do not merge yet.** Two blocking findings, B1 and B2. Both need only small fixes. Everything else checks out.

**What I did:** I read CLAUDE.md, CLUSTER.md §5, the previous review, the full diff and every changed file whole. I also traced the code these changes touch: the series-log readers in `gate/sweep.py`, `gate/agent/campaigns.py` and `reference/differential.py`, `ingest/datalayer.py`, `ingest/hl.py`, and the poll readers in `ingest/availability.py` and `ingest/execution.py`.

**What I could not do:**
- Run any tests: `nix develop` needed approval, so I have no test results of my own.
- Run a shell experiment on `pull.sh`'s Blockers update, so B2 comes from reading the script.
- Read the live mirror manifests, also blocked.

I edited nothing.

## Frozen identities: unchanged

- **`kernel/`:** no file in the diff.
- **`harness_hash` inputs** (`gate/agent/{brief.md,research.md,swarm.md,daemon.py,harness.py}` plus model, limits and binary): none touched.
- **Thesis manifest** (every repo module `thesis.runner` and `thesis.report` import, plus `DATA`):
  - No module under `thesis/`, `ingest/`, `sandbox/` or `gate/kernel.py` imports `gate.campaign`, `gate.sweep`, `gate.agent.campaigns` or `ingest.record`.
  - `audit/stage10/manifest.json` lists none of the changed files.
  - I traced this by reading the code; I did not run the manifest command.

## Ruling by ruling

### 1. Series recovery is append-only and lives in `resume()`; the lock is only a lock — implemented
- `gate/campaign.py:65-73`: `exclusive()` only takes the lock.
- `gate/campaign.py:82-88`: `resume()` appends a single `\n` if the log doesn't end in one.
- `records()` (`:46-57`) skips any line that doesn't parse. It is shared by `recorded`, `need`, `summary` and `sweep.results`.

**Checked and fine:**
- **Mirror:** the recovered log only grows, so the mirror and `verify` accept it. The test runs both on a SIGKILLed log.
- **`summary()`:** the torn line is skipped and the crash row counts, so `n == 10` and the per-id `audits` hold. Only the crash row is listed, which correctly fails C4.3, as it did before.
- **Torn fragments:** one can never parse, because a row is a single JSON object and a prefix of one never closes.
- **Recovery runs again harmlessly:** a second `resume()` sees a log ending in `\n` and appends nothing.
- **No campaign goes uncounted:** every started id has its directory, so it gets a crash row.

**Does the reader rule hide a real corrupt row?** It skips any line that doesn't parse, wherever it is. That alone cannot pass a criterion, because every judged reader checks the count:
- `criteria/test_stage2.py:52,61,66` and `criteria/test_stages3to5.py:30,41,100` assert `n == 300/100/20/10`. A skipped row fails them loudly.
- If a `resume()` runs after the corruption, the id becomes a crash, which counts as a promotion. That is conservative.
- `mixed_summary` and `top5_programs` raise `KeyError` on a missing id.
- The only readers without a count check are `need()` (pacing) and the baseline spreads, which are descriptive.
- **Result: no outcome changes.**

**Lesser point, not blocking:** `sweep.truth()` (`gate/sweep.py:215`) appends under `exclusive()`, not `resume()`.
- After a torn tail in `truth.jsonl`, the next result is written onto the fragment's line and lost.
- That line no longer parses, so the result is simply recomputed on the next run.
- `mixed_summary` raises `KeyError` until then, so nothing is silent. On `main`, `recorded()` raised instead, so this is not a regression.
- `reference/differential.py:236,243` still parses its log directly, as on `main`.

### 2. Mirror snapshots day-file sizes before listing and parses no history — implemented
- `ops/live.py:197-199`: sizes and mtimes of every `*.jsonl` are captured first, then the other files are listed.
- `:218-229`: each day file is copied only up to its captured size.
- The datalayer parser is deleted.
- The datalayer writes each body whole before appending its row (`ingest/datalayer.py:100-105`). So every row in a copied prefix has its body on disk before `raw/` is listed.

**Checked at the snapshot size:**
- **Torn earlier run:** if a crashed run left the target longer, the copy truncates it at the start offset first.
- **Shrunk source:** a source smaller than the mirrored size is refused before copying, and the copy refuses one that shrinks mid-copy.
- **Manifest vs `verify`:** the manifest's `size` is the snapshot size and its `sha256` covers the target whole. `verify` hashes the same length on both sides, so the two agree.
- **A changed behaviour, harmless:** day files whose names contain `-wal` are no longer excluded; the old code skipped them by mistake.

**Not introduced here:** the agent volume's session homes (`run/home`) are deleted by `sandbox/session.py:145`. If any `.jsonl` there ever reached a manifest, the "vanished" refusal would stop the `agent` volume.
- The old listing had the same exposure, so the diff doesn't add it.
- I couldn't read the live manifest to check whether it has happened.

### 3. At most one HL verification per step; a third failure drops it with a logged error — implemented, but see B1
- `ingest/record.py:88-103`: first polls run first, then a single `if` makes at most one verification per step.
- The third failure logs a row and removes the request from the queue.
- **First polls are not starved:** at most one request (about 20 weight, roughly 3 s at 360/min) sits ahead of them per pass.

**Not blocking:** the three attempts run on consecutive 0.5 s steps, with no spacing between them.
- Each attempt is `Info.post`'s own six tries with backoff: 31 s of sleeps plus timeouts (`ingest/hl.py:38-50`).
- So in practice a request is dropped after about 1.5 to 5 minutes of outage.
- A 10-minute 5xx outage at H+10 min loses several reference values that would have succeeded later. That follows the ruling to the letter, but drops more than "persistent failure" suggests.

### 4. Oracle pull drops `--checksum`, skips same-inode files, publishes per file — implemented, but see B2
- `--checksum` is gone (`pull.sh:55`).
- `samefile` skips unchanged hard links (`publish.py:25`).
- Each file that extends its destination is published under the lock. Each divergent one is refused, all are named, and the exit is nonzero.
- `last-pull` stays put on any refusal.
- `extends()` correctly rejects a destination longer than its source.
- **The pull doesn't silently stop:** a lasting divergence keeps the Blocker line and the stale `last-pull`.

## Blocking findings

### B1. A dropped verification is written as a verify poll, and the C0.3/C0.7 host merge counts it as complete
`ingest/record.py:98-100` against `ingest/availability.py:73-77,99-101,146-149`

- **What's written:** the dropped row has `"purpose": "verify"`, `found: false` and `data: []`.
- **How `merge()` misreads it:** `complete()` treats any row with `purpose == "verify"` as the verify poll being present. `merge()` then takes that boundary from the first host whose polls are complete.
- **Failure scenario:**
  1. Local's verification for (funding, BTC, H) is dropped after 3 failures.
  2. The OCI host verified the same boundary normally.
  3. `merge()` still picks local for that boundary.
  4. `analyze()` takes `ref[0] = _value(kind, [], H) = None` and records a "no verify value" failure.
  5. Under `main`, the failure left no row, local was incomplete, and OCI's real reference value was used.
- **What it changes:**
  - Any C0.3/C0.7-style judgment or merge over recordings made after this deploys (forward window, recalibration) reports availability failures that didn't happen, and loses OCI's reference values.
  - The rows go into the irreplaceable recording permanently. They carry `dropped: true`, but the existing reader ignores it, and that merge rule is a criteria amendment.
  - Stage 0's judged window is spent and in the past, so no recorded result changes today.
- **Fix:** record the drop under its own purpose, e.g. `"purpose": "dropped"`, which `complete()`, `analyze()` and `relative_ranges()` already ignore. Or log it to stderr only, as `forever()` does.
- **Test:** add one through `availability.merge` with two hosts. The current tests check only the row's fields.

### B2. Multi-line pull errors leave stale lines in PROGRESS.md and put the VM's IP in a pushed file
`ops/oci/pull.sh:57,66-67`, which goes live the moment this merges (the timer runs the main checkout).

- **What changed:** `err="$err $d: $out"` used to keep only `tail -1`. Now `$out` is rsync's whole output, or every divergence line, so the Blocker entry spans several lines.
- **The cleanup leaks:** a good pull deletes only lines matching the mark (`pull.sh:61`). The continuation lines stay under Blockers forever. Each incident leaves more behind, for example `…/polls-….jsonl: source no longer extends destination`.
- **What that causes:**
  - **A wrong status record:** Blockers keep naming divergences or outages that were resolved.
  - **Blocked commits:** PROGRESS.md grows toward its 12 KiB cap (`ops/test_progress.py`), past which every commit is blocked.
  - **The VM's IP leaks:** the most common failure is an SSH timeout after an IP change. rsync's full output starts `ssh: connect to host <MM_OCI_IP> port 22: …`, so the IP from the gitignored `host.env` lands in PROGRESS.md, which is pushed to GitHub. The old `tail -1` line (`rsync error: … (code 255)`) did not include it.
- **Untested:** the tests only read stderr, and they never follow a failed pull with a good one to check PROGRESS.md afterwards.
- **Fix:**
  - Make `publish.py` report every divergence on one line, e.g. joined with `; `, and keep `tail -1` for rsync. Or flatten newlines before building `line`.
  - Add a test that runs a failing pull and then a good one, and asserts PROGRESS.md is back to its original bytes.

## Not blocking

- **C4.3 per-agent check** (`criteria/test_stages3to5.py:47-51`):
  - It tightens the check to enforce C4.3 as written, so it can't increase false discoveries.
  - `swarm_null` records `agent_evaluations` in every row, crash path included (`gate/agent/campaigns.py:167-169`).
  - Only crash rows written by `resume()` lack it, and they already fail on `audits`.
  - I could not confirm the eight live rows carry the field; reading the mirror was blocked.
- **`ops/test_commitcheck.py:28-33` is pinned to `git show bb8f502:`.**
  - It breaks the suite if that commit becomes unreachable, for example after a squash-merge and garbage collection, or in a shallow clone. Then every commit is blocked.
  - It also guards a one-off correction rather than a lasting failure mode.
- **The test-pass condition for merging is still open.**
  - `audit/decisions.md` (08:37) reports 412 passed and the 2 failures already named. It defers the full suite on a checkout with `data/` to merge time.
  - The previous review's finding 4 still applies until that run is recorded.
- **Deploying:** the `record.py` and `live.py` changes take effect only on a new image.
  - The previous review's advice stands: `apply(digest, "mirror", "mirror-verify")` rolls only the CronJobs.
  - Deploy `hl` only after B1 is fixed; rolling it leaves a gap in the recording.

**Blocking: B1 and B2.** Once they're fixed, only those two diffs need a recheck; neither changes the series, mirror or queue design.
