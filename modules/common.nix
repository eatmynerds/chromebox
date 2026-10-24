{ lib, pkgs, inventory, name, ... }:
let
  c = inventory.cluster;
in
{
  system.stateVersion = "25.11";

  networking.hostName = name;
  time.timeZone = c.timeZone;

  networking.hosts = lib.mapAttrs' (n: h: lib.nameValuePair h.ip [ n "${n}.${c.domain}" ]) inventory.hosts;

  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;

  # one initrd for every laptop
  boot.initrd.availableKernelModules = [
    "nvme" "ahci" "sd_mod" "xhci_pci" "ehci_pci" "usb_storage" "usbhid"
    "sdhci_pci" "sdhci_acpi" "mmc_block" "rtsx_pci_sdmmc"
  ];
  # usb ethernet adapters
  boot.kernelModules = [ "r8152" "ax88179_178a" "cdc_ether" "cdc_ncm" ];

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

  # password is only for the local console, ssh is key-only
  users.mutableUsers = false;
  users.users.${c.adminUser} = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    hashedPasswordFile = "/etc/nixos-secrets/user-password.hash";
  };
  security.sudo.wheelNeedsPassword = false;
  # keys come from .env, not nix
  users.allowNoPasswordLogin = true;

  services.openssh = {
    enable = true;
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
