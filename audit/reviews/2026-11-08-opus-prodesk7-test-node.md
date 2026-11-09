# prodesk7 test node (Homelab role mm-test-node), review by a fresh Claude (Opus), 2026-11-08 17:48 UTC (12:48 EST)

Reviewed: Homelab `9929aa9` (role `roles/mm-test-node`, playbook `playbooks/mm-test-node.yml`, built by Sonnet), plus what is
actually deployed on prodesk7, which is the Homelab working tree, not the commit: uncommitted `files/mm-tests` (stdin
lifeline), `files/mm-tests-run` (runs the controller's `stage/<id>/run.sh`), daemon cap 1G → 2G. The controller side read
is the uncommitted `run_unit` in `../mm-prodesk7` `ops/shards.py`. Nothing in either repo or on the node was edited. Probes
ran as two throwaway instances through the role's wrapper (`opusreview1`, `opusreview2`, 17:44–17:47 UTC (12:44–12:47 EST));
 everything they created (stage dirs, a 1 MiB `/dev/shm` file, one SysV segment) was removed, verified absent
afterwards. Live pods' restart counts were 1 each (11 h old) before and after. Nothing inside `/var/lib/rancher`,
`/home/kevin` or pod logs was read.

**Verdict: yes after fixes.** The path isolation holds against every route tried, including the Nix daemon. What fails is
resource and channel isolation: three escapes reproduced (host `/dev/shm` and SysV IPC outlive the unit and its memory cap;
the stage directory turns kevin into a confused deputy; crashes run apport as root outside the cgroup), and two hold by
configuration (no aggregate cap across instances; `IOWeight=1` is inert). Recorders are the first pods kubelet evicts
under memory pressure (priority −50, `CLUSTER.md` §1), so every memory escape below lands on them.

## Findings, ranked

1. **Host `/dev/shm` and SysV IPC escape the 4G cap and outlive the unit (reproduced).** `PrivateDevices=yes` bind-mounts
   the host's `/dev/shm` (7.5G tmpfs) into the unit; there is no `PrivateIPC`/`RemoveIPC`. Probe 1 wrote
   `/dev/shm/mm-review-probe` and ran `ipcmk -M 4096`; after the unit ended both were still on the host, owned by mmtest.
   Pages are charged to the unit only while it lives; afterwards they belong to nobody the OOM killer can kill. Two runs
   writing ~3.9G each pin 7.5G of a 14.9 GiB node; SysV segments (no `shmmax` limit set) add more. A killed honest test
   leaks the same way. Outcome: node memory pressure → kubelet evicts recorders first, or global OOM with no test process
   left to kill → **recording gap**. Fix in `mm-tests@.service`: `PrivateIPC=yes` and a private `/dev/shm`
   (`TemporaryFileSystem=/tmp:size=1G,... /dev/shm:size=…,mode=1777,nosuid,nodev`); both die with the unit's namespaces.
   Verify with the same two-run probe.

2. **No aggregate cap: every instance gets its own 4G (confirmed by config).** The template's parent
   `system-mm\x2dtests.slice` has `memory.max = max`; the controller names each run by a fresh uuid, and two builders run
   shards concurrently. REMOTE's `flock 9` is not a boundary: fd 9 is inherited by pytest, and any test can
   `flock(9, LOCK_UN)` to let a waiting instance proceed. Budget even for one instance: MemTotal 15,621,204 kB = 14.9 GiB;
   kubepods peak 4.76 GiB; host peak ~2.4 GiB; unit 4 GiB; daemon 2 GiB (deployed, and pinned at it during the builder's
   run: `memory.events max 38712`) leaves ~1.6–1.8 GiB, not the 3 GB `defaults/main.yml` derives (it uses 16.0 GB total,
   mixes GB with the GiB of `MemoryMax`, and predates the 2G daemon). A second instance takes the node over. Outcome:
   **recorders evicted or OOM-killed**. Fix: one top-level `mm-test.slice` holding `mm-tests@`, `nix-daemon.service` and
   `mm-test-gc.service` (`Slice=` in each), with the single budget on it: `MemoryMax` derived in GiB from measured peaks,
   `MemorySwapMax=0`, `TasksMax`, `AllowedCPUs`, `CPUWeight=idle`, IO limits (finding 4). At top level `cpu.idle` competes
   with `kubepods.slice` directly; today it only yields inside `system.slice`, which still takes up to 100/(100+469) of
   contended CPU from the pods. Delete the per-unit copies of those settings.

3. **The stage directory makes kevin a confused deputy (reproduced).** The controller creates `stage/<id>` mode 770 group
   mmtest and writes `run.sh`, `workers`, `in.tar.gz` into it, then `cat`s `out.log` and `report.json` from it, as kevin:
   uid 1000, owner of the recordings, `NOPASSWD: ALL` on prodesk7. `fs.protected_symlinks` does not cover a non-sticky
   directory. Probe 1 planted `report.json -> /etc/hostname` and `link -> kevinfile`; kevin's `cat report.json` printed
   `prodesk7`, and kevin's `printf … > link` rewrote `kevinfile`. A test can read any file kevin can (a live recording in the
   forward window) into the controller's log on the PC, and, with a second instance running (finding 2), plant
   `in.tar.gz` in the next run's directory between kevin's `mkdir` and `cat >`, so kevin overwrites any file it can write.
   PVC directory names are visible to the unit in `/proc/self/mountinfo`. Outcomes: **a recording overwritten**;
   **forward-window data reaches research** (CLAUDE.md, Holdout). Fix: mmtest never gets to create entries where kevin
   writes or reads by path. The controller makes `stage/<id>` 2750, writes inputs 0640, and pre-creates `out.log` and
   `report.json` 0660; the runner writes them in place (`mm-tests-run`'s redirect and `conftest.py`'s `write_text` already
   do). Fix the role's comment and `run_unit` together.

4. **`IOWeight=1` does nothing (confirmed by config, not measured).** sda uses `mq-deadline` and `io.cost.qos` is unset,
   so `io.weight` is ignored. The unit and the daemon can saturate the disk under the PVCs: the loop image's writes land
   on the same root LV. Outcome: recorder write latency; a **gap** if a write stalls past a poll (depends on the recorder).
   Fix: `IOReadBandwidthMax`/`IOWriteBandwidthMax`/`IO*IOPSMax` on `/var/lib/mmtest` (loop0, so it covers the tests and
   Nix's store writes) on the slice of finding 2. Derive the numbers from the disk's measured capacity and the recorders'
   need, then verify with a rate-limited fio probe.

5. **Crashes run apport as root outside the unit (reproduced).** `core_pattern` pipes to apport, and the kernel spawns pipe
   helpers regardless of `RLIMIT_CORE`. 20 SIGSEGVs from probe 1 produced 9 sampled `apport` processes as root, none in the
   unit's cgroup. A crash loop turns the unit's idle CPU into normal-priority root CPU work and uncapped memory (one Python
   start per crash). Outcome: **CPU and memory starvation of pods**, bounded by how fast the unit can fork. Fix: on
   prodesk7, disable apport (`kernel.core_pattern=core`), and set `LimitCORE=0` on the unit.

6. **Nix daemon, the main question: no escape found; harden the residue.** Checked: the unit is untrusted (`nix store
   info`: `Trusted: 0`; `trusted-users = root`). `builtins.path` and `nix store add` read host paths in the client, which is
   mmtest in the sandbox, so `/var/lib/rancher` is unreachable that way. Builds run sandboxed (`sandbox = true`) as nixbld
   (the daemon runs as root, so `build-users-group` defaults to `nixbld`; `nix config show` as kevin prints it empty). They
   run in `/nix/var/nix/builds` on the image, with private IPC and `/dev/shm`. Untrusted clients cannot set
   `sandbox-paths`, `sandbox`, `__noChroot` or untrusted substituters, and the store needs signatures. Untrusted clients
   can set `keep-failed` (it is in the protocol's client settings), but kept build dirs stay on the image. Builds are
   charged to `nix-daemon.service` (`use-cgroups = false`), idle, on CPUs 0-9. Residue: (a) `sandbox-fallback = true`: if
   sandbox setup ever fails, builds run unsandboxed as nixbld in the host mount namespace; I found no way for a client to
   force it. Set `sandbox-fallback = false` in `nix.custom.conf`. (b) `TasksMax=1048576` from Determinate's unit lets a
   build fork-bomb until its memory cap (~70k tasks of `threads-max` 121,486); the slice's `TasksMax` covers it. (c)
   `determinate-nixd.socket` is mode 0666, a root HTTP API reachable by tests. Not examined: either restrict it
   (`SocketMode=0600` drop-in, if the CLI does not need it) or check its endpoints. (d) The daemon is still root code
   parsing untrusted input, with past local-root bugs; keep it updated. Outcome at stake: any daemon escape is root, so
   **recordings readable or destroyed**.

7. **The unit does not require its mounts (low).** `nix.mount` requires `var-lib-mmtest.mount`, and the daemon's units are
   `RequiredBy` it (verified), so a missing image leaves the daemon down rather than writing to the root fs. `mm-tests@`
   has no such dependency: today a failed image mount only fails runs, because the underlying `/var/lib/mmtest` is root
   0755 (from the task order; not visible under the mount). Fix: `RequiresMountsFor=/var/lib/mmtest /nix`. Outcome: root
   fs writes → **kubelet nodefs eviction** (only far from today's 383G free).

8. **Logs reach the root fs (low, not tested).** `/dev/log` is inside the unit and rsyslog is active; journald's per-unit
   limit (10,000 messages/30 s) still allows GBs per hour into `/var/log`. Fix: `LogRateLimitIntervalSec`/`LogRateLimitBurst`
   or `LogLevelMax` on the unit. Outcome: the root fs filling → **eviction or recorder ENOSPC**, after many hours of
   deliberate spam.

## Stale or redundant (no outcome; delete)

- The commit's `mm-tests-run` (`src.tar`/`tests`, `work/<id>`) and 1G daemon cap are not what runs: commit the working
  tree, and then the deployed state can be reviewed by hash.
- "Preallocate the image": mkfs.ext4's discard punched the fallocated blocks out (5.1 GB allocated of 48 GB), and
  `fstrim.timer` keeps them out. The bound is "at most 48 GiB of the root fs", which is fine (383 GB free); delete the
  task and the "fixed-size" wording.
- `/etc/sudoers.d/mm-tests` grants nothing: kevin already has `NOPASSWD: ALL` on prodesk7, so the wrapper's id check is
  not a boundary (it does block option and path injection, verified by reading). The id regex is duplicated in
  `mm-tests-run`.
- `-/home/kevin` in `InaccessiblePaths` duplicates `ProtectHome=yes` (stat of `/home/kevin` gives EACCES from
  ProtectHome).
- `CLUSTER.md` §7 ("prodesk7 … has no Nix: it is refused before SSH") goes stale when the runner change lands.

## Checked and holding

- Overmounts: `/var/lib/rancher`, `/var/lib/kubelet`, `/etc/rancher`, `/run/k3s`, `/run/containerd` are `d---------
  root` inside the unit.
- `/proc/<pid>/root` of PID 1 and of uid-1000 pod processes: EACCES.
- A user namespace (unprivileged userns is enabled on prodesk7) cannot lift the overmounts: `umount /var/lib/rancher`
  reports "not mounted", a non-recursive bind of `/var/lib` fails (locked children), and `--rbind` shows the overmount.
- No hardlink route (different filesystem; `protected_hardlinks=1`).
- Tarball extraction runs as mmtest inside the sandbox, so `..`, absolute paths and symlinks reach only what mmtest can.
- The NFS exports to prodesk7 are `secure` and `ip_unprivileged_port_start=1024`, so the unit cannot speak NFS to the
  mirror. Other host listeners (6443, 10250, etcd 2379, CRI stream 10010) need credentials that are hidden from the unit.
- Reboot: the `nofail` mounts are not ordered before `local-fs.target`, and nothing the role added orders before k3s.
- Host changes by the Determinate installer: `/etc/bash.bashrc`, `/etc/zshrc`, `/etc/profile.d/nix.sh` (interactive
  shells only), nixbld uids 30001–32, a tmpfiles symlink into `/nix`. No sysctl, k3s, containerd or cgroup-delegation
  change (`99-homelab.conf` predates the install).

## Re-review, 2026-11-08 18:21 UTC (13:21 EST)

Reviewed: Homelab `cbaff55` (the deployed tree as found) and `baebaeb` (fixes), checked against the node: every unit,
drop-in, script and setting matches `baebaeb`. Also the runner on branch `prodesk7-node` at `2760267` in `../mm-prodesk7`
(`git diff main...prodesk7-node`: `ops/shards.py` `run_unit`, `CLUSTER.md` §7, `ops/test_shards.py`). The probes went
through the controller's real code path: a driver imported `ops/shards.py` from that worktree, replaced only `REMOTE`
(the probe script) and `package` (an empty tarball), and called `run_unit(…, "prodesk7", …)`. That ran the real
`prepare` over SSH, `sudo mm-tests start` with the stdin lifeline, the `cat`s and the final `rm -rf`. Probes ran
18:18–18:20 UTC (13:18–13:20 EST). Afterwards: stage empty, no mmtest processes, no probe files in `/dev/shm`, no mmtest
SysV segments, and the probe's store paths deleted. Pods' restart counts were unchanged (1 each, 11 h old).

**Verdict: yes, safe to run the full suite there.** Every escape from the first review is closed, and the reproduced ones
were re-run and now fail. One adversarial gap stays open: write IOPS (open item 1). It is a latency risk the project's
own suite does not exercise, so it does not block.

Probe results:

- **Host `/dev/shm` and SysV IPC: closed (re-run).** In the unit, `/dev/shm` and `/tmp` are each a private 1 GiB tmpfs.
  The probe wrote `/dev/shm/mm-review-probe` and an `ipcmk -M 4096` segment. After the unit ended, the host had neither.
- **Two concurrent instances: serialized (re-run).** Two `run_unit` calls started together. B ran
  18:18:52.8–18:19:04.9 UTC, and A started at 18:19:05.4 UTC, after B ended. The wrapper's flock on `/run/mm-tests.lock`
  is held outside the unit: the unit's fds were stdin, the pipe and `out.log`, with no lock fd, so a test cannot release
  it. Both ran in `/mmtest.slice/mm-tests@<id>.service`. The slice caps the aggregate anyway (`memory.max` 5 GiB,
  `pids.max` 8192, `cpu.idle` 1, CPUs 0-9, `io.max` on 7:0 and 8:0).
- **Symlink planting, confused deputy: closed (re-run through `run_unit`).** As mmtest, every attempt was refused: `ln -s`
  into `stage/<id>`, `mv report.json`, a hard link of `out.log`, `chmod out.log`, and `touch` in `/var/lib/mmtest` and
  `stage/`. `stage/<id>` is `drwxr-s--- kevin:mmtest`; the inputs are 0640, and `out.log` and `report.json` are 0660
  kevin-owned. The controller read back only what the unit wrote into those files, and `rm -rf` removed the directory.
- **Crash loop: apport gone; a root helper remains, judged acceptable.** 300 SIGSEGVs took 0.9 s, and the host sampler
  saw no `apport` or helper process. With `core_pattern = |/bin/false`, the kernel still execs `/bin/false` as root,
  outside every cgroup, once per crash, because pipe helpers ignore `RLIMIT_CORE`. It lives about a millisecond, and the
  crashes are only produced as fast as the idle-class loop runs. **The node-wide change is right:** `core` plus
  `LimitCORE=0` would stop the helper for the unit, but k3s runs with `LimitCORE=infinity`, so crashing containers would
  start writing full core files into their working directories, possibly on the PVCs' filesystem. `|/bin/false`
  writes nothing anywhere. The only cost is crash dumps on prodesk7, which apport never collected for containers
  anyway.
- **Memory hog: capped (re-run).** The probe filled 1000 MiB of `/dev/shm` and 900 MiB of `/tmp`, then added anonymous
  memory in 256 MiB steps. The slice rose to 5,368,504,320 B (the 5 GiB cap; the daemon's cache was reclaimed first),
  and the OOM killer ended the unit at 3,072 MiB of anonymous memory (`OOMPolicy=kill`, group kill). Host MemAvailable
  never fell below 7.5 GB, kubepods stayed at ~2.9 GB, the Nix daemon kept running (`NRestarts=0`), and the slice fell
  back to 17 MB. The controller still got the report written before the hog and returned exit 1.
- **Nix daemon routes: closed.**
  - `nix store info`: `Trusted: 0`.
  - A build requested with `sandbox false`, `sandbox-fallback true`, `sandbox-paths /var/lib/rancher` and
    `build-users-group ""` drew "ignoring the client-specified setting … restricted setting" for each, and ran
    sandboxed with only busybox `sh`.
  - `sandbox-fallback = false` is in `nix.custom.conf`.
  - Connecting to `determinate-nixd.socket` (now `srw------- root`) fails with EACCES.
  - The daemon and the gc are in `mmtest.slice`, so its `TasksMax=1048576` is bounded by the slice's 8192.
- **Reboot and mount ordering (checked by config).** `mm-tests@` has `Requires=var-lib-mmtest.mount` and
  `RequiresMountsFor=/nix`, so it is ordered after both mounts. `mmtest.slice` depends only on `-.slice`. apport is
  `disabled`, and `99-mm-test-node.conf` sets `core_pattern` at boot. `/var/lib/mmtest` is root 0755, and only
  `runner` and `stage` are writable by the unit. Nothing orders before k3s.

`run_unit` (three-dot from main): correct. Prepare uses umask 027, `mkdir -m 750`, pre-creates the outputs and sets them
to 660. The lifeline pipe is held until `wait` returns (`close_fds` keeps it out of the other shards' children), and on
`BOUND` closing it stops the unit. An empty `report.json` parses to `{}`, so that node's tests are rerun here. The final
`rm -rf` runs even when prepare fails, and a stage orphaned by a killed controller is reaped after 180 min, safely now,
since mmtest cannot create entries there.

Still open, none of it blocking:

1. **Write IOPS cap above the drive's sync capacity (adversarial, not measured).** `IOWriteIOPSMax=1000` on loop0, but
   the role's own note measures the drive under the PVCs at 290 synchronous 4 KiB writes per second. Each fsync on the
   image becomes a backing-file fsync on the root fs, so a test can fsync from `runner/` faster than the drive can serve
   them. jbd2's journal writes are a root kthread's and are not throttled at all. Recorders' SQLite fsyncs then queue
   behind them on the same journal and drive. Outcome: write stalls; a **gap** only if a recorder misses a poll it
   cannot retake. The honest suite fsyncs little on the image (basetemp is tmpfs). Fix: set the write IOPS cap well
   under 290 (e.g. 100), then measure fsync latency on the root fs during a short capped storm while recorders are
   idle. I did not run that storm, because it is the harm being tested for.
2. **The controller buffers whole files (PC side).** `cat out.log` and `cat report.json` use `capture_output`, and
   `out.log` can grow to the image's free space. Within the 60 s timeout that is several GB in the controller's memory
   on the PC. Fix: read with a size cap (`tail -c`/`head -c`). Outcome: PC memory, not prodesk7.
3. **A full suite has not yet run there.** The private 1 GiB `/tmp` holds basetemp for 5 workers. ENOSPC would show up as
   test failures, not reruns, so the first full run should be compared against a local one. Outcome: false failures
   only.
4. **Leftover empty `mm.slice`** (parent of the old `mm-test.slice` name; no processes, no unit file). It goes at the
   next reboot or with `systemctl stop mm.slice`.
