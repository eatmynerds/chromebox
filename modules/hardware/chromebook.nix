{ lib, ... }:
{
  hardware.cpu.intel.updateMicrocode = true;

  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;
}
