# Home configuration for supiri (M3 Personal)
{ ... }:
{
  imports = [
    ../modules/home/common.nix
  ];

  home.packages = [ ];

  # Git user info (using new settings API)
  programs.git.settings = {
    user = {
      name = "Isala Piyarisi";
      email = "mail@isala.me";
    };
    pull.rebase = true; # Personal preference
  };
}
