{ pkgs, lib, intrustd, pure-build, ... }:
let ourPkgs = (import ./shell.nix { inherit pkgs; });
    inherit (ourPkgs) exim clamav spamassassin;

    mailDir = "/intrustd/mail";
    spoolDir = "${mailDir}/spool";
    intrustdMailDb = "/intrustd/mail/accounts.db";
    spamAssassinStateDir = "/intrustd/spam";
    clamAvDir = "/run/clamav";
    clamAvStateDir = "/intrustd/clamav-db";
    spamdSock = "/run/spamd.sock";

    accountsDir = "/intrustd/accounts";

    clamAvSock = "${clamAvDir}/local.sock";
    clamAvPid = "${clamAvDir}/clamd.pid";

    eximUser = "intrustd";
    eximGroup = "intrustd";
    clamAvUser = "intrustd";
    clamAvGroup = "intrustd";
    spamAssassinUser = "intrustd";
    spamAssassinGroup = "intrustd";

    eximConfiguration = pkgs.substituteAll {
      isExecutable = false;
      src = ./resources/exim.conf;
      inherit mailDir spoolDir intrustdMailDb clamAvSock
              spamdSock eximUser eximGroup accountsDir;
    };

    clamAvConfiguration = pkgs.substituteAll {
      isExecutable = false;
      src = ./resources/clamav.conf;
      inherit clamAvSock clamAvPid clamAvUser clamAvGroup clamAvStateDir;
    };

    spamd-init-pre = pkgs.writeText "init.pre" ''
      required_score   5.0
      use_bayes        1
      bayes_auto_learn 1
      add_header all Status _YESNO_, score=_SCORE_ required=_REQD_ tests=_TESTS_ autolearn=_AUTOLEARN_ version=_VERSION_
    '';

    spamd-local-cf = pkgs.substituteAll {
      isExecutable = false;
      src = ./resources/spamd-local.cf;
    };

    spamdEnv = pkgs.buildEnv {
      name = "spamd-env";
      paths = [];
      postBuild = ''
        ln -sf ${spamd-init-pre} $out/init.pre
        ln -sf ${spamd-local-cf} $out/local.cf
      '';
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

  app.services.spamassassin = {
    name = "spamassassin";
    autostart = true;

    startExec = ''
       mkdir -p ${spamAssassinStateDir}
       chown ${spamAssassinUser}:${spamAssassinGroup} ${spamAssassinStateDir}
       # TODO Run sa-update
       exec ${spamassassin}/bin/spamd --username=${spamAssassinUser} --groupname=${spamAssassinGroup} \
            --siteconfigpath=${spamdEnv} --allow-tell --pidfile=/run/spamd.pid --virtual-config-dir=${accountsDir}/%u/spam
    '';
  };

  # TODO freshclam sa-update
}
