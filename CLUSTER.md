# CLUSTER: the live workloads on the homelab cluster

The recorders and the mirror run on the homelab's k3s cluster (1.36, containerd 2.3), so this PC can be off without
stopping them. The agent series (stages 3 and 4) has finished. Batch Jobs run in namespace `moneymachine`,
submitted from this PC, inputs and results on its NFS. The Oracle recorder is an independent second Hyperliquid host.

Agent sessions run in bubblewrap with private unix sockets inside runner pods that have their own user namespace. The
CLI's credential reaches a session as `CLAUDE_CODE_OAUTH_TOKEN`, passed by `sandbox/session.py`.

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
| `agent-series` | Job | `cli agent-null swarm` (stage 4's C4.5) | `agent` | `claude-token` | 9,000 s |
| `agent-real` | Job, one attempt | `cli agent-real data/agent/real 1792613363942` | `agent` | `claude-token` | 9,000 s |
| `mirror` | CronJob, every 10 min | section 5 | the five read-only; `mirror` | none | 600 s |
| `mirror-verify` | CronJob, daily | section 5 | the five and `mirror`, read-only | none | 600 s |

- Each volume is mounted at its repo path (`hl` at `data/live`, `sources` at `data/sources_live`, `datalayer` at
  `data/datalayer`, `thesis` at `data/thesis`, `agent` at `data/agent`), so every command runs as it does here.
- All run on prodesk7 (a `kubernetes.io/hostname` node selector) with the `moneymachine-live` priority, as uid 1000, gid 100, read-only root and the commands in exec
  form (Python is PID 1). The series pods add `hostUsers: false`, `procMount: Unmasked` and the Localhost
  profiles. The recorders and the mirror jobs are ordinary restricted pods with RuntimeDefault: NFS takes no
  idmapped mounts.
- **One writer per directory.** Each writer holds an exclusive `flock` on a lock file in its directory and exits if it
  is held: the series does already, and the recorders take one too. A pod on an
  unreachable node is never force-deleted until the node is confirmed down.
- **Stopping.** On SIGTERM, recorders stop between polls and the series between campaigns. Their waits wake on SIGTERM. Bubblewrap's `--die-with-parent` ends a session with its runner.
- **Retries.** A restarted series resumes: a campaign started and unrecorded is recorded as a crash (counted as a
  promotion), never rerun. The real campaign resumes its attempt and never repeats an arm or the release. A Kubernetes retry never becomes a fresh attempt. A rollback never reruns a consumed campaign or date.
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
  The dev shell carries the same claude-code, so the harness hash computed here equal the
  pod's. Each result records the image digest beside the frozen hashes, not inside them.
- **Seeding.** `mm` is never in the image (its identity embeds its build path). `ops/live.py seed` delivers the exact
  bytes: files go through the mirror export, and a pod copies
  them into the volume and checks every sha256. It never overwrites a file with other content. The series finds `mm`
  through `CARGO_TARGET_DIR`.
- **Requests and limits**: recorders 100m and 256Mi (limit 512Mi); series 1 CPU and 3Gi
  (6Gi); mirror jobs 200m and 256Mi (512Mi). Each emptyDir is capped at 2Gi. Capacity alarms: section 5.
- **Availability.** One node holds every volume, so a prodesk7 outage stops everything, and its disk holds the only copy of what the mirror has not yet copied. The Oracle VM is the only
  independent recorder, and only for Hyperliquid.

**`agent-series`** runs a series' declared campaigns (`gate/agent/campaigns.py`, `COHORTS`): stage 4's C4.5,
logged in `agent/swarm-null-3.jsonl` (v1's and v2's `swarm-null*.jsonl` and stage 3's `agent-null*.jsonl` logs stay, their records). N2's funding source comes from
the blob batch Jobs stage, seeded once into the volume under its frozen sha256:
```
python ops/live.py seed <digest> agent /srv/moneymachine/inputs/d07162b80359580d73d78934aa2cba4a47d6e0ce7c14153d6f32ca2adf295c39:inputs/d07162b80359580d73d78934aa2cba4a47d6e0ce7c14153d6f32ca2adf295c39
```
Before its first campaign it loads that blob, the cost cells and `mm` (run once, its sha256 in every row); if one
fails, it exits with nothing started.

## 3. Credentials and usage

The series pods take `CLAUDE_CODE_OAUTH_TOKEN` from `claude-token`, and `sandbox/session.py` passes it into
each session's cleared environment. That is the only way a session gets a credential: no credential file is copied.
Pacing (`wait_for_room`) runs in the series pod and reads each account's windows, TAMU first; it runs the next campaign on the first with room, and the series log records the account's name, never
the token. Recorders hold no credential but `datalayer-keys`.

## 4. Agent sessions

`sandbox/session.py` runs `claude -p` in bubblewrap (`--unshare-all`, cleared environment, read-only store closures,
workspace and private HOME, unix sockets for the client and the egress relay allowing only `api.anthropic.com`). The
egress relay is a hostname-level CONNECT allowlist, not an inference-only gateway. The token is visible to the agent,
in its own environment. The pod adds an outer layer: its own user namespace,
the network policy above, and no service account token.

**Gate**, all in the deployed pod and never repaired with `privileged`, host namespaces or added capabilities:
- A sandboxed session in the runner pod authenticates with the token alone, as the intended account and model, and the
  pacing probe reads that account's windows.
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
- The stage 3 harness hash is computed in the pod. Each launch checks it against the frozen
  one.

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
its manifest, and staged into batch inputs by hash.

### Capacity guard

`ops/diskguard.py`, run hourly by `mm-diskguard.timer` (declared in `ops/units.nix`, the flake's `homeManagerModules.default`, running `nix run .#diskguard`; until the dotfiles import it, the symlinked `ops/diskguard.sh` unit runs), alarms when
**available bytes or inodes are at or below 20% of the filesystem's total**. The choice and its limitations live in
the paper's appendix O2. It measures this PC's `data/` and `/srv/moneymachine/mirror` directly and checks all five
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
Missing reports alarm after login; while logged in, nominal stale-alarm delay is at most 90 minutes from the last
report, plus scheduling and check delays (paper O2). Notification delivery failure fails the service, not a successful
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

## 7. Sharded test runs (no live workloads)

A full suite finishes fastest when one run spreads across this desktop and the idle nodes:
```
python3 ops/shards.py /path/to/worktree
python3 ops/shards.py /path/to/worktree ops -k "live"
python3 ops/shards.py /path/to/worktree --machines local,gmktec
```
The runner collects the test ids here (selection arguments, paths, `-k`, `-m`, go to collection only), splits them into
shards balanced by recorded durations (`~/.cache/mm-shards/durations.json`, refreshed by every run; an unseen test counts
as the median) and by cores (this PC 12, prodesk5 6, gmktec 8, prodesk7 5 workers), learned slowness and learned per-machine overhead (seconds beyond the tests: transfer, Nix, collection, tail), runs the shards at once (`pytest -n auto` on each node; here, workers sized from free memory at 650 MB each, `gate/compute.py`, so concurrent suites shrink) and
merges them: one summary, one exit status. The status is nonzero if any shard exits nonzero, any test fails or errors, or
any collected test goes unreported; tests of a node that gave no result are rerun here. Logs are in a `/tmp/mm-shards-*`
directory, deleted on success. `conftest.py` writes each shard's outcomes under `--shard-report`.

- **Nodes:** prodesk5 (`kevin@192.168.8.229`) and gmktec (`kevin@192.168.8.153`), both with Nix (found by a login shell,
  not by a plain `ssh host command`; the runner extends PATH itself), and prodesk7 (below). SSH must already work
  noninteractively with a known host key; failures are not worked around, and every other destination is refused.
- **prodesk7 holds every live recording**, so it runs tests only through the Homelab role `mm-test-node`: the same
  package is staged in `/var/lib/mmtest/stage/<run>/` and `sudo mm-tests start <run>` runs it as `mmtest` in
  `mm-tests@<run>.service`, under `mmtest.slice`: one budget for the unit, the Nix daemon and its builds and garbage
  collection (5 GiB memory with no swap, 8192 tasks, CPUs 0-9, idle CPU weight, 40 MB/s write and 80 MB/s read on the
  image's device). The pods keep what the node leaves: 14.9 GiB minus kubepods' 4.76 GiB peak, the host's 2.4 GiB and the slice's 5 GiB is
  2.7 GiB. The unit sees none of k3s, the PVCs or `/home`; `/tmp` and `/dev/shm` are 1 GiB tmpfs each, private to it and
  counted in the budget; runs go one at a time under a lock outside every unit, a run lasts at most an hour, and
  the unit stops when the controller's ssh dies (SIGKILL included). Nix and its home live in a 48 GiB sparse image at
  `/var/lib/mmtest`, not on the PVCs' filesystem. Five workers because a worker measured about 0.4 GiB (peak resident
  sum 2.3 GiB for six, locally). Tests that need what the unit lacks must skip (`LOCAL_ONLY` or a capability check);
  a skipped or unreported test is rerun here.
- **A node's checkout is persistent:** `/home/kevin/.cache/mm-runner` (its own HOME with the Nix and Cargo caches, and `w/`; TMPDIR and pytest's basetemp are on tmpfs, `/dev/shm/mm-runner`, emptied after each run, since the SIGKILL tests are storage-sensitive, `audit/2026-11-04-suite-speed.md`),
  so the kernel build and Nix evaluation are incremental. Each run sends one tarball (a HEAD bundle, the current tracked and
  non-ignored files, the deleted names and the ids), resets `w/` to the bundle's HEAD, overlays the files and stages them for
  Nix; ignored build output stays. A `flock` on the directory serializes runs on a node, so a second builder waits there;
  `nice -n 10`, one hour cap. Nothing outside that directory is read or changed (Nix daemon store operations aside), and the
  checkout is **not a sandbox** for untrusted tests. Delete `/home/kevin/.cache/mm-runner` to reset a node.
- **Rust:** `kernel/tests/test_rust.py` runs the kernel's `cargo test --release` and each mutant (`kernel/mutants/mutants.py`: the
  test must pass on a copy of the tree and fail by assertion on the mutated copy) as ordinary tests, so any shard with a
  toolchain runs them; where `cargo` is missing they skip and are rerun here. Mutants take slots of free memory
  (`SLOT_BYTES`, 2.2 GB) across the run's workers, each with its own cargo target.
- **This PC only** (`LOCAL_ONLY` in `ops/shards.py`): `data/` is never shipped (a node gets an empty `w/data`), so the
  tests that need `data/store` run here, and fail in a worktree without one
  (`kernel/tests/cli/test_differential.py::test_kernel_matches_witness`). So does
  `reference/tests/` under this runner, which builds Lean by Lake; the flake check `reference` runs it with the Nix-built
  `refmm` and the frozen funding blob, on any builder. So do the `gate/tests/test_sandbox.py` tests that resolve host binaries (`/usr/bin/dash`) into the Nix store, which the nodes'
  Ubuntu layout (`/usr/lib/cargo/bin/coreutils`) breaks.
- Links escaping the worktree and nested repositories are refused. Don't edit the source during transfer. The local index
  is not changed.
