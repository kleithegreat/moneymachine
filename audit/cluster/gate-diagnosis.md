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
