# Home configuration for isala (M1 Office)
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
    pull.rebase = true; # Office preference
  };
}
