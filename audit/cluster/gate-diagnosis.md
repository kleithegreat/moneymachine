# Sandbox gate on prodesk7: diagnosis

Probes in runner pods (`hostUsers: false`, uid 1000, all capabilities dropped), image `sha256:97b2817f…`:

| seccomp | AppArmor | `bwrap --unshare-user` | `bwrap --unshare-all --proc /proc` |
|---|---|---|---|
| Localhost `profiles/moneymachine-sandbox.json` | Localhost `moneymachine-sandbox` (label `moneymachine-sandbox//&unconfined`) | setting up uid map: Permission denied | loopback: Failed RTM_NEWADDR: Operation not permitted |
| Localhost | RuntimeDefault (label `cri-containerd.apparmor.d//&unconfined`) | setting up uid map: Permission denied | loopback: Failed RTM_NEWADDR: Operation not permitted |
| RuntimeDefault | Localhost | No permissions to create a new namespace | same |

`procMount: Unmasked` is refused at admission: `violates PodSecurity "restricted:latest": procMount`.

The same image passes all six isolation tests in rootless podman on this PC (NixOS, no AppArmor): user namespace, every
capability dropped, default seccomp, `/proc` unmasked.

## After option (a): `kernel.apparmor_restrict_unprivileged_userns=0` on prodesk7, namespace `enforce: baseline`

- `procMount: Default`: bubblewrap builds its namespaces, then fails `Can't mount proc on /proc: Operation not permitted`
  (`gate-default.json`). `Unmasked` mounts it.
- Under `Unmasked`, a sandboxed `claude -p` authenticates with `CLAUDE_CODE_OAUTH_TOKEN` alone through the relay (egress
  log: only `CONNECT api.anthropic.com:443`, allowed) and returns `"subtype":"success"`. Yet neither it nor
  `claude --version` returns to its caller, and the isolation tests stall.
- Cause: signals are denied. In a runner pod (labels `moneymachine-sandbox//&unconfined`, and
  `cri-containerd.apparmor.d//&unconfined` under the runtime default), `kill -9` from the pod's shell to its own child
  (`sleep`, or bubblewrap) fails with `Permission denied`. So bubblewrap's PID-1 reaper never receives its parent-death
  signal when the outer process exits. A leftover (here a background `sleep 300`, in a session the relay loop) keeps the
  output pipe open: a piped run took 300 s despite `timeout -s KILL 25`.
- With `--as-pid-1` the leftover dies with the command (piped run: 0 s), but killing bubblewrap from outside still
  fails, so the harness's turn and wall-time limits would not hold. The profile must allow signals.
