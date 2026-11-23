# Neon (Gemini 4 Neon, web UI) on the Python extinction plan

Reviewer: Gemini 4 Neon through the web UI, which did not write the plan (a fresh Opus did). Bundle `neon-python-extinction-bundle.md` (`python-extinction` `59b6543`, 113 KB). Reply saved by the human as a PDF, extracted with `pdftotext`, received 2026-11-23. Verbatim below.


 See attached instructions.

 User prompt: See attached instructions.

 Response: Finding 1: mmops picks a double-backed JSON parser (jsont) for
 61-bit nanosecond mtimes and 260 counters, and free * 5 <= total
 overflows OCaml int at 260
 What it breaks: mmops mirror's change detection and byte-for-byte MANIFEST.json
 preservation (Section 4, Step 3d), mmops diskguard's 260 threshold checks and float
 rejection (Section 2.7, Step 3a), and the plan's constraint that flake.lock does not move
 (Section 2.2, 2.5, Section 7).
 Construction:
 1. ops/live.py writes each file's st_mtime_ns as a raw JSON integer in
 MANIFEST.json—in November 2026, ≈ 1.795 × 1018 ≈ 260.6 nanoseconds. The
 plan rejects jq in Section 2.7 specifically because its tests reach 260 and jq parses
 JSON numbers as IEEE-754 doubles (53-bit significand), and adds a C stub in
 Section 2.5 because Unix.stat's float cannot hold nanosecond mtimes. Yet Section
 2.5 chooses jsont 0.2.0 to read MANIFEST.json for mmops. In jsont, JSON
 number tokens are decoded through OCaml float (Jsont.Json.Number of
 float * Meta.t; its int64 codec targets JSON strings, not JSON numbers). When
 mmops mirror reads Python's MANIFEST.json, every nanosecond mtime rounds to
 a 256 ns ULP (e.g., 1795395540123456789 becomes 1795395540123456768). On
 the very next run, st.st_mtime_ns != prev["mtime"] triggers on ~255/256 of
 unchanged files, causing mmops mirror to re-copy thousands of unchanged
 datalayer bodies over NFS every 10 minutes and breaking Step 3d's byte-for-byte
 differential.
 2. In mmops diskguard, decoding capacity counters and taken through jsont's
 float-backed numbers loses exactness above 253 (reintroducing the exact 260
 precision bug jq was rejected for) and erases the syntactic distinction between
 integer 1 and float 1.0, violating Step 3a's rule that floats must be refused.
 (Preserving arbitrary member order of carried-over entries per Section 4 also fights
 standard typed jsont codecs.)
 3. Even with an exact integer parser, implementing Step 3a's free * 5 <= total in
 native 63-bit signed OCaml int (max_int = 262 − 1 =
 4,611,686,018,427,387,903) overflows at the plan's own 260 test scale: for free =
 total = 2^60 (1,152,921,504,606,846,976), 5 × 260 =
 5,764,607,523,034,234,880 wraps to −3,458,764,513,820,540,928 ≤ 260 , firing

11/22/26, 9:04 PM See attached instructions.

 a false alarm on a 100%-free filesystem. Even Int64.mul overflows for free above
 ⌊(263 − 1)/5⌋ ≈ 1.84 × 1018 . For non-negative integers free and total > 0, the
 exact, overflow-free equivalent is free <= total / 5.
 Outcome it could change: Broken mmops differential or severe NFS re-copy thrashing
 during 10-minute mirror cycles (causing missed/overlapping mirror runs and stale-capacity
 alarms), false or missed disk-guard alarms on large counters or malformed float manifests,
 and a forced mid-build switch away from jsont (either writing a custom exact-integer
 JSON parser for mmops or moving flake.lock).
 Defect type: Design defect.

 Finding 2: mmdata's 72-hour shadow skips datalayer-keys, its spec omits
 User-Agent override and query-param merging, and its cut-over accepts
 silent HTTP 400/403 error loops
 What it breaks: Live recording of all keyed datalayer sources (BLS_API_KEY,
 BEA_API_KEY, EIA_API_KEY, and SEC_USER_AGENT in datalayer-keys) across the
 Step 5e cut-over and Step 5f deletion of ingest/datalayer.py.
 Construction:
 1. In ingest/datalayer.py, httpx.Client sets a default header User-Agent:
 spec["user_agent"], and each poll calls
 http.get(httpx.URL(url).copy_merge_params(params),
 headers=headers | ...). Two subtle behaviors happen implicitly in httpx: (a)
 when a feed declares auth with "header": "User-Agent" (for
 SEC_USER_AGENT), httpx replaces the client's default User-Agent case-
 insensitively; and (b) copy_merge_params merges query credentials cleanly onto
 URLs that already contain ? query parameters (with URL-encoding). Step 5a
 (DATALAYER.md) specifies neither case-insensitive override of default User-Agent
 nor merging onto URLs with existing query strings. Under libcurl, setting a default
 User-Agent and also appending auth's User-Agent to CURLOPT_HTTPHEADER
 sends duplicate User-Agent headers (which SEC EDGAR rejects with HTTP 403),
 and naive ?param=val appending breaks any feed URL that already has a query
 string (producing 400/403 from BLS, BEA, or EIA).
 2. Step 5e item 1 runs datalayer-shadow with no Secret, polling only keyless feeds.
 None of the four keyed sources—nor .keys.env mounted via subPath—are ever
 exercised against real upstream servers before cut-over. Step 5d's local differential
 against a fake server only checks what the fake enforces and does not even require
 asserting identical outbound request URLs and headers or testing a User-Agent-
 overriding auth header and pre-parameterized URL.

11/22/26, 9:04 PM See attached instructions.

 3. Step 5e item 3 declares the cut-over accepted when the day file continues without
 mirror refusal, consecutive polls stay within cadence plus 5 minutes, and mmops
 verify passes the next night. Because mmdata intentionally records every HTTP
 status (including 400, 401, and 403) as a normal poll row and valid compressed body,
 a broken keyed feed satisfies every single acceptance check while storing error
 pages instead of macro releases and SEC filings. Step 5f then deletes
 ingest/datalayer.py.

 Outcome it could change: Silent, permanent loss of point-in-time recordings across all
 four keyed macro/filing sources (BLS, BEA, EIA, SEC), which cannot be refetched where
 sources keep no vintages.
 Defect type: Design defect (spec omissions, blind shadow coverage, and status-blind cut-
 over acceptance).

 Finding 3: Retiring sources in Step 4 destroys prodesk7's only kernel NTP
 clock-error witness (adjtimex), which datalayer needs for point-in-time
 known_at validity—and Step 4 does not wait for S2

 What it breaks: Point-in-time (known_at) auditability of datalayer's live recordings, and
 continuity of prodesk7's clock-sync record if study 2 wants it under question S2.
 Construction:
 1. Section 2.1 dismisses sources_record.py's adjtimex logging (maxerror_ms,
 esterror_ms, unsynced) by claiming: "The clock bound has no reader: study 2
 times copies and pulls by the venue's own Date precisely because nothing witnesses
 the host's clock." That ignores datalayer: ingest/datalayer.py records
 {"feed", "url", "sent", "recv", "status", "sha256", "bytes"}—it
 does not record HTTP Date headers—and its entire design contract states "A body is
 known no earlier than its poll's recv." Every future reading-agent study (Q2, Section
 2.2's entire justification for keeping mmdata) relies on prodesk7's host clock recv to
 prove no lookahead on macro releases and filings.
 2. sources is currently the only workload on prodesk7 logging adjtimex. Yet Section
 3's dependency table makes Step 4 wait only for R1, not for S2 (whether mmrec
 should absorb adjtimex) and without migrating adjtimex into mmdata or mmops
 first.
 3. Step 4 retires sources. Later, prodesk7's NTP daemon loses sync or drifts for
 several days during scheduled macro releases. Nothing records unsynced: true or
 maxerror_ms exceeding 1,000 ms. Months later, when a reading-agent study
 evaluates known_at, there is no witness to prove prodesk7's clock was synced or
 to quarantine an unsynced window, and that kernel clock state can never be

11/22/26, 9:04 PM See attached instructions.

 recovered retroactively. Even if S2 later answers "yes" for mmrec, retiring sources
 before S2 creates an unrecoverable gap in the clock-sync log.
 Outcome it could change: Unwitnessed host timestamps on datalayer recordings
 (risking silent lookahead contamination or un-auditable timestamps in a future judged
 reading-agent study), and a permanent gap in prodesk7 clock-sync records if S2 wants
 them.
 Defect type: Design defect.
 CONTINUE

 User prompt: continue

 Response: Finding 4: mmdata's fresh-handle transport breaks httpx's
 connection pooling across 642 feeds (blowing GDELT's 15-minute cadence),
 and the 72-hour shadow risks rate-limiting live datalayer from the same IP
 What it breaks: GDELT's 15-minute point-in-time recording cadence under mmdata, the
 72-hour datalayer-shadow acceptance check (Step 5e item 1), live datalayer's
 upstream access during the shadow window, and disk cleanliness on the 20Gi PVC.
 Construction:
 1. ingest/datalayer.py polls 642 feeds from only 15 sources sequentially in a
 single loop (SPACING = 1 s after each poll, TICK = 60 s between sweeps), reusing
 a single httpx.Client connection pool across the ~43 feeds per source. Section
 2.2 replaces this with study 2's transport: "one Curl.perform on a fresh handle in
 Async's thread pool." Using a fresh libcurl handle per request destroys TCP and
 TLS session reuse across all 642 feeds, forcing a fresh DNS/TCP/TLS handshake on
 every poll.
 2. On datalayer-shadow's cold start (empty emptyDir), every keyless feed (~600+)
 is immediately due. Even the mandatory SPACING = 1 s plus TICK = 60 s
 consumes ~11 minutes before any network I/O; adding fresh-handle TLS handshakes
 and response times (or even one or two slow/120 s-timeout endpoints) pushes a
 sweep well past 15 minutes. That breaks GDELT's 15-minute cadence on startup and
 on any synchronized daily burst—permanently missing GDELT releases, since Section
 5 notes GDELT's index only names its latest file—and causes datalayer-shadow to
 fail its own "within its cadence plus two minutes" (17 min) criterion.
 3. Because datalayer-shadow runs on prodesk7 alongside live datalayer, both
 share the same egress IP. Firing a ~600-request cold-start burst and doubling

11/22/26, 9:04 PM See attached instructions.

 steady-state traffic for 72 hours against rate-limited public/government APIs risks
 triggering HTTP 429s or temporary IP blocks against the production datalayer pod.
 4. Meanwhile, Section 4 and Step 5d spend engineering and verification effort enforcing
 byte-for-byte json.dumps (ensure_ascii surrogate pairs, key ordering) that no
 JSON reader relies on, while leaving real streaming/transport hazards unspecified—
 such as cleanup of orphaned .tmp files left in raw/ whenever a streaming download
 aborts mid-body or the pod is killed (which mirror skips, silently leaking PVC space).
 Outcome it could change: Permanently missed GDELT 15-minute snapshots, IP-based
 rate-limiting or blocking of the live production datalayer recorder during the 72-hour
 shadow, and leaked .tmp files consuming the 20Gi PVC.
 Defect type: Design defect.

 Finding 5: Sealing hl, thesis, agent (and sources) leaves sealed manifests
 unpinned by mmops verify, traps verify in a 20-minute spin on sealed
 corruption, and contradicts ops/workloads.nix's single volume table
 during rollout
 What it breaks: Tamper/corruption detection on sealed volumes (hl, thesis, agent,
 sources), mmops verify's failure latency, and zero-alarm switch-over across Steps 3e,
 3g, and 4.
 Construction:
 1. Unpinned sealed manifests: Step 3e logs each sealed volume's final
 MANIFEST.json sha256 in audit/decisions.md (human prose), but Step 3a
 (MIRROR.md) never passes those hashes to mmops verify or checks them. mmops
 verify only verifies that /mirror/<vol>/MANIFEST.json exists and matches the
 files listed inside it. If a sealed MANIFEST.json on NFS is silently rolled back,
 overwritten, or truncated to a valid empty-file JSON object, mmops verify passes
 while silently losing integrity coverage of that volume.
 2. 20-minute spin and unverified non-day sources: Under Step 3a, any mirror-copy
 hash mismatch enters a 1,200-second (20-minute) polling loop waiting for a newer
 MANIFEST.json. For a sealed volume, mirror never writes a newer manifest, so
 every corrupted mirror file burns 20 minutes waiting on nothing. Meanwhile,
 ops/live.py verify only checks source on prodesk7 for day (*.jsonl) files—
 never for plain files or .sqlite ledgers (whose live WAL files on prodesk7 do not
 match sqlite3.backup snapshots byte-for-byte anyway). Sealing thesis and
 agent removes them from mirror while leaving their prodesk7 .sqlite and plain
 files unverified, and dropping the work/ rule from mirror_kind (Section 2.5) newly
 classifies any work/*.jsonl file still listed in a sealed agent/thesis manifest as a
 day file whose prodesk7 source verify must now match.

11/22/26, 9:04 PM See attached instructions.

 3. Single-table rollout contradiction: Section 2.5 states that mirror, mirror-
 verify, and diskguard all read one volume table in ops/workloads.nix. Yet Step
 3e and Step 4 (after 3e) require removing volumes from diskguard (by merging to
 main, which mm-diskguard.timer executes) before applying mirror, whereas
 Step 3g requires applying mirror (adding ws) before diskguard expects ws. With
 one table, Step 3g forces applying an unmerged branch to the cluster and waiting for
 a CronJob run before merging to main—and if mirror must be rolled back to Python
 during Step 3e, main's diskguard has already stopped watching the sealed
 volumes that Python mirror resumed copying.
 Outcome it could change: Silent loss of integrity verification on sealed manifests or
 thesis/agent source volumes, spurious critical disk-guard alarms on ws during Step 3g,
 or unmonitored rollback windows during Step 3e.
 Defect type: Design defect.

 Finding 6: mmops mirror's SIGKILL crash test conflicts with Python's in-
 place day-file append, MIRROR.md omits missing-source refusal, and Step 3e
 leaves mirror's read-only mount boundary unguarded
 What it breaks: Independent test-to-implementation handoff in Step 3b/3c, crash-atomic
 mirror files on NFS, failure detection on broken volume mounts, and the read-only safety
 boundary for live recording PVCs.
 Construction:
 1. In ops/live.py, appending to an existing day file opens target directly in place
 (r+b), seeks to prev["size"], truncates, and writes new bytes straight into
 target. Step 3b test 1 requires that a SIGKILL while appending to a day file
 "publishes no partial file and leaves the previous manifest whole." A separate test
 author reading only MIRROR.md and Step 3b will reasonably assert that target on
 NFS is byte-unchanged after SIGKILL—which fails an in-place appender (and
 exposes torn bytes past prev["size"] to any reader not clamping to
 MANIFEST.json). Conversely, making day-file appends atomic via .tmp + rename
 contradicts Step 3a's "copied on from their mirrored length" and turns every 10-
 minute append into a full-file NFS rewrite if ever applied to a large day file.
 2. ops/live.py line 206 silently skips any volume whose source directory does not
 exist whenever old contains no day or ledger files (if not src.exists() and
 not any(mirror_kind(r) != "plain" for r in old): continue). That
 condition is always true for a newly added volume and for Step 3g's empty-manifest
 ws. Step 3a (MIRROR.md) does not specify refusing a missing source root, risking a
 silent no-op on a misconfigured mount.

11/22/26, 9:04 PM See attached instructions.

 3. Step 1 test 2's manifest boundary check verifies that mirror-verify mounts
 mirror read-only, but does not check that mirror mounts its recording PVCs read-
 only (because ops/live.py mounts thesis and agent read-write for SQLite).
 When Step 3e removes thesis and agent from mirror and changes all remaining
 recording mounts (and later ws in 3g) to read-only, the plan adds no boundary check
 enforcing readOnly: true on mirror's recording mounts—leaving no automated
 guard against a future ops/workloads.nix edit mounting datalayer or ws read-
 write in mirror.
 Outcome it could change: Broken Step 3b/3c builder handoff, torn day-file tails left on
 NFS after a killed mirror run, silent skip of an unmounted source volume, or an accidental
 read-write mount in mirror able to corrupt the only copy of ws or datalayer.
 Defect type: Mixed — design defect (missing read-only boundary check after Step 3e;
 unmounted source root handling) and spec defect (unresolved in-place vs. atomic-rename
 day-file append between Step 3a and Step 3b).
 CONTINUE

 User prompt: continue

 Response: Finding 7: K1's recommended option (a) destroys kernel v2's
 independent archive oracle and risks silently altering historical archive
 results
 What it breaks: Independent cross-language verification of archive ingestion (brief 3, step
 3, test 5) and representation stability between historical archive tables and future kernel
 v2 runs.
 Construction:
 1. In ingest/archive.py, parse() and _write_snapshot() do more than
 decompress .lz4 JSON: they drop empty lines and one-sided books (if not bids
 or not asks: continue), convert price/size strings to IEEE-754 Float64,
 compute mid = (bid0 + ask0) / 2, and sort/deduplicate by time
 (keep="first", maintaining order) across hour boundaries.
 2. Section 2.4 recommends K1 option (a): having kernel v2 read raw .lz4 lines directly
 with the forward websocket reader's decoder, eliminating the Parquet snapshot tier,
 source_hours, Float64 quotes, and test 5's independent oracle.

 3. Making the forward decoder read both live and archive feeds removes oracle
 independence—any bug in l2Book frame decoding, one-sided book handling, or
 cross-hour timestamp deduplication now agrees with itself in both paths.

11/22/26, 9:04 PM See attached instructions.

 Simultaneously switching the 17-coin historical archive (April–October 2026) from
 Float64 Parquet snapshots to forward string frames changes rounding and edge-
 case filtering, which can shift backtest outputs and judged comparisons against prior
 builds.
 4. Deleting archive.fetch in Step 6 without a replacement also leaves ARCHIVE.md
 describing a dead fetcher; if the human ever approves another S3 pull for new coins
 or dates, requester-pays pagination, spend.tsv cost guards, and the forward-
 window refusal must be rewritten from scratch.
 Outcome it could change: Undetected decoder bugs passing a tautological test 5, or
 silent drift in judged results computed over the historical archive.
 Defect type: Design defect (option (b)—an independent OCaml raw-.lz4 parser written
 from ARCHIVE.md and differential-tested against Python parse() before Step 6 deletes
 Python—preserves independence without retaining Python).

 Finding 8: The rollback premise ("previous image only") is false for host-side
 tools (diskguard, push, apply), and Step 1's flake-app deployer has a List-
 envelope mismatch and tag/source drift
 What it breaks: Rollback safety for diskguard (Step 3e/3f) and the deployer (Step 1),
 Step 1's differential test against ops/live.py, and image-tag integrity in push.
 Construction:
 1. Section 6 asserts that once a switch is accepted, "A rollback needs only the previous
 image, never the Python on main." That is false for ops/diskguard.py (executed on
 this PC directly from the main checkout by mm-diskguard.timer, not from the
 cluster container image) and for push/apply (run on this PC). Step 1 also breaks its
 own swap rule: it deletes ops/live.py's deployer in the merge commit before Test
 4 (kubectl diff on the live cluster, run "after the merge") verifies zero drift.
 2. In ops/live.py, apply(digest, *names) wraps even a single workload in
 {"apiVersion": "v1", "kind": "List", "items": [manifest(n,
 digest), ...]}. Step 1 Test 1 requires apply sha256:0 <name> to output JSON
 equal to manifest(name, "sha256:0") (a bare single resource, not a List), while
 Test 3 expects apply sha256:abc ws vault to send two objects. A builder
 satisfying Test 1 literally breaks multi-object List output or diverges from
 ops/live.py.

 3. Moving push into a flake app (nix run .#push) separates git rev-parse --
 short HEAD (which cannot run on a .git-stripped /nix/store flake source and
 must inspect $PWD) from the flake evaluation building .#image. Running push from a
 dirty worktree or with a flake reference different from $PWD tags one commit's short
 SHA onto another tree's image.

11/22/26, 9:04 PM See attached instructions.

 Outcome it could change: A broken rollback path if mmops diskguard fails on this PC
 after Step 3f, live cluster drift discovered only after the Python deployer is gone, or mis-
 tagged container images pushed to the registry.
 Defect type: Mixed — design defect (false rollback assumption for host-side tools; Step 1
 deleting before live kubectl diff; push tag/source decoupling) and text/spec defect
 (Test 1 vs. List envelope).

 What should exist that the plan deletes, and what should be
 deleted that it keeps
 Deleted by the plan, should exist (before deletion):
 Host clock-sync logging (adjtimex on prodesk7): Currently in
 sources_record.py. Must be migrated to mmdata, mmrec, or mmops before Step 4
 retires sources, because datalayer relies on prodesk7's host clock (recv) for
 point-in-time known_at validity without recording HTTP Date headers.
 An independent archive-parsing oracle: Keep an independent parser via K1 option
 (b) rather than collapsing test 5 into the forward decoder under option (a).
 Pinned sealed-manifest hashes and a mirror read-only mount check: mmops
 verify should check sealed volumes against their recorded final manifest hashes
 (not just self-consistency), and the flake manifest check should enforce readOnly:
 true on mirror's recording PVCs once thesis and agent are sealed.

 Kept by the plan, should be deleted or relaxed:
 Byte-for-byte json.dumps (ensure_ascii surrogate-pair escaping and carried-
 over key order) in Section 4: No downstream JSON reader depends on Python's
 exact ASCII-escape bytes or arbitrary key order. Requiring byte-identical JSON
 forces bespoke serialization complexity and distracts from real streaming hazards
 (such as verifying an existing 200 MB raw/<digest>.gz in mmdata without blowing
 the 20 MB RSS limit, and cleaning up orphaned .tmp files). Semantic JSON equality
 with exact 64-bit integer preservation is the right differential test.
 Retiring sources's Discourse/Snapshot polling itself: Defensible only once
 adjtimex is rescued and R1 explicitly confronts the human's 2026-11-14 "recorders
 for anything we could possibly need" rule—specifically noting that Discourse stores
 only post HTML hashes (unusable by a reading agent) and Snapshot proposals are
 largely re-queryable via GraphQL/IPFS, unlike ephemeral orderbooks or unversioned
 macro releases.

 What I accept

11/22/26, 9:04 PM See attached instructions.

 The overall architecture and language split: Moving datalayer, mirror/verify, and
 diskguard into OCaml executables (mmdata, mmops) inside recorder/, moving workload
 manifests into Nix (ops/workloads.nix), and moving the commit hook and shell-
 wrapper tests into shell is coherent and keeps flake.lock stable once the JSON parser
 choice is fixed.
 Deleting archive.bars and adding the python-left ratchet (Step 0): bars has no
 caller on any branch, and a shrink-only flake check is the right mechanical guard against
 study 1's Python sneaking back through branch merges.
 Keeping datalayer as a separate process and streaming its bodies: Isolating mmdata
 from ws prevents macro-feed faults from touching market recording, and streaming
 redaction/hashing/compression fixes a genuine crash-loop hazard in Python under the
 512Mi limit.
 Adding an explicit capacity-only manifest for ws (Step 3g): Fixing the accidental
 reliance on shared filesystems closes a real blind spot once other volumes stop being
 mirrored.
 Leaving ws and vault untouched during the migration and stripping the container
 image to binaries + venue/ in Step 7: Avoiding gratuitous restarts of ws protects the
 unmirrored primary recording.

 Final Ledger
 # Item Verdict Changes what is built or run?

 jsont float-backed JSON
 parsing for 61-bit nanosecond Yes (built & run): mmops must use an
 exact-integer JSON parser (not jsont
 1 mtimes & 260 counters, and Disputed
 float numbers) and overflow-free free
 free * 5 <= total OCaml
 <= total / 5 arithmetic.
 int overflow in mmops

 Yes (built & run): Spec must define
 mmdata keyless shadow, User-Agent replacement and query
 missing User-Agent override merging; differential must check
 2 / query-param merge spec, Disputed outbound requests; cut-over must
 and status-blind cut-over validate non-4xx/5xx status parity on
 acceptance keyed feeds before Step 5f deletes
 Python.

11/22/26, 9:04 PM See attached instructions.

 # Item Verdict Changes what is built or run?

 Yes (built & run): Step 4 must wait for
 Retiring sources in Step 4
 adjtimex logging to move into
 3 without rescuing adjtimex Disputed
 mmdata, mmrec, or mmops so prodesk7
 or waiting on S2
 has no unwitnessed clock window.
 Yes (built & run): mmdata needs per-
 host connection/TLS reuse (or bounded
 Fresh libcurl handles per
 concurrency) so GDELT's 15-min
 poll across 642 feeds,
 cadence holds; shadow must avoid
 shadow IP rate-limit risk,
 4 Disputed hammering live feeds' rate limits from
 .tmp cleanup, and over-
 the same IP; .tmp cleanup and
 specified byte-for-byte
 streaming intact() checks must be
 ensure_ascii
 specified; relax ensure_ascii byte
 equality to exact-int JSON equality.
 Yes (built & run): mmops verify must
 Unpinned sealed manifests,
 pin sealed manifest hashes, fail
 20-min verify spin on sealed
 immediately on sealed mismatches, and
 5 corruption, dropped work/ Disputed
 handle legacy work/*.jsonl in sealed
 rule on sealed manifests, and
 manifests; decouple mirror/guard
 single-table rollout conflict
 rollout lists during Steps 3e/3g/4.
 Yes (built): Resolve in-place vs. atomic
 SIGKILL day-file append
 day-file append explicitly in
 contract vs. in-place Python
 MIRROR.md; refuse missing source
 6 writes, silent missing-source Disputed
 roots; add a flake check enforcing
 skip, and missing readOnly:
 readOnly: true on mirror's
 true check on mirror
 recording PVCs after Step 3e.
 Yes (built): Recommend K1 option (b)
 K1 recommendation (a)
 (independent OCaml raw-.lz4 parser
 7 collapsing the archive oracle Disputed
 verified against Python parse() before
 into the forward decoder
 deletion) rather than option (a).
 Yes (built & run): Run kubectl diff
 False "image-only rollback"
 before deleting ops/live.py's
 premise for host-side tools,
 deployer; align Step 1 Test 1 with
 Step 1 deleting before live
 8 Disputed Kubernetes List output; derive push
 kubectl diff, List
 tag from the built flake revision;
 envelope mismatch, and push
 document git-revert rollback for
 $PWD drift
 diskguard.

11/22/26, 9:04 PM See attached instructions.

 # Item Verdict Changes what is built or run?

 Step 0 (python-left ratchet
 9 Agreed No.
 and archive.bars deletion)
 Language split (OCaml
 mmdata/mmops, Nix
 10 workloads.nix, shell Agreed No.
 hooks/tests) and keeping
 ws/vault untouched

 Streaming bodies in mmdata,
 adding ws capacity-only
 11 Agreed No.
 manifest (Step 3g), and
 slimming the Step 7 image
 Retiring sources's
 Discourse/Snapshot polling Agreed
 12 Only via item 3 above.
 (conditional on R1 review and (conditional)
 rescuing adjtimex)


