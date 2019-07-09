import <intrustd/nix/hydra-app-jobsets.nix> {
  description = "Intrustd Mail App";
  src = { type = "git"; value = "git://github.com/intrustd/mail.git"; emailresponsible = true; };
}
