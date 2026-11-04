# Findings

Static review only: no recordings sought or inspected, and no files changed. These are code-proven failure paths, not claims that the triggers occurred in production. Ranked by consequence.

**Frozen identities:** None of the fixes below requires changing the agent harness or judged kernel. **Thesis fork** means the natural fix changes a module included by `thesis/harness.py:27–44` in the frozen stage-10 identity, requiring a new track and fresh evidence. In particular, `thesis/report.py:9–10` imports `ingest.datalayer` and `ingest.live`.

## 1. A torn JSONL append can permanently stop the datalayer recorder

**Path:** `ingest/live.py:22–25,28–33`; `ingest/datalayer.py:68–70,109–114`.

- **Trigger:** Disk exhaustion or an interrupted write leaves an incomplete final JSON record.
- **Wrong result:** `append()` neither checks nor separates an existing incomplete tail. Subsequent records concatenate onto it. `read()` unconditionally parses every line, so it raises at that point—even when later records are intact.
- **Consequence:** On datalayer restart, `last_polls()` encounters the malformed line before entering the recording loop. Every restart fails again, preventing **all future datalayer recordings** until intervention. For HL and sources, subsequent recording can continue, but their ordinary readers cannot traverse the damaged history.
- **Likelihood:** Exceptional rather than routine, but a single storage-full event or abrupt termination during an append is sufficient.
- **Frozen identity:** **Thesis fork** for a fix in the shared writer/reader.

## 2. An interrupted body write leaves a permanently reused corrupt blob

**Path:** `ingest/datalayer.py:99–105`; reader at `:63–65`.

- **Trigger:** Writing `raw/<digest>.gz` fails after creating a partial file—for example, with `ENOSPC`.
- **Wrong result:** The final content-addressed pathname is written directly. On the next successful response with the same body, `raw.exists()` suppresses the write without checking gzip integrity or the decompressed hash. The recorder then appends a successful poll referencing that corrupt file.
- **Consequence:** **Irrecoverably wrong recordings:** repeated HTTP-200 polls appear healthy but have unreadable bodies. Even receiving the complete body again does not repair the stored copy.
- **Likelihood:** Conditional on an interrupted write; repeated identical bodies are normal for unchanged feeds, making the poisoned state persistent.
- **Frozen identity:** **Thesis fork** (`ingest/datalayer.py`).

## 3. The Oracle pull can overwrite the only surviving historical bytes

**Path:** `ops/oci/pull.sh:12–20`; recorder durability at `ingest/live.py:24–25`.

- **Trigger:** The PC has copied records `A,B`. After an unclean VM shutdown, the source loses an unflushed tail containing `B` and subsequently grows as `A,C,D`.
- **Wrong result:** `rsync --append-verify` is not an append-history refusal check. Once the source grows beyond the destination length, a prefix mismatch causes rsync to retransmit the whole file in place. The destination becomes `A,C,D`; its unique surviving `B` is overwritten. Equal-sized or shorter source files can instead be skipped without detecting the disagreement.
- **Consequence:** **Loss of recordings already pulled**, contrary to the script’s append-only claim and the paper’s acquisition guarantee. A successful run updates `last-pull`.
- **Likelihood:** Low: requires source truncation or rewriting, plausibly following an unclean shutdown. Ordinary source growth alone is safe.
- **Frozen identity:** None for a pull-script fix.

## 4. A successful mirror generation can contain polls whose bodies were never copied

**Path:** `ops/live.py:196–199,215–232,235–245`; body-before-log publication at `ingest/datalayer.py:100–105`.

- **Trigger:** After the mirror builds its sorted source-file list, datalayer creates a new body and appends its poll to an already-listed day file, before that file is copied.
- **Wrong result:** The copied log includes the new reference, but the new body was absent from the enumerated file list. The manifest commits successfully. `verify()` checks listed files only, so it also succeeds.
- **Consequence:** **Invalid backup evidence:** a manifest advertised as the trusted copy is not self-contained; reading that poll’s body fails. Losing the source before another successful mirror makes the omission permanent.
- **Likelihood:** An ordinary concurrent-recording race, especially during bursts. Usually repaired by a later mirror, but neither successful check identifies the incomplete generation.
- **Frozen identity:** None for a mirror fix.

## 5. One exhausted HL request discards the remaining verification batch

**Path:** `ingest/record.py:83–87,96–103`; retries at `ingest/hl.py:38–50`.

- **Trigger:** At an ordinary hourly verification, one coin’s request exhausts its retries or returns a non-retryable error.
- **Wrong result:** `self.verify.pop(0)` removes the entire batch **before** polling its coins. An exception unwinds the loop; `forever()` logs it and resumes, but the failed coin and all remaining coins have no queued verification.
- **Consequence:** **Lost reference recordings**, potentially for all eleven coins from one failed request. L2 recording continues independently, so ongoing book traffic does not establish that boundary evidence is complete. C0.3 analysis reports missing verification values for affected groups.
- **Likelihood:** Occasional under network/API incidents; only one exhausted request during a batch is necessary.
- **Frozen identity:** None (`ingest/record.py`).

## 6. GDELT silently skips releases during normal operation

**Path:** `venue/sources/datalayer.json:42–48`; `ingest/datalayer.py:78–85,116–123`.

- **Trigger:** GDELT advances its latest-release pointer every fifteen minutes. The recorder’s interval includes request duration, spacing, tick rounding and time spent polling other feeds.
- **Wrong result:** Each visit fetches only the release currently named by `lastupdate.txt`; no release cursor or intermediate enumeration exists. For example, index reads at 12:14 and 12:30:01 capture the 12:00 and 12:30 releases, never 12:15.
- **Consequence:** **Missing release recordings despite successful polls.** The independent hosts do not guarantee complete union coverage.
- **Likelihood:** Routine. This limitation is already acknowledged in `audit/cluster/handoff.md:39`; the implementation still has the same path.
- **Frozen identity:** **Thesis fork** for acquisition/scheduling changes in `ingest/datalayer.py`.

## 7. Sources’ truncated lists are admitted as complete event coverage

**Path:** `ingest/sources_record.py:21–22,43–44,53–59`; `ingest/events.py:36–46,58–81`.

- **Trigger:** Between two four-minute polls, a forum publishes 51 posts. `/posts.json` returns only its latest 50 (`venue/sources.toml:80`).
- **Wrong result:** The oldest new post is never requested: the recorder has no pagination path. Nevertheless, `events.records()` accepts the returned list as a successful poll, and coverage uses its receive time without completeness information. With otherwise continuous polling, the derived count records 50 rather than 51 while retaining coverage.
- **Consequence:** **Lost items and wrong event counts**, rather than undefined input for incomplete coverage. The offline no-overlap counter can warn (`ingest/sources_avail.py:47–49`) but does not recover the missing page or exclude coverage. Snapshot has the analogous newest-20 limit.
- **Likelihood:** Low during quiet operation on the configured forum/space; more likely during bursts and after outages. Longer outages also lose raw items even when temporal coverage correctly becomes undefined.
- **Frozen identity:** None for recorder/completeness-handling fixes in these modules.

## 8. Verification reports success when entire volumes have no manifest

**Path:** `ops/live.py:235–245`; expected volumes at `:29–30`.

- **Trigger:** A mirror run fails after completing an earlier volume but before creating a later volume’s first manifest, or a volume’s mirror directory is absent during recovery.
- **Wrong result:** `verify()` simply skips every missing manifest. With no manifests at all, it still prints `verified` and exits successfully.
- **Consequence:** **A wrong integrity verdict:** wholly unbacked-up volumes are indistinguishable from verified ones in the job result. It also never inventories source files to detect wholly uncopied new day files.
- **Likelihood:** Conditional on incomplete initialization/recovery or failed mirroring; not expected after every healthy run, but directly relevant when verification is most needed.
- **Frozen identity:** None.

## 9. The deployed HL budget guarantees incomplete four-hour boundary polling

**Path:** `ops/live.py:40–41`; `ingest/record.py:27,32,73–79`; limiter at `ingest/hl.py:25–33,35`.

- **Trigger:** The configured eleven listed coins reach a four-hour boundary with immediately successful responses.
- **Wrong result:** The deployed total budget is 480/min; reserving 120 leaves **360** for boundary requests. Eleven funding requests plus eleven bar requests cost **440**. After eighteen requests, the remaining four wait for the sixty-second limiter window.
- **Consequence:** Those bars cannot meet the **35-second completeness bound** in `ingest/availability.py:73–77`. The cluster cannot independently supply complete C0.3 four-hour boundary evidence, even with a healthy venue and network.
- **Likelihood:** Guaranteed at ordinary four-hour boundaries. Already observed and acknowledged in `audit/cluster/handoff.md:25–28`.
- **Frozen identity:** None for deployment-budget or recorder scheduling changes.

## 10. Every four-hour verification batch is queued twice

**Path:** `ingest/record.py:64–65,72–76,83–87`.

- **Trigger:** A new hour is also a four-hour boundary.
- **Wrong result:** `self.verify.append((…, kinds))` sits inside `for kind in kinds`. With `["funding", "bar"]`, two entries are queued, each containing **both** kinds.
- **Consequence:** **Duplicate verification recordings** and 44 requests instead of 22 for eleven coins. The extra 440 request weight delays the second set; records still carry the same boundary and `"verify"` purpose. The analysis selects the first reference, so this alone does not establish a wrong C0.3 verdict.
- **Likelihood:** Guaranteed every four hours while continuously running.
- **Frozen identity:** None.

## Areas without an additional serious finding

I found no additional serious defect in the `adjtimex` field extraction against the currently adopted kernel-bound specification, or in the Oracle forward-window exclusion patterns. Oracle acquisition inherits the shared recorder/persistence defects above; its pull has the separate preservation failure in finding 3.
