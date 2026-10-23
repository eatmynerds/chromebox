#!/usr/bin/env bash

# Usage: ./scripts/deploy.sh            # all hosts (init server, then servers, then agents)
#        ./scripts/deploy.sh tp2 cb1    # specific hosts

set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/lib.sh

git add -A
check_secrets_untracked

stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
build_authorized_keys "$stage/authorized_keys"
build_password_hash "$stage/user-password.hash"

hosts_json=$(nix eval --json --file ./inventory.nix hosts)

if [ $# -gt 0 ]; then
  targets=("$@")
else
  mapfile -t targets < <(jq -r '
    to_entries
    | sort_by(if .value.init == true then 0 elif .value.role == "server" then 1 else 2 end)
    | .[].key' <<<"$hosts_json")
fi

for h in "${targets[@]}"; do
  ip=$(jq -r --arg h "$h" '.[$h].ip' <<<"$hosts_json")
  echo "==> $h ($ip)"
  ssh "root@$ip" 'install -m 644 /dev/stdin /etc/ssh/cluster_authorized_keys' < "$stage/authorized_keys"
  if [ -f "$stage/user-password.hash" ]; then
    ssh "root@$ip" 'install -D -m 600 /dev/stdin /etc/nixos-secrets/user-password.hash' < "$stage/user-password.hash"
  fi
  nixos-rebuild switch --flake ".#$h" --target-host "root@$ip"
done
