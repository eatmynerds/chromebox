{
  description = "chromebox cluster";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nixpkgs, disko, ... }:
    let
      inherit (nixpkgs) lib;
      inventory = import ./inventory.nix;

      mkHost = name: host: lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inventory name host; };
        modules = [
          disko.nixosModules.disko
          ./modules/common.nix
          ./modules/network.nix
          ./modules/disk.nix
          ./modules/k3s.nix
          ./modules/laptop-server.nix
          (./modules/hardware + "/${host.hardware}.nix")
        ];
      };
      hosts = lib.mapAttrs mkHost inventory.hosts;

      installer = lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inventory hosts; };
        modules = [
          "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
          ./modules/installer.nix
        ];
      };
    in
    {
      nixosConfigurations = hosts;
      packages.x86_64-linux.installer-iso = installer.config.system.build.isoImage;
    };
}
