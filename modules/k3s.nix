{ lib, pkgs, config, inventory, host, ... }:
let
  c = inventory.cluster;
  isServer = host.role == "server";
  isInit = host.init or false;
  # join token, kept out of the store
  tokenFile = "/var/lib/rancher/k3s/cluster-token";
  portainerPasswordFile = "/etc/nixos-secrets/portainer-admin-password";
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
    ] ++ lib.optional (config.cluster.iface != null) "--flannel-iface=${config.cluster.iface}"
    ++ lib.optionals isServer [
      "--tls-san=${c.apiAddress}"
      "--tls-san=${config.networking.hostName}.${c.domain}"
    ];

    # portainer on https 30779
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

  # no token yet, don't start
  systemd.services.k3s.unitConfig.ConditionPathExists = tokenFile;

  # create the portainer admin before the setup timeout
  # needs the setup token from the logs
  systemd.services.portainer-admin-init = lib.mkIf isInit {
    description = "Create Portainer admin account";
    wantedBy = [ "multi-user.target" ];
    after = [ "k3s.service" ];
    unitConfig.ConditionPathExists = portainerPasswordFile;
    path = [ pkgs.curl pkgs.jq pkgs.gnugrep config.services.k3s.package ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      api=https://${host.ip}:30779/api
      body=$(jq -n --rawfile pw ${portainerPasswordFile} '{Username: "admin", Password: $pw}')
      for _ in $(seq 1 180); do
        # 204 means admin exists
        if [ "$(curl -sk -o /dev/null -w '%{http_code}' $api/users/admin/check || true)" = 204 ]; then
          echo "Portainer admin account already exists"; exit 0
        fi
        token=$(k3s kubectl -n portainer logs deploy/portainer 2>/dev/null \
          | grep -o 'setup_token=[0-9a-f]*' | tail -n 1 | cut -d= -f2 || true)
        code=$(curl -sk -o /dev/null -w '%{http_code}' -X POST \
          -H 'Content-Type: application/json' -H "X-Setup-Token: $token" -d "$body" \
          $api/users/admin/init || true)
        case "$code" in
          200|204) echo "Portainer admin account created"; exit 0 ;;
          409) echo "Portainer admin account already exists"; exit 0 ;;
        esac
        sleep 5
      done
      echo "Portainer never became reachable (last HTTP code: $code)" >&2
      exit 1
    '';
  };

  environment.shellAliases = lib.mkIf isServer {
    kubectl = "sudo k3s kubectl";
    k = "sudo k3s kubectl";
  };
}
