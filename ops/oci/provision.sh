#!/usr/bin/env bash
# The second Hyperliquid recorder (human decision 2026-10-23), on Oracle Cloud's Always Free tier.
# - This script creates the VM in the tenancy's home region (us-ashburn-1) from Always Free resources only:
#   VCN, internet gateway and subnet, with SSH open only from this PC's current public IP. It tries
#   VM.Standard.A1.Flex (1 OCPU, 6 GB) in each availability domain, then VM.Standard.E2.1.Micro. It is idempotent
#   by display name. Run as: nix develop .#cloud -c ops/oci/provision.sh
# - A budget, mm-free-tier-guard ($1 a month), alerts on actual or forecast spend of $1.
# - cloud-init.yaml installs nix and swap, creates the `mm` user with its own read-only GitHub deploy key, and
#   installs mm-recorder.service: the same recorder code at 600/min, the stage 0 budget, half its own IP's limit, restarted on failure, with a memory cap. Its
#   pidfile is /home/mm/live/recorder.json.
# - The VM never connects to this PC. This PC pulls the VM's files every 10 minutes (pull.sh, mm-oci-pull.timer)
#   into data/live-oci/<instance id>/, append-only, never deleting or truncating.
# - Idle reclamation: Oracle may reclaim an Always Free instance that stays idle for 7 days, and a recorder is
#   mostly idle. Load is never padded to avoid that. If the VM disappears, every pulled file stays here, and a
#   recreated VM (this script again) lands in a new directory.
set -euo pipefail
cd "$(dirname "$0")"
T=$(sed -n 's/^tenancy=//p' ~/.oci/config)
KEY=~/.ssh/mm_oci_ed25519
PC_IP=$(curl -fsS https://checkip.amazonaws.com)
[ -f "$KEY" ] || ssh-keygen -t ed25519 -N '' -C mm-oci-pull -f "$KEY"

VCN=$(oci network vcn list -c "$T" --display-name mm-vcn --query 'data[0].id' --raw-output 2>/dev/null || true)
[ -n "$VCN" ] || VCN=$(oci network vcn create -c "$T" --display-name mm-vcn --cidr-blocks '["10.20.0.0/16"]' --wait-for-state AVAILABLE --query 'data.id' --raw-output)
IGW=$(oci network internet-gateway list -c "$T" --vcn-id "$VCN" --display-name mm-igw --query 'data[0].id' --raw-output 2>/dev/null || true)
[ -n "$IGW" ] || IGW=$(oci network internet-gateway create -c "$T" --vcn-id "$VCN" --display-name mm-igw --is-enabled true --wait-for-state AVAILABLE --query 'data.id' --raw-output)
RT=$(oci network vcn get --vcn-id "$VCN" --query 'data."default-route-table-id"' --raw-output)
oci network route-table update --rt-id "$RT" --force --route-rules "[{\"destination\":\"0.0.0.0/0\",\"networkEntityId\":\"$IGW\"}]" > /dev/null
SL=$(oci network vcn get --vcn-id "$VCN" --query 'data."default-security-list-id"' --raw-output)
oci network security-list update --security-list-id "$SL" --force \
  --ingress-security-rules "[{\"protocol\":\"6\",\"source\":\"$PC_IP/32\",\"tcpOptions\":{\"destinationPortRange\":{\"min\":22,\"max\":22}}}]" \
  --egress-security-rules '[{"protocol":"all","destination":"0.0.0.0/0"}]' > /dev/null
SUB=$(oci network subnet list -c "$T" --vcn-id "$VCN" --display-name mm-subnet --query 'data[0].id' --raw-output 2>/dev/null || true)
[ -n "$SUB" ] || SUB=$(oci network subnet create -c "$T" --vcn-id "$VCN" --display-name mm-subnet --cidr-block 10.20.1.0/24 --wait-for-state AVAILABLE --query 'data.id' --raw-output)

INST=$(oci compute instance list -c "$T" --display-name mm-recorder --lifecycle-state RUNNING --query 'data[0].id' --raw-output 2>/dev/null || true)
if [ -z "$INST" ]; then
  for AD in $(oci iam availability-domain list --query 'data[].name' --raw-output | tr -d '[]",'); do
    for SHAPE in VM.Standard.A1.Flex VM.Standard.E2.1.Micro; do
      OS_SHAPE=$SHAPE
      IMG=$(oci compute image list -c "$T" --operating-system "Canonical Ubuntu" --operating-system-version "24.04" --shape "$OS_SHAPE" --sort-by TIMECREATED --query 'data[0].id' --raw-output)
      CFG=$([ "$SHAPE" = VM.Standard.A1.Flex ] && echo '--shape-config {"ocpus":1,"memoryInGBs":6}' || true)
      INST=$(oci compute instance launch -c "$T" --availability-domain "$AD" --display-name mm-recorder --shape "$SHAPE" $CFG \
        --image-id "$IMG" --subnet-id "$SUB" --assign-public-ip true --ssh-authorized-keys-file "$KEY.pub" \
        --user-data-file cloud-init.yaml --wait-for-state RUNNING --query 'data.id' --raw-output 2>/tmp/mm-oci-launch.err) && break 2
      echo "no $SHAPE in $AD: $(grep -o '"message": "[^"]*"' /tmp/mm-oci-launch.err | head -1)" >&2
    done
  done
fi
[ -n "$INST" ] || { echo "no Always Free capacity in any availability domain" >&2; exit 1; }
IP=$(oci compute instance list-vnics --instance-id "$INST" --query 'data[0]."public-ip"' --raw-output)
echo "{\"instance\": \"$INST\", \"ip\": \"$IP\"}"
