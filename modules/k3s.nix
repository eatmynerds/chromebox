{ lib, config, inventory, host, ... }:
let
  c = inventory.cluster;
  isServer = host.role == "server";
  isInit = host.init or false;
  # Shared secret for joining the cluster. Copied in by scripts/install.sh,
  # never stored in the Nix store or git.
  tokenFile = "/var/lib/rancher/k3s/cluster-token";
in
{
  services.k3s = {
    enable = true;
    role = host.role;
    inherit tokenFile;
    clusterInit = isInit;
    serverAddr = lib.optionalString (!isInit) "https://${c.apiAddress}:6443";
    extraFlags = [
      "--node-ip=${host.ip}"
      "--flannel-iface=${config.cluster.iface}"
    ] ++ lib.optionals isServer [
      "--tls-san=${c.apiAddress}"
      "--tls-san=${config.networking.hostName}.${c.domain}"
    ];

    # Portainer, installed by k3s's built-in Helm controller on the init server.
    # UI: https://<any-node-ip>:30779  (http on 30777)
    manifests = lib.mkIf isInit {
      portainer.content = {
        apiVersion = "helm.cattle.io/v1";
        kind = "HelmChart";
        metadata = {
          name = "portainer";
          namespace = "kube-system";
        };
        spec = {
          repo = "https://portainer.github.io/k8s/";
          chart = "portainer";
          targetNamespace = "portainer";
          createNamespace = true;
          valuesContent = builtins.toJSON {
            service.type = "NodePort";
            persistence.enabled = true;
          };
        };
      };
    };
  };

  # Don't crash-loop k3s on a box that hasn't received the token yet.
  systemd.services.k3s.unitConfig.ConditionPathExists = tokenFile;

  environment.shellAliases = lib.mkIf isServer {
    kubectl = "sudo k3s kubectl";
    k = "sudo k3s kubectl";
  };
}
