{ lib, inventory, host, config, ... }:
let
  c = inventory.cluster;
  vlanIface = "vlan${toString c.vlanId}";

  uplinkMatch =
    if host.mac != null
    then { PermanentMACAddress = host.mac; }
    else { Type = "ether"; Path = "pci-*"; };

  l3 = {
    address = [ "${host.ip}/${toString c.prefixLength}" ];
    gateway = [ c.gateway ];
    dns = c.dns;
    linkConfig.RequiredForOnline = "routable";
  };
in
{
  options.cluster.iface = lib.mkOption {
    type = lib.types.str;
    readOnly = true;
    default = if c.taggedVlan then vlanIface else "lan0";
  };

  config = {
    networking.useDHCP = false;
    networking.useNetworkd = true;
    networking.wireless.enable = false;

    systemd.network = {
      enable = true;

      links."10-lan0" = {
        matchConfig = uplinkMatch;
        linkConfig.Name = "lan0";
      };

      netdevs = lib.mkIf c.taggedVlan {
        "20-${vlanIface}" = {
          netdevConfig = { Kind = "vlan"; Name = vlanIface; };
          vlanConfig.Id = c.vlanId;
        };
      };

      networks =
        if c.taggedVlan then {
          "10-lan0" = {
            matchConfig.Name = "lan0";
            vlan = [ vlanIface ];
            networkConfig.LinkLocalAddressing = "no";
            linkConfig.RequiredForOnline = "carrier";
          };
          "20-${vlanIface}" = { matchConfig.Name = vlanIface; } // l3;
        } else {
          "10-lan0" = { matchConfig.Name = "lan0"; } // l3;
        };
    };

    networking.firewall = {
      enable = true;
      allowedTCPPorts = [
        6443  # Kubernetes API
        2379  # etcd client (servers)
        2380  # etcd peer (servers)
        10250 # kubelet metrics/logs
      ];
      allowedTCPPortRanges = [{ from = 30000; to = 32767; }]; # NodePorts (Portainer = 30777/30779)
      allowedUDPPorts = [ 8472 ]; # flannel VXLAN
      trustedInterfaces = [ "cni0" "flannel.1" ];
    };
  };
}
