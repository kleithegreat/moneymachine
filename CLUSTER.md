# CLUSTER: the live workloads on the homelab cluster

The recorders, the thesis track (stage 10) and the agent series (stages 3 and 4) run on the homelab's k3s cluster
(1.36, containerd 2.3), so this PC can be off without stopping them. Batch Jobs stay as they are: namespace
`moneymachine`, submitted from this PC, inputs and results on its NFS. The Oracle recorder stays an independent second
Hyperliquid host.

The agent sandbox does not change: each session still runs in bubblewrap with private unix sockets, inside a runner pod
that has its own user namespace. Every file the stage 3 harness hash and the stage 10 manifest cover stays byte-identical,
and the image carries the exact `claude-code-2.1.304` store path the stage 3 hash names. So stage 3's freeze stands and
the thesis track keeps its version and its C10.5 window.

Section 1 is what the Homelab repo (Flux) builds; sections 2 to 5 are what this repo builds against it.

## 1. Homelab objects

- **Namespace** `moneymachine-live`, Pod Security `enforce: restricted`. No volume of `moneymachine` is mounted in it, so
  no licensed kernel-only data reaches it.
- **Node profiles** on prodesk5, for the runner pods: a Localhost seccomp profile, RuntimeDefault plus `unshare`, `clone`
  and `clone3` with namespace flags, and `mount`, `pivot_root` and `umount2`, as bubblewrap needs; and a Localhost
  AppArmor profile allowing `userns` creation and those mounts (Ubuntu 26.04 restricts unprivileged user namespaces).
  Restricted Pod Security admits both, and admits `procMount: Unmasked` for pods with `hostUsers: false`.
- **PriorityClass** `moneymachine-live`, value above `moneymachine-batch`.
- **PVCs** on prodesk5 (the backed-up node), ReadWriteOnce: `hl` 50Gi, `sources` 5Gi, `datalayer` 20Gi, `thesis`
  20Gi, `agent` 20Gi. Every SQLite ledger lives on one of them, never on NFS.
- **PV and PVC** `mirror`: NFS from this PC, `/srv/moneymachine/mirror`, ReadWriteMany, 200Gi.
- **Secrets**, rendered by Flux from SOPS files the human writes:
  - `claude-credentials`: one key `.credentials.json`, the Cornell account's CLI credential (from `claude
    setup-token`), mounted as the runners' `$HOME/.claude/.credentials.json`, the file the sandbox copies today;
  - `datalayer-keys`: one key `.keys.env`, the lines `BLS_API_KEY`, `BEA_API_KEY`, `EIA_API_KEY` and `SEC_USER_AGENT`
    (the datalayer feeds' declared `auth`). No `DATABENTO_API_KEY` and no FRED key.
- **RBAC**: ServiceAccount `deployer`, bound to this PC's kubeconfig, may create, get, list, watch, update, patch and
  delete statefulsets, jobs, cronjobs and pods, and get pods/log, in `moneymachine-live` only. It can therefore mount
  every Secret and volume there: this PC is trusted with all live credentials and data. Workload pods run as
  ServiceAccount `live` with no permissions and `automountServiceAccountToken: false`.
- **NetworkPolicies**: deny all ingress and egress; allow every pod egress on TCP 80 and 443 to 0.0.0.0/0 except
  10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 100.64.0.0/10 and 169.254.0.0/16, plus DNS to kube-dns. That is
  stricter than this PC, which reaches the whole LAN. IPv6 egress is denied. The homelab confirms that no homelab
  service or licensed-data host is reachable at a public address from the pods.
- **ResourceQuota**: 12 pods, 6 CPU and 12Gi memory requested.

## 2. Workloads (this repo, `ops/live.py`, applied with `deployer`)

| Name | Kind | Command | Volumes | Secret | Grace |
|---|---|---|---|---|---|
| `hl` | StatefulSet | `cli record … /data/hl` | `hl` | none | 300 s |
| `sources` | StatefulSet | `cli sources-record /data/sources` | `sources` | none | 300 s |
| `datalayer` | StatefulSet | `cli datalayer-record /data/datalayer` | `datalayer` | `datalayer-keys` | 300 s |
| `thesis` | StatefulSet | `cli thesis-run` | `thesis`; `datalayer` read-only | `claude-credentials` | 4,200 s |
| `agent-series` | Job | `cli agent-null agent 20` (stage 4: `swarm 10`) | `agent` | `claude-credentials` | 9,000 s |
| `mirror` | CronJob | section 5 | the five read-only; `mirror` | none | 600 s |

- All run on prodesk5 with the `moneymachine-live` priority, as uid 1000, gid 100, read-only root and the commands in exec
  form (Python is PID 1). The thesis and series pods add `hostUsers: false`, `procMount: Unmasked` and the Localhost
  profiles; recorders keep RuntimeDefault.
- **One writer per directory.** Each writer holds an exclusive `flock` on `<dir>/.writer.lock` and exits if it is
  held. A pod on an unreachable node is never force-deleted until the node is confirmed down.
- **Stopping.** Recorders stop between polls on SIGTERM, as today. The series stops between campaigns, and its pacing
  wait wakes on SIGTERM. The thesis runner is covered by its frozen manifest and cannot drain, as on this PC.
  - Its StatefulSet uses `updateStrategy: OnDelete`, so nothing restarts it automatically.
  - A restart is deliberate maintenance after a UTC day's last session. An unplanned kill (a node failure) interrupts
    it as a reboot of this PC would, and is accounted for the same way.
  - Graceful draining needs a code change, so it comes with the track's next version.
  - Bubblewrap's `--die-with-parent` ends a session with its runner.
- **Retries.** A restarted series resumes: a campaign started and unrecorded is recorded as a crash (counted as a
  promotion), never rerun. The real campaign refuses an existing directory. A Kubernetes retry never becomes a fresh
  attempt.
- **Clocks.** Each recorder keeps its own clock log, and prodesk5 runs NTP. The logged offset against the venue's
  server time is the check (C5.3: under 1 s).
- **Images**, built by `nix build` without changing `flake.lock` (which the thesis manifest hashes), pushed and pinned by
  digest:
  - `moneymachine-live`: the repo at `/app`, the Python env, `mm`, the exact `claude-code-2.1.304` store path,
    bubblewrap, sqlite3, rsync, and the Nix store database the sandbox's closure query (`nix-store -qR`) reads.
  - Writable `emptyDir` for `/tmp` and the sessions' work directories.
  - Its `/bin` and `/usr`, which bubblewrap binds into the sandbox, hold what the PC's do: `/bin/sh` and `/usr/bin/env`.
  - Each result records the image digest, beside the frozen hashes and not inside them.
- **Requests and limits**: recorders 100m and 256Mi (limit 512Mi); thesis 500m and 2Gi (4Gi); series 1 CPU and 3Gi
  (6Gi); mirror 200m and 256Mi. Each emptyDir is capped at 2Gi. The mirror reports volume usage, and this PC's
  disk guard raises a blocker above 80 %.
- **Availability.** One node holds every volume, so a prodesk5 outage stops everything. The Oracle VM is the only
  independent recorder, and only for Hyperliquid.

## 3. Credentials and usage

The thesis and series runners hold `claude-credentials`, and their sessions get a copy, as today. Pacing
(`wait_for_room`) runs in the series pod, so it reads the Cornell account's windows, which its sessions spend.
Recorders hold no credential but `datalayer-keys`.

Gate before cut-over: a session in the runner pod must authenticate with that file. If the CLI accepts a
`setup-token` only through `CLAUDE_CODE_OAUTH_TOKEN`, then `sandbox/session.py` must pass it, and that changes both
hashes: stage 3 refreezes before its first campaign, and stage 10 cuts a new track version.

## 4. Agent sessions

Unchanged: `sandbox/session.py` runs `claude -p` in bubblewrap (`--unshare-all`, cleared environment, read-only store
closures, workspace and private HOME, unix sockets for the client and the egress relay allowing only
`api.anthropic.com`). The egress relay is a hostname-level CONNECT allowlist, not an inference-only gateway. The pod
adds an outer layer: its own user namespace, the network policy above, and no service account token.

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
- The stage 3 harness hash and the thesis manifest, computed in the pod, equal the frozen ones. Each is checked again
  at every launch.

## 5. Recorded data back to this PC

The `mirror` CronJob (`concurrencyPolicy: Forbid`) runs every 10 minutes:

- It copies each volume into a new generation directory: day files with `rsync`, and each SQLite ledger with
  `sqlite3 .backup`.
- It hashes every file into the generation's manifest and writes that manifest last, so a generation without one is
  incomplete. It also writes the volumes' usage.
- Day files are append-only: a file that shrank, or changed below its old length, stops the run and is reported. SQLite
  snapshots are point-in-time copies, compared by nothing.
- The data a restore can lose is everything since the last complete generation, which grows while this PC is off.
  prodesk5's volumes are backed up by the homelab.
- When this PC is off, runs fail and the next one catches up; prodesk5's volumes stay the record.
- On this PC, each mirrored recorder is one more host directory, read like `data/live-oci`'s from the latest complete
  generation, and staged into batch inputs by hash as today.

## 6. Cut-over

1. The homelab builds section 1; this repo builds the image and `ops/live.py`. Section 4's gate and section 3's
   credential gate pass, and the human has approved moving the credentials.
2. The cluster recorders start, each in its own host directory. Both hosts then record side by side for 7 days.
3. Handoff, per source: this PC's recorder stops (`recorder-restart`'s SIGTERM path, for the last time) only once
   these hold:
   - the overlap reconciles: the same items and revisions;
   - the cluster's last successful poll is under one cadence old;
   - pagination and clock checks pass;
   - a complete mirror generation contains the handoff time.
   The handoff instant is recorded, and this PC's directories stay as closed hosts.
4. Thesis: after a UTC day's last session, stop it on this PC. Copy `data/thesis` (ledgers by `sqlite3 .backup`,
   with nothing writing; the pinned `mm` byte for byte). Restore-test the copy, check the manifest in the pod, then
   start. The day's sessions and dates are reconciled from the ledger before and after the move.
5. Stage 3: the harness hash is checked in the pod, then the series Job starts.
6. After the handoff: delete what this replaces, and update CLAUDE.md's Recorders, Heavy-jobs and Waiting lines.
   Git keeps the old paths for rollback, and a rollback never reruns a consumed campaign or date.
