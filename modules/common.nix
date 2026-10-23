{ lib, pkgs, inventory, name, ... }:
let
  c = inventory.cluster;
in
{
  system.stateVersion = "25.11";

  networking.hostName = name;
  time.timeZone = c.timeZone;

  # Every node can resolve every other node by name (tp1, tp1.lab, ...).
  networking.hosts = lib.mapAttrs' (n: h: lib.nameValuePair h.ip [ n "${n}.${c.domain}" ]) inventory.hosts;

  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;

  # No per-machine hardware-configuration.nix: one initrd that boots any of
  # the laptops (NVMe, SATA, Chromebook eMMC, USB).
  boot.initrd.availableKernelModules = [
    "nvme" "ahci" "sd_mod" "xhci_pci" "ehci_pci" "usb_storage" "usbhid"
    "sdhci_pci" "sdhci_acpi" "mmc_block" "rtsx_pci_sdmmc"
  ];

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" "@wheel" ];
    auto-optimise-store = true;
  };
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  # Users are fully declarative. SSH is key-only; the password (optional,
  # USER_PASSWORD in .env) is only for logging in at the laptop's own keyboard.
  users.mutableUsers = false;
  users.users.${c.adminUser} = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    hashedPasswordFile = "/etc/nixos-secrets/user-password.hash";
  };
  security.sudo.wheelNeedsPassword = false;
  # Keys/password aren't in the Nix config (they're in the gitignored .env), so
  # tell NixOS we know -- the scripts guarantee a key file exists.
  users.allowNoPasswordLogin = true;

  services.openssh = {
    enable = true;
    # Written by the USB installer and scripts/deploy.sh from .env.
    authorizedKeysFiles = [ "/etc/ssh/cluster_authorized_keys" ];
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  services.fstrim.enable = true;

  environment.systemPackages = with pkgs; [
    vim
    git
    htop
    curl
    k9s
    kubernetes-helm
  ];
}
