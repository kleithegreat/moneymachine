# CLUSTER: the live workloads on the homelab cluster

The recorders and the mirror run on the homelab's k3s cluster (1.36, containerd 2.3), so this PC can be off without
stopping them. The Oracle VM recorded independently until its retirement on 2026-11-22; it now only holds the forward window's Hyperliquid day files until 2027-02-01.

Section 1 is what the Homelab repo (Flux) builds; sections 2, 5 and 6 are what this repo builds against it.

## 1. Homelab objects

- **Namespace** `moneymachine-live`, Pod Security `enforce: baseline` with `warn` and `audit: restricted`. No volume of `moneymachine` is mounted in it, so
  no licensed kernel-only data reaches it.
- **PriorityClass** `moneymachine-live`: value −50, `preemptionPolicy: Never`, so homelab services always win.
- **PVCs**, local-path, ReadWriteOnce, bound on the first pod's node (prodesk7), and not backed up: `hl` 50Gi (retained, its recorder retired 2026-11-22), `sources` 5Gi, `datalayer` 20Gi, `ws` 300Gi (not mirrored: its only copy, the human's choice of 2026-11-14), `thesis`
  20Gi, `agent` 20Gi. Every SQLite ledger lives on one of them, never on NFS.
- **PV and PVC** `mirror`: NFS from this PC, `/srv/moneymachine/mirror`, ReadWriteMany, 200Gi. This PC's NixOS
  configuration exports that directory beside `inputs` and `results`. It holds the only copy of the live data.
- **Secret** `datalayer-keys`, created by the advisor with kubectl from a local file, outside Git: one key `.keys.env`, the lines `BLS_API_KEY`, `BEA_API_KEY`, `EIA_API_KEY` and `SEC_USER_AGENT`
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
| `sources` | StatefulSet | `cli sources-record data/sources_live` | `sources` | none | 300 s |
| `datalayer` | StatefulSet | `cli datalayer-record data/datalayer` | `datalayer` | `datalayer-keys` | 300 s |
| `ws` | StatefulSet | `mmrec run data/ws` (`recorder/RECORDER.md`) | `ws` | none | 30 s |
| `vault` | CronJob, hourly at :07 | `mmvault run data/ws --user 0x53375ca9…2a06` (`recorder/VAULT.md`) | `ws` | none | 30 s |
| `mirror` | CronJob, every 10 min | section 5 | the five read-only; `mirror` | none | 600 s |
| `mirror-verify` | CronJob, daily | section 5 | the five and `mirror`, read-only | none | 600 s |

- Each volume is mounted at its repo path (`hl` at `data/live`, `sources` at `data/sources_live`, `datalayer` at
  `data/datalayer`, `thesis` at `data/thesis`, `agent` at `data/agent`), so every command runs as it does here.
- All run on prodesk7 (a `kubernetes.io/hostname` node selector) with the `moneymachine-live` priority, as uid 1000, gid 100, read-only root and the commands in exec
  form (Python is PID 1). All are ordinary restricted pods with RuntimeDefault: NFS takes no
  idmapped mounts.
- **One writer per directory.** Each writer holds an exclusive `flock` on a lock file in its directory and exits if it
  is held. A pod on an
  unreachable node is never force-deleted until the node is confirmed down.
- **Stopping.** On SIGTERM, recorders stop between polls. Their waits wake on SIGTERM.
- **Retries.** A rollback never reruns a consumed date.
- **Clocks.** `sources` logs the node kernel's own bound on its clock error (`adjtimex`: `maxerror_ms`, `esterror_ms`,
  `unsynced`) every cycle as source "clock", key "kernel". It is a bound the kernel's NTP daemon reports, never an
  offset against anything, and it does not prove freshness. C5.3's 72 h segment reports its maximum and requires
  `unsynced` false and `maxerror_ms` under 1000.
- **Image** `moneymachine`, built by `nix build .#image`, pushed and pinned by digest: the repo at `/app`, the Python
  env, sqlite3, and a writable `emptyDir` for `/tmp`. Its `/bin` and `/usr` hold what the PC's do: `/bin/sh` and
  `/usr/bin/env`.
- **Requests and limits**: recorders 100m and 256Mi (limit 512Mi); mirror jobs 200m and 256Mi (512Mi). Each emptyDir is capped at 2Gi. Capacity alarms: section 5.
- **Availability.** One node holds every volume, so a prodesk7 outage stops everything, and its disk holds the only copy of what the mirror has not yet copied. No second host records.

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

Pull-only copies, append-only prefixes, a manifest published last and checked SQLite snapshots are preservation
choices: they keep prior bytes and separate a live writer from its verifier. They bound no throughput, backlog or
recovery point, and a valid old mirror is no proof of freshness.

Each volume's `MANIFEST.json` lists every file's size, mtime and sha256, and the source filesystem's capacity. It is written last,
so readers trust only what it lists. The `mirror-verify` CronJob re-hashes daily every mirrored file, and every day
file's source over its mirrored length, against the manifest. It refuses a missing manifest for any of the five
expected volumes, including an entirely empty mirror.

When this PC is off, runs fail and the next one catches up. Until then, prodesk7's volumes hold the only copy of
anything newer. On this PC, each mirrored recorder is one more host directory, read like `data/live-oci`'s through
its manifest, and staged into batch inputs by hash.

### Capacity guard

`ops/diskguard.py`, run hourly by `mm-diskguard.timer` (declared in `ops/units.nix`, the flake's `homeManagerModules.default`, running `nix run .#diskguard`), alarms when
**available bytes or inodes are at or below 20% of the filesystem's total**. One fifth is a precautionary choice, not a
response guarantee: it leaves a substantial minority of each filesystem for intervention and scales with the real
filesystem, unlike a fixed byte allowance, at the cost of earlier alarms. At constant growth g on capacity C it leaves
0.2C/g of time, and adequate warning needs that to exceed detection delay plus the human's response time; neither is
measured, so that is not established, and a burst can exhaust the reserve. It measures this PC's `data/` and `/srv/moneymachine/mirror` directly and checks all five
prodesk7 volumes through their manifests' `capacity` counters and `taken` timestamp. These are real filesystem
capacities, not the local-path PVC requests (which do not enforce storage quotas). Shared filesystems need no
separate rule. Byte availability excludes blocks reserved from the writer (`statvfs.f_bavail`); inode availability
uses `f_favail`. Missing, malformed, future-dated or older-than-30-minute reports and unmeasurable filesystems also alarm.
It also alarms when `data/live-oci/last-pull` (written by each good `ops/oci/pull.sh` run, which on failure only exits
nonzero) is missing, future-dated or over an hour old: the Oracle VM keeps the only copy of the forward window's
Hyperliquid days until a pull has run. Nothing stops copying or deletes recordings.

Each unhealthy check exits nonzero, logs its reasons to the user service's journal, and sends a **critical, non-expiring
desktop notification** with `notify-send`; it repeats hourly until healthy rather than suppressing an acknowledged
alarm. The timer runs only while the human is logged in: **there is no off-PC alarm**.
Missing reports alarm after login. Thirty minutes is a chosen tolerance of three ten-minute mirror periods, not a
throughput bound; with the hourly checker, nominal stale-alarm delay while logged in is at most 30 + 60 = 90 minutes
from the last report, plus scheduling and check delays, which is no hard bound or proof of a recovery point. Notification delivery failure fails the service, not a successful
check. The desktop notification daemon and user service's session D-Bus environment must work; deployment must verify
that the human actually sees the alarm.
Daily `mirror-verify` integrity failures still appear in Kubernetes job status/logs; this is a capacity/freshness alarm,
not a new integrity-verification guarantee.

Rolling `mirror` and `mirror-verify` back is re-applying their previous digest to those two. Changing the guard: merge into this PC's
main checkout, which the timer runs; a manifest-format change also needs a new image for those two CronJobs, applied
before the merge, since old manifests alarm. Verify by one normal invocation and the synthetic alarm below, seen by the human.

For the visible alarm check, this injects only an in-memory test result (expected exit 1):
```
nix develop -c python -c 'from ops import diskguard as d; d.check = lambda *a: ["SYNTHETIC TEST: filesystem at 19% available"]; raise SystemExit(d.main())'
```

## 6. Tests (no live workloads)

`nix run .#test`, from the worktree, runs the whole suite in two steps:
```
nix flake check -L          # the checks: built on the remote builders, cached by their inputs
nix develop -c pytest -m local   # the tests marked `local`, here
```
A flake sees only tracked files, so `git add` new ones first. `nix build -L .#checks.x86_64-linux.<name>` runs one group
and `nix log <drv>` shows a failure's full output.

- **The checks** (`flake.nix`, `checks.x86_64-linux`): `style`, `progress-cap`, `ingest`, `ops`,
  `mmrec-tests` and `lean-proofs`. Each runs `pytest -m "not local"`
  over its paths in a Nix sandbox, so it is rebuilt only when its inputs (its source subset) change. Prose (`docs`, `CLAUDE.md`,
  `PROGRESS.md`, ...) is outside every source subset, so a prose-only commit leaves all of them cached.
- **The `local` marker** (`pyproject.toml`): tests that need this PC, because they read the real `data/` (link `data/` into a
  worktree, never commit it), kill a process, or read git history. `nix flake check` skips them and
  `nix run .#test` runs them here.
- **Builders:** the three nodes (prodesk5, gmktec, prodesk7) are Nix remote builders for this PC (dotfiles). prodesk7 holds
  every live recording, so its builds run in the Nix daemon's `mmtest.slice` (5 GiB memory with no swap, CPUs 0-9, idle CPU
  weight, I/O caps on the image's device), with `ProtectHome` and the PVCs and k3s inaccessible; Nix's sandbox does the rest.
  Nothing of the project is kept on a node besides the Nix store.
