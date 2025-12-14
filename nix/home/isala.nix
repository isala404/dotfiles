# Home configuration for isala (M1 Office)
{ ... }:
{
  imports = [
    ../modules/home/common.nix
  ];

  home.packages = [ ];

  # Git user info
  programs.git = {
    userName = "Isala Piyarisi";
    userEmail = "mail@isala.me";
    extraConfig.pull.rebase = true;  # Office preference
  };
}
