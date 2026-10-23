{
  cluster = {
    domain = "lab";
    timeZone = "America/Chicago";

    vlanId = 1;
    taggedVlan = false;

    prefixLength = 24;
    gateway = "192.168.1.1";
    dns = [ "192.168.1.1" "1.1.1.1" ];

    apiAddress = "192.168.1.201";

    adminUser = "nerds";
  };

  hosts = {
    tp1 = { ip = "192.168.1.201"; mac = null; role = "server"; init = true; hardware = "thinkpad";   };
    tp2 = { ip = "192.168.1.202"; mac = null; role = "server";              hardware = "thinkpad";   };
    tp3 = { ip = "192.168.1.203"; mac = null; role = "server";              hardware = "thinkpad";   };
    tp4 = { ip = "192.168.1.204"; mac = null; role = "agent";               hardware = "thinkpad";   };

    cb1 = { ip = "192.168.1.211"; mac = null; role = "agent";               hardware = "chromebook"; };
    cb2 = { ip = "192.168.1.212"; mac = null; role = "agent";               hardware = "chromebook"; };
    cb3 = { ip = "192.168.1.213"; mac = null; role = "agent";               hardware = "chromebook"; };
  };
}
