#!/usr/bin/env bash
# The live workloads' boundaries (CLUSTER.md), closed-world: over a directory of built manifests, one `<name>.json` per workload,
# exit 0 only if every manifest is made of allowed parts alone. Security contexts must equal their allowed objects, every
# object's keys must be in its allowed set, and a mount is judged by the claim its volume resolves to, never by a name. The
# table of claims is the boundary's own, written here from the plan, not read from ops/workloads.nix. Each violation is printed
# with its workload's name. The flake check `workload-boundaries` runs this over `.#manifests`.
set -euo pipefail
shopt -s inherit_errexit

dir=${1:?usage: check-workloads.sh <directory of manifests>}
names="sources datalayer ws vault mirror mirror-verify"

clauses=$(cat <<'JQ'
def obj($o; $what; $ok):
  if ($o | type) != "object" then "\($what) is not an object"
  else $o | keys[] | select(IN($ok[]) | not) | "\($what) has the key \(.)" end;
def is($v; $t; $what): if ($v | type) == $t then empty else "\($what) must be a \($t)" end;
def eq($actual; $want; $what):
  if $actual == $want then empty else "\($what) is \($actual | tojson), want \($want | tojson)" end;
def recording: {hl: false, sources: false, datalayer: false, thesis: false, agent: false};
{sources: {sources: true}, datalayer: {datalayer: true}, ws: {ws: true}, vault: {ws: true},
 mirror: (recording + {thesis: true, agent: true, mirror: true}),
 "mirror-verify": (recording + {mirror: false})} as $table
| . as $m
| (if .kind == "StatefulSet" then .spec.template.spec
   elif .kind == "CronJob" then .spec.jobTemplate.spec.template.spec else null end) as $p
| (if .kind == "CronJob" then .spec.jobTemplate.spec else null end) as $job
| (if ($p | type) != "object" then "kind \(.kind | tojson) is not a StatefulSet or a CronJob" else
    ($p.containers // []) as $cs
    | ($p.volumes // []) as $vols
    | (
        obj($m; "manifest"; ["apiVersion", "kind", "metadata", "spec"]),
        obj($m.spec; "spec"; if $job == null then ["replicas", "serviceName", "selector", "template"]
          else ["schedule", "concurrencyPolicy", "successfulJobsHistoryLimit", "jobTemplate"] end),
        (if $job == null then obj($m.spec.template; "template"; ["metadata", "spec"]), is($m.spec.serviceName; "string"; "serviceName")
         else obj($job; "job spec"; ["backoffLimit", "template", "activeDeadlineSeconds"]),
              obj($m.spec.jobTemplate; "jobTemplate"; ["metadata", "spec"]),
              obj($job.template; "template"; ["metadata", "spec"]),
              is($m.spec.schedule; "string"; "schedule") end),
        obj($p; "pod spec"; ["serviceAccountName", "automountServiceAccountToken", "enableServiceLinks", "priorityClassName",
          "nodeSelector", "terminationGracePeriodSeconds", "securityContext", "containers", "volumes", "restartPolicy",
          "activeDeadlineSeconds"]),
        is($p.serviceAccountName; "string"; "serviceAccountName"),
        is($p.enableServiceLinks; "boolean"; "enableServiceLinks"),
        is($p.terminationGracePeriodSeconds; "number"; "terminationGracePeriodSeconds"),
        eq($p.automountServiceAccountToken; false; "automountServiceAccountToken"),
        eq($p.priorityClassName; "moneymachine-live"; "priorityClassName"),
        eq($p.nodeSelector; {"kubernetes.io/hostname": "prodesk7"}; "nodeSelector"),
        eq($p.securityContext; {runAsUser: 1000, runAsGroup: 100, fsGroup: 100, runAsNonRoot: true,
          seccompProfile: {type: "RuntimeDefault"}, appArmorProfile: {type: "RuntimeDefault"}}; "pod securityContext"),
        (if ($cs | length) != 1 then "the pod has \($cs | length) containers, want exactly one" else empty end),
        ($cs[] | . as $c
          | obj($c; "container \($c.name)"; ["name", "image", "workingDir", "command", "resources", "securityContext", "volumeMounts"]),
            eq($c.securityContext; {allowPrivilegeEscalation: false, readOnlyRootFilesystem: true, capabilities: {drop: ["ALL"]}};
              "container \($c.name) securityContext"),
            is($c.workingDir; "string"; "container \($c.name) workingDir"),
            is($c.command; "array"; "container \($c.name) command"),
            is($c.resources; "object"; "container \($c.name) resources"),
            (if ($c.image | type) == "string" and ($c.image | test("^git\\.home\\.lab/admin/moneymachine@sha256:[0-9a-f]+$")) then empty
             else "container \($c.name) image \($c.image | tojson) is not the registry's by digest" end)),
        ($vols | group_by(.name)[] | select(length > 1) | "volume \(.[0].name) is defined twice"),
        ($vols[] | . as $v
          | (($v | del(.name) | keys) as $k
             | if $k | IN(["emptyDir"], ["persistentVolumeClaim"], ["secret"]) | not
               then "volume \($v.name) must be exactly one of an emptyDir, a claim or a Secret" else empty end),
            (if $v.emptyDir then obj($v.emptyDir; "emptyDir \($v.name)"; ["sizeLimit"]) else empty end),
            (if $v.persistentVolumeClaim then
               obj($v.persistentVolumeClaim; "claim volume \($v.name)"; ["claimName"]),
               (($v.persistentVolumeClaim.claimName | tostring) as $claim
                | if ($table[$name] | has($claim)) then empty else "claim \($claim) is not one \($name) may mount" end)
             else empty end),
            (if $v.secret then
               obj($v.secret; "Secret volume \($v.name)"; ["secretName"]),
               (if $name == "datalayer" and $v.secret.secretName == "datalayer-keys" then empty
                else "Secret \($v.secret.secretName | tojson) is not the datalayer's keys" end)
             else empty end)),
        ($cs[] | (.volumeMounts // [])[] | . as $mt
          | obj($mt; "mount \($mt.name)"; ["name", "mountPath", "readOnly", "subPath"]),
            (($vols | map(select(.name == $mt.name)) | .[0]) as $v
             | if $v == null then "mount \($mt.name) names no volume"
               elif $v.persistentVolumeClaim then
                 (($v.persistentVolumeClaim.claimName | tostring) as $claim
                  | if $mt.readOnly == true or $table[$name][$claim] == true then empty
                    else "claim \($claim) is mounted writable (as \($mt.name))" end)
               elif $v.secret and $mt.readOnly != true then "Secret volume \($mt.name) is mounted writable"
               else empty end)),
        (if $name == "mirror-verify" then
           (if ($p.terminationGracePeriodSeconds // 0) < 600 then "grace period under 600 s" else empty end),
           (($p.activeDeadlineSeconds, $job.activeDeadlineSeconds)
             | select(. != null and . < 1200) | "activeDeadlineSeconds \(.) is under 1200")
         else empty end)
      ) end)
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
