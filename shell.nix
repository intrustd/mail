{ pkgs ? (import <nixpkgs> {}) }:

let stdenv = pkgs.stdenv;

    intrustd-py-srcs =
      pkgs.fetchFromGitHub {
        owner = "intrustd";
        repo = "py-intrustd";
        rev = "3ded67ad1d153f7d3e969fce2f26e5f737a2a1c8";
        sha256 = "14dkz41n81vfppab2k4b8mc25ciqzwsr1wrw6slbsxi1znvdajsk";
      };

    intrustd-py = pkgs.callPackage intrustd-py-srcs { };

    iniherit = pkgs.python3.pkgs.buildPythonPackage rec {
      pname = "iniherit";
      version = "0.3.9";

      src = pkgs.python3.pkgs.fetchPypi {
        inherit pname version;
        sha256 = "06d90849ff0c4fadb7e255ce31e7c8e188a99af90d761435c72b79b36adbb67a";
      };

      propagatedBuildInputs = with pkgs.python3.pkgs; [ six ];
      doCheck = false;
    };

    yoyo-migrations = pkgs.python3.pkgs.buildPythonPackage rec {
      pname = "yoyo-migrations";
      version = "6.1.0";

      src = pkgs.python3.pkgs.fetchPypi {
        inherit pname version;
        sha256 = "4538dbdfe4784c30bade14275558247ec8ce8111b4948dc38f51d4172f9d513c";
      };

      propagatedBuildInputs = with pkgs.python3.pkgs; [ iniherit text-unidecode ];
      doCheck = false;
    };

    exim = pkgs.exim.overrideDerivation (super: {
      buildInputs = super.buildInputs ++ [ pkgs.sqlite ];
      nativeBuildInputs = [ pkgs.perl pkgs.pkgconfig pkgs.stdenv.cc ];
      depsBuildBuild = [ pkgs.buildPackages.stdenv.cc ];
      preBuild = ''
        ${super.preBuild}
        mv Local/Makefile Local/Makefile.bak
        PKG_CONFIG_PATH=$PKG_CONFIG_PATH:${pkgs.sqlite.dev}/lib/pkgconfig
        substituteInPlace scripts/Configure-Makefile --replace pcre-config ${pkgs.pcre.dev}/bin/pcre-config
        sed 's:^# \(LOOKUP_SQLITE=yes\):\1:
             s:^# \(LOOKUP_SQLITE_PC=sqlite3\):\1:
             s:^LOOKUP_DBM=yes$:USE_DBM=yes:
             ' < Local/Makefile.bak > Local/Makefile
        echo 'LOOKUP_LIBS+=-L${pkgs.db.out}/lib' >> Local/Makefile
        echo 'DBMLIB=-L${pkgs.db.out}/lib -ldb' >> Local/Makefile
        echo 'INCLUDE+=-I${pkgs.db.dev}/include' >> Local/Makefile
        cat Local/Makefile
      '';
    });

    clamav = (pkgs.clamav.overrideDerivation
                 (super: { configureFlags = builtins.filter (flag: flag != "--enable-milter") super.configureFlags ++ [ "--disable-libsystemd" ];
                           postPatch = ''
                             ${super.postPatch}
                             substituteInPlace clamd/priv_fts.h --replace __BEGIN_DECLS "" --replace __END_DECLS "" --replace __THROW ""
                             substituteInPlace clamd/fts.c --replace "_D_EXACT_NAMLEN (dp)" "((dp)->d_reclen)"
                           ''; }))
                 .override { systemd = null; libmilter = null; };

    spamassassin = pkgs.callPackage ./spamassassin.nix {};

in pkgs.stdenv.mkDerivation {
  name = "intrustd-mail";

  inherit  yoyo-migrations exim clamav pkgs spamassassin;

  buildInputs = with pkgs; [
    nodejs-8_x zlib

    sqlite

    exim clamav

    nix-prefetch-git nodePackages.node2nix

    (python3.withPackages (ps: [
       ps.flask ps.sqlalchemy intrustd-py ps.requests
       yoyo-migrations
     ]))

     lighttpd php
  ];

  inherit intrustd-py;

#  CMAKE_
}
