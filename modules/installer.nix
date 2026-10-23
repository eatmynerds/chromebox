{ lib, pkgs, inventory, hosts, ... }:
let
  secretsDir = builtins.getEnv "CLUSTER_SECRETS_DIR";
  secrets =
    if secretsDir == ""
    then throw "Build the USB with ./scripts/build-usb.sh -- it supplies the SSH keys and k3s token."
    else builtins.path { path = secretsDir; name = "cluster-secrets"; };

  hostsJson = pkgs.writeText "cluster-hosts.json" (builtins.toJSON (lib.mapAttrs
    (name: h: {
      inherit (h) ip role hardware;
      mac = if h.mac == null then null else lib.toLower h.mac;
      toplevel = "${hosts.${name}.config.system.build.toplevel}";
      format = "${hosts.${name}.config.system.build.formatScript}";
      mount = "${hosts.${name}.config.system.build.mountScript}";
    })
    inventory.hosts));

  autoInstall = pkgs.writeShellApplication {
    name = "cluster-auto-install";
    runtimeInputs = with pkgs; [
      coreutils util-linux gptfdisk jq gnugrep gnused systemd nix nixos-install-tools
    ];
    checkPhase = ":";
    text = ''
      HOSTS_JSON=${hostsJson}
      SECRETS=${secrets}
    '' + builtins.readFile ../scripts/auto-install.sh;
  };
in
{
  environment.systemPackages = [ autoInstall ];

  systemd.services.cluster-auto-install = {
    description = "Wipe internal disk and install cluster node";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-udev-settle.service" ];
    conflicts = [ "getty@tty1.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe autoInstall;
      StandardInput = "tty-force";
      StandardOutput = "tty";
      StandardError = "tty";
      TTYPath = "/dev/tty1";
      TTYReset = true;
      TTYVHangup = true;
    };
  };

  boot.kernelParams = [ "consoleblank=0" ];
  isoImage.squashfsCompression = "zstd -Xcompression-level 6";
}
