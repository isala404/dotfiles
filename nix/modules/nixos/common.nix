# Common NixOS (Linux server) configuration
# Shared across all Linux servers
{ pkgs, ... }:
{
  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Enable Nix flakes
  nix.settings.experimental-features = "nix-command flakes";

  # Common system packages for all NixOS machines
  environment.systemPackages = with pkgs; [
    # Core utilities
    vim
    wget
    curl
    ripgrep
    jq
    yq
    htop
    tmux

    # Git
    git
    git-lfs
    gh

    # Languages & Runtimes (add as needed)
    go
    nodejs_20

    # Kubernetes & Cloud (for servers that need it)
    kubectl
    kubernetes-helm
    k9s

    # Security
    trivy

    # Nix tooling
    nixfmt-rfc-style
  ];

  environment.variables = {
    EDITOR = "vim";
  };

  # Fish shell
  programs.fish.enable = true;

  # Zsh shell
  programs.zsh.enable = true;

  # Basic firewall
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ]; # SSH
  };

  # Enable SSH
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # Timezone
  time.timeZone = "UTC";

  # System settings
  system.stateVersion = "24.11";
}
