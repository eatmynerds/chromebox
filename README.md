# Chromebox

One USB stick installs every node. 

## Setup

You need Nix installed (`sh <(curl -L https://nixos.org/nix/install) --daemon`).

```bash
ssh-keygen -t ed25519
cp env.example .env # paste ~/.ssh/id_ed25519.pub into SSH_PUBLIC_KEY,
                    # optionally set USER_PASSWORD for keyboard login
./scripts/build-usb.sh
```

Flash the final iso to a USB stick

## Install

Plug the machine into the switch, boot it from the USB, and do nothing:

1. It works out which host it is. If you filled in `mac` in `inventory.nix` it's
   automatic; otherwise it shows a list and you type a number.
2. It finds the internal disk (NVMe, SATA, or Chromebook eMMC) by itself.
3. It shows what it's about to erase and counts down 15 s. **Press any key to cancel.**
4. Wipe → install → powers off. Pull the USB, power on. Done.

# Usage

Portainer: `https://192.168.1.201:30779` (any node IP works). Create the admin user within a
few minutes of first start or Portainer locks itself
(`k -n portainer rollout restart deploy/portainer` to unlock).

## Adding more devices later

1. Add a line to `hosts` in `inventory.nix` (new IP, `role = "agent"`).
2. `./scripts/build-usb.sh`, re-flash.
3. Boot the new machine from the USB.

## Changing things on running nodes

Edit a module (packages, firewall, k3s flags) or `.env` (keys, password), then:

```bash
./scripts/deploy.sh              # all nodes
./scripts/deploy.sh cb2          # just one
```