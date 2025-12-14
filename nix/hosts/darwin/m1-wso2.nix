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
    kubelogin       # Azure AD auth for AKS

    # ─────────────────────────────────────────
    # Kubernetes Networking (Cilium stack)
    # ─────────────────────────────────────────
    cilium-cli      # Cilium management
    hubble          # Cilium observability

    # ─────────────────────────────────────────
    # GitOps & CD
    # ─────────────────────────────────────────
    argocd          # GitOps CD
    fluxcd          # Alternative GitOps

    # ─────────────────────────────────────────
    # Development
    # ─────────────────────────────────────────
    pnpm            # Fast package manager
    kind            # Local k8s clusters
    k3d             # Local k8s clusters

    # ─────────────────────────────────────────
    # Testing & Performance
    # ─────────────────────────────────────────
    k6              # Load testing
    vegeta          # HTTP load testing
  ];

  environment.variables = {
    PATH = "$HOME/.rd/bin:$HOME/.bun/bin:$PATH";
  };

  # =============================================
  # Fish Shell - Work-specific paths
  # =============================================
  programs.fish.interactiveShellInit = ''
    set fish_greeting
    starship init fish | source
    zoxide init fish | source
    direnv hook fish | source

    # FZF configuration
    set -gx FZF_DEFAULT_COMMAND 'fd --type f --hidden --follow --exclude .git'
    set -gx FZF_CTRL_T_COMMAND "$FZF_DEFAULT_COMMAND"
    set -gx FZF_ALT_C_COMMAND 'fd --type d --hidden --follow --exclude .git'
    set -gx FZF_DEFAULT_OPTS '--height 40% --layout=reverse --border'

    function fish_should_add_to_history
      test (string length -- $argv) -le 500
    end

    # Rancher Desktop
    fish_add_path ~/.rd/bin
    fish_add_path ~/.bun/bin

    # Use kubecolor for kubectl output
    function kubectl
      command kubecolor $argv
    end
  '';

  # =============================================
  # Homebrew - Work Applications
  # =============================================
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "zap";
    };

    brews = [
      "mas"           # Mac App Store CLI
      "jmeter"        # Performance testing
      "llama.cpp"     # Local LLM inference
      "gemini-cli"    # Google Gemini
      "opencode"      # AI coding assistant
    ];

    casks = [
      # Browsers
      "google-chrome"
      "brave-browser"

      # Development
      "visual-studio-code"
      "cursor"
      "rancher"         # Container management (Docker alternative)
      "postman"
      "dbeaver-community"

      # Communication
      "discord"
      "spotify"
      "slack"

      # Work
      "workspace-one-intelligent-hub"

      # Utilities
      "vlc"
      "obs"
      "wireshark"       # Network analysis
    ];

    masApps = { };
  };

  # =============================================
  # User Configuration
  # =============================================
  users.users.isala.shell = pkgs.fish;

  system.activationScripts.extraActivation.text = ''
    softwareupdate --install-rosetta --agree-to-license
    echo "Setting fish as default shell for isala..." >&2
    dscl . -create /Users/isala UserShell /run/current-system/sw/bin/fish
  '';

  system.primaryUser = "isala";
}
