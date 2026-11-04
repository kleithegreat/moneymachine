## Verdict
**The redesign removes the principal session-pod blockers. It does not yet justify cut-over.** Keeping bubblewrap, private Unix sockets and the existing client/transcript path is substantially simpler and safer than replacing them with network-facing session infrastructure.
A nested bubblewrap sandbox is **not inherently weaker** because its parent pod has a user namespace. Conversely, unchanged hashes establish code identity—not equivalent runtime confinement. Stage 3’s freeze and stage 10’s existing version can stand if the actual runtime preserves their invariants and the credential gate passes. A host move alone does not require refreezing.
“Resolved” below means addressed by the redesigned specification, not independently verified in a running deployment.
## Earlier findings
Severity is the **remaining** severity.
| # | Status | Severity | Assessment and smallest remaining fix |
|---|---|---|---|
| 1 | **Resolved** | note | The session again has bubblewrap’s disconnected network namespace; NetworkPolicy is no longer its primary network boundary. Outer-runner networking remains finding 13. |
| 2 | **Moot** | note | Separate session pods and shared runner TCP endpoints are gone. Private per-session sockets preserve the old ownership boundary. |
| 3 | **Moot** | note | The proposed network bearer-capability protocol is gone. |
| 4 | **Resolved** | note | The unchanged daemon/client path removes the newly network-facing confused deputy. Preserve the existing disclosure and public-fetch tests in the pod. |
| 5 | **Moot** | note | No launcher-created session template requires closed-template admission. Runner confinement still needs the checks below; Restricted admission is not proof of equivalence. |
| 6 | **Resolved** | note | The launcher and its contradictory environment policy are gone; `deployer` is explicitly trusted. |
| 7 | **Resolved** | note | The read-only client bind mount and isolated Python invocation remain unchanged. |
| 8 | **Still open** | should fix | The inner environment is preserved, but its `/bin`, `/usr`, closures and inherited security filters now come from the image/runtime. **Fix:** compare their effective contents and permissions with the original sandbox. |
| 9 | **Resolved** | note | Transcripts are again captured outside bubblewrap by the existing parent, rather than uploaded by an agent-adjacent pod process. |
| 10 | **Resolved** | note | Sessions are local descendants again, restoring the established `--die-with-parent` boundary. Runner shutdown remains finding 19. |
| 11 | **Moot** | note | The proxy is not newly exposed over pod TCP. Its parsing, threading and tunnel-cleanup weaknesses are inherited, not new migration blockers. |
| 12 | **Still open** | note | CONNECT to Anthropic remains hostname-level authority, not inference-only authority. **Fix:** retain that accurate description; do not claim API-operation isolation. |
| 13 | **Still open** | blocks | The public-address assurance addresses one concern, but the actual CNI, node-traffic exceptions and service/NAT behavior remain unspecified. **Fix:** test runner access to node services, API endpoints, LAN/licensed-data routes and IPv6 on the actual dataplane; add receiving-side or host enforcement wherever policy is insufficient. |
| 14 | **Resolved** | note | Desktop/deployer access to all live Secrets and volumes is now explicitly accepted; broad launcher deletion authority is gone. |
| 15 | **Moot** | note | The `agent-image` ConfigMap workflow is gone; images are digest-pinned. |
| 16 | **Still open** | blocks | The research-input path is described, but credential migration still awaits human approval. Image/data exclusion and Secret datastore/node/backup protection remain unverified. **Fix:** make approval and those checks explicit pre-deployment gates. |
| 17 | **Resolved** | note | Exclusive directory locks and the no-force-delete rule replace the false StatefulSet/RWO fencing claim. Ensure locks cover the full writer lifetime and all launch paths. |
| 18 | **Still open** | blocks | Series crash accounting is specified, but a durable claim **before work** is not explicit, and thesis date/session restart behavior is not established. **Fix:** verify durable claims and crash recovery at evaluation/registration/recording boundaries; interrupted attempts must remain consumed. |
| 19 | **Still open** | blocks | Exec form is helpful, but Python PID 1 without SIGTERM handling plus a session-watching `preStop` is not a shutdown protocol. See below. |
| 20 | **Still open** | should fix | Single-node availability is honestly stated. Requests, limits, writable-space bounds, disk alerts and operational headroom remain undefined. **Fix:** specify them and test pressure/quota failure. |
| 21 | **Still open** | should fix | Per-recorder clock logs improve the design; venue timestamps and NTP alone do not establish clock uncertainty below one second. **Fix:** define each source’s measurement method, invalidate uncertain periods, and test clock jumps/restarts. |
| 22 | **Still open** | blocks | Generations and `Forbid` help, but the append-only comparison conflicts with mutable SQLite backups, and independently copied files need not form a consistent recovery point. **Fix:** separate append-only streams from mutable snapshots, publish validated generations atomically, and test restoration. |
| 23 | **Resolved** | note | Current successful-poll, pagination, clock, overlap and mirror gates now replace “24 hours looked healthy.” Acceptance and recoverability gaps remain below. |
| 24 | **Resolved** | note | Disabled paths are retained through seven-day acceptance, and rollback must preserve consumed identities. |
| 25 | **Still open** | should fix | The union-of-hosts safeguards are largely present. “A poll covers a minute” is still undefined. **Fix:** define coverage from the polling contract and gap logs without rounding away outages or treating later backfill as live coverage. |
| 26 | **Still open** | blocks | Appending before migration does not prevent retrospective reclassification of already-measured history. **Fix:** give the revision a prospective effective instant, retain historical failures, and require fresh validation under the revised rule. |
| 27 | **Moot** | note | No refreeze is needed on the unchanged-hash path. If the credential fallback changes the harness, retain reconciled evidence of no prior campaign activity and append the successor freeze with fresh IDs. |
| 28 | **Moot** | note | The proposed new TCP/bootstrap/transcript boundary is gone. Record the effective deployment separately for reproducibility; merely moving hosts does not require expanding the frozen scientific hash. |
| 29 | **Still open** | blocks | Stopping between sessions is not a consistent migration snapshot or proof against consuming a date twice. **Fix:** quiesce every writer, reconcile date/session claims, restore-test the snapshot, and assign continuous scoring ownership—including old-version scoring if fallback creates a version. |
| 30 | **Moot** | note | The normal path creates no new window. Preserve the original exact UTC dates, benchmark schedule and obligations; the freeze timestamp alone is not a complete definition of 28 consecutive UTC days. Define new boundaries only if a genuine new version is frozen. |
| 31 | **Moot** | note | Untrusted session pods are gone. A separate session namespace no longer solves an active problem. |
| 32 | **Resolved** | note | The design adopts the important simplification: keep the existing sandbox and local lifecycle boundary. A dedicated VM is an alternative, not a mandatory prerequisite. |
## Redesign-specific issues
### 1. Nested bubblewrap: plausible equivalence, not yet demonstrated
**Blocks.** An inner user namespace cannot acquire capabilities in its ancestors merely by becoming root inside itself. With the same namespace creation, mounts and private sockets, nesting can preserve the original isolation and add an outer boundary.
However, the deployed runtime must actually permit the required namespace and mount operations **without** adding host privilege. User-namespace support, volume/idmapped-mount compatibility, namespace limits and inherited filters all matter. A simple successful CLI call is insufficient.
**Smallest fix:** extend the in-pod isolation gate to inspect the effective UID/GID maps, capabilities, namespaces and mount table; exercise client immutability, repo/ledger exclusion, cross-session access and direct network denial. Do not “repair” failures with `privileged`, host namespaces or host-level `CAP_SYS_ADMIN`.
### 2. The Localhost profiles need executable definitions
**Should fix.** These are relaxations relative to ordinary RuntimeDefault container confinement, but not necessarily relative to the original host sandbox. Compare the actual effective policies rather than assuming either direction.
“RuntimeDefault plus …” is not itself a deployable seccomp profile. In particular, classic seccomp cannot inspect the namespace flags inside the structure pointed to by `clone3`; allowing that syscall is broader than filtering ordinary `clone` flags. Mount syscalls also cannot be safely path-scoped using seccomp alone.
Both seccomp and AppArmor continue to constrain—or permit operations by—descendants. Rules needed for bubblewrap setup may remain available to the agent.
**Smallest fix:** commit the exact profiles, their runtime-default source/version and node installation checks. Scope AppArmor mounts explicitly, retain dropped capabilities and no privilege escalation, and test the agent’s effective confinement after exec. Missing profiles must fail closed.
### 3. `procMount: Unmasked` is a real tradeoff, not automatically an escape
**Should fix.** User-namespace-qualified admission of Unmasked does not make it equivalent to default masking. It removes runtime protection from paths that otherwise receive masking/read-only treatment.
It does **not** by itself expose the host PID namespace or grant permission to write non-namespaced kernel controls. Bubblewrap’s freshly mounted `/proc` must also be compared with the original host sandbox—not with an ordinary masked container.
**Smallest fix:** document why Unmasked is necessary for this nested mount arrangement, inventory the resulting runtime paths, and test relevant reads/writes from both runner and inner sandbox. Keep Default if it works; otherwise explicitly accept the demonstrated exposure with the user-namespace and capability restrictions intact.
### 4. The frozen thesis shutdown plan is insufficient
**Blocks.** Python running as PID 1 with no SIGTERM handler cannot be assumed to perform normal SIGTERM termination. `preStop` consumes the same grace period; waiting for one bubblewrap process does not stop the runner from starting the next no-reading or conditional session. A day’s work can also contain several sequential sessions.
`--die-with-parent` supplies child cleanup, not ledger finalization or graceful draining.
**Smallest fix:** use a signal-aware supervisor outside the frozen manifest, with a tested quiescent-stop procedure and explicit accounting for unavoidable interruption. Do not claim that the supervisor alone makes the unmodified runner drain gracefully. If reliable draining requires editing frozen code, take the new-version path. Until then, prevent automatic rollouts from being mistaken for graceful maintenance.
### 5. The credential gate is correct—but must remain a blocking gate
**Blocks until passed and approved.** A `setup-token` value is not established to be a valid `.credentials.json` merely by placing it in that filename. Conversely, the design correctly acknowledges the possibility of a version-changing fix rather than hiding it.
**Smallest fix:** require an actual bubblewrapped session to authenticate using only the mounted/copied file, cleared environment and existing relay. Verify the intended account/model, pacing visibility, and credential rotation or expiry behavior—not just initial authentication. Obtain the pending human approval.
If the existing supported credential-file format works, neither freeze needs changing. If environment forwarding requires modifying `sandbox/session.py`, both identities change as the plan acknowledges.
### 6. An exact CLI store path is necessary, not a complete runtime image
**Should fix.** The sandbox also executes `nix-store -qR`, resolves Python/coreutils/shell roots, mounts their closures, creates short-path temporary sockets and writes private HOME/work directories. Carrying the CLI path alone does not provide the Nix query machinery/database or writable paths needed by that code.
Additionally, `/bin` and `/usr` are bound wholesale into the sandbox; image contents there are observable.
**Smallest fix:** build and test the complete runtime closure, including working closure queries and writable temporary storage under the read-only-root policy. Verify actual executable resolution, image contents and both frozen hashes inside the final image. Record the image digest as supplemental provenance without changing frozen result-producing code.
### 7. C5.3 needs a prospective revision and a precise coverage rule
**Blocks for a revised compliance claim.** The draft preserves first start, shared outages and deterministic observations well. It still needs:
- an explicit effective UTC instant;
- preservation of pre-revision failures without retrospective rescue by newly counted hosts;
- a definition of coverage that cannot hide gaps through minute binning;
- a fresh validation segment satisfying C5.3, including duration/item thresholds and reconciliation.
**Smallest fix:** append those qualifications before collecting migration-validation evidence. Keep the original and revised reports separate. Twenty-four hours may support an operational handoff; it does not alone validate a revised C5.3 rule.
### 8. The acceptance gate cannot literally keep every handoff check true
**Blocks.** After desktop recorders stop, continuing overlap reconciliation against their polls is impossible. A complete mirror generation can also be old; its existence does not prove that the handoff watermark is recoverable. The mirror’s SQLite append-only conflict makes this consequential, not cosmetic.
**Smallest fix:** separate:
1. **Handoff checks:** current reconciled overlap and a recoverable snapshot containing the handoff watermark.
2. **Seven-day checks:** ongoing successful-poll coverage, clocks, pagination/edit reconciliation, mirror freshness and restoration, plus experiment restart/shutdown accounting.
Alternatively, retain both recorders through the seven-day overlap and stop the desktop afterwards. Define mirror recovery loss from the **last successful** copy: while the PC is off, it can greatly exceed ten minutes.
### 9. Operational additions must actually stay outside the frozen code
**Should fix.** Writer locks, image-digest recording and improved crash accounting are compatible with unchanged hashes only if implemented outside the hashed files or already present. `thesis_harness.py` discovers imported repository modules; a change in a seemingly shared helper can therefore change the track manifest.
**Smallest fix:** inventory the actual manifest files and implement operational wrappers/provenance externally where possible. Make both computed hash checks mandatory immediately before launch. If an operational requirement cannot be met without changing covered code, use the documented refreeze/version transition rather than retaining the old identity.
