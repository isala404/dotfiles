# Common home-manager configuration for Linux
# Similar to common.nix but without macOS-specific configs
{ ... }:
{
  imports = [
    ./starship.nix
    ./git.nix
    # Note: editors.nix has macOS-specific paths, create a linux version if needed
  ];

  home.stateVersion = "24.11";

  # Nix configuration
  xdg.configFile."nix/nix.conf".text = ''
    experimental-features = nix-command flakes
  '';
}
