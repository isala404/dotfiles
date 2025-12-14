# Common home-manager configuration
# Imports all shared home modules
{ ... }:
{
  imports = [
    ./starship.nix
    ./git.nix
    ./editors.nix
  ];

  home.stateVersion = "24.11";

  # Nix configuration
  xdg.configFile."nix/nix.conf".text = ''
    experimental-features = nix-command flakes
  '';
}
