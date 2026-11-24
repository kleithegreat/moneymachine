#!/usr/bin/env bash
# Local tests of the deployer in the flake (plan, step 1a, points 1 to 5). Drives the flake from outside; kubectl, skopeo, nix and
# git are stubs on PATH, and nothing reaches the cluster or the registry. Each case prints ok or FAIL and the script exits nonzero
# on any FAIL.
#
# INTERFACE ASSUMED (the builder must provide exactly this; the plan leaves it open):
#   - `.#manifests` (packages.x86_64-linux.manifests): a directory with one `<name>.json` per workload, each the bare manifest
#     as the Python's `manifest(name, digest)` returns it, with a placeholder digest in the image.
#   - `.#apps.x86_64-linux.apply` and `.push`: bash programs that find `kubectl`, `skopeo`, `nix` and `git` on the caller's
#     PATH (not wrapped with their own), and read $HOME for ~/.kube/moneymachine-live.yaml and ~/.config/containers/auth.json.
#     `apply <digest> <name>...` runs `kubectl -n moneymachine-live apply -f -` with KUBECONFIG=$HOME/.kube/moneymachine-live.yaml.
#     `push` carries the flake's own revision (its short form is the first 7 characters of the flake's revision), refuses a tree
#     with none before running anything, runs `nix build ... --print-out-paths` for the image and takes the image from its
#     output, then runs `skopeo copy --digestfile <file> ... docker://git.home.lab/admin/moneymachine:<rev>`.
#   - `ops/check-workloads.sh <dir>`: the boundary check (plan point 3) over a directory of built manifests: exit 0 if every
#     clause holds, else nonzero with the offending workload's name in its output. The flake checks `workload-boundaries` runs
#     it over `.#manifests`; the flake check `volume-table` compares the table's mirrored volumes with `diskguard.VOLUMES`
#     (read from ops/diskguard.py).
set -uo pipefail
shopt -s inherit_errexit
repo=$(git rev-parse --show-toplevel)
scratch=$(mktemp -d "${TMPDIR:-$HOME/.cache}/mm-test-workloads.XXXXXX")
trap 'rm -rf "$scratch"' EXIT
fails=0
names="sources datalayer ws vault mirror mirror-verify"
registry=git.home.lab/admin/moneymachine

pass() { echo "ok   $1"; }
fail() { echo "FAIL $1"; shift; [ $# -eq 0 ] || printf '       %s\n' "$@"; fails=$((fails + 1)); }

fresh() {
  rm -rf "$scratch/t"
  mkdir "$scratch/t"
  (cd "$repo" && git ls-files -z | grep -zv '^data/' | xargs -0 cp --parents -t "$scratch/t") || return 1
  (cd "$scratch/t" && git init -q && git add -A && git -c user.name=t -c user.email=t@t commit -qm fixture) || return 1
}

stubs=$scratch/stubs
mkdir -p "$stubs"
cat >"$stubs/kubectl" <<'STUB'
#!/usr/bin/env bash
{ printf '<%s>' "$@"; printf '\n'; } >>"$STUBLOG/kubectl.args"
echo "$KUBECONFIG" >>"$STUBLOG/kubectl.config"
cat >"$STUBLOG/kubectl.stdin"
STUB
cat >"$stubs/skopeo" <<'STUB'
#!/usr/bin/env bash
{ printf '<%s>' "$@"; printf '\n'; } >>"$STUBLOG/skopeo.args"
while [ $# -gt 0 ]; do
  if [ "$1" = --digestfile ]; then echo "sha256:feedfeedfeed" >"$2"; fi
  shift
done
STUB
cat >"$stubs/nix" <<'STUB'
#!/usr/bin/env bash
{ printf '<%s>' "$@"; printf '\n'; } >>"$STUBLOG/nix.args"
echo /nix/store/fake-image
STUB
cat >"$stubs/git" <<'STUB'
#!/usr/bin/env bash
{ printf '<%s>' "$@"; printf '\n'; } >>"$STUBLOG/git.args"
case "$1" in
  rev-parse) echo deadbee ;;
esac
STUB
chmod +x "$stubs"/*

newlog() { rm -rf "$scratch/log" "$scratch/home"; mkdir -p "$scratch/log" "$scratch/home"; }

# the program of a flake app, built (nix eval alone does not build it); empty on any failure
app_program() {
  local dir=$1 attr=$2 path
  path=$(cd "$dir" && nix eval --raw ".#apps.x86_64-linux.$attr.program" 2>"$scratch/eval.err") || return 1
  [ -n "$path" ] || return 1
  nix build --no-link --impure --expr "
    let f = builtins.getFlake \"git+file://$dir\";
    in f.inputs.nixpkgs.legacyPackages.x86_64-linux.runCommand \"app-built\" { p = f.apps.x86_64-linux.$attr.program; } \"echo \$p > \$out\"
  " >/dev/null 2>>"$scratch/eval.err" || return 1
  [ -x "$path" ] || return 1
  printf '%s' "$path"
}

# Python's apply, through the devshell's interpreter, with kubectl stubbed
pybin=$(cd "$repo" && nix develop -c which python) || { fail "0. the devshell's python is found"; exit 1; }

# 1. Equal to the Python's
newlog
(cd "$repo" && HOME=$scratch/home STUBLOG=$scratch/log PATH=$stubs:$PATH "$pybin" ops/live.py apply sha256:0 $names) >"$scratch/py.out" 2>&1
if [ ! -s "$scratch/log/kubectl.stdin" ]; then
  fail "1. the Python's apply sent a List" "$(tail -3 "$scratch/py.out")"
  pyok=0
else
  cp "$scratch/log/kubectl.stdin" "$scratch/py.list"
  pyok=1
fi

newlog
app_apply=$(app_program "$repo" apply)
if [ -z "$app_apply" ] || [ ! -x "$app_apply" ]; then
  fail "1. the flake's apply app exists" "$(tail -2 "$scratch/eval.err")"
  apply_ok=0
else
  apply_ok=1
  HOME=$scratch/home STUBLOG=$scratch/log PATH=$stubs:$PATH "$app_apply" sha256:0 $names >"$scratch/apply.out" 2>&1
  [ -s "$scratch/log/kubectl.stdin" ] || { fail "1. the flake's apply sent a List" "$(tail -3 "$scratch/apply.out")"; apply_ok=0; }
  cp "$scratch/log/kubectl.stdin" "$scratch/app.list" 2>/dev/null
fi

jqn() { jq -S -e "$1" "$2" 2>/dev/null; }

if [ "$pyok" = 1 ] && [ "$apply_ok" = 1 ]; then
  a=$(jqn 'del(.items)' "$scratch/py.list") && b=$(jqn 'del(.items)' "$scratch/app.list") && [ -n "$a" ] && [ "$a" = "$b" ] \
    && [ "$(jq -r '.kind' "$scratch/app.list")" = List ] && pass "1a. the List envelope equals the Python's" \
    || fail "1a. the List envelope equals the Python's" "$a" "$b"
  count=$(jq '.items | length' "$scratch/app.list" 2>/dev/null)
  [ "$count" = 6 ] && [ "$(jq '.items | length' "$scratch/py.list")" = 6 ] && pass "1b. both lists hold six items" || fail "1b. both lists hold six items" "app: $count"
  for i in 0 1 2 3 4 5; do
    a=$(jqn ".items[$i]" "$scratch/py.list") && b=$(jqn ".items[$i]" "$scratch/app.list") && [ -n "$a" ] && [ "$a" = "$b" ] \
      && pass "1c. item $i equals the Python's ($(jq -r ".items[$i].metadata.name" "$scratch/app.list"))" \
      || fail "1c. item $i equals the Python's"
  done
  args=$(cat "$scratch/log/kubectl.args")
  [ "$args" = "<-n><moneymachine-live><apply><-f><->" ] && [ "$(cat "$scratch/log/kubectl.config")" = "$scratch/home/.kube/moneymachine-live.yaml" ] \
    && pass "1d. kubectl is called as the Python calls it, under ~/.kube/moneymachine-live.yaml" \
    || fail "1d. kubectl is called as the Python calls it" "$args" "$(cat "$scratch/log/kubectl.config")"
else
  fail "1. comparison with the Python's output (a side is missing)"
fi

# 2. The volume table equals diskguard.VOLUMES (flake check volume-table)
fresh || { fail "fixture"; exit 1; }
build() { (cd "$scratch/t" && git add -A && nix build --no-link "$@" 2>&1); }
out=$(build .#checks.x86_64-linux.volume-table) && pass "2a. volume-table passes on this tree" || fail "2a. volume-table passes on this tree" "$(echo "$out" | tail -3)"
sed -i 's|^    "agent": "data/agent",|    "agent": "data/agent",\n    "extra": "data/extra",|' "$scratch/t/ops/diskguard.py"
cmp -s "$scratch/t/ops/diskguard.py" "$repo/ops/diskguard.py" && fail "2b. mutation applied (a volume added to diskguard.VOLUMES)"
if build .#checks.x86_64-linux.volume-table >"$scratch/o" 2>&1; then fail "2b. volume-table rejects a volume the guard has and the table lacks"; else
  grep -q "attribute 'volume-table' .* missing\|does not provide attribute" "$scratch/o" && fail "2b. volume-table exists" || pass "2b. volume-table rejects a volume the guard has and the table lacks"; fi
fresh
sed -i '/^    "thesis": "data\/thesis",/d' "$scratch/t/ops/diskguard.py"
cmp -s "$scratch/t/ops/diskguard.py" "$repo/ops/diskguard.py" && fail "2c. mutation applied (a volume removed from diskguard.VOLUMES)"
if build .#checks.x86_64-linux.volume-table >"$scratch/o" 2>&1; then fail "2c. volume-table rejects a volume the table has and the guard lacks"; else
  grep -q "does not provide attribute" "$scratch/o" && fail "2c. volume-table exists" || pass "2c. volume-table rejects a volume the table has and the guard lacks"; fi

# 3. The boundaries
out=$(cd "$repo" && nix build --no-link .#checks.x86_64-linux.workload-boundaries 2>&1) && pass "3a. workload-boundaries passes on this tree" \
  || fail "3a. workload-boundaries passes on this tree" "$(echo "$out" | tail -3)"
built=$(cd "$repo" && nix build --no-link --print-out-paths .#manifests 2>"$scratch/eval.err")
base_ok=0
if [ -z "$built" ] || [ ! -d "$built" ]; then
  fail "3b. .#manifests builds" "$(tail -2 "$scratch/eval.err")"
else
  have=$(cd "$built" && ls | sort | tr '\n' ' ')
  want=$(for n in $names; do echo "$n.json"; done | sort | tr '\n' ' ')
  if [ "$have" != "$want" ]; then fail "3b. .#manifests holds exactly the six workloads" "$have"
  else
    pass "3b. .#manifests holds exactly the six workloads"
    rm -rf "$scratch/base"; cp -r "$built" "$scratch/base"; chmod -R u+w "$scratch/base"
    if (cd "$repo" && ops/check-workloads.sh "$scratch/base") >"$scratch/o" 2>&1; then base_ok=1; pass "3c. the boundary check passes the built manifests"
    else fail "3c. the boundary check passes the built manifests" "$(tail -3 "$scratch/o")"; fi
    rm -rf "$scratch/empty"; mkdir "$scratch/empty"
    if (cd "$repo" && ops/check-workloads.sh "$scratch/empty") >/dev/null 2>&1; then fail "3d. the boundary check refuses an empty directory"; else pass "3d. the boundary check refuses an empty directory"; fi
  fi
fi

P='def P: if .kind=="CronJob" then .spec.jobTemplate.spec.template.spec else .spec.template.spec end;'
C='P.containers[0]'
mutations=0
mutated() {
  mutations=$((mutations + 1))
  local name=$1 want=$2 workload=$3 filter=$4 out
  if [ "$base_ok" != 1 ]; then fail "3. $name (no passing baseline)"; return; fi
  rm -rf "$scratch/m"; cp -r "$scratch/base" "$scratch/m"
  jq "$P $filter" "$scratch/base/$workload.json" >"$scratch/m/$workload.json" 2>"$scratch/o" || { fail "3. $name (the mutation filter fails)" "$(cat "$scratch/o")"; return; }
  if cmp -s "$scratch/base/$workload.json" "$scratch/m/$workload.json"; then fail "3. $name (the mutation changed nothing)"; return; fi
  out=$(cd "$repo" && ops/check-workloads.sh "$scratch/m" 2>&1)
  local code=$?
  if [ "$want" = reject ]; then
    if [ $code -ne 0 ] && grep -q -- "$workload" <<<"$out"; then pass "3. rejects: $name"; else fail "3. rejects: $name (exit $code, output must name $workload)" "$(echo "$out" | tail -2)"; fi
  else
    [ $code -eq 0 ] && pass "3. accepts: $name" || fail "3. accepts: $name" "$(echo "$out" | tail -2)"
  fi
}

# claims
mutated "a claim named inputs" reject ws 'P.volumes |= map(if .name=="ws" then .persistentVolumeClaim.claimName="inputs" else . end)'
mutated "a claim named results" reject mirror 'P.volumes |= map(if .name=="hl" then .persistentVolumeClaim.claimName="results" else . end)'
mutated "an extra inputs volume" reject vault 'P.volumes += [{name:"inputs",persistentVolumeClaim:{claimName:"inputs"}}]'
# env, hostUsers, secret
mutated "an env on a container" reject ws "$C.env=[{name:\"A\",value:\"b\"}]"
mutated "hostUsers set" reject ws 'P.hostUsers=false'
mutated "the datalayer-keys Secret in vault" reject vault 'P.volumes += [{name:"keys",secret:{secretName:"datalayer-keys"}}]'
# pod
mutated "no seccomp profile" reject ws 'del(P.securityContext.seccompProfile)'
mutated "seccomp Unconfined" reject ws 'P.securityContext.seccompProfile.type="Unconfined"'
mutated "no AppArmor profile" reject ws 'del(P.securityContext.appArmorProfile)'
mutated "AppArmor Unconfined" reject mirror 'P.securityContext.appArmorProfile.type="Unconfined"'
mutated "runAsUser 0" reject vault 'P.securityContext.runAsUser=0'
mutated "runAsGroup 0" reject vault 'P.securityContext.runAsGroup=0'
mutated "runAsNonRoot false" reject vault 'P.securityContext.runAsNonRoot=false'
mutated "no runAsNonRoot" reject sources 'del(P.securityContext.runAsNonRoot)'
mutated "another node" reject sources 'P.nodeSelector={"kubernetes.io/hostname":"prodesk5"}'
mutated "no node selector" reject sources 'del(P.nodeSelector)'
mutated "another priority class" reject datalayer 'P.priorityClassName="system-node-critical"'
mutated "no priority class" reject datalayer 'del(P.priorityClassName)'
mutated "a service-account token" reject ws 'P.automountServiceAccountToken=true'
mutated "no automount setting" reject ws 'del(P.automountServiceAccountToken)'
# container
mutated "a writable root" reject ws "$C.securityContext.readOnlyRootFilesystem=false"
mutated "privilege escalation" reject ws "$C.securityContext.allowPrivilegeEscalation=true"
mutated "a capability not dropped" reject ws "$C.securityContext.capabilities.drop=[\"NET_RAW\"]"
mutated "no capabilities dropped" reject ws "$C.securityContext.capabilities.drop=[]"
mutated "no container security context" reject ws "del($C.securityContext)"
mutated "an image by tag" reject ws "$C.image=\"$registry:latest\""
mutated "an image of another registry" reject ws "$C.image=\"docker.io/library/busybox@sha256:0\""
# recording volumes
mutated "hl writable in mirror" reject mirror "($C.volumeMounts[] | select(.name==\"hl\")).readOnly=false"
mutated "datalayer writable in mirror" reject mirror "($C.volumeMounts[] | select(.name==\"datalayer\")).readOnly=false"
mutated "sources writable in mirror-verify" reject mirror-verify "($C.volumeMounts[] | select(.name==\"sources\")).readOnly=false"
mutated "thesis writable in mirror-verify" reject mirror-verify "($C.volumeMounts[] | select(.name==\"thesis\")).readOnly=false"
mutated "mirror writable in mirror-verify" reject mirror-verify "($C.volumeMounts[] | select(.name==\"mirror\")).readOnly=false"
mutated "mirror writable in vault" reject vault 'P.volumes += [{name:"mirror",persistentVolumeClaim:{claimName:"mirror"}}] | P.containers[0].volumeMounts += [{name:"mirror",mountPath:"/mirror",readOnly:false}]'
mutated "a recording volume mounted with no readOnly in mirror" reject mirror "del(($C.volumeMounts[] | select(.name==\"sources\")).readOnly)"
# mirror-verify
mutated "grace 599 in mirror-verify" reject mirror-verify 'P.terminationGracePeriodSeconds=599'
mutated "pod deadline 1199 in mirror-verify" reject mirror-verify 'P.activeDeadlineSeconds=1199'
mutated "job deadline 1199 in mirror-verify" reject mirror-verify '.spec.jobTemplate.spec.activeDeadlineSeconds=1199'
mutated "grace 601 in mirror-verify" accept mirror-verify 'P.terminationGracePeriodSeconds=601'
mutated "pod deadline 1200 in mirror-verify" accept mirror-verify 'P.activeDeadlineSeconds=1200'
mutated "job deadline 1200 in mirror-verify" accept mirror-verify '.spec.jobTemplate.spec.activeDeadlineSeconds=1200'

# escapes of an enumeration
mutated "container runAsUser 0" reject ws "$C.securityContext.runAsUser=0"
mutated "container runAsNonRoot false" reject ws "$C.securityContext.runAsNonRoot=false"
mutated "container privileged" reject ws "$C.securityContext.privileged=true"
mutated "container seccomp Unconfined" reject ws "$C.securityContext.seccompProfile={type:\"Unconfined\"}"
mutated "container AppArmor Unconfined" reject ws "$C.securityContext.appArmorProfile={type:\"Unconfined\"}"
mutated "container capability SYS_ADMIN added" reject ws "$C.securityContext.capabilities.add=[\"SYS_ADMIN\"]"
mutated "hostNetwork" reject ws 'P.hostNetwork=true'
mutated "hostPID" reject ws 'P.hostPID=true'
mutated "hostIPC" reject ws 'P.hostIPC=true'
mutated "an unknown pod-level key" reject ws 'P.shareProcessNamespace=true'
mutated "an extra container without hardening" reject ws "P.containers += [{name:\"x\",image:\"$registry@sha256:0\"}]"
mutated "an init container without hardening" reject ws "P.initContainers=[{name:\"i\",image:\"$registry@sha256:0\"}]"
mutated "a container envFrom" reject datalayer "$C.envFrom=[{secretRef:{name:\"datalayer-keys\"}}]"
mutated "a pod supplemental group" reject ws 'P.securityContext.supplementalGroups=[0]'
mutated "a pod sysctl" reject ws 'P.securityContext.sysctls=[{name:"net.ipv4.ip_forward",value:"1"}]'
mutated "claim hl writable under a volume named x" reject mirror "P.volumes |= map(if .name==\"hl\" then .name=\"x\" else . end) | ($C.volumeMounts[] | select(.name==\"hl\")) |= (.name=\"x\" | .readOnly=false)"
mutated "claim hl read-only under an alias, writable through a second mount" reject mirror "P.volumes += [{name:\"x\",persistentVolumeClaim:{claimName:\"hl\"}},{name:\"y\",persistentVolumeClaim:{claimName:\"hl\"}}] | $C.volumeMounts += [{name:\"x\",mountPath:\"/x\",readOnly:true},{name:\"y\",mountPath:\"/y\",readOnly:false}]"
mutated "claim hl mounted a second time, writable" reject mirror "$C.volumeMounts += [{name:\"hl\",mountPath:\"/other\",readOnly:false}]"
mutated "a readOnly claim source with a writable mount beside it" reject mirror "(P.volumes[] | select(.name==\"hl\")).persistentVolumeClaim.readOnly=true | ($C.volumeMounts[] | select(.name==\"hl\")).readOnly=false"
# what the boundaries do not constrain
mutated "another image digest" accept ws "$C.image=\"$registry@sha256:abcdef\""
mutated "another command" accept ws "$C.command=[\"mmrec\",\"run\",\"data/other\"]"
mutated "other resources" accept ws "$C.resources={requests:{cpu:\"1\",memory:\"1Gi\"},limits:{memory:\"2Gi\"}}"
mutated "another schedule" accept mirror '.spec.schedule="1 * * * *"'
echo "mutation cases: $mutations"

# 4. apply applies what it is named
if [ "$apply_ok" = 1 ]; then
  newlog
  HOME=$scratch/home STUBLOG=$scratch/log PATH=$stubs:$PATH "$app_apply" sha256:abc ws vault >"$scratch/apply.out" 2>&1
  code=$?
  got=$(jq -c '[.kind, [.items[] | [.metadata.name, .spec.template.spec.containers[0].image // .spec.jobTemplate.spec.template.spec.containers[0].image]]]' "$scratch/log/kubectl.stdin" 2>/dev/null)
  want="[\"List\",[[\"ws\",\"$registry@sha256:abc\"],[\"vault\",\"$registry@sha256:abc\"]]]"
  [ $code -eq 0 ] && [ "$got" = "$want" ] && pass "4a. apply sha256:abc ws vault sends exactly those two at that digest" \
    || fail "4a. apply sha256:abc ws vault sends exactly those two at that digest" "exit $code" "$got"
  for bad in "ws nosuch" "nosuch" "nosuch ws"; do
    newlog
    HOME=$scratch/home STUBLOG=$scratch/log PATH=$stubs:$PATH "$app_apply" sha256:abc $bad >"$scratch/apply.out" 2>&1
    code=$?
    [ $code -ne 0 ] && [ ! -e "$scratch/log/kubectl.args" ] && pass "4b. apply $bad fails before any kubectl call" \
      || fail "4b. apply $bad fails before any kubectl call" "exit $code, kubectl called: $([ -e "$scratch/log/kubectl.args" ] && echo yes || echo no)"
  done
else
  fail "4. apply (the app is missing)"
fi

# 5. push
fresh
push=$(app_program "$scratch/t" push)
rev=$(cd "$scratch/t" && git rev-parse HEAD | cut -c1-7)
if [ -z "$push" ] || [ ! -x "$push" ]; then
  fail "5. the flake's push app exists" "$(tail -2 "$scratch/eval.err")"
else
  newlog
  HOME=$scratch/home STUBLOG=$scratch/log PATH=$stubs:$PATH "$push" >"$scratch/push.out" 2>"$scratch/push.err"
  code=$?
  lines=$(wc -l <"$scratch/push.out")
  ok=1
  [ $code -eq 0 ] && [ "$lines" = 1 ] || ok=0
  jq -e --arg rev "$rev" --arg reg "$registry" '.tag == $rev and .digest == "sha256:feedfeedfeed" and .image == "/nix/store/fake-image"' "$scratch/push.out" >/dev/null 2>&1 || ok=0
  grep -qF -- "<docker://$registry:$rev>" "$scratch/log/skopeo.args" 2>/dev/null || ok=0
  grep -qF "<docker-archive:/nix/store/fake-image>" "$scratch/log/skopeo.args" 2>/dev/null || ok=0
  grep -q -- "deadbee" "$scratch/log/skopeo.args" 2>/dev/null && ok=0
  [ "$ok" = 1 ] && pass "5a. a clean tree prints {tag, digest, image} and tags with the flake's revision, not HEAD's" \
    || fail "5a. a clean tree prints {tag, digest, image} and tags with the flake's revision" "exit $code, lines $lines, want tag $rev" "$(cat "$scratch/push.out")" "$(cat "$scratch/log/skopeo.args" 2>/dev/null)"
  grep -qF "<build>" "$scratch/log/nix.args" 2>/dev/null && pass "5b. a clean tree builds the image with nix" || fail "5b. a clean tree builds the image with nix"

  echo "# dirty" >>"$scratch/t/CLAUDE.md"
  dirty=$(app_program "$scratch/t" push)
  if [ -z "$dirty" ] || [ ! -x "$dirty" ]; then
    fail "5c. the push app of a dirty tree evaluates" "$(tail -2 "$scratch/eval.err")"
  else
    newlog
    HOME=$scratch/home STUBLOG=$scratch/log PATH=$stubs:$PATH "$dirty" >"$scratch/push.out" 2>"$scratch/push.err"
    code=$?
    if [ $code -ne 0 ] && [ ! -e "$scratch/log/nix.args" ] && [ ! -e "$scratch/log/skopeo.args" ] && [ ! -s "$scratch/push.out" ]; then
      pass "5c. a dirty tree is refused before anything is built or copied"
    else
      fail "5c. a dirty tree is refused before anything is built or copied" "exit $code" "nix called: $([ -e "$scratch/log/nix.args" ] && echo yes || echo no)" "skopeo called: $([ -e "$scratch/log/skopeo.args" ] && echo yes || echo no)"
    fi
  fi
fi

[ "$fails" -eq 0 ] || { echo "$fails failed"; exit 1; }
echo "all passed"
