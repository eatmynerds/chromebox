{ ... }:
{
  hardware.cpu.intel.updateMicrocode = true;

  # Always plugged in: cap the battery at 80% so it doesn't swell.
  services.tlp = {
    enable = true;
    settings = {
      START_CHARGE_THRESH_BAT0 = 40;
      STOP_CHARGE_THRESH_BAT0 = 80;
    };
  };
}
