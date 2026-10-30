# CLUSTER: the live workloads on the homelab cluster

The recorders, the thesis track (stage 10) and the agent series (stages 3 and 4) run on the homelab's k3s cluster
(1.36, containerd 2.3), so this PC can be off without stopping them. Batch Jobs stay as they are: namespace
`moneymachine`, submitted from this PC, inputs and results on its NFS. The Oracle recorder stays an independent second
Hyperliquid host.

Agent sessions still run in bubblewrap with private unix sockets, now inside runner pods that have their own user
namespace. The CLI's credential reaches a session as `CLAUDE_CODE_OAUTH_TOKEN`, passed by `sandbox/session.py`. That
changes both frozen identities, so stage 3's harness is refrozen before its first campaign, and stage 10 cuts a new
track version at the move.

Section 1 is what the Homelab repo (Flux) builds; sections 2 to 5 are what this repo builds against it.

## 1. Homelab objects

- **Namespace** `moneymachine-live`, Pod Security `enforce: baseline` with `warn` and `audit: restricted`: baseline
  admits `procMount: Unmasked` for user-namespaced pods, which restricted refuses. No volume of `moneymachine` is mounted in it, so
  no licensed kernel-only data reaches it.
- **Node profiles**, installed on prodesk7 only, for the runner pods: the Localhost seccomp profile
  `profiles/moneymachine-sandbox.json`, RuntimeDefault plus what bubblewrap needs (`unshare`, `clone` and `clone3` with
  namespace flags, `mount`, `pivot_root`, `umount2`); and the Localhost AppArmor profile `moneymachine-sandbox`,
  allowing `userns` creation and those mounts (Ubuntu 26.04 restricts unprivileged user namespaces).
  prodesk7 also sets `kernel.apparmor_restrict_unprivileged_userns=0` (live and persistent): Ubuntu's restriction
  otherwise denies a nested user namespace's uid map under any pod profile (`audit/cluster/gate-diagnosis.md`).
- **PriorityClass** `moneymachine-live`: value −50, `preemptionPolicy: Never`, so homelab services always win.
- **PVCs**, local-path, ReadWriteOnce, bound on the first pod's node (prodesk7), and not backed up: `hl` 50Gi, `sources` 5Gi, `datalayer` 20Gi, `thesis`
  20Gi, `agent` 20Gi. Every SQLite ledger lives on one of them, never on NFS.
- **PV and PVC** `mirror`: NFS from this PC, `/srv/moneymachine/mirror`, ReadWriteMany, 200Gi. This PC's NixOS
  configuration exports that directory beside `inputs` and `results`. It holds the only copy of the live data.
- **Secrets**, created by the advisor with kubectl from local files, outside Git:
  - `claude-token`: key `CLAUDE_CODE_OAUTH_TOKEN`, a `claude setup-token` token of the Cornell account; key `TAMU`, the TAMU account's, which only `agent-series` and `agent-real` read (as `CLAUDE_CODE_OAUTH_TOKEN_TAMU` and `_CORNELL`; `wait_for_room` sets `CLAUDE_CODE_OAUTH_TOKEN` to the account it picks);
  - `datalayer-keys`: one key `.keys.env`, the lines `BLS_API_KEY`, `BEA_API_KEY`, `EIA_API_KEY` and `SEC_USER_AGENT`
    (the datalayer feeds' declared `auth`). No `DATABENTO_API_KEY` and no FRED key.
- **RBAC**: ServiceAccount `deployer`, its kubeconfig at this PC's `~/.kube/moneymachine-live.yaml`, may create, get, list, watch, update, patch and
  delete statefulsets, jobs, cronjobs and pods; read pods/log and events; and read PVCs and the quota. It cannot read
  Secrets. Its scope is `moneymachine-live` only. It can therefore mount
  every Secret and volume there: this PC is trusted with all live credentials and data. Workload pods run as
  ServiceAccount `live` with no permissions and `automountServiceAccountToken: false`.
- **NetworkPolicies**: deny all ingress and egress; allow every pod egress on TCP 80 and 443 to 0.0.0.0/0 except
  10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 100.64.0.0/10 and 169.254.0.0/16, plus DNS to kube-dns. That is stricter than this PC, which reaches the whole LAN.
  IPv6 egress is denied. The homelab confirms that no homelab service or licensed-data host is reachable at a public
  address from the pods.
- **ResourceQuota**: 12 pods, 6 CPU and 12Gi memory requested.

## 2. Workloads (this repo, `ops/live.py`, applied with `deployer`)

| Name | Kind | Command | Volumes | Secret | Grace |
|---|---|---|---|---|---|
| `hl` | StatefulSet | `cli record data/live/universe.json venue/hyperliquid/rules.json data/live 480` | `hl` | none | 300 s |
| `sources` | StatefulSet | `cli sources-record data/sources_live` | `sources` | none | 300 s |
| `datalayer` | StatefulSet | `cli datalayer-record data/datalayer` | `datalayer` | `datalayer-keys` | 300 s |
| `thesis` | StatefulSet | `cli thesis-run` | `thesis`; `datalayer` read-only | `claude-token` | 15,000 s |
| `agent-series` | Job | `cli agent-null agent 20` (stage 4: `swarm 10`) | `agent` | `claude-token` | 9,000 s |
| `agent-real` | Job, one attempt | `cli agent-real data/agent/real 1792613363942` | `agent` | `claude-token` | 9,000 s |
| `mirror` | CronJob, every 10 min | section 5 | the five read-only; `mirror` | none | 600 s |
| `mirror-verify` | CronJob, daily | section 5 | the five and `mirror`, read-only | none | 600 s |

- Each volume is mounted at its repo path (`hl` at `data/live`, `sources` at `data/sources_live`, `datalayer` at
  `data/datalayer`, `thesis` at `data/thesis`, `agent` at `data/agent`), so every command runs as it does here.
- All run on prodesk7 (a `kubernetes.io/hostname` node selector) with the `moneymachine-live` priority, as uid 1000, gid 100, read-only root and the commands in exec
  form (Python is PID 1). The thesis and series pods add `hostUsers: false`, `procMount: Unmasked` and the Localhost
  profiles. The recorders and the mirror jobs are ordinary restricted pods with RuntimeDefault: NFS takes no
  idmapped mounts.
- **One writer per directory.** Each writer holds an exclusive `flock` on a lock file in its directory and exits if it
  is held: the thesis runner and the series do already, and the recorders take one beside their pidfile. A pod on an
  unreachable node is never force-deleted until the node is confirmed down.
- **Stopping.** On SIGTERM, recorders stop between polls (as today), the thesis runner after its current step (a day's
  sessions, at most four of an hour each, hence its grace), and the series between campaigns. Their waits wake on SIGTERM. The thesis StatefulSet uses `updateStrategy: OnDelete`, so a restart
  is always deliberate. Bubblewrap's `--die-with-parent` ends a session with its runner.
- **Retries.** A restarted series resumes: a campaign started and unrecorded is recorded as a crash (counted as a
  promotion), never rerun. The real campaign refuses an existing directory. The thesis runner records each date's
  sessions in its ledger and does not repeat one. A Kubernetes retry never becomes a fresh attempt.
- **Clocks.** Each recorder keeps its own clock log, and prodesk7 runs NTP. The logged offset against the venue's
  server time is the check (C5.3: under 1 s).
- **Image** `moneymachine`, one for batch and live, built by `nix build .#image`, pushed and pinned by digest:
  - contents: the repo at `/app`, the Python env, `mm`, claude-code pinned in the flake at exactly 2.1.304,
    bubblewrap, sqlite3, and the Nix store database that the sandbox's closure query (`nix-store -qR`)
    reads;
  - writable `emptyDir` for `/tmp` and the sessions' work directories;
  - its `/bin` and `/usr`, which bubblewrap binds into the sandbox, hold what the PC's do: `/bin/sh` and `/usr/bin/env`.
  The dev shell carries the same claude-code, so the harness hash and the thesis manifest computed here equal the
  pod's. Each result records the image digest beside the frozen hashes, not inside them.
- **Seeding.** `mm` is never in the image (its identity embeds its build path). `ops/live.py seed` delivers the exact
  bytes, and `data/thesis` and `data/universe.json` at the move: files go through the mirror export, and a pod copies
  them into the volume and checks every sha256. It never overwrites a file with other content. The series finds `mm`
  through `CARGO_TARGET_DIR`; the thesis track pins its own copy.
- **Requests and limits**: recorders 100m and 256Mi (limit 512Mi); thesis 500m and 2Gi (4Gi); series 1 CPU and 3Gi
  (6Gi); mirror jobs 200m and 256Mi (512Mi). Each emptyDir is capped at 2Gi. The mirror reports volume usage,
  and this PC's disk guard raises a blocker above 80 %.
- **Availability.** One node holds every volume, so a prodesk7 outage stops everything, and its disk holds the only copy of what the mirror has not yet copied. The Oracle VM is the only
  independent recorder, and only for Hyperliquid.

**`agent-real`** (stage 3's one real campaign) is the series' pod with `restartPolicy: Never` and `backoffLimit: 0`: a
pod that dies is never a second attempt. It starts only after `agent-series` has completed, as both write `agent`.
Its inputs are not in any volume: before applying it, seed the dataset version's store and the untouched holdout into
`agent` (`ops/live.py seed <digest> agent data/store:real/store data/holdout:real/holdout`), so the holdout's
`spent.jsonl` claim lives on the volume, and the mirror carries it to this PC. That claim is per store: the copy in
this PC's `data/holdout` does not see it, and the holdout is released once, on one host. `agent-summary` is not a
workload: its baseline (`data/campaigns/null.jsonl`) is on this PC, so it runs here, no model call, on the series log
from the mirror (`/srv/moneymachine/mirror/agent/agent-null.jsonl`, sha256 checked against its `MANIFEST.json`, copied to
`data/agent/`).

## 3. Credentials and usage

The thesis and series pods take `CLAUDE_CODE_OAUTH_TOKEN` from `claude-token`, and `sandbox/session.py` passes it into
each session's cleared environment. That is the only way a session gets a credential: no credential file is copied.
Pacing (`wait_for_room`) runs in the series pod and reads each account's windows, TAMU first (the thesis track also
draws on Cornell); it runs the next campaign on the first with room, and the series log records the account's name, never
the token. Recorders hold no credential but `datalayer-keys`.

**Gate:** a sandboxed session in the runner pod authenticates with the token alone, as the intended account and
model, and the pacing probe reads that account's windows.

## 4. Agent sessions

`sandbox/session.py` runs `claude -p` in bubblewrap (`--unshare-all`, cleared environment, read-only store closures,
workspace and private HOME, unix sockets for the client and the egress relay allowing only `api.anthropic.com`). The
egress relay is a hostname-level CONNECT allowlist, not an inference-only gateway. The token is visible to the agent,
in its own environment, as the copied credential file was before. The pod adds an outer layer: its own user namespace,
the network policy above, and no service account token.

**Gate before cut-over**, all in the deployed pod and never repaired with `privileged`, host namespaces or added
capabilities:
- Stage 3's isolation test reruns there: the client is immutable, there is no repo, ledger or `data/`, no other
  session's files, and no direct network.
- It also records the sandboxed process's UID/GID maps, capabilities, namespaces, mount table and `/proc`, beside
  the same record taken on this PC. Any difference is explained or fixed.
- The seccomp and AppArmor profiles are committed in full. A missing profile makes the pod fail to start.
- `procMount: Unmasked`: under `Default`, bubblewrap's `/proc` mount fails (`audit/cluster/gate-diagnosis.md`).
- Signals: processes in the pod must be able to signal their own children (the harness ends a session by killing
  bubblewrap, and bubblewrap's reaper ends by its parent-death signal), so the AppArmor profile allows signals among its
  own, stacked label included.
- From the runner pod, the network policy is tested on the cluster's actual dataplane: node addresses and their
  services, the API server, the LAN, this PC's NFS, IPv6, and a homelab service's public address all refused.
- The stage 3 harness hash and the thesis manifest are computed in the pod. Each launch checks them against the frozen
  ones.

## 5. The mirror on this PC: the live data's only copy

The `mirror` CronJob (`concurrencyPolicy: Forbid`) runs every 10 minutes (`ops/live.py`, `mirror`). Any failed check
stops the run:
- Day files (`*.jsonl`) only grow: one that shrank, changed below its mirrored length, or vanished from the source is
  refused.
- Every copy's bytes are compared with the source's over the same length.
- SQLite ledgers are point-in-time snapshots (SQLite's backup) that must pass its integrity check.
- Other files are copied whole when their size or mtime changes.
- A mirrored file shorter than its manifest entry is refused.

Each volume's `MANIFEST.json` lists every file's size, mtime and sha256, and the volume's usage. It is written last,
so readers trust only what it lists. The `mirror-verify` CronJob re-hashes daily every mirrored file, and every day
file's source over its mirrored length, against the manifest.

When this PC is off, runs fail and the next one catches up. Until then, prodesk7's volumes hold the only copy of
anything newer. On this PC, each mirrored recorder is one more host directory, read like `data/live-oci`'s through
its manifest, and staged into batch inputs by hash as today.

## 6. Cut-over

Done 2026-10-30 (`audit/cluster/handoff.md`): the stage 3 harness was refrozen and the thesis track cut a new version
at the move; this PC's recorders handed off at a reboot, after the overlaps reconciled. Git keeps the old paths for
rollback, and a rollback never reruns a consumed campaign or date.
