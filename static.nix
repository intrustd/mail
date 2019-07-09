{ pkgs, stdenv, manifest }:

let nodePkgSet = import ./js { pkgs = pkgs.buildPackages; nodejs = pkgs.buildPackages."nodejs-8_x"; };

    nodeDeps = (nodePkgSet.shell.override { bypassCache = true; }).nodeDependencies;

in pkgs.buildEnv {
  name = "mail-static-todo";
  paths = [];
  postBuild = ''
    cat >$out/manifest.json <<EOF
    {}
  '';
}
