{ lib, inventory, name, host, ... }:
let
  c = inventory.cluster;
  isInit = host.init or false;
  mediaDir = "/srv/media";

  # one jellyfin per media host, pinned to that node
  release = node: nodePort: {
    content = {
      apiVersion = "helm.cattle.io/v1";
      kind = "HelmChart";
      metadata = {
        name = "jellyfin-${node}";
        namespace = "kube-system";
      };
      spec = {
        repo = "https://jellyfin.github.io/jellyfin-helm";
        chart = "jellyfin";
        targetNamespace = "jellyfin-${node}";
        createNamespace = true;
        valuesContent = builtins.toJSON {
          service = {
            type = "NodePort";
            inherit nodePort;
          };
          nodeSelector."kubernetes.io/hostname" = node;
          persistence = {
            config.size = "10Gi";
            media = {
              type = "hostPath";
              hostPath = mediaDir;
            };
          };
        };
      };
    };
  };
in
{
  services.k3s.manifests = lib.mkIf isInit
    (lib.mapAttrs' (node: port: lib.nameValuePair "jellyfin-${node}" (release node port)) c.mediaHosts);

  systemd.tmpfiles.rules = lib.optional (c.mediaHosts ? ${name}) "d ${mediaDir} 0775 ${c.adminUser} users -";
}
