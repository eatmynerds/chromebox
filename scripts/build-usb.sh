#!/usr/bin/env bash
# Builds the auto-installer ISO. Flash it to a USB stick once, then boot every
# node (ThinkPad or Chromebook) from it -- it wipes the disk and installs.
#
# Usage: ./scripts/build-usb.sh
# Rebuild it after changing inventory.nix, modules/, or .env.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/lib.sh

# Flakes only see files git knows about; .gitignore keeps the secrets out.
git add -A
check_secrets_untracked

stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
build_authorized_keys "$stage/authorized_keys"
build_password_hash "$stage/user-password.hash"
ensure_token
cp secrets/k3s-token "$stage/k3s-token"

echo "Building installer ISO (first build downloads a few GB and takes a while)..."
CLUSTER_SECRETS_DIR="$stage" nix build --impure .#installer-iso -o result-iso
install -m 600 result-iso/iso/*.iso ./k3s-installer.iso
rm -f result-iso

echo
echo "ISO: $(pwd)/k3s-installer.iso"
echo "Flash it with Rufus (pick 'DD image' mode) or balenaEtcher."
echo "It contains your k3s token -- keep the USB stick private."
