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
  - `claude-token`: key `CLAUDE_CODE_OAUTH_TOKEN`, a `claude setup-token` token of the Cornell account; key `PERSONAL`, the personal account's, which the thesis reads (each runner names its key in `ops/live.py`'s `WORKLOADS`); key `TAMU`, the TAMU account's, which only `agent-series` and `agent-real` read (as `CLAUDE_CODE_OAUTH_TOKEN_TAMU` and `_CORNELL`; `wait_for_room` sets `CLAUDE_CODE_OAUTH_TOKEN` to the account it picks);
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
| `agent-series` | Job | `cli agent-null swarm` (stage 4's C4.5; stage 3's `agent` cohort is done) | `agent` | `claude-token` | 9,000 s |
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
  is held: the thesis runner and the series do already, and the recorders take one too. A pod on an
  unreachable node is never force-deleted until the node is confirmed down.
- **Stopping.** On SIGTERM, recorders stop between polls (as today), the thesis runner after its current step (a day's
  sessions, at most four of an hour each, hence its grace), and the series between campaigns. Their waits wake on SIGTERM. The thesis StatefulSet uses `updateStrategy: OnDelete`, so a restart
  is always deliberate. Bubblewrap's `--die-with-parent` ends a session with its runner.
- **Retries.** A restarted series resumes: a campaign started and unrecorded is recorded as a crash (counted as a
  promotion), never rerun. The real campaign resumes its attempt and never repeats an arm or the release. The thesis runner records each date's
  sessions in its ledger and does not repeat one. A Kubernetes retry never becomes a fresh attempt.
- **Clocks.** `sources` logs the node kernel's own bound on its clock error (`adjtimex`: `maxerror_ms`, `esterror_ms`,
  `unsynced`) every cycle as source "clock", key "kernel". It is a bound the kernel's NTP daemon reports, never an
  offset against anything, and it does not prove freshness. C5.3's 72 h segment reports its maximum and requires
  `unsynced` false and `maxerror_ms` under 1000. The Oracle VM keeps its own timesyncd offset log (`ops/oci/clocklog.py`).
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
  (6Gi); mirror jobs 200m and 256Mi (512Mi). Each emptyDir is capped at 2Gi. Capacity alarms: section 5.
- **Availability.** One node holds every volume, so a prodesk7 outage stops everything, and its disk holds the only copy of what the mirror has not yet copied. The Oracle VM is the only
  independent recorder, and only for Hyperliquid.

**`agent-series`** runs a series' declared campaigns (`gate/agent/campaigns.py`, `COHORTS`): now stage 4's C4.5,
logged in `agent/swarm-null-3.jsonl` (v1's and v2's `swarm-null*.jsonl` and stage 3's `agent-null*.jsonl` logs stay, their records). N2's funding source comes from
the blob batch Jobs stage, seeded once into the volume under its frozen sha256:
```
python ops/live.py seed <digest> agent /srv/moneymachine/inputs/d07162b80359580d73d78934aa2cba4a47d6e0ce7c14153d6f32ca2adf295c39:inputs/d07162b80359580d73d78934aa2cba4a47d6e0ce7c14153d6f32ca2adf295c39
```
Before its first campaign it loads that blob, the cost cells and `mm` (run once, its sha256 in every row); if one
fails, it exits with nothing started.

**`agent-real`** (stage 3's one real campaign) is the series' pod with `restartPolicy: Never` and `backoffLimit: 0`: it
never restarts by itself. It holds the series' lock, so it cannot overlap it. Its inputs are not in any volume: seed the
dataset version's store and the untouched holdout into `agent`. The cluster's `real/holdout/spent.jsonl` is then the
one authoritative release store, and the claim is per store, so this PC's copy claims the window before `apply`, which
makes any local use or re-seed fail closed:
```
python ops/live.py seed <digest> agent data/store:real/store data/holdout:real/holdout
echo '{"start":1785542400000,"end":1790726400000,"campaign":"stage3-real"}' >> data/holdout/spent.jsonl
python ops/live.py apply <digest> agent-real
```
To resume after a failed pod, delete the Job and apply it again: it skips what is done, and a claim naming the campaign
means no second evaluation, only the report from `pre-release.json` and the ledger. A void attempt (`void.json`) moves
to `stage3-real-2`. The report is `agent/stage3-real/real.json` in the mirror; check its sha256 against `MANIFEST.json`
and copy it to `audit/stage3/real.json`. Its image needs `audit/stage3/null-summary.json` committed first; the
series stays on its own digest.

`agent-summary` is not a workload: its baseline (`data/campaigns/null.jsonl`) is on this PC, so it runs here, no model
call, on the series log from the mirror (`/srv/moneymachine/mirror/agent/agent-null-3.jsonl`, sha256 checked against
its `MANIFEST.json`, copied to `data/agent/`): `python -m cli agent-summary agent audit/stage3/null-summary.json`. The
summary lists the campaigns' ids and kernels; `agent-real` starts only if they are C3.2 v3's ids and its own `mm`.

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
- Outside sandbox workspaces (`work/`), day files (`*.jsonl`) only grow: one that shrank, changed below its mirrored
  length, or vanished from the source is refused.
- The mirror captures day-file sizes before listing other files (including `raw/`) and copies only those prefixes.
  The datalayer writes each body before its row, so every row in a copied prefix has its body listed. Later rows and
  new day files wait for the next run. No history is parsed; malformed lines are copied as bytes, not a refusal.
- Every copy's bytes are compared with the source's over the same length.
- SQLite ledgers outside workspaces are point-in-time snapshots (SQLite's backup) that must pass its integrity check;
  an observed or previously mirrored ledger vanishing is refused, as for day files.
- Other files, including everything inside a workspace regardless of suffix, are copied whole when their size or
  mtime changes; disappearance during enumeration, copying or source comparison omits them from the new manifest,
  without publishing an unchecked copy. Writers' transient `*.tmp`, locks and SQLite sidecars are excluded.
- A mirrored file shorter than its manifest entry is refused.

Each volume's `MANIFEST.json` lists every file's size, mtime and sha256, and the source filesystem's capacity. It is written last,
so readers trust only what it lists. The `mirror-verify` CronJob re-hashes daily every mirrored file, and every day
file's source over its mirrored length, against the manifest. It refuses a missing manifest for any of the five
expected volumes, including an entirely empty mirror.

When this PC is off, runs fail and the next one catches up. Until then, prodesk7's volumes hold the only copy of
anything newer. On this PC, each mirrored recorder is one more host directory, read like `data/live-oci`'s through
its manifest, and staged into batch inputs by hash as today.

### Capacity guard

`ops/diskguard.py`, run hourly by the existing `mm-diskguard.timer` through `ops/diskguard.sh`, alarms when
**available bytes or inodes are at or below 20% of the filesystem's total**. The choice and its limitations live in
the paper's appendix O2. It measures this PC's `data/` and `/srv/moneymachine/mirror` directly and checks all five
prodesk7 volumes through their manifests' `capacity` counters and `taken` timestamp. These are real filesystem
capacities, not the local-path PVC requests (which do not enforce storage quotas). Shared filesystems need no
separate rule. Byte availability excludes blocks reserved from the writer (`statvfs.f_bavail`); inode availability
uses `f_favail`. Missing, malformed, future-dated or older-than-30-minute reports and unmeasurable filesystems also alarm.
Nothing stops copying or deletes recordings.

Each unhealthy check exits nonzero, logs its reasons to the user service's journal, and sends a **critical, non-expiring
desktop notification** with `notify-send`; it repeats hourly until healthy rather than suppressing an acknowledged
alarm. It no longer edits `PROGRESS.md`. The timer runs only while the human is logged in: **there is no off-PC alarm**.
Missing reports alarm after login; while logged in, nominal stale-alarm delay is at most 90 minutes from the last
report, plus scheduling and check delays (paper O2). Notification delivery failure fails the service, not a successful
check. The desktop notification daemon and user service's session D-Bus environment must work; deployment must verify
that the human actually sees the alarm.
Daily `mirror-verify` integrity failures still appear in Kubernetes job status/logs; this is a capacity/freshness alarm,
not a new integrity-verification guarantee.

Deployed 2026-11-07 03:14 UTC (2026-11-06 22:14 EST): `mirror` and `mirror-verify` on image `sha256:c80908c8…`
(previously `sha256:17764092…`; rolling back is re-applying it to those two). Changing the guard: merge into this PC's
main checkout, which the timer runs; a manifest-format change also needs a new image for those two CronJobs, applied
before the merge, since old manifests alarm. Verify by one normal invocation and the synthetic alarm below, seen by the human.

For the visible alarm check, this injects only an in-memory test result (expected exit 1):
```
nix develop -c python -c 'from ops import diskguard as d; d.check = lambda *a: ["SYNTHETIC TEST: filesystem at 19% available"]; raise SystemExit(d.main())'
```

## 6. Cut-over

Done 2026-10-30 (`audit/cluster/handoff.md`): the stage 3 harness was refrozen and the thesis track cut a new version
at the move; this PC's recorders handed off at a reboot, after the overlaps reconciled. Git keeps the old paths for
rollback, and a rollback never reruns a consumed campaign or date.

## 7. Sharded test runs (no live workloads)

A full suite finishes fastest when one run spreads across this desktop and the idle nodes:
```
python3 ops/shards.py /path/to/worktree
python3 ops/shards.py /path/to/worktree ops thesis -k "registry"
python3 ops/shards.py /path/to/worktree --machines local,gmktec
```
The runner collects the test ids here (selection arguments, paths, `-k`, `-m`, go to collection only), splits them into
shards balanced by recorded durations (`~/.cache/mm-shards/durations.json`, refreshed by every run; an unseen test counts
as the median) and by cores (this PC 12, prodesk5 6, gmktec 8), runs the shards at once (`pytest -n auto` on each) and
merges them: one summary, one exit status. The status is nonzero if any shard exits nonzero, any test fails or errors, or
any collected test goes unreported; tests of a node that gave no result are rerun here. Logs are in a `/tmp/mm-shards-*`
directory, deleted on success. `conftest.py` writes each shard's outcomes under `--shard-report`.

- **Nodes:** prodesk5 (`kevin@192.168.8.229`) and gmktec (`kevin@192.168.8.153`), both with Nix (found by a login shell,
  not by a plain `ssh host command`; the runner extends PATH itself). **prodesk7 holds every live recording and has no Nix:
  it is refused before SSH**, and so is every other destination. SSH must already work noninteractively with a known host
  key; failures are not worked around.
- **A node's checkout is persistent:** `/home/kevin/.cache/mm-runner` (its own HOME with the Nix and Cargo caches, and `w/`; TMPDIR and pytest's basetemp are on tmpfs, `/dev/shm/mm-runner`, emptied after each run, since the SIGKILL tests are storage-sensitive, `audit/2026-11-04-suite-speed.md`),
  so the kernel build and Nix evaluation are incremental. Each run sends one tarball (a HEAD bundle, the current tracked and
  non-ignored files, the deleted names and the ids), resets `w/` to the bundle's HEAD, overlays the files and stages them for
  Nix; ignored build output stays. A `flock` on the directory serializes runs on a node, so a second builder waits there;
  `nice -n 10`, one hour cap. Nothing outside that directory is read or changed (Nix daemon store operations aside), and the
  checkout is **not a sandbox** for untrusted tests. Delete `/home/kevin/.cache/mm-runner` to reset a node.
- **This PC only** (`LOCAL_ONLY` in `ops/shards.py`): `data/` is never shipped (a node gets an empty `w/data`), so the
  tests that need `data/store` run here, and fail in a worktree without one
  (`kernel/tests/cli/test_differential.py::test_kernel_matches_witness`,
  `reference/tests/test_lean_differential.py::test_runs_agree_bit_for_bit`). All of `reference/tests/` stays here, because
  its Lean build took a node six to twelve minutes cold and killed a worker on gmktec, which also runs game servers. So do
  the `gate/tests/test_sandbox.py` tests that resolve host binaries (`/usr/bin/dash`) into the Nix store, which the nodes'
  Ubuntu layout (`/usr/lib/cargo/bin/coreutils`) breaks.
- Links escaping the worktree and nested repositories are refused. Don't edit the source during transfer. The local index
  is not changed.
