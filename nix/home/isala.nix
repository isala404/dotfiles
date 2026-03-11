# Home configuration for isala (M1 Office)
{ ... }:
{
  imports = [
    ../modules/home/common.nix
  ];

  home.packages = [ ];

  # Ghostty terminal config
  xdg.configFile."ghostty/config".text = ''
    font-family = JetBrainsMono Nerd Font
    font-size = 13

    theme = One Half Dark

    window-padding-x = 8
    window-padding-y = 4

    window-width = 140
    window-height = 35

    background-opacity = 0.95
    background-blur = true

    cursor-style = block
    cursor-style-blink = true

    scrollback-limit = 10000000

    copy-on-select = clipboard

    shell-integration = fish

    mouse-hide-while-typing = true

    confirm-close-surface = false
  '';

  # Git user info (using new settings API)
  programs.git.settings = {
    user = {
      name = "Isala Piyarisi";
      email = "mail@isala.me";
    };
    pull.rebase = true; # Office preference
  };
}
