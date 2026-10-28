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

- **Namespace** `moneymachine-live`, Pod Security `enforce: restricted`. No volume of `moneymachine` is mounted in it, so
  no licensed kernel-only data reaches it.
- **Node profiles** on prodesk5, for the runner pods: a Localhost seccomp profile `moneymachine-bwrap.json` (in the
  kubelet's seccomp directory), RuntimeDefault plus `unshare`, `clone`
  and `clone3` with namespace flags, and `mount`, `pivot_root` and `umount2`, as bubblewrap needs; and a Localhost
  AppArmor profile `moneymachine-bwrap` allowing `userns` creation and those mounts (Ubuntu 26.04 restricts unprivileged user namespaces).
  Restricted Pod Security admits both, and admits `procMount: Unmasked` for pods with `hostUsers: false`.
- **PriorityClass** `moneymachine-live`: negative value, `preemptionPolicy: Never`, so homelab services always win.
- **PVCs** on prodesk5 (the backed-up node), ReadWriteOnce: `hl` 50Gi, `sources` 5Gi, `datalayer` 20Gi, `thesis`
  20Gi, `agent` 20Gi. Every SQLite ledger lives on one of them, never on NFS.
- **PV and PVC** `mirror`: NFS from this PC, `/srv/moneymachine/mirror`, ReadWriteMany, 200Gi. This PC's NixOS
  configuration creates and exports that directory beside `inputs` and `results`.
- **Secrets**, created by the advisor with kubectl from local files, outside Git:
  - `claude-token`: key `CLAUDE_CODE_OAUTH_TOKEN`, a `claude setup-token` token of the Cornell account;
  - `datalayer-keys`: one key `.keys.env`, the lines `BLS_API_KEY`, `BEA_API_KEY`, `EIA_API_KEY` and `SEC_USER_AGENT`
    (the datalayer feeds' declared `auth`). No `DATABENTO_API_KEY` and no FRED key;
  - `restic`: `RESTIC_REPOSITORY`, `RESTIC_PASSWORD` and the repository backend's credentials, if any.
- **RBAC**: ServiceAccount `deployer`, its kubeconfig at this PC's `~/.kube/moneymachine-live.yaml`, may create, get, list, watch, update, patch and
  delete statefulsets, jobs, cronjobs and pods, and get pods/log, in `moneymachine-live` only. It can therefore mount
  every Secret and volume there: this PC is trusted with all live credentials and data. Workload pods run as
  ServiceAccount `live` with no permissions and `automountServiceAccountToken: false`.
- **NetworkPolicies**: deny all ingress and egress; allow every pod egress on TCP 80 and 443 to 0.0.0.0/0 except
  10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 100.64.0.0/10 and 169.254.0.0/16, plus DNS to kube-dns; and the
  `restic` pod egress to the restic repository only. That is stricter than this PC, which reaches the whole LAN.
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
| `mirror` | CronJob, every 10 min | section 5 | the five read-only; `mirror` | none | 600 s |
| `restic` | CronJob, hourly | section 5 | `thesis`, `agent` read-only | `restic` | 600 s |

- Each volume is mounted at its repo path (`hl` at `data/live`, `sources` at `data/sources_live`, `datalayer` at
  `data/datalayer`, `thesis` at `data/thesis`, `agent` at `data/agent`), so every command runs as it does here.
- All run on prodesk5 with the `moneymachine-live` priority, as uid 1000, gid 100, read-only root and the commands in exec
  form (Python is PID 1). The thesis and series pods add `hostUsers: false`, `procMount: Unmasked` and the Localhost
  profiles. The recorders, `mirror` and `restic` are ordinary restricted pods with RuntimeDefault: NFS takes no
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
- **Clocks.** Each recorder keeps its own clock log, and prodesk5 runs NTP. The logged offset against the venue's
  server time is the check (C5.3: under 1 s).
- **Image** `moneymachine`, one for batch and live, built by `nix build .#image`, pushed and pinned by digest:
  - contents: the repo at `/app`, the Python env, `mm`, claude-code pinned in the flake at exactly 2.1.304,
    bubblewrap, sqlite3, rsync, restic, and the Nix store database that the sandbox's closure query (`nix-store -qR`)
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
  (6Gi); mirror and restic 200m and 256Mi (512Mi). Each emptyDir is capped at 2Gi. The mirror reports volume usage,
  and this PC's disk guard raises a blocker above 80 %.
- **Availability.** One node holds every volume, so a prodesk5 outage stops everything. The Oracle VM is the only
  independent recorder, and only for Hyperliquid.

## 3. Credentials and usage

The thesis and series pods take `CLAUDE_CODE_OAUTH_TOKEN` from `claude-token`, and `sandbox/session.py` passes it into
each session's cleared environment. That is the only way a session gets a credential: no credential file is copied.
Pacing (`wait_for_room`) runs in the series pod with the same token, so it reads the Cornell account's windows, which
its sessions spend. Recorders hold no credential but `datalayer-keys`.

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
- `procMount: Default` is tried first; Unmasked is used only if bubblewrap's `/proc` mount fails without it.
- From the runner pod, the network policy is tested on the cluster's actual dataplane: node addresses and their
  services, the API server, the LAN, this PC's NFS, IPv6, and a homelab service's public address all refused.
- The stage 3 harness hash and the thesis manifest are computed in the pod. Each launch checks them against the frozen
  ones.

## 5. Recorded data back to this PC, and backups

The `mirror` CronJob (`concurrencyPolicy: Forbid`) runs every 10 minutes:

- It copies each volume into a new generation directory: day files with `rsync`, and each SQLite ledger with
  `sqlite3 .backup`.
- It hashes every file into the generation's manifest and writes that manifest last, so a generation without one is
  incomplete. It also writes the volumes' usage.
- Day files are append-only: a file that shrank, or changed below its old length, stops the run and is reported. SQLite
  snapshots are point-in-time copies, compared by nothing.
- When this PC is off, runs fail and the next one catches up; prodesk5's volumes stay the record.
- On this PC, each mirrored recorder is one more host directory, read like `data/live-oci`'s from the latest complete
  generation, and staged into batch inputs by hash as today.

The `restic` CronJob (`concurrencyPolicy: Forbid`) runs hourly. It snapshots each live ledger with `sqlite3 .backup`
into an emptyDir and runs `restic backup` of those snapshots to the homelab's repository. It does not depend on this
PC. A restore can lose at most an hour of ledger rows. The homelab's own backup of prodesk5 covers the day files.

## 6. Cut-over

1. The homelab builds section 1; this repo builds the image and `ops/live.py`. Section 3's credential gate and section
   4's sandbox gate pass first.
2. The cluster recorders start, each in its own host directory.
   - **Hyperliquid** reconciles against the Oracle recorder, which is always on, not against this PC.
   - **Sources and datalayer** overlap with this PC's recorders for 72 h, or until the PC's next reboot, whichever
     comes first.
3. Handoff, per source: this PC's recorder stops, and its directory closes as a host. Its last poll is the handoff
   instant, which is recorded. Before then:
   - the overlap reconciles (the same items and revisions);
   - the cluster's last successful poll is under one cadence old;
   - pagination and clock checks pass;
   - a complete mirror generation contains the handoff instant.
4. Thesis: after a UTC day's last session, stop it on this PC. Freeze the new track version here (the freeze builds
   and pins `mm`), commit, build the image, and seed `data/thesis` (ledgers by SQLite's backup, with nothing writing).
   Then start it; its manifest check in the pod confirms the freeze. C10.5's window counts from that freeze.
   - Theses of the previous version keep resolving under their frozen rules, reported under their own version.
   - The day's sessions and dates are reconciled from the ledger before and after the move.
5. Stage 3: the harness was refrozen here before any campaign (`audit/stage3/harness.json`). Seed `mm`; the series Job
   checks the frozen hash at every campaign.
6. After the handoff: delete what this replaces, and update CLAUDE.md's Recorders, Heavy-jobs and Waiting lines.
   Git keeps the old paths for rollback, and a rollback never reruns a consumed campaign or date.
