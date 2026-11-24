# push: build this flake's image, copy it to the registry under the flake's revision, print {tag, digest, image}. `rev` (empty
# when the tree is dirty), `imageDrv` and `registry` are set above this text.
shopt -s inherit_errexit
[ -n "$rev" ] || { echo "push: this flake has no revision (a dirty tree); commit first" >&2; exit 1; }
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
image=$(nix build --no-link --print-out-paths "$imageDrv^*")
skopeo copy --authfile "$HOME/.config/containers/auth.json" --digestfile "$tmp/digest" \
  "docker-archive:$image" "docker://$registry:$rev" >/dev/null
digest=$(<"$tmp/digest")
jq -cn --arg tag "$rev" --arg digest "$digest" --arg image "$image" '{tag: $tag, digest: $digest, image: $image}'
