#!/usr/bin/env bash
# The live workloads' boundaries (CLUSTER.md), closed-world: over a directory of built manifests, one `<name>.json` per workload,
# exit 0 only if each manifest equals its allowed form. A field is fixed (the manifest, less its free fields, equals the form below)
# or free (type checked: image digest, command, resources, workingDir, schedule, successfulJobsHistoryLimit, the grace period,
# volumes and mounts), and a mount is judged by the claim its volume resolves to, never by a name. The form and the claims table
# are the plan's, not read from ops/workloads.nix. The flake check `workload-boundaries` runs this over `.#manifests`.
set -euo pipefail
shopt -s inherit_errexit

dir=${1:?usage: check-workloads.sh <directory of manifests>}
names="sources datalayer ws vault mirror mirror-verify"

clauses=$(cat <<'JQ'
def leaves: [paths(type != "object" and type != "array")];
def same($got; $want; $what):
  if $got == $want then empty else
    ([($got, $want) | leaves[]] | unique) as $ps
    | [$ps[] | . as $p | (try ($got | getpath($p)) catch null) as $g | (try ($want | getpath($p)) catch null) as $w
       | select($g != $w) | "\($what) \($p | map(tostring) | join(".")) is \($g | tojson), want \($w | tojson)"] as $d
    | if ($d | length) > 0 then $d[] else "\($what) is not its allowed form" end
  end;
def is($v; $t; $what): if ($v | type) == $t then empty else "\($what) must be a \($t)" end;
def recording: {hl: false, sources: false, datalayer: false, thesis: false, agent: false};
def emptyDir($n): {name: $n, emptyDir: {sizeLimit: "2Gi"}};
def keysVolume: {name: "keys", secret: {secretName: "datalayer-keys"}};
def keysMount: {name: "keys", mountPath: "/app/repo/.keys.env", subPath: ".keys.env", readOnly: true};
{sources: {sources: true}, datalayer: {datalayer: true}, ws: {ws: true}, vault: {ws: true},
 mirror: (recording + {thesis: true, agent: true, mirror: true}),
 "mirror-verify": (recording + {mirror: false})} as $table
| (if .kind == "StatefulSet" then ["spec", "template", "spec"]
   elif .kind == "CronJob" then ["spec", "jobTemplate", "spec", "template", "spec"] else null end) as $pp
| if $pp == null then "kind \(.kind | tojson) is not a StatefulSet or a CronJob" else
    getpath($pp) as $p
    | ($p.containers // []) as $cs | ($p.volumes // []) as $vols | {app: $name} as $labels
    | ($name == "mirror-verify") as $mv | ($pp | length > 3) as $cron
    | ({serviceAccountName: "live", automountServiceAccountToken: false, enableServiceLinks: false,
        priorityClassName: "moneymachine-live", nodeSelector: {"kubernetes.io/hostname": "prodesk7"},
        securityContext: {runAsUser: 1000, runAsGroup: 100, fsGroup: 100, runAsNonRoot: true,
          seccompProfile: {type: "RuntimeDefault"}, appArmorProfile: {type: "RuntimeDefault"}},
        containers: [{name: $name, securityContext:
          {allowPrivilegeEscalation: false, readOnlyRootFilesystem: true, capabilities: {drop: ["ALL"]}}}]}
       + (if $cron then {restartPolicy: "Never"} else {} end)) as $pod
    | {metadata: {name: $name, labels: $labels}} as $meta
    | (if $cron then
         {apiVersion: "batch/v1", kind: "CronJob"} + $meta + {spec: {concurrencyPolicy: "Forbid",
           jobTemplate: {spec: {backoffLimit: 0, template: {metadata: {labels: $labels}, spec: $pod}}}}}
       else
         {apiVersion: "apps/v1", kind: "StatefulSet"} + $meta + {spec: {replicas: 1, serviceName: $name,
           selector: {matchLabels: $labels}, template: {metadata: {labels: $labels}, spec: $pod}}}
       end) as $form
    | ([$pp + ["volumes"], $pp + ["terminationGracePeriodSeconds"]]
       + (["image", "command", "resources", "workingDir", "volumeMounts"] | map($pp + ["containers", 0, .]))
       + (if $cron then [["spec", "schedule"], ["spec", "successfulJobsHistoryLimit"]] else [] end)
       + (if $mv then [$pp + ["activeDeadlineSeconds"], ["spec", "jobTemplate", "spec", "activeDeadlineSeconds"]] else [] end)) as $free
    | (
        same(delpaths($free); $form; "manifest"),
        ($cs[] | . as $c
          | is($c.workingDir; "string"; "workingDir"),
            is($c.command; "array"; "command"),
            is($c.resources; "object"; "resources"),
            (if ($c.image | type) == "string" and ($c.image | test("^git\\.home\\.lab/admin/moneymachine@sha256:[0-9a-f]+$")) then empty
             else "image \($c.image | tojson) is not the registry's by digest" end)),
        (if $cron then is(.spec.schedule; "string"; "schedule"), is(.spec.successfulJobsHistoryLimit; "number"; "successfulJobsHistoryLimit") else empty end),
        is($p.terminationGracePeriodSeconds; "number"; "terminationGracePeriodSeconds"),
        ($vols | group_by(.name)[] | select(length > 1) | "volume \(.[0].name) is defined twice"),
        ($vols[] | . as $v
          | if $v.persistentVolumeClaim then
              same($v; {name: $v.name, persistentVolumeClaim: {claimName: $v.persistentVolumeClaim.claimName}}; "claim volume \($v.name)"),
              (($v.persistentVolumeClaim.claimName | tostring) as $claim
               | if $table[$name] | has($claim) then empty else "claim \($claim) is not one \($name) may mount" end)
            elif $name == "datalayer" and $v.name == "keys" then same($v; keysVolume; "volume keys")
            elif $v.name | IN("tmp", "scratch") then same($v; emptyDir($v.name); "volume \($v.name)")
            else "volume \($v.name) is not a claim, an emptyDir or the datalayer's keys" end),
        ($cs[] | (.volumeMounts // [])[] | . as $mt
          | ($vols | map(select(.name == $mt.name)) | .[0]) as $v
          | if $v == null then "mount \($mt.name) names no volume"
            elif $v.persistentVolumeClaim then
              same($mt; {name: $mt.name, mountPath: $mt.mountPath} + ($mt | {readOnly} | with_entries(select(.value != null))); "mount \($mt.name)"),
              is($mt.mountPath; "string"; "mount \($mt.name) mountPath"),
              (($v.persistentVolumeClaim.claimName | tostring) as $claim
               | if $mt.readOnly == true or $table[$name][$claim] == true then empty
                 else "claim \($claim) is mounted writable (as \($mt.name))" end)
            elif $v.secret then same($mt; keysMount; "mount \($mt.name)")
            else same($mt; {name: $mt.name, mountPath: "/\($mt.name)"}; "mount \($mt.name)") end),
        (if $mv then
           (if ($p.terminationGracePeriodSeconds // 0) < 600 then "grace period under 600 s" else empty end),
           (($p.activeDeadlineSeconds, .spec.jobTemplate.spec.activeDeadlineSeconds)
             | select(. != null and . < 1200) | "activeDeadlineSeconds \(.) is under 1200")
         else empty end)
      ) end
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
