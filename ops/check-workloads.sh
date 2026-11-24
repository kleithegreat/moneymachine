#!/usr/bin/env bash
# The live workloads' boundaries (CLUSTER.md): over a directory of built manifests, one `<name>.json` per workload, exit 0 only if
# every clause holds. Each violation is printed with its workload's name. The flake check `workload-boundaries` runs this over
# `.#manifests`; ops/test-workloads.sh mutates manifests to show each clause rejects.
set -euo pipefail
shopt -s inherit_errexit

dir=${1:?usage: check-workloads.sh <directory of manifests>}
names="sources datalayer ws vault mirror mirror-verify"

clauses=$(cat <<'JQ'
def pod: if .kind == "CronJob" then .spec.jobTemplate.spec.template.spec else .spec.template.spec end;
def expect($actual; $want; $what):
  if $actual == $want then empty else "\($what) is \($actual | tojson), want \($want | tojson)" end;
pod as $p
| ($p.containers + ($p.initContainers // [])) as $cs
| ($p.securityContext // {}) as $sc
| ($p.volumes // []) as $vols
| ["hl", "sources", "datalayer", "thesis", "agent", "ws"] as $recording
| {sources: ["sources"], datalayer: ["datalayer"], ws: ["ws"], vault: ["ws"],
   mirror: ["thesis", "agent", "mirror"], "mirror-verify": []} as $writers
| (
    ($vols[] | select((has("emptyDir") or has("persistentVolumeClaim") or has("secret")) | not)
      | "volume \(.name) is not an emptyDir, a claim or a Secret"),
    ($vols[] | .persistentVolumeClaim // empty | .claimName
      | select(IN($recording[], "mirror") | not) | "claim \(.) is not a recording volume or the mirror"),
    ($vols[] | select(has("secret"))
      | select(($name == "datalayer" and .secret.secretName == "datalayer-keys") | not)
      | "Secret volume \(.name) (\(.secret.secretName)) is not the datalayer's keys"),
    ($cs[] | select(has("env") or has("envFrom")) | "container \(.name) sets env"),
    (if $p | has("hostUsers") then "pod sets hostUsers" else empty end),
    expect($sc.seccompProfile.type; "RuntimeDefault"; "seccomp profile"),
    expect($sc.appArmorProfile.type; "RuntimeDefault"; "AppArmor profile"),
    expect($sc.runAsUser; 1000; "runAsUser"),
    expect($sc.runAsGroup; 100; "runAsGroup"),
    expect($sc.runAsNonRoot; true; "runAsNonRoot"),
    expect($p.nodeSelector; {"kubernetes.io/hostname": "prodesk7"}; "nodeSelector"),
    expect($p.priorityClassName; "moneymachine-live"; "priorityClassName"),
    expect($p.automountServiceAccountToken; false; "automountServiceAccountToken"),
    ($cs[] | . as $c
      | expect($c.securityContext.readOnlyRootFilesystem; true; "container \($c.name) readOnlyRootFilesystem"),
        expect($c.securityContext.allowPrivilegeEscalation; false; "container \($c.name) allowPrivilegeEscalation"),
        expect($c.securityContext.capabilities.drop; ["ALL"]; "container \($c.name) dropped capabilities"),
        (select(($c.image // "" | test("^git\\.home\\.lab/admin/moneymachine@sha256:[0-9a-f]+$")) | not)
          | "container \($c.name) image \($c.image | tojson) is not the registry's by digest")),
    ($cs[] | .volumeMounts[]? | select(.name | IN($recording[], "mirror"))
      | select(.readOnly != true) | select(.name | IN(($writers[$name] // [])[]) | not)
      | "\(.name) is mounted writable"),
    (if $name == "mirror-verify" then
       (if ($p.terminationGracePeriodSeconds // 0) < 600 then "grace period under 600 s" else empty end),
       (($p.activeDeadlineSeconds, .spec.jobTemplate.spec.activeDeadlineSeconds)
         | select(. != null and . < 1200) | "activeDeadlineSeconds \(.) is under 1200")
     else empty end)
  )
| "\($name): \(.)"
JQ
)

failed=0
for name in $names; do
  file=$dir/$name.json
  if [ ! -f "$file" ]; then
    echo "$name: no manifest in $dir"
    failed=1
    continue
  fi
  violations=$(jq -r --arg name "$name" "$clauses" "$file")
  if [ -n "$violations" ]; then
    printf '%s\n' "$violations"
    failed=1
  fi
done
exit "$failed"
