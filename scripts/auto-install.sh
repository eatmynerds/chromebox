say() { printf '\n\033[1m%s\033[0m\n' "$*"; }
halt() {
  printf '\n%s\n' "$*"
  echo "Press Alt+F2 for a shell, or just power off."
  sleep infinity
}
trap 'halt "$(printf "\033[31mINSTALL FAILED (line %s). Nothing was changed if it failed before wiping.\033[0m" "$LINENO")"' ERR

clear || true
say "=== k3s cluster auto-installer ==="
udevadm settle

get() { jq -r --arg n "$host" ".[\$n].$1" "$HOSTS_JSON"; }

# which host is this
host=""
while read -r mac; do
  match=$(jq -r --arg mac "$mac" 'to_entries[] | select(.value.mac == $mac) | .key' "$HOSTS_JSON")
  if [ -n "$match" ]; then host=$match; break; fi
done < <(cat /sys/class/net/*/address 2>/dev/null)

vendor=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || echo unknown)
case "$vendor" in
  Google*) detected=chromebook ;;
  LENOVO*) detected=thinkpad ;;
  *) detected="" ;;
esac

if [ -n "$host" ]; then
  say "Recognised this machine by its MAC address: $host"
else
  mapfile -t names < <(jq -r 'keys[]' "$HOSTS_JSON")
  say "Which machine is this?  (detected: $vendor${detected:+ -> $detected})"
  for i in "${!names[@]}"; do
    n=${names[$i]}
    printf '  %2d) %-6s %-15s %-7s %s\n' $((i + 1)) "$n" \
      "$(jq -r --arg n "$n" '.[$n].ip' "$HOSTS_JSON")" \
      "$(jq -r --arg n "$n" '.[$n].role' "$HOSTS_JSON")" \
      "$(jq -r --arg n "$n" '.[$n].hardware' "$HOSTS_JSON")"
  done
  while [ -z "$host" ]; do
    read -r -p "Number or name: " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#names[@]})); then
      host=${names[$((choice - 1))]}
    elif jq -e --arg n "$choice" 'has($n)' "$HOSTS_JSON" >/dev/null; then
      host=$choice
    fi
  done
fi

boot_src=$(findmnt -no SOURCE /iso 2>/dev/null || true)
boot_disk=""
if [ -n "$boot_src" ]; then
  boot_disk=$(lsblk -npo PKNAME "$boot_src" 2>/dev/null | head -n1 || true)
  boot_disk=${boot_disk:-$boot_src}
fi

disk=$(lsblk -J -d -b -p -o NAME,SIZE,TYPE,RM,TRAN | jq -r --arg boot "$boot_disk" '
  [ .blockdevices[]
    | select(.type == "disk")
    | select(.rm == false or .rm == "0" or .rm == 0)
    | select((.tran // "") != "usb")
    | select(.name != $boot)
    | select(.name | test("boot[0-9]+$|rpmb$|^/dev/(loop|zram|ram|sr)") | not)
  ] | sort_by(.size | tonumber) | last | .name // empty')
[ -n "$disk" ] || halt "No internal disk found. Nothing was changed."
disk_desc=$(lsblk -dno MODEL,SIZE "$disk" | tr -s ' ')

say "About to ERASE EVERYTHING on:  $disk  ($disk_desc)"
echo "and install:                   $host  ($(get role), $(get hardware), $(get ip))"
if [ -n "$detected" ] && [ "$detected" != "$(get hardware)" ]; then
  printf '\033[33mWARNING: this looks like a %s but %s is configured as a %s.\033[0m\n' \
    "$detected" "$host" "$(get hardware)"
fi
echo
for s in $(seq 15 -1 1); do
  printf '\rStarting in %2ds -- press any key to CANCEL ' "$s"
  if read -r -s -n 1 -t 1; then
    echo
    halt "Cancelled. Nothing was changed."
  fi
done
echo

say "Wiping $disk"
umount -R /mnt 2>/dev/null || true
while read -r part; do wipefs -af "$part" || true; done < <(lsblk -lnpo NAME "$disk" | tail -n +2)
wipefs -af "$disk"
sgdisk --zap-all "$disk"
udevadm settle
ln -sfn "$disk" /dev/install-target

say "Partitioning and formatting"
"$(get format)"
"$(get mount)"

say "Copying SSH keys and cluster token"
install -D -m 644 "$SECRETS/authorized_keys" /mnt/etc/ssh/cluster_authorized_keys
install -D -m 600 "$SECRETS/k3s-token" /mnt/var/lib/rancher/k3s/cluster-token
if [ -f "$SECRETS/user-password.hash" ]; then
  install -D -m 600 "$SECRETS/user-password.hash" /mnt/etc/nixos-secrets/user-password.hash
fi
if [ -f "$SECRETS/portainer-admin-password" ]; then
  install -D -m 600 "$SECRETS/portainer-admin-password" /mnt/etc/nixos-secrets/portainer-admin-password
fi

say "Installing NixOS as $host (a few minutes)"
nixos-install --root /mnt --system "$(get toplevel)" --no-root-passwd --no-channel-copy
umount -R /mnt

trap - ERR
say "Done! $host is installed."
echo "Powering off in 15s. REMOVE THE USB STICK, then turn it back on."
echo "It will come up at $(get ip) and join the cluster by itself."
sleep 15
systemctl poweroff
