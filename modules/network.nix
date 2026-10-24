{ lib, inventory, host, ... }:
let
  c = inventory.cluster;
  vlanIface = "vlan${toString c.vlanId}";

  # static ip on any wired port, or just the one with `mac` if set
  # lan0 is for nodes from the old config
  wiredMatch =
    if host.mac != null
    then { PermanentMACAddress = host.mac; }
    else { Name = "en* lan0"; };

  l3 = {
    address = [ "${host.ip}/${toString c.prefixLength}" ];
    gateway = [ c.gateway ];
    dns = c.dns;
    linkConfig.RequiredForOnline = "routable";
  };
in
{
  # flannel iface, null = default route
  options.cluster.iface = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    readOnly = true;
    default = if c.taggedVlan then vlanIface else null;
  };

  config = {
    networking.useDHCP = false;
    networking.useNetworkd = true;
    networking.wireless.enable = false;

    # some usb adapters show up as a cd drive first
    hardware.usb-modeswitch.enable = true;

    systemd.network = {
      enable = true;

      wait-online.anyInterface = true;

      netdevs = lib.mkIf c.taggedVlan {
        "20-${vlanIface}" = {
          netdevConfig = { Kind = "vlan"; Name = vlanIface; };
          vlanConfig.Id = c.vlanId;
        };
      };

      networks =
        if c.taggedVlan then {
          "10-wired" = {
            matchConfig = wiredMatch;
            vlan = [ vlanIface ];
            networkConfig.LinkLocalAddressing = "no";
            linkConfig.RequiredForOnline = "carrier";
          };
          "20-${vlanIface}" = { matchConfig.Name = vlanIface; } // l3;
        } else {
          "10-wired" = { matchConfig = wiredMatch; } // l3;
        };
    };

    networking.firewall = {
      enable = true;
      allowedTCPPorts = [
        6443  # k8s api
        2379  # etcd
        2380  # etcd peer
        10250 # kubelet
      ];
      allowedTCPPortRanges = [{ from = 30000; to = 32767; }]; # nodeports
      allowedUDPPorts = [ 8472 ]; # flannel
      trustedInterfaces = [ "cni0" "flannel.1" ];
    };
  };
}
