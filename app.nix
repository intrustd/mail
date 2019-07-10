{ pkgs, lib, intrustd, pure-build, ... }:
let ourPkgs = (import ./shell.nix { inherit pkgs; });
    inherit (ourPkgs) exim clamav;

    mailDir = "/intrustd/mail";
    spoolDir = "${mailDir}/spool";
    intrustdMailDb = "/intrustd/mail/accounts.db";
    clamAvDir = "/run/clamav";
    clamAvStateDir = "/intrustd/clamav-db";
    spamdPort = 11333;
    spamdControllerPort = spamdPort + 1;
    spamdPid = "/run/spamd.pid";

    accountsDir = "/intrustd/accounts";

    clamAvSock = "${clamAvDir}/local.sock";
    clamAvPid = "${clamAvDir}/clamd.pid";

    eximUser = "intrustd";
    eximGroup = "intrustd";
    clamAvUser = "intrustd";
    clamAvGroup = "intrustd";
    rspamdUser = "intrustd";
    rspamdGroup = "intrustd";

    eximConfiguration = pkgs.substituteAll {
      isExecutable = false;
      src = ./resources/exim.conf;
      inherit mailDir spoolDir intrustdMailDb clamAvSock
              spamdPort eximUser eximGroup accountsDir;
    };

    clamAvConfiguration = pkgs.substituteAll {
      isExecutable = false;
      src = ./resources/clamav.conf;
      inherit clamAvSock clamAvPid clamAvUser clamAvGroup clamAvStateDir;
    };

    rspamdConfiguration = pkgs.substituteAll {
      isExecutable = false;
      src = ./resources/rspamd.conf;
      inherit spamdPort spamdPid spamdControllerPort;
    };

in {
  app.meta = {
    slug = "mail";
    name = "Intrustd Mail";
    authors = [ "Travis Athougies<travis@athougies.net>" ];
    app-url = "https://mail.intrustd.com";
    icon = "https://mail.intrustd.com/images/mail.svg";
  };

  app.identifier = "mail.intrustd.com";
  app.singleton = true;

  app.services.smtpd = {
    name = "smtpd";
    autostart = true;

    startExec = ''
      mkdir -p ${spoolDir}
      chown ${eximUser}:${eximGroup} ${spoolDir}
      exec ${exim}/bin/exim -bdf -q30m -C ${eximConfiguration}
    '';
  };

  app.services.clamav = {
    name = "clamav";
    autostart = true;

    startExec = ''
       mkdir -m 0755 -p ${clamAvDir}
       mkdir -p ${clamAvStateDir}
       exec ${clamav}/bin/clamd
    '';
  };

  app.services.rspamd = {
    name = "rspamd";
    autostart = true;

    startExec = ''
       exec ${pkgs.rspamd}/bin/rspamd --user=${rspamdUser} --group=${rspamdGroup} -f -c ${rspamdConfiguration}
    '';
  };

  # TODO freshclam sa-update
}
