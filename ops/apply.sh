# apply <digest> <name>...: apply the named workloads at an image digest. `manifests` and `registry` are set above this text.
shopt -s inherit_errexit
usage() {
  echo "usage: apply <sha256:digest> <workload>..." >&2
  exit 2
}
[ $# -ge 2 ] || usage
digest=$1
shift
[[ $digest =~ ^sha256:[0-9a-f]+$ ]] || usage
files=()
for name in "$@"; do
  [[ $name =~ ^[a-z][a-z-]*$ ]] && [ -f "$manifests/$name.json" ] || { echo "apply: no workload named $name" >&2; exit 1; }
  files+=("$manifests/$name.json")
done
list=$(jq -cn --arg image "$registry@$digest" '
  [inputs | (if .kind == "CronJob" then .spec.jobTemplate.spec.template.spec else .spec.template.spec end).containers[0].image = $image]
  | {apiVersion: "v1", kind: "List", items: .}' "${files[@]}")
printf '%s' "$list" | KUBECONFIG=$HOME/.kube/moneymachine-live.yaml kubectl -n moneymachine-live apply -f -
