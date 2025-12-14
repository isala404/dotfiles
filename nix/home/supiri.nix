# Home configuration for supiri (M3 Personal)
{ ... }:
{
  imports = [
    ../modules/home/common.nix
  ];

  home.packages = [ ];

  # Git user info (full name for personal)
  programs.git = {
    userName = "Isala Piyarisi";
    userEmail = "mail@isala.me";
    extraConfig.pull.rebase = true;  # Personal preference
  };
}
