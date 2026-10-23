{ lib, ... }:
{
  hardware.cpu.intel.updateMicrocode = true;

  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

  boot.kernelModules = [ "r8152" "ax88179_178a" "cdc_ether" ];
}
