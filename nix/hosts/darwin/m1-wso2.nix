# M1 Office Computer Configuration (WSO2)
# User: isala
# Platform Engineering focused setup
{ pkgs, ... }:
{
  imports = [
    ../../modules/darwin/common.nix
  ];

  # =============================================
  # Additional Work-Specific Packages
  # =============================================
  environment.systemPackages = with pkgs; [
    # ─────────────────────────────────────────
    # Azure & Cloud (WSO2 specific)
    # ─────────────────────────────────────────
    (azure-cli.withExtensions [
      azure-cli.extensions.aks-preview
      azure-cli.extensions.bastion
      azure-cli.extensions.ssh
    ])
    kubelogin # Azure AD auth for AKS

    # ─────────────────────────────────────────
    # Kubernetes Networking (Cilium stack)
    # ─────────────────────────────────────────
    cilium-cli # Cilium management
    hubble # Cilium observability

    # ─────────────────────────────────────────
    # GitOps & CD
    # ─────────────────────────────────────────
    fluxcd # Alternative GitOps

    # ─────────────────────────────────────────
    # Development
    # ─────────────────────────────────────────
    pnpm # Fast package manager
    kind # Local k8s clusters
    k3d # Local k8s clusters

    # ─────────────────────────────────────────
    # Testing & Performance
    # ─────────────────────────────────────────
    k6 # Load testing
  ];

  environment.variables = {
    PATH = "$HOME/.rd/bin:$PATH";
  };

  # =============================================
  # Fish Shell - Work-specific paths
  # =============================================
  programs.fish.interactiveShellInit = ''
    # Rancher Desktop on PATH
    fish_add_path ~/.rd/bin
  '';

  # =============================================
  # Homebrew - Work-only additions
  # =============================================
  homebrew = {
    brews = [
      "jmeter" # Performance testing
      "llama.cpp" # Local LLM inference
    ];

    casks = [
      # Browsers
      "brave-browser"

      # Development
      "rancher" # Container management (Docker alternative)

      # Work
      "workspace-one-intelligent-hub"

      # AWS
      "session-manager-plugin"

      # Utilities
      "wireshark-app" # Network analysis
    ];

    masApps = { };
  };
}
